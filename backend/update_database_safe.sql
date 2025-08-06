-- 安全的数据库更新脚本
-- 这个脚本会检查列是否存在，然后才添加

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

-- 3. 为联系人表创建唯一索引（如果不存在）
CREATE UNIQUE INDEX IF NOT EXISTS IX_Contacts_UserContact ON Contacts(UserId, ContactUserId);

-- 4. 验证表结构
SELECT 'ChatMessages table created successfully' as Status;
SELECT COUNT(*) as ChatMessagesCount FROM ChatMessages;
SELECT COUNT(*) as ContactsCount FROM Contacts;
SELECT COUNT(*) as UsersCount FROM Users; 