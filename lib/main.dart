import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_model.dart';
import 'src/glass.dart';
import 'src/haptics.dart';
import 'src/pages/home_shell.dart';
import 'src/pages/onboarding_page.dart';
import 'src/theme.dart';
import 'src/widgets/app_icon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final model = AppModel();
  await model.init();
  runApp(SoundOutApp(model: model));
}

class SoundOutApp extends StatefulWidget {
  const SoundOutApp({super.key, required this.model});

  final AppModel model;

  @override
  State<SoundOutApp> createState() => _SoundOutAppState();
}

class _SoundOutAppState extends State<SoundOutApp> {
  late final ValueNotifier<({bool enabled, double strength})> _glass;

  @override
  void initState() {
    super.initState();
    _glass = ValueNotifier(_snapshot());
    widget.model.addListener(_syncGlass);
  }

  ({bool enabled, double strength}) _snapshot() {
    final settings = widget.model.settings;
    return (enabled: settings.glassEffect, strength: settings.glassStrength);
  }

  void _syncGlass() {
    final next = _snapshot();
    final current = _glass.value;
    if (next.enabled != current.enabled || next.strength != current.strength) {
      _glass.value = next;
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_syncGlass);
    _glass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: widget.model,
      child: ValueListenableBuilder<({bool enabled, double strength})>(
        valueListenable: _glass,
        builder: (context, glass, _) {
          return MaterialApp(
            title: 'SoundOut',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light, glass: glass.enabled),
            darkTheme: buildAppTheme(Brightness.dark, glass: glass.enabled),
            themeMode: ThemeMode.system,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemOverlayStyleFor(brightness),
                child: GlassScope(
                  enabled: glass.enabled,
                  strength: glass.strength,
                  child: AppBackdrop(child: child ?? const SizedBox.shrink()),
                ),
              );
            },
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    if (!model.ready) {
      return const _BootScreen();
    }
    if (model.error != null) {
      return _ErrorScreen(onRetry: model.retry);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: model.settings.onboardingDone
          ? const HomeShell(key: ValueKey('home'))
          : const OnboardingPage(key: ValueKey('onboarding')),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(size: 72, radius: 19),
                const SizedBox(height: 28),
                Text('无法读取本地数据', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '请重新打开应用。如果问题仍然存在，可以尝试清除应用数据。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    AppHaptics.tap();
                    onRetry();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
