using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.Security.Claims;
using VideoCallAPI.Models;
using Newtonsoft.Json;

namespace VideoCallAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly IJwtService _jwtService;

        public AuthController(IUserService userService, IJwtService jwtService)
        {
            _userService = userService;
            _jwtService = jwtService;
        }

        [HttpPost("register")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> Register(UserRegistrationDto registrationDto)
        {
            try
            {
                var user = await _userService.RegisterAsync(registrationDto);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "注册成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "注册失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("login")]
        public async Task<ActionResult<ApiResponse<object>>> Login(UserLoginDto loginDto)
        {
            try
            {
                var token = await _userService.LoginAsync(loginDto);
                var userId = _jwtService.GetUserIdFromToken(token);
                
                if (userId == null)
                {
                    return BadRequest(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "登录失败",
                        Errors = new List<string> { "无法从Token中获取用户ID" }
                    });
                }
                
                var user = await _userService.GetUserByIdAsync(userId.Value);

                return Ok(new ApiResponse<object>
                {
                    Success = true,
                    Message = "登录成功",
                    Data = new
                    {
                        Token = token,
                        User = user
                    }
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<object>
                {
                    Success = false,
                    Message = "登录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("change-password")]
        [Authorize]
        public async Task<ActionResult<ApiResponse>> ChangePassword(ChangePasswordDto changePasswordDto)
        {
            try
            {
                var userId = GetUserId();
                var success = await _userService.ChangePasswordAsync(userId, changePasswordDto);
                
                if (success)
                {
                    return Ok(new ApiResponse
                    {
                        Success = true,
                        Message = "密码修改成功"
                    });
                }
                
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "密码修改失败"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "密码修改失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("profile")]
        [Authorize]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> GetProfile()
        {
            try
            {
                var userId = GetUserId();
                var user = await _userService.GetUserByIdAsync(userId);
                
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Data = user
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "获取用户信息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPut("profile")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> UpdateProfile([FromBody] UpdateProfileDto updateProfileDto)
        {
            try
            {
                var userId = GetUserId();
                var result = await _userService.UpdateProfileAsync(userId, updateProfileDto);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "个人资料更新成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "更新失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPost("upload-avatar")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> UploadAvatar(IFormFile avatar)
        {
            try
            {
                if (avatar == null || avatar.Length == 0)
                {
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "请选择头像文件",
                        Errors = new List<string> { "头像文件不能为空" }
                    });
                }

                // 检查文件类型
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif" };
                var fileExtension = Path.GetExtension(avatar.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(fileExtension))
                {
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "不支持的文件格式",
                        Errors = new List<string> { "只支持 JPG, JPEG, PNG, GIF 格式的图片" }
                    });
                }

                // 检查文件大小 (最大 5MB)
                if (avatar.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new ApiResponse<UserResponseDto>
                    {
                        Success = false,
                        Message = "文件太大",
                        Errors = new List<string> { "头像文件不能超过 5MB" }
                    });
                }

                var userId = GetUserId();
                var result = await _userService.UploadAvatarAsync(userId, avatar);
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "头像上传成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "头像上传失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("search-users")]
        public async Task<ActionResult<ApiResponse<UserSearchResultDto>>> SearchUsers([FromQuery] string query = "", [FromQuery] int page = 1, [FromQuery] int page_size = 20)
        {
            try
            {
                var userId = GetUserId();
                var searchDto = new SearchUsersDto
                {
                    query = query,
                    page = page,
                    page_size = page_size
                };
                
                var result = await _userService.SearchUsersAsync(userId, searchDto);
                return Ok(new ApiResponse<UserSearchResultDto>
                {
                    Success = true,
                    Message = "搜索成功",
                    Data = result
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<UserSearchResultDto>
                {
                    Success = false,
                    Message = "搜索失败",
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

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ContactsController : ControllerBase
    {
        private readonly IContactService _contactService;

        public ContactsController(IContactService contactService)
        {
            _contactService = contactService;
        }

        [HttpGet]
        public async Task<ActionResult<ApiResponse<List<ContactResponseDto>>>> GetContacts()
        {
            try
            {
                var userId = GetUserId();
                var contacts = await _contactService.GetContactsAsync(userId);
                System.Console.WriteLine(JsonConvert.SerializeObject(contacts));
                return Ok(new ApiResponse<List<ContactResponseDto>>
                {
                    Success = true,
                    Data = contacts
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
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
        public async Task<ActionResult<ApiResponse<ContactResponseDto>>> AddContact(AddContactDto addContactDto)
        {
            try
            {
                var userId = GetUserId();
                var contact = await _contactService.AddContactAsync(userId, addContactDto);
                
                return Ok(new ApiResponse<ContactResponseDto>
                {
                    Success = true,
                    Message = "添加联系人成功",
                    Data = contact
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<ContactResponseDto>
                {
                    Success = false,
                    Message = "添加联系人失败",
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
                await _contactService.RemoveContactAsync(userId, contactId);
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "联系人删除成功"
                });
            }
            catch (Exception ex)
            {
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
                    Message = "修改备注失败",
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

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ChatController : ControllerBase
    {
        private readonly IChatService _chatService;

        public ChatController(IChatService chatService)
        {
            _chatService = chatService;
        }

        [HttpPost("send")]
        public async Task<ActionResult<ApiResponse<ChatMessageDto>>> SendMessage([FromBody] SendMessageDto sendMessageDto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();
                
                return BadRequest(new ApiResponse<ChatMessageDto>
                {
                    Success = false,
                    Message = "请求参数验证失败",
                    Errors = errors
                });
            }

            try
            {
                var userId = GetUserId();
                var message = await _chatService.SendMessageAsync(userId, sendMessageDto);
                
                return Ok(new ApiResponse<ChatMessageDto>
                {
                    Success = true,
                    Message = "消息发送成功",
                    Data = message
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<ChatMessageDto>
                {
                    Success = false,
                    Message = "发送消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("history/{contactId}")]
        public async Task<ActionResult<ApiResponse<List<ChatMessageDto>>>> GetChatHistory(int contactId)
        {
            try
            {
                var userId = GetUserId();
                var messages = await _chatService.GetChatHistoryAsync(userId, contactId);
                
                return Ok(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = true,
                    Data = messages
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = false,
                    Message = "获取聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpPatch("messages/{messageId}/read")]
        public async Task<ActionResult<ApiResponse>> MarkMessageAsRead(int messageId)
        {
            try
            {
                var userId = GetUserId();
                await _chatService.MarkMessageAsReadAsync(messageId, userId);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "消息已标记为已读"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "标记消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("unread")]
        public async Task<ActionResult<ApiResponse<List<ChatMessageDto>>>> GetUnreadMessages()
        {
            try
            {
                var userId = GetUserId();
                var messages = await _chatService.GetUnreadMessagesAsync(userId);
                
                return Ok(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = true,
                    Data = messages
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ChatMessageDto>>
                {
                    Success = false,
                    Message = "获取未读消息失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpGet("chat-history")]
        public async Task<ActionResult<ApiResponse<List<ChatHistoryDto>>>> GetChatHistory()
        {
            try
            {
                var userId = GetUserId();
                var chatHistory = await _chatService.GetChatHistoryAsync(userId);
                
                return Ok(new ApiResponse<List<ChatHistoryDto>>
                {
                    Success = true,
                    Data = chatHistory
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<ChatHistoryDto>>
                {
                    Success = false,
                    Message = "获取聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        [HttpDelete("chat-history/{contactId}")]
        public async Task<ActionResult<ApiResponse>> DeleteChatHistory(int contactId)
        {
            try
            {
                var userId = GetUserId();
                await _chatService.DeleteChatHistoryAsync(userId, contactId);
                
                return Ok(new ApiResponse
                {
                    Success = true,
                    Message = "删除聊天记录成功"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除聊天记录失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
                throw new UnauthorizedAccessException("无效的用户ID");
            return userId;
        }
    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class CallsController : ControllerBase
    {
        private readonly ICallService _callService;

        public CallsController(ICallService callService)
        {
            _callService = callService;
        }

        [HttpGet("history")]
        public async Task<ActionResult<ApiResponse<List<CallHistory>>>> GetCallHistory()
        {
            try
            {
                var userId = GetUserId();
                var history = await _callService.GetCallHistoryAsync(userId);
                
                return Ok(new ApiResponse<List<CallHistory>>
                {
                    Success = true,
                    Data = history
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<List<CallHistory>>
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
                var room = await _callService.CreateRoomAsync(userId, createRoomDto);
                
                return Ok(new ApiResponse<RoomResponseDto>
                {
                    Success = true,
                    Message = "房间创建成功",
                    Data = room
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse<RoomResponseDto>
                {
                    Success = false,
                    Message = "房间创建失败",
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
