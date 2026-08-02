# Website Progress

## 已完成

- 升级 React、React DOM、React Router、Ant Design、Vite、ESLint、MobX、Axios、SignalR Client 等依赖。
- 重新生成 `node_modules` 和 npm lock 状态。
- 保留 `typescript@6.0.3`，原因是当前最新版 `typescript@7.0.2` 不满足 `typescript-eslint@8.65.0` 的 peer dependency。

## 最新验证

- `npm install`：成功。
- `npm run build`：成功。
- Vite 生产构建输出 `dist/`，存在单 chunk 超过 500 kB 的提示，不阻断构建。

## 后续建议

- 后续可按路由拆分页面代码，降低首包大小。
- 等 `typescript-eslint` 支持 TypeScript 7 后再升级 TypeScript。
