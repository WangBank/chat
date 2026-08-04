using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Mail;
using System.Text;

namespace VideoCallAPI.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public void EnsureConfigured()
        {
            _ = GetSettings();
        }

        public async Task SendPasswordResetEmailAsync(string toEmail, string displayName, string resetUrl)
        {
            var settings = GetSettings();
            using var message = new MailMessage
            {
                From = new MailAddress(settings.FromEmail, settings.FromName, Encoding.UTF8),
                Subject = "Forever Love 密码重置",
                SubjectEncoding = Encoding.UTF8,
                BodyEncoding = Encoding.UTF8,
                IsBodyHtml = true,
                Body = BuildPasswordResetBody(displayName, resetUrl)
            };
            message.To.Add(new MailAddress(toEmail, displayName, Encoding.UTF8));

            using var smtpClient = new SmtpClient(settings.SmtpHost, settings.SmtpPort)
            {
                DeliveryMethod = SmtpDeliveryMethod.Network,
                EnableSsl = settings.EnableSsl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(settings.Username, settings.Password)
            };

            await smtpClient.SendMailAsync(message);
            _logger.LogInformation("邮件发送成功: To={ToEmail}, Subject={Subject}", toEmail, message.Subject);
        }

        private EmailSettings GetSettings()
        {
            var smtpHost = _configuration["Email:SmtpHost"]?.Trim();
            var username = _configuration["Email:Username"]?.Trim();
            var password = _configuration["Email:Password"]?.Trim();
            var fromEmail = _configuration["Email:FromEmail"]?.Trim();
            var fromName = _configuration["Email:FromName"]?.Trim();
            var smtpPort = _configuration.GetValue<int?>("Email:SmtpPort") ?? 587;
            var enableSsl = _configuration.GetValue<bool?>("Email:EnableSsl") ?? true;

            if (string.IsNullOrWhiteSpace(smtpHost))
                throw new InvalidOperationException("邮件服务尚未配置，请设置 Email:SmtpHost");
            if (smtpPort <= 0)
                throw new InvalidOperationException("邮件服务端口配置不正确，请设置 Email:SmtpPort");
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("邮件服务尚未配置，请设置 Email:Username");
            if (smtpHost.Contains("qq.com", StringComparison.OrdinalIgnoreCase) && !username.Contains('@'))
                throw new InvalidOperationException("QQ邮箱 SMTP 的 Email:Username 必须填写完整 QQ 邮箱地址，例如 your-email@qq.com");
            if (string.IsNullOrWhiteSpace(password))
                throw new InvalidOperationException("邮件服务尚未配置，请设置 Email:Password，QQ邮箱这里填写授权码");

            if (string.IsNullOrWhiteSpace(fromEmail))
                fromEmail = username;
            if (!new EmailAddressAttribute().IsValid(fromEmail))
                throw new InvalidOperationException("邮件发件人配置不正确，请设置 Email:FromEmail");

            return new EmailSettings(
                smtpHost,
                smtpPort,
                enableSsl,
                username,
                password,
                fromEmail,
                string.IsNullOrWhiteSpace(fromName) ? "Forever Love" : fromName);
        }

        private static string BuildPasswordResetBody(string displayName, string resetUrl)
        {
            var safeDisplayName = WebUtility.HtmlEncode(displayName);
            var safeResetUrl = WebUtility.HtmlEncode(resetUrl);

            return $"""
                <div style="font-family:Segoe UI,Arial,sans-serif;line-height:1.6;color:#111820;">
                  <p>{safeDisplayName}，你好：</p>
                  <p>你正在重置 Forever Love 的登录密码。请点击下面的链接设置新密码：</p>
                  <p><a href="{safeResetUrl}" style="color:#0794df;">重置密码</a></p>
                  <p>如果按钮无法打开，请复制下面的链接到浏览器：</p>
                  <p style="word-break:break-all;color:#4b5563;">{safeResetUrl}</p>
                  <p>如果不是你本人操作，可以忽略这封邮件。</p>
                </div>
                """;
        }

        private sealed record EmailSettings(
            string SmtpHost,
            int SmtpPort,
            bool EnableSsl,
            string Username,
            string Password,
            string FromEmail,
            string FromName);
    }
}
