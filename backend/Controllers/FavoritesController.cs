using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using VideoCallAPI.Models;
using VideoCallAPI.Data;
using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Hubs;
using BCrypt.Net;

namespace VideoCallAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class FavoritesController : ControllerBase
    {
        private static readonly HashSet<string> AllowedFavoriteTypes = new() { "chat", "media", "file", "link", "note" };
        private readonly VideoCallDbContext _context;
        private readonly ILogger<FavoritesController> _logger;
        private readonly IContentSecurityService _contentSecurity;

        public FavoritesController(
            VideoCallDbContext context,
            ILogger<FavoritesController> logger,
            IContentSecurityService contentSecurity)
        {
            _context = context;
            _logger = logger;
            _contentSecurity = contentSecurity;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<FavoriteItemResponseDto>>>> GetFavorites([FromQuery] string? type = null, [FromQuery] string? query = null)
        {
            try
            {
                var userId = GetUserId();
                var favoritesQuery = _context.FavoriteItems
                    .Where(item => item.user_id == userId);

                var normalizedType = _contentSecurity.NormalizeOptionalText(type, "收藏类型", 20, filterSensitiveWords: false)?.ToLower();
                if (!string.IsNullOrWhiteSpace(normalizedType) && normalizedType != "all")
                {
                    favoritesQuery = favoritesQuery.Where(item => item.type == normalizedType);
                }

                if (!string.IsNullOrWhiteSpace(query))
                {
                    var keyword = _contentSecurity
                        .NormalizeRequiredText(query, "搜索内容", 100, filterSensitiveWords: false)
                        .ToLower();
                    favoritesQuery = favoritesQuery.Where(item =>
                        item.content.ToLower().Contains(keyword) ||
                        item.source_name.ToLower().Contains(keyword));
                }

                var favorites = await favoritesQuery
                    .OrderByDescending(item => item.created_at)
                    .Take(500)
                    .ToListAsync();

                return Ok(new ApiResponse<List<FavoriteItemResponseDto>>
                {
                    Success = true,
                    Data = favorites.Select(MapToFavoriteDto).ToList()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取收藏失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<FavoriteItemResponseDto>>
                {
                    Success = false,
                    Message = "获取收藏失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<FavoriteItemResponseDto>>> CreateFavorite(CreateFavoriteItemDto createDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var favoriteType = _contentSecurity
                    .NormalizeRequiredText(createDto.type, "收藏类型", 20, filterSensitiveWords: false)
                    .ToLower();
                if (!AllowedFavoriteTypes.Contains(favoriteType))
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "不支持的收藏类型"
                    });
                }

                var content = _contentSecurity.NormalizeRequiredText(
                    createDto.content,
                    "收藏内容",
                    1000,
                    rejectSensitiveWords: true);
                var sourceName = _contentSecurity.NormalizeOptionalText(
                    createDto.source_name,
                    "来源名称",
                    100,
                    rejectSensitiveWords: true) ?? "我的账号";
                var filePath = _contentSecurity.NormalizeStoredFilePath(createDto.file_path, "文件路径", "/chat-files/");

                var exists = await _context.FavoriteItems.AnyAsync(item =>
                    item.user_id == userId &&
                    item.type == favoriteType &&
                    item.content == content &&
                    item.source_name == sourceName &&
                    item.file_path == filePath);

                if (exists)
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "已经收藏过了"
                    });
                }

                var favorite = new FavoriteItem
                {
                    user_id = userId,
                    content = content,
                    type = favoriteType,
                    source_name = sourceName,
                    file_path = filePath,
                    file_size = createDto.file_size,
                    created_at = DateTime.UtcNow
                };

                _context.FavoriteItems.Add(favorite);
                await _context.SaveChangesAsync();

                return Ok(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = true,
                    Message = "已添加到收藏",
                    Data = MapToFavoriteDto(favorite)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "创建收藏失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "创建收藏失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPut("{favoriteId}")]
        public async Task<ActionResult<ApiResponse<FavoriteItemResponseDto>>> UpdateFavorite(int favoriteId, UpdateFavoriteItemDto updateDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var favorite = await _context.FavoriteItems
                    .FirstOrDefaultAsync(item => item.id == favoriteId && item.user_id == userId);

                if (favorite == null)
                {
                    return NotFound(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "收藏不存在"
                    });
                }

                if (favorite.type != "note")
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "只有笔记收藏可以编辑"
                    });
                }

                var content = _contentSecurity.NormalizeRequiredText(
                    updateDto.content,
                    "收藏内容",
                    1000,
                    rejectSensitiveWords: true);

                var exists = await _context.FavoriteItems.AnyAsync(item =>
                    item.id != favoriteId &&
                    item.user_id == userId &&
                    item.type == favorite.type &&
                    item.content == content &&
                    item.source_name == favorite.source_name &&
                    item.file_path == favorite.file_path);

                if (exists)
                {
                    return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                    {
                        Success = false,
                        Message = "已经收藏过了"
                    });
                }

                favorite.content = content;
                await _context.SaveChangesAsync();

                return Ok(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = true,
                    Message = "笔记已更新",
                    Data = MapToFavoriteDto(favorite)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "更新收藏失败: UserId={UserId}, FavoriteId={FavoriteId}", GetUserId(), favoriteId);
                return BadRequest(new ApiResponse<FavoriteItemResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "更新收藏失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("{favoriteId}")]
        public async Task<ActionResult<ApiResponse>> DeleteFavorite(int favoriteId)
        {
            try
            {
                var userId = GetUserId();
                var favorite = await _context.FavoriteItems
                    .FirstOrDefaultAsync(item => item.id == favoriteId && item.user_id == userId);

                if (favorite == null)
                {
                    return NotFound(new ApiResponse
                    {
                        Success = false,
                        Message = "收藏不存在"
                    });
                }

                _context.FavoriteItems.Remove(favorite);
                await _context.SaveChangesAsync();

                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "收藏已删除"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "删除收藏失败: UserId={UserId}, FavoriteId={FavoriteId}", GetUserId(), favoriteId);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除收藏失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private static FavoriteItemResponseDto MapToFavoriteDto(FavoriteItem favorite)
        {
            return new FavoriteItemResponseDto
            {
                id = favorite.id,
                content = favorite.content,
                type = favorite.type,
                source_name = favorite.source_name,
                file_path = favorite.file_path,
                file_size = favorite.file_size,
                created_at = favorite.created_at
            };
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
                throw new UnauthorizedAccessException("无效的用户ID");
            return userId;
        }
    }
}
