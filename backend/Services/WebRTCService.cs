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
                call_id = callId,
                caller_id = callerId,
                receiver_id = receiverId,
                call_type = callType,
                status = CallStatus.Initiated,
                start_time = DateTime.UtcNow
            };

            lock (_lock)
            {
                _sessions[callId] = session;
            }

            _logger.LogInformation("创建WebRTC会话: {call_id}, 呼叫者: {caller_id}, 接收者: {receiver_id}, 类型: {CallType}", 
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
                    session.status = CallStatus.Ended;
                    session.end_time = DateTime.UtcNow;
                    _sessions.Remove(callId);
                    
                    // 清理用户连接
                    var userConnections = _userConnections.Values
                        .Where(uc => uc.connection_id.StartsWith(callId))
                        .ToList();
                    
                    foreach (var connection in userConnections)
                    {
                        connection.state = WebRTCConnectionState.Closed;
                        connection.disconnected_at = DateTime.UtcNow;
                        _userConnections.Remove(connection.connection_id);
                    }

                    _logger.LogInformation("结束WebRTC会话: {call_id}", callId);
                    return true;
                }
                return false;
            }
        }

        public async Task SendMessageAsync(WebRTCMessage message)
        {
            var session = await GetSessionAsync(message.call_id);
            if (session != null)
            {
                lock (_lock)
                {
                    session.message_history.Add(message);
                }

                _logger.LogDebug("发送WebRTC消息: {call_id}, 类型: {type}, 发送者: {sender_id}", 
                    message.call_id, message.type, message.sender_id);
            }
        }

        public async Task<List<WebRTCMessage>> GetSessionMessagesAsync(string callId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    return session.message_history.ToList();
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
                    session.user_connections[userId] = connectionId;
                    
                    var userConnection = new UserConnection
                    {
                        user_id = userId,
                        connection_id = connectionId,
                        state = WebRTCConnectionState.Connecting,
                        connected_at = DateTime.UtcNow
                    };
                    
                    _userConnections[connectionId] = userConnection;
                }

                _logger.LogInformation("用户连接: {call_id}, 用户: {user_id}, 连接: {connection_id}", 
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
                    if (session.user_connections.TryGetValue(userId, out var connectionId))
                    {
                        session.user_connections.Remove(userId);
                        
                        if (_userConnections.TryGetValue(connectionId, out var userConnection))
                        {
                            userConnection.state = WebRTCConnectionState.Disconnected;
                            userConnection.disconnected_at = DateTime.UtcNow;
                        }
                    }
                }

                _logger.LogInformation("用户断开连接: {call_id}, 用户: {user_id}", callId, userId);
            }
        }

        public async Task<bool> IsUserConnectedAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null)
            {
                lock (_lock)
                {
                    return session.user_connections.ContainsKey(userId);
                }
            }
            return false;
        }

        public async Task<bool> AcceptCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && session.receiver_id == userId)
            {
                lock (_lock)
                {
                    session.status = CallStatus.Answered;
                }

                _logger.LogInformation("接受通话: {call_id}, 用户: {user_id}", callId, userId);
                return true;
            }
            return false;
        }

        public async Task<bool> RejectCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && session.receiver_id == userId)
            {
                lock (_lock)
                {
                    session.status = CallStatus.Rejected;
                    session.end_time = DateTime.UtcNow;
                }

                _logger.LogInformation("拒绝通话: {call_id}, 用户: {user_id}", callId, userId);
                return true;
            }
            return false;
        }

        public async Task<bool> EndCallAsync(string callId, int userId)
        {
            var session = await GetSessionAsync(callId);
            if (session != null && (session.caller_id == userId || session.receiver_id == userId))
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
                    if (kvp.Value.start_time < cutoffTime)
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