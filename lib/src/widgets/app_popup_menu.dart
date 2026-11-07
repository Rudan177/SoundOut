// ignore_for_file: prefer_initializing_formals
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../glass.dart';
import '../haptics.dart';
import '../tokens.dart';

/// 菜单里的一项。视觉、间距和选中态对齐 FlClash：
/// 15/20 的标签、20 号图标、16 号勾选，条目圆角 16，外层卡片圆角 24 且内缩 8。
@immutable
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.danger = false,
    this.checked = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
  final bool danger;
  final bool checked;
}

const _cardInset = 8.0;
const _itemRadius = AppCorner.md;
const _cardRadius = _itemRadius + _cardInset;
const _itemIconSize = 20.0;
const _arrowSize = 16.0;
const _menuMinWidth = 160.0;
const _menuMaxWidth = 280.0;
const _menuMargin = 16.0;
const _anchorOverlap = 8.0;
const _defaultMaxVisibleItems = 7;
const _rowVerticalPadding = 12.0;
const _overlayDuration = Duration(milliseconds: 50);

const _pressedDark = Color(0x40CCCCCC);
const _pressedLight = Color(0x66BCBCBC);
const _focusDark = Color(0x1FFFFFFF);
const _focusLight = Color(0x1F000000);
const _hoverDark = Color(0x0AFFFFFF);
const _hoverLight = Color(0x0A000000);

final Curve _popupSpring = SpringCurve(
  SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 0.754),
  seconds: 0.36,
);

TextStyle _labelStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: 15, height: 20 / 15);

TextStyle _footnoteStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall!
        .copyWith(fontSize: 13, height: 18 / 13);

