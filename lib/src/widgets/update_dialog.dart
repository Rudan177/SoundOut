import 'package:flutter/material.dart';

import '../haptics.dart';
import '../update_service.dart';
import 'ui_helpers.dart';

Future<String?> showUpdateAvailableDialog(
  BuildContext context,
  UpdateInfo update,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _UpdateAvailableDialog(update: update),
  );
}

Future<void> handleInstallResult(
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
                  AppHaptics.tap();
                  final retry = await service.installApk(path);
                  if (!context.mounted) return;
                  await handleInstallResult(context, service, retry);
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
              const SizedBox(height: 12),
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
          onPressed: () {
            AppHaptics.tap();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        if (update.apkUrl != null)
          FilledButton(
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop('download');
            },
            child: const Text('更新'),
          )
        else
          FilledButton(
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop('release');
            },
            child: const Text('前往下载'),
          ),
      ],
    );
  }
}
