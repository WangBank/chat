# Flutter 视频通话与联系人管理项目

## 项目简介
本项目基于 Flutter，面向 Android 平台，包含视频通话和联系人信息管理两大核心功能。

## 功能规划
- 视频通话：集成第三方视频通话 SDK（如 agora_rtc_engine、flutter_webrtc 等）
- 联系人管理：本地或云端存储联系人信息，支持增删查改

## 快速开始
1. 确保已安装 Flutter SDK 并配置好 Android 环境
2. 进入项目根目录，执行：
   ```powershell
   flutter pub get
   flutter run
   ```

## 依赖建议
- 视频通话：`agora_rtc_engine` 或 `flutter_webrtc`
- 联系人管理：`sqflite` 或 `cloud_firestore`

## 备注
如遇依赖包下载失败，请检查网络或配置国内镜像。
