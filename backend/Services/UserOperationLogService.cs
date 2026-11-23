using System.Security.Claims;
using VideoCallAPI.Data;
using VideoCallAPI.Models;
using VideoCallAPI.Models.DTOs;

namespace VideoCallAPI.Services;

public sealed record OperationActor(int Id, string? Username)
{
    public static OperationActor? FromClaims(ClaimsPrincipal? principal)
    {
        if (principal?.Identity?.IsAuthenticated != true ||
            !int.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id))
            return null;

        return new(id, principal.FindFirstValue(ClaimTypes.Name));
    }

    public static void SignedIn(HttpContext context, UserResponseDto user) =>
        context.Items[typeof(OperationActor)] = new OperationActor(user.id, user.username);
}

public sealed class UserOperationLogService(
    IServiceScopeFactory scopeFactory,
    ILogger<UserOperationLogService> logger)
{
    public async Task RecordAsync(OperationActor? actor, string operation, string source,
        bool success, int? statusCode = null)
    {
        try
        {
            // The business DbContext may still contain uncommitted changes after a failed operation.
            await using var scope = scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<VideoCallDbContext>();
            db.UserOperationLogs.Add(new UserOperationLog
            {
                UserId = actor?.Id,
                Username = actor?.Username,
                Operation = operation,
                Source = source,
                Success = success,
                StatusCode = statusCode,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "保存用户操作日志失败：{Operation}", operation);
        }
    }
}
