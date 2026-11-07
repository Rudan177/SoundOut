import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

const brandGreen = Color(0xFF2F6B4F);
const brandInk = Color(0xFF173B2C);
const brandLime = Color(0xFFB7E36F);

SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
      .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      );
}

ThemeData buildAppTheme(Brightness brightness, {bool glass = false}) {
  final isDark = brightness == Brightness.dark;
  final seed = ColorScheme.fromSeed(
    seedColor: brandGreen,
    brightness: brightness,
  );
  final scheme = seed.copyWith(
    primary: isDark ? const Color(0xFF9FD3AE) : const Color(0xFF2F6B4F),
    onPrimary: isDark ? const Color(0xFF0B2B18) : Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF204C32)
        : const Color(0xFFCDEBD8),
    onPrimaryContainer: isDark
        ? const Color(0xFFC7EBD2)
        : const Color(0xFF0C2C1B),
    surface: isDark ? const Color(0xFF101410) : const Color(0xFFF8F7F1),
    onSurface: isDark ? const Color(0xFFE5E9E1) : const Color(0xFF1A1D18),
    surfaceContainerLowest: isDark ? const Color(0xFF0B0E0B) : Colors.white,
    surfaceContainerLow: isDark
        ? const Color(0xFF171C17)
        : const Color(0xFFF2F4EC),
    surfaceContainer: isDark
        ? const Color(0xFF1B211C)
        : const Color(0xFFECEFE6),
    surfaceContainerHigh: isDark
        ? const Color(0xFF252C26)
        : const Color(0xFFE6E9E0),
    surfaceContainerHighest: isDark
        ? const Color(0xFF303831)
        : const Color(0xFFDFE3DA),
    onSurfaceVariant: isDark
        ? const Color(0xFFBAC3B8)
        : const Color(0xFF5D655C),
    outline: isDark ? const Color(0xFF889287) : const Color(0xFF899287),
    outlineVariant: isDark ? const Color(0xFF303A30) : const Color(0xFFDDE3D8),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
      height: 1.15,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.35),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  final overlayStyle = systemOverlayStyleFor(brightness);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: glass ? Colors.transparent : scheme.surface,
    canvasColor: glass ? Colors.transparent : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: glass ? Colors.transparent : scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlayStyle,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontSize: 19,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.56 : 0.32),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      elevation: 2,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 16,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      secondaryActiveTrackColor: scheme.primary.withValues(alpha: 0.5),
      thumbColor: scheme.primary,
      overlayColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.dragged) ||
            states.contains(WidgetState.focused)) {
          return scheme.primary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
      thumbShape: const HandleThumbShape(),
      trackShape: const GappedSliderTrackShape(),
      thumbSize: WidgetStateProperty.resolveWith<Size?>((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return const Size(2, 36);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Size(4, 40);
        }
        return const Size(4, 32);
      }),
      trackGap: 6,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashColor: scheme.primary.withValues(alpha: 0.08),
    highlightColor: scheme.primary.withValues(alpha: 0.04),
  );
}
