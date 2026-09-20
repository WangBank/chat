# Flutter Client Progress

## 已完成

- Flutter SDK 已升级到 `3.47.5`，Dart 已升级到 `3.13.4`。
- `pubspec.yaml` SDK 约束已提升到 Flutter 3.47 / Dart 3.13。
- 直接依赖全部升级到最新可解析版本：`flutter_webrtc 1.6.2+hotfix.3`、`file_picker 13.1.0`、`image 4.10.1`、`permission_handler 13.0.2`、`sqflite 2.4.4`、`shared_preferences 2.5.5`；`flutter pub upgrade` 共更新 147 个依赖。
- `permission_handler` 13.x 要求 `compileSdk 37`（Flutter 3.47 默认 36），`android/app/build.gradle.kts` 已固定为 37，CI 同步安装 `platforms;android-37.0` 与 `build-tools;37.0.0`。
- `.github/workflows/android-release-apk.yml` 的 `FLUTTER_VERSION` 已同步到 `3.47.5`。
- 移除旧的 `shared_preferences_android` dependency override。
- Android 工程升级到当前 Flutter 模板版本：Gradle 9.1、AGP 9.0、Kotlin 2.3、Java 17。
- app 模块迁移到 Built-in Kotlin 方式。
- 登录注册流程支持注册后自动登录，移动端可使用受控 QQ dev-login/dev-bind 验证 QQ 登录链路。
- 个人资料页支持自定义头像、个性签名、性别、生日年份和地区资料展示/更新。
- 联系人页支持好友申请、好友通知、同意/拒绝、清理已处理通知、联系人备注修改和在线状态显示。
- 聊天页支持表情、图片发送、普通文件发送、消息引用、引用预览、已读标记和未读状态同步。
- 应用回到前台时会恢复 SignalR 在线状态，减少移动端长久在线却被标记离线的问题。
- App 内更新默认清单地址改为产品域名 `https://chat.wangbank.top/download/android-version.json`，GitHub 清单作为兜底（`ANDROID_UPDATE_MANIFEST_URL` / `ANDROID_UPDATE_MANIFEST_FALLBACK_URL` 可覆盖）；下载 APK 时按清单的 `apkUrl → apkFallbackUrl → mirrors` 顺序重试。

## 最新验证

- `flutter pub get`：成功。
- `flutter pub outdated`：direct/dev dependencies 均已是最新。
- `flutter analyze --no-fatal-infos --no-fatal-warnings`：成功。
- `flutter build apk --debug`：成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- 2026-09-19：`flutter pub upgrade` 成功（更新 147 个依赖），`flutter pub outdated` 显示直接依赖与 dev 依赖全部最新。
- 2026-09-19：`flutter analyze --no-fatal-infos --no-fatal-warnings` 无 error/warning（524 条历史 info，均为既有的 `avoid_print` 等风格提示）。
- 2026-09-19：`flutter test` 6 项全部通过。
- 2026-09-19：`flutter build web --release` 成功；`flutter build apk --debug` 成功（Flutter 3.47.5、compileSdk 37、permission_handler 13.0.2）。
- 2026-09-19：`flutter build ios --debug --no-codesign` 成功生成 `build/ios/iphoneos/Runner.app`；Flutter 3.47 工具同时自动迁移了本地 iOS 工程（iOS 最低版本 15.0、UIScene 生命周期、Swift Package Manager 集成）。iOS 工程目录未纳入版本控制，迁移只影响本机工作副本。
- 2026-09-20：新增 `test/app_update_manifest_test.dart`（默认清单域名、下载地址顺序与去重、非法 mirrors 过滤、sha256 校验、强制更新判断），`flutter test` 12 项全部通过；`flutter analyze --no-fatal-infos --no-fatal-warnings` 无 error。
- 移动端聊天、联系人和资料功能使用后端现有 API：`/contacts/friend-requests`、`/contacts/{id}/display-name`、`/chat/upload`、`/chat/messages/{id}/read`、`/auth/profile` 和 `/auth/upload-avatar`。

## 注意事项

- 普通 `flutter analyze` 仍会报告大量历史 lint，包括 `avoid_print`、命名风格、`withOpacity` deprecated、async context 等。
- `flutter_webrtc` 当前仍应用 Kotlin Gradle Plugin，Flutter 会提示未来版本可能需要上游插件迁移到 Built-in Kotlin；Android 构建仍有该上游告警，但不阻断。
- iOS 工程当前使用自定义 Podfile，Flutter 3.47 提示所有插件已提供 Swift Package 版本，后续可手工迁移到 SPM 以加快构建。
- `flutter_client`、`website` 的 lock 文件（`pubspec.lock`、`package-lock.json`）按仓库 `.gitignore` 不纳入版本控制，CI 与部署会重新解析依赖；本次升级验证的是当前 registry 上可解析到的最新版本。
- 移动端真实 QQ OAuth 仍需要平台侧跳转能力；当前移动端使用后端受控 dev-login 验证账号资料同步和绑定逻辑。
