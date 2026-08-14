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
    public class ContactsController : ControllerBase
    {
        private readonly IContactService _contactService;
        private readonly ILogger<ContactsController> _logger;

        public ContactsController(IContactService contactService, ILogger<ContactsController> logger)
        {
            _contactService = contactService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<ContactResponseDto>>>> GetContacts()
        {
            try
            {
                var userId = GetUserId();
                var contacts = await _contactService.GetContactsAsync(userId);
                return Ok(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = true,
                    Data = contacts
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取联系人列表失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = false,
                    Message = "获取联系人失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("search")]
        public async Task<ActionResult<ApiResponse<List<ContactResponseDto>>>> SearchContacts([FromQuery] string query)
        {
            try
            {
                var userId = GetUserId();
                var contacts = await _contactService.SearchContactsAsync(userId, query);
                
                return Ok(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = true,
                    Data = contacts
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = false,
                    Message = "搜索联系人失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<FriendRequestResponseDto>>> AddContact(AddContactDto addContactDto)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation(
                    "发送好友申请请求: UserId={UserId}, ContactUsername={ContactUsername}",
                    userId,
                    addContactDto.username);
                var request = await _contactService.CreateFriendRequestAsync(userId, new CreateFriendRequestDto
                {
                    username = addContactDto.username,
                    source = "联系人添加"
                });
                _logger.LogInformation(
                    "好友申请已发送: UserId={UserId}, RequestId={RequestId}",
                    userId,
                    request.id);
                
                return Ok(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = true,
                    Message = request.direction == "incoming"
                        ? "对方已向你发送好友申请，请在好友通知中处理"
                        : "好友申请已发送，等待对方同意",
                    Data = request
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "发送好友申请失败: UserId={UserId}, ContactUsername={ContactUsername}",
                    GetUserId(),
                    addContactDto.username);
                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送好友申请失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("friend-requests")]
        public async Task<ActionResult<ApiResponse<List<FriendRequestResponseDto>>>> GetFriendRequests()
        {
            try
            {
                var userId = GetUserId();
                var requests = await _contactService.GetFriendRequestsAsync(userId);

                return Ok(new ApiResponse<List<FriendRequestResponseDto>>
                {
                    Success = true,
                    Data = requests
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "获取好友申请失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse<List<FriendRequestResponseDto>>
                {
                    Success = false,
                    Message = "获取好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("friend-requests")]
        public async Task<ActionResult<ApiResponse<FriendRequestResponseDto>>> CreateFriendRequest(CreateFriendRequestDto requestDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var request = await _contactService.CreateFriendRequestAsync(userId, requestDto);

                return Ok(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = true,
                    Message = request.direction == "incoming" ? "对方已向你发送好友申请，请在好友通知中处理" : "好友申请已发送",
                    Data = request
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "发送好友申请失败: UserId={UserId}, ContactUsername={ContactUsername}", GetUserId(), requestDto.username);
                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "发送好友申请失败"),
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("friend-requests/{requestId}")]
        public async Task<ActionResult<ApiResponse<FriendRequestResponseDto>>> RespondFriendRequest(int requestId, FriendRequestDecisionDto decisionDto)
        {
            try
            {
                var userId = GetUserId();
                var request = await _contactService.RespondFriendRequestAsync(userId, requestId, decisionDto);

                return Ok(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = true,
                    Message = request.status == "accepted" ? "已同意好友申请" : "已拒绝好友申请",
                    Data = request
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "处理好友申请失败: UserId={UserId}, RequestId={RequestId}", GetUserId(), requestId);
                return BadRequest(new ApiResponse<FriendRequestResponseDto>
                {
                    Success = false,
                    Message = "处理好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("friend-requests/handled")]
        public async Task<ActionResult<ApiResponse>> ClearHandledFriendRequests()
        {
            try
            {
                var userId = GetUserId();
                await _contactService.ClearHandledFriendRequestsAsync(userId);

                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "已清理处理过的好友申请"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "清理好友申请失败: UserId={UserId}", GetUserId());
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "清理好友申请失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("{contactId}")]
        public async Task<ActionResult<ApiResponse>> RemoveContact(int contactId)
        {
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("删除联系人请求: UserId={UserId}, ContactId={ContactId}", userId, contactId);
                await _contactService.RemoveContactAsync(userId, contactId);
                _logger.LogInformation("删除联系人成功: UserId={UserId}, ContactId={ContactId}", userId, contactId);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "联系人删除成功"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "删除联系人失败: UserId={UserId}, ContactId={ContactId}", GetUserId(), contactId);
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("{contactId}/block")]
        public async Task<ActionResult<ApiResponse>> BlockContact(int contactId, [FromBody] bool isBlocked)
        {
            try
            {
                var userId = GetUserId();
                await _contactService.BlockContactAsync(userId, contactId, isBlocked);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = isBlocked ? "联系人已屏蔽" : "联系人已取消屏蔽"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "操作失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("{contactId}/display-name")]
        public async Task<ActionResult<ApiResponse<ContactResponseDto>>> UpdateDisplayName(int contactId, [FromBody] string displayName)
        {
            try
            {
                var userId = GetUserId();
                var contact = await _contactService.UpdateContactDisplayNameAsync(userId, contactId, displayName);
                
                return Ok(new ApiResponse<ContactResponseDto>
                {
                    Success = true,
                    Message = "备注修改成功",
                    Data = contact
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<ContactResponseDto>
                {
                    Success = false,
                    Message = ApiErrorMessage.ForClient(ex, "修改备注失败"),
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
