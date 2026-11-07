import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models.dart';
import 'app_popup_menu.dart';
import 'audio_cover.dart';

class AudioTile extends StatelessWidget {
  AudioTile({
    super.key,
    required this.audio,
    required this.isDefault,
    required this.isPlayingAudio,
    required this.isPlaying,
    required this.onPlay,
    required this.onSetDefault,
    required this.onDesktop,
    required this.onDelete,
  });

  final AudioItem audio;
  final bool isDefault;
  final bool isPlayingAudio;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onSetDefault;
  final VoidCallback onDesktop;
  final VoidCallback onDelete;

  final GlobalKey _menuKey = GlobalKey();

  Future<void> _openMenu(BuildContext context) async {
    final action = await showAppPopupMenu<_AudioAction>(
      context: context,
      anchorKey: _menuKey,
      entries: [
        AppMenuEntry(
          value: _AudioAction.setDefault,
          label: '设为当前音频',
          icon: Icons.check_circle_outline_rounded,
          enabled: !isDefault,
          checked: isDefault,
        ),
        const AppMenuEntry(
          value: _AudioAction.addToDesktop,
          label: '添加到桌面',
          icon: Icons.add_to_home_screen_rounded,
        ),
        const AppMenuEntry(
          value: _AudioAction.delete,
          label: '删除',
          icon: Icons.delete_outline_rounded,
          danger: true,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case _AudioAction.setDefault:
        onSetDefault();
        break;
      case _AudioAction.addToDesktop:
        onDesktop();
        break;
      case _AudioAction.delete:
        onDelete();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = isPlayingAudio;

    return Material(
      color: isDefault
          ? scheme.primary.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.08 : 0.04,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.tap();
          onPlay();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              AudioCover(audio: audio, size: 48, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            audio.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      audio.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  AppHaptics.tap();
                  onPlay();
                },
                tooltip: isPlaying
                    ? '暂停'
                    : (active ? '继续' : '播放'),
                style: IconButton.styleFrom(
                  backgroundColor: active || isDefault
                      ? scheme.primary
                      : scheme.primaryContainer,
                  foregroundColor: active || isDefault
                      ? scheme.onPrimary
                      : scheme.onPrimaryContainer,
                  minimumSize: const Size.square(38),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                ),
              ),
              IconButton(
                key: _menuKey,
                onPressed: () {
                  AppHaptics.tap();
                  _openMenu(context);
                },
                tooltip: '更多',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(40),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AudioAction { setDefault, addToDesktop, delete }
