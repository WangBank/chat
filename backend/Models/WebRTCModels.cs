namespace VideoCallAPI.Models
{
    // WebRTC 信令消息类型
    using System.Text.Json.Serialization;

    [JsonConverter(typeof(JsonStringEnumConverter))]
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
        public string id { get; set; } = Guid.NewGuid().ToString();
        public WebRTCMessageType type { get; set; }
        public string call_id { get; set; } = string.Empty;
        public int sender_id { get; set; }
        public int receiver_id { get; set; }
        public string data { get; set; } = string.Empty;
        public DateTime timestamp { get; set; } = DateTime.UtcNow;
    }

    // 通话请求
    public class CallRequest
    {
        public string call_id { get; set; } = string.Empty;
        public int caller_id { get; set; }
        public int receiver_id { get; set; }
        public CallType call_type { get; set; }
        public DateTime timestamp { get; set; } = DateTime.UtcNow;
    }

    // 通话响应
    public class CallResponse
    {
        public string call_id { get; set; } = string.Empty;
        public bool accepted { get; set; }
        public string? reason { get; set; }
        public DateTime timestamp { get; set; } = DateTime.UtcNow;
    }

    // ICE 候选
    public class IceCandidate
    {
        public string candidate { get; set; } = string.Empty;
        public string sdp_mid { get; set; } = string.Empty;
        public int sdp_m_line_index { get; set; }
    }

    // WebRTC 会话
    public class WebRTCSession
    {
        public string call_id { get; set; } = string.Empty;
        public int caller_id { get; set; }
        public int receiver_id { get; set; }
        public CallType call_type { get; set; }
        public CallStatus status { get; set; }
        public DateTime start_time { get; set; } = DateTime.UtcNow;
        public DateTime? end_time { get; set; }
        public Dictionary<int, string> user_connections { get; set; } = new();
        public List<WebRTCMessage> message_history { get; set; } = new();
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
        public int user_id { get; set; }
        public string connection_id { get; set; } = string.Empty;
        public WebRTCConnectionState state { get; set; } = WebRTCConnectionState.New;
        public DateTime connected_at { get; set; } = DateTime.UtcNow;
        public DateTime? disconnected_at { get; set; }
    }
}