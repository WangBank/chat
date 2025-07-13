#!/bin/bash

# Flutter WebRTC 兼容性问题解决方案
echo "=== Flutter WebRTC 兼容性问题解决方案 ==="

echo "问题：flutter_webrtc 插件与新版 Flutter 不兼容，报错找不到 PluginRegistry.Registrar"
echo "原因：flutter_webrtc 0.11.7 使用了已弃用的 Plugin API"
echo ""

echo "解决方案："
echo "1. 升级到兼容的 flutter_webrtc 版本"
echo "2. 或者使用 Agora SDK 作为替代方案"
echo "3. 或者降级 Flutter 版本"
echo ""

echo "步骤 1: 检查 Flutter 安装"
if command -v flutter &> /dev/null; then
    echo "✅ Flutter 已安装"
    flutter --version
else
    echo "❌ Flutter 未安装"
    echo "请先安装 Flutter: https://flutter.dev/docs/get-started/install"
    echo ""
    echo "macOS 安装命令："
    echo "git clone https://github.com/flutter/flutter.git -b stable"
    echo "export PATH=\"\$PATH:`pwd`/flutter/bin\""
    echo "flutter doctor"
fi

echo ""
echo "步骤 2: 修复 pubspec.yaml"
echo "将 flutter_webrtc 版本改为："
echo "  flutter_webrtc: ^0.12.3  # 或更新版本"
echo ""

echo "步骤 3: 清理并重新构建"
echo "cd /Users/wangzhen/codes/ForeverLove/chat/flutter_client"
echo "flutter clean"
echo "flutter pub get"
echo "flutter build apk --debug"
echo ""

echo "步骤 4: 如果仍有问题，使用 Agora 替代方案"
echo "在 pubspec.yaml 中替换："
echo "  # flutter_webrtc: ^0.12.3"
echo "  agora_rtc_engine: ^6.3.2"
echo ""

echo "步骤 5: 或者使用我们创建的占位符服务"
echo "暂时注释 flutter_webrtc，使用 webrtc_service_placeholder.dart"
echo ""

echo "=== 执行修复 ==="

# 检查 Flutter 可用性
if command -v flutter &> /dev/null; then
    echo "✅ Flutter 环境已配置好"
    flutter --version
    echo ""
    
    # 应用修复
    echo "🔧 应用修复..."
    if [ -f "pubspec_fixed.yaml" ]; then
        cp pubspec_fixed.yaml pubspec.yaml
        echo "✅ 已更新 pubspec.yaml"
    fi
    
    # 清理并重新构建
    echo "🧹 清理项目..."
    flutter clean > /dev/null 2>&1
    
    echo "📦 获取依赖..."
    flutter pub get
    
    echo "🔨 构建项目..."
    flutter build apk --debug
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 修复成功！"
        echo "✅ flutter_webrtc 兼容性问题已解决"
        echo "✅ 项目可以正常构建"
        echo ""
        echo "现在可以运行："
        echo "  flutter run --debug"
    else
        echo "❌ 构建失败，请检查错误信息"
    fi
else
    echo "❌ Flutter 未配置，请先运行以下命令："
    echo "source ~/.zshrc"
fi
