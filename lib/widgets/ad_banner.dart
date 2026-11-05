import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ad_config.dart';
import '../services/app_log.dart';

/// 各页面横幅广告（灰鲸横幅形态）。
///
/// 仅 Android 生效；其它平台或总开关关闭时渲染为空。
/// 加载失败不再永久隐藏：之前失败一次就整个会话都不再拉，
/// 冷启动时 SDK 还没初始化完、第一次拉不到就永远没横幅了。
/// 现在失败后退避重试（15s/30s/60s…，最多 5 次），重试时重建
/// AndroidView（新 channel + 新原生 BannerView）重新拉一次；
/// 失败期间不占位，拉到了才显示。成功一次就停掉重试。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.height = 50});

  final double height;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static int _channelSeq = 0;
  static const int _maxRetries = 5;
  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 60),
    Duration(seconds: 60),
  ];

  late String _channelName;
  MethodChannel? _channel;
  bool _visible = true;
  int _retries = 0;
  int _viewKey = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _setupChannel();
  }

  void _setupChannel() {
    _channelName = 'flutter_ads_plugin/banner_callback_${_channelSeq++}';
    _channel = MethodChannel(_channelName)
      ..setMethodCallHandler((call) async {
        if (call.method == 'onAdLoadSuccess') {
          _retryTimer?.cancel();
          _retries = 0;
        } else if (call.method == 'onAdLoadError') {
          AppLog.d('ads', 'banner error: ${call.arguments}');
          _scheduleRetry();
        }
      });
  }

  void _scheduleRetry() {
    if (_retries >= _maxRetries) {
      AppLog.d('ads', 'banner retry stopped after $_maxRetries tries');
      return;
    }
    final delay = _retryDelays[_retries];
    _retries++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _channel?.setMethodCallHandler(null);
      setState(() {
        _setupChannel();
        _viewKey++;
        _visible = true;
      });
    });
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || !AdConfig.enabled || !_visible) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AndroidView(
        key: ValueKey<int>(_viewKey),
        viewType: 'flutter_ads_plugin/bannerview',
        creationParams: <String, Object>{
          'codeId': AdConfig.bannerId,
          'channelName': _channelName,
          'width': width.toInt(),
          'height': widget.height.toInt(),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
