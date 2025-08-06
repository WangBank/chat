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
            if (await _context.Users.AnyAsync(u => u.Username == registrationDto.Username))
                throw new InvalidOperationException("用户名已存在");

            // 检查邮箱是否已存在
            if (await _context.Users.AnyAsync(u => u.Email == registrationDto.Email))
                throw new InvalidOperationException("邮箱已存在");

            var user = new User
            {
                Username = registrationDto.Username,
                Email = registrationDto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(registrationDto.Password),
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        public async Task<string> LoginAsync(UserLoginDto loginDto)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == loginDto.Username);
            if (user == null || !BCrypt.Net.BCrypt.Verify(loginDto.Password, user.PasswordHash))
                throw new UnauthorizedAccessException("用户名或密码错误");

            // 更新最后登录时间
            user.LastLoginAt = DateTime.UtcNow;
            user.IsOnline = true;
            await _context.SaveChangesAsync();

            return _jwtService.GenerateToken(user);
        }

        public async Task<UserResponseDto> GetUserAsync(int userId)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            return MapToUserResponse(user);
        }

        public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto changePasswordDto)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            if (!BCrypt.Net.BCrypt.Verify(changePasswordDto.OldPassword, user.PasswordHash))
                throw new UnauthorizedAccessException("原密码错误");

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(changePasswordDto.NewPassword);
            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateProfileDto updateProfileDto)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            if (!string.IsNullOrWhiteSpace(updateProfileDto.Nickname))
                user.Nickname = updateProfileDto.Nickname;
            
            if (!string.IsNullOrWhiteSpace(updateProfileDto.AvatarPath))
                user.AvatarPath = updateProfileDto.AvatarPath;

            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        public async Task<UserResponseDto> UploadAvatarAsync(int userId, IFormFile avatar)
        {
            var user = await _context.Users.FindAsync(userId);
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
            user.AvatarPath = $"/uploads/avatars/{fileName}";
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return MapToUserResponse(user);
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Nickname = user.Nickname,
                AvatarPath = user.AvatarPath,
                IsOnline = user.IsOnline,
                LastLoginAt = user.LastLoginAt,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };
        }

        public async Task<UserSearchResultDto> SearchUsersAsync(int currentUserId, SearchUsersDto searchDto)
        {
            var query = _context.Users.AsQueryable();

            // 排除当前用户
            query = query.Where(u => u.Id != currentUserId);

            // 排除已经是联系人的用户
            var existingContactIds = await _context.Contacts
                .Where(c => c.UserId == currentUserId)
                .Select(c => c.ContactUserId)
                .ToListAsync();
            
            query = query.Where(u => !existingContactIds.Contains(u.Id));

            // 搜索条件
            if (!string.IsNullOrWhiteSpace(searchDto.Query))
            {
                var searchTerm = searchDto.Query.ToLower();
                query = query.Where(u => 
                    u.Username.ToLower().Contains(searchTerm) ||
                    u.Nickname.ToLower().Contains(searchTerm) ||
                    u.Email.ToLower().Contains(searchTerm));
            }

            // 获取总数
            var totalCount = await query.CountAsync();

            // 分页
            var users = await query
                .OrderBy(u => u.Username)
                .Skip((searchDto.Page - 1) * searchDto.PageSize)
                .Take(searchDto.PageSize)
                .ToListAsync();

            var totalPages = (int)Math.Ceiling((double)totalCount / searchDto.PageSize);

            return new UserSearchResultDto
            {
                Users = users.Select(MapToUserResponse).ToList(),
                TotalCount = totalCount,
                Page = searchDto.Page,
                PageSize = searchDto.PageSize,
                TotalPages = totalPages
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
            var contactUser = await _context.Users.FirstOrDefaultAsync(u => u.Username == addContactDto.Username);
            if (contactUser == null)
                throw new ArgumentException("用户不存在");

            if (contactUser.Id == userId)
                throw new InvalidOperationException("不能添加自己为联系人");

            // 检查是否已经是联系人
            if (await _context.Contacts.AnyAsync(c => c.UserId == userId && c.ContactUserId == contactUser.Id))
                throw new InvalidOperationException("用户已在联系人列表中");

            // 创建双向联系人关系
            var contact1 = new Contact
            {
                UserId = userId,
                ContactUserId = contactUser.Id,
                DisplayName = addContactDto.DisplayName,
                AddedAt = DateTime.UtcNow
            };

            var contact2 = new Contact
            {
                UserId = contactUser.Id,
                ContactUserId = userId,
                DisplayName = null, // 对方可以自己设置备注名
                AddedAt = DateTime.UtcNow
            };

            _context.Contacts.Add(contact1);
            _context.Contacts.Add(contact2);
            await _context.SaveChangesAsync();

            return new ContactResponseDto
            {
                Id = contact1.Id,
                ContactUser = MapToUserResponse(contactUser),
                DisplayName = contact1.DisplayName,
                AddedAt = contact1.AddedAt,
                IsBlocked = contact1.IsBlocked,
                LastMessageAt = contact1.LastMessageAt,
                UnreadCount = contact1.UnreadCount
            };
        }

        public async Task<List<ContactResponseDto>> GetContactsAsync(int userId)
        {
            var contacts = await _context.Contacts
                .Include(c => c.ContactUser)
                .Where(c => c.UserId == userId)
                .OrderBy(c => c.DisplayName ?? c.ContactUser.Username)
                .ToListAsync();

            return contacts.Select(c => new ContactResponseDto
            {
                Id = c.Id,
                ContactUser = MapToUserResponse(c.ContactUser),
                DisplayName = c.DisplayName,
                AddedAt = c.AddedAt,
                IsBlocked = c.IsBlocked,
                LastMessageAt = c.LastMessageAt,
                UnreadCount = c.UnreadCount
            }).ToList();
        }

        public async Task<List<ContactResponseDto>> SearchContactsAsync(int userId, string query)
        {
            if (string.IsNullOrWhiteSpace(query))
                return await GetContactsAsync(userId);

            var contacts = await _context.Contacts
                .Include(c => c.ContactUser)
                .Where(c => c.UserId == userId && 
                           (c.ContactUser.Username.Contains(query) || 
                            c.ContactUser.Nickname.Contains(query) ||
                            c.DisplayName.Contains(query)))
                .OrderBy(c => c.DisplayName ?? c.ContactUser.Username)
                .ToListAsync();

            return contacts.Select(c => new ContactResponseDto
            {
                Id = c.Id,
                ContactUser = MapToUserResponse(c.ContactUser),
                DisplayName = c.DisplayName,
                AddedAt = c.AddedAt,
                IsBlocked = c.IsBlocked,
                LastMessageAt = c.LastMessageAt,
                UnreadCount = c.UnreadCount
            }).ToList();
        }

        public async Task RemoveContactAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            // 删除双向联系人关系
            var reverseContact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.UserId == contact.ContactUserId && c.ContactUserId == userId);

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
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            contact.IsBlocked = isBlocked;
            await _context.SaveChangesAsync();
        }

        public async Task<ContactResponseDto> UpdateContactDisplayNameAsync(int userId, int contactId, string displayName)
        {
            var contact = await _context.Contacts
                .Include(c => c.ContactUser)
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            contact.DisplayName = displayName;
            await _context.SaveChangesAsync();

            return new ContactResponseDto
            {
                Id = contact.Id,
                ContactUser = MapToUserResponse(contact.ContactUser),
                DisplayName = contact.DisplayName,
                AddedAt = contact.AddedAt,
                IsBlocked = contact.IsBlocked,
                LastMessageAt = contact.LastMessageAt,
                UnreadCount = contact.UnreadCount
            };
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                AvatarPath = user.AvatarPath,
                IsOnline = user.IsOnline,
                LastLoginAt = user.LastLoginAt
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
                    new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new Claim(ClaimTypes.Name, user.Username),
                    new Claim(ClaimTypes.Email, user.Email)
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
        SenderId = senderId,
        ReceiverId = sendMessageDto.ReceiverId,
        Content = sendMessageDto.Content,
        Type = sendMessageDto.Type,
        Timestamp = DateTime.UtcNow,
        CreatedAt = DateTime.UtcNow
    };

    _context.ChatMessages.Add(message);
    await _context.SaveChangesAsync();

    // 更新联系人的最后消息时间
    var contact = await _context.Contacts
        .FirstOrDefaultAsync(c => c.UserId == sendMessageDto.ReceiverId && c.ContactUserId == senderId);
    if (contact != null)
    {
        contact.LastMessageAt = DateTime.UtcNow;
        contact.UnreadCount++;
        await _context.SaveChangesAsync();
    }

    // 重新加载消息以包含导航属性
    var loadedMessage = await _context.ChatMessages
        .Include(m => m.Sender)
        .Include(m => m.Receiver)
        .FirstOrDefaultAsync(m => m.Id == message.Id);

    return MapToChatMessageDto(loadedMessage!);
}

        public async Task<List<ChatMessageDto>> GetChatHistoryAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);
            if (contact == null)
                throw new ArgumentException("联系人不存在");

            var messages = await _context.ChatMessages
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .Where(m => (m.SenderId == userId && m.ReceiverId == contact.ContactUserId) ||
                           (m.SenderId == contact.ContactUserId && m.ReceiverId == userId))
                .OrderBy(m => m.Timestamp)
                .ToListAsync();

            return messages.Select(MapToChatMessageDto).ToList();
        }

        public async Task<List<ChatHistoryDto>> GetChatHistoryAsync(int userId)
        {
            var contacts = await _context.Contacts
                .Include(c => c.ContactUser)
                .Where(c => c.UserId == userId && c.LastMessageAt != null)
                .OrderByDescending(c => c.LastMessageAt)
                .ToListAsync();

            var chatHistoryList = new List<ChatHistoryDto>();

            foreach (var contact in contacts)
            {
                var messages = await _context.ChatMessages
                    .Include(m => m.Sender)
                    .Include(m => m.Receiver)
                    .Where(m => (m.SenderId == userId && m.ReceiverId == contact.ContactUserId) ||
                               (m.SenderId == contact.ContactUserId && m.ReceiverId == userId))
                    .OrderByDescending(m => m.Timestamp)
                    .Take(10)
                    .ToListAsync();

                chatHistoryList.Add(new ChatHistoryDto
                {
                    ContactId = contact.Id,
                    ContactName = contact.DisplayName ?? contact.ContactUser.Username,
                    LastMessageAt = contact.LastMessageAt,
                    UnreadCount = contact.UnreadCount,
                    Messages = messages.Select(MapToChatMessageDto).ToList()
                });
            }

            return chatHistoryList;
        }

        public async Task MarkMessageAsReadAsync(int messageId, int userId)
        {
            var message = await _context.ChatMessages
                .FirstOrDefaultAsync(m => m.Id == messageId && m.ReceiverId == userId);

            if (message != null)
            {
                message.IsRead = true;
                await _context.SaveChangesAsync();
            }
        }

        public async Task<List<ChatMessageDto>> GetUnreadMessagesAsync(int userId)
        {
            var messages = await _context.ChatMessages
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .Where(m => m.ReceiverId == userId && !m.IsRead)
                .OrderBy(m => m.Timestamp)
                .ToListAsync();

            return messages.Select(MapToChatMessageDto).ToList();
        }

        public async Task DeleteChatHistoryAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);
            if (contact == null)
                throw new ArgumentException("联系人不存在");

            var messages = await _context.ChatMessages
                .Where(m => (m.SenderId == userId && m.ReceiverId == contact.ContactUserId) ||
                           (m.SenderId == contact.ContactUserId && m.ReceiverId == userId))
                .ToListAsync();

            _context.ChatMessages.RemoveRange(messages);
            
            // 重置联系人的最后消息时间和未读计数
            contact.LastMessageAt = null;
            contact.UnreadCount = 0;
            
            await _context.SaveChangesAsync();
        }

        private static ChatMessageDto MapToChatMessageDto(ChatMessage message)
        {
            return new ChatMessageDto
            {
                Id = message.Id,
                SenderId = message.SenderId,
                ReceiverId = message.ReceiverId,
                Content = message.Content,
                Type = message.Type,
                Timestamp = message.Timestamp,
                IsRead = message.IsRead,
                FilePath = message.FilePath,
                FileSize = message.FileSize,
                Duration = message.Duration,
                CreatedAt = message.CreatedAt,
                Sender = MapToUserResponse(message.Sender),
                Receiver = MapToUserResponse(message.Receiver)
            };
        }

        private static UserResponseDto MapToUserResponse(User user)
        {
            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Nickname = user.Nickname,
                AvatarPath = user.AvatarPath,
                IsOnline = user.IsOnline,
                LastLoginAt = user.LastLoginAt,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };
        }
    }
}
