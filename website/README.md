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
https://chat.wangbank.top
```

本地开发时可通过环境变量覆盖：

```bash
VITE_API_BASE_URL=http://localhost:17101 npm run dev
```

## 功能

- 用户登录、注册、忘记密码和注册后自动进入系统
- QQ 登录入口、QQ 回调加载遮罩、QQ 资料同步和 QQ 绑定入口
- 随机生成账号密码
- QQ 风格聊天工作台、会话列表、消息气泡、在线状态和未读状态
- 单聊和群聊即时消息、消息引用、聊天历史、群聊历史和聊天记录筛选
- 表情面板、常用表情、GIF 动态表情和搜索；GIF 表情来自 `microsoft/fluentui-emoji-animated`，当前引入 354 个 MIT 许可动态表情，其中表情、动物自然和旅行地点分类各取 100 个
- 图片、GIF 和文件发送，文件通过后端 `/api/chat/upload` 存储到 `/chat-files`
- 语音通话和视频通话
- 联系人管理、好友申请通知、添加好友验证消息、联系人备注和好友分组维护
- 群聊列表、群聊资料、群消息、群成员和群聊历史记录
- 收藏聊天、媒体、文件、链接和笔记，支持搜索和类型筛选
- 管理员后台、用户管理、在线用户查看和用户密码重置
- 版本号显示

## 登录和资料

QQ 授权回调返回登录页时，页面会立即进入 `QQ 授权中` 加载态，禁用账号密码输入、注册切换、随机账号和第三方登录按钮，避免回调处理期间继续输入。登录成功后会写入本地 token 和用户资料，并建立 SignalR 连接。

Web 端会展示后端返回的自定义头像、个性签名、性别、生日年份、国家、省份和城市。真实 QQ OAuth 会同步 QQ 昵称、头像、性别、国家、省份、城市和 `year` 年份；完整生日和 QQ 个性签名取决于 QQ 接口是否返回。

## 聊天体验

聊天页支持单聊和群聊两种会话。发送内容可以是文本、表情、GIF 动态表情、图片、文件和语音类型；引用消息会保存发送者、内容、类型和文件路径快照，即使原消息后续变化，引用卡片仍能显示当时的摘要。

历史记录弹窗支持按全部、图片、表情、文件和链接筛选。收藏页支持添加笔记、从消息添加收藏、按类型过滤和搜索；后端不可用时 Web 端会保留本地收藏兜底。

## 项目结构

```text
src/
├── components/      # 组件
├── config/          # 配置
├── data/            # GIF 动态表情数据
├── pages/           # 页面
├── services/        # API、SignalR、WebRTC 服务
├── stores/          # MobX 状态
└── App.tsx          # 路由入口
```

最新进度和验证记录见 [PROGRESS.md](PROGRESS.md)。
