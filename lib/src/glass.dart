import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 液态玻璃开关：由应用根部注入，悬浮面板与卡片据此决定是否使用玻璃层。
class GlassScope extends InheritedWidget {
  const GlassScope({
    super.key,
    required this.enabled,
    this.strength = 0.5,
    required super.child,
  });

  final bool enabled;
  final double strength;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.enabled ??
      false;

  static double strengthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.strength ?? 0.5;

  static double sigmaOf(BuildContext context) => GlassRecipe.of(context).sigma;

  @override
  bool updateShouldNotify(GlassScope oldWidget) =>
      oldWidget.enabled != enabled || oldWidget.strength != strength;
}

/// 玻璃强度 0 / 0.5 / 1 对应三档配方：
/// - 弱：普通模糊，能看清背后轮廓但没有玻璃质感；
/// - 中：液态玻璃，冷调半透明 + 左上高光 + 内圈反光边；
/// - 强：几乎完全透明，只留极淡的染色和一缕边缘反光。
class GlassRecipe {
  const GlassRecipe({
    required this.sigma,
    required this.tintAlpha,
    required this.borderAlpha,
    required this.highlightAlpha,
    required this.saturation,
  });

  final double sigma;
  final double tintAlpha;
  final double borderAlpha;
  final double highlightAlpha;

  /// 模糊之后稍微提饱和，玻璃后面的颜色才像液态玻璃一样透出来。
  final double saturation;

  static const weak = GlassRecipe(
    sigma: 18,
    tintAlpha: 0.66,
    borderAlpha: 0.14,
    highlightAlpha: 0,
    saturation: 1,
  );

  static const medium = GlassRecipe(
    sigma: 22,
    tintAlpha: 0.24,
    borderAlpha: 0.28,
    highlightAlpha: 0.18,
    saturation: 1.5,
  );

  static const strong = GlassRecipe(
    sigma: 6,
    tintAlpha: 0.035,
    borderAlpha: 0.12,
    highlightAlpha: 0.05,
    saturation: 1.35,
  );

  static GlassRecipe of(BuildContext context) {
    final strength = GlassScope.strengthOf(context).clamp(0.0, 1.0);
    return strength <= 0.5
        ? _between(weak, medium, strength / 0.5)
        : _between(medium, strong, (strength - 0.5) / 0.5);
  }

  static GlassRecipe _between(GlassRecipe a, GlassRecipe b, double t) =>
      GlassRecipe(
        sigma: a.sigma + (b.sigma - a.sigma) * t,
        tintAlpha: a.tintAlpha + (b.tintAlpha - a.tintAlpha) * t,
        borderAlpha: a.borderAlpha + (b.borderAlpha - a.borderAlpha) * t,
        highlightAlpha:
            a.highlightAlpha + (b.highlightAlpha - a.highlightAlpha) * t,
        saturation: a.saturation + (b.saturation - a.saturation) * t,
      );

  /// 饱和度矩阵；1 为原色，>1 提饱和。
  static List<double> saturationMatrix(double s) => _saturationMatrix(s);

  static List<double> _saturationMatrix(double s) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final inv = 1 - s;
    return [
      lumR * inv + s,
      lumG * inv,
      lumB * inv,
      0,
      0,
      lumR * inv,
      lumG * inv + s,
      lumB * inv,
      0,
      0,
      lumR * inv,
      lumG * inv,
      lumB * inv + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// 从左上到右下的高光，模拟玻璃边缘的受光。
  LinearGradient get highlight => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: highlightAlpha),
      Colors.white.withValues(alpha: 0),
      Colors.white.withValues(alpha: highlightAlpha * 0.4),
    ],
    stops: const [0, 0.5, 1],
  );
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// 一块完整的液态玻璃：背景模糊 + 染色 + 高光 + 反光边，外加外阴影。
/// 关闭液态玻璃时退化成 [fallbackColor] 的实心表面，调用方不需要分支。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.shape,
    required this.fallbackColor,
    required this.child,
    this.tint,
    this.shadows,
    this.sigmaBoost = 0,
    this.glass = true,
    this.border = true,
  });

  final OutlinedBorder shape;
  final Color fallbackColor;
  final Color? tint;
  final List<BoxShadow>? shadows;
  final double sigmaBoost;

  /// 需要保持不透明的面板可以关掉玻璃层，即使全局开着液态玻璃。
  final bool glass;

  /// 贴着窗口边缘的表面不要外框，只保留玻璃的模糊与染色。
  final bool border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!glass || !GlassScope.of(context)) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          color: fallbackColor,
          shape: shape,
          shadows: shadows,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final recipe = GlassRecipe.of(context);
    final sigma = recipe.sigma + sigmaBoost;
    final blur = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    final filter = recipe.saturation == 1
        ? blur
        : ImageFilter.compose(
            outer: ColorFilter.matrix(
              GlassRecipe._saturationMatrix(recipe.saturation),
            ),
            inner: blur,
          );
    // 深色纸面上用白光勾边；浅色纸面改用很淡的深色发丝边。
    final borderAlpha = (recipe.borderAlpha * (_isDark(context) ? 1.0 : 0.62))
        .clamp(0.0, 1.0)
        .toDouble();
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: filter,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: (tint ?? scheme.surfaceContainerLowest).withValues(
                      alpha: recipe.tintAlpha,
                    ),
                    shape: shape,
                  ),
                ),
              ),
              if (recipe.highlightAlpha > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: shape,
                        gradient: recipe.highlight,
                      ),
                    ),
                  ),
                ),
              if (border)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: shape.copyWith(
                          side: BorderSide(
                            color: (_isDark(context) ? Colors.white : Colors.black)
                                .withValues(alpha: borderAlpha),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Material(type: MaterialType.transparency, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃面板；关闭时退化成普通的不透明表面。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.opaqueColor,
    this.tint,
    this.shadows,
  });

  final Widget child;
  final double radius;
  final Color? opaqueColor;
  final Color? tint;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final fallback = opaqueColor ??
        (_isDark(context) ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest);
    return GlassSurface(
      shape: shape,
      fallbackColor: fallback,
      tint: tint,
      shadows: shadows,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// 全应用玻璃底：开启玻璃时铺一层低彩度渐变与柔光团，
/// 让上层玻璃有颜色可以透出来；关闭时退回普通纯色页面。
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!GlassScope.of(context)) {
      return ColoredBox(color: scheme.surface, child: child);
    }
    final dark = _isDark(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF0B0E0B), Color(0xFF14251A), Color(0xFF1D2B22)]
                  : const [Color(0xFFF8F7F1), Color(0xFFEDF3E8), Color(0xFFDCEADF)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -80,
                top: -60,
                child: _Glow(
                  size: 280,
                  color: brandGreen.withValues(alpha: dark ? 0.22 : 0.16),
                ),
              ),
              Positioned(
                right: -70,
                bottom: 40,
                child: _Glow(
                  size: 260,
                  color: brandLime.withValues(alpha: dark ? 0.10 : 0.30),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
