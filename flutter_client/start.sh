#!/bin/bash

echo "🚀 启动 Flutter WebRTC 视频通话应用"

# 检查Flutter是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter未安装，请先安装Flutter SDK"
    echo "请访问: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "📦 安装依赖包..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ 依赖安装失败"
    exit 1
fi

echo "🔍 检查Flutter环境..."
flutter doctor

echo ""
echo "📱 可用的设备:"
flutter devices

echo ""
echo "🎯 启动应用..."
echo "请确保后端服务器已在 https://localhost:7000 运行"

# 检查是否有设备连接
DEVICES=$(flutter devices --machine | jq '. | length')
if [ "$DEVICES" -eq 0 ]; then
    echo "❌ 没有找到可用设备"
    echo "请连接设备或启动模拟器"
    exit 1
fi

# 启动应用
flutter run

echo "✅ 应用启动完成"
