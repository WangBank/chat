using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using VideoCallAPI.Data;
using VideoCallAPI.Hubs;
using VideoCallAPI.Services;
using VideoCallAPI.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

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
builder.Services.AddScoped<ICallService, CallService>();
builder.Services.AddScoped<IContactService, ContactService>();
builder.Services.AddScoped<IJwtService, JwtService>();

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
        policy.WithOrigins("http://localhost:3000", "https://localhost:3000") // Flutter web 地址
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// 配置SignalR Hub
app.MapHub<VideoCallHub>("/videocallhub").RequireCors("SignalRCors");

// 数据库迁移和种子数据
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<VideoCallDbContext>();
    try
    {
        // 确保数据库已创建
        context.Database.EnsureCreated();
        
        // 添加测试数据（如果没有用户）
        if (!context.Users.Any())
        {
            var testUsers = new List<User>
            {
                new User
                {
                    Username = "testuser1",
                    Email = "test1@example.com",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
                    CreatedAt = DateTime.UtcNow,
                    IsOnline = false
                },
                new User
                {
                    Username = "testuser2",
                    Email = "test2@example.com",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
                    CreatedAt = DateTime.UtcNow,
                    IsOnline = false
                }
            };
            
            context.Users.AddRange(testUsers);
            context.SaveChanges();
            
            var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
            logger.LogInformation("测试用户已创建: testuser1, testuser2 (密码: password123)");
        }
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "初始化数据库时发生错误");
    }
}

app.Run();
