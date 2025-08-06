using VideoCallAPI.Models;

namespace VideoCallAPI.Services
{
    public interface IWebRTCService
    {
        // 会话管理
        Task<WebRTCSession> CreateSessionAsync(int callerId, int receiverId, CallType callType);
        Task<WebRTCSession?> GetSessionAsync(string callId);
        Task<bool> EndSessionAsync(string callId);
        
        // 信令消息
        Task SendMessageAsync(WebRTCMessage message);
        Task<List<WebRTCMessage>> GetSessionMessagesAsync(string callId);
        
        // 用户连接管理
        Task ConnectUserAsync(string callId, int userId, string connectionId);
        Task DisconnectUserAsync(string callId, int userId);
        Task<bool> IsUserConnectedAsync(string callId, int userId);
        
        // 通话管理
        Task<bool> AcceptCallAsync(string callId, int userId);
        Task<bool> RejectCallAsync(string callId, int userId);
        Task<bool> EndCallAsync(string callId, int userId);
        
        // 清理
        Task CleanupExpiredSessionsAsync();
    }
} 