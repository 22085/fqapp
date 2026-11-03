import 'dart:async';

import 'package:flutter/widgets.dart';

import 'ad_service.dart';

/// 全路由插屏观察者：每次推入新页面时尝试一次插屏。
///
/// 只对整页路由（PageRoute）生效，弹窗、对话框、底部弹窗
/// （PopupRoute）不触发；首个路由与启动后 10 秒内不触发
/// （开屏广告时段）。实际展示受 [AdService] 的 3 分钟冷却与
/// 30 秒超时保护，失败直接放行，不挡页面跳转。
class AdRouteObserver extends NavigatorObserver {
  AdRouteObserver() : _bornAt = DateTime.now();

  final DateTime _bornAt;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.isFirst) return;
    if (DateTime.now().difference(_bornAt) < const Duration(seconds: 10)) {
      return;
    }
    if (route is! PageRoute<dynamic> || route is PopupRoute<dynamic>) return;
    // 不等待：插屏展示或失败都不阻塞路由切换。
    unawaited(AdService.instance.maybeShowInterstitial());
  }
}
