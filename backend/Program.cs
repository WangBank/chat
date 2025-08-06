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

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
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
builder.Services.AddSignalR();

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
        policy.WithOrigins(
                  "http://172.27.2.52:3000", 
                  "https://172.27.2.52:3000", // Flutter web 地址
                  "http://172.27.2.52:7001",   // Android 模拟器
                  "http://172.27.2.52:7001",  // 本地回环
                  "http://localhost:7001",  // 本地地址
                  "http://172.27.2.52:7001" // 你的电脑IP地址
              )
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
    
// 开发环境下的完全开放策略（仅用于开发）
options.AddPolicy("Development", policy =>
{
    policy.SetIsOriginAllowed(origin => true) // 允许任何来源
          .AllowAnyHeader()
          .AllowAnyMethod()
          .AllowCredentials();
});
});

var app = builder.Build();

// Configure the HTTP request pipeline.
// 启用Swagger（开发和生产环境都启用，方便API文档访问）
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "VideoCall API V1");
    c.RoutePrefix = "swagger";
});

// 仅在生产环境使用 HTTPS 重定向
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// 使用宽松的CORS策略，支持Android模拟器和各种开发环境
app.UseCors("Development");

// 配置静态文件服务
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// 配置SignalR Hub - 在开发环境使用宽松策略
if (app.Environment.IsDevelopment())
{
    app.MapHub<VideoCallHub>("/videocallhub").RequireCors("Development");
}
else
{
    app.MapHub<VideoCallHub>("/videocallhub").RequireCors("SignalRCors");
}

app.Run();