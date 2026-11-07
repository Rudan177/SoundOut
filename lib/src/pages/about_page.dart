import 'package:flutter/material.dart';

import '../widgets/app_icon.dart';
import '../widgets/settings_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicensePage(
          applicationName: 'SoundOut',
          applicationVersion: '0.2.2:01-BS08',
          applicationLegalese: 'ByRUDAN',
          applicationIcon: const AppIcon(size: 48, radius: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: Column(
              children: [
                const AppIcon(size: 88, radius: 24, shadow: true),
                const SizedBox(height: 20),
                Text(
                  'SoundOut',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Text(
                      '0.2.2:01-BS08',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '把常用声音放到手边。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SettingsSection(
            title: '应用信息',
            children: [
              const SettingsRow(
                icon: Icons.person_outline_rounded,
                title: '开发者',
                value: 'ByRUDAN',
              ),
              const SettingsRow(
                icon: Icons.tag_rounded,
                title: '版本',
                value: '0.2.2:01-BS08',
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: '开源许可',
                subtitle: '查看 Flutter 与第三方开源协议',
                showChevron: true,
                onTap: () => _openLicenses(context),
              ),
            ],
          ),
          SettingsSection(
            title: '说明',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'SoundOut 是一款本地音频快捷播放工具。导入的音频会复制到应用私有目录，不会上传到网络。卸载应用后，应用内的音频文件也会一并删除。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'ByRUDAN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
