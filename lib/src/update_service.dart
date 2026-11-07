import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;

import 'native_bridge.dart';

const String updateVersionFile = 'assets/version.json';
const String _remoteVersionUrl =
    'https://raw.githubusercontent.com/Rudan177/SoundOut/main/assets/version.json';
const String _releaseApiUrl =
    'https://api.github.com/repos/Rudan177/SoundOut/releases/latest';
const String _userAgent = 'SoundOut-Updater';

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.build,
    required this.versionName,
    required this.versionCode,
    required this.repository,
    required this.changelog,
  });

  final String version;
  final String build;
  final String versionName;
  final int versionCode;
  final String repository;
  final List<String> changelog;

  static VersionInfo fromJson(Map<String, dynamic> json) {
    final version = _string(json['version']);
    final build = _string(json['build']);
    final versionName = _string(json['versionName']).isNotEmpty
        ? _string(json['versionName'])
        : (build.isEmpty ? version : '$version:$build');
    return VersionInfo(
      version: version,
      build: build,
      versionName: versionName,
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      repository: _string(json['repository']),
      changelog: (json['changelog'] as List?)
              ?.whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const [],
    );
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.apkName,
    required this.apkSize,
    required this.releaseUrl,
  });

  final VersionInfo version;
  final String? apkUrl;
  final String apkName;
  final int? apkSize;
  final String releaseUrl;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.local,
    required this.remote,
    required this.update,
  });

  final VersionInfo local;
  final VersionInfo remote;
  final UpdateInfo? update;
}

sealed class UpdateDownloadState {
  const UpdateDownloadState({required this.versionName});

  final String versionName;
}

final class UpdateDownloading extends UpdateDownloadState {
  const UpdateDownloading({
    required super.versionName,
    this.received = 0,
    this.total = 0,
  });

  final int received;
  final int total;
}

final class UpdateReady extends UpdateDownloadState {
  const UpdateReady({required super.versionName, required this.path});

  final String path;
}

final ValueNotifier<UpdateDownloadState?> updateDownloadState =
    ValueNotifier<UpdateDownloadState?>(null);

class UpdateService {
  UpdateService({NativeBridge? bridge}) : _bridge = bridge ?? NativeBridge();

  final NativeBridge _bridge;

  Future<VersionInfo> readLocalVersion() async {
    try {
      final raw = await rootBundle.loadString(updateVersionFile);
      return VersionInfo.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return VersionInfo.fromJson(const <String, dynamic>{
        'version': '0.2.2',
        'build': '01-BS09',
        'versionName': '0.2.2:01-BS09',
        'versionCode': 8,
        'repository': 'Rudan177/SoundOut',
        'changelog': <String>[],
      });
    }
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    final local = await readLocalVersion();
    final remoteJson = await _fetchJson(_remoteVersionUrl);
    if (remoteJson is! Map) {
      throw const UpdateException('版本信息格式不正确');
    }
    final remote = VersionInfo.fromJson(remoteJson.cast<String, dynamic>());
    if (!_isNewer(remote, local)) {
      return UpdateCheckResult(local: local, remote: remote, update: null);
    }

    final repository = remote.repository.isNotEmpty
        ? remote.repository
        : 'Rudan177/SoundOut';
    final releaseUrl = 'https://github.com/$repository/releases/latest';
    final releaseJson = await _tryFetchLatestRelease();
    final assets = _parseAssets(releaseJson);
    final abi = await _safeDeviceAbi();
    final asset = _pickAsset(assets, abi);

    return UpdateCheckResult(
      local: local,
      remote: remote,
      update: UpdateInfo(
        version: remote,
        apkUrl: asset?.url,
        apkName: asset?.name ?? '',
        apkSize: asset?.size,
        releaseUrl: _string(releaseJson?['html_url']).isNotEmpty
            ? _string(releaseJson?['html_url'])
            : releaseUrl,
      ),
    );
  }

