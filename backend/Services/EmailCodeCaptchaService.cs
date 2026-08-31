using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Data;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;

namespace VideoCallAPI.Services
{
    /// <summary>
    /// 发送邮箱验证码前的短时、一次性图案校验。
    /// 图案答案仅保存为 HMAC，且挑战绑定用途、输入信息、登录用户和请求指纹。
    /// </summary>
    public sealed class EmailCodeCaptchaService : IEmailCodeCaptchaService
    {
        private static readonly byte[] DevelopmentFallbackKey = RandomNumberGenerator.GetBytes(32);
        private static readonly string[] Symbols =
        {
            "circle", "triangle", "square", "diamond", "star",
            "plus", "moon", "flower", "sparkle"
        };

        private readonly VideoCallDbContext _context;
        private readonly ILogger<EmailCodeCaptchaService> _logger;
        private readonly byte[] _signingKey;

        public EmailCodeCaptchaService(
            VideoCallDbContext context,
            IConfiguration configuration,
            IHostEnvironment environment,
            ILogger<EmailCodeCaptchaService> logger)
        {
            _context = context;
            _logger = logger;

            var configuredKey = configuration["Captcha:SigningKey"];
            if (string.IsNullOrWhiteSpace(configuredKey))
            {
                _signingKey = DevelopmentFallbackKey;
                if (!environment.IsDevelopment())
                {
                    _logger.LogWarning("Captcha:SigningKey 未配置，服务重启会使未完成的图案校验失效");
                }
            }
            else
            {
                _signingKey = Encoding.UTF8.GetBytes(configuredKey);
            }
        }

        public async Task<EmailCodeCaptchaChallengeDto> CreateAsync(
            EmailCodeCaptchaRequestDto requestDto,
            int? userId,
            string clientFingerprint)
        {
            var purpose = ParsePurpose(requestDto.purpose);
            ValidateCreationBinding(purpose, requestDto, userId);

            var now = DateTime.UtcNow;
            await _context.EmailCodeCaptchaChallenges
                .Where(item => item.expires_at < now.AddDays(-1))
                .ExecuteDeleteAsync();

            var tiles = Symbols.OrderBy(_ => RandomNumberGenerator.GetInt32(int.MaxValue)).ToList();
            var targets = tiles
                .OrderBy(_ => RandomNumberGenerator.GetInt32(int.MaxValue))
                .Take(3)
                .ToList();
            var answer = targets.Select(symbol => tiles.IndexOf(symbol)).ToList();
            var id = Guid.NewGuid().ToString("N");

            _context.EmailCodeCaptchaChallenges.Add(new EmailCodeCaptchaChallenge
            {
                id = id,
                purpose = purpose,
                answer_hash = Hash($"answer|{id}|{CanonicalAnswer(answer)}"),
                binding_hash = Hash(BuildBinding(purpose, requestDto.email, requestDto.username, userId, clientFingerprint)),
                expires_at = now.AddMinutes(2),
                created_at = now
            });
            await _context.SaveChangesAsync();

            return new EmailCodeCaptchaChallengeDto
            {
                captcha_id = id,
                target_sequence = targets,
                tiles = tiles.Select((symbol, position) => new EmailCodeCaptchaTileDto
                {
                    position = position,
                    symbol = symbol
                }).ToList(),
                expires_at = now.AddMinutes(2)
            };
        }

