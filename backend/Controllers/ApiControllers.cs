using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using VideoCallAPI.Models.DTOs;
using VideoCallAPI.Services;
using System.Security.Claims;
using VideoCallAPI.Models;

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
                
                var user = await _userService.GetUserAsync(userId.Value);

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
                var user = await _userService.GetUserAsync(userId);
                
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
                    Message = "获取联系人失败",
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
                    Message = "删除联系人成功"
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new ApiResponse
                {
                    Success = false,
                    Message = "删除联系人失败",
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
