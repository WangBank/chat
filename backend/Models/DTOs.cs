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
        [Required(ErrorMessage = "用户名或邮箱是必填的")]
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
        public string? signature { get; set; }
        public string? gender { get; set; }
        public string? birthday { get; set; }
        public string? country { get; set; }
        public string? province { get; set; }
        public string? region { get; set; }
        public string? avatar_path { get; set; }
        public bool qq_bound { get; set; }
        public string? qq_nickname { get; set; }
        public string? qq_avatar_url { get; set; }
        public DateTime? qq_bound_at { get; set; }
        public bool is_online { get; set; }
        public DateTime? last_login_at { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
    }

    public class QQLoginUrlResponseDto
    {
        public string auth_url { get; set; } = string.Empty;
        public string state { get; set; } = string.Empty;
        public string mode { get; set; } = "login";
        public bool configured { get; set; }
        public bool mock_available { get; set; }
    }

    public class QQLoginRequestDto
    {
        [Required(ErrorMessage = "授权码是必填的")]
        public string code { get; set; } = string.Empty;

        [Required(ErrorMessage = "state 是必填的")]
        public string state { get; set; } = string.Empty;
    }

    public class QQDevLoginDto
    {
        public string? open_id { get; set; }

        [StringLength(100, ErrorMessage = "QQ昵称不能超过100个字符")]
        public string? nickname { get; set; }

        [StringLength(500, ErrorMessage = "QQ头像地址不能超过500个字符")]
        public string? avatar_url { get; set; }

        [StringLength(10, ErrorMessage = "QQ性别不能超过10个字符")]
        public string? gender { get; set; }

        [StringLength(50, ErrorMessage = "QQ省份不能超过50个字符")]
        public string? province { get; set; }

        [StringLength(50, ErrorMessage = "QQ国家不能超过50个字符")]
        public string? country { get; set; }

        [StringLength(50, ErrorMessage = "QQ城市不能超过50个字符")]
        public string? city { get; set; }

        [StringLength(10, ErrorMessage = "QQ生日年份不能超过10个字符")]
        public string? year { get; set; }

        [StringLength(100, ErrorMessage = "QQ个性签名不能超过100个字符")]
        public string? signature { get; set; }
    }

    public class QQBindingResponseDto
    {
        public bool bound { get; set; }
        public string? qq_nickname { get; set; }
        public string? qq_avatar_url { get; set; }
        public DateTime? qq_bound_at { get; set; }
    }

    public class UpdateProfileDto
    {
        public string? display_name { get; set; }
        public string? avatar_path { get; set; }

        [StringLength(100, ErrorMessage = "个性签名不能超过100个字符")]
        public string? signature { get; set; }

        [StringLength(10, ErrorMessage = "性别不能超过10个字符")]
        public string? gender { get; set; }

        [StringLength(10, ErrorMessage = "生日格式不能超过10个字符")]
        public string? birthday { get; set; }

        [StringLength(50, ErrorMessage = "国家不能超过50个字符")]
        public string? country { get; set; }

        [StringLength(50, ErrorMessage = "省份不能超过50个字符")]
        public string? province { get; set; }

        [StringLength(50, ErrorMessage = "地区不能超过50个字符")]
        public string? region { get; set; }
    }

    public class ChangePasswordDto
    {
        public string old_password { get; set; } = string.Empty;
        public string new_password { get; set; } = string.Empty;
    }

    public class ForgotPasswordDto
    {
        [Required(ErrorMessage = "邮箱是必填的")]
        [EmailAddress(ErrorMessage = "邮箱格式不正确")]
        public string email { get; set; } = string.Empty;
    }

    public class ResetPasswordDto
    {
        [Required(ErrorMessage = "重置令牌是必填的")]
        public string token { get; set; } = string.Empty;

        [Required(ErrorMessage = "新密码是必填的")]
        [MinLength(6, ErrorMessage = "密码至少6位")]
        public string new_password { get; set; } = string.Empty;
    }

    public class AdminChangePasswordDto
    {
        public int user_id { get; set; }
        public string new_password { get; set; } = string.Empty;
    }

    public class AdminCreateUserDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        [StringLength(50, MinimumLength = 3, ErrorMessage = "用户名长度必须为3到50位")]
        public string username { get; set; } = string.Empty;

        [Required(ErrorMessage = "邮箱是必填的")]
        [EmailAddress(ErrorMessage = "邮箱格式不正确")]
        [StringLength(100, ErrorMessage = "邮箱不能超过100个字符")]
        public string email { get; set; } = string.Empty;

        [Required(ErrorMessage = "密码是必填的")]
        [MinLength(6, ErrorMessage = "密码至少6位")]
        public string password { get; set; } = string.Empty;

        [StringLength(50, ErrorMessage = "昵称不能超过50个字符")]
        public string? display_name { get; set; }
    }

    public class AdminUpdateUserDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        [StringLength(50, MinimumLength = 3, ErrorMessage = "用户名长度必须为3到50位")]
        public string username { get; set; } = string.Empty;

        [Required(ErrorMessage = "邮箱是必填的")]
        [EmailAddress(ErrorMessage = "邮箱格式不正确")]
        [StringLength(100, ErrorMessage = "邮箱不能超过100个字符")]
        public string email { get; set; } = string.Empty;

        [StringLength(50, ErrorMessage = "昵称不能超过50个字符")]
        public string? display_name { get; set; }
    }

    // 联系人相关 DTO
    public class AddContactDto
    {
        public string username { get; set; } = string.Empty;
        public string? display_name { get; set; }
    }

    public class CreateFriendRequestDto
    {
        [Required(ErrorMessage = "用户名是必填的")]
        public string username { get; set; } = string.Empty;

        [StringLength(100, ErrorMessage = "验证消息不能超过100个字符")]
        public string? note { get; set; }

        [StringLength(50, ErrorMessage = "来源不能超过50个字符")]
        public string? source { get; set; }
    }

    public class FriendRequestDecisionDto
    {
        [Required(ErrorMessage = "处理结果是必填的")]
        public string status { get; set; } = string.Empty;
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

    public class FriendRequestResponseDto
    {
        public int id { get; set; }
        public UserResponseDto requester { get; set; } = null!;
        public UserResponseDto receiver { get; set; } = null!;
        public string? note { get; set; }
        public string source { get; set; } = string.Empty;
        public string status { get; set; } = string.Empty;
        public string direction { get; set; } = string.Empty;
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
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

        public string? file_path { get; set; }

        public int? file_size { get; set; }

        public int? duration { get; set; }

        public int? reply_to_message_id { get; set; }
    }

    public class ReplyMessageSnapshotDto
    {
        public int? id { get; set; }
        public string sender_name { get; set; } = string.Empty;
        public string content { get; set; } = string.Empty;
        public MessageType type { get; set; } = MessageType.Text;
        public string? file_path { get; set; }
    }

    public class ChatUploadResponseDto
    {
        public string file_name { get; set; } = string.Empty;
        public string file_path { get; set; } = string.Empty;
        public long file_size { get; set; }
        public string content_type { get; set; } = string.Empty;
    }

    public class ChatUploadRequestDto
    {
        [Required(ErrorMessage = "请选择要发送的文件")]
        public IFormFile file { get; set; } = null!;
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
        public int? reply_to_message_id { get; set; }
        public ReplyMessageSnapshotDto? reply_to { get; set; }
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

    // 群聊相关 DTO
    public class CreateChatGroupDto
    {
        [StringLength(80, ErrorMessage = "群聊名称不能超过80个字符")]
        public string? name { get; set; }

        [StringLength(50, ErrorMessage = "群聊分类不能超过50个字符")]
        public string? category { get; set; }

        public List<int> member_ids { get; set; } = new List<int>();

        public bool pinned { get; set; } = false;
    }

    public class ChatGroupResponseDto
    {
        public int id { get; set; }
        public string name { get; set; } = string.Empty;
        public string category { get; set; } = string.Empty;
        public List<int> member_ids { get; set; } = new List<int>();
        public List<UserResponseDto> members { get; set; } = new List<UserResponseDto>();
        public bool pinned { get; set; }
        public int owner_id { get; set; }
        public string? announcement { get; set; }
        public string? note { get; set; }
        public DateTime created_at { get; set; }
        public DateTime updated_at { get; set; }
    }

    public class SendGroupMessageDto
    {
        [Required(ErrorMessage = "消息内容是必填的")]
        [MinLength(1, ErrorMessage = "消息内容不能为空")]
        public string content { get; set; } = string.Empty;

        public MessageType type { get; set; } = MessageType.Text;

        public string? file_path { get; set; }

        public int? file_size { get; set; }

        public int? duration { get; set; }

        public int? reply_to_message_id { get; set; }
    }

    public class GroupChatMessageDto
    {
        public int id { get; set; }
        public int group_id { get; set; }
        public int sender_id { get; set; }
        public string sender_name { get; set; } = string.Empty;
        public string content { get; set; } = string.Empty;
        public MessageType type { get; set; }
        public DateTime timestamp { get; set; }
        public string? file_path { get; set; }
        public int? file_size { get; set; }
        public int? duration { get; set; }
        public int? reply_to_message_id { get; set; }
        public ReplyMessageSnapshotDto? reply_to { get; set; }
        public DateTime created_at { get; set; }
        public UserResponseDto sender { get; set; } = null!;
    }

    // 收藏相关 DTO
    public class CreateFavoriteItemDto
    {
        [Required(ErrorMessage = "收藏内容是必填的")]
        [MinLength(1, ErrorMessage = "收藏内容不能为空")]
        public string content { get; set; } = string.Empty;

        [Required(ErrorMessage = "收藏类型是必填的")]
        [StringLength(20, ErrorMessage = "收藏类型不能超过20个字符")]
        public string type { get; set; } = "chat";

        [StringLength(100, ErrorMessage = "来源名称不能超过100个字符")]
        public string? source_name { get; set; }

        public string? file_path { get; set; }

        public int? file_size { get; set; }
    }

    public class UpdateFavoriteItemDto
    {
        [Required(ErrorMessage = "收藏内容是必填的")]
        [MinLength(1, ErrorMessage = "收藏内容不能为空")]
        [StringLength(1000, ErrorMessage = "收藏内容不能超过1000个字符")]
        public string content { get; set; } = string.Empty;
    }

    public class FavoriteItemResponseDto
    {
        public int id { get; set; }
        public string content { get; set; } = string.Empty;
        public string type { get; set; } = string.Empty;
        public string source_name { get; set; } = string.Empty;
        public string? file_path { get; set; }
        public int? file_size { get; set; }
        public DateTime created_at { get; set; }
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
