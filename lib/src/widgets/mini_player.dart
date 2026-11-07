import 'package:flutter/material.dart';

import '../glass.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'audio_cover.dart';

/// 贴着导航胶囊的迷你播放条：圆形玻璃胶囊、20 半径封面，
/// 右侧播放/暂停与下一段，点按整条进入音频页。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.snapshot,
    required this.audio,
    required this.onToggle,
    required this.onNext,
    required this.onOpen,
  });

  final PlaybackSnapshot snapshot;
  final AudioItem? audio;
  final VoidCallback onToggle;
  final VoidCallback? onNext;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = snapshot.title.isEmpty
        ? (audio?.title ?? '正在播放')
        : snapshot.title;
    final meta = snapshot.durationMs > 0
        ? '${snapshot.repeatLabel} · ${formatDuration(snapshot.positionMs)} / '
              '${formatDuration(snapshot.durationMs)}'
        : snapshot.repeatLabel;

    return GlassPanel(
      radius: AppCorner.full,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            AppHaptics.tap();
            onOpen();
          },
          customBorder: AppShape.full,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(
              children: [
                AudioCover(audio: audio, size: 40, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: snapshot.playing ? '暂停' : '播放',
                  onPressed: () {
                    AppHaptics.tap();
                    onToggle();
                  },
                  iconSize: 26,
                  color: scheme.onSurface,
                  icon: Icon(
                    snapshot.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: '下一段',
                  onPressed: onNext == null
                      ? null
                      : () {
                          AppHaptics.tap();
                          onNext!();
                        },
                  iconSize: 24,
                  color: scheme.onSurface,
                  disabledColor: scheme.onSurface.opacity38,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