/// 在 [anchorRect] 旁打开菜单；未给锚点时锚定 [anchorKey] 或 [context] 对应控件。
Future<T?> showAppPopupMenu<T>({
  required BuildContext context,
  required List<AppMenuEntry<T>> entries,
  GlobalKey? anchorKey,
  Rect? anchorRect,
  double minWidth = _menuMinWidth,
  double maxWidth = _menuMaxWidth,
  int maxVisibleItems = _defaultMaxVisibleItems,
}) {
  AppHaptics.tap();
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay;
  Rect? anchor = anchorRect;
  if (anchor == null) {
    final target = anchorKey?.currentContext ?? context;
    final box = target.findRenderObject() as RenderBox?;
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && overlayBox != null) {
      anchor = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    }
  }
  return navigator.push<T>(
    _AppPopupRoute<T>(
      anchor: anchor,
      entries: entries,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxVisibleItems: maxVisibleItems,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _AppPopupRoute<T> extends PopupRoute<T> {
  _AppPopupRoute({
    required this.anchor,
    required this.entries,
    required this.minWidth,
    required this.maxWidth,
    required this.maxVisibleItems,
    required this.barrierLabel,
  });

  final Rect? anchor;
  final List<AppMenuEntry<T>> entries;
  final double minWidth;
  final double maxWidth;
  final int maxVisibleItems;
  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _AppPopupLayout(
      anchor: anchor,
      child: _AppPopupCard<T>(
        anchor: anchor,
        entries: entries,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxVisibleItems: maxVisibleItems,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _AppPopupLayout extends StatelessWidget {
  const _AppPopupLayout({required this.anchor, required this.child});

  final Rect? anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return CustomSingleChildLayout(
      delegate: _AppPopupLayoutDelegate(
        anchor: anchor,
        safeInsets: media.padding + media.viewInsets,
      ),
      child: child,
    );
  }
}

class _AppPopupLayoutDelegate extends SingleChildLayoutDelegate {
  _AppPopupLayoutDelegate({required this.anchor, required this.safeInsets});

  final Rect? anchor;
  final EdgeInsets safeInsets;

  EdgeInsets get _insets => safeInsets + const EdgeInsets.all(_menuMargin);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final insets = _insets;
    return BoxConstraints.loose(
      Size(
        math.max(0, constraints.maxWidth - insets.horizontal),
        math.max(0, constraints.maxHeight - insets.vertical),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = this.anchor;
    final insets = _insets;
    final maxX = size.width - insets.right - childSize.width;
    final maxY = size.height - insets.bottom - childSize.height;
    if (anchor == null) {
      return Offset(
        ((size.width - childSize.width) / 2)
            .clamp(insets.left, math.max(insets.left, maxX))
            .toDouble(),
        ((size.height - childSize.height) / 2)
            .clamp(insets.top, math.max(insets.top, maxY))
            .toDouble(),
      );
    }
    // 菜单贴着目标右上角展开，并压住目标 8 像素；空间不足时只做夹取。
    final x = (anchor.right - childSize.width)
        .clamp(insets.left, math.max(insets.left, maxX))
        .toDouble();
    final y = (anchor.top - _anchorOverlap)
        .clamp(insets.top, math.max(insets.top, maxY))
        .toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_AppPopupLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor || safeInsets != oldDelegate.safeInsets;
}

/// 菜单的锚点形变：从触发控件的中心长成卡片。
class _AppPopupMorph extends SingleChildRenderObjectWidget {
  const _AppPopupMorph({
    required this.anchor,
    required this.animation,
    required this.fill,
    required this.glass,
    required this.sigma,
    required this.saturation,
    required this.tintAlpha,
    required this.rimColor,
    required this.rimWidth,
    required this.rimShine,
    required this.shadows,
    required this.disableAnimations,
    super.child,
  });

  final Rect? anchor;
  final Animation<double> animation;
  final Color fill;
  final bool glass;
  final double sigma;
  final double saturation;
  final double tintAlpha;
  final Color? rimColor;
  final double rimWidth;
  final bool rimShine;
  final List<BoxShadow> shadows;
  final bool disableAnimations;

  @override
  _RenderAppPopupMorph createRenderObject(BuildContext context) {
    return _RenderAppPopupMorph(
      anchor: anchor,
      animation: animation,
      fill: fill,
      glass: glass,
      sigma: sigma,
      saturation: saturation,
      tintAlpha: tintAlpha,
      rimColor: rimColor,
      rimWidth: rimWidth,
      rimShine: rimShine,
      shadows: shadows,
      disableAnimations: disableAnimations,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAppPopupMorph renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..animation = animation
      ..fill = fill
      ..glass = glass
      ..sigma = sigma
      ..saturation = saturation
      ..tintAlpha = tintAlpha
      ..rimColor = rimColor
      ..rimWidth = rimWidth
      ..rimShine = rimShine
      ..shadows = shadows
      ..disableAnimations = disableAnimations;
  }
}

class _RenderAppPopupMorph extends RenderProxyBox {
  _RenderAppPopupMorph({
    required Rect? anchor,
    required Animation<double> animation,
    required Color fill,
    required bool glass,
    required double sigma,
    required double saturation,
    required double tintAlpha,
    required Color? rimColor,
    required double rimWidth,
    required bool rimShine,
    required List<BoxShadow> shadows,
    required bool disableAnimations,
  }) : _anchor = anchor,
       _animation = animation,
       _fill = fill,
       _glass = glass,
       _sigma = sigma,
       _saturation = saturation,
       _tintAlpha = tintAlpha,
       _rimColor = rimColor,
       _rimWidth = rimWidth,
       _rimShine = rimShine,
       _shadows = shadows,
       _disableAnimations = disableAnimations;

  Rect? _anchor;
  Rect? get anchor => _anchor;
  set anchor(Rect? value) {
    if (value == _anchor) {
      return;
    }
    _anchor = value;
    markNeedsPaint();
  }

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (value == _animation) {
      return;
    }
    if (attached) {
      _animation
        ..removeListener(markNeedsPaint)
        ..removeStatusListener(_handleStatus);
      value
        ..addListener(markNeedsPaint)
        ..addStatusListener(_handleStatus);
    }
    _animation = value;
    markNeedsPaint();
  }

  Color _fill;
  set fill(Color value) {
    if (value == _fill) {
      return;
    }
    _fill = value;
    markNeedsPaint();
  }

  bool _glass;
  set glass(bool value) {
    if (value == _glass) {
      return;
    }
    _glass = value;
    markNeedsPaint();
  }

  double _sigma;
  set sigma(double value) {
    if (value == _sigma) {
      return;
    }
    _sigma = value;
    markNeedsPaint();
  }

  double _saturation;
  set saturation(double value) {
    if (value == _saturation) {
      return;
    }
    _saturation = value;
    markNeedsPaint();
  }

  double _tintAlpha;
  set tintAlpha(double value) {
    if (value == _tintAlpha) {
      return;
    }
    _tintAlpha = value;
    markNeedsPaint();
  }

  Color? _rimColor;
  set rimColor(Color? value) {
    if (value == _rimColor) {
      return;
    }
    _rimColor = value;
    markNeedsPaint();
  }

  double _rimWidth;
  set rimWidth(double value) {
    if (value == _rimWidth) {
      return;
    }
    _rimWidth = value;
    markNeedsPaint();
  }

  bool _rimShine;
  set rimShine(bool value) {
    if (value == _rimShine) {
      return;
    }
    _rimShine = value;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> value) {
    if (listEquals(value, _shadows)) {
      return;
    }
    _shadows = value;
    markNeedsPaint();
  }

  bool _disableAnimations;
  set disableAnimations(bool value) {
    if (value == _disableAnimations) {
      return;
    }
    _disableAnimations = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  void _handleStatus(AnimationStatus status) => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation
      ..addListener(markNeedsPaint)
      ..addStatusListener(_handleStatus);
  }

  @override
  void detach() {
    _animation
      ..removeListener(markNeedsPaint)
      ..removeStatusListener(_handleStatus);
    super.detach();
  }

  double get _progress {
    if (_disableAnimations) {
      return 1;
    }
    final value = _animation.value.clamp(0.0, 1.0);
    if (_animation.status == AnimationStatus.reverse) {
      return Curves.easeInOutCubic.transform(value);
    }
    return _popupSpring.transform(value);
  }

  ImageFilter _glassFilter(double strength) {
    final blur = ImageFilter.blur(
      sigmaX: _sigma * strength,
      sigmaY: _sigma * strength,
    );
    final saturation = 1 + (_saturation - 1) * strength;
    if (saturation == 1) {
      return blur;
    }
    return ImageFilter.compose(
      outer: ColorFilter.matrix(GlassRecipe.saturationMatrix(saturation)),
      inner: blur,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.isEmpty) {
      return;
    }
    final bounds = Offset.zero & size;
    final progress = _progress.clamp(0.0, 1.02);
    final anchor = this.anchor;
    final anchorRect =
        (anchor ??
                Rect.fromCenter(center: bounds.center, width: 40, height: 40))
            .shift(-offset);
    // 直接拿触发控件这一层做放大：起始块就是它的外框，随后长成整张卡片。
    final startWidth = math.min(anchorRect.width, size.width);
    final startHeight = math.min(anchorRect.height, size.height);
    final platter = Rect.fromCenter(
      center: Offset.lerp(anchorRect.center, bounds.center, progress)!,
      width: math.max(0.0, startWidth + (size.width - startWidth) * progress),
      height: math.max(
        0.0,
        startHeight + (size.height - startHeight) * progress,
      ),
    );
    final squaring = Curves.easeOutCubic.transform(
      ((progress - 0.16) / 0.62).clamp(0.0, 1.0),
    );
    // 圆角从控件外框的胶囊半高，逐步收成菜单卡片的 24。
    final startRadius = math.min(startWidth, startHeight) / 2;
    final radius = math.max(
      0.0,
      math.min(
        platter.height / 2,
        startRadius + (_cardRadius - startRadius) * squaring,
      ),
    );
    final path = AppShape.all(radius).getOuterPath(platter);
    final settled =
        _disableAnimations ||
        (progress >= 1.0 && _animation.status != AnimationStatus.reverse);

    final strength = progress.clamp(0.0, 1.0);
    _paintShadows(context.canvas, offset, path, strength);

    final clipBounds = platter.expandToInclude(bounds);
    if (!_glass) {
      context.canvas.drawPath(
        path.shift(offset),
        Paint()..color = _fill.withValues(alpha: strength),
      );
    } else if (strength > 0.02) {
      context.pushClipPath(needsCompositing, offset, clipBounds, path, (
        context,
        offset,
      ) {
        context.pushLayer(
          BackdropFilterLayer(filter: _glassFilter(strength * strength)),
          (context, offset) {
            context.canvas.drawPath(
              path.shift(offset),
              Paint()..color = _fill.withValues(alpha: _tintAlpha * strength),
            );
          },
          offset,
        );
      });
    }

    final closing = _animation.status == AnimationStatus.reverse;
    final reveal = closing
        ? ((progress - 0.45) / 0.55).clamp(0.0, 1.0)
        : ((progress - 0.12) / 0.72).clamp(0.0, 1.0);
    if (reveal > 0) {
      final contentScale = size.width <= 0 ? 1.0 : platter.width / size.width;
      final contentMatrix =
          Matrix4.translationValues(platter.center.dx, platter.center.dy, 0)
            ..scaleByDouble(contentScale, contentScale, 1, 1)
            ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
      final blur = 2.5 * (1 - reveal);
      context.pushClipPath(needsCompositing, offset, clipBounds, path, (
        context,
        offset,
      ) {
        void paintChild(PaintingContext context, Offset offset) {
          if (settled) {
            context.paintChild(child, offset);
            return;
          }
          context.pushTransform(
            needsCompositing,
            offset,
            contentMatrix,
            (context, offset) => context.paintChild(child, offset),
          );
        }

        void paintBlurred(PaintingContext context, Offset offset) {
          if (settled || blur <= 0.05) {
            paintChild(context, offset);
            return;
          }
          context.pushLayer(
            ImageFilterLayer(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            ),
            paintChild,
            offset,
          );
        }

        if (settled || reveal >= 1) {
          paintBlurred(context, offset);
          return;
        }
        context.pushOpacity(
          offset,
          (reveal * 255).round().clamp(0, 255),
          paintBlurred,
        );
      });
    }

    if (_glass) {
      _paintRim(context.canvas, offset, platter, radius, strength);
    }
  }

  /// 发丝边：左右两侧重、上下中间轻，深色模式再叠一层很淡的顶部高光。
  void _paintRim(
    Canvas canvas,
    Offset offset,
    Rect platter,
    double radius,
    double strength,
  ) {
    final color = _rimColor;
    if (color == null || strength <= 0 || platter.isEmpty) {
      return;
    }
    final rect = platter.shift(offset);
    final across = math.min(radius / math.max(rect.width, 1), 0.4);
    final side = color.a * strength;
    Color dark(double alpha) => color.withValues(alpha: alpha);
    final path = AppShape.all(radius).getOuterPath(rect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rimWidth
        ..shader = LinearGradient(
          colors: [
            dark(side),
            dark(side * 0.55),
            dark(side * 0.28),
            dark(side * 0.28),
            dark(side * 0.55),
            dark(side),
          ],
          stops: [0, across / 4, across, 1 - across, 1 - across / 4, 1],
        ).createShader(rect),
    );
    if (_rimShine) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _rimWidth
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.16 * strength),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  void _paintShadows(Canvas canvas, Offset offset, Path path, double strength) {
    if (strength <= 0 || _shadows.isEmpty) {
      return;
    }
    final local = path.shift(offset);
    final reach =
        _shadows.fold<double>(
          0,
          (reach, shadow) =>
              math.max(reach, shadow.blurSigma * 3 + shadow.offset.distance),
        ) +
        8;
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(local.getBounds().inflate(reach))
      ..addPath(local, Offset.zero);
    canvas.save();
    canvas.clipPath(clip);
    for (final shadow in _shadows) {
      final paint = shadow.toPaint()
        ..color = shadow.color.withValues(alpha: shadow.color.a * strength);
      canvas.drawPath(local.shift(shadow.offset), paint);
    }
    canvas.restore();
  }
}

class _AppPopupCard<T> extends StatefulWidget {
  const _AppPopupCard({
    required this.anchor,
    required this.entries,
    required this.minWidth,
    required this.maxWidth,
    required this.maxVisibleItems,
  });

  final Rect? anchor;
  final List<AppMenuEntry<T>> entries;
  final double minWidth;
  final double maxWidth;
  final int maxVisibleItems;

  @override
  State<_AppPopupCard<T>> createState() => _AppPopupCardState<T>();
}

class _AppPopupCardState<T> extends State<_AppPopupCard<T>> {
  final _scroll = ScrollController();
  final _checkedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChecked());
  }

  void _revealChecked() {
    final checked = _checkedKey.currentContext;
    if (checked == null || !mounted) {
      return;
    }
    final renderObject = checked.findRenderObject();
    if (renderObject == null || !_scroll.hasClients) {
      return;
    }
    final visible = widget.maxVisibleItems;
    final alignment = visible <= 1 ? 0.0 : (visible ~/ 2) / (visible - 0.5);
    _scroll.position.ensureVisible(
      renderObject,
      alignment: alignment,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animation = ModalRoute.of(context)?.animation;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding + media.viewInsets;
    final width = _menuWidth(context);
    final rowExtent =
        _rowVerticalPadding * 2 +
        MediaQuery.textScalerOf(context).scale(_footnoteStyle(context).height!);
    final maxHeight = math.max(
      0.0,
      math.min(
        screen.height - safe.vertical - _menuMargin * 2,
        _cardInset * 2 + (widget.maxVisibleItems + 0.5) * rowExtent,
      ),
    );
    final fill = context.isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final checkedIndex = widget.entries.indexWhere((entry) => entry.checked);
    final rows = <Widget>[];
    for (var i = 0; i < widget.entries.length; i++) {
      rows.add(
        _MenuRow<T>(
          key: i == checkedIndex ? _checkedKey : null,
          entry: widget.entries[i],
        ),
      );
    }

    final recipe = GlassRecipe.of(context);
    final rimColor = Colors.black.withValues(
      alpha: context.isDark ? 0.30 : 0.16,
    );
    // 菜单比普通玻璃面板更实一点，才压得住下面滚动的列表；但仍跟随用户
    // 选择的玻璃强度，强档依旧能看见背后的颜色。
    final tintAlpha = context.isDark
        ? math.min(0.66, recipe.tintAlpha + 0.32)
        : math.min(0.62, recipe.tintAlpha + 0.28);
    final content = Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(_cardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: rows,
              ),
            ),
          ),
        ),
      ),
    );

    final card = _AppPopupMorph(
      anchor: widget.anchor,
      animation: animation ?? const AlwaysStoppedAnimation<double>(1),
      fill: fill,
      glass: GlassScope.of(context),
      sigma: recipe.sigma,
      saturation: recipe.saturation,
      tintAlpha: tintAlpha,
      rimColor: rimColor,
      rimWidth: 0.8,
      rimShine: context.isDark,
      shadows: [
        BoxShadow(
          color: scheme.shadow.withValues(
            alpha: 0.118 * (context.isDark ? 1.5 : 1.0),
          ),
          blurRadius: 29,
          offset: const Offset(0, 8),
        ),
      ],
      disableAnimations: MediaQuery.disableAnimationsOf(context),
      child: SizedBox(width: width, child: content),
    );

    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
          },
          child: card,
        ),
      ),
    );
  }

  double _menuWidth(BuildContext context) {
    final labelStyle = _labelStyle(context);
    final subtitleStyle = _footnoteStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    double widest = 0;
    for (final entry in widget.entries) {
      final hasArrow = entry.checked;
      final hasIcon = entry.icon != null;
      final padding = (hasArrow ? 20.0 : 24.0) + (hasIcon ? 32.0 : 0.0);
      double line(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: textDirection,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        return painter.width;
      }

      widest = math.max(widest, padding + line(entry.label, labelStyle));
      if (entry.subtitle case final subtitle?) {
        widest = math.max(widest, padding + line(subtitle, subtitleStyle));
      }
    }
    final media = MediaQuery.of(context);
    final room = math.max(
      0.0,
      media.size.width -
          (media.padding + media.viewInsets).horizontal -
          _menuMargin * 2,
    );
    return widest
        .clamp(math.min(widget.minWidth, room), math.min(widget.maxWidth, room))
        .toDouble();
  }
}

