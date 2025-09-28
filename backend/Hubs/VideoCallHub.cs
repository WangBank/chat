using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;

namespace VideoCallAPI.Hubs
{
    public class VideoCallHub : Hub
    {
        private readonly IWebRTCService _webRTCService;
        private readonly IUserService _userService;
        private readonly ILogger<VideoCallHub> _logger;
        private static readonly Dictionary<string, int> _connectionUserMap = new();

        public VideoCallHub(
            IWebRTCService webRTCService,
            IUserService userService,
            ILogger<VideoCallHub> logger)
        {
            _webRTCService = webRTCService;
            _userService = userService;
            _logger = logger;
        }

        public override async Task OnConnectedAsync()
        {
            _logger.LogInformation("客户端连接: {connection_id}", Context.ConnectionId);
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var connectionId = Context.ConnectionId;
            if (_connectionUserMap.TryGetValue(connectionId, out var userId))
            {
                _connectionUserMap.Remove(connectionId);
                _logger.LogInformation("用户断开连接: {user_id}, 连接: {connection_id}", userId, connectionId);
            }
            await base.OnDisconnectedAsync(exception);
        }

        // 用户认证
        public async Task Authenticate(int userId)
        {
            _connectionUserMap[Context.ConnectionId] = userId;
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
            _logger.LogInformation("用户认证: {user_id}, 连接: {connection_id}", userId, Context.ConnectionId);
        }

