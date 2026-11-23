using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VideoCallAPI.Data;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;

namespace VideoCallAPI.Controllers;

[ApiController]
[Authorize]
[Route("api/admin/backups")]
public sealed class DatabaseBackupsController(DatabaseBackupService backups, VideoCallDbContext database,
    IConfiguration configuration, ILogger<DatabaseBackupsController> logger) : ControllerBase
{
    public sealed record RestoreRequest(string ConfirmBackupId);

    [HttpGet]
    public Task<IActionResult> List() => ExecuteAsync(() => Task.FromResult(backups.List()));

    [HttpPost]
    public Task<IActionResult> Create(CancellationToken cancellationToken) =>
        ExecuteAsync(() => backups.CreateAsync(cancellationToken));

    [HttpPost("{id:guid}/restore")]
    public Task<IActionResult> Restore(Guid id, RestoreRequest request, CancellationToken cancellationToken) =>
        ExecuteAsync(() =>
        {
            if (!Guid.TryParse(request.ConfirmBackupId, out var confirmed) || confirmed != id)
                throw new ArgumentException("请确认所选备份后再还原。");
            return backups.RestoreAsync(id, cancellationToken);
        });

    private async Task<IActionResult> ExecuteAsync<T>(Func<Task<T>> operation)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)) return Unauthorized();
        if (!await AdminIdentityPolicy.IsAdminUserAsync(userId, database, configuration, HttpContext.RequestAborted))
            return Forbid();
        try
        {
            return Ok(new ApiResponse<T> { Success = true, Data = await operation() });
        }
        catch (BackupInProgressException exception)
        {
            return Conflict(new ApiResponse { Message = exception.Message });
        }
        catch (IncompatibleBackupException exception)
        {
            return Conflict(new ApiResponse { Message = exception.Message });
        }
        catch (FileNotFoundException)
        {
            return NotFound(new ApiResponse { Message = "找不到所选备份。" });
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new ApiResponse { Message = exception.Message });
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "数据库备份操作失败，用户 {UserId}", userId);
            return StatusCode(500, new ApiResponse { Message = "数据库操作失败，请查看服务端日志并检查备份目录和 PostgreSQL 客户端。" });
        }
    }
}
