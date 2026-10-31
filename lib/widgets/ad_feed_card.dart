import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ad_config.dart';
import '../services/app_log.dart';

/// 短剧 feed 里的原生信息流广告卡（灰鲸模板 express 形态）。
///
/// 仅 Android 生效；其它平台渲染为空。广告加载失败时原生侧回调
/// onError，本卡片只记一条日志，不占位、不挡滑动——用户划走即过。
class AdFeedCard extends StatefulWidget {
  const AdFeedCard({super.key, this.height = 180});

  final double height;

  @override
  State<AdFeedCard> createState() => _AdFeedCardState();
}

class _AdFeedCardState extends State<AdFeedCard> {
  static int _channelSeq = 0;
  late final String _channelName;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _channelName =
        'flutter_ads_plugin/feedview_callback_${_channelSeq++}';
    _channel = MethodChannel(_channelName)
      ..setMethodCallHandler((call) async {
        if (call.method == 'onError' || call.method == 'onADError') {
          AppLog.d('ads', 'feed card error: ${call.arguments}');
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
    if (!Platform.isAndroid || !AdConfig.enabled) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: widget.height,
      child: AndroidView(
        viewType: 'flutter_ads_plugin/feedview',
        creationParams: <String, Object>{
          'codeId': AdConfig.feedId,
          'channelName': _channelName,
          'width': 360,
          'height': widget.height.toInt(),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
