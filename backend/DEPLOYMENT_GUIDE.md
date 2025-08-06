# 聊天功能部署指南

## 概述
本文档介绍如何部署和配置新添加的聊天功能。

## 1. 数据库更新

### 自动更新（推荐）
```bash
# 给脚本执行权限
chmod +x update_database.sh

# 运行数据库更新脚本
./update_database.sh
```

### 手动更新
如果自动更新失败，可以手动执行：

```bash
# 备份数据库
cp videocall.db videocall_backup.db

# 运行 SQL 脚本
sqlite3 videocall.db < update_database.sql
```

## 2. 验证数据库结构

检查数据库表是否正确创建：

```bash
sqlite3 videocall.db ".tables"
```

应该看到以下表：
- Users
- Contacts
- CallHistories
- Rooms
- RoomParticipants
- **ChatMessages** (新增)

## 3. 启动后端服务

```bash
# 恢复依赖包
dotnet restore

# 构建项目
dotnet build

# 启动服务
dotnet run
```

## 4. 验证 API 端点

使用以下命令测试新的 API 端点：

### 测试聊天 API
```bash
# 发送消息
curl -X POST "http://localhost:7001/api/chat/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "receiverId": 2,
    "content": "测试消息",
    "type": 1
  }'

# 获取聊天记录
curl -X GET "http://localhost:7001/api/chat/history/2" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 获取未读消息
curl -X GET "http://localhost:7001/api/chat/unread" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 测试联系人 API
```bash
# 修改联系人备注
curl -X PATCH "http://localhost:7001/api/contacts/1/display-name" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '"新备注名"'
```

## 5. Flutter 客户端配置

### 安装依赖
```bash
cd ../flutter_client
flutter pub get
```

### 更新 IP 地址
确保 `lib/config/app_config.dart` 中的 `baseUrl` 使用正确的 IP 地址：

```dart
static String get baseUrl {
  return 'http://YOUR_IP_ADDRESS:7001/api';
}
```

### 重新构建应用
```bash
flutter clean
flutter pub get
flutter run
```

## 6. 功能测试

### 联系人功能
1. 登录应用
2. 进入联系人页面
3. 添加新联系人
4. 修改联系人备注
5. 屏蔽/取消屏蔽联系人
6. 删除联系人

### 聊天功能
1. 从联系人列表选择"发送消息"
2. 发送文本消息
3. 查看聊天记录
4. 验证消息在本地存储

### 通话功能
1. 从联系人列表发起视频通话
2. 从联系人列表发起语音通话
3. 验证通话功能正常

## 7. 故障排除

### 数据库问题
- 确保 SQLite 已安装
- 检查数据库文件权限
- 验证 SQL 脚本语法

### API 问题
- 检查服务是否正常启动
- 验证端口 7001 是否可用
- 检查 CORS 配置

### Flutter 问题
- 确保 IP 地址正确
- 检查网络连接
- 验证依赖包安装

## 8. 性能优化

### 数据库优化
- 聊天消息表已创建索引
- 定期清理旧消息
- 考虑分页加载聊天记录

### API 优化
- 实现消息分页
- 添加消息缓存
- 优化查询性能

## 9. 安全考虑

- 验证用户权限
- 防止 SQL 注入
- 消息内容过滤
- 文件上传限制

## 10. 监控和日志

- 监控 API 响应时间
- 记录错误日志
- 跟踪用户活动
- 数据库性能监控 