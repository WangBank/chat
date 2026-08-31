using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using VideoCallAPI.Data;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;
using BCrypt.Net;

namespace VideoCallAPI.Services
{
    public class UserService : IUserService
    {
        private readonly VideoCallDbContext _context;
        private readonly IJwtService _jwtService;
        private readonly ILogger<UserService> _logger;
        private readonly IContentSecurityService _contentSecurity;
        private readonly IConfiguration _configuration;
        private readonly IEmailService _emailService;
        private readonly IEmailCodeCaptchaService _emailCodeCaptchaService;

        public UserService(
            VideoCallDbContext context,
            IJwtService jwtService,
            ILogger<UserService> logger,
            IContentSecurityService contentSecurity,
            IConfiguration configuration,
            IEmailService emailService,
            IEmailCodeCaptchaService emailCodeCaptchaService)
        {
            _context = context;
            _jwtService = jwtService;
            _logger = logger;
            _contentSecurity = contentSecurity;
            _configuration = configuration;
            _emailService = emailService;
            _emailCodeCaptchaService = emailCodeCaptchaService;
        }

        private string NormalizeEmail(string? value)
        {
            var email = _contentSecurity
                .NormalizeRequiredText(value, "邮箱", 100, filterSensitiveWords: false)
                .ToLowerInvariant();

            if (!new EmailAddressAttribute().IsValid(email))
                throw new ArgumentException("邮箱格式不正确");

            return email;
        }

        private static void EnsureValidUsername(string username)
        {
            if (username.Length < 3)
                throw new ArgumentException("用户名至少3位");

            if (!username.All(IsAllowedUsernameCharacter))
                throw new ArgumentException("用户名只能包含英文字母、数字、下划线或短横线");
        }

        private static bool IsAllowedUsernameCharacter(char value)
        {
            return (value >= 'a' && value <= 'z') ||
                   (value >= 'A' && value <= 'Z') ||
                   (value >= '0' && value <= '9') ||
                   value == '_' ||
                   value == '-';
        }

        private Task<bool> IsUsernameOrEmailUsedAsync(string username, string email, int? excludedUserId = null)
        {
            var normalizedUsername = username.ToLowerInvariant();
            var normalizedEmail = email.ToLowerInvariant();

            return _context.users.AnyAsync(user =>
                (!excludedUserId.HasValue || user.id != excludedUserId.Value) &&
                (user.username.ToLower() == normalizedUsername || user.email.ToLower() == normalizedEmail));
        }

