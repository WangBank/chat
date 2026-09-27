# Forever Love Chat 功能说明

Forever Love Chat 是一个跨平台即时通讯系统，包含 ASP.NET Core API、React Web
客户端和 Flutter 移动端客户端。系统通过 REST API 处理业务数据，通过 SignalR
保持在线状态与推送实时事件；语音和视频通话由 API 承担 SFU 媒体转发。

发布、环境变量、Docker、Android APK 和 SFU/TURN 的操作步骤见
[发布流程](DEPLOYMENT.md)。

## 系统组成

| 组件 | 职责 |
| --- | --- |
| `backend/` | API、SignalR Hub、PostgreSQL 数据访问、文件存储、通话记录与 SFU 媒体转发 |
| `website/` | Web 聊天、好友、群聊、收藏、音视频通话、管理员后台与 APK 下载页面 |
| `flutter_client/` | Android/iOS 聊天、联系人、个人资料、实时状态、语音和视频通话、应用更新 |

## 用户与资料

- 用户名或邮箱注册、登录，注册后自动登录。
- 邮箱验证码注册、忘记密码和重置密码。
- QQ OAuth 登录和账号绑定；受控开发环境可启用 QQ dev-login/dev-bind。
- 头像上传和展示；维护昵称、个性签名、性别、生日年份、国家、省份与城市。
- 真实 QQ 授权会同步 QQ 接口实际返回的昵称、头像、性别和地区资料。

## 好友与在线状态

- 搜索用户、发送附带验证消息的好友申请、接受或拒绝申请、清理已处理通知。
- 联系人备注、删除和屏蔽；Web 端支持本地好友分组维护。
- SignalR 推送在线状态，并通过心跳和应用回到前台后的重连维持移动端在线状态。

## 聊天与群聊

- 单聊和群聊支持文本、表情、GIF、图片、文件与语音类型消息。
- 图片和文件上传、预览/下载链接、聊天列表、历史记录、消息已读/未读状态。
- 消息引用会保存发送者、内容、类型和文件路径快照，原消息后续变化不影响引用摘要。
- 群聊支持创建、成员、公告、备注、消息发送和历史记录。
- 历史记录可按全部、图片、表情、文件和链接筛选。

## 收藏与内容安全

- 收藏聊天、媒体、文件、链接和笔记；支持备注、类型筛选、搜索、去重和删除。
- 后端对用户名、资料、好友申请、聊天、群聊和收藏等用户输入执行敏感词检查。
- 上传文件受类型限制，服务端校验外部 URL 与存储路径；接口使用 JWT 鉴权和基础安全响应头。

## 语音与视频通话

- 一对一语音和视频通话，通话状态和历史记录写入后端。
- SignalR 负责来电、接听、拒绝、结束与 WebRTC 信令；网络切换时自动重连并重新认证。
- 双方各自与 API 建立 DTLS-SRTP PeerConnection。API 使用 SIPSorcery 解密收到的 RTP，转发给其他通话方后重新加密；不对音视频做解码或混音。
- 客户端会缓存早到的 ICE 候选、重试短暂丢失的 SFU Offer 和 ICE 信令，并只应用一次 SFU Answer。
- 公网 SFU 必须配置公网 IPv4 和 UDP 媒体端口；受限网络可使用可选 TURN 中继。具体配置见[发布流程](DEPLOYMENT.md#音视频-sfu-与-turn)。

## 管理与可观测性

- 管理员可查看在线用户和分页用户列表，并创建、编辑用户或重置用户密码。
- Swagger/OpenAPI 提供 API 浏览与调试入口。
- Serilog 输出控制台和按日滚动的文件日志；SFU 记录 PeerConnection 状态和转发 RTP 计数，不记录 SDP 凭据或媒体内容。

## 客户端差异

| 能力 | Web | Flutter 移动端 |
| --- | --- | --- |
| 聊天、好友、群聊、收藏 | 支持 | 支持核心聊天、好友和群聊流程 |
| 管理员后台 | 支持 | 不提供 |
| APK 下载 | 产品域名下载页 | 应用内检查更新并按多个下载地址回退 |
| 音视频通话 | 支持 | 支持 |
| QQ 授权 | 浏览器回调登录 | 通过后端登录/绑定链路；真实移动端跳转取决于平台侧能力 |

## API 范围

主要 API 按以下资源分组：

- `/api/auth`：认证、邮箱验证码、QQ 登录/绑定、密码和个人资料。
- `/api/contacts`：联系人、好友申请、备注和屏蔽。
- `/api/chat`：消息、上传、已读/未读、聊天列表和历史记录。
- `/api/groups`：群聊、成员和群消息。
- `/api/favorites`：收藏及笔记。
- `/api/calls`：通话历史和群组通话房间。
- `/api/admin`：管理员用户和在线状态管理。
- `/api/system`：版本、WebRTC ICE 配置和受鉴权保护的 SFU 状态。

本地运行时可通过 `/swagger` 查看与当前代码一致的请求模型和完整接口清单。

## 第三方资源

- 敏感词词库快照来自 [fwwdn/sensitive-stop-words](https://github.com/fwwdn/sensitive-stop-words)，采用 Apache-2.0；许可文本保留在 `backend/Data/sensitive-words/fwwdn-sensitive-stop-words/LICENSE.txt`。
- Web 动态表情来自 Microsoft Fluent UI Animated Emoji，采用 MIT；许可文本保留在 `website/public/stickers/fluent-animated/LICENSE-MIT.txt`。
- Flutter 默认头像由 DiceBear Adventurer API 生成。
