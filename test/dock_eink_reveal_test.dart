// RootShell 集成守卫：墨水屏整层禁用底栏自动收起，并且切进墨水屏时把可能
// 已经收起的底栏零时长露出（500ms 平移在局部刷新屏上会留明显残影）。
//
// 这套接线在 331c58e0（PR #429 整合）里整段丢失过，随后本用例被改写成
// 「底栏常驻」守卫。现在恢复原契约，并用真实几何判断可见性：只看
// findsOneWidget 抓不到已经滑到屏外的底栏。
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

  // 空 items 会让首页停在加载态(无限动画),pumpAndSettle 永远等不到静帧;
  // 每条 feed 给几张卡片,既让壳层进入稳态也保证首页可滚动。
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

  testWidgets('eink disables auto-hide and reveals without a 500ms slide', (
    tester,
  ) async {
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
    expect(shellSlide, findsOneWidget);
    AnimatedSlide slideWidget() => tester.widget<AnimatedSlide>(
      find.descendant(of: shellSlide, matching: find.byType(AnimatedSlide)),
    );

    const surface = Rect.fromLTWH(0, 0, 400, 800);
    Rect dockRect() => tester.getRect(find.byType(ShellDock));
    void expectDockVisible(String when) {
      final rect = dockRect();
      expect(rect.height, greaterThan(0), reason: '$when:底栏必须有高度');
      expect(
        rect.intersect(surface).height,
        greaterThan(rect.height * 0.9),
        reason: '$when:底栏必须几乎整块落在可视区内',
      );
    }

    expectDockVisible('初始');

    // 正常模式：滚一把就把底栏收起来（自动隐藏确实生效）。
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(slideWidget().offset, const Offset(0, 1));

    // 切进墨水屏：第一帧就露出，且过渡时长为零（不跑 500ms 残影）。
    einkModeNotifier.value = true;
    await tester.pump();
    expect(
      slideWidget().offset,
      Offset.zero,
      reason: '进入墨水屏必须立刻露出（_onEinkModeChanged 的 reveal）',
    );
    expect(
      slideWidget().duration,
      Duration.zero,
      reason: '墨水屏下 reveal 过渡必须零时长',
    );
    expectDockVisible('eink 开');

    // 墨水屏下再滚：disabledProbe 整层短路，底栏不动。
    final resting = dockRect();
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(slideWidget().offset, Offset.zero);
    expect(dockRect().top, closeTo(resting.top, 0.5), reason: 'eink 下底栏不应移动');
    expectDockVisible('eink 滚动后');

    // 退出墨水屏：自动隐藏恢复。
    einkModeNotifier.value = false;
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(slideWidget().offset, const Offset(0, 1), reason: '退出墨水屏后应恢复滚动收起');

    expect(tester.takeException(), isNull);
    // _verifyInvariants 先于 tearDown 检查 debug 变量,必须在这里复位。
    debugDefaultTargetPlatformOverride = null;
  });
}
