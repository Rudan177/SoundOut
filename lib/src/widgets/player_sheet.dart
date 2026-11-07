import 'package:flutter/material.dart';

import '../app_model.dart';
import '../glass.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'desktop_entry_sheet.dart';
import 'player_panel.dart';

/// 半屏播放器：和迷你条同一套玻璃层，点按迷你条在播放中展开。
Future<void> showPlayerSheet(BuildContext context) async {
  AppHaptics.tap();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (_) => const _PlayerSheet(),
  );
}

class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet();

  AudioItem? _adjacent(List<AudioItem> audios, String? id, int delta) {
    if (audios.length < 2 || id == null) return null;
    final index = audios.indexWhere((audio) => audio.id == id);
    if (index < 0) return null;
    return audios[(index + delta + audios.length) % audios.length];
  }

  Future<void> _toggle(AppModel model, AudioItem audio) async {
    try {
      final playback = model.playback;
      if (playback.active && playback.audioId == audio.id) {
        if (playback.playing) {
          await model.pausePlayback();
        } else {
          await model.resumePlayback();
        }
      } else {
        await model.play(audio.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final audio = model.audioById(model.playback.audioId) ?? model.defaultAudio;
    final media = MediaQuery.of(context);
    if (audio == null) {
      return const SizedBox.shrink();
    }
    final previous = _adjacent(model.audios, audio.id, -1);
    final next = _adjacent(model.audios, audio.id, 1);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + media.padding.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
          child: GlassPanel(
            radius: AppCorner.xxl,
            opaqueColor: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerLowest,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 34,
                offset: const Offset(0, 12),
              ),
            ],
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PlayerPanel(
                    audio: audio,
                    playback: model.playback,
                    coverSize: 148,
                    onPlay: () => _toggle(model, audio),
                    onPrevious: previous == null
                        ? null
                        : () => model.play(previous.id),
                    onNext: next == null ? null : () => model.play(next.id),
                    onSeek: (positionMs) =>
                        model.seekPlayback(positionMs).catchError((_) {}),
                    onDesktop: () => pinAudioShortcut(context, model, audio),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
