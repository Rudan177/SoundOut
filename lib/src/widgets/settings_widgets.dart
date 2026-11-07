import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../glass.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'app_popup_menu.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footnote,
  });

  final String title;
  final List<Widget> children;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GlassPanel(
            radius: 20,
            opaqueColor: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: scheme.onSurface.withValues(alpha: 0.08),
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                footnote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.tap();
              onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () {
        AppHaptics.select();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: (next) {
                AppHaptics.select();
                onChanged(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 带锚点列表的取值行：右侧数值胶囊点击后，从胶囊位置展开玻璃列表。
class SettingsMenuRow<T> extends StatefulWidget {
  const SettingsMenuRow({
    super.key,
    required this.title,
    required this.value,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String value;
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  State<SettingsMenuRow<T>> createState() => _SettingsMenuRowState<T>();
}

class _SettingsMenuRowState<T> extends State<SettingsMenuRow<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _menuOpen = false;

  Future<void> _open() async {
    setState(() => _menuOpen = true);
    final value = await showAppPopupMenu<T>(
      context: context,
      anchorKey: _anchorKey,
      entries: [
        for (final (option, label) in widget.options)
          AppMenuEntry(
            value: option,
            label: label,
            checked: option == widget.selected,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);
    if (value == null || value == widget.selected) return;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: _open,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                opacity: _menuOpen ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Material(
                  key: _anchorKey,
                  color: scheme.onSurface.withValues(
                    alpha: scheme.brightness == Brightness.dark ? 0.10 : 0.06,
                  ),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _open,
                    customBorder: const StadiumBorder(),
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 9, 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              widget.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 玻璃分段控件：玻璃轨道里一枚跟随手指的透镜，点按或横向拖动都能切换，
/// 切换时给出细一格的触感反馈。
class SegmentedControl<T> extends StatefulWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 38,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  static const _inset = 3.0;
  static const _duration = Duration(milliseconds: 220);

  int? _dragIndex;
  double _pitch = 0;

  int get _selectedIndex {
    final index = widget.segments.indexWhere(
      (segment) => segment.$1 == widget.value,
    );
    return index < 0 ? 0 : index;
  }

  int _indexAt(double x) {
    if (_pitch <= 0) return 0;
    return ((x - _inset) / _pitch).floor().clamp(0, widget.segments.length - 1);
  }

  void _slideTo(double x) {
    if (widget.segments.isEmpty) return;
    final index = _indexAt(x);
    if (index == _dragIndex) return;
    setState(() => _dragIndex = index);
    if (index != _selectedIndex) AppHaptics.select();
  }

  void _commit() {
    final index = _dragIndex;
    setState(() => _dragIndex = null);
    if (index == null || index == _selectedIndex) return;
    widget.onChanged(widget.segments[index].$1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.segments.length;
    if (count == 0) return const SizedBox.shrink();
    final lensIndex = (_dragIndex ?? _selectedIndex).clamp(0, count - 1);
    final trackFill = context.isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    return LayoutBuilder(
      builder: (context, constraints) {
        _pitch = math.max(0.0, (constraints.maxWidth - _inset * 2) / count);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _slideTo(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              _slideTo(details.localPosition.dx),
          onHorizontalDragEnd: (_) => _commit(),
          onHorizontalDragCancel: () => setState(() => _dragIndex = null),
          child: GlassSurface(
            shape: AppShape.full,
            fallbackColor: trackFill,
            tint: trackFill,
            child: SizedBox(
              height: widget.height,
              child: Padding(
                padding: const EdgeInsets.all(_inset),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _duration,
                      curve: Curves.easeOutCubic,
                      left: lensIndex * _pitch,
                      top: 0,
                      bottom: 0,
                      width: _pitch,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: scheme.primary,
                          shape: AppShape.full,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (index, (_, label))
                            in widget.segments.indexed)
                          Expanded(
                            child: Semantics(
                              selected: index == lensIndex,
                              button: true,
                              child: Material(
                                type: MaterialType.transparency,
                                shape: AppShape.full,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  customBorder: AppShape.full,
                                  splashFactory: NoSplash.splashFactory,
                                  highlightColor: Colors.transparent,
                                  hoverColor: index == lensIndex
                                      ? Colors.transparent
                                      : scheme.onSurface.opacity10,
                                  onTap: () {
                                    if (index == _selectedIndex) return;
                                    AppHaptics.select();
                                    widget.onChanged(widget.segments[index].$1);
                                  },
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: _duration,
                                      style:
                                          Theme.of(context).textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: index == lensIndex
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: index == lensIndex
                                                    ? scheme.onPrimary
                                                    : scheme.onSurfaceVariant,
                                              ) ??
                                          const TextStyle(),
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
