#!/bin/bash

# 从现有的meme-project目录初始化统一项目
# Initialize unified project from existing meme-project directory

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在正确的目录
if [ ! -f "README.md" ] || [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the meme-generator-unified root directory"
    exit 1
fi

# 检查源目录是否存在
SOURCE_DIR="../meme-project"
if [ ! -d "$SOURCE_DIR" ]; then
    print_error "Source directory $SOURCE_DIR not found"
    print_error "Please ensure the meme-project directory exists in the parent directory"
    exit 1
fi

print_status "Initializing from existing meme-project..."

# 创建必要的目录
print_status "Creating directory structure..."
mkdir -p core contrib emoji data config logs

# 复制核心meme-generator代码
if [ -d "$SOURCE_DIR/meme-generator-main" ]; then
    print_status "Copying meme-generator core..."
    cp -r "$SOURCE_DIR/meme-generator-main/"* core/
    print_success "Core meme-generator copied"
else
    print_warning "meme-generator-main not found in source directory"
fi

# 复制contrib表情包
if [ -d "$SOURCE_DIR/meme-generator-contrib-main" ]; then
    print_status "Copying meme-generator-contrib..."
    cp -r "$SOURCE_DIR/meme-generator-contrib-main/"* contrib/
    print_success "Contrib memes copied"
else
    print_warning "meme-generator-contrib-main not found in source directory"
fi

# 复制emoji表情包
if [ -d "$SOURCE_DIR/meme_emoji-main" ]; then
    print_status "Copying meme_emoji..."
    cp -r "$SOURCE_DIR/meme_emoji-main/"* emoji/
    print_success "Emoji memes copied"
else
    print_warning "meme_emoji-main not found in source directory"
fi

# 创建配置文件
print_status "Creating configuration files..."

# 创建基础配置文件
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

print_success "Configuration file created at config/config.toml"

# 检查Python环境
print_status "Checking Python environment..."
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    PYTHON_CMD=python
else
    print_error "Python is not installed. Please install Python 3.9+ first."
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
print_status "Found Python $PYTHON_VERSION"

# 检查Python版本
if $PYTHON_CMD -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)"; then
    print_success "Python version is compatible"
else
    print_error "Python 3.9+ is required. Current version: $PYTHON_VERSION"
    exit 1
fi

# 安装依赖
read -p "Do you want to install Python dependencies now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Installing Python dependencies..."
    $PYTHON_CMD -m pip install --upgrade pip
    $PYTHON_CMD -m pip install -r requirements.txt
    print_success "Dependencies installed"
fi

# 测试导入
print_status "Testing meme_generator import..."
cd core
if $PYTHON_CMD -c "
import sys
sys.path.insert(0, '.')
try:
    import meme_generator
    print('✅ meme_generator imported successfully')
    print(f'Available memes: {len(meme_generator.get_memes())}')
except Exception as e:
    print(f'❌ Failed to import meme_generator: {e}')
    sys.exit(1)
"; then
    print_success "Core functionality test passed"
else
    print_error "Core functionality test failed"
fi
cd ..

# 创建启动脚本
print_status "Creating startup script..."
cat > scripts/start-dev.sh << 'EOF'
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
python -m meme_generator.cli --host 127.0.0.1 --port 2233
EOF

chmod +x scripts/start-dev.sh
print_success "Development startup script created"

# Git初始化建议
print_status "Git repository setup..."
if [ ! -d ".git" ]; then
    print_warning "This is not a Git repository yet."
    read -p "Do you want to initialize a Git repository? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        git add .
        git commit -m "Initial commit: Meme Generator Unified

- Integrated meme-generator core
- Integrated meme-generator-contrib
- Integrated meme_emoji
- Added Docker support
- Added GitHub Actions workflows
- Added comprehensive documentation"
        print_success "Git repository initialized"
    fi
else
    print_success "Git repository already exists"
fi

# 显示下一步
echo ""
print_success "🎉 Initialization completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit config/config.toml to configure your settings"
echo "2. Copy .env.example to .env and set your API keys (if using Docker)"
echo "3. Start development server: ./scripts/start-dev.sh"
echo "4. Or start with Docker: docker-compose up -d"
echo "5. Visit http://localhost:2233/docs to see the API documentation"
echo ""
echo "📚 Documentation:"
echo "- API Documentation: docs/API.md"
echo "- Deployment Guide: docs/DEPLOYMENT.md"
echo "- Project README: README.md"
echo ""
echo "🔧 Available scripts:"
echo "- ./scripts/setup.sh - Full setup from scratch"
echo "- ./scripts/start-dev.sh - Start development server"
echo "- ./scripts/sync-repos.sh - Sync with upstream repositories"
echo ""
print_success "Happy meme generating! 🎨"