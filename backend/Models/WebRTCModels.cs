namespace VideoCallAPI.Models
{
    // WebRTC 信令消息类型
    public enum WebRTCMessageType
    {
        Offer,
        Answer,
        IceCandidate,
        CallRequest,
        CallResponse,
        CallEnd
    }

    // WebRTC 信令消息
    public class WebRTCMessage
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public WebRTCMessageType Type { get; set; }
        public string CallId { get; set; } = string.Empty;
        public int SenderId { get; set; }
        public int ReceiverId { get; set; }
        public string Data { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    // 通话请求
    public class CallRequest
    {
        public string CallId { get; set; } = string.Empty;
        public int CallerId { get; set; }
        public int ReceiverId { get; set; }
        public CallType CallType { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    // 通话响应
    public class CallResponse
    {
        public string CallId { get; set; } = string.Empty;
        public bool Accepted { get; set; }
        public string? Reason { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    // ICE 候选
    public class IceCandidate
    {
        public string Candidate { get; set; } = string.Empty;
        public string SdpMid { get; set; } = string.Empty;
        public int SdpMLineIndex { get; set; }
    }

    // WebRTC 会话
    public class WebRTCSession
    {
        public string CallId { get; set; } = string.Empty;
        public int CallerId { get; set; }
        public int ReceiverId { get; set; }
        public CallType CallType { get; set; }
        public CallStatus Status { get; set; }
        public DateTime StartTime { get; set; } = DateTime.UtcNow;
        public DateTime? EndTime { get; set; }
        public Dictionary<int, string> UserConnections { get; set; } = new();
        public List<WebRTCMessage> MessageHistory { get; set; } = new();
    }

    // WebRTC 连接状态
    public enum WebRTCConnectionState
    {
        New,
        Connecting,
        Connected,
        Disconnected,
        Failed,
        Closed
    }

    // 用户连接信息
    public class UserConnection
    {
        public int UserId { get; set; }
        public string ConnectionId { get; set; } = string.Empty;
        public WebRTCConnectionState State { get; set; } = WebRTCConnectionState.New;
        public DateTime ConnectedAt { get; set; } = DateTime.UtcNow;
        public DateTime? DisconnectedAt { get; set; }
    }
} 