import 'package:flutter_test/flutter_test.dart';

import 'package:chat/config/app_config.dart';
import 'package:chat/services/app_update_service.dart';

Map<String, dynamic> manifestJson({
  String apkUrl = 'https://chat.wangbank.top/download/android',
  Object? apkFallbackUrl,
  Object? mirrors,
  String sha256 = 'abc123',
  int versionCode = 9,
}) {
  return <String, dynamic>{
    'versionName': '1.0.8',
    'versionCode': versionCode,
    'minSupportedVersionCode': 1,
    'mandatory': false,
    'apkUrl': apkUrl,
    'sha256': sha256,
    'size': 94035036,
    if (apkFallbackUrl != null) 'apkFallbackUrl': apkFallbackUrl,
    if (mirrors != null) 'mirrors': mirrors,
  };
}

void main() {
  test('default update manifest points at the product domain', () {
    expect(
      AppConfig.updateManifestUrl,
      'https://chat.wangbank.top/download/android-version.json',
    );
    expect(
      AppConfig.updateManifestFallbackUrl,
      contains('github.com'),
    );
  });

  test('download urls prefer the synced product domain and keep GitHub as fallback',
      () {
    final manifest = AppUpdateManifest.fromJson(manifestJson(
      apkFallbackUrl:
          'https://github.com/WangBank/chat/releases/download/tag/LoveChat-Android.apk',
      mirrors: [
        'https://github.com/WangBank/chat/releases/download/tag/LoveChat-Android.apk',
        'https://mirror.example.com/LoveChat-Android.apk',
      ],
    ));

    expect(manifest.downloadUrls.length, 3);
    expect(manifest.downloadUrls.first.toString(),
        'https://chat.wangbank.top/download/android');
    expect(manifest.downloadUrls[1].host, 'github.com');
    expect(manifest.downloadUrls[2].host, 'mirror.example.com');
  });

  test('duplicate and invalid mirrors are ignored', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson(
      apkFallbackUrl: 'https://chat.wangbank.top/download/android',
      mirrors: ['', '   ', 'not-a-url', 42, 'https://fallback.example.com/app.apk'],
    ));

    expect(
      manifest.downloadUrls.map((uri) => uri.toString()).toList(),
      [
        'https://chat.wangbank.top/download/android',
        'https://fallback.example.com/app.apk',
      ],
    );
  });

  test('manifest without mirrors keeps a single download url', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson());
    expect(manifest.downloadUrls.length, 1);
  });

  test('manifest requires sha256 and apkUrl', () {
    expect(
      () => AppUpdateManifest.fromJson(manifestJson(sha256: '')),
      throwsA(isA<AppUpdateException>()),
    );
    expect(
      () => AppUpdateManifest.fromJson(manifestJson(apkUrl: '')),
      throwsA(isA<AppUpdateException>()),
    );
  });

  test('mandatory and minimum version drive forced updates', () {
    final manifest = AppUpdateManifest.fromJson(manifestJson(versionCode: 12));
    expect(manifest.isNewerThan(const CurrentAppInfo(versionName: '1.0.8', versionCode: 9)), isTrue);
    expect(manifest.isRequiredFor(const CurrentAppInfo(versionName: '1.0.8', versionCode: 9)), isFalse);
    expect(manifest.isRequiredFor(const CurrentAppInfo(versionName: '1.0.0', versionCode: 0)), isTrue);
  });
}
