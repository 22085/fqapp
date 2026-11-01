import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ad_config.dart';
import '../services/app_log.dart';

/// 各页面底部横幅广告（灰鲸横幅形态）。
///
/// 仅 Android 生效；其它平台或总开关关闭时渲染为空。加载失败时
/// 原生侧回调 onAdLoadError，本组件自动隐藏，不留空白条、不挡内容。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.height = 50});

  final double height;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static int _channelSeq = 0;
  late final String _channelName;
  MethodChannel? _channel;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _channelName = 'flutter_ads_plugin/banner_callback_${_channelSeq++}';
    _channel = MethodChannel(_channelName)
      ..setMethodCallHandler((call) async {
        if (call.method == 'onAdLoadError') {
          AppLog.d('ads', 'banner error: ${call.arguments}');
          if (mounted) setState(() => _visible = false);
        }
      });
  }

  @override
  void dispose() {
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
