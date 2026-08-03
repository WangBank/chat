using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.Text.Json;
using VideoCallAPI.Data;
using VideoCallAPI.Hubs;
using VideoCallAPI.Services;
using VideoCallAPI.Models;
using Microsoft.Extensions.FileProviders;
using BCrypt.Net;
using Serilog;
using Serilog.Events;
using System.Threading.RateLimiting;

// 配置 Serilog
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.EntityFrameworkCore", LogEventLevel.Information)
    .Enrich.FromLogContext()
    .Enrich.WithEnvironmentName()
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .WriteTo.Console()
    .WriteTo.File(
        "logs/videocall-.log",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 30,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{
    Log.Information("启动 VideoCall API 应用程序");

var builder = WebApplication.CreateBuilder(args);

// 使用 Serilog 替换默认日志
builder.Host.UseSerilog();

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
        // 枚举默认序列化为数字，不需要特殊配置
    });

// 添加模型验证
builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.SuppressModelStateInvalidFilter = false;
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// 全局限流，按客户端 IP 控制突发请求，降低暴力尝试和接口刷量风险。
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
    {
        var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetFixedWindowLimiter(
            clientIp,
            _ => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 180,
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                Window = TimeSpan.FromMinutes(1)
            });
    });
});

// 配置PostgreSQL数据库
var databaseConnectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' is not configured.");
builder.Services.AddDbContext<VideoCallDbContext>(options =>
    options.UseNpgsql(databaseConnectionString));

// 配置JWT认证
const string DevelopmentJwtSecret = "VideoCallSecretKey123456789012345678901234567890";
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? DevelopmentJwtSecret;
if (!builder.Environment.IsDevelopment() &&
    string.Equals(jwtSecret, DevelopmentJwtSecret, StringComparison.Ordinal))
{
    throw new InvalidOperationException("Production JWT secret must be configured with a non-default value.");
}
var key = Encoding.ASCII.GetBytes(jwtSecret);
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "VideoCallAPI";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "VideoCallClient";

builder.Services.AddAuthentication(x =>
{
    x.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    x.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(x =>
{
    x.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    x.SaveToken = true;
    x.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ClockSkew = TimeSpan.Zero
    };
    
    // 配置SignalR JWT认证
    x.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/videocallhub"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

// 注册服务
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IContactService, ContactService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<ICallService, CallService>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IContentSecurityService, ContentSecurityService>();
builder.Services.AddMemoryCache();
builder.Services.AddHttpClient<IQQAuthService, QQAuthService>();
builder.Services.AddSingleton<IWebRTCService, WebRTCService>();

// 配置SignalR
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(90);
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
});

// 配置CORS
var productionCorsOrigins = BuildProductionCorsOrigins(builder.Configuration);
builder.Services.AddCors(options =>
{
    options.AddPolicy("SignalRCors", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
            builder.Environment.IsDevelopment() || IsAllowedProductionOrigin(origin, productionCorsOrigins))
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials();
    });
    
    // 开发环境下的完全开放策略（仅用于开发）
    options.AddPolicy("Development", policy =>
    {
        policy.SetIsOriginAllowed(origin => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
    
    // 生产环境的宽松CORS策略（用于部署后的网站和手机访问）
    options.AddPolicy("Production", policy =>
    {
        policy.SetIsOriginAllowed(origin => IsAllowedProductionOrigin(origin, productionCorsOrigins))
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials();
    });
});

var app = builder.Build();
var appVersion = app.Configuration["App:Version"]
    ?? System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString()
    ?? "0.0.0";

// 初始化数据库和admin账号
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<VideoCallDbContext>();
    await context.Database.MigrateAsync();
    
    // 检查admin账号是否存在
    var adminUser = await context.users.FirstOrDefaultAsync(u => u.username == "admin");
    if (adminUser == null)
    {
        // 创建admin账号
        var adminPassword = "$2a$11$Vvta7xJz8GWPPrc8MR0CiuivCNGw4vEWtla9PIcKsXJ1Okkvl/E5W";
        var adminEmail = builder.Configuration["Admin:Email"] ?? "admin@example.com";
        
        adminUser = new User
        {
            username = "admin",
            email = adminEmail,
            password_hash = adminPassword,
            created_at = DateTime.UtcNow,
            updated_at = DateTime.UtcNow,
            is_online = false
        };
        
        context.users.Add(adminUser);
        await context.SaveChangesAsync();
        Console.WriteLine("Admin账号已创建: admin / " + adminPassword);
    }

    if (builder.Configuration.GetValue<bool>("DemoSeed:Enabled"))
    {
        await SeedDemoChatDataAsync(context, builder.Configuration);
    }
}

// Configure the HTTP request pipeline.
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["X-Frame-Options"] = "DENY";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers["X-XSS-Protection"] = "0";
        context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        return Task.CompletedTask;
    });

    await next();
});

