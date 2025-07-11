namespace VideoCallAPI.Models.DTOs
{
    // 用户相关 DTO
    public class UserRegistrationDto
    {
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class UserLoginDto
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class UserResponseDto
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? AvatarPath { get; set; }
        public bool IsOnline { get; set; }
        public DateTime? LastLoginAt { get; set; }
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
    }

    // 通话相关 DTO
    public class InitiateCallDto
    {
        public int ReceiverId { get; set; }
        public CallType CallType { get; set; }
    }

    public class CallResponseDto
    {
        public string CallId { get; set; } = string.Empty;
        public UserResponseDto Caller { get; set; } = null!;
        public UserResponseDto Receiver { get; set; } = null!;
        public CallType CallType { get; set; }
        public CallStatus Status { get; set; }
        public DateTime StartTime { get; set; }
    }

    public class AnswerCallDto
    {
        public string CallId { get; set; } = string.Empty;
        public bool Accept { get; set; }
    }

    // WebRTC 相关 DTO
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

    // 房间相关 DTO
    public class CreateRoomDto
    {
        public string RoomName { get; set; } = string.Empty;
        public int MaxParticipants { get; set; } = 10;
    }

    public class JoinRoomDto
    {
        public string RoomCode { get; set; } = string.Empty;
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

    // API 响应包装
    public class ApiResponse<T>
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public T? Data { get; set; }
        public List<string> Errors { get; set; } = new List<string>();
    }

    public class ApiResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public List<string> Errors { get; set; } = new List<string>();
    }
}
