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
        public async Task<ActionResult<ApiResponse<object>>> Register(UserRegistrationDto registrationDto)
        {
            try
            {
                _logger.LogInformation("用户注册请求: {Username}, {Email}", registrationDto.username, registrationDto.email);
                await _userService.RegisterAsync(registrationDto);
                var token = await _userService.LoginAsync(new UserLoginDto
                {
                    username = registrationDto.username,
                    password = registrationDto.password
                });
                var userId = _jwtService.GetUserIdFromToken(token);

                if (userId == null)
                {
                    _logger.LogWarning("注册成功但无法从Token中获取用户ID: Username={Username}", registrationDto.username);
                    return BadRequest(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "注册后自动登录失败",
                        Errors = new List<string> { "无法从Token中获取用户ID" }
                    });
                }

                var user = await _userService.GetUserByIdAsync(userId.Value);
                _logger.LogInformation("用户注册并自动登录成功: UserId={UserId}, Username={Username}", user.id, user.username);
                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Message = "注册成功",
                    Data = new
                    {
                        Token = token,
                        User = user
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用户注册失败: Username={Username}, Email={Email}", registrationDto.username, registrationDto.email);
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "注册失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("registration-email-code")]
        public async Task<ActionResult<ApiResponse>> RequestRegistrationEmailCode(
            RegistrationEmailVerificationCodeRequestDto requestDto)
        {
            try
            {
                await _userService.RequestRegistrationEmailVerificationCodeAsync(requestDto);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "验证码已发送，5分钟内有效"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送注册邮箱验证码失败: Username={Username}, Email={Email}", requestDto.username, requestDto.email);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送验证码失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-email-code")]
        [Authorize]
        public async Task<ActionResult<ApiResponse>> RequestEmailChangeCode(
            ChangeEmailVerificationCodeRequestDto requestDto)
        {
            try
            {
                var userId = GetUserId();
                await _userService.RequestEmailChangeVerificationCodeAsync(userId, requestDto);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "验证码已发送，5分钟内有效"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送修改邮箱验证码失败: UserId={UserId}, Email={Email}", GetUserId(), requestDto.email);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送验证码失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-email")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> ChangeEmail(ChangeEmailDto changeEmailDto)
        {
            try
            {
                var userId = GetUserId();
                var user = await _userService.ChangeEmailAsync(userId, changeEmailDto);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "邮箱修改成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "修改邮箱失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "邮箱修改失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("login")]
        public async Task<ActionResult<ApiResponse<object>>> Login(UserLoginDto loginDto)
        {
            try
            {
                _logger.LogInformation("用户登录请求: {LoginIdentity}", loginDto.username);
                var token = await _userService.LoginAsync(loginDto);
                var userId = _jwtService.GetUserIdFromToken(token);
                
                if (userId == null)
                {
                    _logger.LogWarning("登录失败，无法从Token中获取用户ID: {LoginIdentity}", loginDto.username);
                    return BadRequest(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "登录失败",
                        Errors = new List<string> { "无法从Token中获取用户ID" }
                    });
                }
                
                var user = await _userService.GetUserByIdAsync(userId.Value);
                _logger.LogInformation("用户登录成功: UserId={UserId}, LoginIdentity={LoginIdentity}", userId.Value, loginDto.username);

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
                _logger.LogError(ex, "用户登录失败: LoginIdentity={LoginIdentity}", loginDto.username);
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
                    Message = ApiErrorMessage.ForClient(ex, "密码修改失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-password-code")]
        [Authorize]
        public async Task<ActionResult<ApiResponse>> RequestPasswordChangeCode()
        {
            try
            {
                var userId = GetUserId();
                await _userService.RequestPasswordChangeEmailVerificationCodeAsync(userId);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "验证码已发送，5分钟内有效"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送修改密码验证码失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送验证码失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("forgot-password")]
        public async Task<ActionResult<ApiResponse>> ForgotPassword(ForgotPasswordDto forgotPasswordDto)
        {
            try
            {
                await _userService.ForgotPasswordAsync(forgotPasswordDto);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "如果邮箱存在，重置邮件已发送，请检查邮箱"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送密码重置邮件失败: Email={Email}", forgotPasswordDto.email);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送重置邮件失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("reset-password")]
        public async Task<ActionResult<ApiResponse>> ResetPassword(ResetPasswordDto resetPasswordDto)
        {
            try
            {
                await _userService.ResetPasswordAsync(resetPasswordDto);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "密码重置成功，请重新登录"
                });
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "密码重置失败");
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "密码重置失败"),
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
                    Message = ApiErrorMessage.ForClient(ex, "更新失败"),
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
}
