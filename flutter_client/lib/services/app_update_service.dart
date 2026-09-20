import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class CurrentAppInfo {
  final String versionName;
  final int versionCode;

  const CurrentAppInfo({
    required this.versionName,
    required this.versionCode,
  });
}

class AppUpdateManifest {
  final String versionName;
  final int versionCode;
  final int minSupportedVersionCode;
  final bool mandatory;
  final Uri apkUrl;
  final String sha256;
  final int? size;
  final String? releaseTag;
  final String? notes;
  final List<Uri> fallbackApkUrls;

  const AppUpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.minSupportedVersionCode,
    required this.mandatory,
    required this.apkUrl,
    required this.sha256,
    this.size,
    this.releaseTag,
    this.notes,
    this.fallbackApkUrls = const <Uri>[],
  });

  /// 下载地址候选列表：国内镜像优先，GitHub 兜底。
  List<Uri> get downloadUrls {
    final urls = <Uri>[apkUrl];
    final seen = <String>{apkUrl.toString()};
    for (final candidate in fallbackApkUrls) {
      if (seen.add(candidate.toString())) {
        urls.add(candidate);
      }
    }
    return urls;
  }

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final versionName = json['versionName']?.toString().trim();
    final versionCode = _parseInt(json['versionCode']);
    final minSupportedVersionCode =
        _parseInt(json['minSupportedVersionCode']) ?? 1;
    final apkUrlValue = json['apkUrl']?.toString().trim();
    final sha256Value = json['sha256']?.toString().trim().toLowerCase();
    final fallbackApkUrls = _parseFallbackApkUrls(json);

    if (versionName == null || versionName.isEmpty) {
      throw const AppUpdateException('版本清单缺少 versionName');
    }
    if (versionCode == null || versionCode <= 0) {
      throw const AppUpdateException('版本清单缺少有效的 versionCode');
    }
    if (apkUrlValue == null || apkUrlValue.isEmpty) {
      throw const AppUpdateException('版本清单缺少 apkUrl');
    }
    if (sha256Value == null || sha256Value.isEmpty) {
      throw const AppUpdateException('版本清单缺少 sha256');
    }

    return AppUpdateManifest(
      versionName: versionName,
      versionCode: versionCode,
      minSupportedVersionCode: minSupportedVersionCode,
      mandatory: json['mandatory'] == true ||
          json['mandatory']?.toString().toLowerCase() == 'true',
      apkUrl: Uri.parse(apkUrlValue),
      sha256: sha256Value,
      size: _parseInt(json['size']),
      releaseTag: json['releaseTag']?.toString(),
      notes: json['notes']?.toString(),
      fallbackApkUrls: fallbackApkUrls,
    );
  }

  static List<Uri> _parseFallbackApkUrls(Map<String, dynamic> json) {
    final values = <String>[];
    final singleFallback = json['apkFallbackUrl']?.toString().trim();
    if (singleFallback != null && singleFallback.isNotEmpty) {
      values.add(singleFallback);
    }

    final mirrors = json['mirrors'];
    if (mirrors is List) {
      for (final entry in mirrors) {
        final value = entry?.toString().trim();
        if (value != null && value.isNotEmpty) {
          values.add(value);
        }
      }
    }

    final urls = <Uri>[];
    final seen = <String>{};
    for (final value in values) {
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) continue;
      if (seen.add(uri.toString())) {
        urls.add(uri);
      }
    }
    return urls;
  }

  bool isNewerThan(CurrentAppInfo current) {
    return versionCode > current.versionCode;
  }

  bool isRequiredFor(CurrentAppInfo current) {
    return mandatory || current.versionCode < minSupportedVersionCode;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AppUpdateInfo {
  final CurrentAppInfo current;
  final AppUpdateManifest latest;

  const AppUpdateInfo({
    required this.current,
    required this.latest,
  });

  bool get isRequired => latest.isRequiredFor(current);
}

class AppUpdateDownloadProgress {
  final int receivedBytes;
  final int? totalBytes;

  const AppUpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}

class AppUpdateException implements Exception {
  final String message;

  const AppUpdateException(this.message);

  @override
  String toString() => message;
}

class InstallPermissionRequiredException extends AppUpdateException {
  const InstallPermissionRequiredException()
      : super('Android 需要先允许本应用安装未知来源应用');
}

class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel('top.wangbank.chat/update');
  static const Duration _manifestTimeout = Duration(seconds: 15);
  static const Duration _downloadConnectTimeout = Duration(seconds: 30);
  static const Duration _downloadIdleTimeout = Duration(seconds: 20);
  static const Duration _downloadTotalTimeout = Duration(minutes: 8);

  final http.Client _client;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final current = await getCurrentAppInfo();
    final manifest = await fetchManifest();
    if (!manifest.isNewerThan(current)) return null;

    return AppUpdateInfo(current: current, latest: manifest);
  }

  Future<CurrentAppInfo> getCurrentAppInfo() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getPackageInfo');
    if (result == null) {
      throw const AppUpdateException('无法读取当前应用版本');
    }

    final versionName = result['versionName']?.toString() ?? 'unknown';
    final versionCode = AppUpdateManifest._parseInt(result['versionCode']) ?? 0;

    return CurrentAppInfo(versionName: versionName, versionCode: versionCode);
  }

  Future<AppUpdateManifest> fetchManifest() async {
    final candidates = <String>[AppConfig.updateManifestUrl];
    final fallbackUrl = AppConfig.updateManifestFallbackUrl.trim();
    if (fallbackUrl.isNotEmpty && !candidates.contains(fallbackUrl)) {
      candidates.add(fallbackUrl);
    }

    AppUpdateException? lastError;
    for (final candidate in candidates) {
      try {
        return await _fetchManifestFrom(candidate);
      } on AppUpdateException catch (error) {
        lastError = error;
      } catch (_) {
        lastError = AppUpdateException('检查更新失败：无法访问 $candidate');
      }
    }

    throw lastError ?? const AppUpdateException('检查更新失败，请稍后重试');
  }

  Future<AppUpdateManifest> _fetchManifestFrom(String manifestUrl) async {
    final uri = Uri.parse(manifestUrl);
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'}).timeout(
      _manifestTimeout,
      onTimeout: () {
        throw const AppUpdateException('检查更新超时，请稍后重试');
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('检查更新失败：HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const AppUpdateException('版本清单格式不正确');
    }

    return AppUpdateManifest.fromJson(decoded);
  }

  Future<File> downloadApk(
    AppUpdateManifest manifest, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final appDir = await getApplicationSupportDirectory();
    final updateDir = Directory('${appDir.path}/updates');
    await updateDir.create(recursive: true);
    final file = File('${updateDir.path}/LoveChat-${manifest.versionCode}.apk');

    AppUpdateException? lastError;
    for (final url in manifest.downloadUrls) {
      try {
        return await _downloadApkFrom(url, manifest, file, onProgress);
      } on AppUpdateException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = AppUpdateException('下载更新失败：$error');
      }
    }

    throw lastError ?? const AppUpdateException('下载更新失败，请稍后重试');
  }

  Future<File> _downloadApkFrom(
    Uri url,
    AppUpdateManifest manifest,
    File file,
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  ) async {
    final request = http.Request('GET', url);
    request.headers.addAll(const {
      'Accept': 'application/vnd.android.package-archive,*/*',
      'User-Agent': 'LoveChat-Android-Updater',
    });
    final response = await _client.send(request).timeout(
      _downloadConnectTimeout,
      onTimeout: () {
        throw const AppUpdateException('连接更新服务器超时，请检查网络后重试');
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('下载更新失败：HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? manifest.size;
    var receivedBytes = 0;
    final output = file.openWrite();

    final startedAt = DateTime.now();
    try {
      await for (final chunk in response.stream.timeout(
        _downloadIdleTimeout,
        onTimeout: (sink) {
          sink.addError(const AppUpdateException('下载更新超时，请检查网络后重试'));
          sink.close();
        },
      )) {
        if (DateTime.now().difference(startedAt) > _downloadTotalTimeout) {
          throw const AppUpdateException('下载时间过长，请检查网络后重试');
        }

        receivedBytes += chunk.length;
        output.add(chunk);
        onProgress?.call(
          AppUpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }
      await output.close();
    } on AppUpdateException {
      await output.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } catch (_) {
      await output.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }

    final calculatedSha256 =
        sha256.convert(await file.readAsBytes()).toString();
    final expectedSha256 = manifest.sha256.toLowerCase();
    if (calculatedSha256.toLowerCase() != expectedSha256) {
      if (await file.exists()) {
        await file.delete();
      }
      throw const AppUpdateException('下载文件校验失败，请重新下载');
    }

    return file;
  }

  Future<void> installApk(File apkFile) async {
    try {
      await _channel.invokeMethod<void>('installApk', {'path': apkFile.path});
    } on PlatformException catch (error) {
      if (error.code == 'unknown_sources_disabled') {
        throw const InstallPermissionRequiredException();
      }
      throw AppUpdateException(error.message ?? '无法打开安装器');
    }
  }

  Future<bool> canInstallApks() async {
    try {
      final result = await _channel.invokeMethod<bool>('canInstallApks');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  void dispose() {
    _client.close();
  }
}
