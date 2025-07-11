using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

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
        
        [StringLength(255)]
        public string? AvatarPath { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        public DateTime? LastLoginAt { get; set; }
        
        public bool IsOnline { get; set; } = false;
        
        // 导航属性
        public virtual ICollection<Contact> Contacts { get; set; } = new List<Contact>();
        public virtual ICollection<Contact> ContactedBy { get; set; } = new List<Contact>();
        public virtual ICollection<CallHistory> InitiatedCalls { get; set; } = new List<CallHistory>();
        public virtual ICollection<CallHistory> ReceivedCalls { get; set; } = new List<CallHistory>();
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
        
        // 导航属性
        [ForeignKey("UserId")]
        public virtual User User { get; set; } = null!;
        
        [ForeignKey("ContactUserId")]
        public virtual User ContactUser { get; set; } = null!;
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
        Video = 1,
        Audio = 2
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
}
