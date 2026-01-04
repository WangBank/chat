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
        public string username { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "邮箱是必填的")]
        [EmailAddress(ErrorMessage = "邮箱格式不正确")]
        public string email { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "密码是必填的")]
        [MinLength(6, ErrorMessage = "密码至少6位")]
        public string password { get; set; } = string.Empty;
    }

    public class UserLoginDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        public string username { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "密码是必填的")]
        public string password { get; set; } = string.Empty;
    }

    public class UserResponseDto
    {
        public int id { get; set; }
        public string username { get; set; } = string.Empty;
        public string email { get; set; } = string.Empty;
        public string? display_name { get; set; }
        public string? avatar_path { get; set; }
        public bool is_online { get; set; }
        public DateTime? last_login_at { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
    }

    public class UpdateProfileDto
    {
        public string? display_name { get; set; }
        public string? avatar_path { get; set; }
    }

    public class ChangePasswordDto
    {
        public string old_password { get; set; } = string.Empty;
        public string new_password { get; set; } = string.Empty;
    }

    public class AdminChangePasswordDto
    {
        public int user_id { get; set; }
        public string new_password { get; set; } = string.Empty;
    }

    // 联系人相关 DTO
    public class AddContactDto
    {
        public string username { get; set; } = string.Empty;
        public string? display_name { get; set; }
    }

    public class ContactResponseDto
    {
        public int id { get; set; }
        public UserResponseDto contact_user { get; set; } = null!;
        public string? display_name { get; set; }
        public DateTime added_at { get; set; }
        public bool is_blocked { get; set; }
        public DateTime? last_message_at { get; set; }
        public int unread_count { get; set; }
    }

    // 聊天相关 DTO
    public class SendMessageDto
    {
        [Required(ErrorMessage = "接收者ID是必填的")]
        public int receiver_id { get; set; }
        
        [Required(ErrorMessage = "消息内容是必填的")]
        [MinLength(1, ErrorMessage = "消息内容不能为空")]
        public string content { get; set; } = string.Empty;
        
        public MessageType type { get; set; } = MessageType.Text;
    }

    public class ChatMessageDto
    {
        public int id { get; set; }
        public int sender_id { get; set; }
        public int receiver_id { get; set; }
        public string content { get; set; } = string.Empty;
        public MessageType type { get; set; }
        public DateTime timestamp { get; set; }
        public bool is_read { get; set; }
        public string? file_path { get; set; }
        public int? file_size { get; set; }
        public int? duration { get; set; }
        public DateTime created_at { get; set; }
        public UserResponseDto sender { get; set; } = null!;
        public UserResponseDto receiver { get; set; } = null!;
    }

    public class ChatHistoryDto
    {
        public int contact_id { get; set; }
        public string contact_name { get; set; } = string.Empty;
        public DateTime? last_message_at { get; set; }
        public int unread_count { get; set; }
        public List<ChatMessageDto> messages { get; set; } = new List<ChatMessageDto>();
    }

    public class DeleteChatHistoryDto
    {
        public int contact_id { get; set; }
    }

    // 通话相关 DTO
    public class CallResponseDto
    {
        public string call_id { get; set; } = string.Empty;
        public UserResponseDto caller { get; set; } = null!;
        public UserResponseDto receiver { get; set; } = null!;
        public CallType call_type { get; set; }
        public CallStatus status { get; set; }
        public DateTime start_time { get; set; }
        public DateTime? end_time { get; set; }
        public int? duration { get; set; }
    }

    public class CreateRoomDto
    {
        public string room_name { get; set; } = string.Empty;
        public int max_participants { get; set; } = 10;
    }

    public class RoomResponseDto
    {
        public int id { get; set; }
        public string room_name { get; set; } = string.Empty;
        public string room_code { get; set; } = string.Empty;
        public UserResponseDto creator { get; set; } = null!;
        public DateTime created_at { get; set; }
        public bool is_active { get; set; }
        public int max_participants { get; set; }
        public int current_participants { get; set; }
        public List<UserResponseDto> participants { get; set; } = new List<UserResponseDto>();
    }

    // 搜索相关 DTO
    public class SearchContactsDto
    {
        public string query { get; set; } = string.Empty;
    }

    public class SearchUsersDto
    {
        public string query { get; set; } = string.Empty;
        public int page { get; set; } = 1;
        public int page_size { get; set; } = 20;
    }

    public class UserSearchResultDto
    {
        public List<UserResponseDto> users { get; set; } = new List<UserResponseDto>();
        public int total_count { get; set; }
        public int page { get; set; }
        public int page_size { get; set; }
        public int total_pages { get; set; }
    }

    // WebRTC 相关 DTO
    public class InitiateCallDto
    {
        public int receiver_id { get; set; }
        public CallType call_type { get; set; }
    }

    public class AnswerCallDto
    {
        public string call_id { get; set; } = string.Empty;
        public bool accept { get; set; }
    }

    public class WebRTCOfferDto
    {
        public string call_id { get; set; } = string.Empty;
        public string offer { get; set; } = string.Empty;
    }

    public class WebRTCAnswerDto
    {
        public string call_id { get; set; } = string.Empty;
        public string answer { get; set; } = string.Empty;
    }

    public class WebRTCCandidateDto
    {
        public string call_id { get; set; } = string.Empty;
        public string candidate { get; set; } = string.Empty;
    }
}
