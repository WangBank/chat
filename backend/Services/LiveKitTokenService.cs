using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;
using VideoCallAPI.Models.DTOs;

namespace VideoCallAPI.Services
{
    public sealed class LiveKitOptions
    {
        public string Url { get; set; } = string.Empty;
        public string ApiKey { get; set; } = string.Empty;
        public string ApiSecret { get; set; } = string.Empty;
        public string RoomPrefix { get; set; } = "call-";
        public int TokenTtlMinutes { get; set; } = 30;
    }

    public sealed class LiveKitTokenService : ILiveKitTokenService
    {
        private readonly LiveKitOptions _options;

        public LiveKitTokenService(IConfiguration configuration)
        {
            _options = configuration.GetSection("LiveKit").Get<LiveKitOptions>() ?? new LiveKitOptions();
        }

        public LiveKitConnectionDto CreateConnection(int userId, string callId)
        {
            if (!Uri.TryCreate(_options.Url, UriKind.Absolute, out var serverUrl) ||
                (serverUrl.Scheme != Uri.UriSchemeWs && serverUrl.Scheme != Uri.UriSchemeWss))
            {
                throw new InvalidOperationException("LiveKit 服务地址未配置或格式不正确");
            }

            if (string.IsNullOrWhiteSpace(_options.ApiKey) || string.IsNullOrWhiteSpace(_options.ApiSecret))
            {
                throw new InvalidOperationException("LiveKit API 密钥未配置");
            }

            if (Encoding.UTF8.GetByteCount(_options.ApiSecret) < 16)
            {
                throw new InvalidOperationException("LiveKit API 密钥长度至少需要 16 个字节");
            }

            var roomName = $"{_options.RoomPrefix}{callId}";
            var issuedAt = DateTime.UtcNow;
            var expiresAt = issuedAt.AddMinutes(Math.Clamp(_options.TokenTtlMinutes, 1, 60));
            var videoGrant = JsonSerializer.Serialize(new
            {
                roomJoin = true,
                room = roomName,
                canPublish = true,
                canSubscribe = true,
                canPublishData = false
            });
            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, $"user-{userId}"),
                new(JwtRegisteredClaimNames.Name, $"user-{userId}"),
                new("video", videoGrant, JsonClaimValueTypes.Json)
            };
            var credentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.ApiSecret)),
                SecurityAlgorithms.HmacSha256);
            var token = new JwtSecurityToken(
                issuer: _options.ApiKey,
                claims: claims,
                notBefore: issuedAt,
                expires: expiresAt,
                signingCredentials: credentials);

            return new LiveKitConnectionDto
            {
                url = _options.Url.TrimEnd('/'),
                token = new JwtSecurityTokenHandler().WriteToken(token),
                room_name = roomName,
                expires_at = expiresAt
            };
        }
    }
}