// 仅在开发环境启用Swagger，Release模式禁用
var swaggerEnabled = app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled");
if (swaggerEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "VideoCall API V1");
        c.RoutePrefix = "swagger";
    });
}

// 仅在生产环境使用 HTTPS 重定向
var useHttpsRedirection = app.Configuration.GetValue(
    "Security:UseHttpsRedirection",
    !app.Environment.IsDevelopment());
if (useHttpsRedirection)
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

// 根据环境使用不同的CORS策略
if (app.Environment.IsDevelopment())
{
    app.UseCors("Development");
}
else
{
    // 生产环境使用Production策略，支持部署后的网站和手机访问
    app.UseCors("Production");
}

app.UseRateLimiter();

// 配置静态文件服务
app.UseStaticFiles();

// 配置avatar文件夹的静态文件服务
var avatarPath = Path.Combine(Directory.GetCurrentDirectory(), "avatar");
if (!Directory.Exists(avatarPath))
{
    Directory.CreateDirectory(avatarPath);
}
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(avatarPath),
    RequestPath = "/avatar",
    OnPrepareResponse = context =>
    {
        var allowInline = IsSafeInlineMediaType(context.Context.Response.ContentType);
        ApplyStaticFileSecurityHeaders(context.Context.Response, allowInline);
    }
});

// 配置聊天文件夹的静态文件服务
var chatFilesPath = Path.Combine(Directory.GetCurrentDirectory(), "chat-files");
if (!Directory.Exists(chatFilesPath))
{
    Directory.CreateDirectory(chatFilesPath);
}
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(chatFilesPath),
    RequestPath = "/chat-files",
    OnPrepareResponse = context =>
    {
        var allowInline = IsSafeInlineMediaType(context.Context.Response.ContentType);
        ApplyStaticFileSecurityHeaders(context.Context.Response, allowInline);
    }
});

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    version = appVersion,
    environment = app.Environment.EnvironmentName,
    utc_time = DateTimeOffset.UtcNow
}));

app.MapGet("/api/system/version", () => Results.Ok(new
{
    version = appVersion
}));

app.MapControllers();

// 配置SignalR Hub - 根据环境使用不同的CORS策略
if (app.Environment.IsDevelopment())
{
    app.MapHub<VideoCallHub>("/videocallhub").RequireAuthorization().RequireCors("Development");
}
else
{
    // 生产环境使用Production策略，支持部署后的网站和手机访问
    app.MapHub<VideoCallHub>("/videocallhub").RequireAuthorization().RequireCors("Production");
}

app.Run();

static async Task SeedDemoChatDataAsync(VideoCallDbContext context, IConfiguration configuration)
{
    var demoPassword = configuration["DemoSeed:Password"] ?? "Test123456!";
    var passwordHash = BCrypt.Net.BCrypt.HashPassword(demoPassword);
    var now = DateTime.UtcNow;
    var testUsers = new List<User>();

    for (var index = 1; index <= 10; index++)
    {
        var username = $"testuser{index:00}";
        var user = await context.users.FirstOrDefaultAsync(item => item.username == username);
        if (user == null)
        {
            user = new User
            {
                username = username,
                email = $"{username}@example.com",
                password_hash = passwordHash,
                display_name = $"测试用户{index:00}",
                signature = $"QQ 风格测试账号 {index:00}",
                gender = index % 2 == 0 ? "女" : "男",
                birthday = $"199{index % 10}-0{(index % 9) + 1}-15",
                country = "中国",
                province = index % 2 == 0 ? "上海" : "山东",
                region = index % 2 == 0 ? "上海" : "青岛",
                qq_open_id = $"seed_qq_testuser{index:00}",
                qq_nickname = $"QQ测试{index:00}",
                qq_bound_at = now,
                created_at = now,
                updated_at = now
            };
            context.users.Add(user);
        }
        else
        {
            user.display_name ??= $"测试用户{index:00}";
            user.signature ??= $"QQ 风格测试账号 {index:00}";
            user.qq_open_id ??= $"seed_qq_testuser{index:00}";
            user.qq_nickname ??= $"QQ测试{index:00}";
            user.qq_bound_at ??= now;
            user.updated_at = now;
        }

        testUsers.Add(user);
    }

    await context.SaveChangesAsync();

    var owner = testUsers[0];
    foreach (var friend in testUsers.Skip(1))
    {
        await EnsureContactPairAsync(context, owner.id, friend.id, null, now);
    }

    var admin = await context.users.FirstOrDefaultAsync(item => item.username == "admin");
    if (admin != null)
    {
        foreach (var testUser in testUsers)
        {
            await EnsureContactPairAsync(context, admin.id, testUser.id, null, now);
        }
    }

    await context.SaveChangesAsync();

    var group = await context.ChatGroups
        .Include(item => item.members)
        .FirstOrDefaultAsync(item => item.owner_id == owner.id && item.name == "QQ功能测试群");

    if (group == null)
    {
        group = new ChatGroup
        {
            name = "QQ功能测试群",
            category = "测试群聊",
            owner_id = owner.id,
            announcement = "用于验证群聊资料、成员列表、图片文件和表情发送。",
            note = "10个测试用户自动创建的群聊。",
            pinned = true,
            created_at = now,
            updated_at = now
        };
        context.ChatGroups.Add(group);
        await context.SaveChangesAsync();
    }

    await EnsureGroupMemberAsync(context, group.id, owner.id, "owner", now);
    foreach (var member in testUsers.Skip(1))
    {
        await EnsureGroupMemberAsync(context, group.id, member.id, "member", now);
    }

    if (!await context.GroupChatMessages.AnyAsync(item => item.group_id == group.id))
    {
        context.GroupChatMessages.AddRange(
            new GroupChatMessage
            {
                group_id = group.id,
                sender_id = owner.id,
                content = "大家好，这里是 QQ 功能测试群 😀",
                type = MessageType.Text,
                timestamp = now,
                created_at = now
            },
            new GroupChatMessage
            {
                group_id = group.id,
                sender_id = testUsers[1].id,
                content = "已加入群聊，可以测试表情、图片和文件。",
                type = MessageType.Text,
                timestamp = now.AddSeconds(8),
                created_at = now.AddSeconds(8)
            });
    }

    group.updated_at = now;
    await context.SaveChangesAsync();
}

