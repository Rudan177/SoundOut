import 'package:flutter/material.dart';

import '../app_model.dart';
import '../haptics.dart';
import '../models.dart';
import 'app_sheet.dart';
import 'ui_helpers.dart';

enum _DesktopChoice { shortcut, widget }

Future<void> showDesktopEntrySheet(
  BuildContext context, {
  AudioItem? audio,
}) async {
  final model = AppScope.read(context);
  final target = audio ?? model.defaultAudio;
  if (target == null) {
    showAppSnackBar(context, '请先导入音频');
    return;
  }

  final choice = await showAppSheet<_DesktopChoice>(
    context: context,
    title: '添加到桌面',
    maxHeightFactor: 0.45,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DesktopRow(
            icon: Icons.bolt_rounded,
            title: '应用快捷方式',
            onTap: () => Navigator.of(context).pop(_DesktopChoice.shortcut),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 20,
            endIndent: 20,
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          _DesktopRow(
            icon: Icons.widgets_rounded,
            title: '桌面小组件',
            onTap: () => Navigator.of(context).pop(_DesktopChoice.widget),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: TextButton(
              onPressed: () {
                AppHaptics.tap();
                Navigator.of(context).pop();
                showManualAddDialog(context);
              },
              child: Text(
                '没有出现添加提示？',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  if (!context.mounted || choice == null) return;
  switch (choice) {
    case _DesktopChoice.shortcut:
      await pinAudioShortcut(context, model, target);
      break;
    case _DesktopChoice.widget:
      await pinWidget(context, model);
      break;
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () {
        AppHaptics.tap();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android 8+ 添加快捷方式没有可单独申请的运行时权限，确认框由
/// `ShortcutManager.requestPinShortcut` 直接唤起。首次导入或首次启动且有
/// 音频时，直接调起系统添加快捷方式确认框。
Future<void> maybeOfferShortcutPermission(
  BuildContext context,
  AppModel model,
) async {
  if (model.settings.shortcutPromptShown) return;
  final audio = model.defaultAudio;
  if (audio == null) return;
  await model.updateSettings({'shortcutPromptShown': true});
  if (!context.mounted) return;
  await Future<void>.delayed(const Duration(milliseconds: 160));
  if (context.mounted) {
    await pinAudioShortcut(context, model, audio);
  }
}

Future<void> pinAudioShortcut(
  BuildContext context,
  AppModel model,
  AudioItem audio,
) async {
  try {
    final result = await model.pinShortcut(audio.id);
    if (!context.mounted) return;
    final oem = result['oem'] as String?;
    final method = result['method'] as String? ?? 'none';
    final alreadyPinned = result['alreadyPinned'] as bool? ?? false;
    final requested = result['requested'] as bool? ?? false;
    if (alreadyPinned) {
      showAppSnackBar(context, '「${audio.title}」已在桌面');
    } else if (requested) {
      showAppSnackBar(
        context,
        method == 'legacy' ? '已请求添加桌面快捷方式' : '请在桌面确认添加快捷方式',
        action: SnackBarAction(
          label: '没出现？',
          onPressed: () {
            AppHaptics.tap();
            showManualAddDialog(
              context,
              shortcut: true,
              oem: oem,
              model: model,
            );
          },
        ),
      );
    } else {
      await showManualAddDialog(
        context,
        shortcut: true,
        oem: oem,
        model: model,
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, '添加失败，请稍后重试');
    }
  }
}

Future<void> pinWidget(BuildContext context, AppModel model) async {
  // Let a just-closed sheet finish dismissing; some launchers ignore a pin
  // request made while the activity is regaining focus.
  await Future<void>.delayed(const Duration(milliseconds: 240));
  if (!context.mounted) return;
  final onPinShortcut = model.defaultAudio == null
      ? null
      : () => pinAudioShortcut(context, model, model.defaultAudio!);
  try {
    final result = await model.requestPinWidget();
    if (!context.mounted) return;
    final oem = result['oem'] as String?;
    final requested = result['requested'] as bool? ?? false;
    if (requested) {
      showAppSnackBar(
        context,
        '请在桌面确认添加小组件',
        action: SnackBarAction(
          label: '没出现？',
          onPressed: () {
            AppHaptics.tap();
            showManualAddDialog(
              context,
              oem: oem,
              model: model,
              onPinShortcut: onPinShortcut,
            );
          },
        ),
      );
    } else {
      await showManualAddDialog(
        context,
        oem: oem,
        model: model,
        onPinShortcut: onPinShortcut,
      );
    }
  } catch (_) {
    if (context.mounted) {
      await showManualAddDialog(
        context,
        model: model,
        onPinShortcut: onPinShortcut,
      );
    }
  }
}

String _widgetManualText(String? oem) {
  switch (oem) {
    case 'xiaomi':
      return '长按桌面空白处 → 添加小部件 → 找到 SoundOut，拖到桌面。\n\n'
          '如果小部件列表里没有，或添加后点按无反应：设置 → 应用设置 → SoundOut → 权限管理，'
          '允许「桌面快捷方式」；再到「自启动」中允许 SoundOut 后台运行。';
    case 'huawei':
      return '双指捏合桌面 → 小部件/服务卡片 → 找到 SoundOut，拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「创建桌面快捷方式」；'
          '并在「应用启动管理」中关闭自动管理，允许自启动。';
    case 'honor':
      return '双指捏合桌面 → 小部件/服务卡片 → 找到 SoundOut，拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「创建桌面快捷方式」；'
          '并在「应用启动管理」中允许自启动。';
    case 'oppo':
      return '长按桌面空白处 → 小部件/插件 → 找到 SoundOut，拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「桌面快捷方式」；'
          '再到「自启动」中允许 SoundOut。';
    case 'vivo':
      return '长按桌面空白处 → 原子组件/小部件 → 找到 SoundOut，拖到桌面。\n\n'
          '如果没有：i 管家 → 应用管理 → 权限管理 → SoundOut，允许「桌面快捷方式」；'
          '再到「自启动」中允许 SoundOut。';
    default:
      return '长按桌面空白处 → 小组件 → SoundOut，拖到桌面后点按齿轮选择音频。';
  }
}

String _shortcutManualText(String? oem) {
  switch (oem) {
    case 'xiaomi':
      return '长按桌面上的 SoundOut 图标 → 在快捷方式菜单中按住音频，把它拖到桌面。\n\n'
          '如果长按没有快捷方式菜单：设置 → 应用设置 → SoundOut → 权限管理，允许「桌面快捷方式」。';
    case 'huawei':
      return '长按桌面上的 SoundOut 图标 → 在弹出的快捷方式中选择音频并拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「创建桌面快捷方式」。';
    case 'honor':
      return '长按桌面上的 SoundOut 图标 → 在弹出的快捷方式中选择音频并拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「创建桌面快捷方式」。';
    case 'oppo':
      return '长按桌面上的 SoundOut 图标 → 选择快捷方式中的音频并拖到桌面。\n\n'
          '如果没有：设置 → 应用 → 应用管理 → SoundOut → 权限，允许「桌面快捷方式」。';
    case 'vivo':
      return '长按桌面上的 SoundOut 图标 → 选择快捷方式中的音频并拖到桌面。\n\n'
          '如果没有：i 管家 → 应用管理 → 权限管理 → SoundOut，允许「桌面快捷方式」。';
    default:
      return '长按桌面上的 SoundOut 图标，在快捷方式菜单中按住音频，把它拖到桌面。';
  }
}

Future<void> showManualAddDialog(
  BuildContext context, {
  bool shortcut = false,
  String? oem,
  AppModel? model,
  Future<void> Function()? onPinShortcut,
}) async {
  final canOpenSettings = model != null &&
      (await model.desktopCapabilities())['canOpenSettings'] == true;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          shortcut ? '手动添加快捷方式' : '手动添加到桌面',
        ),
        content: Text(
          shortcut ? _shortcutManualText(oem) : _widgetManualText(oem),
        ),
        actions: [
          if (canOpenSettings)
            TextButton(
              onPressed: () async {
                AppHaptics.tap();
                Navigator.of(context).pop();
                await model.openDesktopPermissionSettings();
              },
              child: const Text('打开权限设置'),
            ),
          if (onPinShortcut != null)
            TextButton(
              onPressed: () {
                AppHaptics.tap();
                Navigator.of(context).pop();
                onPinShortcut();
              },
              child: const Text('改为添加快捷方式'),
            ),
          TextButton(
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop();
            },
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}
