# Backend Progress

## 已完成

- 升级目标框架到 `net10.0`，并设置 C# `LangVersion=latest`。
- 修正 `global.json`，使用本机有效 SDK `10.0.101`，roll-forward 到 latest feature。
- NuGet 顶层包已升级到当前可用最新版。
- 数据库 provider 已从 SQLite 切换为 PostgreSQL。
- 移除旧 SQLite migration，生成 `InitPostgres` migration。
- 启动时从 `EnsureCreated()` 改为 `MigrateAsync()`。
- 用 Docker `postgres:latest` 在 `localhost:17132` 完成 migration 和 API smoke test。
- 移除无必要的 `Newtonsoft.Json` using，改用 `System.Text.Json`。

## 最新验证

- `dotnet list package --outdated`：无可更新包。
- `dotnet build`：成功，0 警告，0 错误。
- `dotnet ef database update`：成功应用 PostgreSQL migration。
- Docker PostgreSQL 表验证：`users`、`Contacts`、`ChatMessages`、`CallHistories`、`Rooms`、`RoomParticipants`、`__EFMigrationsHistory` 已创建。
- HTTP smoke test：注册、登录、添加联系人、获取联系人、发送消息、读取聊天记录均返回 200。

## 注意事项

- 开发连接串默认使用 Docker 端口 `17132`。
- 生产环境建议通过 `ConnectionStrings__DefaultConnection` 注入真实 PostgreSQL 连接串。
- 默认 `admin` 账号会在首次启动时创建，首次使用后应修改密码。
