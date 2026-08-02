using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using VideoCallAPI.Data;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;

namespace VideoCallAPI.Services
{
    public class QQAuthService : IQQAuthService
    {
        private const string AuthorizeEndpoint = "https://graph.qq.com/oauth2.0/authorize";
        private const string TokenEndpoint = "https://graph.qq.com/oauth2.0/token";
        private const string OpenIdEndpoint = "https://graph.qq.com/oauth2.0/me";
        private const string UserInfoEndpoint = "https://graph.qq.com/user/get_user_info";
        private static readonly TimeSpan StateLifetime = TimeSpan.FromMinutes(10);

        private readonly VideoCallDbContext _context;
        private readonly IJwtService _jwtService;
        private readonly IContentSecurityService _contentSecurity;
        private readonly IConfiguration _configuration;
        private readonly IMemoryCache _memoryCache;
        private readonly HttpClient _httpClient;
        private readonly ILogger<QQAuthService> _logger;

        public QQAuthService(
            VideoCallDbContext context,
            IJwtService jwtService,
            IContentSecurityService contentSecurity,
            IConfiguration configuration,
            IMemoryCache memoryCache,
            HttpClient httpClient,
            ILogger<QQAuthService> logger)
        {
            _context = context;
            _jwtService = jwtService;
            _contentSecurity = contentSecurity;
            _configuration = configuration;
            _memoryCache = memoryCache;
            _httpClient = httpClient;
            _logger = logger;
        }

        public QQLoginUrlResponseDto CreateLoginUrl(string mode)
        {
            var normalizedMode = NormalizeMode(mode);
            var state = GenerateState();
            _memoryCache.Set(GetStateCacheKey(state), normalizedMode, StateLifetime);

            var configured = IsConfigured();
            return new QQLoginUrlResponseDto
            {
                auth_url = configured ? BuildAuthorizationUrl(state) : string.Empty,
                state = state,
                mode = normalizedMode,
                configured = configured,
                mock_available = IsMockLoginEnabled()
            };
        }

        public async Task<(string Token, UserResponseDto User)> CompleteLoginAsync(QQLoginRequestDto loginDto)
        {
            var profile = await GetQQProfileFromCodeAsync(loginDto, "login");
            var user = await FindOrCreateQQUserAsync(profile);
            await _context.SaveChangesAsync();

            return (_jwtService.GenerateToken(user), MapToUserResponse(user));
        }

        public async Task<UserResponseDto> BindAsync(int userId, QQLoginRequestDto loginDto)
        {
            var profile = await GetQQProfileFromCodeAsync(loginDto, "bind");
            var user = await BindProfileToUserAsync(userId, profile);
            await _context.SaveChangesAsync();
            return MapToUserResponse(user);
        }

        public async Task<(string Token, UserResponseDto User)> DevLoginAsync(QQDevLoginDto loginDto)
        {
            EnsureMockLoginEnabled();
            var profile = CreateDevProfile(loginDto);
            var user = await FindOrCreateQQUserAsync(profile);
            await _context.SaveChangesAsync();

            return (_jwtService.GenerateToken(user), MapToUserResponse(user));
        }

        public async Task<UserResponseDto> DevBindAsync(int userId, QQDevLoginDto loginDto)
        {
            EnsureMockLoginEnabled();
            var profile = CreateDevProfile(loginDto);
            var user = await BindProfileToUserAsync(userId, profile);
            await _context.SaveChangesAsync();
            return MapToUserResponse(user);
        }

        private async Task<QQProfile> GetQQProfileFromCodeAsync(QQLoginRequestDto loginDto, string expectedMode)
        {
            if (!IsConfigured())
                throw new InvalidOperationException("QQ登录尚未配置，请先设置 QQ:ClientId、QQ:ClientSecret 和 QQ:RedirectUri");

            ConsumeState(loginDto.state, expectedMode);

            var code = _contentSecurity.NormalizeRequiredText(loginDto.code, "QQ授权码", 500, filterSensitiveWords: false);
            var clientId = GetRequiredConfig("QQ:ClientId");
            var clientSecret = GetRequiredConfig("QQ:ClientSecret");
            var redirectUri = GetRequiredConfig("QQ:RedirectUri");

            var tokenUrl = $"{TokenEndpoint}?{BuildQuery(new Dictionary<string, string>
            {
                ["grant_type"] = "authorization_code",
                ["client_id"] = clientId,
                ["client_secret"] = clientSecret,
                ["code"] = code,
                ["redirect_uri"] = redirectUri
            })}";

            var tokenPayload = ParseQueryPayload(await _httpClient.GetStringAsync(tokenUrl));
            if (!tokenPayload.TryGetValue("access_token", out var accessToken) || string.IsNullOrWhiteSpace(accessToken))
            {
                var error = tokenPayload.TryGetValue("error_description", out var description)
                    ? description
                    : "QQ access_token 获取失败";
                throw new InvalidOperationException(error);
            }

