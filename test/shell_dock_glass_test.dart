import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fqapp/services/app_theme.dart';
import 'package:fqapp/services/app_theme_style.dart';
import 'package:fqapp/widgets/shell_dock.dart';
import 'package:fqapp/widgets/wenku/glass_dock.dart';
import 'package:fqapp/widgets/wenku/src/easy_glass.dart';

void main() {
  setUp(() {
    einkModeNotifier.value = false;
    oledModeNotifier.value = false;
  });
  tearDown(() {
    einkModeNotifier.value = false;
    oledModeNotifier.value = false;
  });

  Widget app(ValueNotifier<bool> animating) => MaterialApp(
    theme: AppTheme.createTheme(Brightness.light, style: AppThemeStyle.archive),
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: animating,
        builder: (context, value, _) => ShellDock(
          selectedIndex: 0,
          onSelected: (_) {},
          overVideo: false,
          staticMaterial: false,
          animating: value,
        ),
      ),
    ),
  );

  for (final style in AppThemeStyle.values) {
    testWidgets(
      'hidden drama keeps the library and profile destinations in $style',
      (tester) async {
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.createTheme(Brightness.light, style: style),
            home: Scaffold(
              bottomNavigationBar: ShellDock(
                selectedIndex: 2,
                onSelected: (index) => selected = index,
                overVideo: false,
                staticMaterial: false,
                showDrama: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('短剧'), findsNothing);
        await tester.tap(find.text('书架'));
        expect(selected, 2);
        await tester.tap(find.text('我的'));
        expect(selected, 3);
      },
    );
  }

  testWidgets('classic dock keeps its backdrop filter during page motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.classic,
        ),
        home: Scaffold(
          bottomNavigationBar: ShellDock(
            selectedIndex: 2,
            onSelected: (_) {},
            overVideo: false,
            staticMaterial: false,
            animating: true,
            showDrama: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('档案 dock 切页期间保持折射和边缘模糊', (tester) async {
    final animating = ValueNotifier<bool>(false);
    addTearDown(animating.dispose);
    await tester.pumpWidget(app(animating));
    await tester.pumpAndSettle();

    // 静止态：underlay 边缘模糊与胶囊实时折射都在。
    expect(find.byKey(const ValueKey('dock-underlay')), findsOneWidget);
    expect(find.byType(EasyGlassSurface), findsOneWidget);
    final stateBefore = tester.state(find.byType(GlassDock));

    animating.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsOneWidget);
    expect(find.byType(EasyGlassSurface), findsOneWidget);
    // 预设切换只换材质分支，不能把 dock 的 State 换掉（选中/拖动状态
    // 会在动画结束后丢失）。
    expect(tester.state(find.byType(GlassDock)), same(stateBefore));

    // The same dock stays mounted after the transition.
    animating.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsOneWidget);
    expect(find.byType(EasyGlassSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('档案 dock 动画期间仍可点按切换，staticMaterial 行为不变', (tester) async {
    final animating = ValueNotifier<bool>(true);
    addTearDown(animating.dispose);
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.archive,
        ),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: animating,
            builder: (context, value, _) => ShellDock(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
              overVideo: false,
              staticMaterial: false,
              animating: value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigation stays interactive during the transition.
    await tester.tap(
      find.descendant(of: find.byType(GlassDock), matching: find.text('书架')),
    );
    await tester.pumpAndSettle();
    expect(selected, 2);

    // staticMaterial 单独成立时（视频流 / OLED）同样没有 underlay，
    // 与 animating 无关——既有契约不被本次改动破坏。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(
          Brightness.light,
          style: AppThemeStyle.archive,
        ),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: ShellDock(
            selectedIndex: 0,
            onSelected: (_) {},
            overVideo: false,
            staticMaterial: true,
            animating: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-underlay')), findsNothing);
    expect(find.byType(GlassDock), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
