using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Data;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;
using System.Collections.Concurrent;

namespace VideoCallAPI.Services
{
    public class CallService : ICallService
    {
        private readonly VideoCallDbContext _context;
        private readonly ILogger<CallService> _logger;
        
        // 内存中的活跃通话管理
        private static readonly ConcurrentDictionary<string, CallSession> _activeCalls = new();

        public CallService(VideoCallDbContext context, ILogger<CallService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public async Task<CallResponseDto> InitiateCallAsync(int callerId, int receiverId, CallType callType)
        {
            // 检查用户是否存在
            var caller = await _context.Users.FindAsync(callerId);
            var receiver = await _context.Users.FindAsync(receiverId);

            if (caller == null || receiver == null)
                throw new ArgumentException("用户不存在");

            if (!receiver.IsOnline)
                throw new InvalidOperationException("用户不在线");

            // 创建通话记录
            var callHistory = new CallHistory
            {
                CallerId = callerId,
                ReceiverId = receiverId,
                CallType = callType,
                Status = CallStatus.Initiated,
                StartTime = DateTime.UtcNow
            };

            _context.CallHistories.Add(callHistory);
            await _context.SaveChangesAsync();

            var callId = Guid.NewGuid().ToString();
            
            // 创建通话会话
            var callSession = new CallSession
            {
                Id = callId,
                CallerId = callerId,
                ReceiverId = receiverId,
                CallType = callType,
                Status = CallStatus.Initiated,
                StartTime = DateTime.UtcNow,
                CallHistoryId = callHistory.Id
            };

            _activeCalls.TryAdd(callId, callSession);

            return new CallResponseDto
            {
                CallId = callId,
                Caller = MapToUserResponse(caller),
                Receiver = MapToUserResponse(receiver),
                CallType = callType,
                Status = CallStatus.Initiated,
                StartTime = DateTime.UtcNow
            };
        }

        public async Task<CallResponseDto> AnswerCallAsync(string callId, int userId, bool accept)
        {
            if (!_activeCalls.TryGetValue(callId, out var callSession))
                throw new InvalidOperationException("通话不存在");

            if (callSession.ReceiverId != userId)
                throw new UnauthorizedAccessException("无权限操作此通话");

            var status = accept ? CallStatus.Answered : CallStatus.Rejected;
            callSession.Status = status;

            // 更新数据库记录
            var callHistory = await _context.CallHistories.FindAsync(callSession.CallHistoryId);
            if (callHistory != null)
            {
                callHistory.Status = status;
                if (!accept)
                {
                    callHistory.EndTime = DateTime.UtcNow;
                    callHistory.EndReason = "被拒绝";
                }
                await _context.SaveChangesAsync();
            }

            // 如果被拒绝，移除通话会话
            if (!accept)
            {
                _activeCalls.TryRemove(callId, out _);
            }

            var caller = await _context.Users.FindAsync(callSession.CallerId);
            var receiver = await _context.Users.FindAsync(callSession.ReceiverId);

            return new CallResponseDto
            {
                CallId = callId,
                Caller = MapToUserResponse(caller!),
                Receiver = MapToUserResponse(receiver!),
                CallType = callSession.CallType,
                Status = status,
                StartTime = callSession.StartTime
            };
        }

        public async Task EndCallAsync(string callId, int userId)
        {
            if (!_activeCalls.TryRemove(callId, out var callSession))
                throw new InvalidOperationException("通话不存在");

            // 更新数据库记录
            var callHistory = await _context.CallHistories.FindAsync(callSession.CallHistoryId);
            if (callHistory != null)
            {
                callHistory.Status = CallStatus.Ended;
                callHistory.EndTime = DateTime.UtcNow;
                
                if (callHistory.Status == CallStatus.Answered)
                {
                    var duration = (int)(DateTime.UtcNow - callHistory.StartTime).TotalSeconds;
                    callHistory.Duration = duration;
                }
                
                await _context.SaveChangesAsync();
            }
        }

        public async Task UpdateUserOnlineStatus(int userId, bool isOnline)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user != null)
            {
                user.IsOnline = isOnline;
                if (isOnline)
                {
                    user.LastLoginAt = DateTime.UtcNow;
                }
                await _context.SaveChangesAsync();
            }
        }

