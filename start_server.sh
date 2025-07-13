#!/bin/bash

echo "🚀 启动 ForeverLove 视频通话应用"
echo "================================"

# 检查网络配置
COMPUTER_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "📱 你的电脑IP地址: $COMPUTER_IP"
echo "📱 手机应该可以通过 http://$COMPUTER_IP:7001 访问服务器"
echo ""

# 检查端口是否被占用
if lsof -i :7001 > /dev/null 2>&1; then
    echo "⚠️  端口 7001 已被占用，正在终止占用进程..."
    # 尝试终止占用端口的进程
    PID=$(lsof -ti :7001)
    if [ ! -z "$PID" ]; then
        kill -9 $PID
        echo "✅ 已终止进程 $PID"
        sleep 2
    fi
fi

# 启动后端服务器
echo "🔧 启动后端服务器..."
cd /Users/wangzhen/codes/ForeverLove/chat/backend

# 检查 dotnet 是否可用
if ! command -v dotnet &> /dev/null; then
    echo "❌ .NET Core 未安装或不在 PATH 中"
    echo "请安装 .NET Core: https://dotnet.microsoft.com/download"
    exit 1
fi

# 启动服务器（后台运行）
echo "启动 ASP.NET Core 服务器..."
dotnet run &
SERVER_PID=$!

echo "✅ 后端服务器已启动 (PID: $SERVER_PID)"
echo "🌐 服务器地址: http://$COMPUTER_IP:7001"
echo ""

# 等待服务器启动
echo "⏳ 等待服务器启动..."
sleep 5

# 测试服务器是否可访问
if curl -s "http://localhost:7001" > /dev/null; then
    echo "✅ 服务器启动成功"
else
    echo "⚠️  服务器可能还在启动中..."
fi

echo ""
echo "📋 接下来的步骤："
echo "1. 确保手机和电脑在同一WiFi网络"
echo "2. 在手机浏览器测试访问: http://$COMPUTER_IP:7001"
echo "3. 启动 Flutter 应用: cd flutter_client && flutter run"
echo ""
echo "💡 提示:"
echo "- 如果无法连接，检查防火墙设置"
echo "- IP地址变化时需要更新配置文件"
echo ""
echo "按 Ctrl+C 停止服务器"

# 等待用户中断
trap "echo '🛑 停止服务器...'; kill $SERVER_PID; exit" INT
wait $SERVER_PID
