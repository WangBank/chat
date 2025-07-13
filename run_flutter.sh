#!/bin/bash

echo "🚀 启动 ForeverLove Flutter 应用"
echo "================================"

# 设置 Flutter 环境
export PATH="/Users/wangzhen/codes/flutter/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 进入项目目录
cd /Users/wangzhen/codes/ForeverLove/chat/flutter_client

echo "📍 当前目录: $(pwd)"
echo "📋 检查项目文件:"
ls -la pubspec.yaml

echo ""
echo "🔍 检查 Flutter 版本:"
flutter --version

echo ""
echo "📱 检查连接的设备:"
flutter devices

echo ""
echo "🚀 启动应用..."
flutter run -d emulator-5554 --hot
