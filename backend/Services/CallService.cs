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
            var caller = await _context.users.FindAsync(callerId);
            var receiver = await _context.users.FindAsync(receiverId);

            if (caller == null || receiver == null)
                throw new ArgumentException("用户不存在");

            if (!receiver.is_online)
                throw new InvalidOperationException("用户不在线");

            // 创建通话记录
            var callHistory = new CallHistory
            {
                caller_id = callerId,
                receiver_id = receiverId,
                call_type = callType,
                status = CallStatus.Initiated,
                start_time = DateTime.UtcNow
            };

            _context.CallHistories.Add(callHistory);
            await _context.SaveChangesAsync();

            var callId = Guid.NewGuid().ToString();
            
            // 创建通话会话
            var callSession = new CallSession
            {
                id = callId,
                caller_id = callerId,
                receiver_id = receiverId,
                CallType = callType,
                Status = CallStatus.Initiated,
                start_time = DateTime.UtcNow,
                CallHistoryId = callHistory.id
            };

            _activeCalls.TryAdd(callId, callSession);

            return new CallResponseDto
            {
                call_id = callId,
                caller = MapToUserResponse(caller),
                receiver = MapToUserResponse(receiver),
                call_type = callType,
                status = CallStatus.Initiated,
                start_time = DateTime.UtcNow
            };
        }

        public async Task<CallResponseDto> AnswerCallAsync(string callId, int userId, bool accept)
        {
            if (!_activeCalls.TryGetValue(callId, out var callSession))
                throw new InvalidOperationException("通话不存在");

            if (callSession.receiver_id != userId)
                throw new UnauthorizedAccessException("无权限操作此通话");

            var status = accept ? CallStatus.Answered : CallStatus.Rejected;
            callSession.Status = status;

            // 更新数据库记录
            var callHistory = await _context.CallHistories.FindAsync(callSession.CallHistoryId);
            if (callHistory != null)
            {
                callHistory.status = status;
                if (!accept)
                {
                    callHistory.end_time = DateTime.UtcNow;
                    callHistory.end_reason = "被拒绝";
                }
                await _context.SaveChangesAsync();
            }

            // 如果被拒绝，移除通话会话
            if (!accept)
            {
                _activeCalls.TryRemove(callId, out _);
            }

            var caller = await _context.users.FindAsync(callSession.caller_id);
            var receiver = await _context.users.FindAsync(callSession.receiver_id);

            return new CallResponseDto
            {
                call_id = callId,
                caller = MapToUserResponse(caller!),
                receiver = MapToUserResponse(receiver!),
                call_type = callSession.CallType,
                status = status,
                start_time = callSession.start_time
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
                callHistory.status = CallStatus.Ended;
                callHistory.end_time = DateTime.UtcNow;
                
                if (callHistory.status == CallStatus.Answered)
                {
                    var duration = (int)(DateTime.UtcNow - callHistory.start_time).TotalSeconds;
                    callHistory.duration = duration;
                }
                
                await _context.SaveChangesAsync();
            }
        }

        public async Task UpdateUserOnlineStatus(int userId, bool isOnline)
        {
            var user = await _context.users.FindAsync(userId);
            if (user != null)
            {
                user.is_online = isOnline;
                if (isOnline)
                {
                    user.last_login_at = DateTime.UtcNow;
                }
                await _context.SaveChangesAsync();
            }
        }

        public async Task<RoomResponseDto> CreateRoomAsync(int userId, CreateRoomDto createRoomDto)
        {
            var room = new Room
            {
                room_name = createRoomDto.room_name,
                room_code = GenerateRoomCode(),
                created_by = userId,
                max_participants = createRoomDto.max_participants
            };

            _context.Rooms.Add(room);
            await _context.SaveChangesAsync();

            // 创建者自动加入房间
            var participant = new RoomParticipant
            {
                room_id = room.id,
                user_id = userId
            };

            _context.RoomParticipants.Add(participant);
            await _context.SaveChangesAsync();

            var creator = await _context.users.FindAsync(userId);
            return new RoomResponseDto
            {
                id = room.id,
                room_name = room.room_name,
                room_code = room.room_code,
                creator = MapToUserResponse(creator!),
                created_at = room.created_at,
                is_active = room.is_active,
                max_participants = room.max_participants,
                current_participants = 1,
                participants = new List<UserResponseDto> { MapToUserResponse(creator!) }
            };
        }

        public async Task<RoomResponseDto> JoinRoomAsync(string roomCode, int userId)
        {
            var room = await _context.Rooms
                .Include(r => r.creator)
                .Include(r => r.participants)
                .ThenInclude(p => p.User)
                .FirstOrDefaultAsync(r => r.room_code == roomCode && r.is_active);

            if (room == null)
                throw new InvalidOperationException("房间不存在或已关闭");

            var activeParticipants = room.participants.Where(p => p.is_active).Count();
            if (activeParticipants >= room.max_participants)
                throw new InvalidOperationException("房间已满");

            // 检查用户是否已在房间中
            var existingParticipant = room.participants
                .FirstOrDefault(p => p.user_id == userId && p.is_active);

            if (existingParticipant == null)
            {
                var participant = new RoomParticipant
                {
                    room_id = room.id,
                    user_id = userId
                };

                _context.RoomParticipants.Add(participant);
                await _context.SaveChangesAsync();

                // 重新加载房间数据
                room = await _context.Rooms
                    .Include(r => r.creator)
                    .Include(r => r.participants)
                    .ThenInclude(p => p.User)
                    .FirstOrDefaultAsync(r => r.id == room.id);
            }

            var participants = room!.participants
                .Where(p => p.is_active)
                .Select(p => MapToUserResponse(p.User))
                .ToList();

            return new RoomResponseDto
            {
                id = room.id,
                room_name = room.room_name,
                room_code = room.room_code,
                creator = MapToUserResponse(room.creator),
                created_at = room.created_at,
                is_active = room.is_active,
                max_participants = room.max_participants,
                current_participants = participants.Count,
                participants = participants
            };
        }

        public async Task LeaveRoomAsync(int roomId, int userId)
        {
            var participant = await _context.RoomParticipants
                .FirstOrDefaultAsync(p => p.room_id == roomId && p.user_id == userId && p.is_active);

            if (participant != null)
            {
                participant.is_active = false;
                participant.left_at = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
        }

        public async Task<List<CallHistory>> GetCallHistoryAsync(int userId)
        {
            return await _context.CallHistories
                .Include(c => c.Caller)
                .Include(c => c.receiver)
                .Where(c => c.caller_id == userId || c.receiver_id == userId)
                .OrderByDescending(c => c.start_time)
                .Take(50)
                .ToListAsync();
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                id = user.id,
                username = user.username,
                email = user.email,
                avatar_path = user.avatar_path,
                is_online = user.is_online,
                last_login_at = user.last_login_at
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
        public string id { get; set; } = string.Empty;
        public int caller_id { get; set; }
        public int receiver_id { get; set; }
        public CallType CallType { get; set; }
        public CallStatus Status { get; set; }
        public DateTime start_time { get; set; }
        public int CallHistoryId { get; set; }
    }
}
