using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using VideoCallAPI.Models;
using VideoCallAPI.Data;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Hubs;
using BCrypt.Net;

namespace VideoCallAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class GroupsController : ControllerBase
    {
        private readonly VideoCallDbContext _context;
        private readonly ILogger<GroupsController> _logger;
        private readonly IContentSecurityService _contentSecurity;

        public GroupsController(
            VideoCallDbContext context,
            ILogger<GroupsController> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<ChatGroupResponseDto>>>> GetGroups()
        {
            try
            {
                var userId = GetUserId();
                var groups = await _context.ChatGroups
                    .Include(g => g.members)
                        .ThenInclude(m => m.user)
                    .Where(g => g.members.Any(m => m.user_id == userId && m.is_active))
                    .OrderByDescending(g => g.pinned)
                    .ThenByDescending(g => g.updated_at)
                    .ToListAsync();

                return Ok(new ApiResponse<List<ChatGroupResponseDto>>
                {
                    Success = true,
                    Data = groups.Select(MapToChatGroupDto).ToList()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取群聊列表失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<ChatGroupResponseDto>>
                {
                    Success = false,
                    Message = "获取群聊列表失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<ChatGroupResponseDto>>> CreateGroup(CreateChatGroupDto createDto)
        {
            try
            {
                var userId = GetUserId();
                var memberIds = createDto.member_ids
                    .Where(id => id != userId)
                    .Distinct()
                    .ToList();

                if (memberIds.Count == 0)
                {
                    return BadRequest(new ApiResponse<ChatGroupResponseDto>
                    {
                        Success = false,
                        Message = "至少选择一个好友"
                    });
                }

                var contactIds = await _context.Contacts
                    .Where(c => c.user_id == userId && memberIds.Contains(c.contact_user_id))
                    .Select(c => c.contact_user_id)
                    .ToListAsync();

                var missingIds = memberIds.Except(contactIds).ToList();
                if (missingIds.Count > 0)
                {
                    return BadRequest(new ApiResponse<ChatGroupResponseDto>
                    {
                        Success = false,
                        Message = "群成员必须先添加为好友"
                    });
                }

                var now = DateTime.UtcNow;
                var group = new ChatGroup
                {
                    name = _contentSecurity.NormalizeOptionalText(
                        createDto.name,
                        "群聊名称",
                        80,
                        rejectSensitiveWords: true) ?? "未命名的群聊",
                    category = _contentSecurity.NormalizeOptionalText(
                        createDto.category,
                        "群聊分类",
                        50,
                        rejectSensitiveWords: true) ?? "我创建的群聊",
                    owner_id = userId,
                    pinned = createDto.pinned,
                    created_at = now,
                    updated_at = now
                };

                group.members.Add(new ChatGroupMember
                {
                    user_id = userId,
                    role = "owner",
                    joined_at = now,
                    is_active = true
                });

                foreach (var memberId in memberIds)
                {
                    group.members.Add(new ChatGroupMember
                    {
                        user_id = memberId,
                        role = "member",
                        joined_at = now,
                        is_active = true
                    });
                }

                _context.ChatGroups.Add(group);
                await _context.SaveChangesAsync();

                var created = await _context.ChatGroups
                    .Include(g => g.members)
                        .ThenInclude(m => m.user)
                    .FirstAsync(g => g.id == group.id);

                return Ok(new ApiResponse<ChatGroupResponseDto>
                {
                    Success = true,
                    Message = "群聊已创建",
                    Data = MapToChatGroupDto(created)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "创建群聊失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<ChatGroupResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "创建群聊失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("{groupId}/messages")]
        public async Task<ActionResult<ApiResponse<List<GroupChatMessageDto>>>> GetMessages(int groupId)
        {
            try
            {
                var userId = GetUserId();
                if (!await IsGroupMember(groupId, userId))
                {
                    return Forbid();
                }

                var messages = await _context.GroupChatMessages
                    .Include(m => m.sender)
                    .Where(m => m.group_id == groupId)
                    .OrderBy(m => m.created_at)
                    .Take(200)
                    .ToListAsync();

                return Ok(new ApiResponse<List<GroupChatMessageDto>>
                {
                    Success = true,
                    Data = messages.Select(MapToGroupMessageDto).ToList()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取群聊消息失败: UserId={UserId}, GroupId={GroupId}", GetUserId(), groupId);
                return BadRequest(new ApiResponse<List<GroupChatMessageDto>>
                {
                    Success = false,
                    Message = "获取群聊消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("{groupId}/messages")]
        public async Task<ActionResult<ApiResponse<GroupChatMessageDto>>> SendMessage(int groupId, SendGroupMessageDto messageDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<GroupChatMessageDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                if (!await IsGroupMember(groupId, userId))
                {
                    return Forbid();
                }

                var now = DateTime.UtcNow;
                var content = _contentSecurity.NormalizeRequiredText(
                    messageDto.content,
                    "消息内容",
                    1000,
                    rejectSensitiveWords: true);
                var filePath = _contentSecurity.NormalizeStoredFilePath(messageDto.file_path, "文件路径", "/chat-files/");
                var duration = messageDto.duration;
                if (duration.HasValue && (duration.Value < 0 || duration.Value > 3600))
                    throw new ArgumentException("消息时长不合法");
                var replySnapshot = await GetGroupReplySnapshotAsync(groupId, messageDto.reply_to_message_id);
                var message = new GroupChatMessage
                {
                    group_id = groupId,
                    sender_id = userId,
                    content = content,
                    type = messageDto.type,
                    file_path = filePath,
                    file_size = messageDto.file_size,
                    duration = duration,
                    reply_to_message_id = replySnapshot?.id,
                    reply_to_sender_name = replySnapshot?.sender_name,
                    reply_to_content = replySnapshot?.content,
                    reply_to_type = replySnapshot?.type,
                    reply_to_file_path = replySnapshot?.file_path,
                    timestamp = now,
                    created_at = now
                };

                _context.GroupChatMessages.Add(message);

                var group = await _context.ChatGroups.FindAsync(groupId);
                if (group != null)
                {
                    group.updated_at = now;
                }

                await _context.SaveChangesAsync();

                var saved = await _context.GroupChatMessages
                    .Include(m => m.sender)
                    .FirstAsync(m => m.id == message.id);

                return Ok(new ApiResponse<GroupChatMessageDto>
                {
                    Success = true,
                    Message = "群消息发送成功",
                    Data = MapToGroupMessageDto(saved)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送群聊消息失败: UserId={UserId}, GroupId={GroupId}", GetUserId(), groupId);
                return BadRequest(new ApiResponse<GroupChatMessageDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送群聊消息失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private async Task<bool> IsGroupMember(int groupId, int userId)
        {
            return await _context.ChatGroupMembers
                .AnyAsync(m => m.group_id == groupId && m.user_id == userId && m.is_active);
        }

        private static ChatGroupResponseDto MapToChatGroupDto(ChatGroup group)
        {
            var activeMembers = group.members
                .Where(m => m.is_active)
                .OrderByDescending(m => m.role == "owner")
                .ThenBy(m => m.joined_at)
                .ToList();

            return new ChatGroupResponseDto
            {
                id = group.id,
                name = group.name,
                category = group.category,
                member_ids = activeMembers.Select(m => m.user_id).Where(id => id != group.owner_id).ToList(),
                members = activeMembers.Select(m => MapToUserResponse(m.user)).ToList(),
                pinned = group.pinned,
                owner_id = group.owner_id,
                announcement = group.announcement,
                note = group.note,
                created_at = group.created_at,
                updated_at = group.updated_at
            };
        }

        private static GroupChatMessageDto MapToGroupMessageDto(GroupChatMessage message)
        {
            return new GroupChatMessageDto
            {
                id = message.id,
                group_id = message.group_id,
                sender_id = message.sender_id,
                sender_name = GetDisplayName(message.sender),
                content = message.content,
                type = message.type,
                timestamp = message.timestamp,
                file_path = message.file_path,
                file_size = message.file_size,
                duration = message.duration,
                reply_to_message_id = message.reply_to_message_id,
                reply_to = CreateReplySnapshot(
                    message.reply_to_message_id,
                    message.reply_to_sender_name,
                    message.reply_to_content,
                    message.reply_to_type,
                    message.reply_to_file_path),
                created_at = message.created_at,
                sender = MapToUserResponse(message.sender)
            };
        }

        private async Task<ReplyMessageSnapshotDto?> GetGroupReplySnapshotAsync(int groupId, int? replyToMessageId)
        {
            if (!replyToMessageId.HasValue)
                return null;

            var replyMessage = await _context.GroupChatMessages
                .Include(m => m.sender)
                .FirstOrDefaultAsync(m => m.id == replyToMessageId.Value && m.group_id == groupId);

            if (replyMessage == null)
                throw new ArgumentException("引用消息不存在");

            return new ReplyMessageSnapshotDto
            {
                id = replyMessage.id,
                sender_name = GetDisplayName(replyMessage.sender),
                content = BuildReplyPreview(replyMessage.content, replyMessage.type),
                type = replyMessage.type,
                file_path = replyMessage.file_path
            };
        }

        private static ReplyMessageSnapshotDto? CreateReplySnapshot(
            int? id,
            string? senderName,
            string? content,
            MessageType? type,
            string? filePath)
        {
            if (!id.HasValue || string.IsNullOrWhiteSpace(senderName) || string.IsNullOrWhiteSpace(content))
                return null;

            return new ReplyMessageSnapshotDto
            {
                id = id,
                sender_name = senderName,
                content = content,
                type = type ?? MessageType.Text,
                file_path = filePath
            };
        }

        private static string BuildReplyPreview(string? content, MessageType type)
        {
            var text = content?.Trim() ?? string.Empty;
            var value = type switch
            {
                MessageType.Image => "[图片]",
                MessageType.Video => "[视频]",
                MessageType.Audio => string.IsNullOrWhiteSpace(text)
                    ? GetMessageTypeLabel(type)
                    : text.StartsWith("[语音]") ? text : $"[语音] {text}",
                MessageType.File => string.IsNullOrWhiteSpace(text)
                    ? GetMessageTypeLabel(type)
                    : text.StartsWith("[文件]") ? text : $"[文件] {text}",
                MessageType.Text => string.IsNullOrWhiteSpace(text) ? GetMessageTypeLabel(type) : text,
                _ => string.IsNullOrWhiteSpace(text) ? GetMessageTypeLabel(type) : text
            };
            return value.Length > 300 ? value[..300] : value;
        }

        private static string GetMessageTypeLabel(MessageType type)
        {
            return type switch
            {
                MessageType.Image => "[图片]",
                MessageType.Video => "[视频]",
                MessageType.Audio => "[语音]",
                MessageType.File => "[文件]",
                _ => "[消息]"
            };
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

        private static string GetDisplayName(User user)
        {
            return string.IsNullOrWhiteSpace(user.display_name) ? user.username : user.display_name;
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
                throw new UnauthorizedAccessException("无效的用户ID");
            return userId;
        }
    }
}