            var openIdUrl = $"{OpenIdEndpoint}?access_token={Uri.EscapeDataString(accessToken)}";
            var openIdPayload = ParseQQJsonCallback(await _httpClient.GetStringAsync(openIdUrl));
            var openId = GetRequiredJsonString(openIdPayload, "openid", "QQ openid 获取失败");
            var unionId = GetOptionalJsonString(openIdPayload, "unionid");

            var userInfoUrl = $"{UserInfoEndpoint}?{BuildQuery(new Dictionary<string, string>
            {
                ["access_token"] = accessToken,
                ["oauth_consumer_key"] = clientId,
                ["openid"] = openId
            })}";

            using var userInfo = JsonDocument.Parse(await _httpClient.GetStringAsync(userInfoUrl));
            var root = userInfo.RootElement;
            if (root.TryGetProperty("ret", out var retElement) && retElement.GetInt32() != 0)
            {
                var message = GetOptionalJsonString(root, "msg") ?? "QQ用户信息获取失败";
                throw new InvalidOperationException(message);
            }

            var nickname = GetOptionalJsonString(root, "nickname") ?? "QQ用户";
            var avatarUrl =
                GetOptionalJsonString(root, "figureurl_qq_2") ??
                GetOptionalJsonString(root, "figureurl_qq_1") ??
                GetOptionalJsonString(root, "figureurl_2") ??
                GetOptionalJsonString(root, "figureurl_1");

            return new QQProfile(openId, unionId, nickname, avatarUrl);
        }

        private async Task<User> FindOrCreateQQUserAsync(QQProfile profile)
        {
            var user = await _context.users.FirstOrDefaultAsync(u => u.qq_open_id == profile.OpenId);
            var now = DateTime.UtcNow;

            if (user == null)
            {
                var username = await GenerateUniqueUsernameAsync(profile.OpenId);
                user = new User
                {
                    username = username,
                    email = $"{username}@qq.local",
                    password_hash = BCrypt.Net.BCrypt.HashPassword($"{Guid.NewGuid():N}:{profile.OpenId}"),
                    display_name = NormalizeNickname(profile.Nickname),
                    created_at = now,
                    updated_at = now
                };

                _context.users.Add(user);
            }

            ApplyQQProfile(user, profile, overwriteLocalProfile: true);
            user.last_login_at = now;
            user.last_heartbeat_at = now;
            user.is_online = true;
            user.updated_at = now;

            _logger.LogInformation("QQ登录成功: UserId={UserId}, OpenId={OpenId}", user.id, profile.OpenId);
            return user;
        }

        private async Task<User> BindProfileToUserAsync(int userId, QQProfile profile)
        {
            var user = await _context.users.FirstOrDefaultAsync(u => u.id == userId);
            if (user == null)
                throw new ArgumentException("用户不存在");

            var existingUser = await _context.users
                .FirstOrDefaultAsync(u => u.qq_open_id == profile.OpenId && u.id != userId);
            if (existingUser != null)
                throw new InvalidOperationException("该 QQ 已绑定其他账号");

            ApplyQQProfile(user, profile, overwriteLocalProfile: false);
            user.updated_at = DateTime.UtcNow;
            _logger.LogInformation("QQ绑定成功: UserId={UserId}, OpenId={OpenId}", userId, profile.OpenId);
            return user;
        }

        private void ApplyQQProfile(User user, QQProfile profile, bool overwriteLocalProfile)
        {
            user.qq_open_id = profile.OpenId;
            user.qq_union_id = profile.UnionId;
            user.qq_nickname = NormalizeNickname(profile.Nickname);
            user.qq_avatar_url = NormalizeExternalUrl(profile.AvatarUrl, "QQ头像地址");
            user.qq_bound_at ??= DateTime.UtcNow;

            if (overwriteLocalProfile || string.IsNullOrWhiteSpace(user.display_name))
                user.display_name = user.qq_nickname;

            if ((overwriteLocalProfile || string.IsNullOrWhiteSpace(user.avatar_path)) &&
                !string.IsNullOrWhiteSpace(user.qq_avatar_url) &&
                user.qq_avatar_url.Length <= 255)
            {
                user.avatar_path = user.qq_avatar_url;
            }
        }

        private QQProfile CreateDevProfile(QQDevLoginDto loginDto)
        {
            var openId = _contentSecurity.NormalizeOptionalText(loginDto.open_id, "QQ OpenId", 64, filterSensitiveWords: false)
                ?? "dev_qq_forever_love";
            var nickname = _contentSecurity.NormalizeOptionalText(loginDto.nickname, "QQ昵称", 100)
                ?? "QQ测试用户";
            var avatarUrl = NormalizeExternalUrl(loginDto.avatar_url, "QQ头像地址");
            return new QQProfile(openId, null, nickname, avatarUrl);
        }

        private string BuildAuthorizationUrl(string state)
        {
            return $"{AuthorizeEndpoint}?{BuildQuery(new Dictionary<string, string>
            {
                ["response_type"] = "code",
                ["client_id"] = GetRequiredConfig("QQ:ClientId"),
                ["redirect_uri"] = GetRequiredConfig("QQ:RedirectUri"),
                ["state"] = state,
                ["scope"] = "get_user_info"
            })}";
        }

        private void ConsumeState(string state, string expectedMode)
        {
            var normalizedState = _contentSecurity.NormalizeRequiredText(state, "state", 120, filterSensitiveWords: false);
            var cacheKey = GetStateCacheKey(normalizedState);

            if (!_memoryCache.TryGetValue<string>(cacheKey, out var storedMode))
                throw new UnauthorizedAccessException("QQ登录状态已失效，请重新发起登录");

            _memoryCache.Remove(cacheKey);
            if (!string.Equals(storedMode, expectedMode, StringComparison.Ordinal))
                throw new UnauthorizedAccessException("QQ登录状态与当前操作不匹配");
        }

        private async Task<string> GenerateUniqueUsernameAsync(string openId)
        {
            var suffix = Regex.Replace(openId.ToLowerInvariant(), "[^a-z0-9]", string.Empty);
            if (suffix.Length > 12)
                suffix = suffix[^12..];
            if (string.IsNullOrWhiteSpace(suffix))
                suffix = Guid.NewGuid().ToString("N")[..12];

            var baseUsername = $"qq_{suffix}";
            var username = baseUsername;
            var counter = 1;
            while (await _context.users.AnyAsync(u => u.username == username))
            {
                username = $"{baseUsername}_{counter}";
                counter++;
            }

            return username.Length <= 50 ? username : username[..50];
        }

        private string NormalizeNickname(string value)
        {
            return _contentSecurity.NormalizeOptionalText(value, "QQ昵称", 100) ?? "QQ用户";
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

        private static string? NormalizeExternalUrl(string? value, string fieldName)
        {
            var normalized = value?.Trim();
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            if (normalized.Length > 500)
                throw new InvalidOperationException($"{fieldName}不能超过500个字符");

            if (!Uri.TryCreate(normalized, UriKind.Absolute, out var uri) ||
                (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
            {
                throw new InvalidOperationException($"{fieldName}不是有效的图片地址");
            }

            return normalized;
        }

        private bool IsConfigured()
        {
            return !string.IsNullOrWhiteSpace(_configuration["QQ:ClientId"]) &&
                   !string.IsNullOrWhiteSpace(_configuration["QQ:ClientSecret"]) &&
                   !string.IsNullOrWhiteSpace(_configuration["QQ:RedirectUri"]);
        }

        private bool IsMockLoginEnabled()
        {
            return _configuration.GetValue<bool>("QQ:AllowMockLogin");
        }

        private void EnsureMockLoginEnabled()
        {
            if (!IsMockLoginEnabled())
                throw new UnauthorizedAccessException("当前环境未启用 QQ 测试登录");
        }

        private string GetRequiredConfig(string key)
        {
            var value = _configuration[key];
            return string.IsNullOrWhiteSpace(value)
                ? throw new InvalidOperationException($"{key} 未配置")
                : value;
        }

        private static string NormalizeMode(string mode)
        {
            var normalized = string.IsNullOrWhiteSpace(mode) ? "login" : mode.Trim().ToLowerInvariant();
            return normalized is "login" or "bind"
                ? normalized
                : throw new ArgumentException("QQ登录模式只能是 login 或 bind");
        }

        private static string GenerateState()
        {
            return Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        }

        private static string GetStateCacheKey(string state)
        {
            return $"qq-oauth-state:{state}";
        }

        private static string BuildQuery(IReadOnlyDictionary<string, string> values)
        {
            return string.Join("&", values.Select(item =>
                $"{Uri.EscapeDataString(item.Key)}={Uri.EscapeDataString(item.Value)}"));
        }

        private static Dictionary<string, string> ParseQueryPayload(string payload)
        {
            return payload.Split('&', StringSplitOptions.RemoveEmptyEntries)
                .Select(part => part.Split('=', 2))
                .Where(parts => parts.Length == 2)
                .ToDictionary(
                    parts => Uri.UnescapeDataString(parts[0]),
                    parts => Uri.UnescapeDataString(parts[1]),
                    StringComparer.OrdinalIgnoreCase);
        }

        private static JsonElement ParseQQJsonCallback(string payload)
        {
            var start = payload.IndexOf('{');
            var end = payload.LastIndexOf('}');
            if (start < 0 || end <= start)
                throw new InvalidOperationException("QQ openid 响应格式错误");

            using var document = JsonDocument.Parse(payload[start..(end + 1)]);
            return document.RootElement.Clone();
        }

        private static string GetRequiredJsonString(JsonElement element, string propertyName, string errorMessage)
        {
            return GetOptionalJsonString(element, propertyName) ?? throw new InvalidOperationException(errorMessage);
        }

        private static string? GetOptionalJsonString(JsonElement element, string propertyName)
        {
            if (!element.TryGetProperty(propertyName, out var property))
                return null;

            return property.ValueKind == JsonValueKind.String ? property.GetString() : property.ToString();
        }

        private sealed record QQProfile(string OpenId, string? UnionId, string Nickname, string? AvatarUrl);
    }
}
