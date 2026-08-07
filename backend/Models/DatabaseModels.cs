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
        public string? display_name { get; set; } // 昵称

        [StringLength(100)]
        public string? signature { get; set; } // 个性签名

        [StringLength(10)]
        public string? gender { get; set; } // 性别

        [StringLength(10)]
        public string? birthday { get; set; } // 生日

        [StringLength(50)]
        public string? country { get; set; } // 国家

        [StringLength(50)]
        public string? province { get; set; } // 省份

        [StringLength(50)]
        public string? region { get; set; } // 地区
        
        [StringLength(255)]
        public string? avatar_path { get; set; }

        [StringLength(64)]
        public string? qq_open_id { get; set; }

        [StringLength(64)]
        public string? qq_union_id { get; set; }

        [StringLength(100)]
        public string? qq_nickname { get; set; }

        [StringLength(500)]
        public string? qq_avatar_url { get; set; }

        public DateTime? qq_bound_at { get; set; }
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        public DateTime updated_at { get; set; } = DateTime.UtcNow;
        
        public DateTime? last_login_at { get; set; }

        public DateTime? last_heartbeat_at { get; set; }
        
        public bool is_online { get; set; } = false;
        
        // 导航属性
        public virtual ICollection<Contact> Contacts { get; set; } = new List<Contact>();
        public virtual ICollection<Contact> ContactedBy { get; set; } = new List<Contact>();
        public virtual ICollection<CallHistory> InitiatedCalls { get; set; } = new List<CallHistory>();
        public virtual ICollection<CallHistory> ReceivedCalls { get; set; } = new List<CallHistory>();
        public virtual ICollection<ChatMessage> SentMessages { get; set; } = new List<ChatMessage>();
        public virtual ICollection<ChatMessage> ReceivedMessages { get; set; } = new List<ChatMessage>();
        public virtual ICollection<FriendRequest> SentFriendRequests { get; set; } = new List<FriendRequest>();
        public virtual ICollection<FriendRequest> ReceivedFriendRequests { get; set; } = new List<FriendRequest>();
        public virtual ICollection<ChatGroup> OwnedChatGroups { get; set; } = new List<ChatGroup>();
        public virtual ICollection<ChatGroupMember> ChatGroupMembers { get; set; } = new List<ChatGroupMember>();
        public virtual ICollection<GroupChatMessage> SentGroupMessages { get; set; } = new List<GroupChatMessage>();
        public virtual ICollection<FavoriteItem> FavoriteItems { get; set; } = new List<FavoriteItem>();
        public virtual ICollection<PasswordResetToken> PasswordResetTokens { get; set; } = new List<PasswordResetToken>();
    }

    // 密码重置令牌表
    public class PasswordResetToken
    {
        [Key]
        public int id { get; set; }

        [Required]
        public int user_id { get; set; }

        [Required]
        [StringLength(64)]
        public string token_hash { get; set; } = string.Empty;

        public DateTime expires_at { get; set; }

        public bool is_used { get; set; } = false;

        public DateTime? used_at { get; set; }

        public DateTime created_at { get; set; } = DateTime.UtcNow;

        [ForeignKey("user_id")]
        public virtual User user { get; set; } = null!;
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

    // 好友申请表
    public class FriendRequest
    {
        [Key]
        public int id { get; set; }

        [Required]
        public int requester_id { get; set; }

        [Required]
        public int receiver_id { get; set; }

        [StringLength(100)]
        public string? note { get; set; }

        [StringLength(50)]
        public string source { get; set; } = "账号搜索";

        [Required]
        public FriendRequestStatus status { get; set; } = FriendRequestStatus.Pending;

        public DateTime created_at { get; set; } = DateTime.UtcNow;

        public DateTime updated_at { get; set; } = DateTime.UtcNow;

        [ForeignKey("requester_id")]
        public virtual User requester { get; set; } = null!;

        [ForeignKey("receiver_id")]
        public virtual User receiver { get; set; } = null!;
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

        public int? reply_to_message_id { get; set; }

        [StringLength(100)]
        public string? reply_to_sender_name { get; set; }

        [StringLength(300)]
        public string? reply_to_content { get; set; }

        public MessageType? reply_to_type { get; set; }

        [StringLength(255)]
        public string? reply_to_file_path { get; set; }
        
        public DateTime created_at { get; set; } = DateTime.UtcNow;
        
        // 导航属性
        [ForeignKey("sender_id")]
        public virtual User sender { get; set; } = null!;
        
        [ForeignKey("receiver_id")]
        public virtual User receiver { get; set; } = null!;
    }

    // 聊天群表
    public class ChatGroup
    {
        [Key]
        public int id { get; set; }

        [Required]
        [StringLength(80)]
        public string name { get; set; } = string.Empty;

        [StringLength(50)]
        public string category { get; set; } = "我创建的群聊";

        [Required]
        public int owner_id { get; set; }

        [StringLength(500)]
        public string? announcement { get; set; }

        [StringLength(200)]
        public string? note { get; set; }

        public bool pinned { get; set; } = false;

        public DateTime created_at { get; set; } = DateTime.UtcNow;

        public DateTime updated_at { get; set; } = DateTime.UtcNow;

        [ForeignKey("owner_id")]
        public virtual User owner { get; set; } = null!;

        public virtual ICollection<ChatGroupMember> members { get; set; } = new List<ChatGroupMember>();
        public virtual ICollection<GroupChatMessage> messages { get; set; } = new List<GroupChatMessage>();
    }

    // 聊天群成员表
    public class ChatGroupMember
    {
        [Key]
        public int id { get; set; }

        [Required]
        public int group_id { get; set; }

        [Required]
        public int user_id { get; set; }

        [StringLength(20)]
        public string role { get; set; } = "member";

        public DateTime joined_at { get; set; } = DateTime.UtcNow;

        public bool is_active { get; set; } = true;

        [ForeignKey("group_id")]
        public virtual ChatGroup group { get; set; } = null!;

        [ForeignKey("user_id")]
        public virtual User user { get; set; } = null!;
    }

    // 群聊消息表
    public class GroupChatMessage
    {
        [Key]
        public int id { get; set; }

        [Required]
        public int group_id { get; set; }

        [Required]
        public int sender_id { get; set; }

        [Required]
        [StringLength(1000)]
        public string content { get; set; } = string.Empty;

        [Required]
        public MessageType type { get; set; } = MessageType.Text;

        public DateTime timestamp { get; set; } = DateTime.UtcNow;

        [StringLength(255)]
        public string? file_path { get; set; }

        public int? file_size { get; set; }

        public int? duration { get; set; }

        public int? reply_to_message_id { get; set; }

        [StringLength(100)]
        public string? reply_to_sender_name { get; set; }

        [StringLength(300)]
        public string? reply_to_content { get; set; }

        public MessageType? reply_to_type { get; set; }

        [StringLength(255)]
        public string? reply_to_file_path { get; set; }

        public DateTime created_at { get; set; } = DateTime.UtcNow;

        [ForeignKey("group_id")]
        public virtual ChatGroup group { get; set; } = null!;

        [ForeignKey("sender_id")]
        public virtual User sender { get; set; } = null!;
    }

    // 收藏表
    public class FavoriteItem
    {
        [Key]
        public int id { get; set; }

        [Required]
        public int user_id { get; set; }

        [Required]
        [StringLength(1000)]
        public string content { get; set; } = string.Empty;

        [Required]
        [StringLength(20)]
        public string type { get; set; } = "chat";

        [Required]
        [StringLength(100)]
        public string source_name { get; set; } = string.Empty;

        [StringLength(255)]
        public string? file_path { get; set; }

        public int? file_size { get; set; }

        public DateTime created_at { get; set; } = DateTime.UtcNow;

        [ForeignKey("user_id")]
        public virtual User user { get; set; } = null!;
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

    public enum FriendRequestStatus
    {
        Pending = 1,
        Accepted = 2,
        Rejected = 3
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
