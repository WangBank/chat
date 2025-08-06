using VideoCallAPI.Models;
using System.ComponentModel.DataAnnotations;

namespace VideoCallAPI.Models.DTOs
{
    // 基础API响应
    public class ApiResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public List<string> Errors { get; set; } = new List<string>();
    }

    public class ApiResponse<T> : ApiResponse
    {
        public T? Data { get; set; }
    }

    // 用户相关 DTO
    public class UserRegistrationDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        public string Username { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "邮箱是必填的")]
        [EmailAddress(ErrorMessage = "邮箱格式不正确")]
        public string Email { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "密码是必填的")]
        [MinLength(6, ErrorMessage = "密码至少6位")]
        public string Password { get; set; } = string.Empty;
    }

    public class UserLoginDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        public string Username { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "密码是必填的")]
        public string Password { get; set; } = string.Empty;
    }

    public class UserResponseDto
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Nickname { get; set; }
        public string? AvatarPath { get; set; }
        public bool IsOnline { get; set; }
        public DateTime? LastLoginAt { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class UpdateProfileDto
    {
        public string? Nickname { get; set; }
        public string? AvatarPath { get; set; }
    }

    public class ChangePasswordDto
    {
        public string OldPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }

    // 联系人相关 DTO
    public class AddContactDto
    {
        public string Username { get; set; } = string.Empty;
        public string? DisplayName { get; set; }
    }

    public class ContactResponseDto
    {
        public int Id { get; set; }
        public UserResponseDto ContactUser { get; set; } = null!;
        public string? DisplayName { get; set; }
        public DateTime AddedAt { get; set; }
        public bool IsBlocked { get; set; }
        public DateTime? LastMessageAt { get; set; }
        public int UnreadCount { get; set; }
    }

    // 聊天相关 DTO
    public class SendMessageDto
    {
        [Required(ErrorMessage = "接收者ID是必填的")]
        public int ReceiverId { get; set; }
        
        [Required(ErrorMessage = "消息内容是必填的")]
        [MinLength(1, ErrorMessage = "消息内容不能为空")]
        public string Content { get; set; } = string.Empty;
        
        public MessageType Type { get; set; } = MessageType.Text;
    }

    public class ChatMessageDto
    {
        public int Id { get; set; }
        public int SenderId { get; set; }
        public int ReceiverId { get; set; }
        public string Content { get; set; } = string.Empty;
        public MessageType Type { get; set; }
        public DateTime Timestamp { get; set; }
        public bool IsRead { get; set; }
        public string? FilePath { get; set; }
        public int? FileSize { get; set; }
        public int? Duration { get; set; }
        public DateTime CreatedAt { get; set; }
        public UserResponseDto Sender { get; set; } = null!;
        public UserResponseDto Receiver { get; set; } = null!;
    }

    public class ChatHistoryDto
    {
        public int ContactId { get; set; }
        public string ContactName { get; set; } = string.Empty;
        public DateTime? LastMessageAt { get; set; }
        public int UnreadCount { get; set; }
        public List<ChatMessageDto> Messages { get; set; } = new List<ChatMessageDto>();
    }

    public class DeleteChatHistoryDto
    {
        public int ContactId { get; set; }
    }

    // 通话相关 DTO
    public class CallResponseDto
    {
        public string CallId { get; set; } = string.Empty;
        public UserResponseDto Caller { get; set; } = null!;
        public UserResponseDto Receiver { get; set; } = null!;
        public CallType CallType { get; set; }
        public CallStatus Status { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public int? Duration { get; set; }
    }

    public class CreateRoomDto
    {
        public string RoomName { get; set; } = string.Empty;
        public int MaxParticipants { get; set; } = 10;
    }

    public class RoomResponseDto
    {
        public int Id { get; set; }
        public string RoomName { get; set; } = string.Empty;
        public string RoomCode { get; set; } = string.Empty;
        public UserResponseDto Creator { get; set; } = null!;
        public DateTime CreatedAt { get; set; }
        public bool IsActive { get; set; }
        public int MaxParticipants { get; set; }
        public int CurrentParticipants { get; set; }
        public List<UserResponseDto> Participants { get; set; } = new List<UserResponseDto>();
    }

    // 搜索相关 DTO
    public class SearchContactsDto
    {
        public string Query { get; set; } = string.Empty;
    }

    public class SearchUsersDto
    {
        public string Query { get; set; } = string.Empty;
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 20;
    }

    public class UserSearchResultDto
    {
        public List<UserResponseDto> Users { get; set; } = new List<UserResponseDto>();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
    }

    // WebRTC 相关 DTO
    public class InitiateCallDto
    {
        public int ReceiverId { get; set; }
        public CallType CallType { get; set; }
    }

    public class AnswerCallDto
    {
        public string CallId { get; set; } = string.Empty;
        public bool Accept { get; set; }
    }

    public class WebRTCOfferDto
    {
        public string CallId { get; set; } = string.Empty;
        public string Offer { get; set; } = string.Empty;
    }

    public class WebRTCAnswerDto
    {
        public string CallId { get; set; } = string.Empty;
        public string Answer { get; set; } = string.Empty;
    }

    public class WebRTCCandidateDto
    {
        public string CallId { get; set; } = string.Empty;
        public string Candidate { get; set; } = string.Empty;
    }
}
