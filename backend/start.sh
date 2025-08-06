#!/bin/bash

echo "=== Video Call API 启动脚本 (SQLite版本) ==="

# 检查 .NET 8.0 是否安装
if ! command -v dotnet &> /dev/null; then
    echo "错误: .NET 8.0 SDK 未安装"
    echo "请访问 https://dotnet.microsoft.com/download 下载安装"
    exit 1
fi

# 检查 .NET 版本
DOTNET_VERSION=$(dotnet --version | cut -d. -f1)
if [ "$DOTNET_VERSION" -lt "8" ]; then
    echo "错误: 需要 .NET 8.0 或更高版本"
    echo "当前版本: $(dotnet --version)"
    exit 1
fi

echo "✓ .NET 版本检查通过: $(dotnet --version)"

# 进入后端目录
cd "$(dirname "$0")"

# 恢复依赖包
echo "正在恢复 NuGet 包..."
dotnet restore

if [ $? -ne 0 ]; then
    echo "错误: 依赖包恢复失败"
    exit 1
fi

echo "✓ 依赖包恢复成功"

# 构建项目
echo "正在构建项目..."
dotnet build

if [ $? -ne 0 ]; then
    echo "错误: 项目构建失败"
    exit 1
fi

echo "✓ 项目构建成功"

# 检查是否需要创建数据库
if [ ! -f "videocall_dev.db" ]; then
    echo "正在初始化SQLite数据库..."
fi

# 启动项目
echo "正在启动 Video Call API (SQLite版本)..."
echo "API 地址: https://172.27.2.52:7000"
echo "Swagger 文档: https://172.27.2.52:7000/swagger"
echo "SignalR Hub: https://172.27.2.52:7000/videocallhub"
echo "数据库: SQLite (videocall_dev.db)"
echo ""
echo "测试账号:"
echo "  用户名: testuser1, 密码: password123"
echo "  用户名: testuser2, 密码: password123"
echo ""
echo "按 Ctrl+C 停止服务"

dotnet run
