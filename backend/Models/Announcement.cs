using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VideoCallAPI.Models;

[Table("announcements")]
public sealed class Announcement
{
    public int id { get; set; }
    [MaxLength(120)] public required string title { get; set; }
    [MaxLength(4000)] public required string body { get; set; }
    public int? published_by { get; set; }
    public DateTime published_at { get; set; }
}

[Table("announcement_reads")]
public sealed class AnnouncementRead
{
    public int user_id { get; set; }
    public int announcement_id { get; set; }
}
