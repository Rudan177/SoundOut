import 'package:flutter/material.dart';

import '../glass.dart';
import '../haptics.dart';
import '../update_service.dart';
import '../widgets/app_icon.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/ui_helpers.dart';
import '../widgets/update_dialog.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final UpdateService _service = UpdateService();
  bool _checking = false;

  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicensePage(
          applicationName: 'SoundOut',
          applicationVersion: '0.3.0:01-BS16',
          applicationLegalese: 'ByRUDAN',
          applicationIcon: const AppIcon(size: 48, radius: 13),
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    UpdateCheckResult result;
    try {
      result = await _service.checkForUpdate();
    } catch (error) {
      if (!mounted) return;
      setState(() => _checking = false);
      showAppSnackBar(
        context,
        error is UpdateException ? error.message : '检查更新失败，请稍后重试',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);

    final update = result.update;
    if (update == null) {
      showAppSnackBar(context, '已是最新版本 ${result.local.versionName}');
      return;
    }
    final action = await showUpdateAvailableDialog(context, update);
    if (!mounted || action == null) return;
    if (action == 'release') {
      await _service.openUrl(update.releaseUrl);
      return;
    }
    if (action != 'download') return;

    showAppSnackBar(context, '开始下载更新');
    try {
      await _service.downloadUpdate(update);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error is UpdateException ? error.message : '下载失败，请检查网络后重试',
      );
    }
  }

  Future<void> _installUpdate() async {
    final result = await _service.installDownloaded();
    if (!mounted) return;
    await handleInstallResult(context, _service, result);
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
                      '0.3.0:01-BS16',
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
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _checking
                      ? null
                      : () {
                          AppHaptics.tap();
                          _checkUpdate();
                        },
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_checking ? '正在检查…' : '检查更新'),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<UpdateDownloadState?>(
            valueListenable: updateDownloadState,
            builder: (context, download, _) {
              if (download == null) return const SizedBox.shrink();
              return _UpdateStatusCard(
                download: download,
                onInstall: () => _installUpdate(),
              );
            },
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
                value: '0.3.0:01-BS16',
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

class _UpdateStatusCard extends StatelessWidget {
  const _UpdateStatusCard({required this.download, required this.onInstall});

  final UpdateDownloadState download;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = download is UpdateReady;
    final UpdateDownloading? downloading = switch (download) {
      final UpdateDownloading value => value,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassPanel(
        radius: 20,
        opaqueColor: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        child: InkWell(
          onTap: ready
              ? () {
                  AppHaptics.tap();
                  onInstall();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ready
                          ? Icons.check_circle_rounded
                          : Icons.cloud_download_outlined,
                      size: 20,
                      color: ready ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ready ? '更新已下载' : '正在下载更新',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          download.versionName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (downloading != null) ...[
                  LinearProgressIndicator(
                    value: downloading.total > 0
                        ? downloading.received / downloading.total
                        : null,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressText(downloading),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Text(
                    '点击安装并完成更新',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _progressText(UpdateDownloading download) {
  final received = _formatBytes(download.received);
  if (download.total <= 0) return received;
  return '$received / ${_formatBytes(download.total)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
