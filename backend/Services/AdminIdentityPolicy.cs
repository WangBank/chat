namespace VideoCallAPI.Services
{
    public static class AdminIdentityPolicy
    {
        public static IReadOnlyList<string> GetAdminEmails(IConfiguration configuration)
        {
            var overrideEmails = configuration["Admin:Email"];
            if (!string.IsNullOrWhiteSpace(overrideEmails))
            {
                return SplitConfiguredEmails(overrideEmails)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
            }

            var configuredEmails = configuration
                .GetSection("Admin:Emails")
                .GetChildren()
                .Select(item => item.Value)
                .Where(email => !string.IsNullOrWhiteSpace(email))
                .SelectMany(SplitConfiguredEmails)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            return configuredEmails;
        }

        private static IEnumerable<string> SplitConfiguredEmails(string? value)
        {
            return (value ?? string.Empty)
                .Split(new[] { ',', ';', '\r', '\n', ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(email => email.Trim().ToLowerInvariant())
                .Where(email => !string.IsNullOrWhiteSpace(email));
        }

        public static bool IsAdminEmail(string? email, IConfiguration configuration)
        {
            return !string.IsNullOrWhiteSpace(email)
                && GetAdminEmails(configuration).Contains(email.Trim(), StringComparer.OrdinalIgnoreCase);
        }
    }
}
