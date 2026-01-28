# Serilog 日志使用指南

## 已完成的配置

项目已成功集成 Serilog 日志系统，具有以下功能：

### 1. NuGet 包
- ✅ Serilog.AspNetCore
- ✅ Serilog.Sinks.File
- ✅ Serilog.Sinks.Console
- ✅ Serilog.Enrichers.Environment
- ✅ Serilog.Enrichers.Thread

### 2. 日志配置
- 日志文件位置：`logs/videocall-{Date}.log`
- 日志滚动：每天一个新文件
- 保留天数：30天
- 同时输出到控制台和文件

### 3. 日志级别
- 默认：Information
- Microsoft：Warning
- EntityFrameworkCore：Information

## 如何在代码中使用日志

### 在控制器中使用

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace VideoCallAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly IJwtService _jwtService;
        private readonly ILogger<AuthController> _logger; // 添加日志

        public AuthController(
            IUserService userService, 
            IJwtService jwtService,
            ILogger<AuthController> logger) // 注入日志
        {
            _userService = userService;
            _jwtService = jwtService;
            _logger = logger; // 保存日志实例
        }

        [HttpPost("register")]
        public async Task<ActionResult<ApiResponse<UserResponseDto>>> Register(UserRegistrationDto registrationDto)
        {
            try
            {
                _logger.LogInformation("用户注册请求: {Username}", registrationDto.Username);
                
                var user = await _userService.RegisterAsync(registrationDto);
                
                _logger.LogInformation("用户注册成功: {UserId}, {Username}", user.Id, user.Username);
                
                return Ok(new ApiResponse<UserResponseDto>
                {
                    Success = true,
                    Message = "注册成功",
                    Data = user
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用户注册失败: {Username}, 错误: {Message}", 
                    registrationDto.Username, ex.Message);
                    
                return BadRequest(new ApiResponse<UserResponseDto>
                {
                    Success = false,
                    Message = "注册失败",
                    Errors = new List<string> { ex.Message }
                });
            }
        }
    }
}
```

### 在服务中使用

```csharp
public class UserService : IUserService
{
    private readonly VideoCallDbContext _context;
    private readonly ILogger<UserService> _logger;

    public UserService(VideoCallDbContext context, ILogger<UserService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<UserResponseDto> RegisterAsync(UserRegistrationDto dto)
    {
        _logger.LogDebug("开始注册用户: {Username}", dto.Username);

        // 检查用户是否存在
        var existingUser = await _context.users
            .FirstOrDefaultAsync(u => u.username == dto.Username || u.email == dto.Email);

        if (existingUser != null)
        {
            _logger.LogWarning("注册失败，用户已存在: {Username}", dto.Username);
            throw new Exception("用户名或邮箱已存在");
        }

        // ... 其他代码

        _logger.LogInformation("用户注册成功: {UserId}", user.user_id);
        return userDto;
    }
}
```

### 在 SignalR Hub 中使用

```csharp
public class VideoCallHub : Hub
{
    private readonly IWebRTCService _webRtcService;
    private readonly ILogger<VideoCallHub> _logger;

    public VideoCallHub(IWebRTCService webRtcService, ILogger<VideoCallHub> logger)
    {
        _webRtcService = webRtcService;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        _logger.LogInformation("用户连接到 SignalR Hub: {UserId}, ConnectionId: {ConnectionId}", 
            userId, Context.ConnectionId);
            
        await base.OnConnectedAsync();
    }

    public async Task JoinCall(string callId)
    {
        try
        {
            _logger.LogInformation("用户加入通话: CallId={CallId}, UserId={UserId}", 
                callId, Context.UserIdentifier);
                
            await Groups.AddToGroupAsync(Context.ConnectionId, callId);
            // ... 其他代码
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "加入通话失败: CallId={CallId}, UserId={UserId}", 
                callId, Context.UserIdentifier);
            throw;
        }
    }
}
```

## 日志级别说明

- **LogTrace**: 最详细的信息，仅用于开发调试
- **LogDebug**: 调试信息，用于开发时跟踪流程
- **LogInformation**: 一般信息，记录正常的业务流程
- **LogWarning**: 警告信息，表示可能的问题
- **LogError**: 错误信息，记录异常和错误
- **LogCritical**: 严重错误，需要立即处理的问题

## 日志文件示例

```
2026-01-06 10:30:15.123 [INF] [VideoCallAPI.Controllers.AuthController] 用户注册请求: admin
2026-01-06 10:30:15.456 [INF] [VideoCallAPI.Services.UserService] 开始注册用户: admin
2026-01-06 10:30:15.789 [INF] [VideoCallAPI.Services.UserService] 用户注册成功: 123
2026-01-06 10:30:16.012 [INF] [VideoCallAPI.Controllers.AuthController] 用户注册成功: 123, admin
```

## 查看日志

```bash
# 查看最新日志
tail -f logs/videocall-20260106.log

# 查看错误日志
grep "ERR" logs/videocall-*.log

# 查看特定用户的操作
grep "Username=admin" logs/videocall-*.log
```

## 建议

1. **在所有异常处理中使用 LogError**：记录完整的异常堆栈
2. **记录关键业务操作**：用户登录、注册、通话开始/结束等
3. **使用结构化日志**：使用占位符 `{PropertyName}` 而不是字符串拼接
4. **避免记录敏感信息**：密码、token 等不应记录到日志中
5. **在生产环境调整日志级别**：减少 Debug 级别的日志输出

## 配置调整

如需调整日志配置，请编辑 `appsettings.json` 或 `appsettings.Development.json` 中的 `Serilog` 部分。
