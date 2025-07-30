# Meme Generator Unified

🚀 **统一的表情包生成器** - 整合三个主要meme生成器仓库的完整解决方案

## 📋 项目概述

本项目整合了以下三个优秀的表情包生成器仓库：

- 🎯 **[meme-generator](https://github.com/MemeCrafters/meme-generator)** - 核心框架（已支持OpenAI like API翻译）
- 🔧 **[meme-generator-contrib](https://github.com/MemeCrafters/meme-generator-contrib)** - 额外表情包仓库
- ✨ **[meme_emoji](https://github.com/anyliew/meme_emoji)** - 热门表情包扩展

## ✨ 特性

- 🎨 **完整表情库** - 整合所有三个仓库的表情包
- 🌐 **多语言翻译** - 支持百度翻译和OpenAI like API翻译
- 🔄 **自动同步** - GitHub Actions自动同步上游仓库更新
- 🐳 **Docker部署** - 一键部署，包含所有依赖
- 📦 **统一管理** - 单一入口管理所有表情包

## 🏗️ 项目结构

```
meme-generator-unified/
├── core/                    # 核心meme-generator代码
├── contrib/                 # meme-generator-contrib表情包
├── emoji/                   # meme_emoji表情包
├── docker/                  # Docker配置文件
├── .github/workflows/       # GitHub Actions工作流
├── scripts/                 # 构建和同步脚本
├── config/                  # 配置文件模板
└── docs/                    # 文档
```

## 🚀 快速开始

### Docker部署（推荐）

```bash
# 克隆仓库
git clone --recursive https://github.com/your-username/meme-generator-unified.git
cd meme-generator-unified

# 构建并启动
docker-compose up -d
```

### 手动部署

```bash
# 克隆仓库（包含子模块）
git clone --recursive https://github.com/your-username/meme-generator-unified.git
cd meme-generator-unified

# 安装依赖
pip install -r requirements.txt

# 启动服务
python -m meme_generator.cli
```

## ⚙️ 配置

### 翻译服务配置

支持两种翻译服务：

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

## 🔄 自动同步

项目通过GitHub Actions自动同步上游仓库：

- 每日检查上游更新
- 自动合并兼容的更新
- 冲突时创建PR进行人工处理
- 自动构建和发布Docker镜像

## 📚 表情包列表

- **核心表情包**: 来自meme-generator主仓库
- **扩展表情包**: 来自meme-generator-contrib
- **热门表情包**: 来自meme_emoji

详细列表请查看各子仓库的文档。

## 🤝 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork本仓库
2. 创建特性分支
3. 提交更改
4. 创建Pull Request

## 📄 许可证

本项目遵循MIT许可证，详见各子仓库的许可证文件。

## 🙏 致谢

感谢以下项目的开发者：
- [MemeCrafters/meme-generator](https://github.com/MemeCrafters/meme-generator)
- [MemeCrafters/meme-generator-contrib](https://github.com/MemeCrafters/meme-generator-contrib)
- [anyliew/meme_emoji](https://github.com/anyliew/meme_emoji)

## 📞 支持

如有问题，请通过以下方式联系：
- 创建Issue
- 加入QQ群：682145034