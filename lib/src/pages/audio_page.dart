import 'package:flutter/material.dart';

import '../app_model.dart';
import '../glass.dart';
import '../haptics.dart';
import '../models.dart';
import '../widgets/audio_tile.dart';
import '../widgets/page_heading.dart';
import '../widgets/desktop_entry_sheet.dart';
import '../widgets/player_panel.dart';
import '../widgets/ui_helpers.dart';

class AudioPage extends StatelessWidget {
  const AudioPage({super.key, required this.bottomPadding});

  final double bottomPadding;

  AudioItem? _adjacent(List<AudioItem> audios, String? id, int delta) {
    if (audios.length < 2 || id == null) return null;
    final index = audios.indexWhere((audio) => audio.id == id);
    if (index < 0) return null;
    return audios[(index + delta + audios.length) % audios.length];
  }

  Future<void> _import(BuildContext context) async {
    try {
      final summary = await AppScope.read(context).importAudio();
      if (!context.mounted || summary.canceled) return;
      if (summary.imported > 0) {
        final extra = [
          if (summary.failed > 0) '${summary.failed} 段未能读取',
          if (summary.duplicates > 0) '${summary.duplicates} 段已存在',
        ].join('，');
        showAppSnackBar(
          context,
          extra.isEmpty
              ? '已导入 ${summary.imported} 段音频'
              : '已导入 ${summary.imported} 段，$extra',
        );
        await maybeOfferShortcutPermission(context, AppScope.read(context));
      } else if (summary.duplicates > 0) {
        showAppSnackBar(context, '所选音频已在音频库中');
      } else if (summary.failed > 0) {
        showAppSnackBar(context, '没有可用的音频文件');
      }
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, '导入失败，请重试');
    }
  }

  Future<void> _togglePlay(BuildContext context, AudioItem audio) async {
    final model = AppScope.read(context);
    AppHaptics.select();
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
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, '无法播放这段音频');
    }
  }

  Future<void> _setDefault(BuildContext context, AudioItem audio) async {
    try {
      await AppScope.read(context).updateSettings({'defaultAudioId': audio.id});
      if (context.mounted) showAppSnackBar(context, '已设为当前音频');
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, '保存失败，请重试');
    }
  }

  Future<void> _delete(BuildContext context, AudioItem audio) async {
    final confirmed = await showDeleteAudioDialog(context, audio.title);
    if (!confirmed || !context.mounted) return;
    try {
      await AppScope.read(context).deleteAudio(audio);
      if (context.mounted) showAppSnackBar(context, '已删除');
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, '删除失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const topPadding = 16.0;
    final defaultAudio = model.defaultAudio;
    final previous = _adjacent(model.audios, defaultAudio?.id, -1);
    final next = _adjacent(model.audios, defaultAudio?.id, 1);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('audio-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeading(
                    title: '音频',
                    subtitle: '导入音频，点按即可播放。',
                    trailing: IconButton.filledTonal(
                      onPressed: model.importing
                          ? null
                          : () {
                              AppHaptics.tap();
                              _import(context);
                            },
                      tooltip: '导入音频',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        minimumSize: const Size.square(46),
                      ),
                      icon: model.importing
                          ? SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimaryContainer,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 24),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DefaultAudioCard(
                    audio: defaultAudio,
                    playback: model.playback,
                    importing: model.importing,
                    onPlay: defaultAudio == null
                        ? () => _import(context)
                        : () => _togglePlay(context, defaultAudio),
                    onImport: () => _import(context),
                    onPrevious: previous == null
                        ? null
                        : () => _togglePlay(context, previous),
                    onNext: next == null
                        ? null
                        : () => _togglePlay(context, next),
                    onDesktop: defaultAudio == null
                        ? null
                        : () => pinAudioShortcut(context, model, defaultAudio),
                    onSeek: (positionMs) =>
                        model.seekPlayback(positionMs).catchError((_) {}),
                  ),
                  if (model.audios.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('全部音频', style: theme.textTheme.titleMedium),
                        const SizedBox(width: 6),
                        Text(
                          '${model.audios.length} 段',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          if (model.audios.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassPanel(
                  radius: 20,
                  opaqueColor: scheme.brightness == Brightness.dark
                      ? scheme.surfaceContainerLow
                      : scheme.surfaceContainerLowest,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < model.audios.length;
                        index++
                      ) ...[
                        if (index > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 16,
                            endIndent: 16,
                            color: scheme.onSurface.withValues(alpha: 0.08),
                          ),
                        AudioTile(
                          audio: model.audios[index],
                          isDefault: defaultAudio?.id == model.audios[index].id,
                          isPlayingAudio:
                              model.playback.audioId == model.audios[index].id,
                          isPlaying:
                              model.playback.audioId ==
                                  model.audios[index].id &&
                              model.playback.playing,
                          onPlay: () =>
                              _togglePlay(context, model.audios[index]),
                          onSetDefault: () =>
                              _setDefault(context, model.audios[index]),
                          onDesktop: () => pinAudioShortcut(
                            context,
                            model,
                            model.audios[index],
                          ),
                          onDelete: () => _delete(context, model.audios[index]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
        ],
      ),
    );
  }
}

/// 当前音频的完整播控：大封面、标题、可拖动进度与上一段/播放/下一段。
/// 参考播放面板去掉了底部的四枚动作按钮。
class _DefaultAudioCard extends StatefulWidget {
  const _DefaultAudioCard({
    required this.audio,
    required this.playback,
    required this.importing,
    required this.onPlay,
    required this.onImport,
    required this.onPrevious,
    required this.onNext,
    required this.onDesktop,
    required this.onSeek,
  });

  final AudioItem? audio;
  final PlaybackSnapshot playback;
  final bool importing;
  final VoidCallback onPlay;
  final VoidCallback onImport;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onDesktop;
  final ValueChanged<int> onSeek;

  @override
  State<_DefaultAudioCard> createState() => _DefaultAudioCardState();
}

class _DefaultAudioCardState extends State<_DefaultAudioCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final audio = widget.audio;

    if (audio == null) {
      return GlassPanel(
        radius: 28,
        opaqueColor: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.library_music_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('还没有音频', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          '先导入一段声音，再创建桌面入口。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.importing
                      ? null
                      : () {
                          AppHaptics.tap();
                          widget.onImport();
                        },
                  icon: widget.importing
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.file_open_outlined, size: 18),
                  label: Text(widget.importing ? '正在导入' : '选择音频文件'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassPanel(
      radius: 28,
      opaqueColor: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: PlayerPanel(
          audio: audio,
          playback: widget.playback,
          onPlay: widget.onPlay,
          onPrevious: widget.onPrevious,
          onNext: widget.onNext,
          onSeek: widget.onSeek,
          onDesktop: widget.onDesktop,
        ),
      ),
    );
  }
}