class _MenuRow<T> extends StatefulWidget {
  const _MenuRow({super.key, required this.entry});

  final AppMenuEntry<T> entry;

  @override
  State<_MenuRow<T>> createState() => _MenuRowState<T>();
}

class _MenuRowState<T> extends State<_MenuRow<T>> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  AppMenuEntry<T> get entry => widget.entry;

  bool get _enabled => entry.enabled;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        _activate();
        return null;
      },
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) {
        _activate();
        return null;
      },
    ),
  };

  void _activate() {
    if (!_enabled) {
      return;
    }
    AppHaptics.tap();
    Navigator.of(context).pop(entry.value);
  }

  Color? _overlayColor(ColorScheme scheme) {
    if (!_enabled) {
      return null;
    }
    final dark = scheme.brightness == Brightness.dark;
    if (_pressed) {
      return dark ? _pressedDark : _pressedLight;
    }
    if (_focused) {
      return dark ? _focusDark : _focusLight;
    }
    if (_hovered) {
      return entry.danger
          ? scheme.error.opacity10
          : (dark ? _hoverDark : _hoverLight);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = _enabled;
    final color = entry.danger ? scheme.error : scheme.onSurface;
    final foreground = enabled ? color : color.opacity30;
    final showCheck = entry.checked;
    final padding = showCheck
        ? const EdgeInsets.only(
            left: 12,
            top: _rowVerticalPadding,
            bottom: _rowVerticalPadding,
            right: 8,
          )
        : const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: _rowVerticalPadding,
          );

    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (entry.icon case final icon?) ...[
            Icon(icon, size: _itemIconSize, color: foreground),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(context).copyWith(color: foreground),
                ),
                if (entry.subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _footnoteStyle(context).copyWith(
                      color: enabled
                          ? scheme.onSurfaceVariant
                          : scheme.onSurfaceVariant.opacity30,
                    ),
                  ),
              ],
            ),
          ),
          if (showCheck) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_rounded, size: _arrowSize, color: foreground),
          ],
        ],
      ),
    );

    final row = FocusableActionDetector(
      actions: _actions,
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (hovered) {
        if (hovered != _hovered) {
          setState(() => _hovered = hovered);
        }
      },
      onShowFocusHighlight: (focused) {
        if (focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? _activate : null,
        child: AnimatedContainer(
          duration: _overlayDuration,
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            color: _overlayColor(scheme) ?? Colors.transparent,
            shape: AppShape.all(_itemRadius),
          ),
          child: content,
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      checked: entry.checked,
      onTap: enabled ? _activate : null,
      child: row,
    );
  }
}
