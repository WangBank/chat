# Forever Love Chat Backend

后端是基于 ASP.NET Core 的即时通讯 API 服务，提供用户认证、联系人、聊天、通话、管理员接口和 SignalR WebRTC 信令。

## 技术栈

- .NET 10 / C# latest
- ASP.NET Core Web API
- Entity Framework Core 10
- Npgsql / PostgreSQL
- SignalR
- JWT Bearer
- BCrypt.Net-Next
- Serilog
- Swashbuckle / OpenAPI

## 本地数据库

开发环境使用 Docker PostgreSQL：

```bash
docker run --name foreverlove-chat-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=foreverlove_chat_dev \
  -p 17132:5432 \
  -d postgres:latest
```

默认连接串位于 `appsettings.Development.json`：

```text
Host=localhost;Port=17132;Database=foreverlove_chat_dev;Username=postgres;Password=postgres
```

生产默认连接串位于 `appsettings.json`，也可以通过环境变量 `ConnectionStrings__DefaultConnection` 覆盖。

## 开发命令

```bash
dotnet restore
dotnet build
dotnet ef database update
ASPNETCORE_ENVIRONMENT=Development dotnet run
```

服务默认监听 `http://localhost:17101`，Swagger UI 位于 `http://localhost:17101/swagger`。

## Docker 一键部署

仓库根目录提供 API Docker 部署脚本，会自动创建 Docker network、确认 PostgreSQL 容器、构建 API 镜像、停止旧 API 容器或占用 API 端口的本地服务，并启动新容器：

```bash
./deploy-api-docker.sh
```

默认访问地址：

```text
http://localhost:17101/swagger
```

常用覆盖项：

```bash
API_PORT=17103 ./deploy-api-docker.sh
API_IMAGE=foreverlove-chat-api:prod API_CONTAINER=foreverlove-chat-api-prod ./deploy-api-docker.sh
```

如果使用外部 PostgreSQL，不让脚本管理数据库容器：

```bash
API_ENVIRONMENT=Production \
POSTGRES_HOST=host.docker.internal \
POSTGRES_CONTAINER_PORT=17132 \
SKIP_POSTGRES=1 \
./deploy-api-docker.sh
```

## 数据库迁移

当前 provider 是 PostgreSQL：

```bash
dotnet ef migrations add <MigrationName>
dotnet ef database update
```

应用启动时会执行 `Database.MigrateAsync()`，首次启动会自动应用未执行的 migration，并创建默认 `admin` 账号记录。

## API 摘要

- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/change-password` - 修改密码
- `GET /api/auth/profile` - 获取用户信息
- `GET /api/contacts` - 获取联系人列表
- `POST /api/contacts` - 兼容旧客户端，发送好友申请，不直接添加联系人
- `GET /api/contacts/friend-requests` - 获取好友申请
- `POST /api/contacts/friend-requests` - 发送好友申请
- `PATCH /api/contacts/friend-requests/{requestId}` - 同意或拒绝好友申请
- `DELETE /api/contacts/{id}` - 删除联系人
- `PATCH /api/contacts/{id}/block` - 屏蔽或取消屏蔽联系人
- `PATCH /api/contacts/{id}/display-name` - 修改联系人备注
- `POST /api/chat/send` - 发送消息
- `GET /api/chat/history/{contactId}` - 获取聊天记录
- `GET /api/chat/unread` - 获取未读消息
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间
- `GET /api/admin/online-users` - 管理员查看在线用户
- `GET /api/admin/users` - 管理员查看用户

## 日志

Serilog 同时输出控制台和文件：

- 日志目录：`logs/`
- 文件格式：`videocall-YYYYMMDD.log`
- 滚动策略：每天一个文件
- 保留数量：30 个文件

常用命令：

```bash
tail -f logs/videocall-*.log
grep "ERR" logs/videocall-*.log
```

## 功能校验

基础 smoke test：

```bash
curl -s http://localhost:17101/swagger/v1/swagger.json
curl -s -X POST http://localhost:17101/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","email":"demo@example.com","password":"Password123!"}'
```

完整进度和最新验证记录见 [PROGRESS.md](PROGRESS.md)。
