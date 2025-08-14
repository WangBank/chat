using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace VideoCallAPI.Models
{
    // 用户表
    public class User
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        [StringLength(50)]
        public string username { get; set; } = string.Empty;
        
        [Required]
        [StringLength(100)]
        public string email { get; set; } = string.Empty;
        
        [Required]
        public string password_hash { get; set; } = string.Empty;
        
        [StringLength(50)]
        public string? nickname { get; set; } // 昵称
        
        [StringLength(255)]
        public string? avatar_path { get; set; }
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        public DateTime updated_at { get; set; } = DateTime.UtcNow;
        
        public DateTime? last_login_at { get; set; }
        
        public bool is_online { get; set; } = false;
        
        // 导航属性
        public virtual ICollection<Contact> Contacts { get; set; } = new List<Contact>();
        public virtual ICollection<Contact> ContactedBy { get; set; } = new List<Contact>();
        public virtual ICollection<CallHistory> InitiatedCalls { get; set; } = new List<CallHistory>();
        public virtual ICollection<CallHistory> ReceivedCalls { get; set; } = new List<CallHistory>();
        public virtual ICollection<ChatMessage> SentMessages { get; set; } = new List<ChatMessage>();
        public virtual ICollection<ChatMessage> ReceivedMessages { get; set; } = new List<ChatMessage>();
    }

    // 联系人表
    public class Contact
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        public int user_id { get; set; }
        
        [Required]
        public int contact_user_id { get; set; }
        
        [StringLength(50)]
        public string? display_name { get; set; }
        
        public DateTime added_at { get; set; } = DateTime.UtcNow;
        
        public bool is_blocked { get; set; } = false;
        
        public DateTime? last_message_at { get; set; } // 最后消息时间
        
        public int unread_count { get; set; } = 0; // 未读消息数
        
        // 导航属性
        [ForeignKey("user_id")]
        public virtual User User { get; set; } = null!;
        
        [ForeignKey("contact_user_id")]
        public virtual User contact_user { get; set; } = null!;
    }

    // 聊天消息表
    public class ChatMessage
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        public int sender_id { get; set; }
        
        [Required]
        public int receiver_id { get; set; }
        
        [Required]
        [StringLength(1000)]
        public string content { get; set; } = string.Empty;
        
        [Required]
        public MessageType type { get; set; } = MessageType.Text;
        
        public DateTime timestamp { get; set; } = DateTime.UtcNow;
        
        public bool is_read { get; set; } = false;
        
        [StringLength(255)]
        public string? file_path { get; set; } // 文件路径
        
        public int? file_size { get; set; } // 文件大小
        
        public int? duration { get; set; } // 语音/视频时长（秒）
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        // 导航属性
        [ForeignKey("sender_id")]
        public virtual User sender { get; set; } = null!;
        
        [ForeignKey("receiver_id")]
        public virtual User receiver { get; set; } = null!;
    }

    // 通话历史表
    public class CallHistory
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        public int caller_id { get; set; }
        
        [Required]
        public int receiver_id { get; set; }
        
        [Required]
        public CallType call_type { get; set; }
        
        [Required]
        public CallStatus status { get; set; }
        
        public DateTime start_time { get; set; } = DateTime.UtcNow;
        
        public DateTime? end_time { get; set; }
        
        public int? duration { get; set; } // 秒
        
        [StringLength(255)]
        public string? end_reason { get; set; }
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        // 导航属性
        [ForeignKey("caller_id")]
        public virtual User Caller { get; set; } = null!;
        
        [ForeignKey("receiver_id")]
        public virtual User receiver { get; set; } = null!;
    }

    // 房间表（用于群组通话）
    public class Room
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        [StringLength(100)]
        public string room_name { get; set; } = string.Empty;
        
        [Required]
        public string room_code { get; set; } = Guid.NewGuid().ToString();
        
        [Required]
        public int created_by { get; set; }
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        public bool is_active { get; set; } = true;
        
        public int max_participants { get; set; } = 10;
        
        // 导航属性
        [ForeignKey("created_by")]
        public virtual User creator { get; set; } = null!;
        
        public virtual ICollection<RoomParticipant> participants { get; set; } = new List<RoomParticipant>();
    }

    // 房间参与者表
    public class RoomParticipant
    {
        [Key]
        public int id { get; set; }
        
        [Required]
        public int room_id { get; set; }
        
        [Required]
        public int user_id { get; set; }
        
        public DateTime joined_at { get; set; } = DateTime.UtcNow;
        
        public DateTime? left_at { get; set; }
        
        public bool is_active { get; set; } = true;
        
        // 导航属性
        [ForeignKey("room_id")]
        public virtual Room Room { get; set; } = null!;
        
        [ForeignKey("user_id")]
        public virtual User User { get; set; } = null!;
    }

    // 枚举
    public enum CallType
    {
        Voice = 1,
        Video = 2
    }

    public enum CallStatus
    {
        Initiated = 1,
        Ringing = 2,
        Answered = 3,
        Rejected = 4,
        Missed = 5,
        Ended = 6,
        Failed = 7
    }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum MessageType
    {
        Text = 1,
        Image = 2,
        Video = 3,
        Audio = 4,
        File = 5
    }
}
