-- 初始化数据库脚本
-- 创建完整的聊天应用数据库结构

-- 删除现有表（如果存在）
DROP TABLE IF EXISTS "RoomParticipants";
DROP TABLE IF EXISTS "Rooms";
DROP TABLE IF EXISTS "ChatMessages";
DROP TABLE IF EXISTS "CallHistories";
DROP TABLE IF EXISTS "Contacts";
DROP TABLE IF EXISTS "Users";

-- 创建用户表
CREATE TABLE "Users" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "Username" TEXT NOT NULL UNIQUE,
    "Email" TEXT NOT NULL UNIQUE,
    "PasswordHash" TEXT NOT NULL,
    "Nickname" TEXT,
    "AvatarPath" TEXT,
    "IsOnline" INTEGER NOT NULL DEFAULT 0,
    "LastLoginAt" TEXT,
    "CreatedAt" TEXT NOT NULL,
    "UpdatedAt" TEXT NOT NULL
);

-- 创建联系人表
CREATE TABLE "Contacts" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "UserId" INTEGER NOT NULL,
    "ContactUserId" INTEGER NOT NULL,
    "DisplayName" TEXT,
    "AddedAt" TEXT NOT NULL,
    "IsBlocked" INTEGER NOT NULL DEFAULT 0,
    "LastMessageAt" TEXT,
    "UnreadCount" INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    FOREIGN KEY ("ContactUserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    UNIQUE("UserId", "ContactUserId")
);

