# 自动同步使用指南

## 概述

这个项目现在配置了完全自动化的上游仓库同步系统，可以：

1. **自动检测更新**：每天自动检查三个上游仓库的更新
2. **自动同步代码**：发现更新时自动拉取最新代码
3. **自动构建Docker**：代码更新后自动构建新的Docker镜像

## 工作流程

### 1. 自动同步工作流 (`.github/workflows/auto-sync.yml`)

**触发条件：**
- 每天北京时间08:00自动运行
- 可以手动触发

**工作内容：**
- 检查三个子模块的上游更新：
  - `core`: https://github.com/MemeCrafters/meme-generator.git
  - `contrib`: https://github.com/MemeCrafters/meme-generator-contrib.git
  - `emoji`: https://github.com/anyliew/meme_emoji.git
- 如果有更新，自动提交到你的仓库 (https://github.com/syfantasy/meme-generator)
- 触发Docker构建

### 2. Docker构建工作流 (`.github/workflows/docker-build.yml`)

**触发条件：**
- 代码推送到main分支时
- 自动同步工作流触发时
- 可以手动触发

**工作内容：**
- 构建多架构Docker镜像 (amd64/arm64)
- 推送到GitHub Container Registry
- 自动标记为latest

## 使用方法

### 自动运行
无需任何操作，系统会：
- 每天自动检查更新
- 发现更新时自动同步
- 自动构建新的Docker镜像

### 手动触发
如果需要立即检查更新：
1. 进入GitHub仓库
2. 点击 "Actions" 标签
3. 选择 "Auto Sync Upstream Repositories"
4. 点击 "Run workflow"

### 使用Docker镜像
```bash
# 拉取最新镜像
docker pull ghcr.io/syfantasy/meme-generator:latest

# 运行容器
docker run -d -p 2233:2233 ghcr.io/syfantasy/meme-generator:latest
```

## 监控和日志

### 查看同步状态
1. 进入GitHub仓库的Actions页面
2. 查看"Auto Sync Upstream Repositories"工作流的运行历史
3. 点击具体的运行记录查看详细日志

### 同步结果
- ✅ **有更新**：会看到新的提交，提交信息包含"Auto-sync: Update submodules"
- ℹ️ **无更新**：工作流正常运行但没有新提交

### Docker构建状态
- 在Actions页面查看"Build and Push Docker Image"工作流
- 成功构建后可以在Packages页面看到新的镜像版本

## 故障排除

### 如果同步失败
1. 检查Actions页面的错误日志
2. 常见问题：
   - 网络连接问题：重新运行工作流
   - 权限问题：检查GITHUB_TOKEN权限
   - 合并冲突：可能需要手动解决

### 如果Docker构建失败
1. 检查Dockerfile是否正确
2. 检查依赖是否完整
3. 查看构建日志中的具体错误信息

## 配置说明

### 同步频率
当前设置为每天一次，如需修改：
```yaml
schedule:
  - cron: '0 0 * * *'  # 每天UTC 00:00 (北京时间08:00)
```

### 子模块配置
子模块配置在`.gitmodules`文件中：
```ini
[submodule "core"]
    path = core
    url = https://github.com/MemeCrafters/meme-generator.git
    branch = main

[submodule "contrib"]
    path = contrib
    url = https://github.com/MemeCrafters/meme-generator-contrib.git
    branch = main

[submodule "emoji"]
    path = emoji
    url = https://github.com/anyliew/meme_emoji.git
    branch = main
```

## 优势

1. **完全自动化**：无需人工干预
2. **及时更新**：每天检查，确保不错过重要更新
3. **一体化**：代码同步+Docker构建一条龙服务
4. **可追溯**：所有操作都有详细日志
5. **灵活控制**：支持手动触发和自定义配置

这样你就有了一个完全自动化的三合一meme生成器，既保持了与上游的同步，又保留了你的改进（OpenAI翻译等）。