        private Task<bool> IsEmailUsedAsync(string email, int? excludedUserId = null)
        {
            var normalizedEmail = email.ToLowerInvariant();
            return _context.users.AnyAsync(user =>
                (!excludedUserId.HasValue || user.id != excludedUserId.Value) &&
                user.email.ToLower() == normalizedEmail);
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

        public async Task RequestRegistrationEmailVerificationCodeAsync(
            RegistrationEmailVerificationCodeRequestDto requestDto,
            string clientFingerprint)
        {
            var username = _contentSecurity.NormalizeRequiredText(
                requestDto.username,
                "用户名",
                50,
                filterSensitiveWords: false,
                rejectSensitiveWords: true);
            EnsureValidUsername(username);
            var email = NormalizeEmail(requestDto.email);

            if (await IsUsernameOrEmailUsedAsync(username, email))
                throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入");

            await EnsureEmailCodeSendRateLimitAsync(email);
            await _emailCodeCaptchaService.VerifyAsync(
                requestDto,
                EmailVerificationPurpose.Registration,
                email,
                username,
                null,
                clientFingerprint);

            await CreateAndSendEmailVerificationCodeAsync(
                email,
                username,
                EmailVerificationPurpose.Registration);
        }

        public async Task RequestEmailChangeVerificationCodeAsync(
            int userId,
            ChangeEmailVerificationCodeRequestDto requestDto,
            string clientFingerprint)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            var email = NormalizeEmail(requestDto.email);
            if (string.Equals(user.email, email, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("新邮箱与当前邮箱一致");
            if (await IsEmailUsedAsync(email, userId))
                throw new InvalidOperationException("该邮箱已被使用，请更换后重试");

            await EnsureEmailCodeSendRateLimitAsync(email);
            await _emailCodeCaptchaService.VerifyAsync(
                requestDto,
                EmailVerificationPurpose.ChangeEmail,
                email,
                null,
                userId,
                clientFingerprint);

            await CreateAndSendEmailVerificationCodeAsync(
                email,
                GetDisplayName(user),
                EmailVerificationPurpose.ChangeEmail);
        }

        public async Task<UserResponseDto> ChangeEmailAsync(int userId, ChangeEmailDto changeEmailDto)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            var email = NormalizeEmail(changeEmailDto.email);
            if (string.Equals(user.email, email, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("新邮箱与当前邮箱一致");
            if (await IsEmailUsedAsync(email, userId))
                throw new InvalidOperationException("该邮箱已被使用，请更换后重试");

            var verificationCode = await GetValidEmailVerificationCodeAsync(
                email,
                changeEmailDto.verification_code,
                EmailVerificationPurpose.ChangeEmail);

            user.email = email;
            user.email_verified_at = DateTime.UtcNow;
            user.updated_at = DateTime.UtcNow;
            verificationCode.is_used = true;
            verificationCode.used_at = DateTime.UtcNow;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (IsUniqueUserConflict(ex))
            {
                _logger.LogWarning(ex, "修改邮箱失败，唯一索引冲突: UserId={UserId}, Email={Email}", userId, email);
                throw new InvalidOperationException("该邮箱已被使用，请更换后重试", ex);
            }

            _logger.LogInformation("用户邮箱修改成功: UserId={UserId}", userId);
            return MapToUserResponse(user);
        }

        public async Task<UserResponseDto> RegisterAsync(UserRegistrationDto registrationDto)
        {
            var username = _contentSecurity.NormalizeRequiredText(
                registrationDto.username,
                "用户名",
                50,
                filterSensitiveWords: false,
                rejectSensitiveWords: true);
            EnsureValidUsername(username);
            var email = NormalizeEmail(registrationDto.email);

            if (await IsUsernameOrEmailUsedAsync(username, email))
            {
                _logger.LogWarning("注册失败，用户名或邮箱已存在: {Username}, {Email}", username, email);
                throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入");
            }

            var verificationCode = await GetValidEmailVerificationCodeAsync(
                email,
                registrationDto.verification_code,
                EmailVerificationPurpose.Registration);

            var user = new User
            {
                username = username,
                email = email,
                email_verified_at = DateTime.UtcNow,
                password_hash = BCrypt.Net.BCrypt.HashPassword(registrationDto.password),
                created_at = DateTime.UtcNow
            };

            _context.users.Add(user);
            verificationCode.is_used = true;
            verificationCode.used_at = DateTime.UtcNow;
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (IsUniqueUserConflict(ex))
            {
                _logger.LogWarning(ex, "注册失败，唯一索引冲突: {Username}, {Email}", username, email);
                throw new InvalidOperationException("当前用户名或者邮箱被使用请重新输入", ex);
            }

            _logger.LogInformation("用户注册成功: UserId={UserId}, Username={Username}", user.id, user.username);
            return MapToUserResponse(user);
        }

        private async Task CreateAndSendEmailVerificationCodeAsync(
            string email,
            string displayName,
            EmailVerificationPurpose purpose)
        {
            _emailService.EnsureConfigured();

            var now = DateTime.UtcNow;
            var activeCodes = await _context.EmailVerificationCodes
                .Where(item => item.email == email && item.purpose == purpose && !item.is_used && item.expires_at > now)
                .ToListAsync();
            foreach (var activeCode in activeCodes)
            {
                activeCode.is_used = true;
                activeCode.used_at = now;
            }

            var code = GenerateEmailVerificationCode();
            _context.EmailVerificationCodes.Add(new EmailVerificationCode
            {
                email = email,
                purpose = purpose,
                code_hash = BCrypt.Net.BCrypt.HashPassword(code),
                expires_at = now.AddMinutes(5),
                created_at = now
            });
            await _context.SaveChangesAsync();

            await _emailService.SendEmailVerificationCodeAsync(email, displayName, code, purpose);
            _logger.LogInformation("邮箱验证码已发送: Email={Email}, Purpose={Purpose}", email, purpose);
        }

        private async Task EnsureEmailCodeSendRateLimitAsync(string email)
        {
            var now = DateTime.UtcNow;
            var oneMinuteAgo = now.AddMinutes(-1);
            var dailyLimitStart = now.AddDays(-1);

            var sentInLastMinute = await _context.EmailVerificationCodes
                .AnyAsync(item => item.email == email && item.created_at > oneMinuteAgo);
            if (sentInLastMinute)
                throw new InvalidOperationException("操作过于频繁，请60秒后再试");

            var sentToday = await _context.EmailVerificationCodes
                .CountAsync(item => item.email == email && item.created_at > dailyLimitStart);
            if (sentToday >= 10)
                throw new InvalidOperationException("该邮箱今日验证码发送次数已达上限，请24小时后再试");
        }

        private async Task<EmailVerificationCode> GetValidEmailVerificationCodeAsync(
            string email,
            string? suppliedCode,
            EmailVerificationPurpose purpose)
        {
            var code = NormalizeEmailVerificationCode(suppliedCode);
            var now = DateTime.UtcNow;
            var verificationCode = await _context.EmailVerificationCodes
                .Where(item => item.email == email && item.purpose == purpose && !item.is_used && item.expires_at > now)
                .OrderByDescending(item => item.created_at)
                .FirstOrDefaultAsync();

            if (verificationCode == null)
                throw new InvalidOperationException("邮箱验证码无效或已过期，请重新获取");
            if (!BCrypt.Net.BCrypt.Verify(code, verificationCode.code_hash))
                throw new InvalidOperationException("邮箱验证码不正确");

            return verificationCode;
        }

        private string NormalizeEmailVerificationCode(string? value)
        {
            var code = _contentSecurity.NormalizeRequiredText(
                value,
                "邮箱验证码",
                6,
                filterSensitiveWords: false);
            if (code.Length != 6 || !code.All(character => character >= '0' && character <= '9'))
                throw new ArgumentException("邮箱验证码必须为6位数字");

            return code;
        }

        private static string GenerateEmailVerificationCode()
        {
            return RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        }

        public async Task<string> LoginAsync(UserLoginDto loginDto)
        {
            var loginIdentity = _contentSecurity
                .NormalizeRequiredText(loginDto.username, "用户名或邮箱", 100, filterSensitiveWords: false)
                .ToLowerInvariant();
            var user = await _context.users.FirstOrDefaultAsync(u =>
                u.username.ToLower() == loginIdentity ||
                u.email.ToLower() == loginIdentity);
            if (user == null || !BCrypt.Net.BCrypt.Verify(loginDto.password, user.password_hash))
            {
                _logger.LogWarning("登录失败，用户名/邮箱或密码错误: {LoginIdentity}", loginIdentity);
                throw new UnauthorizedAccessException("用户名/邮箱或密码错误");
            }

            var now = DateTime.UtcNow;

            // 更新最后登录时间，并写入首个心跳
            user.last_login_at = now;
            user.last_heartbeat_at = now;
            user.is_online = true;
            await _context.SaveChangesAsync();

            _logger.LogInformation("用户登录成功: UserId={UserId}, LoginIdentity={LoginIdentity}", user.id, loginIdentity);
            return _jwtService.GenerateToken(user);
        }

        public async Task<UserResponseDto> GetUserByIdAsync(int userId)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            return MapToUserResponse(user);
        }

        public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto changePasswordDto)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            if (string.IsNullOrWhiteSpace(changePasswordDto.new_password) || changePasswordDto.new_password.Length < 6)
                throw new ArgumentException("新密码至少6位");

            EmailVerificationCode? verificationCode = null;
            if (!string.IsNullOrWhiteSpace(changePasswordDto.old_password))
            {
                if (!BCrypt.Net.BCrypt.Verify(changePasswordDto.old_password, user.password_hash))
                    throw new UnauthorizedAccessException("原密码错误");
            }
            else
            {
                if (!user.email_verified_at.HasValue)
                    throw new InvalidOperationException("当前邮箱未认证，请先在个人资料中修改并验证邮箱，或使用旧密码修改");

                verificationCode = await GetValidEmailVerificationCodeAsync(
                    user.email,
                    changePasswordDto.verification_code,
                    EmailVerificationPurpose.ChangePassword);
                verificationCode.is_used = true;
                verificationCode.used_at = DateTime.UtcNow;
            }

            user.password_hash = BCrypt.Net.BCrypt.HashPassword(changePasswordDto.new_password);
            await _context.SaveChangesAsync();

            return true;
        }

