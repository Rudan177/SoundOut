import 'package:flutter/services.dart';

import 'models.dart';

class NativeBridge {
  static const _methodChannel = MethodChannel('soundout/native');
  static const _playbackChannel = EventChannel('soundout/playback');

  Stream<PlaybackSnapshot> get playback => _playbackChannel
      .receiveBroadcastStream()
      .map((event) => PlaybackSnapshot.fromMap(_asMap(event)));

  Future<Map<String, dynamic>> getState() async {
    return _asMap(await _methodChannel.invokeMethod<dynamic>('getState'));
  }

  Future<Map<String, dynamic>> pickAudio() async {
    return _asMap(await _methodChannel.invokeMethod<dynamic>('pickAudio'));
  }

  Future<Map<String, dynamic>> pickCustomIcon() async {
    return _asMap(await _methodChannel.invokeMethod<dynamic>('pickCustomIcon'));
  }

  Future<Map<String, dynamic>> deleteAudio(String id) async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('deleteAudio', {'id': id}),
    );
  }

  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> patch,
  ) async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('updateSettings', patch),
    );
  }

  Future<Map<String, dynamic>> completeOnboarding() async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('completeOnboarding'),
    );
  }

  Future<void> play(String? id) async {
    await _methodChannel.invokeMethod<void>('play', {'id': id});
  }

  Future<void> pausePlayback() async {
    await _methodChannel.invokeMethod<void>('pausePlayback');
  }

  Future<void> resumePlayback() async {
    await _methodChannel.invokeMethod<void>('resumePlayback');
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod<void>('stop');
  }

  Future<void> seekPlayback(int positionMs) async {
    await _methodChannel.invokeMethod<void>('seekPlayback', {
      'positionMs': positionMs,
    });
  }

  Future<Map<String, dynamic>> requestPinWidget() async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('requestPinWidget'),
    );
  }

  Future<Map<String, dynamic>> getDesktopCapabilities() async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('getDesktopCapabilities'),
    );
  }

  Future<bool> openDesktopPermissionSettings() async {
    return await _methodChannel.invokeMethod<bool>(
          'openDesktopPermissionSettings',
        ) ??
        false;
  }

  Future<Map<String, dynamic>> pinShortcut(String id) async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('pinShortcut', {'id': id}),
    );
  }

  Future<String> getAndroidAbi() async {
    return await _methodChannel.invokeMethod<String>('getAndroidAbi') ?? '';
  }

  Future<String> getUpdateCacheDir() async {
    return await _methodChannel.invokeMethod<String>('getUpdateCacheDir') ?? '';
  }

  Future<Map<String, dynamic>> installApk(String path) async {
    return _asMap(
      await _methodChannel.invokeMethod<dynamic>('installApk', {'path': path}),
    );
  }

  Future<bool> openUrl(String url) async {
    return await _methodChannel.invokeMethod<bool>('openUrl', {'url': url}) ??
        false;
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}
