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
        private readonly ILiveKitTokenService _liveKitTokenService;
        private readonly ILogger<CallsController> _logger;

        public CallsController(
            ICallService callService,
            ILiveKitTokenService liveKitTokenService,
            ILogger<CallsController> logger)
        {
            _callService = callService;
            _liveKitTokenService = liveKitTokenService;
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

        [HttpPost("{callId}/livekit-token")]
        public async Task<ActionResult<ApiResponse<LiveKitConnectionDto>>> CreateLiveKitToken(string callId)
        {
            try
            {
                var userId = GetUserId();
                var call = await _callService.GetActiveCallForUserAsync(callId, userId);
                if (call == null)
                {
                    return NotFound(new ApiResponse<LiveKitConnectionDto>
                    {
                        Success = false,
                        Message = "通话不存在或无权加入"
                    });
                }

                if (call.Status != CallStatus.Answered)
                {
                    return Conflict(new ApiResponse<LiveKitConnectionDto>
                    {
                        Success = false,
                        Message = "请等待对方接听后再连接媒体"
                    });
                }

                return Ok(new ApiResponse<LiveKitConnectionDto>
                {
                    Success = true,
                    Data = _liveKitTokenService.CreateConnection(userId, callId)
                });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "LiveKit 令牌签发失败: CallId={CallId}", callId);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new ApiResponse<LiveKitConnectionDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "媒体服务暂不可用")
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "LiveKit 令牌签发异常: CallId={CallId}", callId);
                return BadRequest(new ApiResponse<LiveKitConnectionDto>
                {
                    Success = false,
                    Message = "获取媒体连接失败"
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
