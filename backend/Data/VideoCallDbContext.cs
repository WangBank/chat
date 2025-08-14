using Microsoft.EntityFrameworkCore;
using VideoCallAPI.Models;

namespace VideoCallAPI.Data
{
    public class VideoCallDbContext : DbContext
    {
        public VideoCallDbContext(DbContextOptions<VideoCallDbContext> options) : base(options)
        {
        }

        public DbSet<User> users { get; set; }
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
                entity.HasIndex(e => e.username).IsUnique();
                entity.HasIndex(e => e.email).IsUnique();
            });

            // Contact 表配置
            modelBuilder.Entity<Contact>(entity =>
            {
                entity.HasOne(d => d.User)
                    .WithMany(p => p.Contacts)
                    .HasForeignKey(d => d.user_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.contact_user)
                    .WithMany(p => p.ContactedBy)
                    .HasForeignKey(d => d.contact_user_id)
                    .OnDelete(DeleteBehavior.Restrict);

                // 确保同一用户不能重复添加同一联系人
                entity.HasIndex(e => new { e.user_id, e.contact_user_id }).IsUnique();
            });

            // CallHistory 表配置
            modelBuilder.Entity<CallHistory>(entity =>
            {
                entity.HasOne(d => d.Caller)
                    .WithMany(p => p.InitiatedCalls)
                    .HasForeignKey(d => d.caller_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.receiver)
                    .WithMany(p => p.ReceivedCalls)
                    .HasForeignKey(d => d.receiver_id)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // Room 表配置
            modelBuilder.Entity<Room>(entity =>
            {
                entity.HasIndex(e => e.room_code).IsUnique();
                
                entity.HasOne(d => d.creator)
                    .WithMany()
                    .HasForeignKey(d => d.created_by)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // RoomParticipant 表配置
            modelBuilder.Entity<RoomParticipant>(entity =>
            {
                entity.HasOne(d => d.Room)
                    .WithMany(p => p.participants)
                    .HasForeignKey(d => d.room_id)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.user_id)
                    .OnDelete(DeleteBehavior.Restrict);

                // 确保同一用户在同一房间内只有一条活跃记录
                entity.HasIndex(e => new { e.room_id, e.user_id, e.is_active });
            });

            // 枚举配置
            modelBuilder.Entity<CallHistory>()
                .Property(e => e.call_type)
                .HasConversion<int>();

            modelBuilder.Entity<CallHistory>()
                .Property(e => e.status)
                .HasConversion<int>();

            // ChatMessage 表配置
            modelBuilder.Entity<ChatMessage>(entity =>
            {
                entity.HasOne(d => d.sender)
                    .WithMany(p => p.SentMessages)
                    .HasForeignKey(d => d.sender_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.receiver)
                    .WithMany(p => p.ReceivedMessages)
                    .HasForeignKey(d => d.receiver_id)
                    .OnDelete(DeleteBehavior.Restrict);

                // 为消息查询创建索引
                entity.HasIndex(e => new { e.sender_id, e.receiver_id, e.timestamp });
                entity.HasIndex(e => new { e.receiver_id, e.sender_id, e.timestamp });
            });

            // 枚举配置
            modelBuilder.Entity<ChatMessage>()
                .Property(e => e.type)
                .HasConversion<int>();
        }
    }
}
