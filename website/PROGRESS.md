# Website Progress

## 已完成

- 升级 React 19.3、React DOM 19.3、React Router 7.18.4、Ant Design 6.6.4、MUI 9.4、Vite 8.3.0、ESLint 10.11、MobX 7、Axios 1.20、SignalR Client 10 等依赖。
- `@ant-design/icons` 从部署固定版本 `6.2.5` 升级到 `6.3.4`，并继续保持精确版本固定；`react-router-dom` 同样保持精确固定。
- 重新生成 `node_modules` 和 npm lock 状态。
- 保留 `typescript@6.0.3`，原因是当前最新版 `typescript@7.0.2` 不满足 `typescript-eslint@8.70.0` 的 peer dependency（要求 `<6.1.0`）。
- 登录页补齐 QQ 风格登录入口、QQ 回调首屏加载态、授权中禁用输入和 QQ dev-login 资料同步。
- 聊天页补齐 QQ 风格会话列表、消息气泡、输入框、表情面板、GIF 动态表情、图片/文件发送和历史记录入口。
- GIF 动态表情引入 `microsoft/fluentui-emoji-animated` 数据，当前共 354 个，表情、动物自然和旅行地点分类各取 100 个。
- 好友页补齐好友申请通知、添加好友验证消息、联系人备注、好友分组维护、好友管理器搜索和在线状态展示。
- 单聊和群聊支持消息引用、引用预览、收藏消息、群聊资料页和群聊历史记录。
- 收藏页支持聊天、媒体、文件、链接和笔记，支持搜索、类型筛选和后端不可用时本地兜底。
- APK 下载改为同域 `/download/android`（生产构建，`VITE_APK_DOWNLOAD_URL` 可覆盖）；`server.mjs` 新增 `/download/android` 与 `/download/android-version.json` 路由，支持 ETag、断点续传（Range），本地文件缺失时 302 回退 GitHub Release。

## 最新验证

- `npm install`：成功。
- `npm run build`：成功。
- Vite 生产构建输出 `dist/`，存在单 chunk 超过 500 kB 的提示，不阻断构建。
- 2026-08-07：`npm run build` 成功，QQ 登录加载态和资料同步相关类型检查通过。
- 2026-09-19：`npm install` 升级成功（新增 10 个、移除 2 个、变更 59 个包）；`npm run build`（`tsc -b` + Vite 8.3.0）成功；`npm run lint` 0 error / 5 条既有 warning；`npm run test:contracts` 两项契约检查通过。
- 2026-09-20：APK 下载链路本地验证：`/download/android` 返回 200 + 附件头 + 94035036 字节，SHA256 与清单一致；`Range` 返回 206、非法 Range 返回 416、`If-None-Match` 返回 304；文件缺失时两个路由均 302 到 GitHub Release；新增的 APK 下载契约断言随 `npm run test:contracts` 通过。

## 后续建议

- 后续可按路由拆分页面代码，降低首包大小。
- 等 `typescript-eslint` 支持 TypeScript 7 后再升级 TypeScript。
- Web 聊天页功能集中在单个页面文件，后续如果继续扩展群资料、收藏和好友管理，建议按面板拆分组件降低维护成本。
