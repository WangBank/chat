using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace VideoCallAPI.Models;

[Index(nameof(UserId), nameof(Id))]
public sealed class UserOperationLog
{
    public long Id { get; set; }
    public int? UserId { get; set; }
    [MaxLength(100)] public string? Username { get; set; }
    [MaxLength(128)] public required string Operation { get; set; }
    [MaxLength(16)] public required string Source { get; set; }
    public bool Success { get; set; }
    public int? StatusCode { get; set; }
    public DateTime CreatedAt { get; set; }
}
