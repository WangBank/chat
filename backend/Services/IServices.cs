using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;

namespace VideoCallAPI.Services
{
    public interface ICallService
    {
        Task<CallResponseDto> InitiateCallAsync(int callerId, int receiverId, CallType callType);
        Task<CallResponseDto> AnswerCallAsync(string callId, int userId, bool accept);
        Task EndCallAsync(string callId, int userId);
        Task UpdateUserOnlineStatus(int userId, bool isOnline);
        Task<RoomResponseDto> CreateRoomAsync(int userId, CreateRoomDto createRoomDto);
        Task<RoomResponseDto> JoinRoomAsync(string roomCode, int userId);
        Task LeaveRoomAsync(int roomId, int userId);
        Task<List<CallHistory>> GetCallHistoryAsync(int userId);
    }

    public interface IUserService
    {
        Task<UserResponseDto> RegisterAsync(UserRegistrationDto registrationDto);
        Task<string> LoginAsync(UserLoginDto loginDto);
        Task<UserResponseDto> GetUserByIdAsync(int userId);
        Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto changePasswordDto);
        Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateProfileDto updateProfileDto);
        Task<UserResponseDto> UploadAvatarAsync(int userId, IFormFile avatar);
        Task<UserSearchResultDto> SearchUsersAsync(int currentUserId, SearchUsersDto searchDto);
        Task UpdateHeartbeatAsync(int userId);
        Task MarkOfflineAsync(int userId);
    }

    public interface IQQAuthService
    {
        QQLoginUrlResponseDto CreateLoginUrl(string mode);
        Task<(string Token, UserResponseDto User)> CompleteLoginAsync(QQLoginRequestDto loginDto);
        Task<UserResponseDto> BindAsync(int userId, QQLoginRequestDto loginDto);
        Task<(string Token, UserResponseDto User)> DevLoginAsync(QQDevLoginDto loginDto);
        Task<UserResponseDto> DevBindAsync(int userId, QQDevLoginDto loginDto);
    }

    public interface IContentSecurityService
    {
        string NormalizeRequiredText(string? value, string fieldName, int maxLength, bool filterSensitiveWords = true);
        string? NormalizeOptionalText(string? value, string fieldName, int maxLength, bool filterSensitiveWords = true);
        string? NormalizeStoredFilePath(string? value, string fieldName, params string[] allowedPrefixes);
    }

    public interface IContactService
    {
        Task<ContactResponseDto> AddContactAsync(int userId, AddContactDto addContactDto);
        Task<FriendRequestResponseDto> CreateFriendRequestAsync(int userId, CreateFriendRequestDto requestDto);
        Task<List<FriendRequestResponseDto>> GetFriendRequestsAsync(int userId);
        Task<FriendRequestResponseDto> RespondFriendRequestAsync(int userId, int requestId, FriendRequestDecisionDto decisionDto);
        Task ClearHandledFriendRequestsAsync(int userId);
        Task<List<ContactResponseDto>> GetContactsAsync(int userId);
        Task<List<ContactResponseDto>> SearchContactsAsync(int userId, string query);
        Task RemoveContactAsync(int userId, int contactId);
        Task BlockContactAsync(int userId, int contactId, bool isBlocked);
        Task<ContactResponseDto> UpdateContactDisplayNameAsync(int userId, int contactId, string displayName);
    }

    public interface IChatService
    {
        Task<ChatMessageDto> SendMessageAsync(int senderId, SendMessageDto sendMessageDto);
        Task<List<ChatMessageDto>> GetChatHistoryAsync(int userId, int contactId);
        Task<List<ChatHistoryDto>> GetChatHistoryAsync(int userId);
        Task MarkMessageAsReadAsync(int messageId, int userId);
        Task<List<ChatMessageDto>> GetUnreadMessagesAsync(int userId);
        Task DeleteChatHistoryAsync(int userId, int contactId);
    }

    public interface IJwtService
    {
        string GenerateToken(User user);
        bool ValidateToken(string token);
        int? GetUserIdFromToken(string token);
    }
}
