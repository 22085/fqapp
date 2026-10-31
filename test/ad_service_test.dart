import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/services/ad_config.dart';
import 'package:fqapp/services/ad_service.dart';

/// 广告层在测试宿主机（非 Android）上必须 fail-open：不抛异常，
// 激励按失败处理，插屏直接放行。
void main() {
  test('AdConfig uses demo ids and sane frequencies', () {
    expect(AdConfig.appId, '222700');
    expect(AdConfig.feedCardEvery, greaterThan(0));
    expect(AdConfig.rewardFreeEpisodes, 10);
    expect(AdConfig.novelInterstitialEveryChapters, 3);
  });

  test('AdService is a no-op off Android', () async {
    await AdService.instance.init();
    expect(AdService.instance.isReady, isFalse);
    await AdService.instance.maybeShowInterstitial();
    final outcome = await AdService.instance.showRewardForUnlock(
      seriesKey: 'test',
      episodeIndex: 11,
    );
    expect(outcome, RewardOutcome.failed);
    expect(
      await AdService.instance.isEpisodeUnlocked('test', 11),
      isFalse,
    );
  });
}
