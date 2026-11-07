import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';

class AudioCover extends StatelessWidget {
  const AudioCover({
    super.key,
    required this.audio,
    required this.size,
    this.radius = 14,
  });

  final AudioItem? audio;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = audio?.coverPath;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * devicePixelRatio).round();

    Widget placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          size: size * 0.42,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );

    if (coverPath != null && coverPath.isNotEmpty) {
      placeholder = Image.file(
        File(coverPath),
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(dimension: size, child: placeholder),
    );
  }
}
