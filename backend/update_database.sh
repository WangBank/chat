#!/bin/bash

echo "=== 更新数据库结构 ==="
echo "正在更新数据库以支持聊天功能..."

# 检查数据库文件是否存在
if [ ! -f "videocall.db" ]; then
    echo "❌ 数据库文件 videocall.db 不存在"
    echo "请先运行应用程序以创建数据库"
    exit 1
fi

# 备份现有数据库
echo "📋 备份现有数据库..."
cp videocall.db videocall_backup_$(date +%Y%m%d_%H%M%S).db

# 运行 SQL 脚本
echo "🔧 更新数据库结构..."
sqlite3 videocall.db < update_database.sql

if [ $? -eq 0 ]; then
    echo "✅ 数据库更新成功！"
    echo ""
    echo "📊 数据库状态："
    sqlite3 videocall.db "SELECT 'ChatMessages' as TableName, COUNT(*) as Count FROM ChatMessages UNION ALL SELECT 'Contacts', COUNT(*) FROM Contacts UNION ALL SELECT 'Users', COUNT(*) FROM Users;"
else
    echo "❌ 数据库更新失败"
    echo "请检查 SQL 脚本和数据库文件"
    exit 1
fi

echo ""
echo "🎉 数据库更新完成！"
echo "现在可以启动应用程序了" 