static async Task EnsureContactPairAsync(VideoCallDbContext context, int userId, int contactUserId, string? displayName, DateTime now)
{
    if (!await context.Contacts.AnyAsync(item => item.user_id == userId && item.contact_user_id == contactUserId))
    {
        context.Contacts.Add(new Contact
        {
            user_id = userId,
            contact_user_id = contactUserId,
            display_name = displayName,
            added_at = now
        });
    }

    if (!await context.Contacts.AnyAsync(item => item.user_id == contactUserId && item.contact_user_id == userId))
    {
        context.Contacts.Add(new Contact
        {
            user_id = contactUserId,
            contact_user_id = userId,
            added_at = now
        });
    }
}

static async Task EnsureGroupMemberAsync(VideoCallDbContext context, int groupId, int userId, string role, DateTime now)
{
    var member = await context.ChatGroupMembers
        .FirstOrDefaultAsync(item => item.group_id == groupId && item.user_id == userId);

    if (member == null)
    {
        context.ChatGroupMembers.Add(new ChatGroupMember
        {
            group_id = groupId,
            user_id = userId,
            role = role,
            joined_at = now,
            is_active = true
        });
        return;
    }

    member.role = role;
    member.is_active = true;
}

static HashSet<string> BuildProductionCorsOrigins(IConfiguration configuration)
{
    var origins = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "https://chat.wangbank.top"
    };

    foreach (var item in configuration.GetSection("Cors:AllowedOrigins").GetChildren())
    {
        var normalized = NormalizeCorsOrigin(item.Value);
        if (normalized != null)
            origins.Add(normalized);
    }

    return origins;
}

static bool IsAllowedProductionOrigin(string? origin, HashSet<string> allowedOrigins)
{
    var normalized = NormalizeCorsOrigin(origin);
    return normalized != null && allowedOrigins.Contains(normalized);
}

static string? NormalizeCorsOrigin(string? origin)
{
    if (string.IsNullOrWhiteSpace(origin) ||
        string.Equals(origin, "null", StringComparison.OrdinalIgnoreCase))
    {
        return null;
    }

    if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
        return null;

    if (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps)
        return null;

    return $"{uri.Scheme}://{uri.Authority}";
}

static bool IsSafeInlineMediaType(string? contentType)
{
    if (string.IsNullOrWhiteSpace(contentType))
        return false;

    var normalized = contentType.Split(';', 2)[0].Trim();
    return normalized.StartsWith("image/", StringComparison.OrdinalIgnoreCase) &&
               !string.Equals(normalized, "image/svg+xml", StringComparison.OrdinalIgnoreCase) ||
           normalized.StartsWith("audio/", StringComparison.OrdinalIgnoreCase) ||
           normalized.StartsWith("video/", StringComparison.OrdinalIgnoreCase);
}

static void ApplyStaticFileSecurityHeaders(HttpResponse response, bool allowInline)
{
    response.Headers["X-Content-Type-Options"] = "nosniff";
    response.Headers["Referrer-Policy"] = "no-referrer";

    if (!allowInline)
    {
        response.Headers["Content-Disposition"] = "attachment";
    }
}
}
catch (Exception ex)
{
    if (ex is HostAbortedException)
    {
        throw;
    }

    Log.Fatal(ex, "应用程序启动失败");
    throw;
}
finally
{
    Log.CloseAndFlush();
}
