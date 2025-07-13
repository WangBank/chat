#!/bin/bash

echo "📱 启动 ForeverLove Flutter 应用"
echo "================================"

cd /Users/wangzhen/codes/ForeverLove/chat/flutter_client

# 检查Flutter环境
echo "🔍 检查 Flutter 环境..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未找到，正在设置环境..."
    export PATH="/Users/wangzhen/codes/flutter/flutter/bin:$PATH"
    export PUB_HOSTED_URL="https://pub.flutter-io.cn"
    export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
fi

echo "Flutter 版本:"
flutter --version

# 获取依赖
echo ""
echo "📦 获取 Flutter 依赖..."
flutter pub get

# 检查连接的设备
echo ""
echo "📱 检查连接的设备..."
flutter devices

echo ""
echo "🚀 启动选项："
echo "1. 运行在连接的设备上: flutter run"
echo "2. 运行在特定设备: flutter run -d <device_id>"
echo "3. 运行并开启热重载: flutter run --hot"
echo ""
echo "💡 重要提示："
echo "- 确保手机已连接并启用开发者模式"
echo "- 确保后端服务器正在运行 (port 7001)"
echo "- 测试账号: testuser1/password123 或 testuser2/password123"
echo ""

read -p "是否现在启动应用？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 启动 Flutter 应用..."
    flutter run --hot
fi
