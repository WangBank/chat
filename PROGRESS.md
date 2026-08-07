# Forever Love Chat Progress

## 已完成

- Flutter SDK 升级到 `3.44.8`，Dart 升级到 `3.12.2`。
- 后端目标框架保持并校验为 `.NET 10`，C# 设置为 latest。
- 后端 NuGet 包升级到当前可用最新版。
- Web 客户端依赖升级到当前可解析最新版。
- 后端数据库从 SQLite 切换到 PostgreSQL。
- 使用 Docker `postgres:latest` 完成数据库 migration 和 API smoke test。
- 清理项目 Markdown 文档结构，每个项目保留 `README.md` 和 `PROGRESS.md`。
- 账号体系补齐 QQ 登录/绑定、注册后自动登录、忘记密码邮件、头像、个性签名和个人资料字段同步。
- 好友能力补齐好友申请/通知、联系人备注、Web 端好友分组维护、在线状态和多端资料展示。
- 聊天能力补齐图片文件上传、表情/GIF、消息引用、已读未读、聊天列表、聊天历史和群聊历史。
- Web 端收藏能力支持聊天、媒体、文件、链接和笔记，支持搜索和类型筛选。
- 后端集成开源敏感词库并在用户名、昵称、签名、消息、群聊、收藏等输入链路提示敏感内容。
- CI/CD 发布脚本新增 PostgreSQL 发布前自动备份，默认最近两天、每天最多两个备份。

## 最新验证

- Backend：`dotnet build` 成功，`dotnet ef database update` 成功。
- Backend API：注册、登录、联系人、消息核心流程均返回 200。
- Website：`npm run build` 成功。
- Flutter：`flutter build apk --debug` 成功。
- 2026-08-07：QQ dev-login 烟测返回头像、签名、性别、生日年份、国家、省份和城市字段。
- 2026-08-07：发布前数据库备份逻辑已写入 CI/CD 脚本，静态空白检查通过；运行级验证需在 Windows self-hosted runner 上执行。

## 当前遗留

- TypeScript 7 暂未采用，因为 `typescript-eslint@8.65.0` 还限制 TypeScript `<6.1.0`。
- Flutter 普通 analyze 仍有历史 lint；非 fatal analyze 已通过。
- `flutter_webrtc` 仍触发 Flutter 的上游 KGP future warning。
- QQ 互联 `get_user_info` 标准接口不返回完整生日和 QQ 个性签名，当前只能同步接口实际返回的资料字段。
