#!/bin/bash

echo "🧠 智能数据库更新脚本"
echo "===================="

# 检查数据库文件是否存在
if [ ! -f "videocall.db" ]; then
    echo "❌ 数据库文件 videocall.db 不存在"
    echo "请先运行应用程序以创建数据库"
    exit 1
fi

# 备份现有数据库
echo "📋 备份现有数据库..."
cp videocall.db videocall_backup_$(date +%Y%m%d_%H%M%S).db

echo "🔍 检查现有表结构..."

# 检查 Contacts 表结构
echo "📊 Contacts 表结构："
sqlite3 videocall.db "PRAGMA table_info(Contacts);"

# 检查是否需要添加 DisplayName 列
DISPLAY_NAME_EXISTS=$(sqlite3 videocall.db "SELECT COUNT(*) FROM pragma_table_info('Contacts') WHERE name='DisplayName';")
if [ "$DISPLAY_NAME_EXISTS" -eq 0 ]; then
    echo "➕ 添加 DisplayName 列..."
    sqlite3 videocall.db "ALTER TABLE Contacts ADD COLUMN DisplayName TEXT;"
    echo "✅ DisplayName 列添加成功"
else
    echo "✅ DisplayName 列已存在"
fi

# 检查是否需要添加 IsBlocked 列
IS_BLOCKED_EXISTS=$(sqlite3 videocall.db "SELECT COUNT(*) FROM pragma_table_info('Contacts') WHERE name='IsBlocked';")
if [ "$IS_BLOCKED_EXISTS" -eq 0 ]; then
    echo "➕ 添加 IsBlocked 列..."
    sqlite3 videocall.db "ALTER TABLE Contacts ADD COLUMN IsBlocked INTEGER DEFAULT 0;"
    echo "✅ IsBlocked 列添加成功"
else
    echo "✅ IsBlocked 列已存在"
fi

# 运行安全的 SQL 脚本
echo ""
echo "🔧 运行数据库更新脚本..."
sqlite3 videocall.db < update_database_safe.sql

if [ $? -eq 0 ]; then
    echo "✅ 数据库更新成功！"
    echo ""
    echo "📊 最终数据库状态："
    echo "表列表："
    sqlite3 videocall.db ".tables"
    echo ""
    echo "各表记录数："
    sqlite3 videocall.db "SELECT 'ChatMessages' as TableName, COUNT(*) as Count FROM ChatMessages UNION ALL SELECT 'Contacts', COUNT(*) FROM Contacts UNION ALL SELECT 'Users', COUNT(*) FROM Users;"
else
    echo "❌ 数据库更新失败"
    echo "请检查 SQL 脚本和数据库文件"
    exit 1
fi

echo ""
echo "🎉 智能数据库更新完成！"
echo "现在可以启动应用程序了" 