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
    public class CallsController : ControllerBase
    {
        private readonly ICallService _callService;
        private readonly ILogger<CallsController> _logger;

        public CallsController(ICallService callService, ILogger<CallsController> logger)
        {
            _callService = callService;
            _logger = logger;
        }

        [HttpGet("history")]
        public async Task<ActionResult<ApiResponse<List<CallResponseDto>>>> GetCallHistory()
        {
            try
            {
                var userId = GetUserId();
                var history = await _callService.GetCallHistoryAsync(userId);
                
                return Ok(new ApiResponse<List<CallResponseDto>>
                {
                    Success = true,
                    Data = history
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取通话记录失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<CallResponseDto>>
                {
                    Success = false,
                    Message = "获取通话记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("rooms")]
        public async Task<ActionResult<ApiResponse<RoomResponseDto>>> CreateRoom(CreateRoomDto createRoomDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("创建房间请求: UserId={UserId}, RoomName={RoomName}", userId, createRoomDto.room_name);
                var room = await _callService.CreateRoomAsync(userId, createRoomDto);
                _logger.LogInformation("房间创建成功: RoomId={RoomId}", room.id);
                
                return Ok(new ApiResponse<RoomResponseDto>
                {
                    Success = true,
                    Message = "房间创建成功",
                    Data = room
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "房间创建失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<RoomResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "房间创建失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim != null && int.TryParse(userIdClaim.Value, out int userId))
            {
                return userId;
            }
            throw new UnauthorizedAccessException("用户未登录");
        }
    }
}
