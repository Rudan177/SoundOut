import 'package:flutter/material.dart';

import '../models.dart';
import 'app_sheet.dart';
import 'audio_cover.dart';

class OptionChoice<T> {
  const OptionChoice(this.value, this.title, {this.subtitle});

  final T value;
  final String title;
  final String? subtitle;
}

Future<T?> showOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<OptionChoice<T>> options,
  required T? selected,
  String? description,
}) {
  return showAppSheet<T>(
    context: context,
    title: title,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 20,
          endIndent: 20,
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return Material(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(option.value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (option.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                option.subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showAudioPickerSheet({
  required BuildContext context,
  required List<AudioItem> audios,
  required String? selectedId,
  String title = '默认音频',
}) {
  return showAppSheet<String>(
    context: context,
    title: title,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: audios.length,
        separatorBuilder: (context, index) => Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 76,
          endIndent: 20,
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) {
          final audio = audios[index];
          final isSelected = audio.id == selectedId;
          return Material(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(audio.id),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AudioCover(audio: audio, size: 44, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              audio.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                      const SizedBox(width: 12),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
