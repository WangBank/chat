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
        Task<UserResponseDto> GetUserAsync(int userId);
        Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto changePasswordDto);
        Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateProfileDto updateProfileDto);
        Task<UserResponseDto> UploadAvatarAsync(int userId, IFormFile avatar);
        Task<UserSearchResultDto> SearchUsersAsync(int currentUserId, SearchUsersDto searchDto);
    }

    public interface IContactService
    {
        Task<ContactResponseDto> AddContactAsync(int userId, AddContactDto addContactDto);
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