  Future<String> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = info.apkUrl;
    if (url == null || url.isEmpty) {
      throw const UpdateException('当前版本暂未提供安装包，请前往 GitHub 下载');
    }
    final dirPath = await _bridge.getUpdateCacheDir();
    if (dirPath.isEmpty) throw const UpdateException('无法获取下载目录');
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    final name = _safeFileName(
      info.apkName.isNotEmpty
          ? info.apkName
          : Uri.parse(url).pathSegments.last,
    );
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (file.existsSync()) file.deleteSync();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      request.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, 'application/octet-stream');
      request.followRedirects = true;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载失败（HTTP ${response.statusCode}）');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received == 0) throw const UpdateException('安装包内容为空');
      return file.path;
    } catch (error) {
      if (file.existsSync()) file.deleteSync();
      if (error is UpdateException) rethrow;
      throw UpdateException('下载失败，请检查网络后重试');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> installApk(String path) async {
    return _bridge.installApk(path);
  }

  Future<void> downloadUpdate(UpdateInfo info) async {
    updateDownloadState.value = UpdateDownloading(
      versionName: info.version.versionName,
    );
    var shown = 0;
    try {
      final path = await downloadApk(
        info,
        onProgress: (received, total) {
          final step = total > 0 ? total ~/ 100 : 1 << 20;
          if (received - shown < step && received != total) return;
          shown = received;
          updateDownloadState.value = UpdateDownloading(
            versionName: info.version.versionName,
            received: received,
            total: total,
          );
        },
      );
      updateDownloadState.value = UpdateReady(
        versionName: info.version.versionName,
        path: path,
      );
    } catch (_) {
      updateDownloadState.value = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> installDownloaded() async {
    final state = updateDownloadState.value;
    if (state is! UpdateReady) {
      return const {'status': 'failed', 'message': '没有可安装的更新'};
    }
    final result = await _bridge.installApk(state.path);
    if (result['status'] == 'opened') {
      updateDownloadState.value = null;
    } else {
      result['path'] = state.path;
    }
    return result;
  }

  Future<bool> openUrl(String url) => _bridge.openUrl(url);

  Future<dynamic> _fetchJson(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      request.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('请求失败（HTTP ${response.statusCode}）');
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _tryFetchLatestRelease() async {
    try {
      final json = await _fetchJson(_releaseApiUrl);
      if (json is Map) return json.cast<String, dynamic>();
    } catch (_) {
      // 版本信息仍然可以从 version.json 判断，Release 信息失败时降级到发布页。
    }
    return null;
  }

  Future<String> _safeDeviceAbi() async {
    try {
      return await _bridge.getAndroidAbi();
    } catch (_) {
      return '';
    }
  }

  List<ReleaseAsset> _parseAssets(Map<String, dynamic>? release) {
    final raw = release?['assets'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => ReleaseAsset(
            name: _string(item['name']),
            url: _string(item['browser_download_url']),
            size: (item['size'] as num?)?.toInt(),
          ),
        )
        .where((asset) => asset.url.isNotEmpty)
        .toList(growable: false);
  }

  ReleaseAsset? _pickAsset(List<ReleaseAsset> assets, String abi) {
    final apks = assets
        .where(
          (asset) =>
              asset.name.toLowerCase().endsWith('.apk') &&
              asset.url.isNotEmpty,
        )
        .toList(growable: false);
    if (apks.isEmpty) return null;
    if (abi.isNotEmpty) {
      for (final asset in apks) {
        if (asset.name.contains(abi)) return asset;
      }
    }
    final universal = apks.where(
      (asset) => asset.name.toLowerCase().contains('universal'),
    );
    if (universal.isNotEmpty) return universal.first;
    return apks.first;
  }

  bool _isNewer(VersionInfo remote, VersionInfo local) {
    if (remote.versionCode > local.versionCode) return true;
    if (remote.versionCode < local.versionCode) return false;
    return remote.versionName != local.versionName;
  }
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final int? size;
}

String _string(Object? value) => value is String ? value.trim() : '';

String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return cleaned.isEmpty ? 'soundout-update.apk' : cleaned;
}
