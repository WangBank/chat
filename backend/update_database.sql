-- 更新数据库结构以支持聊天功能
-- 运行此脚本前请备份现有数据库

-- 1. 创建聊天消息表
CREATE TABLE IF NOT EXISTS ChatMessages (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    SenderId INTEGER NOT NULL,
    ReceiverId INTEGER NOT NULL,
    Content TEXT NOT NULL,
    Type INTEGER NOT NULL DEFAULT 1, -- 1=Text, 2=Image, 3=Video, 4=Audio, 5=File
    Timestamp TEXT NOT NULL, -- ISO 8601 格式
    IsRead INTEGER NOT NULL DEFAULT 0, -- 0=false, 1=true
    FilePath TEXT,
    FOREIGN KEY (SenderId) REFERENCES Users(Id) ON DELETE RESTRICT,
    FOREIGN KEY (ReceiverId) REFERENCES Users(Id) ON DELETE RESTRICT
);

-- 2. 为聊天消息表创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS IX_ChatMessages_SenderReceiver ON ChatMessages(SenderId, ReceiverId, Timestamp);
CREATE INDEX IF NOT EXISTS IX_ChatMessages_ReceiverSender ON ChatMessages(ReceiverId, SenderId, Timestamp);
CREATE INDEX IF NOT EXISTS IX_ChatMessages_ReceiverUnread ON ChatMessages(ReceiverId, IsRead) WHERE IsRead = 0;

-- 3. 确保联系人表有必要的字段
-- 检查并添加 DisplayName 字段（如果不存在）
PRAGMA table_info(Contacts);
-- 注意：SQLite 不支持 IF NOT EXISTS 在 ALTER TABLE 中
-- 如果列已存在，这些语句会失败，但不会影响其他操作
-- 如果需要，可以手动检查列是否存在

-- 4. 为联系人表创建唯一索引（如果不存在）
CREATE UNIQUE INDEX IF NOT EXISTS IX_Contacts_UserContact ON Contacts(UserId, ContactUserId);

-- 5. 插入一些测试聊天消息（可选）
-- INSERT INTO ChatMessages (SenderId, ReceiverId, Content, Type, Timestamp, IsRead)
-- VALUES 
--     (1, 2, '你好！', 1, datetime('now'), 0),
--     (2, 1, '你好！很高兴认识你', 1, datetime('now'), 0),
--     (1, 2, '今天天气不错', 1, datetime('now'), 0);

-- 6. 验证表结构
SELECT 'ChatMessages table created successfully' as Status;
SELECT COUNT(*) as ChatMessagesCount FROM ChatMessages;
SELECT COUNT(*) as ContactsCount FROM Contacts;
SELECT COUNT(*) as UsersCount FROM Users; 