# 简聊 - Web客户端

基于 React + Vite + TypeScript + MobX + Ant Design 构建的即时通讯Web应用。

## 功能特性

- ✅ 用户登录、注册、忘记密码
- ✅ 随机生成账号密码功能
- ✅ 即时消息聊天
- ✅ 语音通话（WebRTC）
- ✅ 视频通话（WebRTC）
- ✅ 联系人管理
- ✅ 管理员后台（查看在线用户、所有用户）
- ✅ 版本号显示

## 技术栈

- **React 19** - UI框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **MobX** - 状态管理
- **Ant Design** - UI组件库
- **SignalR** - 实时通信
- **WebRTC** - 音视频通话

## 开发

### 安装依赖

```bash
npm install
```

### 配置环境变量

复制 `.env.example` 为 `.env` 并修改配置：

```bash
cp .env.example .env
```

### 启动开发服务器

```bash
npm run dev
```

### 构建生产版本

```bash
npm run build
```

## 项目结构

```
src/
├── components/      # 组件
├── config/          # 配置文件
├── pages/           # 页面
├── services/        # 服务层（API、SignalR、WebRTC）
├── stores/          # MobX状态管理
└── App.tsx          # 主应用组件
```

## 版本号

当前版本: 1.0.0

版本号显示在：
- 网站左下角
- 管理后台左下角
- 移动端应用


## 配置Nginx
sudo chmod 777 /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/chat_website /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx