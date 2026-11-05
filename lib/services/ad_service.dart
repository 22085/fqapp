import 'dart:async';
import 'dart:io';

import 'package:flutter_ads_plugin/flutter_ads_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';
import 'app_log.dart';

/// 激励视频结果：只有 [granted] 才算拿到奖励并解锁。
enum RewardOutcome {
  /// 播放完成并拿到奖励回调。
  granted,

  /// 用户在拿到奖励前关闭了广告：不解锁，停在当前集。
  dismissed,

  /// 加载/播放失败或超时：调用方按 fail-open 处理（不锁死用户），
  /// 但不记持久解锁。
  failed,
}

/// 灰鲸广告的唯一入口：初始化、插屏、激励、解锁记录。
///
/// 全部方法都 fail-open：SDK 未初始化、加载失败、超时、非 Android
/// 平台时直接返回，不抛异常、不挡住播放与阅读。广告永远不能成为
/// 用户看内容的障碍。
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  final FlutterAdsPlugin _plugin = FlutterAdsPlugin();

  bool _initialized = false;
  bool _interstitialShowing = false;
  DateTime? _lastInterstitialShownAt;
  final Set<String> _unlocked = <String>{};

  /// 每部剧一次激励解锁到的最远集号：拿到一次奖励后，后面一批集
  /// 直接看，不再弹激励。
  final Map<String, int> _unlockedThrough = <String, int>{};
  bool _unlocksLoaded = false;

  bool get isReady => AdConfig.enabled && _initialized;

  /// 冷启动时调用一次（见 `main.dart` 的 `_prepareRuntime`）。
  /// 插件的 init 没有完成回调：这里只发初始化指令，加载发生在
  /// 用户真正进入播放/阅读之后，原生 SDK 有足够时间完成启动。
  Future<void> init() async {
    if (_initialized || !AdConfig.enabled) return;
    if (!Platform.isAndroid) return;
    try {
      _plugin.initAd(AdConfig.appId, 1);
      _initialized = true;
      AppLog.d('ads', 'Huijing SDK init dispatched (demo app id)');
      AppLog.i(
        'ads',
        'config reward free=${AdConfig.rewardFreeEpisodes} '
        'batch=${AdConfig.rewardUnlockBatch}',
      );
    } catch (error, stack) {
      AppLog.e('ads', 'Huijing SDK init failed', error: error, stack: stack);
    }
    await _loadUnlocks();
  }

  /// 开屏广告：冷启动展示一次。加载失败、关闭或超时都直接放行，
  /// 绝不阻塞启动；原生 SDK 刚初始化时留 1 秒宽限再加载。
  Future<void> showSplash() async {
    if (!isReady) return;
    try {
      final completer = Completer<void>();
      void done() {
        if (!completer.isCompleted) completer.complete();
      }

      await Future<void>.delayed(const Duration(seconds: 1));
      _plugin.loadAndShowSplash(
        AdConfig.splashId,
        onSplashClosed: done,
        onSplashAdFailToLoad: (_, _, _) => done(),
      );
      await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: done,
      );
    } catch (error, stack) {
      AppLog.e('ads', 'splash failed', error: error, stack: stack);
    } finally {
      try {
        _plugin.destroySplash();
      } catch (_) {}
    }
  }

  String _unlockKey(String seriesKey, int episodeIndex) =>
      'fqapp_ads_unlock_${seriesKey}_$episodeIndex';

  String _unlockThroughKey(String seriesKey) =>
      'fqapp_ads_unlock_through_$seriesKey';

  Future<void> _loadUnlocks() async {
    if (_unlocksLoaded) return;
    _unlocksLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      const throughPrefix = 'fqapp_ads_unlock_through_';
      for (final key in prefs.getKeys()) {
        if (key.startsWith(throughPrefix)) {
          final through = prefs.getInt(key);
          if (through != null) {
            _unlockedThrough[key.substring(throughPrefix.length)] = through;
          }
        } else if (key.startsWith('fqapp_ads_unlock_')) {
          _unlocked.add(key);
        }
      }
    } catch (_) {
      // 读不到时按未解锁处理，激励流程会重新走一遍。
    }
  }

  /// 该集是否已经激励解锁（持久化，重启后仍有效）：单集解锁记录
  /// 或一批解锁覆盖到的集都算已解锁。
  Future<bool> isEpisodeUnlocked(String seriesKey, int episodeIndex) async {
    await _loadUnlocks();
    final single = _unlocked.contains(_unlockKey(seriesKey, episodeIndex));
    final through = _unlockedThrough[seriesKey];
    final result =
        single || (through != null && episodeIndex <= through);
    AppLog.i(
      'ads',
      'unlock check $seriesKey ep=$episodeIndex single=$single '
      'through=$through result=$result',
    );
    return result;
  }

  Future<void> _markUnlocked(String seriesKey, int episodeIndex) async {
    final key = _unlockKey(seriesKey, episodeIndex);
    _unlocked.add(key);
    final through = episodeIndex + AdConfig.rewardUnlockBatch - 1;
    final prev = _unlockedThrough[seriesKey];
    if (prev == null || through > prev) {
      _unlockedThrough[seriesKey] = through;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
      await prefs.setInt(
        _unlockThroughKey(seriesKey),
        _unlockedThrough[seriesKey]!,
      );
    } catch (_) {
      // 记不住也只影响下次进集时多看一次激励，不挡播放。
    }
    AppLog.i(
      'ads',
      'unlocked $seriesKey ep=$episodeIndex '
      'through=${_unlockedThrough[seriesKey]}',
    );
  }

  /// 章末/切集插屏：满足最短间隔才尝试展示，失败或超时直接放行。
  /// 调用方在展示完成（关闭/失败/超时）后才继续切集/切章。
  Future<void> maybeShowInterstitial() async {
    if (!isReady) return;
    if (_interstitialShowing) return;
    final now = DateTime.now();
    final last = _lastInterstitialShownAt;
    if (last != null &&
        now.difference(last) < AdConfig.interstitialMinInterval) {
      return;
    }
    _interstitialShowing = true;
    try {
      final completer = Completer<void>();
      void done() {
        if (!completer.isCompleted) completer.complete();
      }

      _plugin.loadInterstitial(
        AdConfig.interstitialId,
        onInterstitialAdLoadSuccess: (_) {
          _lastInterstitialShownAt = DateTime.now();
          _plugin.showInterstitial();
        },
        onInterstitialAdClosed: done,
        onInterstitialAdLoadError: (_, _, _) => done(),
        onInterstitialAdPlayError: (_, _, _) => done(),
      );
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: done,
      );
    } catch (error, stack) {
      AppLog.e('ads', 'interstitial failed', error: error, stack: stack);
    } finally {
      _interstitialShowing = false;
      try {
        _plugin.destroyInterstitial();
      } catch (_) {}
    }
  }

  /// 激励视频：拿到奖励回调才返回 [RewardOutcome.granted]。
  /// 展示前先加载，加载成功回调里才 show；超时按失败处理。
  Future<RewardOutcome> showRewardForUnlock({
    required String seriesKey,
    required int episodeIndex,
  }) async {
    if (!isReady) return RewardOutcome.failed;
    bool rewarded = false;
    final completer = Completer<RewardOutcome>();
    void done(RewardOutcome outcome) {
      if (!completer.isCompleted) completer.complete(outcome);
    }

    try {
      _plugin.loadReward(
        AdConfig.rewardId,
        'fqapp-user',
        <String, Object>{},
        onVideoAdLoadSuccess: (_) {
          _plugin.showReward(<String, Object>{'func_type': 1, 'key': '888'});
        },
        onVideoRewarded: (_) {
          rewarded = true;
        },
        onVideoAdClosed: () {
          done(rewarded ? RewardOutcome.granted : RewardOutcome.dismissed);
        },
        onVideoAdLoadError: (_, _, _) => done(RewardOutcome.failed),
        onVideoAdPlayError: (_, _, _) => done(RewardOutcome.failed),
      );
      final outcome = await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => RewardOutcome.failed,
      );
      if (outcome == RewardOutcome.granted) {
        await _markUnlocked(seriesKey, episodeIndex);
      }
      AppLog.i(
        'ads',
        'reward $seriesKey ep=$episodeIndex outcome=$outcome',
      );
      return outcome;
    } catch (error, stack) {
      AppLog.e('ads', 'reward failed', error: error, stack: stack);
      return RewardOutcome.failed;
    } finally {
      try {
        _plugin.destroyReward();
      } catch (_) {}
    }
  }
}
