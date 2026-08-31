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
        public DbSet<FriendRequest> FriendRequests { get; set; }
        public DbSet<ChatGroup> ChatGroups { get; set; }
        public DbSet<ChatGroupMember> ChatGroupMembers { get; set; }
        public DbSet<GroupChatMessage> GroupChatMessages { get; set; }
        public DbSet<FavoriteItem> FavoriteItems { get; set; }
        public DbSet<PasswordResetToken> PasswordResetTokens { get; set; }
        public DbSet<EmailVerificationCode> EmailVerificationCodes { get; set; }
        public DbSet<EmailCodeCaptchaChallenge> EmailCodeCaptchaChallenges { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // User 表配置
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasIndex(e => e.username).IsUnique();
                entity.HasIndex(e => e.email).IsUnique();
                entity.HasIndex(e => e.qq_open_id)
                    .IsUnique()
                    .HasFilter("\"qq_open_id\" IS NOT NULL");
                entity.HasIndex(e => e.qq_union_id)
                    .IsUnique()
                    .HasFilter("\"qq_union_id\" IS NOT NULL");
            });

            // PasswordResetToken 表配置
            modelBuilder.Entity<PasswordResetToken>(entity =>
            {
                entity.HasIndex(e => e.token_hash).IsUnique();
                entity.HasIndex(e => new { e.user_id, e.expires_at });
                entity.HasIndex(e => new { e.is_used, e.expires_at });

                entity.HasOne(d => d.user)
                    .WithMany(p => p.PasswordResetTokens)
                    .HasForeignKey(d => d.user_id)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // 邮箱验证码表配置
            modelBuilder.Entity<EmailVerificationCode>(entity =>
            {
                entity.HasIndex(e => new { e.email, e.purpose, e.expires_at });
                entity.HasIndex(e => new { e.is_used, e.expires_at });
            });

            modelBuilder.Entity<EmailCodeCaptchaChallenge>(entity =>
            {
                entity.HasIndex(e => new { e.is_used, e.expires_at });
                entity.HasIndex(e => new { e.purpose, e.binding_hash, e.created_at });
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

            // FriendRequest 表配置
            modelBuilder.Entity<FriendRequest>(entity =>
            {
                entity.HasOne(d => d.requester)
                    .WithMany(p => p.SentFriendRequests)
                    .HasForeignKey(d => d.requester_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(d => d.receiver)
                    .WithMany(p => p.ReceivedFriendRequests)
                    .HasForeignKey(d => d.receiver_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.Property(e => e.status)
                    .HasConversion<int>();

                entity.HasIndex(e => new { e.requester_id, e.receiver_id }).IsUnique();
                entity.HasIndex(e => new { e.receiver_id, e.status, e.created_at });
                entity.HasIndex(e => new { e.requester_id, e.status, e.created_at });
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
                entity.HasIndex(e => e.reply_to_message_id);
            });

            // 枚举配置
            modelBuilder.Entity<ChatMessage>()
                .Property(e => e.type)
                .HasConversion<int>();

            modelBuilder.Entity<ChatMessage>()
                .Property(e => e.reply_to_type)
                .HasConversion<int?>();

            // ChatGroup 表配置
            modelBuilder.Entity<ChatGroup>(entity =>
            {
                entity.HasOne(d => d.owner)
                    .WithMany(p => p.OwnedChatGroups)
                    .HasForeignKey(d => d.owner_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.owner_id, e.created_at });
            });

            // ChatGroupMember 表配置
            modelBuilder.Entity<ChatGroupMember>(entity =>
            {
                entity.HasOne(d => d.group)
                    .WithMany(p => p.members)
                    .HasForeignKey(d => d.group_id)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.user)
                    .WithMany(p => p.ChatGroupMembers)
                    .HasForeignKey(d => d.user_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.group_id, e.user_id }).IsUnique();
                entity.HasIndex(e => new { e.user_id, e.is_active });
            });

            // GroupChatMessage 表配置
            modelBuilder.Entity<GroupChatMessage>(entity =>
            {
                entity.HasOne(d => d.group)
                    .WithMany(p => p.messages)
                    .HasForeignKey(d => d.group_id)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.sender)
                    .WithMany(p => p.SentGroupMessages)
                    .HasForeignKey(d => d.sender_id)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => new { e.group_id, e.created_at });
                entity.HasIndex(e => e.reply_to_message_id);
            });

            modelBuilder.Entity<GroupChatMessage>()
                .Property(e => e.type)
                .HasConversion<int>();

            modelBuilder.Entity<GroupChatMessage>()
                .Property(e => e.reply_to_type)
                .HasConversion<int?>();

            // FavoriteItem 表配置
            modelBuilder.Entity<FavoriteItem>(entity =>
            {
                entity.HasOne(d => d.user)
                    .WithMany(p => p.FavoriteItems)
                    .HasForeignKey(d => d.user_id)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.user_id, e.created_at });
                entity.HasIndex(e => new { e.user_id, e.type });
            });
        }
    }
}
