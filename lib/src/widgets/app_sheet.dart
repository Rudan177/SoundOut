import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.78,
}) {
  final scheme = Theme.of(context).colorScheme;
  final theme = Theme.of(context);
  const radius = BorderRadius.vertical(top: Radius.circular(28));
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: scheme.scrim.withValues(alpha: 0.28),
    builder: (context) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
            ),
            decoration: BoxDecoration(
              color:
                  (scheme.brightness == Brightness.dark
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainerLowest)
                      .withValues(alpha: 0.9),
              borderRadius: radius,
              border: Border(
                top: BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: scheme.onSurface.withValues(alpha: 0.08),
                  ),
                  Flexible(child: builder(context)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
