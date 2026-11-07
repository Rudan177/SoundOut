import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'models.dart';
import 'native_bridge.dart';

class AppModel extends ChangeNotifier {
  AppModel({NativeBridge? bridge}) : _bridge = bridge ?? NativeBridge();

  final NativeBridge _bridge;
  StreamSubscription<PlaybackSnapshot>? _playbackSubscription;

  List<AudioItem> _audios = const [];
  AppSettings _settings = const AppSettings();
  PlaybackSnapshot _playback = const PlaybackSnapshot();
  bool _ready = false;
  bool _importing = false;
  String? _error;

  List<AudioItem> get audios => _audios;
  AppSettings get settings => _settings;
  PlaybackSnapshot get playback => _playback;
  bool get ready => _ready;
  bool get importing => _importing;
  String? get error => _error;
  bool get hasAudio => _audios.isNotEmpty;

  AudioItem? get defaultAudio {
    if (_audios.isEmpty) return null;
    for (final audio in _audios) {
      if (audio.id == _settings.defaultAudioId) return audio;
    }
    return _audios.first;
  }

  AudioItem? audioById(String? id) {
    if (id == null) return null;
    for (final audio in _audios) {
      if (audio.id == id) return audio;
    }
    return null;
  }

  Future<void> init() async {
    try {
      _applyState(await _bridge.getState());
      _playbackSubscription = _bridge.playback.listen((snapshot) {
        _playback = snapshot;
        notifyListeners();
      });
    } catch (error) {
      _error = error.toString();
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _ready = false;
    _error = null;
    notifyListeners();
    await _playbackSubscription?.cancel();
    _playbackSubscription = null;
    await init();
  }

  Future<ImportSummary> importAudio() async {
    _importing = true;
    notifyListeners();
    try {
      final state = await _bridge.pickAudio();
      _applyState(state);
      return ImportSummary(
        imported: (state['importedCount'] as num?)?.toInt() ?? 0,
        failed: (state['failedCount'] as num?)?.toInt() ?? 0,
        duplicates: (state['duplicateCount'] as num?)?.toInt() ?? 0,
        canceled: state['canceled'] as bool? ?? false,
      );
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  Future<({bool canceled, bool pinned})> pickCustomIcon() async {
    final state = await _bridge.pickCustomIcon();
    _applyState(state);
    final path = _settings.customIconPath;
    if (path != null) FileImage(File(path)).evict();
    notifyListeners();
    return (
      canceled: state['canceled'] as bool? ?? false,
      pinned: state['customIconPinned'] as bool? ?? false,
    );
  }

  Future<void> deleteAudio(AudioItem audio) async {
    final state = await _bridge.deleteAudio(audio.id);
    _applyState(state);
    notifyListeners();
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    final state = await _bridge.updateSettings(patch);
    _applyState(state);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final state = await _bridge.completeOnboarding();
    _applyState(state);
    notifyListeners();
  }

  Future<void> play([String? id]) async {
    await _bridge.play(id);
  }

  Future<void> pausePlayback() async {
    await _bridge.pausePlayback();
  }

  Future<void> resumePlayback() async {
    await _bridge.resumePlayback();
  }

  Future<void> stop() async {
    await _bridge.stop();
  }

  Future<Map<String, dynamic>> requestPinWidget() => _bridge.requestPinWidget();

  Future<Map<String, dynamic>> desktopCapabilities() =>
      _bridge.getDesktopCapabilities();

  Future<bool> openDesktopPermissionSettings() =>
      _bridge.openDesktopPermissionSettings();

  Future<Map<String, dynamic>> pinShortcut(String id) =>
      _bridge.pinShortcut(id);

  void _applyState(Map<String, dynamic> state) {
    final audioList = state['audios'];
    if (audioList is List) {
      _audios = audioList
          .whereType<Map>()
          .map(AudioItem.fromMap)
          .where((audio) => audio.id.isNotEmpty)
          .toList(growable: false);
    }
    if (state['settings'] is Map) {
      _settings = AppSettings.fromMap(state['settings'] as Map);
    }
    if (state['playback'] is Map) {
      _playback = PlaybackSnapshot.fromMap(state['playback'] as Map);
    }
    _error = null;
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel model, required super.child})
    : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.notifier!;
  }

  static AppModel read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
