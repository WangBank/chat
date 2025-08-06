using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace VideoCallAPI.Models
{
    // 用户表
    public class User
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [StringLength(50)]
        public string Username { get; set; } = string.Empty;
        
        [Required]
        [StringLength(100)]
        public string Email { get; set; } = string.Empty;
        
        [Required]
        public string PasswordHash { get; set; } = string.Empty;
        
        [StringLength(50)]
        public string? Nickname { get; set; } // 昵称
        
        [StringLength(255)]
        public string? AvatarPath { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        public DateTime? LastLoginAt { get; set; }
        
        public bool IsOnline { get; set; } = false;
        
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
        public int Id { get; set; }
        
        [Required]
        public int UserId { get; set; }
        
        [Required]
        public int ContactUserId { get; set; }
        
        [StringLength(50)]
        public string? DisplayName { get; set; }
        
        public DateTime AddedAt { get; set; } = DateTime.UtcNow;
        
        public bool IsBlocked { get; set; } = false;
        
        public DateTime? LastMessageAt { get; set; } // 最后消息时间
        
        public int UnreadCount { get; set; } = 0; // 未读消息数
        
        // 导航属性
        [ForeignKey("UserId")]
        public virtual User User { get; set; } = null!;
        
        [ForeignKey("ContactUserId")]
        public virtual User ContactUser { get; set; } = null!;
    }

    // 聊天消息表
    public class ChatMessage
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public int SenderId { get; set; }
        
        [Required]
        public int ReceiverId { get; set; }
        
        [Required]
        [StringLength(1000)]
        public string Content { get; set; } = string.Empty;
        
        [Required]
        public MessageType Type { get; set; } = MessageType.Text;
        
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        
        public bool IsRead { get; set; } = false;
        
        [StringLength(255)]
        public string? FilePath { get; set; } // 文件路径
        
        public int? FileSize { get; set; } // 文件大小
        
        public int? Duration { get; set; } // 语音/视频时长（秒）
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        // 导航属性
        [ForeignKey("SenderId")]
        public virtual User Sender { get; set; } = null!;
        
        [ForeignKey("ReceiverId")]
        public virtual User Receiver { get; set; } = null!;
    }

    // 通话历史表
    public class CallHistory
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public int CallerId { get; set; }
        
        [Required]
        public int ReceiverId { get; set; }
        
        [Required]
        public CallType CallType { get; set; }
        
        [Required]
        public CallStatus Status { get; set; }
        
        public DateTime StartTime { get; set; } = DateTime.UtcNow;
        
        public DateTime? EndTime { get; set; }
        
        public int? Duration { get; set; } // 秒
        
        [StringLength(255)]
        public string? EndReason { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        // 导航属性
        [ForeignKey("CallerId")]
        public virtual User Caller { get; set; } = null!;
        
        [ForeignKey("ReceiverId")]
        public virtual User Receiver { get; set; } = null!;
    }

    // 房间表（用于群组通话）
    public class Room
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [StringLength(100)]
        public string RoomName { get; set; } = string.Empty;
        
        [Required]
        public string RoomCode { get; set; } = Guid.NewGuid().ToString();
        
        [Required]
        public int CreatedBy { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        public bool IsActive { get; set; } = true;
        
        public int MaxParticipants { get; set; } = 10;
        
        // 导航属性
        [ForeignKey("CreatedBy")]
        public virtual User Creator { get; set; } = null!;
        
        public virtual ICollection<RoomParticipant> Participants { get; set; } = new List<RoomParticipant>();
    }

    // 房间参与者表
    public class RoomParticipant
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public int RoomId { get; set; }
        
        [Required]
        public int UserId { get; set; }
        
        public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
        
        public DateTime? LeftAt { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        // 导航属性
        [ForeignKey("RoomId")]
        public virtual Room Room { get; set; } = null!;
        
        [ForeignKey("UserId")]
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
