# Forever Love Chat Progress

## 已完成

- Flutter SDK 升级到 `3.44.8`，Dart 升级到 `3.12.2`。
- 后端目标框架保持并校验为 `.NET 10`，C# 设置为 latest。
- 后端 NuGet 包升级到当前可用最新版。
- Web 客户端依赖升级到当前可解析最新版。
- 后端数据库从 SQLite 切换到 PostgreSQL。
- 使用 Docker `postgres:latest` 完成数据库 migration 和 API smoke test。
- 清理项目 Markdown 文档结构，每个项目保留 `README.md` 和 `PROGRESS.md`。

## 最新验证

- Backend：`dotnet build` 成功，`dotnet ef database update` 成功。
- Backend API：注册、登录、联系人、消息核心流程均返回 200。
- Website：`npm run build` 成功。
- Flutter：`flutter build apk --debug` 成功。

## 当前遗留

- TypeScript 7 暂未采用，因为 `typescript-eslint@8.65.0` 还限制 TypeScript `<6.1.0`。
- Flutter 普通 analyze 仍有历史 lint；非 fatal analyze 已通过。
- `flutter_webrtc` 仍触发 Flutter 的上游 KGP future warning。
