// RootShell 集成守卫：底栏随滚动方向收起/露出，且子路由 pop 回壳层时自动
// 露出。
//
// 这套接线在 331c58e0（PR #429 整合）里整段丢失过，widget 与单测都还在、
// 三条壳层用例却被改写成「底栏常驻」守卫。现在恢复原契约：
// - didChangeDependencies 必须把 DockRouteReveal 挂到当前路由的
//   secondaryAnimation（dock_auto_hide_test 的 DockRouteReveal 组用的是裸
//   MaterialApp + 手动 attach，覆盖不到壳层里「attach(context) 这一行」）；
// - body 冒泡的竖直拖动必须真的把 dock 收起来（滑出可视区），而不是只在
//   语义层改个状态。
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fqapp/main.dart';
import 'package:fqapp/models/homepage_page.dart';
import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/pages/drama_page.dart';
import 'package:fqapp/pages/home_provider.dart';
import 'package:fqapp/services/app_theme.dart';
import 'package:fqapp/widgets/dock_auto_hide.dart';
import 'package:fqapp/widgets/shell_dock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MediaItem book(String id) => MediaItem(
    id: id,
    title: '$id 作品',
    cover: '',
    author: '作者',
    badge: '',
    ep: '',
    kind: 'book',
  );

  // 空 items 会让首页停在加载态(无限动画),pumpAndSettle 永远等不到静帧。
  HomeNotifier notifier({int initialTabIndex = 0}) => HomeNotifier(
    initialTabIndex: initialTabIndex,
    homepageLoader:
        ({int tabType = 2, int offset = 0, String? sessionId}) async {
          return HomepagePage(
            items: [for (var i = 0; i < 6; i++) book('$tabType-$i')],
            nextOffset: null,
            sessionId: null,
          );
        },
    searchLoader: (query, {int page = 1}) async => const [],
  );

  testWidgets('shell dock hides on scroll and a route pop brings it back', (
    tester,
  ) async {
    // 桌面平台会让 disabledProbe 短路，拖拽不再收起 dock。
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => einkModeNotifier.value = false);
    addTearDown(() => dramaLightPageNotifier.value = false);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(() => notifier()),
          dramaProvider.overrideWith(
            () => notifier(initialTabIndex: dramaTabIndex),
          ),
        ],
        child: MaterialApp(home: RootShell(backendStarter: () async {})),
      ),
    );
    await tester.pumpAndSettle();

    final shellSlide = find.ancestor(
      of: find.byType(ShellDock),
      matching: find.byType(DockAutoHideSlide),
    );
    expect(shellSlide, findsOneWidget, reason: '壳层必须把底栏包进 DockAutoHideSlide');
    AnimatedSlide slideWidget() => tester.widget<AnimatedSlide>(
      find.descendant(of: shellSlide, matching: find.byType(AnimatedSlide)),
    );

    const surface = Rect.fromLTWH(0, 0, 400, 800);
    Rect dockRect() => tester.getRect(find.byType(ShellDock));

    expect(slideWidget().offset, Offset.zero);
    final resting = dockRect();

    // 首页 feed 上滚一把：dock 收起（滑到可视区外），这是「多露一截内容」
    // 的实际来源，不只是一个状态位。
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(slideWidget().offset, const Offset(0, 1));
    expect(
      dockRect().intersect(surface).height,
      lessThan(resting.height * 0.1),
      reason: '收起后底栏必须基本离开可视区',
    );

    // 压一个覆盖路由再 pop 回壳层：pop 完成时 dock 必须自己回来，
    // 否则用户回到入口页会发现底栏消失了。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('覆盖页')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(
      slideWidget().offset,
      Offset.zero,
      reason: '子路由 pop 回 RootShell 时 dock 必须自动露出（DockRouteReveal 接线）',
    );
    expect(
      dockRect().intersect(surface).height,
      greaterThan(resting.height * 0.9),
      reason: '露出后底栏必须几乎整块回到可视区',
    );
    expect(tester.takeException(), isNull);
    // _verifyInvariants 先于 tearDown 检查 debug 变量，必须在这里复位。
    debugDefaultTargetPlatformOverride = null;
  });
}
