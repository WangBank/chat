using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.Collections.Concurrent;

namespace VideoCallAPI.Hubs
{
    public class VideoCallHub : Hub
    {
        private readonly IWebRTCService _webRTCService;
        private readonly IUserService _userService;
        private readonly ILogger<VideoCallHub> _logger;
        private readonly IServiceScopeFactory _serviceScopeFactory;
        private readonly IHubContext<VideoCallHub> _hubContext;
        private static readonly ConcurrentDictionary<string, int> _connectionUserMap = new();
        private static readonly ConcurrentDictionary<int, CancellationTokenSource> _pendingOfflineTimers = new();

        public VideoCallHub(
            IWebRTCService webRTCService,
            IUserService userService,
            ILogger<VideoCallHub> logger,
            IServiceScopeFactory serviceScopeFactory,
            IHubContext<VideoCallHub> hubContext)
        {
            _webRTCService = webRTCService;
            _userService = userService;
            _logger = logger;
            _serviceScopeFactory = serviceScopeFactory;
            _hubContext = hubContext;
        }

        public override async Task OnConnectedAsync()
        {
            _logger.LogInformation("客户端连接: {connection_id}", Context.ConnectionId);
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var connectionId = Context.ConnectionId;
            if (_connectionUserMap.TryRemove(connectionId, out var userId))
            {
                if (exception != null)
                {
                    _logger.LogError(exception, "用户异常断开连接: UserId={UserId}, ConnectionId={ConnectionId}", userId, connectionId);
                }
                else
                {
                    _logger.LogInformation("用户正常断开连接: UserId={UserId}, ConnectionId={ConnectionId}", userId, connectionId);
                }

                if (!_connectionUserMap.Values.Contains(userId))
                {
                    ScheduleOffline(userId);
                }
            }
            else if (exception != null)
            {
                _logger.LogError(exception, "未知用户异常断开连接: ConnectionId={ConnectionId}", connectionId);
            }
            await base.OnDisconnectedAsync(exception);
        }

        // 用户认证
        public async Task Authenticate(int userId)
        {
            try
            {
                CancelPendingOffline(userId);
                _connectionUserMap[Context.ConnectionId] = userId;
                await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
                await _userService.UpdateHeartbeatAsync(userId);
                await BroadcastOnlineStatusAsync(userId, true);
                _logger.LogInformation("用户认证成功: UserId={UserId}, ConnectionId={ConnectionId}", userId, Context.ConnectionId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用户认证失败: UserId={UserId}, ConnectionId={ConnectionId}", userId, Context.ConnectionId);
                throw;
            }
        }

        // 客户端心跳。超过 OnlineStatusPolicy.HeartbeatTimeout 没有心跳即视为离线。
        public async Task Heartbeat()
        {
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                await Clients.Caller.SendAsync("CallError", "用户未认证");
                return;
            }

            CancelPendingOffline(userId.Value);
            await _userService.UpdateHeartbeatAsync(userId.Value);
            await BroadcastOnlineStatusAsync(userId.Value, true);
        }

        private Task BroadcastOnlineStatusAsync(int userId, bool isOnline)
        {
            return Clients.All.SendAsync("UserOnlineStatusChanged", new
            {
                user_id = userId,
                is_online = isOnline
            });
        }

        private void ScheduleOffline(int userId)
        {
            CancelPendingOffline(userId);

            var cancellationTokenSource = new CancellationTokenSource();
            _pendingOfflineTimers[userId] = cancellationTokenSource;

            _logger.LogInformation(
                "用户无活跃连接，延迟确认离线: UserId={UserId}, DelaySeconds={DelaySeconds}",
                userId,
                OnlineStatusPolicy.OfflineGracePeriod.TotalSeconds);

            _ = MarkOfflineAfterGracePeriodAsync(
                userId,
                cancellationTokenSource,
                _serviceScopeFactory,
                _hubContext,
                _logger);
        }

