using Microsoft.Extensions.Logging;
using VideoCallAPI.Models;

namespace VideoCallAPI.Services
{
    public class WebRTCService : IWebRTCService
    {
        private readonly ILogger<WebRTCService> _logger;
        private readonly Dictionary<string, WebRTCSession> _sessions = new();
        private readonly Dictionary<string, UserConnection> _userConnections = new();
        private readonly object _lock = new object();

        public WebRTCService(ILogger<WebRTCService> logger)
        {
            _logger = logger;
        }

        public async Task<WebRTCSession> CreateSessionAsync(int callerId, int receiverId, CallType callType)
        {
            var callId = Guid.NewGuid().ToString();
            var session = new WebRTCSession
            {
                CallId = callId,
                CallerId = callerId,
                ReceiverId = receiverId,
                CallType = callType,
                Status = CallStatus.Initiated,
                StartTime = DateTime.UtcNow
            };

            lock (_lock)
            {
                _sessions[callId] = session;
            }

            _logger.LogInformation("创建WebRTC会话: {CallId}, 呼叫者: {CallerId}, 接收者: {ReceiverId}, 类型: {CallType}", 
                callId, callerId, receiverId, callType);

            return await Task.FromResult(session);
        }

        public async Task<WebRTCSession?> GetSessionAsync(string callId)
        {
            lock (_lock)
            {
                return _sessions.TryGetValue(callId, out var session) ? session : null;
            }
        }

        public async Task<bool> EndSessionAsync(string callId)
        {
            lock (_lock)
            {
                if (_sessions.TryGetValue(callId, out var session))
                {
                    session.Status = CallStatus.Ended;
                    session.EndTime = DateTime.UtcNow;
                    _sessions.Remove(callId);
                    
                    // 清理用户连接
                    var userConnections = _userConnections.Values
                        .Where(uc => uc.ConnectionId.StartsWith(callId))
                        .ToList();
                    
                    foreach (var connection in userConnections)
                    {
                        connection.State = WebRTCConnectionState.Closed;
                        connection.DisconnectedAt = DateTime.UtcNow;
                        _userConnections.Remove(connection.ConnectionId);
                    }

                    _logger.LogInformation("结束WebRTC会话: {CallId}", callId);
                    return true;
                }
                return false;
            }
        }

        public async Task SendMessageAsync(WebRTCMessage message)
        {
            var session = await GetSessionAsync(message.CallId);
            if (session != null)
            {
                lock (_lock)
                {
                    session.MessageHistory.Add(message);
                }

                _logger.LogDebug("发送WebRTC消息: {CallId}, 类型: {Type}, 发送者: {SenderId}", 
                    message.CallId, message.Type, message.SenderId);
            }
        }

        public async Task<List<WebRTCMessage>> GetSessionMessagesAsync(string callId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    return session.MessageHistory.ToList();
                }
            }
            return new List<WebRTCMessage>();
        }

        public async Task ConnectUserAsync(string callId, int userId, string connectionId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    session.UserConnections[userId] = connectionId;
                    
                    var userConnection = new UserConnection
                    {
                        UserId = userId,
                        ConnectionId = connectionId,
                        State = WebRTCConnectionState.Connecting,
                        ConnectedAt = DateTime.UtcNow
                    };
                    
                    _userConnections[connectionId] = userConnection;
                }

                _logger.LogInformation("用户连接: {CallId}, 用户: {UserId}, 连接: {ConnectionId}", 
                    callId, userId, connectionId);
            }
        }

        public async Task DisconnectUserAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    if (session.UserConnections.TryGetValue(userId, out var connectionId))
                    {
                        session.UserConnections.Remove(userId);
                        
                        if (_userConnections.TryGetValue(connectionId, out var userConnection))
                        {
                            userConnection.State = WebRTCConnectionState.Disconnected;
                            userConnection.DisconnectedAt = DateTime.UtcNow;
                        }
                    }
                }

                _logger.LogInformation("用户断开连接: {CallId}, 用户: {UserId}", callId, userId);
            }
        }

        public async Task<bool> IsUserConnectedAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    return session.UserConnections.ContainsKey(userId);
                }
            }
            return false;
        }

        public async Task<bool> AcceptCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && session.ReceiverId == userId)
            {
                lock (_lock)
                {
                    session.Status = CallStatus.Answered;
                }

                _logger.LogInformation("接受通话: {CallId}, 用户: {UserId}", callId, userId);
                return true;
            }
            return false;
        }

        public async Task<bool> RejectCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && session.ReceiverId == userId)
            {
                lock (_lock)
                {
                    session.Status = CallStatus.Rejected;
                    session.EndTime = DateTime.UtcNow;
                }

                _logger.LogInformation("拒绝通话: {CallId}, 用户: {UserId}", callId, userId);
                return true;
            }
            return false;
        }

        public async Task<bool> EndCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && (session.CallerId == userId || session.ReceiverId == userId))
            {
                return await EndSessionAsync(callId);
            }
            return false;
        }

        public async Task CleanupExpiredSessionsAsync()
        {
            var expiredSessions = new List<string>();
            var cutoffTime = DateTime.UtcNow.AddMinutes(-30); // 30分钟前的会话

            lock (_lock)
            {
                foreach (var kvp in _sessions)
                {
                    if (kvp.Value.StartTime < cutoffTime)
                    {
                        expiredSessions.Add(kvp.Key);
                    }
                }

                foreach (var callId in expiredSessions)
                {
                    _sessions.Remove(callId);
                }
            }

            if (expiredSessions.Count > 0)
            {
                _logger.LogInformation("清理过期会话: {Count} 个", expiredSessions.Count);
            }
        }

        // 获取活跃会话数量
        public int GetActiveSessionCount()
        {
            lock (_lock)
            {
                return _sessions.Count;
            }
        }

        // 获取用户连接数量
        public int GetActiveConnectionCount()
        {
            lock (_lock)
            {
                return _userConnections.Count;
            }
        }
    }
} 