# Forever Love Chat Progress

## 已完成

- Flutter SDK 升级到 `3.47.5`，Dart 升级到 `3.13.4`。
- 后端目标框架保持并校验为 `.NET 10`，C# 设置为 latest。
- 后端 NuGet 包升级到当前可用最新版（EF Core / ASP.NET Core 运行时包 `10.0.12`、`System.IdentityModel.Tokens.Jwt` `8.23.0`），全局 `dotnet-ef` 工具同步升级到 `10.0.12`。
- Web 客户端依赖升级到当前可解析最新版（React `19.3`、Vite `8.3`、Ant Design `6.6.4`、MUI `9.4`、Axios `1.20`、ESLint `10.11`、TypeScript 保持 `6.0.3`）。
- 后端数据库从 SQLite 切换到 PostgreSQL。
- 使用 Docker `postgres:latest` 完成数据库 migration 和 API smoke test。
- 清理项目 Markdown 文档结构，每个项目保留 `README.md` 和 `PROGRESS.md`。
- 账号体系补齐 QQ 登录/绑定、注册后自动登录、忘记密码邮件、头像、个性签名和个人资料字段同步。
- 好友能力补齐好友申请/通知、联系人备注、Web 端好友分组维护、在线状态和多端资料展示。
- 聊天能力补齐图片文件上传、表情/GIF、消息引用、已读未读、聊天列表、聊天历史和群聊历史。
- Web 端收藏能力支持聊天、媒体、文件、链接和笔记，支持搜索和类型筛选。
- 后端集成开源敏感词库并在用户名、昵称、签名、消息、群聊、收藏等输入链路提示敏感内容。
- CI/CD 发布脚本新增 PostgreSQL 发布前自动备份，默认最近两天、每天最多两个备份。
- APK 国内下载：网站容器新增 `/download/android` 与 `/download/android-version.json` 路由，`scripts/sync-android-release.ps1` 从 GitHub Release 同步并校验 SHA256，`Sync Android APK` workflow 在部署服务器上自动执行；Web 下载按钮与 App 内更新默认走产品域名，GitHub 仅作兜底。

## 最新验证

- Backend：`dotnet build` 成功，`dotnet ef database update` 成功。
- Backend API：注册、登录、联系人、消息核心流程均返回 200。
- Website：`npm run build` 成功。
- Flutter：`flutter build apk --debug` 成功。
- 2026-08-07：QQ dev-login 烟测返回头像、签名、性别、生日年份、国家、省份和城市字段。
- 2026-08-07：发布前数据库备份逻辑已写入 CI/CD 脚本，静态空白检查通过；运行级验证需在 Windows self-hosted runner 上执行。
- 2026-09-19 Backend：`dotnet build` 0 警告 0 错误，`dotnet list package --outdated` 无更新；在全新 PostgreSQL 库上 `dotnet ef database update` 应用 13 个 migration、创建 15 张表；HTTP 冒烟 33 项通过（登录、错误密码拒绝、未授权 401、资料、联系人、好友申请创建/通知/同意、单聊发送与历史、消息已读、群聊发送与历史、收藏、通话记录、邮箱验证码注册 + 自动登录）。
- 2026-09-19 Website：`npm install` + `npm run build`（`tsc -b` + Vite 8.3.0）成功，`npm run lint` 0 error / 5 条既有 warning，`npm run test:contracts` 通过；Headless Chrome 打开生产构建，落地页与图标正常渲染。
- 2026-09-19 Flutter：`flutter pub upgrade`（147 个依赖）、`flutter analyze --no-fatal-infos --no-fatal-warnings` 无 error/warning、`flutter test` 6 项通过、`flutter build web --release` 成功、`flutter build apk --debug` 成功、`flutter build ios --debug --no-codesign` 成功（Flutter 3.47.5 / Dart 3.13.4 + compileSdk 37）。
- 2026-09-20 APK 国内下载：`scripts/sync-android-release.ps1` 实测从 GitHub Release 下载 94035036 字节 APK（约 15 秒）并校验 SHA256 与清单一致；本地起 `server.mjs` 验证 `/download/android` 200/206/304/416 与缺失时 302 回退，下载所得文件 SHA256 与清单一致；Web 构建、lint、契约测试通过；Flutter 更新清单与镜像回退单测 12 项通过。

## 当前遗留

- TypeScript 7 暂未采用，因为 `typescript-eslint@8.70.0` 还限制 TypeScript `<6.1.0`。
- Flutter 普通 analyze 仍有历史 lint；非 fatal analyze 已通过。
- `flutter_webrtc` 仍触发 Flutter 的上游 KGP future warning。
- QQ 互联 `get_user_info` 标准接口不返回完整生日和 QQ 个性签名，当前只能同步接口实际返回的资料字段。
- APK 国内下载依赖部署服务器能访问 GitHub Release（本机实测约 15 秒可下完 94 MB）；若服务器网络受限，可设置仓库变量 `APK_ASSET_MIRROR_PREFIX` 走免费加速镜像。
- `chat.wangbank.top` 当前返回 Cloudflare 502（源站未在线），需要部署主机与隧道恢复后才能线上验证 `/download/android`。
- 已经安装的旧 APK 里编译进的是旧的 GitHub 清单地址，只有安装本次改动之后构建的新 APK 才会走国内更新清单；旧用户需要先通过网页下载按钮（已指向国内地址）安装一次。
