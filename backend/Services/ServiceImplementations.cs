using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
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

        public UserService(
            VideoCallDbContext context,
            IJwtService jwtService,
            ILogger<UserService> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _jwtService = jwtService;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        public async Task<UserResponseDto> RegisterAsync(UserRegistrationDto registrationDto)
        {
            var username = _contentSecurity.NormalizeRequiredText(
                registrationDto.username,
                "用户名",
                50,
                filterSensitiveWords: false,
                rejectSensitiveWords: true);
            var email = _contentSecurity.NormalizeRequiredText(registrationDto.email, "邮箱", 100, filterSensitiveWords: false);

            // 检查用户名是否已存在
            if (await _context.users.AnyAsync(u => u.username == username))
            {
                _logger.LogWarning("注册失败，用户名已存在: {Username}", username);
                throw new InvalidOperationException("用户名已存在");
            }

            // 检查邮箱是否已存在
            if (await _context.users.AnyAsync(u => u.email == email))
            {
                _logger.LogWarning("注册失败，邮箱已存在: {Email}", email);
                throw new InvalidOperationException("邮箱已存在");
            }

            var user = new User
            {
                username = username,
                email = email,
                password_hash = BCrypt.Net.BCrypt.HashPassword(registrationDto.password),
                created_at = DateTime.UtcNow
            };

            _context.users.Add(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation("用户注册成功: UserId={UserId}, Username={Username}", user.id, user.username);
            return MapToUserResponse(user);
        }

        public async Task<string> LoginAsync(UserLoginDto loginDto)
        {
            var username = _contentSecurity.NormalizeRequiredText(loginDto.username, "用户名", 50, filterSensitiveWords: false);
            var user = await _context.users.FirstOrDefaultAsync(u => u.username == username);
            if (user == null || !BCrypt.Net.BCrypt.Verify(loginDto.password, user.password_hash))
            {
                _logger.LogWarning("登录失败，用户名或密码错误: {Username}", username);
                throw new UnauthorizedAccessException("用户名或密码错误");
            }

            var now = DateTime.UtcNow;

            // 更新最后登录时间，并写入首个心跳
            user.last_login_at = now;
            user.last_heartbeat_at = now;
            user.is_online = true;
            await _context.SaveChangesAsync();

            _logger.LogInformation("用户登录成功: UserId={UserId}, Username={Username}", user.id, user.username);
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

            if (!BCrypt.Net.BCrypt.Verify(changePasswordDto.old_password, user.password_hash))
                throw new UnauthorizedAccessException("原密码错误");

            user.password_hash = BCrypt.Net.BCrypt.HashPassword(changePasswordDto.new_password);
            await _context.SaveChangesAsync();

            return true;
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
            query = query.Where(u => u.username.ToLower() != "admin");

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

        public ContactService(
            VideoCallDbContext context,
            ILogger<ContactService> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
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

            if (string.Equals(receiver.username, "admin", StringComparison.OrdinalIgnoreCase))
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

    var message = new ChatMessage
    {
        sender_id = senderId,
        receiver_id = sendMessageDto.receiver_id,
        content = content,
        type = sendMessageDto.type,
        file_path = filePath,
        file_size = sendMessageDto.file_size,
        duration = duration,
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
                created_at = message.created_at,
                sender = MapToUserResponse(message.sender),
                receiver = MapToUserResponse(message.receiver)
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
    }
}
