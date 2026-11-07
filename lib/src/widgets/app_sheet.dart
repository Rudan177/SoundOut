import 'package:flutter/material.dart';

import '../glass.dart';
import '../haptics.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.78,
}) {
  final scheme = Theme.of(context).colorScheme;
  final theme = Theme.of(context);
  const radius = BorderRadius.vertical(top: Radius.circular(28));
  final dark = scheme.brightness == Brightness.dark;
  final fallback = dark
      ? scheme.surfaceContainerHigh
      : scheme.surfaceContainerLowest;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: scheme.scrim.withValues(alpha: 0.28),
    builder: (context) {
      return GlassSurface(
        shape: const RoundedRectangleBorder(borderRadius: radius),
        fallbackColor: fallback,
        tint: fallback,
        sigmaBoost: 4,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
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
                        onPressed: () {
                          AppHaptics.tap();
                          Navigator.of(context).pop();
                        },
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
      );
    },
  );
}
