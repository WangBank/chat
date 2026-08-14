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
    public class ChatController : ControllerBase
    {
        private static readonly HashSet<string> BlockedUploadExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".html", ".htm", ".xhtml", ".svg", ".js", ".mjs", ".css",
            ".php", ".asp", ".aspx", ".jsp", ".jspx",
            ".exe", ".dll", ".bat", ".cmd", ".com", ".scr", ".ps1", ".sh",
            ".jar", ".msi", ".apk", ".ipa", ".deb", ".rpm"
        };

        private static readonly HashSet<string> BlockedUploadContentTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "text/html",
            "application/xhtml+xml",
            "image/svg+xml",
            "application/javascript",
            "text/javascript",
            "application/x-javascript",
            "application/x-msdownload",
            "application/x-sh",
            "application/x-msdos-program",
            "application/x-msi",
            "application/vnd.android.package-archive"
        };

        private readonly IChatService _chatService;
        private readonly IHubContext<VideoCallHub> _hubContext;
        private readonly ILogger<ChatController> _logger;
        private readonly IContentSecurityService _contentSecurity;

        public ChatController(
            IChatService chatService,
            IHubContext<VideoCallHub> hubContext,
            ILogger<ChatController> logger,
            IContentSecurityService contentSecurity)
        {
            _chatService = chatService;
            _hubContext = hubContext;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        [HttpPost("upload")]
        [RequestSizeLimit(20 * 1024 * 1024)]
        public async Task<ActionResult<ApiResponse<ChatUploadResponseDto>>> UploadChatFile([FromForm] ChatUploadRequestDto uploadDto)
        {
            var file = uploadDto.file;
            if (file == null || file.Length == 0)
            {
                return BadRequest(new ApiResponse<ChatUploadResponseDto>
                {
                    Success = false,
                    Message = "请选择要发送的文件"
                });
            }

            if (file.Length > 20 * 1024 * 1024)
            {
                return BadRequest(new ApiResponse<ChatUploadResponseDto>
                {
                    Success = false,
                    Message = "文件大小不能超过 20MB"
                });
            }

            try
            {
                var userId = GetUserId();
                var originalFileName = _contentSecurity.NormalizeRequiredText(
                    Path.GetFileName(file.FileName),
                    "文件名",
                    150,
                    filterSensitiveWords: false,
                    rejectSensitiveWords: true);
                var fileExtension = Path.GetExtension(originalFileName);
                if (BlockedUploadExtensions.Contains(fileExtension) ||
                    BlockedUploadContentTypes.Contains(NormalizeContentType(file.ContentType)))
                {
                    return BadRequest(new ApiResponse<ChatUploadResponseDto>
                    {
                        Success = false,
                        Message = "不支持上传该类型文件",
                        Errors = new List<string> { "该文件类型存在安全风险" }
                    });
                }

                var safeFileName = string.Join("_", originalFileName.Split(Path.GetInvalidFileNameChars(), StringSplitOptions.RemoveEmptyEntries));
                if (string.IsNullOrWhiteSpace(safeFileName))
                    safeFileName = "attachment";
                if (safeFileName.Length > 100)
                {
                    var extension = Path.GetExtension(safeFileName);
                    var nameWithoutExtension = Path.GetFileNameWithoutExtension(safeFileName);
                    safeFileName = $"{nameWithoutExtension[..Math.Min(nameWithoutExtension.Length, 90)]}{extension}";
                }

                var dateFolder = DateTime.UtcNow.ToString("yyyyMMdd");
                var uploadRoot = Path.Combine(Directory.GetCurrentDirectory(), "chat-files", dateFolder);
                Directory.CreateDirectory(uploadRoot);

                var storedFileName = $"{Guid.NewGuid():N}_{safeFileName}";
                var storedPath = Path.Combine(uploadRoot, storedFileName);
                await using (var stream = System.IO.File.Create(storedPath))
                {
                    await file.CopyToAsync(stream);
                }

                _logger.LogInformation("聊天文件上传成功: UserId={UserId}, FileName={FileName}, Size={Size}", userId, originalFileName, file.Length);

                return Ok(new ApiResponse<ChatUploadResponseDto>
                {
                    Success = true,
                    Message = "文件上传成功",
                    Data = new ChatUploadResponseDto
                    {
                        file_name = originalFileName,
                        file_path = $"/chat-files/{dateFolder}/{storedFileName}",
                        file_size = file.Length,
                        content_type = file.ContentType
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "聊天文件上传失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<ChatUploadResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "文件上传失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("send")]
        public async Task<ActionResult<ApiResponse<ChatMessageDto>>> SendMessage([FromBody] SendMessageDto sendMessageDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();
                
                return BadRequest(new ApiResponse<ChatMessageDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                _logger.LogInformation("发送消息: SenderId={SenderId}, ReceiverId={ReceiverId}, Type={Type}", userId, sendMessageDto.receiver_id, sendMessageDto.type);
                var message = await _chatService.SendMessageAsync(userId, sendMessageDto);
                
                // 通过SignalR发送新消息给接收者
                await _hubContext.Clients.Group($"user_{sendMessageDto.receiver_id}").SendAsync("NewMessage", message);
                // 同时发送给发送者（用于同步显示）
                await _hubContext.Clients.Group($"user_{userId}").SendAsync("NewMessage", message);
                
                _logger.LogInformation("消息发送成功: MessageId={MessageId}", message.id);
                return Ok(new ApiResponse<ChatMessageDto>
                {
                    Success = true,
                    Message = "消息发送成功",
                    Data = message
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送消息失败: SenderId={SenderId}, ReceiverId={ReceiverId}", GetUserId(), sendMessageDto.receiver_id);
                return BadRequest(new ApiResponse<ChatMessageDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送消息失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("history/{contactId}")]
        public async Task<ActionResult<ApiResponse<List<ChatMessageDto>>>> GetChatHistory(int contactId)
        {
            try
            {
                var userId = GetUserId();
                var messages = await _chatService.GetChatHistoryAsync(userId, contactId);
                
                return Ok(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = true,
                    Data = messages
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取聊天记录失败: UserId={UserId}, ContactId={ContactId}", GetUserId(), contactId);
                return BadRequest(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = false,
                    Message = "获取聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("messages/{messageId}/read")]
        public async Task<ActionResult<ApiResponse>> MarkMessageAsRead(int messageId)
        {
            try
            {
                var userId = GetUserId();
                await _chatService.MarkMessageAsReadAsync(messageId, userId);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "消息已标记为已读"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "标记消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("unread")]
        public async Task<ActionResult<ApiResponse<List<ChatMessageDto>>>> GetUnreadMessages()
        {
            try
            {
                var userId = GetUserId();
                var messages = await _chatService.GetUnreadMessagesAsync(userId);
                
                return Ok(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = true,
                    Data = messages
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = false,
                    Message = "获取未读消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("chat-history")]
        public async Task<ActionResult<ApiResponse<List<ChatHistoryDto>>>> GetChatHistory()
        {
            try
            {
                var userId = GetUserId();
                var chatHistory = await _chatService.GetChatHistoryAsync(userId);
                
                return Ok(new ApiResponse<List<ChatHistoryDto>>
                {
                    Success = true,
                    Data = chatHistory
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ChatHistoryDto>>
                {
                    Success = false,
                    Message = "获取聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("chat-history/{contactId}")]
        public async Task<ActionResult<ApiResponse>> DeleteChatHistory(int contactId)
        {
            try
            {
                var userId = GetUserId();
                await _chatService.DeleteChatHistoryAsync(userId, contactId);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "删除聊天记录成功"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
                throw new UnauthorizedAccessException("无效的用户ID");
            return userId;
        }

        private static string NormalizeContentType(string? contentType)
        {
            if (string.IsNullOrWhiteSpace(contentType))
                return string.Empty;

            return contentType.Split(';', 2)[0].Trim();
        }
    }
}
