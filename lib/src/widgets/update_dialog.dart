import 'package:flutter/material.dart';

import '../update_service.dart';
import 'ui_helpers.dart';

Future<void> checkForUpdate(BuildContext context) async {
  final service = UpdateService();
  showAppSnackBar(context, '正在检查更新…');
  UpdateCheckResult result;
  try {
    result = await service.checkForUpdate();
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        error is UpdateException ? error.message : '检查更新失败，请稍后重试',
      );
    }
    return;
  }
  if (!context.mounted) return;
  final update = result.update;
  if (update == null) {
    showAppSnackBar(context, '已是最新版本 ${result.local.versionName}');
    return;
  }

  final action = await showDialog<String>(
    context: context,
    builder: (_) => _UpdateAvailableDialog(update: update),
  );
  if (!context.mounted || action == null) return;
  if (action == 'release') {
    await service.openUrl(update.releaseUrl);
    return;
  }
  if (action != 'download') return;

  final install = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(service: service, update: update),
  );
  if (!context.mounted || install == null) return;
  await _handleInstallResult(context, service, install);
}

Future<void> _handleInstallResult(
  BuildContext context,
  UpdateService service,
  Map<String, dynamic> result,
) async {
  final status = result['status'] as String? ?? 'failed';
  final message = result['message'] as String? ?? '';
  final path = result['path'] as String?;
  switch (status) {
    case 'opened':
      showAppSnackBar(context, '已打开安装程序，请按系统提示完成更新');
      return;
    case 'permission_required':
      showAppSnackBar(
        context,
        message.isEmpty ? '请允许 SoundOut 安装未知应用后重试' : message,
        action: path == null || path.isEmpty
            ? null
            : SnackBarAction(
                label: '重试',
                onPressed: () async {
                  final retry = await service.installApk(path);
                  if (!context.mounted) return;
                  await _handleInstallResult(context, service, retry);
                },
              ),
      );
      return;
    default:
      showAppSnackBar(
        context,
        message.isEmpty ? '无法启动安装程序' : message,
      );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({required this.update});

  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = update.version.changelog;
    final size = update.apkSize;
    return AlertDialog(
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                update.version.versionName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (size != null && size > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '安装包 ${(size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('更新内容', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (notes.isEmpty)
                Text(
                  '详情请前往 GitHub Release 查看。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ...notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (update.apkUrl == null) ...[
                const SizedBox(height: 12),
                Text(
                  '当前网络无法读取安装包信息，可前往 GitHub Release 手动下载。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        if (update.apkUrl != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop('download'),
            child: const Text('下载并安装'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop('release'),
            child: const Text('打开发布页'),
          ),
      ],
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.service, required this.update});

  final UpdateService service;
  final UpdateInfo update;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  String? _error;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _progress = null;
      _installing = false;
    });
    String path;
    try {
      path = await widget.service.downloadApk(
        widget.update,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is UpdateException
            ? error.message
            : '下载失败，请检查网络后重试';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _installing = true);
    final result = await widget.service.installApk(path);
    if (!mounted) return;
    Navigator.of(context).pop(<String, dynamic>{...result, 'path': path});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _error;
    return PopScope(
      canPop: error != null,
      child: AlertDialog(
        title: Text(error == null ? '正在下载更新' : '更新失败'),
        content: error != null
            ? Text(error)
            : SizedBox(
                width: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _installing
                          ? '正在打开安装程序…'
                          : _progress == null
                          ? '正在连接 GitHub…'
                          : '已下载 ${(_progress! * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        actions: error == null
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
                FilledButton(onPressed: _start, child: const Text('重试')),
              ],
      ),
    );
  }
}