        public async Task RequestPasswordChangeEmailVerificationCodeAsync(
            int userId,
            EmailCodeCaptchaVerificationDto captchaDto,
            string clientFingerprint)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");
            if (!user.email_verified_at.HasValue)
                throw new InvalidOperationException("当前邮箱未认证，请先在个人资料中修改并验证邮箱");

            await EnsureEmailCodeSendRateLimitAsync(user.email);
            await _emailCodeCaptchaService.VerifyAsync(
                captchaDto,
                EmailVerificationPurpose.ChangePassword,
                null,
                null,
                userId,
                clientFingerprint);

            await CreateAndSendEmailVerificationCodeAsync(
                user.email,
                GetDisplayName(user),
                EmailVerificationPurpose.ChangePassword);
        }

        public async Task ForgotPasswordAsync(ForgotPasswordDto forgotPasswordDto)
        {
            var email = NormalizeEmail(forgotPasswordDto.email);
            var user = await _context.users.FirstOrDefaultAsync(u => u.email.ToLower() == email);

            if (user == null)
            {
                _logger.LogInformation("密码重置请求未匹配到用户邮箱: {Email}", email);
                return;
            }

            _emailService.EnsureConfigured();

            var now = DateTime.UtcNow;
            var token = GeneratePasswordResetToken();
            var tokenHash = HashPasswordResetToken(token);
            var tokenMinutes = Math.Clamp(_configuration.GetValue<int?>("Email:PasswordResetTokenMinutes") ?? 30, 5, 1440);

            var activeTokens = await _context.PasswordResetTokens
                .Where(resetToken => resetToken.user_id == user.id && !resetToken.is_used && resetToken.expires_at > now)
                .ToListAsync();
            foreach (var activeToken in activeTokens)
            {
                activeToken.is_used = true;
                activeToken.used_at = now;
            }

            _context.PasswordResetTokens.Add(new PasswordResetToken
            {
                user_id = user.id,
                token_hash = tokenHash,
                expires_at = now.AddMinutes(tokenMinutes),
                created_at = now
            });

            await _context.SaveChangesAsync();

            var resetUrl = BuildPasswordResetUrl(token);
            await _emailService.SendPasswordResetEmailAsync(user.email, GetDisplayName(user), resetUrl);
            _logger.LogInformation("密码重置邮件已发送: UserId={UserId}, Email={Email}", user.id, user.email);
        }

        public async Task ResetPasswordAsync(ResetPasswordDto resetPasswordDto)
        {
            var token = _contentSecurity.NormalizeRequiredText(
                resetPasswordDto.token,
                "重置令牌",
                500,
                filterSensitiveWords: false);

            if (string.IsNullOrWhiteSpace(resetPasswordDto.new_password) || resetPasswordDto.new_password.Length < 6)
                throw new ArgumentException("密码至少6位");

            var tokenHash = HashPasswordResetToken(token);
            var now = DateTime.UtcNow;
            var resetToken = await _context.PasswordResetTokens
                .Include(item => item.user)
                .FirstOrDefaultAsync(item => item.token_hash == tokenHash && !item.is_used);

            if (resetToken == null || resetToken.expires_at <= now)
                throw new InvalidOperationException("重置链接无效或已过期");

            resetToken.is_used = true;
            resetToken.used_at = now;
            resetToken.user.password_hash = BCrypt.Net.BCrypt.HashPassword(resetPasswordDto.new_password);
            resetToken.user.updated_at = now;

            var remainingTokens = await _context.PasswordResetTokens
                .Where(item => item.user_id == resetToken.user_id && item.id != resetToken.id && !item.is_used)
                .ToListAsync();
            foreach (var remainingToken in remainingTokens)
            {
                remainingToken.is_used = true;
                remainingToken.used_at = now;
            }

            await _context.SaveChangesAsync();
            _logger.LogInformation("密码重置成功: UserId={UserId}", resetToken.user_id);
        }

