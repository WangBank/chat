# Forever Love Chat Flutter Client

Flutter 客户端提供移动端即时通讯体验，包含登录注册、联系人、聊天、语音通话、视频通话、个人资料和本地存储能力。

## 技术栈

- Flutter 3.44
- Dart 3.12
- Android Gradle Plugin 9
- Gradle 9
- Kotlin 2.3
- Java 17
- flutter_webrtc
- signalr_netcore
- shared_preferences
- sqflite
- provider

## 开发命令

```bash
flutter pub get
flutter run
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --debug
```

也可以从仓库根目录通过 `start.sh` 启动移动端：

```bash
./start.sh android
./start.sh ios
./start.sh mobile
```

Android 未检测到已连接设备时会自动启动第一台可用 Android AVD；iOS 未指定设备时会自动选择第一台受支持的 iOS 设备。也可通过设备选择器或 AVD id 指定目标：

```bash
ANDROID_DEVICE=emulator-5554 ./start.sh android
ANDROID_EMULATOR=Pixel_9_Pro_XL_API_35 ./start.sh android
AUTO_START_ANDROID_EMULATOR=0 ./start.sh android
IOS_DEVICE="iPhone 16 Pro" ./start.sh ios
FLUTTER_DEVICE_CONNECTION=attached ./start.sh mobile
```

## 后端地址

默认后端地址在 `lib/config/app_config.dart`：

```text
http://common.wangbank.top:7001/api
```

本地调试时可改为：

```text
http://localhost:7001/api
```

`start.sh` 会通过 `--dart-define` 注入本地 API 地址，不需要手工改代码。可用环境变量覆盖：

```bash
ANDROID_API_URL=http://10.0.2.2:7001/api
ANDROID_SIGNALR_URL=http://10.0.2.2:7001/videocallhub
IOS_API_URL=http://localhost:7001/api
IOS_SIGNALR_URL=http://localhost:7001/videocallhub
```

如果使用真机访问本机后端，应替换为电脑在局域网中的 IP。

## Android

当前 Android 工程按 Flutter 3.44 模板升级：

- Gradle `9.1.0`
- Android Gradle Plugin `9.0.1`
- Kotlin `2.3.20`
- Java 17
- Built-in Kotlin app 模块配置

`flutter_webrtc` 当前仍会触发 Flutter 的 KGP future warning，这是上游插件行为，当前版本仍可构建。

最新进度和验证记录见 [PROGRESS.md](PROGRESS.md)。
