import 'package:flutter/material.dart';

import '../models.dart';
import 'audio_cover.dart';
import 'equalizer_bars.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.snapshot,
    required this.audio,
    required this.onStop,
  });

  final PlaybackSnapshot snapshot;
  final AudioItem? audio;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onInverseSurface;
    final secondary = foreground.withValues(alpha: 0.64);
    final position = formatDuration(snapshot.positionMs);
    final duration = formatDuration(snapshot.durationMs);
    final meta = snapshot.durationMs > 0
        ? '${snapshot.repeatLabel} · $position / $duration'
        : snapshot.repeatLabel;

    return Material(
      color: scheme.inverseSurface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AudioCover(audio: audio, size: 40, radius: 12),
                    if (snapshot.playing)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.inverseSurface.withValues(alpha: 0.66),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: EqualizerBars(
                              color: scheme.inversePrimary,
                              size: 16,
                              active: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.title.isEmpty
                            ? (audio?.title ?? '正在播放')
                            : snapshot.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onStop,
                  tooltip: '停止播放',
                  style: IconButton.styleFrom(
                    backgroundColor: foreground.withValues(alpha: 0.1),
                    foregroundColor: foreground,
                    minimumSize: const Size.square(36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: snapshot.progress,
                minHeight: 2,
                color: scheme.inversePrimary,
                backgroundColor: foreground.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
