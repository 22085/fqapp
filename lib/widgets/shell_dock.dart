import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../services/app_theme.dart';
import '../services/app_style_tokens.dart';
import '../services/frame_stats.dart';
import 'classic_shell_dock.dart';
import 'wenku/src/easy_glass.dart';
import 'wenku/wenku_ui.dart';

/// 主壳层底部导航：上游 Wenku8 `HomeShell` 的 `GlassDock` + `DockUnderlay`，
/// 入口换成 fqapp 的首页 / 短剧 / 书架 / 我的。
class ShellDock extends StatelessWidget {
  const ShellDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.overVideo,
    required this.staticMaterial,
    this.animating = false,
    this.showDrama = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 短剧推荐频道背后是全屏视频流：dock 按深色外观绘制。
  final bool overVideo;

  /// 背后每帧都在变（视频流）或是 OLED 纯黑画布时，不跑实时折射/模糊，
  /// 改用上游轻量模式的同色底板。
  final bool staticMaterial;

  final bool animating;
  final bool showDrama;

  int get _displayIndex =>
      !showDrama && selectedIndex > 0 ? selectedIndex - 1 : selectedIndex;

  void _selectDisplayIndex(int index) =>
      onSelected(!showDrama && index > 0 ? index + 1 : index);

  static const _items = [
    GlassDockItem(CupertinoIcons.house, '首页'),
    GlassDockItem(CupertinoIcons.play, '短剧', symbol: ArchiveSymbol.play),
    GlassDockItem(CupertinoIcons.book, '书架', symbol: ArchiveSymbol.shelf),
    GlassDockItem(CupertinoIcons.person_crop_circle, '我的'),
  ];

  static const _lightweight = PerformancePreferences(
    enabled: true,
    effects: {
      PerformanceEffect.motion,
      PerformanceEffect.animatedIcons,
      PerformanceEffect.shelf3d,
    },
  );

  @override
  Widget build(BuildContext context) {
    // Record the dock build time for debug frame diagnostics.
    // release 下 enabled 恒假，连 Stopwatch 都不创建。
    if (!FrameStats.enabled) return _buildShell(context);
    final watch = Stopwatch()..start();
    final result = _buildShell(context);
    FrameStats.mark(
      'dock build ${watch.elapsedMicroseconds ~/ 1000}ms '
      'anim=$animating static=$staticMaterial overVideo=$overVideo',
    );
    return result;
  }

  Widget _buildShell(BuildContext context) {
    if (AppStyleTokens.of(context).isClassic) {
      return ClassicShellDock(
        selectedIndex: _displayIndex,
        onSelected: _selectDisplayIndex,
        overVideo: overVideo,
        showDrama: showDrama,
      );
    }
    Widget dock = WenkuScope(
      entrance: false,
      performance: staticMaterial
          ? _lightweight
          : const PerformancePreferences(),
      child: Builder(builder: _buildDock),
    );
    if (overVideo && Theme.of(context).brightness != Brightness.dark) {
      dock = Theme(
        data: Theme.of(context).copyWith(brightness: Brightness.dark),
        child: dock,
      );
    }
    return dock;
  }

  Widget _buildDock(BuildContext context) {
    final media = MediaQuery.of(context);
    final eink = WenkuTheme.isEinkOf(context);
    final underlay =
        !staticMaterial &&
        !eink &&
        !media.highContrast &&
        PerformanceScope.of(context).edgeBlur;
    final blur = GlassAppearance.of(context).blur;
    return SizedBox(
      height: DockLayout.underlayExtentOf(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (underlay)
            Positioned.fill(
              child: IgnorePointer(
                key: const ValueKey('dock-underlay'),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final plateau = DockLayout.bottomPaddingOf(
                      context,
                      viewPadding: true,
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        EasyScrollEdge(
                          blur: blur,
                          plateau: plateau,
                          fromBottom: true,
                          child: const SizedBox.expand(),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(
                                  alpha: DockLayout.edgeShadeOpacity,
                                ),
                                Colors.black.withValues(
                                  alpha: DockLayout.edgeShadeOpacity,
                                ),
                                Colors.transparent,
                              ],
                              stops: [
                                0,
                                (plateau / constraints.maxHeight).clamp(
                                  0.0,
                                  1.0,
                                ),
                                1,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22 + media.padding.left,
                0,
                22 + media.padding.right,
                DockLayout.bottomPaddingOf(context),
              ),
              child: GlassDock(
                key: const ValueKey('liquid-dock'),
                selectedIndex: _displayIndex,
                reduceMotion: eink,
                onSelected: _selectDisplayIndex,
                onReselected: _selectDisplayIndex,
                items: [
                  for (final (index, item) in _items.indexed)
                    if (showDrama || index != 1) item,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// OLED 纯黑只在深色外观下生效；壳层据此决定是否改用静态底板。
bool shellDockStaticMaterial({required bool overVideo}) =>
    overVideo || oledActive();
