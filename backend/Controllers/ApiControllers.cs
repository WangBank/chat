using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.Security.Claims;
using VideoCallAPI.Models;
using System.Text.Json;
using VideoCallAPI.Data;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Hubs;
using BCrypt.Net;

namespace VideoCallAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private static readonly HashSet<string> AllowedAvatarContentTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg",
            "image/png",
            "image/gif"
        };

        private readonly IUserService _userService;
        private readonly IJwtService _jwtService;
        private readonly IQQAuthService _qqAuthService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(
            IUserService userService,
            IJwtService jwtService,
            IQQAuthService qqAuthService,
            ILogger<AuthController> logger)
        {
            _userService = userService;
            _jwtService = jwtService;
            _qqAuthService = qqAuthService;
            _logger = logger;
        }

        [HttpPost("register")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> Register(UserRegistrationDto registrationDto)
        {
            try
            {
                _logger.LogInformation("用户注册请求: {Username}, {Email}", registrationDto.username, registrationDto.email);
                var user = await _userService.RegisterAsync(registrationDto);
                _logger.LogInformation("用户注册成功: UserId={UserId}, Username={Username}", user.id, user.username);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "注册成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用户注册失败: Username={Username}, Email={Email}", registrationDto.username, registrationDto.email);
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "注册失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("login")]
        public async Task<ActionResult<ApiResponse<object>>> Login(UserLoginDto loginDto)
        {
            try
            {
                _logger.LogInformation("用户登录请求: {Username}", loginDto.username);
                var token = await _userService.LoginAsync(loginDto);
                var userId = _jwtService.GetUserIdFromToken(token);
                
                if (userId == null)
                {
                    _logger.LogWarning("登录失败，无法从Token中获取用户ID: {Username}", loginDto.username);
                    return BadRequest(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "登录失败",
                        Errors = new List<string> { "无法从Token中获取用户ID" }
                    });
                }
                
                var user = await _userService.GetUserByIdAsync(userId.Value);
                _logger.LogInformation("用户登录成功: UserId={UserId}, Username={Username}", userId.Value, loginDto.username);

                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Message = "登录成功",
                    Data = new
                    {
                        Token = token,
                        User = user
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用户登录失败: Username={Username}", loginDto.username);
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = "登录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("qq/login-url")]
        public ActionResult<ApiResponse<QQLoginUrlResponseDto>> GetQQLoginUrl([FromQuery] string mode = "login")
        {
            try
            {
                var loginUrl = _qqAuthService.CreateLoginUrl(mode);
                return Ok(new ApiResponse<QQLoginUrlResponseDto>
                {
                    Success = true,
                    Message = loginUrl.configured ? "QQ授权地址已生成" : "QQ登录尚未配置",
                    Data = loginUrl
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "生成QQ授权地址失败: Mode={Mode}", mode);
                return BadRequest(new ApiResponse<QQLoginUrlResponseDto>
                {
                    Success = false,
                    Message = "生成QQ授权地址失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("qq/login")]
        public async Task<ActionResult<ApiResponse<object>>> QQLogin(QQLoginRequestDto loginDto)
        {
            try
            {
                var result = await _qqAuthService.CompleteLoginAsync(loginDto);
                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Message = "QQ登录成功",
                    Data = new
                    {
                        Token = result.Token,
                        User = result.User
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "QQ登录失败");
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = "QQ登录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("qq/bind")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> BindQQ(QQLoginRequestDto loginDto)
        {
            try
            {
                var user = await _qqAuthService.BindAsync(GetUserId(), loginDto);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "QQ绑定成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "QQ绑定失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "QQ绑定失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("qq/dev-login")]
        public async Task<ActionResult<ApiResponse<object>>> QQDevLogin(QQDevLoginDto loginDto)
        {
            try
            {
                var result = await _qqAuthService.DevLoginAsync(loginDto);
                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Message = "QQ测试登录成功",
                    Data = new
                    {
                        Token = result.Token,
                        User = result.User
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "QQ测试登录失败");
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = "QQ测试登录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("qq/dev-bind")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> QQDevBind(QQDevLoginDto loginDto)
        {
            try
            {
                var user = await _qqAuthService.DevBindAsync(GetUserId(), loginDto);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "QQ测试绑定成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "QQ测试绑定失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "QQ测试绑定失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-password")]
        [Authorize]
        public async Task<ActionResult<ApiResponse>> ChangePassword(ChangePasswordDto changePasswordDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("用户修改密码请求: UserId={UserId}", userId);
                var success = await _userService.ChangePasswordAsync(userId, changePasswordDto);
                
                if (success)
                {
                    _logger.LogInformation("密码修改成功: UserId={UserId}", userId);
                    return Ok(new ApiResponse
                    {
                        Success = true,
                        Message = "密码修改成功"
                    });
                }
                
                _logger.LogWarning("密码修改失败: UserId={UserId}", userId);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "密码修改失败"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "密码修改失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "密码修改失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("profile")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> GetProfile()
        {
            try
            {
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取用户信息失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "获取用户信息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPut("profile")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> UpdateProfile([FromBody] UpdateProfileDto updateProfileDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("更新用户个人资料: UserId={UserId}", userId);
                var result = await _userService.UpdateProfileAsync(userId, updateProfileDto);
                _logger.LogInformation("用户个人资料更新成功: UserId={UserId}", userId);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "个人资料更新成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "更新用户个人资料失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "更新失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("upload-avatar")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> UploadAvatar(IFormFile avatar)
        {
            try
            {
                if (avatar == null || avatar.Length == 0)
                {
                    _logger.LogWarning("头像上传失败: 文件为空");
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "请选择头像文件",
                        Errors = new List<string> { "头像文件不能为空" }
                    });
                }

                // 检查文件类型
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif" };
                var fileExtension = Path.GetExtension(avatar.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(fileExtension))
                {
                    _logger.LogWarning("头像上传失败: 不支持的文件格式 {Extension}", fileExtension);
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "不支持的文件格式",
                        Errors = new List<string> { "只支持 JPG, JPEG, PNG, GIF 格式的图片" }
                    });
                }

                var avatarContentType = NormalizeContentType(avatar.ContentType);
                if (!string.IsNullOrWhiteSpace(avatarContentType) &&
                    !string.Equals(avatarContentType, "application/octet-stream", StringComparison.OrdinalIgnoreCase) &&
                    !AllowedAvatarContentTypes.Contains(avatarContentType))
                {
                    _logger.LogWarning("头像上传失败: 不支持的内容类型 {ContentType}", avatar.ContentType);
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "不支持的文件格式",
                        Errors = new List<string> { "头像文件内容类型不正确" }
                    });
                }

                // 检查文件大小 (最大 5MB)
                if (avatar.Length > 5 * 1024 * 1024)
                {
                    _logger.LogWarning("头像上传失败: 文件过大 {Size}MB", avatar.Length / (1024 * 1024));
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "文件太大",
                        Errors = new List<string> { "头像文件不能超过 5MB" }
                    });
                }

                var userId = GetUserId();
                _logger.LogInformation("用户上传头像: UserId={UserId}, FileName={FileName}, Size={Size}", userId, avatar.FileName, avatar.Length);
                var result = await _userService.UploadAvatarAsync(userId, avatar);
                _logger.LogInformation("头像上传成功: UserId={UserId}", userId);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "头像上传成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "头像上传失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "头像上传失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("search-users")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserSearchResultDto>>> SearchUsers([FromQuery] string query = "", [FromQuery] int page = 1, [FromQuery] int page_size = 20)
        {
            try
            {
                var userId = GetUserId();
                var searchDto = new SearchUsersDto
                {
                    query = query,
                    page = page,
                    page_size = page_size
                };
                
                var result = await _userService.SearchUsersAsync(userId, searchDto);
                return Ok(new ApiResponse<UserSearchResultDto>
                {
                    Success = true,
                    Message = "搜索成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "搜索用户失败: UserId={UserId}, Query={Query}", GetUserId(), query);
                return BadRequest(new ApiResponse<UserSearchResultDto>
                {
                    Success = false,
                    Message = "搜索失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            throw new UnauthorizedAccessException("用户未登录");
        }

        private static string NormalizeContentType(string? contentType)
        {
            if (string.IsNullOrWhiteSpace(contentType))
                return string.Empty;

            return contentType.Split(';', 2)[0].Trim();
        }

    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ContactsController : ControllerBase
    {
        private readonly IContactService _contactService;
        private readonly ILogger<ContactsController> _logger;

        public ContactsController(IContactService contactService, ILogger<ContactsController> logger)
        {
            _contactService = contactService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<ContactResponseDto>>>> GetContacts()
        {
            try
            {
                var userId = GetUserId();
                var contacts = await _contactService.GetContactsAsync(userId);
                System.Console.WriteLine(JsonSerializer.Serialize(contacts));
                return Ok(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = true,
                    Data = contacts
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取联系人列表失败: UserId={UserId}", GetUserId());
                Console.WriteLine(ex.Message);
                return BadRequest(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = false,
                    Message = "获取联系人失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("search")]
        public async Task<ActionResult<ApiResponse<List<ContactResponseDto>>>> SearchContacts([FromQuery] string query)
        {
            try
            {
                var userId = GetUserId();
                var contacts = await _contactService.SearchContactsAsync(userId, query);
                
                return Ok(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = true,
                    Data = contacts
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = false,
                    Message = "搜索联系人失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<ContactResponseDto>>> AddContact(AddContactDto addContactDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("添加联系人请求: UserId={UserId}, ContactUsername={ContactUsername}", userId, addContactDto.username);
                var contact = await _contactService.AddContactAsync(userId, addContactDto);
                _logger.LogInformation("添加联系人成功: UserId={UserId}, ContactId={ContactId}", userId, contact.id);
                
                return Ok(new ApiResponse<ContactResponseDto>
                {
                    Success = true,
                    Message = "添加联系人成功",
                    Data = contact
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "添加联系人失败: UserId={UserId}, ContactUsername={ContactUsername}", GetUserId(), addContactDto.username);
                return BadRequest(new ApiResponse<ContactResponseDto>
                {
                    Success = false,
                    Message = "添加联系人失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("friend-requests")]
        public async Task<ActionResult<ApiResponse<List<FriendRequestResponseDto>>>> GetFriendRequests()
        {
            try
            {
                var userId = GetUserId();
                var requests = await _contactService.GetFriendRequestsAsync(userId);

                return Ok(new ApiResponse<List<FriendRequestResponseDto>>
                {
                    Success = true,
                    Data = requests
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取好友申请失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<FriendRequestResponseDto>>
                {
                    Success = false,
                    Message = "获取好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("friend-requests")]
        public async Task<ActionResult<ApiResponse<FriendRequestResponseDto>>> CreateFriendRequest(CreateFriendRequestDto requestDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var request = await _contactService.CreateFriendRequestAsync(userId, requestDto);

                return Ok(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = true,
                    Message = request.direction == "incoming" ? "对方已向你发送好友申请，请在好友通知中处理" : "好友申请已发送",
                    Data = request
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送好友申请失败: UserId={UserId}, ContactUsername={ContactUsername}", GetUserId(), requestDto.username);
                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = "发送好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("friend-requests/{requestId}")]
        public async Task<ActionResult<ApiResponse<FriendRequestResponseDto>>> RespondFriendRequest(int requestId, FriendRequestDecisionDto decisionDto)
        {
            try
            {
                var userId = GetUserId();
                var request = await _contactService.RespondFriendRequestAsync(userId, requestId, decisionDto);

                return Ok(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = true,
                    Message = request.status == "accepted" ? "已同意好友申请" : "已拒绝好友申请",
                    Data = request
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "处理好友申请失败: UserId={UserId}, RequestId={RequestId}", GetUserId(), requestId);
                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = "处理好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("friend-requests/handled")]
        public async Task<ActionResult<ApiResponse>> ClearHandledFriendRequests()
        {
            try
            {
                var userId = GetUserId();
                await _contactService.ClearHandledFriendRequestsAsync(userId);

                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "已清理处理过的好友申请"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "清理好友申请失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "清理好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("{contactId}")]
        public async Task<ActionResult<ApiResponse>> RemoveContact(int contactId)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("删除联系人请求: UserId={UserId}, ContactId={ContactId}", userId, contactId);
                await _contactService.RemoveContactAsync(userId, contactId);
                _logger.LogInformation("删除联系人成功: UserId={UserId}, ContactId={ContactId}", userId, contactId);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "联系人删除成功"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "删除联系人失败: UserId={UserId}, ContactId={ContactId}", GetUserId(), contactId);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("{contactId}/block")]
        public async Task<ActionResult<ApiResponse>> BlockContact(int contactId, [FromBody] bool isBlocked)
        {
            try
            {
                var userId = GetUserId();
                await _contactService.BlockContactAsync(userId, contactId, isBlocked);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = isBlocked ? "联系人已屏蔽" : "联系人已取消屏蔽"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "操作失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("{contactId}/display-name")]
        public async Task<ActionResult<ApiResponse<ContactResponseDto>>> UpdateDisplayName(int contactId, [FromBody] string displayName)
        {
            try
            {
                var userId = GetUserId();
                var contact = await _contactService.UpdateContactDisplayNameAsync(userId, contactId, displayName);
                
                return Ok(new ApiResponse<ContactResponseDto>
                {
                    Success = true,
                    Message = "备注修改成功",
                    Data = contact
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<ContactResponseDto>
                {
                    Success = false,
                    Message = "修改备注失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            throw new UnauthorizedAccessException("用户未登录");
        }
    }

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
                    filterSensitiveWords: false);
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
                    Message = "文件上传失败",
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
                    Message = "发送消息失败",
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
                    name = _contentSecurity.NormalizeOptionalText(createDto.name, "群聊名称", 80) ?? "未命名的群聊",
                    category = _contentSecurity.NormalizeOptionalText(createDto.category, "群聊分类", 50) ?? "我创建的群聊",
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
                    Message = "创建群聊失败",
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
                var content = _contentSecurity.NormalizeRequiredText(messageDto.content, "消息内容", 1000);
                var filePath = _contentSecurity.NormalizeStoredFilePath(messageDto.file_path, "文件路径", "/chat-files/");
                var duration = messageDto.duration;
                if (duration.HasValue && (duration.Value < 0 || duration.Value > 3600))
                    throw new ArgumentException("消息时长不合法");
                var message = new GroupChatMessage
                {
                    group_id = groupId,
                    sender_id = userId,
                    content = content,
                    type = messageDto.type,
                    file_path = filePath,
                    file_size = messageDto.file_size,
                    duration = duration,
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
                    Message = "发送群聊消息失败",
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
                created_at = message.created_at,
                sender = MapToUserResponse(message.sender)
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

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class FavoritesController : ControllerBase
    {
        private static readonly HashSet<string> AllowedFavoriteTypes = new() { "chat", "media", "file", "link", "note" };
        private readonly VideoCallDbContext _context;
        private readonly ILogger<FavoritesController> _logger;
        private readonly IContentSecurityService _contentSecurity;

        public FavoritesController(
            VideoCallDbContext context,
            ILogger<FavoritesController> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<FavoriteItemResponseDto>>>> GetFavorites([FromQuery] string? type = null, [FromQuery] string? query = null)
        {
            try
            {
                var userId = GetUserId();
                var favoritesQuery = _context.FavoriteItems
                    .Where(item => item.user_id == userId);

                var normalizedType = _contentSecurity.NormalizeOptionalText(type, "收藏类型", 20, filterSensitiveWords: false)?.ToLower();
                if (!string.IsNullOrWhiteSpace(normalizedType) && normalizedType != "all")
                {
                    favoritesQuery = favoritesQuery.Where(item => item.type == normalizedType);
                }

                if (!string.IsNullOrWhiteSpace(query))
                {
                    var keyword = _contentSecurity
                        .NormalizeRequiredText(query, "搜索内容", 100, filterSensitiveWords: false)
                        .ToLower();
                    favoritesQuery = favoritesQuery.Where(item =>
                        item.content.ToLower().Contains(keyword) ||
                        item.source_name.ToLower().Contains(keyword));
                }

                var favorites = await favoritesQuery
                    .OrderByDescending(item => item.created_at)
                    .Take(500)
                    .ToListAsync();

                return Ok(new ApiResponse<List<FavoriteItemResponseDto>>
                {
                    Success = true,
                    Data = favorites.Select(MapToFavoriteDto).ToList()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取收藏失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<FavoriteItemResponseDto>>
                {
                    Success = false,
                    Message = "获取收藏失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<FavoriteItemResponseDto>>> CreateFavorite(CreateFavoriteItemDto createDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var favoriteType = _contentSecurity
                    .NormalizeRequiredText(createDto.type, "收藏类型", 20, filterSensitiveWords: false)
                    .ToLower();
                if (!AllowedFavoriteTypes.Contains(favoriteType))
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "不支持的收藏类型"
                    });
                }

                var content = _contentSecurity.NormalizeRequiredText(createDto.content, "收藏内容", 1000);
                var sourceName = _contentSecurity.NormalizeOptionalText(createDto.source_name, "来源名称", 100) ?? "我的账号";
                var filePath = _contentSecurity.NormalizeStoredFilePath(createDto.file_path, "文件路径", "/chat-files/");

                var exists = await _context.FavoriteItems.AnyAsync(item =>
                    item.user_id == userId &&
                    item.type == favoriteType &&
                    item.content == content &&
                    item.source_name == sourceName &&
                    item.file_path == filePath);

                if (exists)
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "已经收藏过了"
                    });
                }

                var favorite = new FavoriteItem
                {
                    user_id = userId,
                    content = content,
                    type = favoriteType,
                    source_name = sourceName,
                    file_path = filePath,
                    file_size = createDto.file_size,
                    created_at = DateTime.UtcNow
                };

                _context.FavoriteItems.Add(favorite);
                await _context.SaveChangesAsync();

                return Ok(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = true,
                    Message = "已添加到收藏",
                    Data = MapToFavoriteDto(favorite)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "创建收藏失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = "创建收藏失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("{favoriteId}")]
        public async Task<ActionResult<ApiResponse>> DeleteFavorite(int favoriteId)
        {
            try
            {
                var userId = GetUserId();
                var favorite = await _context.FavoriteItems
                    .FirstOrDefaultAsync(item => item.id == favoriteId && item.user_id == userId);

                if (favorite == null)
                {
                    return NotFound(new ApiResponse
                    {
                        Success = false,
                        Message = "收藏不存在"
                    });
                }

                _context.FavoriteItems.Remove(favorite);
                await _context.SaveChangesAsync();

                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "收藏已删除"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "删除收藏失败: UserId={UserId}, FavoriteId={FavoriteId}", GetUserId(), favoriteId);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除收藏失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private static FavoriteItemResponseDto MapToFavoriteDto(FavoriteItem favorite)
        {
            return new FavoriteItemResponseDto
            {
                id = favorite.id,
                content = favorite.content,
                type = favorite.type,
                source_name = favorite.source_name,
                file_path = favorite.file_path,
                file_size = favorite.file_size,
                created_at = favorite.created_at
            };
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
                throw new UnauthorizedAccessException("无效的用户ID");
            return userId;
        }
    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class CallsController : ControllerBase
    {
        private readonly ICallService _callService;
        private readonly ILogger<CallsController> _logger;

        public CallsController(ICallService callService, ILogger<CallsController> logger)
        {
            _callService = callService;
            _logger = logger;
        }

        [HttpGet("history")]
        public async Task<ActionResult<ApiResponse<List<CallHistory>>>> GetCallHistory()
        {
            try
            {
                var userId = GetUserId();
                var history = await _callService.GetCallHistoryAsync(userId);
                
                return Ok(new ApiResponse<List<CallHistory>>
                {
                    Success = true,
                    Data = history
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取通话记录失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<CallHistory>>
                {
                    Success = false,
                    Message = "获取通话记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("rooms")]
        public async Task<ActionResult<ApiResponse<RoomResponseDto>>> CreateRoom(CreateRoomDto createRoomDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("创建房间请求: UserId={UserId}, RoomName={RoomName}", userId, createRoomDto.room_name);
                var room = await _callService.CreateRoomAsync(userId, createRoomDto);
                _logger.LogInformation("房间创建成功: RoomId={RoomId}", room.id);
                
                return Ok(new ApiResponse<RoomResponseDto>
                {
                    Success = true,
                    Message = "房间创建成功",
                    Data = room
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "房间创建失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<RoomResponseDto>
                {
                    Success = false,
                    Message = "房间创建失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            throw new UnauthorizedAccessException("用户未登录");
        }
    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class AdminController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly VideoCallDbContext _context;
        private readonly ILogger<AdminController> _logger;

        public AdminController(IUserService userService, VideoCallDbContext context, ILogger<AdminController> logger)
        {
            _userService = userService;
            _context = context;
            _logger = logger;
        }

        [HttpGet("online-users")]
        public async Task<ActionResult<ApiResponse<List<UserResponseDto>>>> GetOnlineUsers()
        {
            try
            {
                // 检查是否是管理员
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                if (user == null || user.username != "admin")
                {
                    _logger.LogWarning("非管理员尝试访问在线用户列表: UserId={UserId}", userId);
                    return Unauthorized(new ApiResponse<List<UserResponseDto>>
                    {
                        Success = false,
                        Message = "无权访问"
                    });
                }

                var onlineCutoff = OnlineStatusPolicy.GetOnlineCutoffUtc(DateTime.UtcNow);

                var onlineUsers = await _context.users
                    .Where(u => u.is_online
                        && u.last_heartbeat_at.HasValue
                        && u.last_heartbeat_at.Value >= onlineCutoff)
                    .Select(u => new UserResponseDto
                    {
                        id = u.id,
                        username = u.username,
                        email = u.email,
                        display_name = u.display_name,
                        signature = u.signature,
                        gender = u.gender,
                        birthday = u.birthday,
                        country = u.country,
                        province = u.province,
                        region = u.region,
                        avatar_path = u.avatar_path,
                        qq_bound = !string.IsNullOrWhiteSpace(u.qq_open_id),
                        qq_nickname = u.qq_nickname,
                        qq_avatar_url = u.qq_avatar_url,
                        qq_bound_at = u.qq_bound_at,
                        is_online = true,
                        last_login_at = u.last_login_at,
                        created_at = u.created_at,
                        updated_at = u.updated_at
                    })
                    .ToListAsync();

                return Ok(new ApiResponse<List<UserResponseDto>>
                {
                    Success = true,
                    Data = onlineUsers
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取在线用户列表失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<UserResponseDto>>
                {
                    Success = false,
                    Message = "获取在线用户失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("users")]
        public async Task<ActionResult<ApiResponse<object>>> GetAllUsers([FromQuery] int page = 1, [FromQuery] int page_size = 20)
        {
            try
            {
                // 检查是否是管理员
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                if (user == null || user.username != "admin")
                {
                    return Unauthorized(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "无权访问"
                    });
                }

                var query = _context.users.AsQueryable();
                var totalCount = await query.CountAsync();
                var onlineCutoff = OnlineStatusPolicy.GetOnlineCutoffUtc(DateTime.UtcNow);

                var users = await query
                    .OrderBy(u => u.id)
                    .Skip((page - 1) * page_size)
                    .Take(page_size)
                    .Select(u => new UserResponseDto
                    {
                        id = u.id,
                        username = u.username,
                        email = u.email,
                        display_name = u.display_name,
                        signature = u.signature,
                        gender = u.gender,
                        birthday = u.birthday,
                        country = u.country,
                        province = u.province,
                        region = u.region,
                        avatar_path = u.avatar_path,
                        qq_bound = !string.IsNullOrWhiteSpace(u.qq_open_id),
                        qq_nickname = u.qq_nickname,
                        qq_avatar_url = u.qq_avatar_url,
                        qq_bound_at = u.qq_bound_at,
                        is_online = u.is_online
                            && u.last_heartbeat_at.HasValue
                            && u.last_heartbeat_at.Value >= onlineCutoff,
                        last_login_at = u.last_login_at,
                        created_at = u.created_at,
                        updated_at = u.updated_at
                    })
                    .ToListAsync();

                var totalPages = (int)Math.Ceiling((double)totalCount / page_size);

                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Data = new
                    {
                        users = users,
                        total_count = totalCount,
                        page = page,
                        page_size = page_size,
                        total_pages = totalPages
                    }
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = "获取用户列表失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-user-password")]
        public async Task<ActionResult<ApiResponse>> ChangeUserPassword([FromBody] AdminChangePasswordDto dto)
        {
            try
            {
                // 检查是否是管理员
                var adminUserId = GetUserId();
                var adminUser = await _userService.GetUserByIdAsync(adminUserId);
                if (adminUser == null || adminUser.username != "admin")
                {
                    _logger.LogWarning("非管理员尝试修改用户密码: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", adminUserId, dto.user_id);
                    return Unauthorized(new ApiResponse
                    {
                        Success = false,
                        Message = "无权访问"
                    });
                }

                // 管理员可以直接修改其他用户的密码，不需要原密码
                var targetUser = await _context.users.FindAsync(dto.user_id);
                if (targetUser == null)
                {
                    _logger.LogWarning("修改密码失败，用户不存在: TargetUserId={TargetUserId}", dto.user_id);
                    return BadRequest(new ApiResponse
                    {
                        Success = false,
                        Message = "用户不存在"
                    });
                }

                // 不允许修改admin用户的密码
                if (targetUser.username == "admin")
                {
                    _logger.LogWarning("尝试修改管理员密码: AdminUserId={AdminUserId}", adminUserId);
                    return BadRequest(new ApiResponse
                    {
                        Success = false,
                        Message = "不允许修改管理员密码"
                    });
                }

                _logger.LogInformation("管理员修改用户密码: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}, TargetUsername={TargetUsername}", 
                    adminUserId, dto.user_id, targetUser.username);

                targetUser.password_hash = BCrypt.Net.BCrypt.HashPassword(dto.new_password);
                targetUser.updated_at = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                _logger.LogInformation("管理员修改用户密码成功: TargetUserId={TargetUserId}", dto.user_id);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "密码修改成功"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "管理员修改用户密码失败: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", 
                    GetUserId(), dto.user_id);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "密码修改失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            throw new UnauthorizedAccessException("用户未登录");
        }
    }
}
