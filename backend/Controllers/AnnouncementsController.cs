using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Data;
using VideoCallAPI.Hubs;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;

namespace VideoCallAPI.Controllers;

[ApiController]
[Authorize]
[Route("api/announcements")]
public sealed class AnnouncementsController(VideoCallDbContext db, IConfiguration config,
    IHubContext<VideoCallHub> hub, ILogger<AnnouncementsController> logger) : ControllerBase
{
    public sealed class PublishRequest
    {
        [Required, MaxLength(120)] public required string Title { get; set; }
        [Required, MaxLength(4000)] public required string Body { get; set; }
    }

    private int? UserId => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery, Range(1, 40000000)] int page = 1,
        [FromQuery, Range(1, 50)] int pageSize = 20, CancellationToken cancellationToken = default)
    {
        if (UserId is not int userId || !await db.users.AnyAsync(u => u.id == userId, cancellationToken))
            return Unauthorized();

        var itemsQuery = db.Announcements.Select(a => new
        {
            a.id, a.title, a.body, a.published_at,
            is_read = db.AnnouncementReads.Any(r => r.announcement_id == a.id && r.user_id == userId)
        });
        var counts = await itemsQuery.GroupBy(a => 1)
            .Select(g => new { total = g.Count(), unread = g.Count(a => !a.is_read) })
            .SingleOrDefaultAsync(cancellationToken);
        var items = await itemsQuery.OrderByDescending(a => a.id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return Ok(new { success = true, data = new { items, total = counts?.total ?? 0, unread_count = counts?.unread ?? 0 } });
    }

    [HttpPost("/api/admin/announcements")]
    public async Task<IActionResult> Publish(PublishRequest request, CancellationToken cancellationToken)
    {
        if (UserId is not int userId) return Unauthorized();
        if (!await AdminIdentityPolicy.IsAdminUserAsync(userId, db, config, cancellationToken))
            return Forbid();
        var announcement = new Announcement
        {
            title = request.Title.Trim(),
            body = request.Body.Trim(),
            published_at = DateTime.UtcNow,
            published_by = userId
        };
        db.Announcements.Add(announcement);
        await db.SaveChangesAsync(cancellationToken);
        await NotifyAsync(hub.Clients.All, "AnnouncementPublished", announcement.id);
        return Ok(new { success = true, data = new { announcement.id, announcement.title, announcement.body, announcement.published_at, is_read = false } });
    }

    [HttpPut("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id, CancellationToken cancellationToken)
    {
        if (UserId is not int userId || !await db.users.AnyAsync(u => u.id == userId, cancellationToken))
            return Unauthorized();
        if (!await db.Announcements.AnyAsync(a => a.id == id, cancellationToken)) return NotFound();
        var added = await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO announcement_reads (user_id, announcement_id)
            VALUES ({userId}, {id}) ON CONFLICT DO NOTHING
            """, cancellationToken);
        if (added > 0) await NotifyAsync(hub.Clients.User(userId.ToString(CultureInfo.InvariantCulture)), "AnnouncementRead", id);
        return Ok(new ApiResponse { Success = true });
    }

    private async Task NotifyAsync(IClientProxy clients, string eventName, int id)
    {
        // Publication/read state is durable. A broadcast failure must not invite a duplicate publish.
        try
        {
            await clients.SendAsync(eventName, new { id });
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "实时公告通知发送失败 {Event} {AnnouncementId}", eventName, id);
        }
    }
}