        public async Task VerifyAsync(
            EmailCodeCaptchaVerificationDto captchaDto,
            EmailVerificationPurpose purpose,
            string? email,
            string? username,
            int? userId,
            string clientFingerprint)
        {
            if (string.IsNullOrWhiteSpace(captchaDto.captcha_id) || captchaDto.captcha_answer.Count != 3)
                throw new InvalidOperationException("请先完成图案校验");
            if (captchaDto.captcha_answer.Distinct().Count() != 3 || captchaDto.captcha_answer.Any(position => position is < 0 or > 8))
                throw new InvalidOperationException("图案校验不正确，请重新验证");

            var now = DateTime.UtcNow;
            var challenge = await _context.EmailCodeCaptchaChallenges
                .SingleOrDefaultAsync(item => item.id == captchaDto.captcha_id);
            if (challenge == null || challenge.is_used || challenge.expires_at <= now || challenge.purpose != purpose)
                throw new InvalidOperationException("图案校验已失效，请重新验证");

            var expectedBinding = Hash(BuildBinding(purpose, email, username, userId, clientFingerprint));
            if (!FixedTimeEquals(challenge.binding_hash, expectedBinding))
                throw new InvalidOperationException("图案校验与当前操作不匹配，请重新验证");

            var expectedAnswer = Hash($"answer|{challenge.id}|{CanonicalAnswer(captchaDto.captcha_answer)}");
            if (!FixedTimeEquals(challenge.answer_hash, expectedAnswer))
            {
                challenge.failed_attempts++;
                if (challenge.failed_attempts >= 3)
                {
                    challenge.is_used = true;
                    challenge.used_at = now;
                }
                await _context.SaveChangesAsync();
                throw new InvalidOperationException(challenge.is_used
                    ? "图案校验失败次数过多，请重新验证"
                    : "图案校验不正确，请重试");
            }

            // 条件更新确保同一挑战只能被一个并发请求消费。
            var consumed = await _context.EmailCodeCaptchaChallenges
                .Where(item => item.id == challenge.id && !item.is_used && item.expires_at > now)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.is_used, true)
                    .SetProperty(item => item.used_at, now));
            if (consumed != 1)
                throw new InvalidOperationException("图案校验已失效，请重新验证");
        }

        private static EmailVerificationPurpose ParsePurpose(string value)
        {
            return value.Trim().ToLowerInvariant() switch
            {
                "registration" => EmailVerificationPurpose.Registration,
                "change_email" => EmailVerificationPurpose.ChangeEmail,
                "change_password" => EmailVerificationPurpose.ChangePassword,
                _ => throw new ArgumentException("不支持的图案校验用途")
            };
        }

        private static void ValidateCreationBinding(
            EmailVerificationPurpose purpose,
            EmailCodeCaptchaRequestDto requestDto,
            int? userId)
        {
            if (purpose == EmailVerificationPurpose.Registration &&
                (string.IsNullOrWhiteSpace(requestDto.email) || string.IsNullOrWhiteSpace(requestDto.username)))
            {
                throw new ArgumentException("请先填写用户名和邮箱");
            }
            if (purpose == EmailVerificationPurpose.ChangeEmail && string.IsNullOrWhiteSpace(requestDto.email))
                throw new ArgumentException("请先填写新邮箱");
            if (purpose != EmailVerificationPurpose.Registration && !userId.HasValue)
                throw new UnauthorizedAccessException("请先登录");
        }

        private string Hash(string value)
        {
            using var hmac = new HMACSHA256(_signingKey);
            return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(value)));
        }

        private static string BuildBinding(
            EmailVerificationPurpose purpose,
            string? email,
            string? username,
            int? userId,
            string clientFingerprint)
        {
            return string.Join('|',
                purpose,
                NormalizeBindingPart(email),
                NormalizeBindingPart(username),
                userId?.ToString() ?? "anonymous",
                NormalizeBindingPart(clientFingerprint));
        }

        private static string NormalizeBindingPart(string? value) =>
            value?.Trim().ToLowerInvariant() ?? string.Empty;

        private static string CanonicalAnswer(IEnumerable<int> answer) => string.Join('-', answer);

        private static bool FixedTimeEquals(string left, string right)
        {
            try
            {
                return CryptographicOperations.FixedTimeEquals(
                    Convert.FromHexString(left),
                    Convert.FromHexString(right));
            }
            catch (FormatException)
            {
                return false;
            }
        }
    }
}
