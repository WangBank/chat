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

        public async Task<UserResponseDto> UpdateAvatarAsync(int userId, string avatarPath)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            user.AvatarPath = avatarPath;
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
                AvatarPath = user.AvatarPath,
                IsOnline = user.IsOnline,
                LastLoginAt = user.LastLoginAt
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

            var contact = new Contact
            {
                UserId = userId,
                ContactUserId = contactUser.Id,
                DisplayName = addContactDto.DisplayName,
                AddedAt = DateTime.UtcNow
            };

            _context.Contacts.Add(contact);
            await _context.SaveChangesAsync();

            return new ContactResponseDto
            {
                Id = contact.Id,
                ContactUser = MapToUserResponse(contactUser),
                DisplayName = contact.DisplayName,
                AddedAt = contact.AddedAt,
                IsBlocked = contact.IsBlocked
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
                IsBlocked = c.IsBlocked
            }).ToList();
        }

        public async Task RemoveContactAsync(int userId, int contactId)
        {
            var contact = await _context.Contacts
                .FirstOrDefaultAsync(c => c.Id == contactId && c.UserId == userId);

            if (contact == null)
                throw new ArgumentException("联系人不存在");

            _context.Contacts.Remove(contact);
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
                var userIdClaim = jsonToken.Claims.FirstOrDefault(x => x.Type == ClaimTypes.NameIdentifier);
                
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
}
