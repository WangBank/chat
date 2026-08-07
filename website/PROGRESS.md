# Website Progress

## 已完成

- 升级 React、React DOM、React Router、Ant Design、Vite、ESLint、MobX、Axios、SignalR Client 等依赖。
- 重新生成 `node_modules` 和 npm lock 状态。
- 保留 `typescript@6.0.3`，原因是当前最新版 `typescript@7.0.2` 不满足 `typescript-eslint@8.65.0` 的 peer dependency。
- 登录页补齐 QQ 风格登录入口、QQ 回调首屏加载态、授权中禁用输入和 QQ dev-login 资料同步。
- 聊天页补齐 QQ 风格会话列表、消息气泡、输入框、表情面板、GIF 动态表情、图片/文件发送和历史记录入口。
- GIF 动态表情引入 `microsoft/fluentui-emoji-animated` 数据，当前共 354 个，表情、动物自然和旅行地点分类各取 100 个。
- 好友页补齐好友申请通知、添加好友验证消息、联系人备注、好友分组维护、好友管理器搜索和在线状态展示。
- 单聊和群聊支持消息引用、引用预览、收藏消息、群聊资料页和群聊历史记录。
- 收藏页支持聊天、媒体、文件、链接和笔记，支持搜索、类型筛选和后端不可用时本地兜底。

## 最新验证

- `npm install`：成功。
- `npm run build`：成功。
- Vite 生产构建输出 `dist/`，存在单 chunk 超过 500 kB 的提示，不阻断构建。
- 2026-08-07：`npm run build` 成功，QQ 登录加载态和资料同步相关类型检查通过。

## 后续建议

- 后续可按路由拆分页面代码，降低首包大小。
- 等 `typescript-eslint` 支持 TypeScript 7 后再升级 TypeScript。
- Web 聊天页功能集中在单个页面文件，后续如果继续扩展群资料、收藏和好友管理，建议按面板拆分组件降低维护成本。
