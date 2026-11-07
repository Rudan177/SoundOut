import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.danger = false,
    this.checked = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool danger;
  final bool checked;
}

Future<T?> showAppPopupMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AppMenuEntry<T>> entries,
  double width = 208,
}) {
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  Rect? anchor;
  if (anchorBox != null && anchorBox.hasSize && overlayBox != null) {
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    anchor = topLeft & anchorBox.size;
  }
  HapticFeedback.selectionClick();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final media = MediaQuery.of(context);
      final height = entries.length * 46 + 16;
      final rect = anchor;
      final safe = media.padding;
      var left = media.size.width - width - 16;
      var top = media.size.height - height - safe.bottom - 16;
      if (rect != null) {
        left = math.max(
          12,
          math.min(rect.right - width, media.size.width - width - 12),
        );
        final below = rect.bottom + 4;
        final above = rect.top - height - 4;
        top = below + height <= media.size.height - safe.bottom - 12
            ? below
            : math.max(safe.top + 12, above);
      }
      final floating = scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: Tween<double>(begin: 0.94, end: 1).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: floating,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(
                          alpha: scheme.brightness == Brightness.dark
                              ? 0.32
                              : 0.14,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in entries)
                            _MenuRow<T>(
                              entry: entry,
                              onTap: entry.enabled
                                  ? () => Navigator.of(context).pop(entry.value)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry, required this.onTap});

  final AppMenuEntry<T> entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = !entry.enabled
        ? scheme.onSurface.withValues(alpha: 0.3)
        : entry.danger
        ? scheme.error
        : scheme.onSurface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (entry.icon != null) ...[
                  Icon(entry.icon, size: 18, color: foreground),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (entry.checked) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, size: 17, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
