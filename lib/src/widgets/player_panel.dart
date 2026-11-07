import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'audio_cover.dart';

/// 参考原项目的完整媒体播控：大封面、标题、可拖动进度与上一段/播放/下一段。
/// 底部保留「添加到桌面」一个动作，不再有参考项目里的四枚动作按钮。
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.audio,
    required this.playback,
    required this.onPlay,
    required this.onSeek,
    this.onPrevious,
    this.onNext,
    this.onDesktop,
    this.coverSize = 176,
  });

  final AudioItem audio;
  final PlaybackSnapshot playback;
  final VoidCallback onPlay;
  final ValueChanged<int> onSeek;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onDesktop;
  final double coverSize;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  double? _seekFraction;
  int _seekHapticStep = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final audio = widget.audio;
    final playback = widget.playback;
    final isCurrent = playback.active && playback.audioId == audio.id;
    final isPlaying = isCurrent && playback.playing;
    final durationMs = isCurrent && playback.durationMs > 0
        ? playback.durationMs
        : audio.durationMs;
    final progress = isCurrent && durationMs > 0
        ? (playback.positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final fraction = _seekFraction ?? progress;
    final positionMs = _seekFraction == null
        ? (isCurrent ? playback.positionMs : 0)
        : (fraction * durationMs).round();
    final meta = [
      audio.metaLabel,
      if (isCurrent && playback.repeatLabel.isNotEmpty) playback.repeatLabel,
    ].join(' · ');

    return Column(
      children: [
        Container(
          decoration: ShapeDecoration(
            shape: AppShape.all(widget.coverSize >= 160 ? 28 : 24),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.3 : 0.14,
                ),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AudioCover(
            audio: audio,
            size: widget.coverSize,
            radius: widget.coverSize >= 160 ? 28 : 24,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          audio.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          meta,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),
        Slider(
          value: fraction.clamp(0.0, 1.0),
          onChanged: isCurrent && durationMs > 0
              ? (value) {
                  final step = (value * 20).round();
                  if (step != _seekHapticStep) {
                    _seekHapticStep = step;
                    AppHaptics.select();
                  }
                  setState(() => _seekFraction = value);
                }
              : null,
          onChangeEnd: (value) {
            if (!isCurrent || durationMs <= 0) return;
            widget.onSeek((value * durationMs).round());
            setState(() => _seekFraction = null);
            _seekHapticStep = -1;
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatDuration(positionMs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(durationMs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundTransport(
              icon: Icons.skip_previous_rounded,
              tooltip: '上一段',
              onPressed: widget.onPrevious,
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 68,
              height: 68,
              child: FilledButton(
                onPressed: () {
                  AppHaptics.tap();
                  widget.onPlay();
                },
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(68),
                  shape: AppShape.full,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 20),
            _RoundTransport(
              icon: Icons.skip_next_rounded,
              tooltip: '下一段',
              onPressed: widget.onNext,
            ),
          ],
        ),
        if (widget.onDesktop != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                AppHaptics.tap();
                widget.onDesktop!();
              },
              icon: const Icon(Icons.add_to_home_screen_rounded, size: 18),
              label: const Text('添加到桌面'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoundTransport extends StatelessWidget {
  const _RoundTransport({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: context.isDark ? 0.72 : 0.9,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed == null
              ? null
              : () {
                  AppHaptics.tap();
                  onPressed!();
                },
          iconSize: 28,
          color: scheme.onSurface,
          disabledColor: scheme.onSurface.opacity38,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