        // 发起通话
        public async Task InitiateCall(InitiateCallDto request)
        {
            try
            {
                var callerId = GetCurrentUserId();
                if (callerId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                var session = await _webRTCService.CreateSessionAsync(callerId.Value, request.receiver_id, request.call_type);
                
                // 通知接收者
                var caller = await _userService.GetUserByIdAsync(callerId.Value);
                var receiver = await _userService.GetUserByIdAsync(request.receiver_id);
                
                if (caller != null && receiver != null)
                {
                    await Clients.Group($"user_{request.receiver_id}").SendAsync("IncomingCall", new
                    {
                        call_id = session.call_id,
                        caller = new
                        {
                            id = caller.id,
                            username = caller.username,
                            email = caller.email,
                            nickname = caller.nickname,
                            avatar_path = caller.avatar_path,
                            is_online = caller.is_online,
                            last_login_at = caller.last_login_at,
                            created_at = caller.created_at,
                            updated_at = caller.updated_at
                        },
                        receiver = new
                        {
                            id = receiver.id,
                            username = receiver.username,
                            email = receiver.email,
                            nickname = receiver.nickname,
                            avatar_path = receiver.avatar_path,
                            is_online = receiver.is_online,
                            last_login_at = receiver.last_login_at,
                            created_at = receiver.created_at,
                            updated_at = receiver.updated_at
                        },
                        call_type = request.call_type,
                        status = 1, // Initiated
                        start_time = session.start_time
                    });
                }

                _logger.LogInformation("发起通话: {call_id}, 呼叫者: {caller_id}, 接收者: {receiver_id}", 
                    session.call_id, callerId, request.receiver_id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发起通话失败");
                await Clients.Caller.SendAsync("CallError", "发起通话失败");
            }
        }

        // 应答通话
        public async Task AnswerCall(AnswerCallDto request)
        {
            try
            {
                var userId = GetCurrentUserId();
                if (userId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                if (request.accept)
                {
                    var success = await _webRTCService.AcceptCallAsync(request.call_id, userId.Value);
                    if (success)
                    {
                        var session = await _webRTCService.GetSessionAsync(request.call_id);
                        if (session != null)
                        {
                            // 通知呼叫者通话被接受
                            await Clients.Group($"user_{session.caller_id}").SendAsync("CallAccepted", new
                            {
                                call_id = request.call_id,
                                receiver_id = userId
                            });

                            _logger.LogInformation("通话被接受: {call_id}, 接收者: {user_id}", request.call_id, userId);
                        }
                    }
                }
                else
                {
                    var success = await _webRTCService.RejectCallAsync(request.call_id, userId.Value);
                    if (success)
                    {
                        var session = await _webRTCService.GetSessionAsync(request.call_id);
                        if (session != null)
                        {
                            // 通知呼叫者通话被拒绝
                            await Clients.Group($"user_{session.caller_id}").SendAsync("CallRejected", new
                            {
                                call_id = request.call_id,
                                receiver_id = userId
                            });

                            _logger.LogInformation("通话被拒绝: {call_id}, 接收者: {user_id}", request.call_id, userId);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "应答通话失败");
                await Clients.Caller.SendAsync("CallError", "应答通话失败");
            }
        }

        // 结束通话
        public async Task EndCall(string callId)
        {
            // 获取当前用户ID（按你的现有实现）
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                await Clients.Caller.SendAsync("Error", new { message = "Unauthorized" });
                return;
            }
        // 先广播，再清理，避免被动端漏消息
        await Clients.Group($"call_{callId}").SendAsync("CallEnded", new
        {
            call_id = callId,
            EndedBy = /* 你的当前用户ID */ userId.Value
        });

        var success = await _webRTCService.EndCallAsync(callId, userId.Value);
        if (!success)
        {
            await Clients.Caller.SendAsync("Error", new { message = "End call failed" });
            return;
        }

        // 可选：移除当前连接出通话组或发到用户组兜底
        // await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"call_{callId}");

        // 可选：如需补发到用户组（防止通话组成员异常）可在清理前缓存两端ID并发送
        // await Clients.Group($"user_{callerId}").SendAsync("CallEnded", new { call_id = callId, EndedBy = userId.Value });
        // await Clients.Group($"user_{receiverId}").SendAsync("CallEnded", new { call_id = callId, EndedBy = userId.Value });
        }

        // WebRTC 信令消息
        public async Task SendWebRTCMessage(WebRTCMessage message)
        {
            try
            {
                var userId = GetCurrentUserId();
                if (userId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                message.sender_id = userId.Value;
                await _webRTCService.SendMessageAsync(message);

                var session = await _webRTCService.GetSessionAsync(message.call_id);
                if (session != null)
                {
                    // 转发消息给通话中的其他用户
                    var targetUserId = message.sender_id == session.caller_id ? session.receiver_id : session.caller_id;
                    await Clients.Group($"user_{targetUserId}").SendAsync("WebRTCMessage", message);

                    _logger.LogDebug("转发WebRTC消息: {call_id}, 类型: {type}, 从: {sender_id}, 到: {TargetUserId}", 
                        message.call_id, message.type, message.sender_id, targetUserId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送WebRTC消息失败");
                await Clients.Caller.SendAsync("CallError", "发送WebRTC消息失败");
            }
        }

        // 加入通话
        public async Task JoinCall(string callId)
        {
            try
            {
                var userId = GetCurrentUserId();
                if (userId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                await _webRTCService.ConnectUserAsync(callId, userId.Value, Context.ConnectionId);

                // 将当前连接加入 SignalR 通话组，确保可接收 CallEnded 广播
                await Groups.AddToGroupAsync(Context.ConnectionId, $"call_{callId}");
                _logger.LogInformation("加入SignalR组: call_{callId}, 用户: {user_id}, 连接: {connection_id}", callId, userId, Context.ConnectionId);

                await Clients.Caller.SendAsync("JoinedCall", new { call_id = callId, user_id = userId });

                _logger.LogInformation("用户加入通话: {call_id}, 用户: {user_id}", callId, userId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "加入通话失败");
                await Clients.Caller.SendAsync("CallError", "加入通话失败");
            }
        }

        // 离开通话
        public async Task LeaveCall(string callId)
        {
            try
            {
                var userId = GetCurrentUserId();
                if (userId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                await _webRTCService.DisconnectUserAsync(callId, userId.Value);

                // 将当前连接移出 SignalR 通话组
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"call_{callId}");
                _logger.LogInformation("离开SignalR组: call_{callId}, 用户: {user_id}, 连接: {connection_id}", callId, userId, Context.ConnectionId);

                await Clients.Caller.SendAsync("LeftCall", new { call_id = callId, user_id = userId });

                _logger.LogInformation("用户离开通话: {call_id}, 用户: {user_id}", callId, userId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "离开通话失败");
                await Clients.Caller.SendAsync("CallError", "离开通话失败");
            }
        }

        private int? GetCurrentUserId()
        {
            var connectionId = Context.ConnectionId;
            return _connectionUserMap.TryGetValue(connectionId, out var userId) ? userId : null;
        }
    }
}
