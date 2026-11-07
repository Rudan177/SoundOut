import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/audio_cover.dart';
import '../widgets/audio_tile.dart';
import '../widgets/equalizer_bars.dart';
import '../widgets/page_heading.dart';
import '../widgets/desktop_entry_sheet.dart';
import '../widgets/ui_helpers.dart';

class AudioPage extends StatelessWidget {
  const AudioPage({super.key, required this.bottomPadding});

  final double bottomPadding;

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
    await HapticFeedback.selectionClick();
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
                          : () => _import(context),
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
                    onDesktop: () => showDesktopEntrySheet(context),
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
                child: Material(
                  color: scheme.brightness == Brightness.dark
                      ? scheme.surfaceContainerLow
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
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
                              model.playback.audioId == model.audios[index].id &&
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

class _DefaultAudioCard extends StatelessWidget {
  const _DefaultAudioCard({
    required this.audio,
    required this.playback,
    required this.importing,
    required this.onPlay,
    required this.onImport,
    required this.onDesktop,
  });

  final AudioItem? audio;
  final PlaybackSnapshot playback;
  final bool importing;
  final VoidCallback onPlay;
  final VoidCallback onImport;
  final VoidCallback onDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (audio == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
        ),
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
                onPressed: importing ? null : onImport,
                icon: importing
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.file_open_outlined, size: 18),
                label: Text(importing ? '正在导入' : '选择音频文件'),
              ),
            ),
          ],
        ),
      );
    }

    final isCurrentActive = playback.active && playback.audioId == audio!.id;
    final isPlaying = isCurrentActive && playback.playing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '当前音频',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(
                              alpha: 0.72,
                            ),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (isCurrentActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                EqualizerBars(
                                  color: scheme.onPrimaryContainer,
                                  size: 10,
                                  active: isPlaying,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isPlaying
                                      ? '播放中'
                                      : (isCurrentActive && playback.positionMs > 0
                                          ? '已暂停'
                                          : playback.repeatLabel),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      audio!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      audio!.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: brandInk.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: AudioCover(audio: audio, size: 84, radius: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  isPlaying
                      ? '暂停'
                      : (isCurrentActive && playback.positionMs > 0
                          ? '继续'
                          : '播放'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDesktop,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.add_to_home_screen_rounded, size: 18),
                label: const Text('添加到桌面'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
