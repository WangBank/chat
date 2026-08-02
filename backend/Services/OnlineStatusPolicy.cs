using VideoCallAPI.Models;

namespace VideoCallAPI.Services
{
    public static class OnlineStatusPolicy
    {
        public static readonly TimeSpan HeartbeatTimeout = TimeSpan.FromMinutes(5);
        public static readonly TimeSpan OfflineGracePeriod = TimeSpan.FromSeconds(75);

        public static DateTime GetOnlineCutoffUtc(DateTime utcNow)
        {
            return utcNow.Subtract(HeartbeatTimeout);
        }

        public static bool IsOnline(User user, DateTime? utcNow = null)
        {
            var now = utcNow ?? DateTime.UtcNow;
            return user.is_online
                && user.last_heartbeat_at.HasValue
                && user.last_heartbeat_at.Value >= GetOnlineCutoffUtc(now);
        }
    }
}
