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
    public class AdminController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly VideoCallDbContext _context;
        private readonly ILogger<AdminController> _logger;
        private readonly IContentSecurityService _contentSecurity;
        private readonly IConfiguration _configuration;

        public AdminController(
            IUserService userService,
            VideoCallDbContext context,
            ILogger<AdminController> logger,
            IContentSecurityService contentSecurity,
            IConfiguration configuration)
        {
            _userService = userService;
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
            _configuration = configuration;
        }

        private string NormalizeUsername(string? username)
        {
            var normalized = _contentSecurity.NormalizeRequiredText(
                username,
                "用户名",
                50,
                filterSensitiveWords: false,
                rejectSensitiveWords: true);

            if (normalized.Length < 3)
                throw new ArgumentException("用户名至少3位");

            if (!normalized.All(IsAllowedUsernameCharacter))
                throw new ArgumentException("用户名只能包含英文字母、数字、下划线或短横线");

            return normalized;
        }

        private string NormalizeEmail(string? email)
        {
            var normalized = _contentSecurity
                .NormalizeRequiredText(email, "邮箱", 100, filterSensitiveWords: false)
                .ToLowerInvariant();

            if (!new EmailAddressAttribute().IsValid(normalized))
                throw new ArgumentException("邮箱格式不正确");

            return normalized;
        }

        private string? NormalizeDisplayName(string? displayName)
        {
            return _contentSecurity.NormalizeOptionalText(
                displayName,
                "昵称",
                50,
                rejectSensitiveWords: true);
        }

        private static bool IsAllowedUsernameCharacter(char value)
        {
            return (value >= 'a' && value <= 'z') ||
                   (value >= 'A' && value <= 'Z') ||
                   (value >= '0' && value <= '9') ||
                   value == '_' ||
                   value == '-';
        }

        private async Task EnsureUsernameOrEmailAvailableAsync(string username, string email, int? excludedUserId = null)
        {
            var normalizedUsername = username.ToLowerInvariant();
            var normalizedEmail = email.ToLowerInvariant();
            var exists = await _context.users.AnyAsync(user =>
                (!excludedUserId.HasValue || user.id != excludedUserId.Value) &&
                (user.username.ToLower() == normalizedUsername || user.email.ToLower() == normalizedEmail));

            if (exists)
                throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入");
        }

        private static bool IsUniqueUserConflict(DbUpdateException exception)
        {
            var message = exception.InnerException?.Message ?? exception.Message;
            return message.Contains("users_username", StringComparison.OrdinalIgnoreCase) ||
                   message.Contains("users_email", StringComparison.OrdinalIgnoreCase) ||
                   message.Contains("IX_users_username", StringComparison.OrdinalIgnoreCase) ||
                   message.Contains("IX_users_email", StringComparison.OrdinalIgnoreCase) ||
                   message.Contains("duplicate key", StringComparison.OrdinalIgnoreCase);
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

        [HttpGet("online-users")]
        public async Task<ActionResult<ApiResponse<List<UserResponseDto>>>> GetOnlineUsers()
        {
            try
            {
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                if (!AdminIdentityPolicy.IsAdminEmail(user.email, _configuration))
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
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                if (!AdminIdentityPolicy.IsAdminEmail(user.email, _configuration))
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

        [HttpPost("users")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> CreateUser([FromBody] AdminCreateUserDto dto)
        {
            try
            {
                var adminUserId = GetUserId();
                var adminUser = await _userService.GetUserByIdAsync(adminUserId);
                if (!AdminIdentityPolicy.IsAdminEmail(adminUser.email, _configuration))
                {
                    _logger.LogWarning("非管理员尝试创建用户: AdminUserId={AdminUserId}", adminUserId);
                    return Unauthorized(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "无权访问"
                    });
                }

                var username = NormalizeUsername(dto.username);
                var email = NormalizeEmail(dto.email);
                if (string.IsNullOrWhiteSpace(dto.password) || dto.password.Length < 6)
                    throw new ArgumentException("密码至少6位");

                await EnsureUsernameOrEmailAvailableAsync(username, email);

                var now = DateTime.UtcNow;
                var user = new User
                {
                    username = username,
                    email = email,
                    display_name = NormalizeDisplayName(dto.display_name),
                    password_hash = BCrypt.Net.BCrypt.HashPassword(dto.password),
                    created_at = now,
                    updated_at = now,
                    is_online = false
                };

                _context.users.Add(user);
                try
                {
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateException ex) when (IsUniqueUserConflict(ex))
                {
                    throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入", ex);
                }

                _logger.LogInformation("管理员创建用户成功: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", adminUserId, user.id);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "用户已创建",
                    Data = MapToUserResponse(user)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "管理员创建用户失败: AdminUserId={AdminUserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "创建用户失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPut("users/{userId:int}")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> UpdateUser(int userId, [FromBody] AdminUpdateUserDto dto)
        {
            try
            {
                var adminUserId = GetUserId();
                var adminUser = await _userService.GetUserByIdAsync(adminUserId);
                if (!AdminIdentityPolicy.IsAdminEmail(adminUser.email, _configuration))
                {
                    _logger.LogWarning("非管理员尝试修改用户: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", adminUserId, userId);
                    return Unauthorized(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "无权访问"
                    });
                }

                var targetUser = await _context.users.FindAsync(userId);
                if (targetUser == null)
                    throw new ArgumentException("用户不存在");

                var username = NormalizeUsername(dto.username);
                var email = NormalizeEmail(dto.email);
                if (AdminIdentityPolicy.IsAdminEmail(targetUser.email, _configuration) &&
                    !AdminIdentityPolicy.IsAdminEmail(email, _configuration))
                {
                    throw new InvalidOperationException("管理员邮箱不允许修改");
                }

                await EnsureUsernameOrEmailAvailableAsync(username, email, userId);

                targetUser.username = username;
                targetUser.email = email;
                targetUser.display_name = NormalizeDisplayName(dto.display_name);
                targetUser.updated_at = DateTime.UtcNow;

                try
                {
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateException ex) when (IsUniqueUserConflict(ex))
                {
                    throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入", ex);
                }

                _logger.LogInformation("管理员修改用户成功: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", adminUserId, userId);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "用户已更新",
                    Data = MapToUserResponse(targetUser)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "管理员修改用户失败: AdminUserId={AdminUserId}, TargetUserId={TargetUserId}", GetUserId(), userId);
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "修改用户失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-user-password")]
        public async Task<ActionResult<ApiResponse>> ChangeUserPassword([FromBody] AdminChangePasswordDto dto)
        {
            try
            {
                var adminUserId = GetUserId();
                var adminUser = await _userService.GetUserByIdAsync(adminUserId);
                if (!AdminIdentityPolicy.IsAdminEmail(adminUser.email, _configuration))
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

                if (AdminIdentityPolicy.IsAdminEmail(targetUser.email, _configuration))
                {
                    _logger.LogWarning("尝试修改管理员密码: AdminUserId={AdminUserId}", adminUserId);
                    return BadRequest(new ApiResponse
                    {
                        Success = false,
                        Message = "管理员账号不允许在这里修改密码"
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
                    Message = ApiErrorMessage.ForClient(ex, "密码修改失败"),
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
