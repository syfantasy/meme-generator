# Meme Generator Unified 设置指南

## 🎯 项目概述

本项目成功整合了三个主要的表情包生成器仓库：

- **meme-generator** - 核心框架（支持OpenAI like API翻译）
- **meme-generator-contrib** - 额外表情包仓库
- **meme_emoji** - 热门表情包扩展

## 📁 项目结构

```
meme-generator-unified/
├── core/                    # meme-generator核心代码
├── contrib/                 # meme-generator-contrib表情包
├── emoji/                   # meme_emoji表情包
├── docker/                  # Docker配置文件
├── .github/workflows/       # GitHub Actions工作流
├── scripts/                 # 构建和同步脚本
├── config/                  # 配置文件
├── docs/                    # 文档
├── data/                    # 数据目录
└── logs/                    # 日志目录
```

## 🚀 快速开始

### 方法1: 使用现有代码初始化

如果你已经有了三个仓库的代码，可以使用初始化脚本：

```bash
# Windows (PowerShell)
cd meme-generator-unified
.\scripts\init-from-existing.sh

# Linux/macOS
cd meme-generator-unified
chmod +x scripts/init-from-existing.sh
./scripts/init-from-existing.sh
```

### 方法2: 从头开始设置

```bash
# 1. 运行设置脚本
chmod +x scripts/setup.sh
./scripts/setup.sh

# 2. 安装Python依赖
pip install -r requirements.txt

# 3. 配置翻译服务（可选）
cp .env.example .env
# 编辑 .env 文件设置API密钥
```

### 方法3: Docker部署

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 文件

# 2. 启动服务
docker-compose up -d

# 3. 访问API文档
# http://localhost:2233/docs
```

## ⚙️ 配置说明

### 翻译服务配置

#### 百度翻译
```toml
[translate]
translator_type = "baidu"
baidu_trans_appid = "your_appid"
baidu_trans_apikey = "your_apikey"
```

#### OpenAI Like API
```toml
[translate]
translator_type = "openai"
openai_api_base = "https://api.openai.com/v1"
openai_api_key = "your_api_key"
openai_model = "gpt-3.5-turbo"
```

### 表情包目录配置

```toml
[meme]
load_builtin_memes = true
meme_dirs = ["./contrib/memes", "./emoji/emoji"]
meme_disabled_list = []
```

## 🔧 开发指南

### 启动开发服务器

```bash
# 方法1: 使用脚本
./scripts/start-dev.sh

# 方法2: 手动启动
export PYTHONPATH="$(pwd)/core:$(pwd)/contrib:$(pwd)/emoji:$PYTHONPATH"
cd core
python -m meme_generator.cli --host 127.0.0.1 --port 2233
```

### 同步上游仓库

```bash
# 手动同步
./scripts/sync-repos.sh

# GitHub Actions会自动同步（每日）
```

### 测试功能

```bash
# 测试导入
cd core
python -c "
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../contrib')
sys.path.insert(0, '../emoji')
import meme_generator
print(f'Available memes: {len(meme_generator.get_memes())}')
"
```

## 📊 统计信息

根据复制结果统计：

- **核心文件**: 3,221 个文件（meme-generator）
- **扩展表情**: 269 个文件（meme-generator-contrib）
- **热门表情**: 639 个文件（meme_emoji）
- **总计**: 4,129 个文件

包含的表情包类型：
- 核心表情包：约150+个
- 扩展表情包：约13个
- 热门表情包：约200+个

## 🔄 自动化功能

### GitHub Actions

1. **同步上游仓库** (`sync-upstream.yml`)
   - 每日自动检查更新
   - 自动合并兼容更新
   - 冲突时创建PR

2. **Docker构建** (`docker-build.yml`)
   - 自动构建Docker镜像
   - 推送到GitHub Container Registry
   - 支持多架构构建

### 特性

- ✅ 完整的表情包库整合
- ✅ 支持OpenAI like API翻译
- ✅ Docker一键部署
- ✅ 自动同步上游更新
- ✅ 完整的API文档
- ✅ 健康检查和监控

## 📚 文档

- [API文档](docs/API.md) - 完整的REST API参考
- [部署指南](docs/DEPLOYMENT.md) - 生产环境部署说明
- [项目README](README.md) - 项目概述和快速开始

## 🐛 故障排除

### 常见问题

1. **依赖缺失**
   ```bash
   pip install -r requirements.txt
   ```

2. **Python路径问题**
   ```bash
   export PYTHONPATH="$(pwd)/core:$(pwd)/contrib:$(pwd)/emoji:$PYTHONPATH"
   ```

3. **端口被占用**
   ```bash
   # 修改配置文件中的端口
   # 或使用环境变量
   export PORT=2234
   ```

4. **权限问题（Linux/macOS）**
   ```bash
   chmod +x scripts/*.sh
   ```

## 🎉 完成状态

✅ 项目结构已创建  
✅ 三个仓库代码已整合  
✅ Docker配置已完成  
✅ GitHub Actions已配置  
✅ 文档已编写完成  
✅ 配置文件已创建  

项目已准备就绪，可以开始使用！

## 📞 支持

如有问题，请：
1. 查看文档
2. 检查日志文件
3. 在GitHub上创建Issue
4. 加入QQ群：682145034