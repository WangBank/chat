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

        public UserService(VideoCallDbContext context, IJwtService jwtService)
        {
            _context = context;
            _jwtService = jwtService;
        }

        public async Task<UserResponseDto> RegisterAsync(UserRegistrationDto registrationDto)
        {
            // 检查用户名是否已存在
            if (await _context.users.AnyAsync(u => u.username == registrationDto.username))
                throw new InvalidOperationException("用户名已存在");

            // 检查邮箱是否已存在
            if (await _context.users.AnyAsync(u => u.email == registrationDto.email))
                throw new InvalidOperationException("邮箱已存在");

            var user = new User
            {
                username = registrationDto.username,
                email = registrationDto.email,
                password_hash = BCrypt.Net.BCrypt.HashPassword(registrationDto.password),
                created_at = DateTime.UtcNow
            };

            _context.users.Add(user);
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        public async Task<string> LoginAsync(UserLoginDto loginDto)
        {
            var user = await _context.users.FirstOrDefaultAsync(u => u.username == loginDto.username);
            if (user == null || !BCrypt.Net.BCrypt.Verify(loginDto.password, user.password_hash))
                throw new UnauthorizedAccessException("用户名或密码错误");

            // 更新最后登录时间
            user.last_login_at = DateTime.UtcNow;
            user.is_online = true;
            await _context.SaveChangesAsync();

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

            if (!string.IsNullOrWhiteSpace(updateProfileDto.nickname))
                user.nickname = updateProfileDto.nickname;
            
            if (!string.IsNullOrWhiteSpace(updateProfileDto.avatar_path))
                user.avatar_path = updateProfileDto.avatar_path;

            user.updated_at = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        public async Task<UserResponseDto> UploadAvatarAsync(int userId, IFormFile avatar)
        {
            var user = await _context.users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            // 创建头像存储目录
            var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "avatars");
            if (!Directory.Exists(uploadsDir))
            {
                Directory.CreateDirectory(uploadsDir);
            }

            // 生成唯一文件名
            var fileName = $"{userId}_{DateTime.UtcNow:yyyyMMddHHmmss}{Path.GetExtension(avatar.FileName)}";
            var filePath = Path.Combine(uploadsDir, fileName);

            // 保存文件
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await avatar.CopyToAsync(stream);
            }

            // 更新用户头像路径
            user.avatar_path = $"/uploads/avatars/{fileName}";
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
                nickname = user.nickname,
                avatar_path = user.avatar_path,
                is_online = user.is_online,
                last_login_at = user.last_login_at,
                created_at = user.created_at,
                updated_at = user.updated_at
            };
        }

        public async Task<UserSearchResultDto> SearchUsersAsync(int currentUserId, SearchUsersDto searchDto)
        {
            var query = _context.users.AsQueryable();

            // 排除当前用户
            query = query.Where(u => u.id != currentUserId);

            // 排除已经是联系人的用户
            var existingContactIds = await _context.Contacts
                .Where(c => c.user_id == currentUserId)
                .Select(c => c.contact_user_id)
                .ToListAsync();
            
            query = query.Where(u => !existingContactIds.Contains(u.id));

            // 搜索条件
            if (!string.IsNullOrWhiteSpace(searchDto.query))
            {
                var searchTerm = searchDto.query.ToLower();
                query = query.Where(u => 
                    u.username.ToLower().Contains(searchTerm) ||
                    u.nickname.ToLower().Contains(searchTerm) ||
                    u.email.ToLower().Contains(searchTerm));
            }

            // 获取总数
            var totalCount = await query.CountAsync();

            // 分页
            var users = await query
                .OrderBy(u => u.username)
                .Skip((searchDto.page - 1) * searchDto.page_size)
                .Take(searchDto.page_size)
                .ToListAsync();

            var totalPages = (int)Math.Ceiling((double)totalCount / searchDto.page_size);

            return new UserSearchResultDto
            {
                users = users.Select(MapToUserResponse).ToList(),
                total_count = totalCount,
                page = searchDto.page,
                page_size = searchDto.page_size,
                total_pages = totalPages
            };
        }
    }

    public class ContactService : IContactService
    {
        private readonly VideoCallDbContext _context;

        public ContactService(VideoCallDbContext context)
        {
            _context = context;
        }

        public async Task<ContactResponseDto> AddContactAsync(int userId, AddContactDto addContactDto)
        {
            // 查找要添加的用户
            var contactUser = await _context.users.FirstOrDefaultAsync(u => u.username == addContactDto.username);
            if (contactUser == null)
                throw new ArgumentException("用户不存在");

            if (contactUser.id == userId)
                throw new InvalidOperationException("不能添加自己为联系人");

            // 检查是否已经是联系人
            if (await _context.Contacts.AnyAsync(c => c.user_id == userId && c.contact_user_id == contactUser.id))
                throw new InvalidOperationException("用户已在联系人列表中");

            // 创建双向联系人关系
            var contact1 = new Contact
            {
                user_id = userId,
                contact_user_id = contactUser.id,
                display_name = addContactDto.display_name,
                added_at = DateTime.UtcNow
            };

            var contact2 = new Contact
            {
                user_id = contactUser.id,
                contact_user_id = userId,
                display_name = null, // 对方可以自己设置备注名
                added_at = DateTime.UtcNow
            };

            _context.Contacts.Add(contact1);
            _context.Contacts.Add(contact2);
            await _context.SaveChangesAsync();

            return new ContactResponseDto
            {
                id = contact1.id,
                contact_user = MapToUserResponse(contactUser),
                display_name = contact1.display_name,
                added_at = contact1.added_at,
                is_blocked = contact1.is_blocked,
                last_message_at = contact1.last_message_at,
                unread_count = contact1.unread_count
            };
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

            var contacts = await _context.Contacts
                .Include(c => c.contact_user)
                .Where(c => c.user_id == userId && 
                           (c.contact_user.username.Contains(query) || 
                            c.contact_user.nickname.Contains(query) ||
                            c.display_name.Contains(query)))
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

            contact.display_name = displayName;
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
    }

    public class JwtService : IJwtService
    {
        private readonly IConfiguration _configuration;
        private readonly string _secretKey;

        public JwtService(IConfiguration configuration)
        {
            _configuration = configuration;
            _secretKey = _configuration["Jwt:SecretKey"] ?? "VideoCallSecretKey123456789012345678901234567890";
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
                Expires = DateTime.UtcNow.AddDays(7),
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
                    ValidateIssuer = false,
                    ValidateAudience = false,
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

        public ChatService(VideoCallDbContext context)
        {
            _context = context;
        }

public async Task<ChatMessageDto> SendMessageAsync(int senderId, SendMessageDto sendMessageDto)
{
    var message = new ChatMessage
    {
        sender_id = senderId,
        receiver_id = sendMessageDto.receiver_id,
        content = sendMessageDto.content,
        type = sendMessageDto.type,
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

    return MapToChatMessageDto(loadedMessage!);
}

        public async Task<List<ChatMessageDto>> GetChatHistoryAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.id == contactId && c.user_id == userId);
            if (contact == null)
                throw new ArgumentException("联系人不存在");

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
                message.is_read = true;
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
                nickname = user.nickname,
                avatar_path = user.avatar_path,
                is_online = user.is_online,
                last_login_at = user.last_login_at,
                created_at = user.created_at,
                updated_at = user.updated_at
            };
        }
    }
}
