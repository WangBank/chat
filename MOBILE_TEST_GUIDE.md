# 🎉 ForeverLove 手机应用测试指南

## 📋 当前状态
✅ **后端服务器**: 运行在 192.168.0.2:7001  
✅ **认证系统**: JWT 登录功能正常  
✅ **Flutter 配置**: 已配置正确的服务器地址  
✅ **设备**: Android 模拟器 `emulator-5554` 已连接  

## 🚀 快速启动

### 1. 启动后端服务器（如果还未启动）
```bash
cd /Users/wangzhen/codes/ForeverLove/chat/backend
dotnet run
```

### 2. 启动 Flutter 应用
```bash
./start_flutter_app.sh
```
或者手动启动：
```bash
cd /Users/wangzhen/codes/ForeverLove/chat/flutter_client
export PATH="/Users/wangzhen/codes/flutter/flutter/bin:$PATH"
flutter run -d emulator-5554 --hot
```

## 🔐 测试账号
- **用户1**: `testuser1` / `password123`
- **用户2**: `testuser2` / `password123`

## 🧪 功能测试清单

### 登录功能测试
- [ ] 输入正确用户名密码，点击登录
- [ ] 验证登录成功后跳转到主界面
- [ ] 测试错误密码的提示
- [ ] 验证 Token 是否正确保存

### 联系人功能测试
- [ ] 查看联系人列表
- [ ] 搜索联系人功能
- [ ] 添加新联系人
- [ ] 删除联系人

### 视频通话功能测试
- [ ] 发起视频通话
- [ ] 接收视频通话
- [ ] 通话过程中音视频质量
- [ ] 挂断通话功能
- [ ] 切换摄像头（前置/后置）
- [ ] 静音/取消静音功能

### 用户资料功能测试
- [ ] 查看个人资料
- [ ] 修改头像
- [ ] 修改个人信息
- [ ] 在线状态显示

## 🐛 常见问题排查

### 网络连接问题
如果出现 "client exception with socket exception"：
1. 检查手机/模拟器与电脑是否在同一网络
2. 确认服务器地址 `192.168.0.2:7001` 是否正确
3. 运行测试脚本: `./test_mobile_login.sh`

### 登录失败问题
如果登录失败：
1. 确认用户名密码正确
2. 检查后端服务器是否运行
3. 查看 Flutter 应用的网络请求日志

### 视频通话问题
如果视频通话无法建立：
1. 检查摄像头和麦克风权限
2. 确认 WebRTC 插件版本 (0.12.3)
3. 检查 STUN 服务器配置

## 📱 设备测试

### Android 模拟器测试
- 当前已连接: `emulator-5554`
- 系统版本: Android 15 (API 35)

### 物理设备测试
如需在真实手机上测试：
1. 启用开发者模式和 USB 调试
2. 连接手机到电脑
3. 运行 `flutter devices` 确认识别
4. 使用 `flutter run -d <device_id>` 部署

## 🔧 开发调试

### 热重载
应用运行后，修改代码会自动热重载，按 `r` 手动重载。

### 调试日志
在 Flutter 应用中查看：
- 网络请求日志
- 认证状态
- WebRTC 连接状态

### 后端 API 测试
使用测试脚本验证 API：
```bash
./test_mobile_login.sh
```

## 🎯 下一步开发

1. **完善 UI**: 美化登录界面和通话界面
2. **错误处理**: 添加更好的错误提示和网络异常处理
3. **功能扩展**: 群组通话、消息记录等
4. **性能优化**: 优化视频编码和网络传输
5. **安全加固**: HTTPS 支持、Token 刷新机制

---

💡 **提示**: 遇到问题时，先运行 `./test_mobile_login.sh` 检查后端连接，然后查看 Flutter 控制台输出的详细错误信息。
