using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Models;

namespace VideoCallAPI.Data
{
    public class VideoCallDbContext : DbContext
    {
        public VideoCallDbContext(DbContextOptions<VideoCallDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Contact> Contacts { get; set; }
        public DbSet<CallHistory> CallHistories { get; set; }
        public DbSet<Room> Rooms { get; set; }
        public DbSet<RoomParticipant> RoomParticipants { get; set; }
        public DbSet<ChatMessage> ChatMessages { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // User 表配置
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasIndex(e => e.Username).IsUnique();
                entity.HasIndex(e => e.Email).IsUnique();
            });

            // Contact 表配置
            modelBuilder.Entity<Contact>(entity =>
            {
                entity.HasOne(d => d.User)
                    .WithMany(p => p.Contacts)
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.ContactUser)
                    .WithMany(p => p.ContactedBy)
                    .HasForeignKey(d => d.ContactUserId)
                    .OnDelete(DeleteBehavior.Restrict);

                // 确保同一用户不能重复添加同一联系人
                entity.HasIndex(e => new { e.UserId, e.ContactUserId }).IsUnique();
            });

            // CallHistory 表配置
            modelBuilder.Entity<CallHistory>(entity =>
            {
                entity.HasOne(d => d.Caller)
                    .WithMany(p => p.InitiatedCalls)
                    .HasForeignKey(d => d.CallerId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.Receiver)
                    .WithMany(p => p.ReceivedCalls)
                    .HasForeignKey(d => d.ReceiverId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // Room 表配置
            modelBuilder.Entity<Room>(entity =>
            {
                entity.HasIndex(e => e.RoomCode).IsUnique();
                
                entity.HasOne(d => d.Creator)
                    .WithMany()
                    .HasForeignKey(d => d.CreatedBy)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // RoomParticipant 表配置
            modelBuilder.Entity<RoomParticipant>(entity =>
            {
                entity.HasOne(d => d.Room)
                    .WithMany(p => p.Participants)
                    .HasForeignKey(d => d.RoomId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                // 确保同一用户在同一房间内只有一条活跃记录
                entity.HasIndex(e => new { e.RoomId, e.UserId, e.IsActive });
            });

            // 枚举配置
            modelBuilder.Entity<CallHistory>()
                .Property(e => e.CallType)
                .HasConversion<int>();

            modelBuilder.Entity<CallHistory>()
                .Property(e => e.Status)
                .HasConversion<int>();

            // ChatMessage 表配置
            modelBuilder.Entity<ChatMessage>(entity =>
            {
                entity.HasOne(d => d.Sender)
                    .WithMany(p => p.SentMessages)
                    .HasForeignKey(d => d.SenderId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.Receiver)
                    .WithMany(p => p.ReceivedMessages)
                    .HasForeignKey(d => d.ReceiverId)
                    .OnDelete(DeleteBehavior.Restrict);

                // 为消息查询创建索引
                entity.HasIndex(e => new { e.SenderId, e.ReceiverId, e.Timestamp });
                entity.HasIndex(e => new { e.ReceiverId, e.SenderId, e.Timestamp });
            });

            // 枚举配置
            modelBuilder.Entity<ChatMessage>()
                .Property(e => e.Type)
                .HasConversion<int>();
        }
    }
}
