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
        private readonly IContentSecurityService _contentSecurity;
        
        // 内存中的活跃通话管理
        private static readonly ConcurrentDictionary<string, CallSession> _activeCalls = new();

        public CallService(
            VideoCallDbContext context,
            ILogger<CallService> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        public async Task<CallResponseDto> InitiateCallAsync(int callerId, int receiverId, CallType callType)
        {
            // 检查用户是否存在
            var caller = await _context.users.FindAsync(callerId);
            var receiver = await _context.users.FindAsync(receiverId);

            if (caller == null || receiver == null)
            {
                _logger.LogWarning("发起通话失败，用户不存在: CallerId={CallerId}, ReceiverId={ReceiverId}", callerId, receiverId);
                throw new ArgumentException("用户不存在");
            }

            if (!OnlineStatusPolicy.IsOnline(receiver))
            {
                _logger.LogWarning("发起通话失败，用户不在线: CallerId={CallerId}, ReceiverId={ReceiverId}", callerId, receiverId);
                throw new InvalidOperationException("用户不在线");
            }

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

            _logger.LogInformation("发起通话: CallId={CallId}, CallerId={CallerId}, ReceiverId={ReceiverId}, CallType={CallType}", 
                callId, callerId, receiverId, callType);

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
            {
                _logger.LogWarning("结束通话失败，通话不存在: CallId={CallId}, UserId={UserId}", callId, userId);
                throw new InvalidOperationException("通话不存在");
            }

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

            _logger.LogInformation("结束通话: CallId={CallId}, UserId={UserId}", callId, userId);
        }

        public async Task UpdateUserOnlineStatus(int userId, bool isOnline)
        {
            var user = await _context.users.FindAsync(userId);
            if (user != null)
            {
                var now = DateTime.UtcNow;
                user.is_online = isOnline;
                if (isOnline)
                {
                    user.last_login_at = now;
                    user.last_heartbeat_at = now;
                }
                await _context.SaveChangesAsync();
            }
        }

        public async Task<RoomResponseDto> CreateRoomAsync(int userId, CreateRoomDto createRoomDto)
        {
            var roomName = _contentSecurity.NormalizeRequiredText(createRoomDto.room_name, "房间名称", 100);

            var room = new Room
            {
                room_name = roomName,
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

            _logger.LogInformation("创建房间: RoomId={RoomId}, RoomCode={RoomCode}, CreatorId={CreatorId}, RoomName={RoomName}", 
                room.id, room.room_code, userId, room.room_name);

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
                display_name = user.display_name,
                signature = user.signature,
                gender = user.gender,
                birthday = user.birthday,
                country = user.country,
                province = user.province,
                region = user.region,
                avatar_path = user.avatar_path,
                qq_bound = !string.IsNullOrWhiteSpace(user.qq_open_id),
                qq_nickname = user.qq_nickname,
                qq_avatar_url = user.qq_avatar_url,
                qq_bound_at = user.qq_bound_at,
                is_online = OnlineStatusPolicy.IsOnline(user),
                last_login_at = user.last_login_at,
                created_at = user.created_at,
                updated_at = user.updated_at
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
