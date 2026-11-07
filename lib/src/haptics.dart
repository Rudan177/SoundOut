import 'package:flutter/services.dart';

/// 全局点击触感。是否启用由设置里的开关决定，由 [AppModel] 同步到 [enabled]。
/// 关闭时所有调用都是空操作，界面代码不需要分支。
class AppHaptics {
  AppHaptics._();

  static bool enabled = false;

  /// 普通按钮按下的一下轻震：短、脆。
  static void tap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// 选中、切换一类的反馈，比 [tap] 更细一格。
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// 长按等需要更明确反馈的场景。
  static void strong() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
