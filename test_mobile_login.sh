#!/bin/bash

echo "📱 ForeverLove 手机应用登录测试"
echo "================================"

SERVER_IP="192.168.0.2"
SERVER_PORT="7001"
API_BASE="http://$SERVER_IP:$SERVER_PORT/api"

echo "🌐 服务器地址: $API_BASE"
echo ""

# 测试服务器连接
echo "🔍 测试服务器连接..."
if curl -s "$API_BASE" > /dev/null 2>&1; then
    echo "✅ 服务器连接成功"
else
    echo "❌ 服务器连接失败"
    echo "请确保:"
    echo "1. 后端服务器正在运行 (dotnet run)"
    echo "2. 手机和电脑在同一WiFi网络"
    echo "3. 防火墙允许端口 $SERVER_PORT"
    exit 1
fi

# 测试登录API
echo ""
echo "🔐 测试登录功能..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser1","password":"password123"}')

echo "登录响应: $LOGIN_RESPONSE"

# 解析响应
if echo "$LOGIN_RESPONSE" | grep -q '"success":true'; then
    echo "✅ 登录测试成功"
    
    # 提取Token
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "🔑 Token: ${TOKEN:0:50}..."
    
    # 测试认证API
    echo ""
    echo "👤 测试用户信息获取..."
    PROFILE_RESPONSE=$(curl -s "$API_BASE/auth/profile" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "用户信息: $PROFILE_RESPONSE"
    
    if echo "$PROFILE_RESPONSE" | grep -q '"success":true'; then
        echo "✅ 用户信息获取成功"
    else
        echo "⚠️ 用户信息获取失败"
    fi
    
else
    echo "❌ 登录测试失败"
    echo "错误响应: $LOGIN_RESPONSE"
fi

echo ""
echo "📋 测试用户账号："
echo "用户名: testuser1"
echo "密码: password123"
echo ""
echo "用户名: testuser2" 
echo "密码: password123"
echo ""
echo "💡 Flutter应用配置："
echo "确保 lib/config/app_config.dart 中的 baseUrl 为:"
echo "return 'http://$SERVER_IP:$SERVER_PORT/api';"