-- 创建聊天消息表
CREATE TABLE "ChatMessages" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "SenderId" INTEGER NOT NULL,
    "ReceiverId" INTEGER NOT NULL,
    "Content" TEXT NOT NULL,
    "Type" INTEGER NOT NULL DEFAULT 1,
    "Timestamp" TEXT NOT NULL,
    "IsRead" INTEGER NOT NULL DEFAULT 0,
    "FilePath" TEXT,
    "FileSize" INTEGER,
    "Duration" INTEGER,
    "CreatedAt" TEXT NOT NULL,
    FOREIGN KEY ("SenderId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    FOREIGN KEY ("ReceiverId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

-- 创建通话历史表
CREATE TABLE "CallHistories" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "CallerId" INTEGER NOT NULL,
    "ReceiverId" INTEGER NOT NULL,
    "CallType" INTEGER NOT NULL,
    "Status" INTEGER NOT NULL,
    "StartTime" TEXT NOT NULL,
    "EndTime" TEXT,
    "Duration" INTEGER,
    "EndReason" TEXT,
    "CreatedAt" TEXT NOT NULL,
    FOREIGN KEY ("CallerId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    FOREIGN KEY ("ReceiverId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

-- 创建房间表
CREATE TABLE "Rooms" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "RoomName" TEXT NOT NULL,
    "RoomCode" TEXT NOT NULL UNIQUE,
    "CreatedBy" INTEGER NOT NULL,
    "CreatedAt" TEXT NOT NULL,
    "IsActive" INTEGER NOT NULL DEFAULT 1,
    "MaxParticipants" INTEGER NOT NULL DEFAULT 10,
    FOREIGN KEY ("CreatedBy") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

-- 创建房间参与者表
CREATE TABLE "RoomParticipants" (
    "Id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "RoomId" INTEGER NOT NULL,
    "UserId" INTEGER NOT NULL,
    "JoinedAt" TEXT NOT NULL,
    "LeftAt" TEXT,
    "IsActive" INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY ("RoomId") REFERENCES "Rooms" ("Id") ON DELETE CASCADE,
    FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

-- 创建索引
CREATE INDEX "IX_Users_Username" ON "Users" ("Username");
CREATE INDEX "IX_Users_Email" ON "Users" ("Email");
CREATE INDEX "IX_Contacts_UserId" ON "Contacts" ("UserId");
CREATE INDEX "IX_Contacts_ContactUserId" ON "Contacts" ("ContactUserId");
CREATE INDEX "IX_ChatMessages_SenderId" ON "ChatMessages" ("SenderId");
CREATE INDEX "IX_ChatMessages_ReceiverId" ON "ChatMessages" ("ReceiverId");
CREATE INDEX "IX_ChatMessages_Timestamp" ON "ChatMessages" ("Timestamp");
CREATE INDEX "IX_CallHistories_CallerId" ON "CallHistories" ("CallerId");
CREATE INDEX "IX_CallHistories_ReceiverId" ON "CallHistories" ("ReceiverId");
CREATE INDEX "IX_Rooms_RoomCode" ON "Rooms" ("RoomCode");
CREATE INDEX "IX_RoomParticipants_RoomId" ON "RoomParticipants" ("RoomId");

-- 插入测试数据
INSERT INTO "Users" ("Username", "Email", "PasswordHash", "Nickname", "AvatarPath", "IsOnline", "CreatedAt", "UpdatedAt") VALUES
('testuser', 'test@example.com', '$2a$11$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '测试用户', NULL, 0, datetime('now'), datetime('now')),
('alice', 'alice@example.com', '$2a$11$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '爱丽丝', NULL, 1, datetime('now'), datetime('now')),
('bob', 'bob@example.com', '$2a$11$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '鲍勃', NULL, 0, datetime('now'), datetime('now')),
('charlie', 'charlie@example.com', '$2a$11$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '查理', NULL, 1, datetime('now'), datetime('now')),
('diana', 'diana@example.com', '$2a$11$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '戴安娜', NULL, 0, datetime('now'), datetime('now'));

-- 插入联系人数据
INSERT INTO "Contacts" ("UserId", "ContactUserId", "DisplayName", "AddedAt", "IsBlocked", "LastMessageAt", "UnreadCount") VALUES
(1, 2, '爱丽丝', datetime('now'), 0, datetime('now', '-1 hour'), 2),
(1, 3, '鲍勃', datetime('now'), 0, datetime('now', '-2 hours'), 0),
(1, 4, '查理', datetime('now'), 0, datetime('now', '-30 minutes'), 1),
(2, 1, '测试用户', datetime('now'), 0, datetime('now', '-1 hour'), 0),
(3, 1, '测试用户', datetime('now'), 0, datetime('now', '-2 hours'), 0),
(4, 1, '测试用户', datetime('now'), 0, datetime('now', '-30 minutes'), 0);

-- 插入聊天消息数据
INSERT INTO "ChatMessages" ("SenderId", "ReceiverId", "Content", "Type", "IsRead", "Timestamp", "CreatedAt") VALUES
(2, 1, '你好！', 1, 0, '2025-08-05T07:00:00Z', '2025-08-05T08:00:00Z'),
(1, 2, '你好爱丽丝！', 1, 1, '2025-08-05T07:05:00Z', '2025-08-05T08:05:00Z'),
(2, 1, '今天天气怎么样？', 1, 0, '2025-08-05T07:10:00Z', '2025-08-05T08:10:00Z'),
(3, 1, '鲍勃向你问好', 1, 1, '2025-08-05T06:00:00Z', '2025-08-05T08:00:00Z'),
(1, 3, '你好鲍勃！', 1, 1, '2025-08-05T06:05:00Z', '2025-08-05T08:05:00Z'),
(4, 1, '查理在这里', 1, 0, '2025-08-05T07:30:00Z', '2025-08-05T08:30:00Z');

-- 插入通话记录数据
INSERT INTO "CallHistories" ("CallerId", "ReceiverId", "CallType", "Status", "StartTime", "EndTime", "Duration", "CreatedAt") VALUES
(1, 2, 1, 3, '2025-08-04T08:00:00Z', '2025-08-04T08:05:00Z', 300, '2025-08-05T08:00:00Z'),
(2, 1, 2, 5, '2025-08-03T08:00:00Z', NULL, 0, '2025-08-05T08:00:00Z'),
(1, 3, 1, 4, '2025-08-02T08:00:00Z', '2025-08-02T08:00:10Z', 10, '2025-08-05T08:00:00Z');

-- 更新未读消息计数
UPDATE "Contacts" SET "UnreadCount" = (
    SELECT COUNT(*) FROM "ChatMessages" 
    WHERE "ChatMessages"."ReceiverId" = "Contacts"."UserId" 
    AND "ChatMessages"."SenderId" = "Contacts"."ContactUserId" 
    AND "ChatMessages"."IsRead" = 0
); 