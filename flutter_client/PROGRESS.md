# Flutter Client Progress

## 已完成

- Flutter SDK 已升级到 `3.44.8`。
- Dart 已升级到 `3.12.2`。
- `pubspec.yaml` SDK 约束已提升到 Flutter 3.44 / Dart 3.12。
- `shared_preferences` 已升级到 `2.5.5`。
- 移除旧的 `shared_preferences_android` dependency override。
- Android 工程升级到当前 Flutter 模板版本：Gradle 9.1、AGP 9.0、Kotlin 2.3、Java 17。
- app 模块迁移到 Built-in Kotlin 方式。

## 最新验证

- `flutter pub get`：成功。
- `flutter pub outdated`：direct/dev dependencies 均已是最新。
- `flutter analyze --no-fatal-infos --no-fatal-warnings`：成功。
- `flutter build apk --debug`：成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter test`：未运行成功，因为项目当前没有 `test/` 目录。

## 注意事项

- 普通 `flutter analyze` 仍会报告大量历史 lint，包括 `avoid_print`、命名风格、`withOpacity` deprecated、async context 等。
- `flutter_webrtc` 当前仍应用 Kotlin Gradle Plugin，Flutter 会提示未来版本可能需要上游插件迁移到 Built-in Kotlin。