        private static void CancelPendingOffline(int userId)
        {
            if (_pendingOfflineTimers.TryRemove(userId, out var cancellationTokenSource))
            {
                cancellationTokenSource.Cancel();
            }
        }

        private static async Task MarkOfflineAfterGracePeriodAsync(
            int userId,
            CancellationTokenSource cancellationTokenSource,
            IServiceScopeFactory serviceScopeFactory,
            IHubContext<VideoCallHub> hubContext,
            ILogger<VideoCallHub> logger)
        {
            try
            {
                await Task.Delay(OnlineStatusPolicy.OfflineGracePeriod, cancellationTokenSource.Token);

                if (cancellationTokenSource.IsCancellationRequested || _connectionUserMap.Values.Contains(userId))
                {
                    return;
                }

                using var scope = serviceScopeFactory.CreateScope();
                var userService = scope.ServiceProvider.GetRequiredService<IUserService>();
                await userService.MarkOfflineAsync(userId);
                await hubContext.Clients.All.SendAsync("UserOnlineStatusChanged", new
                {
                    user_id = userId,
                    is_online = false
                });

                logger.LogInformation("用户已确认离线: UserId={UserId}", userId);
            }
            catch (OperationCanceledException)
            {
                logger.LogDebug("用户延迟离线已取消: UserId={UserId}", userId);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "延迟标记用户离线失败: UserId={UserId}", userId);
            }
            finally
            {
                RemovePendingOfflineTimer(userId, cancellationTokenSource);
            }
        }

        private static void RemovePendingOfflineTimer(int userId, CancellationTokenSource cancellationTokenSource)
        {
            var pair = new KeyValuePair<int, CancellationTokenSource>(userId, cancellationTokenSource);
            ((ICollection<KeyValuePair<int, CancellationTokenSource>>)_pendingOfflineTimers).Remove(pair);
            cancellationTokenSource.Dispose();
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
                    var callData = new
                    {
                        call_id = session.call_id,
                        caller = new
                        {
                            id = caller.id,
                            username = caller.username,
                            email = caller.email,
                            display_name = caller.display_name,
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
                            display_name = receiver.display_name,
                            avatar_path = receiver.avatar_path,
                            is_online = receiver.is_online,
                            last_login_at = receiver.last_login_at,
                            created_at = receiver.created_at,
                            updated_at = receiver.updated_at
                        },
                        call_type = request.call_type,
                        status = 1, // Initiated
                        start_time = session.start_time
                    };

                    // 通知接收者
                    await Clients.Group($"user_{request.receiver_id}").SendAsync("IncomingCall", callData);
                    
                    // 同时通知呼叫者（返回call_id等信息）
                    await Clients.Caller.SendAsync("CallInitiated", callData);
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
            try
            {
                // 获取当前用户ID（按你的现有实现）
                var userId = GetCurrentUserId();
                if (!userId.HasValue)
                {
                    _logger.LogWarning("结束通话失败，用户未认证: CallId={CallId}", callId);
                    await Clients.Caller.SendAsync("Error", new { message = "Unauthorized" });
                    return;
                }
                // 先广播，再清理，避免被动端漏消息
                await Clients.Group($"call_{callId}").SendAsync("CallEnded", new
                {
                    call_id = callId,
                    EndedBy = userId.Value
                });

                var success = await _webRTCService.EndCallAsync(callId, userId.Value);
                if (!success)
                {
                    _logger.LogWarning("结束通话失败，通话不存在: CallId={CallId}, UserId={UserId}", callId, userId.Value);
                    await Clients.Caller.SendAsync("Error", new { message = "End call failed" });
                    return;
                }

                _logger.LogInformation("通话已结束: CallId={CallId}, UserId={UserId}", callId, userId.Value);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "结束通话异常: CallId={CallId}", callId);
                await Clients.Caller.SendAsync("CallError", "结束通话失败");
            }
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
