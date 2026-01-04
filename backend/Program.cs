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

var builder = WebApplication.CreateBuilder(args);

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

// 配置SQLite数据库
builder.Services.AddDbContext<VideoCallDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

// 配置JWT认证
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? "VideoCallSecretKey123456789012345678901234567890";
var key = Encoding.ASCII.GetBytes(jwtSecret);

builder.Services.AddAuthentication(x =>
{
    x.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    x.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(x =>
{
    x.RequireHttpsMetadata = false;
    x.SaveToken = true;
    x.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = false,
        ValidateAudience = false,
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
builder.Services.AddSingleton<IWebRTCService, WebRTCService>();

// 配置SignalR
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
});

// 配置CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyHeader()
              .AllowAnyMethod()
              .AllowAnyOrigin();
    });
    
    options.AddPolicy("SignalRCors", policy =>
    {
        // 允许指定主机和域名
        policy.SetIsOriginAllowed(origin =>
        {
            // 允许null origin（移动应用可能发送null或空字符串）
            if (string.IsNullOrEmpty(origin) || origin == "null")
                return true;
            
            try
            {
                var uri = new Uri(origin);
                var host = uri.Host.ToLower();
                
                // 允许localhost（开发环境）
                if (host == "localhost" || host == "127.0.0.1")
                    return true;
                
                // 允许指定IP地址
                if (host == "common.wangbank.top")
                    return true;
                
                // 允许本地网络IP（用于手机访问，如 192.168.x.x, 10.0.x.x）
                if (host.StartsWith("192.168.") || host.StartsWith("10.0.") || host.StartsWith("172.16.") || host.StartsWith("172.17.") || host.StartsWith("172.18.") || host.StartsWith("172.19.") || host.StartsWith("172.20.") || host.StartsWith("172.21.") || host.StartsWith("172.22.") || host.StartsWith("172.23.") || host.StartsWith("172.24.") || host.StartsWith("172.25.") || host.StartsWith("172.26.") || host.StartsWith("172.27.") || host.StartsWith("172.28.") || host.StartsWith("172.29.") || host.StartsWith("172.30.") || host.StartsWith("172.31."))
                    return true;
                
                return false;
            }
            catch
            {
                // 如果解析失败，可能是移动应用的特殊Origin，允许通过
                return true;
            }
        })
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
        policy.SetIsOriginAllowed(origin =>
        {
            // 允许null origin（移动应用可能发送null或空字符串）
            if (string.IsNullOrEmpty(origin) || origin == "null")
                return true;
            
            try
            {
                var uri = new Uri(origin);
                var host = uri.Host.ToLower();
                
                // 允许localhost（开发环境）
                if (host == "localhost" || host == "127.0.0.1")
                    return true;
                
                // 允许指定IP地址和域名
                if (host == "common.wangbank.top")
                    return true;
                
                // 允许本地网络IP（用于手机访问）
                if (host.StartsWith("192.168.") || host.StartsWith("10.0.") || 
                    (host.StartsWith("172.") && host.Split('.').Length == 4))
                    return true;
                
                return false;
            }
            catch
            {
                // 如果解析失败，可能是移动应用的特殊Origin，允许通过
                return true;
            }
        })
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials();
    });
});

var app = builder.Build();

// 初始化数据库和admin账号
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<VideoCallDbContext>();
    context.Database.EnsureCreated();
    
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
}

// Configure the HTTP request pipeline.
// 仅在开发环境启用Swagger，Release模式禁用
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "VideoCall API V1");
        c.RoutePrefix = "swagger";
    });
}

// 仅在生产环境使用 HTTPS 重定向
if (!app.Environment.IsDevelopment())
{
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
    RequestPath = "/avatar"
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// 配置SignalR Hub - 根据环境使用不同的CORS策略
if (app.Environment.IsDevelopment())
{
    app.MapHub<VideoCallHub>("/videocallhub").RequireCors("Development");
}
else
{
    // 生产环境使用Production策略，支持部署后的网站和手机访问
    app.MapHub<VideoCallHub>("/videocallhub").RequireCors("Production");
}

app.Run();
