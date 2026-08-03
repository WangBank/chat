# Forever Love Chat Website

Web 客户端是基于 React、Vite、TypeScript、MobX 和 Ant Design 的即时通讯前端，提供登录注册、联系人、聊天、音视频通话和管理员后台页面。

## 技术栈

- React 19
- TypeScript 6.0
- Vite 8
- Ant Design 6
- MobX
- Axios
- Microsoft SignalR Client
- WebRTC

`typescript@7` 当前不满足 `typescript-eslint@8.65.0` 的 peer dependency，因此本项目使用 `typescript@6.0.3` 作为当前可解析的最高版本。

## 开发命令

```bash
npm install
npm run dev
npm run build
```

默认 API 地址位于 `src/config/app.config.ts`：

```text
http://common.wangbank.top:17101
```

本地开发时可通过环境变量覆盖：

```bash
VITE_API_BASE_URL=http://localhost:17101 npm run dev
```

## 功能

- 用户登录、注册、忘记密码
- 随机生成账号密码
- 即时消息聊天
- 语音通话和视频通话
- 联系人管理
- 管理员后台
- 版本号显示

## 项目结构

```text
src/
├── components/      # 组件
├── config/          # 配置
├── pages/           # 页面
├── services/        # API、SignalR、WebRTC 服务
├── stores/          # MobX 状态
└── App.tsx          # 路由入口
```

最新进度和验证记录见 [PROGRESS.md](PROGRESS.md)。
