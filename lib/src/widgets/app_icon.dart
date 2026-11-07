import 'dart:io';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../models.dart';

String appIconAsset(String? icon) => icon == appIconPhoto
    ? 'assets/images/app_icon_photo.png'
    : 'assets/images/app_icon_original.png';

class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    this.size = 64,
    this.radius = 16,
    this.shadow = false,
    this.icon,
  });

  final double size;
  final double radius;
  final bool shadow;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    final settings = scope?.notifier?.settings;
    final selected = icon ?? settings?.appIcon ?? defaultAppIcon;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size * pixelRatio).round();
    final customPath = settings?.customIconPath;
    final image = selected == appIconCustom &&
            customPath != null &&
            File(customPath).existsSync()
        ? Image.file(
            File(customPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
          )
        : Image.asset(
            appIconAsset(selected),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
          );
    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
    if (!shadow) return framed;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: framed,
    );
  }
}