        public async Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateProfileDto updateProfileDto)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            if (updateProfileDto.display_name != null)
            {
                var displayName = _contentSecurity.NormalizeOptionalText(
                    updateProfileDto.display_name,
                    "昵称",
                    50,
                    rejectSensitiveWords: true);
                if (displayName != null)
                    user.display_name = displayName;
            }
            
            if (updateProfileDto.avatar_path != null)
            {
                var avatarPath = _contentSecurity.NormalizeStoredFilePath(updateProfileDto.avatar_path, "头像路径", "/avatar/");
                if (avatarPath != null)
                    user.avatar_path = avatarPath;
            }

            if (updateProfileDto.signature != null)
                user.signature = _contentSecurity.NormalizeOptionalText(
                    updateProfileDto.signature,
                    "个性签名",
                    100,
                    rejectSensitiveWords: true);

            if (updateProfileDto.gender != null)
                user.gender = _contentSecurity.NormalizeOptionalText(updateProfileDto.gender, "性别", 10);

            if (updateProfileDto.birthday != null)
                user.birthday = _contentSecurity.NormalizeOptionalText(updateProfileDto.birthday, "生日", 10, filterSensitiveWords: false);

            if (updateProfileDto.country != null)
                user.country = _contentSecurity.NormalizeOptionalText(
                    updateProfileDto.country,
                    "国家",
                    50,
                    rejectSensitiveWords: true);

            if (updateProfileDto.province != null)
                user.province = _contentSecurity.NormalizeOptionalText(
                    updateProfileDto.province,
                    "省份",
                    50,
                    rejectSensitiveWords: true);

            if (updateProfileDto.region != null)
                user.region = _contentSecurity.NormalizeOptionalText(
                    updateProfileDto.region,
                    "地区",
                    50,
                    rejectSensitiveWords: true);

            user.updated_at = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        public async Task<UserResponseDto> UploadAvatarAsync(int userId, IFormFile avatar)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            // 创建头像存储目录 - 存放到api/avatar文件夹
            var avatarDir = Path.Combine(Directory.GetCurrentDirectory(), "avatar");
            if (!Directory.Exists(avatarDir))
            {
                Directory.CreateDirectory(avatarDir);
            }

            // 生成唯一文件名
            var fileName = $"{userId}_{DateTime.UtcNow:yyyyMMddHHmmss}{Path.GetExtension(avatar.FileName)}";
            var filePath = Path.Combine(avatarDir, fileName);

            // 保存文件
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await avatar.CopyToAsync(stream);
            }

            // 更新用户头像路径
            user.avatar_path = $"/avatar/{fileName}";
            user.updated_at = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                id = user.id,
                username = user.username,
                email = user.email,
                email_verified = user.email_verified_at.HasValue,
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

        private string BuildPasswordResetUrl(string token)
        {
            var baseUrl = _configuration["Email:PasswordResetBaseUrl"];
            if (string.IsNullOrWhiteSpace(baseUrl))
                baseUrl = "http://localhost:5173/reset-password";

            var separator = baseUrl.Contains('?') ? "&" : "?";
            return $"{baseUrl}{separator}token={Uri.EscapeDataString(token)}";
        }

        private static string GeneratePasswordResetToken()
        {
            var bytes = RandomNumberGenerator.GetBytes(32);
            return Convert.ToBase64String(bytes)
                .TrimEnd('=')
                .Replace('+', '-')
                .Replace('/', '_');
        }

        private static string HashPasswordResetToken(string token)
        {
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(token));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private static string GetDisplayName(User user)
        {
            return string.IsNullOrWhiteSpace(user.display_name) ? user.username : user.display_name;
        }

        public async Task UpdateHeartbeatAsync(int userId)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            user.is_online = true;
            user.last_heartbeat_at = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        public async Task MarkOfflineAsync(int userId)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                return;

            user.is_online = false;
            await _context.SaveChangesAsync();
        }

        public async Task<UserSearchResultDto> SearchUsersAsync(int currentUserId, SearchUsersDto searchDto)
        {
            var page = Math.Max(1, searchDto.page);
            var pageSize = Math.Clamp(searchDto.page_size, 1, 50);
            var query = _context.users.AsQueryable();

            // 排除当前用户
            query = query.Where(u => u.id != currentUserId);
            var adminEmails = AdminIdentityPolicy.GetAdminEmails(_configuration);
            if (adminEmails.Count > 0)
                query = query.Where(u => !adminEmails.Contains(u.email.ToLower()));

            // 排除已经是联系人的用户
            var existingContactIds = await _context.Contacts
                .Where(c => c.user_id == currentUserId)
                .Select(c => c.contact_user_id)
                .ToListAsync();
            
            query = query.Where(u => !existingContactIds.Contains(u.id));

            // 搜索条件
            if (!string.IsNullOrWhiteSpace(searchDto.query))
            {
                var searchTerm = _contentSecurity
                    .NormalizeRequiredText(searchDto.query, "搜索内容", 100, filterSensitiveWords: false)
                    .ToLower();
                query = query.Where(u => 
                    u.username.ToLower().Contains(searchTerm) ||
                    (u.display_name != null && u.display_name.ToLower().Contains(searchTerm)) ||
                    (u.email != null && u.email.ToLower().Contains(searchTerm)));
            }

            // 获取总数
            var totalCount = await query.CountAsync();

            // 分页
            var users = await query
                .OrderBy(u => u.username)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var totalPages = (int)Math.Ceiling((double)totalCount / pageSize);

            return new UserSearchResultDto
            {
                users = users.Select(MapToUserResponse).ToList(),
                total_count = totalCount,
                page = page,
                page_size = pageSize,
                total_pages = totalPages
            };
        }
    }

    public class ContactService : IContactService
    {
        private readonly VideoCallDbContext _context;
        private readonly ILogger<ContactService> _logger;
        private readonly IContentSecurityService _contentSecurity;
        private readonly IConfiguration _configuration;

        public ContactService(
            VideoCallDbContext context,
            ILogger<ContactService> logger,
            IContentSecurityService contentSecurity,
            IConfiguration configuration)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
            _configuration = configuration;
        }

        public async Task<FriendRequestResponseDto> CreateFriendRequestAsync(int userId, CreateFriendRequestDto requestDto)
        {
            var targetUsername = _contentSecurity.NormalizeRequiredText(
                requestDto.username,
                "用户名",
                50,
                filterSensitiveWords: false,
                rejectSensitiveWords: true);

            var requester = await _context.users.FindAsync(userId);
            if (requester == null)
                throw new ArgumentException("用户不存在");

            var receiver = await _context.users.FirstOrDefaultAsync(u => u.username == targetUsername);
            if (receiver == null)
                throw new ArgumentException("用户不存在");

            if (AdminIdentityPolicy.IsAdminEmail(receiver.email, _configuration))
                throw new InvalidOperationException("管理员账号不支持添加为好友");

            if (receiver.id == userId)
                throw new InvalidOperationException("不能添加自己为好友");

            if (await _context.Contacts.AnyAsync(c => c.user_id == userId && c.contact_user_id == receiver.id))
                throw new InvalidOperationException("你们已经是好友");

            var reversePendingRequest = await _context.FriendRequests
                .Include(r => r.requester)
                .Include(r => r.receiver)
                .FirstOrDefaultAsync(r =>
                    r.requester_id == receiver.id &&
                    r.receiver_id == userId &&
                    r.status == FriendRequestStatus.Pending);

            if (reversePendingRequest != null)
                return MapToFriendRequestResponse(reversePendingRequest, userId);

            var now = DateTime.UtcNow;
            var note = _contentSecurity.NormalizeOptionalText(
                requestDto.note,
                "验证消息",
                100,
                rejectSensitiveWords: true)
                ?? BuildDefaultFriendRequestNote(requester);
            var source = _contentSecurity.NormalizeOptionalText(
                requestDto.source,
                "好友来源",
                50,
                rejectSensitiveWords: true) ?? "账号搜索";

            var existingRequest = await _context.FriendRequests
                .Include(r => r.requester)
                .Include(r => r.receiver)
                .FirstOrDefaultAsync(r => r.requester_id == userId && r.receiver_id == receiver.id);

            if (existingRequest != null)
            {
                existingRequest.note = note;
                existingRequest.source = source;
                existingRequest.status = FriendRequestStatus.Pending;
                existingRequest.created_at = now;
                existingRequest.updated_at = now;
                await _context.SaveChangesAsync();
                return MapToFriendRequestResponse(existingRequest, userId);
            }

            var friendRequest = new FriendRequest
            {
                requester_id = userId,
                receiver_id = receiver.id,
                note = note,
                source = source,
                status = FriendRequestStatus.Pending,
                created_at = now,
                updated_at = now
            };

            _context.FriendRequests.Add(friendRequest);
            await _context.SaveChangesAsync();

            var createdRequest = await _context.FriendRequests
                .Include(r => r.requester)
                .Include(r => r.receiver)
                .FirstAsync(r => r.id == friendRequest.id);

            return MapToFriendRequestResponse(createdRequest, userId);
        }

        public async Task<List<FriendRequestResponseDto>> GetFriendRequestsAsync(int userId)
        {
            var requests = await _context.FriendRequests
                .Include(r => r.requester)
                .Include(r => r.receiver)
                .Where(r =>
                    r.requester_id != r.receiver_id &&
                    (r.requester_id == userId || r.receiver_id == userId))
                .OrderByDescending(r => r.updated_at)
                .ThenByDescending(r => r.created_at)
                .ToListAsync();

            return requests.Select(request => MapToFriendRequestResponse(request, userId)).ToList();
        }

        public async Task<FriendRequestResponseDto> RespondFriendRequestAsync(int userId, int requestId, FriendRequestDecisionDto decisionDto)
        {
            var normalizedStatus = decisionDto.status.Trim().ToLowerInvariant();
            var nextStatus = normalizedStatus switch
            {
                "accepted" or "accept" => FriendRequestStatus.Accepted,
                "rejected" or "reject" => FriendRequestStatus.Rejected,
                _ => throw new ArgumentException("处理结果只能是 accepted 或 rejected")
            };

            var request = await _context.FriendRequests
                .Include(r => r.requester)
                .Include(r => r.receiver)
                .FirstOrDefaultAsync(r => r.id == requestId && r.receiver_id == userId);

            if (request == null)
                throw new ArgumentException("好友申请不存在");

            if (request.status != FriendRequestStatus.Pending)
                return MapToFriendRequestResponse(request, userId);

            if (nextStatus == FriendRequestStatus.Accepted)
                await CreateContactPairAsync(userId, request.requester, null);

            request.status = nextStatus;
            request.updated_at = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToFriendRequestResponse(request, userId);
        }

        public async Task ClearHandledFriendRequestsAsync(int userId)
        {
            var handledRequests = await _context.FriendRequests
                .Where(r =>
                    (r.requester_id == userId || r.receiver_id == userId) &&
                    r.status != FriendRequestStatus.Pending)
                .ToListAsync();

            if (handledRequests.Count == 0)
                return;

            _context.FriendRequests.RemoveRange(handledRequests);
            await _context.SaveChangesAsync();
        }

        public async Task<List<ContactResponseDto>> GetContactsAsync(int userId)
        {
            var contacts = await _context.Contacts
                .Include(c => c.contact_user)
                .Where(c => c.user_id == userId)
                .OrderBy(c => c.display_name ?? c.contact_user.username)
                .ToListAsync();

            return contacts.Select(c => new ContactResponseDto
            {
                id = c.id,
                contact_user = MapToUserResponse(c.contact_user),
                display_name = c.display_name,
                added_at = c.added_at,
                is_blocked = c.is_blocked,
                last_message_at = c.last_message_at,
                unread_count = c.unread_count
            }).ToList();
        }

        public async Task<List<ContactResponseDto>> SearchContactsAsync(int userId, string query)
        {
            if (string.IsNullOrWhiteSpace(query))
                return await GetContactsAsync(userId);

            var searchTerm = _contentSecurity.NormalizeRequiredText(query, "搜索内容", 100, filterSensitiveWords: false);

            var contacts = await _context.Contacts
                .Include(c => c.contact_user)
                .Where(c => c.user_id == userId && 
                           (c.contact_user.username.Contains(searchTerm) ||
                            (c.contact_user.display_name != null && c.contact_user.display_name.Contains(searchTerm)) ||
                            (c.display_name != null && c.display_name.Contains(searchTerm))))
                .OrderBy(c => c.display_name ?? c.contact_user.username)
                .ToListAsync();

            return contacts.Select(c => new ContactResponseDto
            {
                id = c.id,
                contact_user = MapToUserResponse(c.contact_user),
                display_name = c.display_name,
                added_at = c.added_at,
                is_blocked = c.is_blocked,
                last_message_at = c.last_message_at,
                unread_count = c.unread_count
            }).ToList();
        }

        public async Task RemoveContactAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            // 删除双向联系人关系
            var reverseContact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.user_id == contact.contact_user_id && c.contact_user_id == userId);

            _context.Contacts.Remove(contact);
            if (reverseContact != null)
            {
                _context.Contacts.Remove(reverseContact);
            }
            
            await _context.SaveChangesAsync();
        }

        public async Task BlockContactAsync(int userId, int contactId, bool isBlocked)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            contact.is_blocked = isBlocked;
            await _context.SaveChangesAsync();
        }

        public async Task<ContactResponseDto> UpdateContactDisplayNameAsync(int userId, int contactId, string displayName)
        {
            var contact = await _context.Contacts
                .Include(c => c.contact_user)
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            contact.display_name = _contentSecurity.NormalizeOptionalText(
                displayName,
                "联系人备注",
                50,
                rejectSensitiveWords: true);
            await _context.SaveChangesAsync();

            return new ContactResponseDto
            {
                id = contact.id,
                contact_user = MapToUserResponse(contact.contact_user),
                display_name = contact.display_name,
                added_at = contact.added_at,
                is_blocked = contact.is_blocked,
                last_message_at = contact.last_message_at,
                unread_count = contact.unread_count
            };
        }

        private async Task<ContactResponseDto> CreateContactPairAsync(int userId, User contactUser, string? displayName)
        {
            var existingContact = await _context.Contacts
                .Include(c => c.contact_user)
                .FirstOrDefaultAsync(c => c.user_id == userId && c.contact_user_id == contactUser.id);

            if (existingContact != null)
                return MapToContactResponse(existingContact);

            var now = DateTime.UtcNow;
            var contact = new Contact
            {
                user_id = userId,
                contact_user_id = contactUser.id,
                display_name = displayName,
                added_at = now,
                contact_user = contactUser
            };

            var reverseContactExists = await _context.Contacts
                .AnyAsync(c => c.user_id == contactUser.id && c.contact_user_id == userId);

            _context.Contacts.Add(contact);

            if (!reverseContactExists)
            {
                _context.Contacts.Add(new Contact
                {
                    user_id = contactUser.id,
                    contact_user_id = userId,
                    display_name = null,
                    added_at = now
                });
            }

            await _context.SaveChangesAsync();
            return MapToContactResponse(contact);
        }

        private static string BuildDefaultFriendRequestNote(User requester)
        {
            var name = string.IsNullOrWhiteSpace(requester.display_name)
                ? requester.username
                : requester.display_name.Trim();
            return $"我是{name}，请求添加你为好友";
        }

        private static ContactResponseDto MapToContactResponse(Contact contact)
        {
            return new ContactResponseDto
            {
                id = contact.id,
                contact_user = MapToUserResponse(contact.contact_user),
                display_name = contact.display_name,
                added_at = contact.added_at,
                is_blocked = contact.is_blocked,
                last_message_at = contact.last_message_at,
                unread_count = contact.unread_count
            };
        }

        private static FriendRequestResponseDto MapToFriendRequestResponse(FriendRequest request, int currentUserId)
        {
            return new FriendRequestResponseDto
            {
                id = request.id,
                requester = MapToUserResponse(request.requester),
                receiver = MapToUserResponse(request.receiver),
                note = request.note,
                source = request.source,
                status = request.status switch
                {
                    FriendRequestStatus.Accepted => "accepted",
                    FriendRequestStatus.Rejected => "rejected",
                    _ => "pending"
                },
                direction = request.requester_id == currentUserId ? "outgoing" : "incoming",
                created_at = request.created_at,
                updated_at = request.updated_at
            };
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                id = user.id,
                username = user.username,
                email = user.email,
                email_verified = user.email_verified_at.HasValue,
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
    }

    public class JwtService : IJwtService
    {
        private readonly IConfiguration _configuration;
        private readonly string _secretKey;
        private readonly string _issuer;
        private readonly string _audience;
        private readonly int _expirationInDays;

        public JwtService(IConfiguration configuration)
        {
            _configuration = configuration;
            _secretKey = _configuration["Jwt:SecretKey"] ?? "VideoCallSecretKey123456789012345678901234567890";
            _issuer = _configuration["Jwt:Issuer"] ?? "VideoCallAPI";
            _audience = _configuration["Jwt:Audience"] ?? "VideoCallClient";
            _expirationInDays = int.TryParse(_configuration["Jwt:ExpirationInDays"], out var days)
                ? Math.Clamp(days, 1, 30)
                : 7;
        }

        public string GenerateToken(User user)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_secretKey);
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, user.id.ToString()),
                    new Claim(ClaimTypes.Name, user.username),
                    new Claim(ClaimTypes.Email, user.email)
                }),
                Issuer = _issuer,
                Audience = _audience,
                Expires = DateTime.UtcNow.AddDays(_expirationInDays),
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
            };
            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        public bool ValidateToken(string token)
        {
            try
            {
                var tokenHandler = new JwtSecurityTokenHandler();
                var key = Encoding.ASCII.GetBytes(_secretKey);
                tokenHandler.ValidateToken(token, new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = true,
                    ValidIssuer = _issuer,
                    ValidateAudience = true,
                    ValidAudience = _audience,
                    ClockSkew = TimeSpan.Zero
                }, out SecurityToken validatedToken);

                return true;
            }
            catch
            {
                return false;
            }
        }

        public int? GetUserIdFromToken(string token)
        {
            try
            {
                var tokenHandler = new JwtSecurityTokenHandler();
                var jsonToken = tokenHandler.ReadJwtToken(token);
                
                // JWT 中的 NameIdentifier 会被序列化为 "nameid"
                var userIdClaim = jsonToken.Claims.FirstOrDefault(x => 
                    x.Type == ClaimTypes.NameIdentifier || x.Type == "nameid");
                
                if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
                {
                    return userId;
                }
                
                return null;
            }
            catch
            {
                return null;
            }
        }
    }

    public class ChatService : IChatService
    {
        private readonly VideoCallDbContext _context;
        private readonly ILogger<ChatService> _logger;
        private readonly IContentSecurityService _contentSecurity;

        public ChatService(
            VideoCallDbContext context,
            ILogger<ChatService> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

public async Task<ChatMessageDto> SendMessageAsync(int senderId, SendMessageDto sendMessageDto)
{
    var senderContact = await _context.Contacts
        .FirstOrDefaultAsync(c => c.user_id == senderId && c.contact_user_id == sendMessageDto.receiver_id);
    if (senderContact == null)
        throw new InvalidOperationException("请先添加好友后再发送消息");

    if (senderContact.is_blocked)
        throw new InvalidOperationException("该联系人已被屏蔽，无法发送消息");

    var content = _contentSecurity.NormalizeRequiredText(
        sendMessageDto.content,
        "消息内容",
        1000,
        rejectSensitiveWords: true);
    var filePath = _contentSecurity.NormalizeStoredFilePath(sendMessageDto.file_path, "文件路径", "/chat-files/");
    var duration = sendMessageDto.duration;
    if (duration.HasValue && (duration.Value < 0 || duration.Value > 3600))
        throw new ArgumentException("消息时长不合法");

    var replySnapshot = await GetReplySnapshotAsync(
        senderId,
        sendMessageDto.receiver_id,
        sendMessageDto.reply_to_message_id);

    var message = new ChatMessage
    {
        sender_id = senderId,
        receiver_id = sendMessageDto.receiver_id,
        content = content,
        type = sendMessageDto.type,
        file_path = filePath,
        file_size = sendMessageDto.file_size,
        duration = duration,
        reply_to_message_id = replySnapshot?.id,
        reply_to_sender_name = replySnapshot?.sender_name,
        reply_to_content = replySnapshot?.content,
        reply_to_type = replySnapshot?.type,
        reply_to_file_path = replySnapshot?.file_path,
        timestamp = DateTime.UtcNow,
        created_at = DateTime.UtcNow
    };

    _context.ChatMessages.Add(message);
    await _context.SaveChangesAsync();

    // 更新联系人的最后消息时间
    var contact = await _context.Contacts
        .FirstOrDefaultAsync(c => c.user_id == sendMessageDto.receiver_id && c.contact_user_id == senderId);
    if (contact != null)
    {
        contact.last_message_at = DateTime.UtcNow;
        contact.unread_count++;
        await _context.SaveChangesAsync();
    }

    // 重新加载消息以包含导航属性
    var loadedMessage = await _context.ChatMessages
        .Include(m => m.sender)
        .Include(m => m.receiver)
        .FirstOrDefaultAsync(m => m.id == message.id);

    _logger.LogInformation("消息发送成功: MessageId={MessageId}, SenderId={SenderId}, ReceiverId={ReceiverId}, Type={Type}", 
        message.id, senderId, sendMessageDto.receiver_id, sendMessageDto.type);

    return MapToChatMessageDto(loadedMessage!);
}

        public async Task<List<ChatMessageDto>> GetChatHistoryAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);
            if (contact == null)
                throw new ArgumentException("联系人不存在");

            var unreadMessages = await _context.ChatMessages
                .Where(m => m.sender_id == contact.contact_user_id &&
                            m.receiver_id == userId &&
                            !m.is_read)
                .ToListAsync();

            if (unreadMessages.Count > 0 || contact.unread_count > 0)
            {
                foreach (var unreadMessage in unreadMessages)
                {
                    unreadMessage.is_read = true;
                }

                contact.unread_count = 0;
                await _context.SaveChangesAsync();
            }

            var messages = await _context.ChatMessages
                .Include(m => m.sender)
                .Include(m => m.receiver)
                .Where(m => (m.sender_id == userId && m.receiver_id == contact.contact_user_id) ||
                           (m.sender_id == contact.contact_user_id && m.receiver_id == userId))
                .OrderBy(m => m.timestamp)
                .ToListAsync();

            return messages.Select(MapToChatMessageDto).ToList();
        }

        public async Task<List<ChatHistoryDto>> GetChatHistoryAsync(int userId)
        {
            var contacts = await _context.Contacts
                .Include(c => c.contact_user)
                .Where(c => c.user_id == userId && c.last_message_at != null)
                .OrderByDescending(c => c.last_message_at)
                .ToListAsync();

            var chatHistoryList = new List<ChatHistoryDto>();

            foreach (var contact in contacts)
            {
                var messages = await _context.ChatMessages
                    .Include(m => m.sender)
                    .Include(m => m.receiver)
                    .Where(m => (m.sender_id == userId && m.receiver_id == contact.contact_user_id) ||
                               (m.sender_id == contact.contact_user_id && m.receiver_id == userId))
                    .OrderByDescending(m => m.timestamp)
                    .Take(10)
                    .ToListAsync();

                chatHistoryList.Add(new ChatHistoryDto
                {
                    contact_id = contact.id,
                    contact_name = contact.display_name ?? contact.contact_user.username,
                    last_message_at = contact.last_message_at,
                    unread_count = contact.unread_count,
                    messages = messages.Select(MapToChatMessageDto).ToList()
                });
            }

            return chatHistoryList;
        }

        public async Task MarkMessageAsReadAsync(int messageId, int userId)
        {
            var message = await _context.ChatMessages
                .FirstOrDefaultAsync(m => m.id == messageId && m.receiver_id == userId);

            if (message != null)
            {
                if (!message.is_read)
                    message.is_read = true;

                var contact = await _context.Contacts
                    .FirstOrDefaultAsync(c => c.user_id == userId && c.contact_user_id == message.sender_id);
                if (contact != null)
                {
                    var unreadCount = await _context.ChatMessages
                        .CountAsync(m => m.sender_id == message.sender_id &&
                                         m.receiver_id == userId &&
                                         !m.is_read &&
                                         m.id != message.id);
                    contact.unread_count = unreadCount;
                }

                await _context.SaveChangesAsync();
            }
        }

        public async Task<List<ChatMessageDto>> GetUnreadMessagesAsync(int userId)
        {
            var messages = await _context.ChatMessages
                .Include(m => m.sender)
                .Include(m => m.receiver)
                .Where(m => m.receiver_id == userId && !m.is_read)
                .OrderBy(m => m.timestamp)
                .ToListAsync();

            return messages.Select(MapToChatMessageDto).ToList();
        }

        public async Task DeleteChatHistoryAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);
            if (contact == null)
                throw new ArgumentException("联系人不存在");

            var messages = await _context.ChatMessages
                .Where(m => (m.sender_id == userId && m.receiver_id == contact.contact_user_id) ||
                           (m.sender_id == contact.contact_user_id && m.receiver_id == userId))
                .ToListAsync();

            _context.ChatMessages.RemoveRange(messages);
            
            // 重置联系人的最后消息时间和未读计数
            contact.last_message_at = null;
            contact.unread_count = 0;
            
            await _context.SaveChangesAsync();
        }

        private static ChatMessageDto MapToChatMessageDto(ChatMessage message)
        {
            return new ChatMessageDto
            {
                id = message.id,
                sender_id = message.sender_id,
                receiver_id = message.receiver_id,
                content = message.content,
                type = message.type,
                timestamp = message.timestamp,
                is_read = message.is_read,
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
                sender = MapToUserResponse(message.sender),
                receiver = MapToUserResponse(message.receiver)
            };
        }

        private async Task<ReplyMessageSnapshotDto?> GetReplySnapshotAsync(int senderId, int receiverId, int? replyToMessageId)
        {
            if (!replyToMessageId.HasValue)
                return null;

            var replyMessage = await _context.ChatMessages
                .Include(m => m.sender)
                .FirstOrDefaultAsync(m => m.id == replyToMessageId.Value &&
                    ((m.sender_id == senderId && m.receiver_id == receiverId) ||
                     (m.sender_id == receiverId && m.receiver_id == senderId)));

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

        private static string GetDisplayName(User user)
        {
            return !string.IsNullOrWhiteSpace(user.display_name) ? user.display_name : user.username;
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                id = user.id,
                username = user.username,
                email = user.email,
                email_verified = user.email_verified_at.HasValue,
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
    }
}
