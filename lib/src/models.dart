class AudioItem {
  const AudioItem({
    required this.id,
    required this.title,
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
    required this.addedAt,
    this.artist,
    this.coverPath,
  });

  final String id;
  final String title;
  final String? artist;
  final int durationMs;
  final String path;
  final String? coverPath;
  final int sizeBytes;
  final int addedAt;

  String get durationLabel => formatDuration(durationMs);

  String get sizeLabel => formatFileSize(sizeBytes);

  String get metaLabel => durationLabel;

  factory AudioItem.fromMap(Map<dynamic, dynamic> map) {
    return AudioItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '未命名音频',
      artist: map['artist'] as String?,
      durationMs: _asInt(map['durationMs']),
      path: map['path'] as String? ?? '',
      coverPath: map['coverPath'] as String?,
      sizeBytes: _asInt(map['sizeBytes']),
      addedAt: _asInt(map['addedAt']),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.defaultAudioId,
    this.volume = 1,
    this.playCount = 1,
    this.repeatIntervalMs = 0,
    this.triggerMode = 'direct',
    this.allowConcurrent = false,
    this.appIcon = defaultAppIcon,
    this.customIconPath,
    this.onboardingDone = false,
    this.shortcutPromptShown = false,
  });

  final String? defaultAudioId;
  final double volume;
  final int playCount;
  final int repeatIntervalMs;
  final String triggerMode;
  final bool allowConcurrent;
  final String appIcon;
  final String? customIconPath;
  final bool onboardingDone;
  final bool shortcutPromptShown;

  bool get isInfinite => playCount <= 0;

  String get appIconLabel => switch (appIcon) {
    appIconPhoto => '照片图标',
    appIconCustom => '自定义图标',
    _ => '初始品牌图标',
  };

  String get playCountLabel => isInfinite ? '循环播放' : '$playCount 次';

  String get repeatIntervalLabel {
    if (repeatIntervalMs <= 0) return '不等待';
    final seconds = repeatIntervalMs / 1000;
    if (seconds == seconds.roundToDouble()) {
      return '${seconds.toInt()} 秒';
    }
    return '${seconds.toStringAsFixed(1)} 秒';
  }

  String get triggerModeLabel => triggerMode == 'open_app' ? '打开应用后播放' : '直接播放';

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AppSettings();
    final rawVolume = (map['volume'] as num?)?.toDouble() ?? 1;
    return AppSettings(
      defaultAudioId: map['defaultAudioId'] as String?,
      volume: rawVolume.clamp(0, 1).toDouble(),
      playCount: _asInt(map['playCount'], fallback: 1).clamp(0, 999),
      repeatIntervalMs: _asInt(map['repeatIntervalMs']).clamp(0, 10000),
      triggerMode: map['triggerMode'] == 'open_app' ? 'open_app' : 'direct',
      allowConcurrent: map['allowConcurrent'] as bool? ?? false,
      appIcon: switch (map['appIcon']) {
        appIconPhoto => appIconPhoto,
        appIconCustom => appIconCustom,
        _ => defaultAppIcon,
      },
      customIconPath: map['customIconPath'] as String?,
      onboardingDone: map['onboardingDone'] as bool? ?? false,
      shortcutPromptShown: map['shortcutPromptShown'] as bool? ?? false,
    );
  }
}

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.audioId,
    this.title = '',
    this.playing = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.repeatIndex = 0,
    this.repeatTotal = 0,
  });

  final String? audioId;
  final String title;
  final bool playing;
  final int positionMs;
  final int durationMs;
  final int repeatIndex;
  final int repeatTotal;

  bool get active => audioId != null && audioId!.isNotEmpty;

  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0, 1).toDouble();
  }

  String get repeatLabel {
    if (repeatTotal <= 0) return '循环播放';
    if (repeatTotal <= 1) return playing ? '正在播放' : '准备播放';
    return playing
        ? '第 $repeatIndex/$repeatTotal 次'
        : '即将播放第 $repeatIndex/$repeatTotal 次';
  }

  factory PlaybackSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const PlaybackSnapshot();
    final id = map['audioId'] as String?;
    return PlaybackSnapshot(
      audioId: id != null && id.isNotEmpty ? id : null,
      title: map['title'] as String? ?? '',
      playing: map['playing'] as bool? ?? false,
      positionMs: _asInt(map['positionMs']),
      durationMs: _asInt(map['durationMs']),
      repeatIndex: _asInt(map['repeatIndex']),
      repeatTotal: _asInt(map['repeatTotal']),
    );
  }
}

class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.failed,
    required this.duplicates,
    required this.canceled,
  });

  final int imported;
  final int failed;
  final int duplicates;
  final bool canceled;
}

String formatDuration(int durationMs) {
  if (durationMs <= 0) return '--:--';
  final totalSeconds = durationMs ~/ 1000;
  final seconds = totalSeconds % 60;
  final minutes = totalSeconds ~/ 60;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return '未知大小';
  const megabyte = 1024 * 1024;
  if (bytes >= megabyte) {
    return '${(bytes / megabyte).toStringAsFixed(1)} MB';
  }
  final kilobytes = bytes / 1024;
  return '${kilobytes.toStringAsFixed(kilobytes >= 100 ? 0 : 1)} KB';
}

const defaultAppIcon = 'original';
const appIconPhoto = 'photo';
const appIconCustom = 'custom';

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
