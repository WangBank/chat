using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Data;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;

namespace VideoCallAPI.Controllers;

[Authorize]
[ApiController]
[Route("api/admin/operation-logs")]
public sealed class OperationLogsController(VideoCallDbContext db, IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery, Range(1, int.MaxValue)] int page = 1,
        [FromQuery, Range(1, 100)] int pageSize = 25, [FromQuery] int? userId = null,
        [FromQuery] bool? success = null, CancellationToken cancellationToken = default)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorId))
            return Unauthorized();
        if (!await AdminIdentityPolicy.IsAdminUserAsync(actorId, db, configuration, cancellationToken))
            return Forbid();

        var logs = db.UserOperationLogs.AsNoTracking();
        if (userId.HasValue) logs = logs.Where(l => l.UserId == userId);
        if (success.HasValue) logs = logs.Where(l => l.Success == success);
        var total = await logs.LongCountAsync(cancellationToken);
        var offset = (long)(page - 1) * pageSize;
        var items = offset >= total || offset > int.MaxValue ? [] :
            await logs.OrderByDescending(l => l.Id).Skip((int)offset).Take(pageSize).ToListAsync(cancellationToken);
        return Ok(new ApiResponse<object> { Success = true, Data = new { items, page, pageSize, total } });
    }
}