        public async Task<RoomResponseDto> CreateRoomAsync(int userId, CreateRoomDto createRoomDto)
        {
            var room = new Room
            {
                RoomName = createRoomDto.RoomName,
                RoomCode = GenerateRoomCode(),
                CreatedBy = userId,
                MaxParticipants = createRoomDto.MaxParticipants
            };

            _context.Rooms.Add(room);
            await _context.SaveChangesAsync();

            // 创建者自动加入房间
            var participant = new RoomParticipant
            {
                RoomId = room.Id,
                UserId = userId
            };

            _context.RoomParticipants.Add(participant);
            await _context.SaveChangesAsync();

            var creator = await _context.Users.FindAsync(userId);
            return new RoomResponseDto
            {
                Id = room.Id,
                RoomName = room.RoomName,
                RoomCode = room.RoomCode,
                Creator = MapToUserResponse(creator!),
                CreatedAt = room.CreatedAt,
                IsActive = room.IsActive,
                MaxParticipants = room.MaxParticipants,
                CurrentParticipants = 1,
                Participants = new List<UserResponseDto> { MapToUserResponse(creator!) }
            };
        }

        public async Task<RoomResponseDto> JoinRoomAsync(string roomCode, int userId)
        {
            var room = await _context.Rooms
                .Include(r => r.Creator)
                .Include(r => r.Participants)
                .ThenInclude(p => p.User)
                .FirstOrDefaultAsync(r => r.RoomCode == roomCode && r.IsActive);

            if (room == null)
                throw new InvalidOperationException("房间不存在或已关闭");

            var activeParticipants = room.Participants.Where(p => p.IsActive).Count();
            if (activeParticipants >= room.MaxParticipants)
                throw new InvalidOperationException("房间已满");

            // 检查用户是否已在房间中
            var existingParticipant = room.Participants
                .FirstOrDefault(p => p.UserId == userId && p.IsActive);

            if (existingParticipant == null)
            {
                var participant = new RoomParticipant
                {
                    RoomId = room.Id,
                    UserId = userId
                };

                _context.RoomParticipants.Add(participant);
                await _context.SaveChangesAsync();

                // 重新加载房间数据
                room = await _context.Rooms
                    .Include(r => r.Creator)
                    .Include(r => r.Participants)
                    .ThenInclude(p => p.User)
                    .FirstOrDefaultAsync(r => r.Id == room.Id);
            }

            var participants = room!.Participants
                .Where(p => p.IsActive)
                .Select(p => MapToUserResponse(p.User))
                .ToList();

            return new RoomResponseDto
            {
                Id = room.Id,
                RoomName = room.RoomName,
                RoomCode = room.RoomCode,
                Creator = MapToUserResponse(room.Creator),
                CreatedAt = room.CreatedAt,
                IsActive = room.IsActive,
                MaxParticipants = room.MaxParticipants,
                CurrentParticipants = participants.Count,
                Participants = participants
            };
        }

        public async Task LeaveRoomAsync(int roomId, int userId)
        {
            var participant = await _context.RoomParticipants
                .FirstOrDefaultAsync(p => p.RoomId == roomId && p.UserId == userId && p.IsActive);

            if (participant != null)
            {
                participant.IsActive = false;
                participant.LeftAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
        }

        public async Task<List<CallHistory>> GetCallHistoryAsync(int userId)
        {
            return await _context.CallHistories
                .Include(c => c.Caller)
                .Include(c => c.Receiver)
                .Where(c => c.CallerId == userId || c.ReceiverId == userId)
                .OrderByDescending(c => c.StartTime)
                .Take(50)
                .ToListAsync();
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                AvatarPath = user.AvatarPath,
                IsOnline = user.IsOnline,
                LastLoginAt = user.LastLoginAt
            };
        }

        private static string GenerateRoomCode()
        {
            var random = new Random();
            return random.Next(100000, 999999).ToString();
        }
    }

    // 通话会话类
    public class CallSession
    {
        public string Id { get; set; } = string.Empty;
        public int CallerId { get; set; }
        public int ReceiverId { get; set; }
        public CallType CallType { get; set; }
        public CallStatus Status { get; set; }
        public DateTime StartTime { get; set; }
        public int CallHistoryId { get; set; }
    }
}
