import 'package:flutter/material.dart';

import '../app_model.dart';
import '../widgets/app_icon.dart';
import '../widgets/desktop_entry_sheet.dart';
import '../widgets/ui_helpers.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final summary = await AppScope.read(context).importAudio();
      if (!mounted || summary.canceled) return;
      if (summary.imported == 0 && summary.failed > 0) {
        showAppSnackBar(context, '没有可用的音频文件');
      } else if (summary.imported == 0 && summary.duplicates > 0) {
        showAppSnackBar(context, '所选音频已在音频库中');
      } else if (summary.imported > 0) {
        await maybeOfferShortcutPermission(context, AppScope.read(context));
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, '导入失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.read(context).completeOnboarding();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, '暂时无法保存，请重试');
        setState(() => _busy = false);
      }
    }
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAudio = model.hasAudio;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  const AppIcon(size: 32, radius: 9),
                  const SizedBox(width: 10),
                  Text(
                    'SoundOut',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('跳过'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  const _IntroStep(),
                  _ImportStep(
                    importedCount: model.audios.length,
                    busy: _busy,
                    onImport: _import,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      final selected = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: selected ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : _page == 0
                          ? _next
                          : hasAudio
                          ? _finish
                          : _import,
                      child: _busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _page == 0
                                      ? Icons.arrow_forward_rounded
                                      : hasAudio
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _page == 0
                                      ? '继续'
                                      : hasAudio
                                      ? '开始使用'
                                      : '选择音频',
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_page == 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasAudio)
                          TextButton(
                            onPressed: _busy ? null : _import,
                            child: const Text('再添加一些'),
                          ),
                        if (!hasAudio)
                          TextButton(
                            onPressed: _busy ? null : _finish,
                            child: const Text('稍后再说'),
                          ),
                      ],
                    ),
                  ] else
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _BrandHero()),
          const SizedBox(height: 36),
          Text(
            '把声音\n放在手边',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 38,
              height: 1.12,
              letterSpacing: -1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '导入几段常用的音频，放到桌面。需要的时候点一下，声音就出来。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          const _FeatureRow(
            icon: Icons.offline_bolt_rounded,
            title: '点按即播',
            description: '快捷方式和桌面小组件，跳过打开应用的步骤',
          ),
          const _FeatureRow(
            icon: Icons.widgets_rounded,
            title: '桌面入口',
            description: '每个小组件都可以选择一段独立的音频',
          ),
          const _FeatureRow(
            icon: Icons.phonelink_lock_rounded,
            title: '只在本机',
            description: '音频保存在应用私有目录，不会上传',
          ),
        ],
      ),
    );
  }
}

class _ImportStep extends StatelessWidget {
  const _ImportStep({
    required this.importedCount,
    required this.busy,
    required this.onImport,
  });

  final int importedCount;
  final bool busy;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAudio = importedCount > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const _ImportPreview(),
          const SizedBox(height: 34),
          Text(
            hasAudio ? '音频已就绪' : '导入第一段音频',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 32,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasAudio
                ? '可以继续添加，或进入 SoundOut 设置默认音频和播放方式。'
                : '支持 MP3、M4A、WAV、OGG 等常见格式，一次可以选择多段。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '已添加 $importedCount 段音频',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : onImport,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasAudio ? '继续添加音频' : '从设备选择音频',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '使用系统文件选择器',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '提示：导入后长按桌面上的 SoundOut 图标，可以直接看到音频快捷方式。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 224,
      height: 224,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 208,
            height: 208,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerLow,
            ),
          ),
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
            ),
          ),
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.55),
            ),
          ),
          const AppIcon(size: 96, radius: 26, shadow: true),
          Positioned(
            right: 22,
            top: 44,
            child: _MiniBadge(
              icon: Icons.bolt_rounded,
              label: '快捷',
              background: scheme.surface,
              foreground: scheme.onSurface,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 40,
            child: _MiniBadge(
              icon: Icons.widgets_rounded,
              label: '桌面',
              background: scheme.surface,
              foreground: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('你的音频', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '0:12 · 1.2 MB',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '一次可以选择多段音频',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
