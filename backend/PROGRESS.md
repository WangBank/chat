# Backend Progress

## 已完成

- 升级目标框架到 `net10.0`，并设置 C# `LangVersion=latest`。
- 修正 `global.json`，使用本机有效 SDK `10.0.101`，roll-forward 到 latest feature。
- NuGet 顶层包已升级到当前可用最新版：EF Core / ASP.NET Core 运行时包 `10.0.12`、`System.IdentityModel.Tokens.Jwt` `8.23.0`、Npgsql `10.0.3`、Serilog `10.0.0`、Swashbuckle `10.2.3`、SIPSorcery `10.0.16`。
- 全局 `dotnet-ef` 工具从 `10.0.10` 升级到 `10.0.12`，与项目 EF Core 运行时版本对齐。
- 数据库 provider 已从 SQLite 切换为 PostgreSQL。
- 移除旧 SQLite migration，生成 `InitPostgres` migration。
- 启动时从 `EnsureCreated()` 改为 `MigrateAsync()`。
- 用 Docker `postgres:latest` 在 `localhost:17132` 完成 migration 和 API smoke test。
- 移除无必要的 `Newtonsoft.Json` using，改用 `System.Text.Json`。
- 注册接口已改为注册成功后自动登录并返回 token 与用户资料。
- QQ OAuth 登录/绑定已接入，支持 QQ dev-login，登录后同步昵称、头像、性别、国家、省份、城市、生日年份和接口返回的签名。
- 邮件找回密码已接入，支持发送重置邮件和 token 重置密码。
- 好友申请流程已替代旧的直接添加联系人逻辑，支持好友通知、同意/拒绝、清理已处理通知和联系人备注。
- 单聊和群聊消息支持图片/文件上传、消息引用快照、已读标记、未读列表、聊天列表和历史记录。
- 群聊、收藏和管理员用户管理接口已补齐。
- 敏感词过滤已集成开源词库，并覆盖用户名、昵称、签名、消息、群聊和收藏等输入。

## 最新验证

- `dotnet list package --outdated`：无可更新包。
- `dotnet build`：成功，0 警告，0 错误。
- `dotnet ef database update`：成功应用 PostgreSQL migration。
- Docker PostgreSQL 表验证：`users`、`Contacts`、`ChatMessages`、`CallHistories`、`Rooms`、`RoomParticipants`、`__EFMigrationsHistory` 已创建。
- HTTP smoke test：注册、登录、添加联系人、获取联系人、发送消息、读取聊天记录均返回 200。
- 2026-08-07：`dotnet build backend/VideoCallAPI.csproj` 成功，0 警告，0 错误。
- 2026-08-07：QQ dev-login 烟测确认返回头像、签名、性别、生日年份、国家、省份和城市字段。
- 2026-09-19：`dotnet build` 成功，0 警告 0 错误；`dotnet list package --outdated` 无更新。
- 2026-09-19：在全新 PostgreSQL 数据库上 `dotnet ef database update` 成功应用 13 个 migration，创建 15 张表。
- 2026-09-19：HTTP 冒烟 33 项通过（健康检查、版本、WebRTC 配置、登录、错误密码拒绝、未授权 401、资料、联系人、好友申请创建/通知/同意、单聊发送与历史、消息已读、群聊发送与历史、收藏创建与查询、通话记录、注册邮箱验证码 + 自动登录）。

## 注意事项

- 开发连接串默认使用 Docker 端口 `17132`。
- 生产环境建议通过 `ConnectionStrings__DefaultConnection` 注入真实 PostgreSQL 连接串。
- 默认 `admin` 账号会在首次启动时创建，首次使用后应修改密码。
- QQ 互联标准资料接口不返回完整生日和 QQ 个性签名，只能同步 `year` 年份和接口实际返回的字段。
- 发布前数据库备份由仓库根目录 `scripts/deploy-local.ps1` 执行，不属于后端启动迁移；恢复流程见根目录 `DEPLOYMENT.md`。
- 已生成的 migration snapshot / Designer 文件里的 `ProductVersion` 注释仍写着 `10.0.11`，属于 EF Core 生成文件的元数据；下次执行 `dotnet ef migrations add` 时会自动更新为当前运行时版本。
- 本机 .NET SDK 为 `10.0.101`，上游最新 10.x SDK 为 `10.0.401`；`global.json` 使用 `rollForward: latestFeature`，安装更高功能带 SDK 后会自动采用，无需改项目文件。
