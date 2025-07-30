#!/bin/bash

# Meme Generator Unified Setup Script
# 用于初始化项目和设置Git子模块

set -e

echo "🚀 Setting up Meme Generator Unified..."

# 检查Git是否安装
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install Git first."
    exit 1
fi

# 创建必要的目录
echo "📁 Creating directories..."
mkdir -p data/contrib data/emoji config logs

# 初始化Git子模块（如果还没有初始化）
echo "🔗 Setting up Git submodules..."

# 添加meme-generator作为子模块
if [ ! -d "core/.git" ]; then
    echo "Adding meme-generator as submodule..."
    git submodule add https://github.com/MemeCrafters/meme-generator.git core
else
    echo "Core submodule already exists"
fi

# 添加meme-generator-contrib作为子模块
if [ ! -d "contrib/.git" ]; then
    echo "Adding meme-generator-contrib as submodule..."
    git submodule add https://github.com/MemeCrafters/meme-generator-contrib.git contrib
else
    echo "Contrib submodule already exists"
fi

# 添加meme_emoji作为子模块
if [ ! -d "emoji/.git" ]; then
    echo "Adding meme_emoji as submodule..."
    git submodule add https://github.com/anyliew/meme_emoji.git emoji
else
    echo "Emoji submodule already exists"
fi

# 初始化和更新子模块
echo "🔄 Initializing and updating submodules..."
git submodule init
git submodule update --recursive

# 创建默认配置文件
echo "⚙️ Creating default configuration..."
if [ ! -f "config/config.toml" ]; then
    cat > config/config.toml << 'EOF'
[meme]
load_builtin_memes = true
meme_dirs = ["./contrib/memes", "./emoji/emoji"]
meme_disabled_list = []

[resource]
resource_url = ""
resource_urls = [
    "https://raw.githubusercontent.com/MemeCrafters/meme-generator/",
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/MemeCrafters/meme-generator/",
    "https://cdn.jsdelivr.net/gh/MemeCrafters/meme-generator@",
    "https://fastly.jsdelivr.net/gh/MemeCrafters/meme-generator@",
    "https://raw.gitmirror.com/MemeCrafters/meme-generator/",
]

[gif]
gif_max_size = 10.0
gif_max_frames = 100

[translate]
# 翻译服务类型: "baidu" 或 "openai"
translator_type = "baidu"

# 百度翻译配置
baidu_trans_appid = ""
baidu_trans_apikey = ""

# OpenAI格式翻译配置
openai_api_base = ""
openai_api_key = ""
openai_model = "gpt-3.5-turbo"
openai_timeout = 30

[server]
host = "127.0.0.1"
port = 2233

[log]
log_level = "INFO"
EOF
    echo "✅ Created default config file at config/config.toml"
else
    echo "ℹ️ Config file already exists"
fi

# 创建环境变量示例文件
echo "📝 Creating environment example file..."
cat > .env.example << 'EOF'
# 翻译服务配置
TRANSLATOR_TYPE=baidu
BAIDU_TRANS_APPID=your_appid_here
BAIDU_TRANS_APIKEY=your_apikey_here

# 或者使用OpenAI格式API
# TRANSLATOR_TYPE=openai
# OPENAI_API_BASE=https://api.openai.com/v1
# OPENAI_API_KEY=your_api_key_here
# OPENAI_MODEL=gpt-3.5-turbo

# 服务器配置
HOST=127.0.0.1
PORT=2233
LOG_LEVEL=INFO

# Meme配置
LOAD_BUILTIN_MEMES=true
GIF_MAX_SIZE=10.0
GIF_MAX_FRAMES=100
EOF

# 检查Python环境
echo "🐍 Checking Python environment..."
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    PYTHON_CMD=python
else
    echo "❌ Python is not installed. Please install Python 3.9+ first."
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
echo "Found Python $PYTHON_VERSION"

# 检查Python版本是否满足要求
if $PYTHON_CMD -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)"; then
    echo "✅ Python version is compatible"
else
    echo "❌ Python 3.9+ is required. Current version: $PYTHON_VERSION"
    exit 1
fi

# 安装Python依赖（可选）
read -p "📦 Do you want to install Python dependencies now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing Python dependencies..."
    $PYTHON_CMD -m pip install --upgrade pip
    $PYTHON_CMD -m pip install -r requirements.txt
    echo "✅ Dependencies installed"
fi

# 检查Docker（可选）
if command -v docker &> /dev/null; then
    echo "🐳 Docker is available"
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo "✅ Docker Compose is available"
        echo "You can use 'docker-compose up -d' to start the service"
    else
        echo "⚠️ Docker Compose is not available"
    fi
else
    echo "ℹ️ Docker is not installed (optional for development)"
fi

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit config/config.toml to configure your settings"
echo "2. Copy .env.example to .env and set your API keys"
echo "3. Run with Python: cd core && python -m meme_generator.cli"
echo "4. Or run with Docker: docker-compose up -d"
echo "5. Visit http://localhost:2233/docs to see the API documentation"
echo ""
echo "📚 For more information, see README.md"