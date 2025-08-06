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
            _logger.LogInformation("客户端连接: {ConnectionId}", Context.ConnectionId);
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var connectionId = Context.ConnectionId;
            if (_connectionUserMap.TryGetValue(connectionId, out var userId))
            {
                _connectionUserMap.Remove(connectionId);
                _logger.LogInformation("用户断开连接: {UserId}, 连接: {ConnectionId}", userId, connectionId);
            }
            await base.OnDisconnectedAsync(exception);
        }

        // 用户认证
        public async Task Authenticate(int userId)
        {
            _connectionUserMap[Context.ConnectionId] = userId;
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
            _logger.LogInformation("用户认证: {UserId}, 连接: {ConnectionId}", userId, Context.ConnectionId);
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

                var session = await _webRTCService.CreateSessionAsync(callerId.Value, request.ReceiverId, request.CallType);
                
                // 通知接收者
                await Clients.Group($"user_{request.ReceiverId}").SendAsync("IncomingCall", new
                {
                    CallId = session.CallId,
                    CallerId = callerId,
                    CallType = request.CallType,
                    Timestamp = session.StartTime
                });

                _logger.LogInformation("发起通话: {CallId}, 呼叫者: {CallerId}, 接收者: {ReceiverId}", 
                    session.CallId, callerId, request.ReceiverId);
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

                if (request.Accept)
                {
                    var success = await _webRTCService.AcceptCallAsync(request.CallId, userId.Value);
                    if (success)
                    {
                        var session = await _webRTCService.GetSessionAsync(request.CallId);
                        if (session != null)
                        {
                            // 通知呼叫者通话被接受
                            await Clients.Group($"user_{session.CallerId}").SendAsync("CallAccepted", new
                            {
                                CallId = request.CallId,
                                ReceiverId = userId
                            });

                            _logger.LogInformation("通话被接受: {CallId}, 接收者: {UserId}", request.CallId, userId);
                        }
                    }
                }
                else
                {
                    var success = await _webRTCService.RejectCallAsync(request.CallId, userId.Value);
                    if (success)
                    {
                        var session = await _webRTCService.GetSessionAsync(request.CallId);
                        if (session != null)
                        {
                            // 通知呼叫者通话被拒绝
                            await Clients.Group($"user_{session.CallerId}").SendAsync("CallRejected", new
                            {
                                CallId = request.CallId,
                                ReceiverId = userId
                            });

                            _logger.LogInformation("通话被拒绝: {CallId}, 接收者: {UserId}", request.CallId, userId);
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
                var userId = GetCurrentUserId();
                if (userId == null)
                {
                    await Clients.Caller.SendAsync("CallError", "用户未认证");
                    return;
                }

                var success = await _webRTCService.EndCallAsync(callId, userId.Value);
                if (success)
                {
                    var session = await _webRTCService.GetSessionAsync(callId);
                    if (session != null)
                    {
                        // 通知所有参与者通话结束
                        await Clients.Group($"user_{session.CallerId}").SendAsync("CallEnded", new
                        {
                            CallId = callId,
                            EndedBy = userId
                        });
                        await Clients.Group($"user_{session.ReceiverId}").SendAsync("CallEnded", new
                        {
                            CallId = callId,
                            EndedBy = userId
                        });

                        _logger.LogInformation("通话结束: {CallId}, 结束者: {UserId}", callId, userId);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "结束通话失败");
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

                message.SenderId = userId.Value;
                await _webRTCService.SendMessageAsync(message);

                var session = await _webRTCService.GetSessionAsync(message.CallId);
                if (session != null)
                {
                    // 转发消息给通话中的其他用户
                    var targetUserId = message.SenderId == session.CallerId ? session.ReceiverId : session.CallerId;
                    await Clients.Group($"user_{targetUserId}").SendAsync("WebRTCMessage", message);

                    _logger.LogDebug("转发WebRTC消息: {CallId}, 类型: {Type}, 从: {SenderId}, 到: {TargetUserId}", 
                        message.CallId, message.Type, message.SenderId, targetUserId);
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
                await Clients.Caller.SendAsync("JoinedCall", new { CallId = callId, UserId = userId });

                _logger.LogInformation("用户加入通话: {CallId}, 用户: {UserId}", callId, userId);
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
                await Clients.Caller.SendAsync("LeftCall", new { CallId = callId, UserId = userId });

                _logger.LogInformation("用户离开通话: {CallId}, 用户: {UserId}", callId, userId);
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
