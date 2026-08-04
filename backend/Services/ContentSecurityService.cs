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
            "傻B", "傻b", "nmsl", "死全家", "滚蛋", "垃圾",
            "赌博", "博彩", "六合彩", "赌球", "代开发票", "诈骗",
            "洗钱", "套现", "代刷", "刷单", "外挂", "黑产",
            "毒品", "冰毒", "海洛因", "摇头丸", "枪支", "买枪", "炸药",
            "色情", "黄色网站", "裸聊", "约炮", "卖淫", "嫖娼", "成人视频"
        };

        private static readonly string[] DefaultIgnoredSensitiveWords =
        {
            "QQ", "qq", "网络", "招聘", "兼职", "客服", "淘宝", "网购", "代理", "全职",
            "有意者", "到货", "本店"
        };

        private static readonly char[] SensitiveWordDelimiters = { '\r', '\n', ',', '，' };

        private static readonly Regex InvisibleCharacterPattern = new(
            "[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F\\u200B-\\u200F\\u202A-\\u202E\\u2060\\uFEFF]",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private static readonly Regex SensitiveWordSeparatorPattern = new(
            "[\\s_\\-.·•、，,。!！?？~～*#@]+",
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

        private readonly IReadOnlyList<string> _sensitiveWords;

        public ContentSecurityService(
            IConfiguration configuration,
            IWebHostEnvironment environment,
            ILogger<ContentSecurityService> logger)
        {
            var configuredWords = configuration
                .GetSection("ContentSecurity:SensitiveWords")
                .GetChildren()
                .Select(item => item.Value)
                .Where(word => !string.IsNullOrWhiteSpace(word))
                .Select(word => word!.Trim());

            var ignoredWords = DefaultIgnoredSensitiveWords
                .Concat(configuration
                    .GetSection("ContentSecurity:IgnoredSensitiveWords")
                    .GetChildren()
                    .Select(item => item.Value)
                    .Where(word => !string.IsNullOrWhiteSpace(word))
                    .Select(word => word!.Trim()))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            _sensitiveWords = DefaultSensitiveWords
                .Concat(configuredWords)
                .Concat(LoadDictionaryWords(configuration, environment, logger))
                .Select(NormalizeSensitiveWord)
                .Where(word => word != null && !ignoredWords.Contains(word))
                .Select(word => word!)
                .Where(word => !string.IsNullOrWhiteSpace(word))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(word => word.Length)
                .ToArray();

            logger.LogInformation("敏感词库已加载: {SensitiveWordCount} 条", _sensitiveWords.Count);
        }

        public string NormalizeRequiredText(
            string? value,
            string fieldName,
            int maxLength,
            bool filterSensitiveWords = true,
            bool rejectSensitiveWords = false)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                throw new ArgumentException($"{fieldName}不能为空");

            EnsureMaxLength(normalized, fieldName, maxLength);
            EnsureNoAttackPayload(normalized, fieldName);
            if (rejectSensitiveWords)
                EnsureNoSensitiveWords(normalized, fieldName);

            return filterSensitiveWords ? FilterSensitiveWords(normalized) : normalized;
        }

        public string? NormalizeOptionalText(
            string? value,
            string fieldName,
            int maxLength,
            bool filterSensitiveWords = true,
            bool rejectSensitiveWords = false)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            EnsureMaxLength(normalized, fieldName, maxLength);
            EnsureNoAttackPayload(normalized, fieldName);
            if (rejectSensitiveWords)
                EnsureNoSensitiveWords(normalized, fieldName);

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

        public void EnsureNoSensitiveWords(string? value, string fieldName)
        {
            var normalized = NormalizeText(value);
            if (string.IsNullOrWhiteSpace(normalized))
                return;

            if (ContainsSensitiveWords(normalized))
                throw new InvalidOperationException($"{fieldName}包含敏感词");
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

        private static IEnumerable<string> LoadDictionaryWords(
            IConfiguration configuration,
            IWebHostEnvironment environment,
            ILogger logger)
        {
            foreach (var directory in GetDictionaryDirectories(configuration, environment))
            {
                if (!Directory.Exists(directory))
                    continue;

                IEnumerable<string> files;
                try
                {
                    files = Directory.EnumerateFiles(directory, "*.txt", SearchOption.AllDirectories).ToList();
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "敏感词目录读取失败: {Directory}", directory);
                    continue;
                }

                foreach (var filePath in files)
                {
                    if (IsMetadataFile(filePath))
                        continue;

                    foreach (var word in LoadDictionaryFile(filePath, logger))
                    {
                        yield return word;
                    }
                }
            }
        }

        private static IEnumerable<string> GetDictionaryDirectories(IConfiguration configuration, IWebHostEnvironment environment)
        {
            var configuredPath = NormalizeText(configuration["ContentSecurity:SensitiveWordsPath"]);
            var directories = new List<string>();
            if (!string.IsNullOrWhiteSpace(configuredPath))
            {
                directories.Add(Path.IsPathRooted(configuredPath)
                    ? configuredPath
                    : Path.Combine(environment.ContentRootPath, configuredPath));
            }

            directories.Add(Path.Combine(environment.ContentRootPath, "Data", "sensitive-words"));
            directories.Add(Path.Combine(AppContext.BaseDirectory, "Data", "sensitive-words"));

            return directories
                .Select(Path.GetFullPath)
                .Distinct(StringComparer.OrdinalIgnoreCase);
        }

        private static IEnumerable<string> LoadDictionaryFile(string filePath, ILogger logger)
        {
            string content;
            try
            {
                content = File.ReadAllText(filePath, Encoding.UTF8);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "敏感词文件读取失败: {FilePath}", filePath);
                yield break;
            }

            foreach (var token in content.Split(SensitiveWordDelimiters, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var word = NormalizeSensitiveWord(token);
                if (word != null)
                    yield return word;
            }
        }

        private static bool IsMetadataFile(string filePath)
        {
            var fileName = Path.GetFileName(filePath);
            return fileName.StartsWith("LICENSE", StringComparison.OrdinalIgnoreCase) ||
                   fileName.StartsWith("README", StringComparison.OrdinalIgnoreCase);
        }

        private static string? NormalizeSensitiveWord(string? value)
        {
            var normalized = NormalizeText(value).Trim('\uFEFF');
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            if (normalized.StartsWith("#", StringComparison.Ordinal) ||
                normalized.StartsWith("//", StringComparison.Ordinal))
                return null;

            return normalized;
        }

        private static IEnumerable<string> BuildSensitiveWordCandidates(string value)
        {
            foreach (var candidate in BuildInspectionCandidates(value))
            {
                yield return candidate;

                var compacted = SensitiveWordSeparatorPattern.Replace(candidate, string.Empty);
                if (!string.Equals(compacted, candidate, StringComparison.Ordinal))
                    yield return compacted;
            }
        }

        private bool ContainsSensitiveWords(string value)
        {
            return BuildSensitiveWordCandidates(value)
                .Any(candidate => _sensitiveWords.Any(word =>
                    candidate.Contains(word, StringComparison.OrdinalIgnoreCase)));
        }

        private string FilterSensitiveWords(string value)
        {
            var result = value;
            foreach (var word in _sensitiveWords)
            {
                result = result.Replace(word, "***", StringComparison.OrdinalIgnoreCase);
            }

            return result;
        }
    }
}
