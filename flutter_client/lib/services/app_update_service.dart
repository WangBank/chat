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
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final versionName = json['versionName']?.toString().trim();
    final versionCode = _parseInt(json['versionCode']);
    final minSupportedVersionCode =
        _parseInt(json['minSupportedVersionCode']) ?? 1;
    final apkUrlValue = json['apkUrl']?.toString().trim();
    final sha256Value = json['sha256']?.toString().trim().toLowerCase();

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
    );
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
    final uri = Uri.parse(AppConfig.updateManifestUrl);
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 15));

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
    final request = http.Request('GET', manifest.apkUrl);
    request.headers.addAll(const {
      'Accept': 'application/vnd.android.package-archive,*/*',
      'User-Agent': 'LoveChat-Android-Updater',
    });
    final response = await _client.send(request).timeout(
          const Duration(seconds: 60),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('下载更新失败：HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? manifest.size;
    var receivedBytes = 0;
    final output = file.openWrite();

    try {
      await for (final chunk in response.stream) {
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
