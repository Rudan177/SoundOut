import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 圆角尺度：外层容器更大，行内元素更小。
abstract final class AppCorner {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double alert = 34;
  static const double full = 1000;

  /// 内嵌元素与容器的间距：容器圆角 = 内层圆角 + inset。
  static const double inset = 8;

  static const double item = md;
  static const double card = item + inset;
}

abstract final class AppRadius {
  static const BorderRadius xs = BorderRadius.all(
    Radius.circular(AppCorner.xs),
  );
  static const BorderRadius sm = BorderRadius.all(
    Radius.circular(AppCorner.sm),
  );
  static const BorderRadius md = BorderRadius.all(
    Radius.circular(AppCorner.md),
  );
  static const BorderRadius lg = BorderRadius.all(
    Radius.circular(AppCorner.lg),
  );
  static const BorderRadius xl = BorderRadius.all(
    Radius.circular(AppCorner.xl),
  );
  static const BorderRadius xxl = BorderRadius.all(
    Radius.circular(AppCorner.xxl),
  );
  static const BorderRadius full = BorderRadius.all(
    Radius.circular(AppCorner.full),
  );

  static BorderRadius all(double corner) => BorderRadius.circular(corner);
}

/// 超椭圆（squircle）形状。
abstract final class AppShape {
  static const RoundedSuperellipseBorder md = RoundedSuperellipseBorder(
    borderRadius: AppRadius.md,
  );
  static const RoundedSuperellipseBorder lg = RoundedSuperellipseBorder(
    borderRadius: AppRadius.lg,
  );
  static const RoundedSuperellipseBorder xl = RoundedSuperellipseBorder(
    borderRadius: AppRadius.xl,
  );
  static const RoundedSuperellipseBorder card = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppCorner.card)),
  );
  static const RoundedSuperellipseBorder full = RoundedSuperellipseBorder(
    borderRadius: AppRadius.full,
  );

  static RoundedSuperellipseBorder all(double corner) =>
      RoundedSuperellipseBorder(borderRadius: AppRadius.all(corner));
}

extension AppContextTokens on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

extension AppColorTokens on Color {
  Color get opacity10 => withValues(alpha: 0.10);
  Color get opacity30 => withValues(alpha: 0.30);
  Color get opacity38 => withValues(alpha: 0.38);
  Color get opacity60 => withValues(alpha: 0.60);
}

/// 以 [spring] 在 [seconds] 内求解，并把剩余量平滑收敛到 1。
class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {required this.seconds})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final double seconds;
  final SpringSimulation _simulation;

  late final double _residual = 1 - _simulation.x(seconds);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * seconds) + _residual * t;
}
