# Flutter Client Progress

## 已完成

- Flutter SDK 已升级到 `3.44.8`。
- Dart 已升级到 `3.12.2`。
- `pubspec.yaml` SDK 约束已提升到 Flutter 3.44 / Dart 3.12。
- `shared_preferences` 已升级到 `2.5.5`。
- 移除旧的 `shared_preferences_android` dependency override。
- Android 工程升级到当前 Flutter 模板版本：Gradle 9.1、AGP 9.0、Kotlin 2.3、Java 17。
- app 模块迁移到 Built-in Kotlin 方式。
- 登录注册流程支持注册后自动登录，移动端可使用受控 QQ dev-login/dev-bind 验证 QQ 登录链路。
- 个人资料页支持自定义头像、个性签名、性别、生日年份和地区资料展示/更新。
- 联系人页支持好友申请、好友通知、同意/拒绝、清理已处理通知、联系人备注修改和在线状态显示。
- 聊天页支持表情、图片发送、普通文件发送、消息引用、引用预览、已读标记和未读状态同步。
- 应用回到前台时会恢复 SignalR 在线状态，减少移动端长久在线却被标记离线的问题。

## 最新验证

- `flutter pub get`：成功。
- `flutter pub outdated`：direct/dev dependencies 均已是最新。
- `flutter analyze --no-fatal-infos --no-fatal-warnings`：成功。
- `flutter build apk --debug`：成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter test`：未运行成功，因为项目当前没有 `test/` 目录。
- 移动端聊天、联系人和资料功能使用后端现有 API：`/contacts/friend-requests`、`/contacts/{id}/display-name`、`/chat/upload`、`/chat/messages/{id}/read`、`/auth/profile` 和 `/auth/upload-avatar`。

## 注意事项

- 普通 `flutter analyze` 仍会报告大量历史 lint，包括 `avoid_print`、命名风格、`withOpacity` deprecated、async context 等。
- `flutter_webrtc` 当前仍应用 Kotlin Gradle Plugin，Flutter 会提示未来版本可能需要上游插件迁移到 Built-in Kotlin。
- 移动端真实 QQ OAuth 仍需要平台侧跳转能力；当前移动端使用后端受控 dev-login 验证账号资料同步和绑定逻辑。
