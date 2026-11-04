import 'package:flutter/foundation.dart';

/// 全局底部横幅的可见性：播放 / 阅读页在栈内时隐藏横幅，不占画面。
///
/// 引用计数：多个播放 / 阅读页叠加时，全部退出后才恢复显示；
/// 每个页面在 initState 里 hide、dispose 里 show，成对调用。
class AdBannerVisibility {
  AdBannerVisibility._();

  static final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  static int _hiddenCount = 0;

  static void hide() {
    _hiddenCount++;
    if (_hiddenCount == 1) visible.value = false;
  }

  static void show() {
    if (_hiddenCount > 0) _hiddenCount--;
    if (_hiddenCount == 0) visible.value = true;
  }
}
