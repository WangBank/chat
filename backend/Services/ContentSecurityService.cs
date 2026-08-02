using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace VideoCallAPI.Services
{
    public class ContentSecurityService : IContentSecurityService
    {
        private static readonly string[] DefaultSensitiveWords =
        {
            "傻逼", "煞笔", "草泥马", "操你妈", "妈的", "他妈的",
            "赌博", "博彩", "六合彩", "赌球", "代开发票", "诈骗",
            "毒品", "冰毒", "海洛因", "摇头丸", "枪支", "买枪",
            "色情", "黄色网站", "裸聊", "约炮", "卖淫", "嫖娼"
        };

        private static readonly Regex InvisibleCharacterPattern = new(
            "[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F\\u200B-\\u200F\\u202A-\\u202E\\u2060\\uFEFF]",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private static readonly Regex[] AttackPatterns =
        {
            new("<\\s*/?\\s*(script|iframe|object|embed|link|meta|base|form|input|textarea|button)\\b",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\bon[a-z]+\\s*=",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\b(javascript|vbscript)\\s*:",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\bdata\\s*:\\s*text/html",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\b(document\\.cookie|document\\.write|window\\.location|eval\\s*\\(|new\\s+function\\s*\\()",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\b(union\\s+select|select\\s+.+\\s+from\\s+information_schema|drop\\s+table|truncate\\s+table|insert\\s+into|delete\\s+from|update\\s+\\w+\\s+set|or\\s+1\\s*=\\s*1|and\\s+1\\s*=\\s*1|;\\s*(drop|delete|insert|update|alter|create)\\b)",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("(\\.\\./|\\.\\.\\\\|%2e%2e|/etc/passwd|cmd\\.exe|powershell|/bin/(sh|bash))",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
            new("\\$\\{\\s*jndi\\s*:",
                RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)
        };

        private readonly IReadOnlyList<Regex> _sensitiveWordPatterns;

        public ContentSecurityService(IConfiguration configuration)
        {
            var configuredWords = configuration
                .GetSection("ContentSecurity:SensitiveWords")
                .GetChildren()
                .Select(item => item.Value)
                .Where(word => !string.IsNullOrWhiteSpace(word))
                .Select(word => word!.Trim());

            _sensitiveWordPatterns = DefaultSensitiveWords
                .Concat(configuredWords)
                .Where(word => !string.IsNullOrWhiteSpace(word))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(word => word.Length)
                .Select(word => new Regex(
                    Regex.Escape(word),
                    RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
                .ToArray();
        }

        public string NormalizeRequiredText(string? value, string fieldName, int maxLength, bool filterSensitiveWords = true)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                throw new ArgumentException($"{fieldName}不能为空");

            EnsureMaxLength(normalized, fieldName, maxLength);
            EnsureNoAttackPayload(normalized, fieldName);

            return filterSensitiveWords ? FilterSensitiveWords(normalized) : normalized;
        }

        public string? NormalizeOptionalText(string? value, string fieldName, int maxLength, bool filterSensitiveWords = true)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            EnsureMaxLength(normalized, fieldName, maxLength);
            EnsureNoAttackPayload(normalized, fieldName);

            return filterSensitiveWords ? FilterSensitiveWords(normalized) : normalized;
        }

        public string? NormalizeStoredFilePath(string? value, string fieldName, params string[] allowedPrefixes)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            EnsureMaxLength(normalized, fieldName, 255);
            EnsureNoAttackPayload(normalized, fieldName);

            if (normalized.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                normalized.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
                normalized.Contains('\\') ||
                normalized.Contains("..", StringComparison.Ordinal))
            {
                throw new InvalidOperationException($"{fieldName}不是有效的服务器文件路径");
            }

            if (allowedPrefixes.Length > 0 &&
                !allowedPrefixes.Any(prefix => normalized.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
            {
                throw new InvalidOperationException($"{fieldName}不是允许的文件路径");
            }

            return normalized;
        }

        private static string NormalizeText(string? value)
        {
            if (value == null)
                return string.Empty;

            var withoutInvisibleChars = InvisibleCharacterPattern.Replace(value, string.Empty);
            return withoutInvisibleChars.Trim();
        }

        private static void EnsureMaxLength(string value, string fieldName, int maxLength)
        {
            if (value.Length > maxLength)
                throw new InvalidOperationException($"{fieldName}不能超过{maxLength}个字符");
        }

        private static void EnsureNoAttackPayload(string value, string fieldName)
        {
            foreach (var candidate in BuildInspectionCandidates(value))
            {
                if (AttackPatterns.Any(pattern => pattern.IsMatch(candidate)))
                    throw new InvalidOperationException($"{fieldName}包含疑似攻击内容");
            }
        }

        private static IEnumerable<string> BuildInspectionCandidates(string value)
        {
            yield return value;

            var htmlDecoded = WebUtility.HtmlDecode(value);
            if (!string.Equals(htmlDecoded, value, StringComparison.Ordinal))
                yield return htmlDecoded;

            string? urlDecoded = null;
            try
            {
                urlDecoded = Uri.UnescapeDataString(value);
            }
            catch
            {
                // Malformed escape sequences are validated by the raw candidate.
            }

            if (urlDecoded != null && !string.Equals(urlDecoded, value, StringComparison.Ordinal))
                yield return urlDecoded;
        }

        private string FilterSensitiveWords(string value)
        {
            var filtered = new StringBuilder(value);
            var result = filtered.ToString();
            foreach (var pattern in _sensitiveWordPatterns)
            {
                result = pattern.Replace(result, "***");
            }

            return result;
        }
    }
}
