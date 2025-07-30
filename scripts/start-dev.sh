#!/bin/bash

# 开发环境启动脚本
set -e

echo "🚀 Starting Meme Generator Unified (Development Mode)..."

# 检查配置文件
if [ ! -f "config/config.toml" ]; then
    echo "❌ Configuration file not found. Please run setup.sh first."
    exit 1
fi

# 设置Python路径
export PYTHONPATH="$(pwd)/core:$(pwd)/contrib:$(pwd)/emoji:$PYTHONPATH"

# 启动服务
cd core
python -m meme_generator.app