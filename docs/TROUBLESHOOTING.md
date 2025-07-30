# 故障排除指南

本文档帮助解决 Meme Generator Unified 项目中的常见问题。

## 🚨 常见部署问题

### 1. Docker 启动失败

#### 问题：命令行参数错误
```
('命令头部 --host 匹配失败', '--host')
```

**解决方案**：
- ✅ **已修复**：v1.0.3版本已修复此问题
- 确保使用正确的启动命令：`python -m meme_generator.cli run`
- 服务器配置通过配置文件管理，不需要命令行参数

#### 问题：端口被占用
```
Error: [Errno 98] Address already in use
```

**解决方案**：
```bash
# 检查端口占用
netstat -tlnp | grep 2233
# 或者修改端口
docker-compose down
# 编辑 docker-compose.yml 修改端口映射
docker-compose up -d
```

#### 问题：权限问题
```
Permission denied
```

**解决方案**：
```bash
# Linux/macOS
sudo chown -R $USER:$USER meme-generator-unified
chmod +x scripts/*.sh

# Windows
# 以管理员身份运行 PowerShell
```

### 2. 依赖安装问题

#### 问题：Python版本不兼容
```
ModuleNotFoundError: No module named 'arclet'
```

**解决方案**：
```bash
# 检查Python版本（需要3.9+）
python --version

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt

# 如果仍有问题，尝试虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/macOS
# 或 venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

#### 问题：skia-python 安装失败
```
ERROR: Failed building wheel for skia-python
```

**解决方案**：
```bash
# Windows: 安装 Visual C++ 运行时
# 下载: https://aka.ms/vs/17/release/VC_redist.x64.exe

# Linux: 安装构建工具
sudo apt-get update
sudo apt-get install build-essential python3-dev

# macOS: 安装 Xcode 命令行工具
xcode-select --install
```

### 3. 配置问题

#### 问题：翻译服务不工作
```
Translation service error
```

**解决方案**：
```bash
# 检查配置文件
cat config/config.toml

# 百度翻译配置
[translate]
translator_type = "baidu"
baidu_trans_appid = "your_real_appid"
baidu_trans_apikey = "your_real_apikey"

# OpenAI配置
[translate]
translator_type = "openai"
openai_api_base = "https://api.openai.com/v1"
openai_api_key = "your_real_api_key"
```

#### 问题：表情包加载失败
```
No memes found
```

**解决方案**：
```bash
# 检查目录结构
ls -la contrib/memes/
ls -la emoji/emoji/

# 检查Python路径
export PYTHONPATH="$(pwd)/core:$(pwd)/contrib:$(pwd)/emoji:$PYTHONPATH"

# 测试导入
cd core
python -c "import meme_generator; print(len(meme_generator.get_memes()))"
```

## 🐳 Docker 特定问题

### 1. 容器启动问题

#### 问题：健康检查失败
```
Health check failed
```

**解决方案**：
```bash
# 检查容器日志
docker-compose logs meme-generator

# 手动测试健康检查
docker exec -it meme-generator-unified_meme-generator_1 curl -f http://localhost:2233/docs

# 重启服务
docker-compose restart
```

#### 问题：字体警告
```
Fontconfig warning: unknown element "reset-dirs"
```

**解决方案**：
- 这是无害的警告，不影响功能
- 如需消除，可以在Dockerfile中添加字体配置

### 2. 数据持久化问题

#### 问题：配置丢失
```
Configuration reset after restart
```

**解决方案**：
```bash
# 确保挂载了配置目录
# docker-compose.yml 中应有：
volumes:
  - ./config:/app/config
  - ./data:/data
```

## 🌐 网络和API问题

### 1. API访问问题

#### 问题：无法访问API文档
```
Connection refused
```

**解决方案**：
```bash
# 检查服务状态
docker-compose ps

# 检查端口映射
docker-compose port meme-generator 2233

# 测试本地访问
curl http://localhost:2233/docs
```

#### 问题：CORS错误
```
CORS policy blocked
```

**解决方案**：
- 在配置文件中添加CORS设置
- 或使用反向代理（Nginx/Caddy）

### 2. 性能问题

#### 问题：生成速度慢
```
Request timeout
```

**解决方案**：
```bash
# 增加超时时间
# 在配置文件中设置
[server]
timeout = 60

# 或在docker-compose.yml中设置
environment:
  - TIMEOUT=60
```

#### 问题：内存不足
```
Out of memory
```

**解决方案**：
```bash
# 限制GIF大小和帧数
[gif]
gif_max_size = 5.0
gif_max_frames = 50

# 增加Docker内存限制
# docker-compose.yml
services:
  meme-generator:
    mem_limit: 2g
```

## 🔧 开发环境问题

### 1. 代码同步问题

#### 问题：子模块未更新
```
Submodule not updated
```

**解决方案**：
```bash
# 更新子模块
git submodule update --init --recursive

# 或使用同步脚本
./scripts/sync-repos.sh
```

#### 问题：合并冲突
```
Merge conflict
```

**解决方案**：
```bash
# 查看冲突文件
git status

# 手动解决冲突后
git add .
git commit -m "Resolve merge conflicts"
```

### 2. 测试问题

#### 问题：测试失败
```
Import error in tests
```

**解决方案**：
```bash
# 设置正确的Python路径
export PYTHONPATH="$(pwd)/core:$(pwd)/contrib:$(pwd)/emoji:$PYTHONPATH"

# 运行测试
python -m pytest tests/
```

## 📊 监控和日志

### 1. 日志分析

#### 查看应用日志
```bash
# Docker环境
docker-compose logs -f meme-generator

# 本地环境
tail -f logs/meme-generator.log
```

#### 调试模式
```bash
# 启用调试日志
[log]
log_level = "DEBUG"
```

### 2. 性能监控

#### 检查资源使用
```bash
# Docker资源使用
docker stats

# 系统资源
htop
# 或
top
```

## 🆘 获取帮助

### 1. 自助诊断
```bash
# 运行诊断脚本
./scripts/diagnose.sh

# 检查系统信息
python --version
docker --version
docker-compose --version
```

### 2. 社区支持

如果以上方法都无法解决问题：

1. **查看文档**：
   - [README.md](../README.md)
   - [SETUP_GUIDE.md](../SETUP_GUIDE.md)
   - [API.md](API.md)
   - [DEPLOYMENT.md](DEPLOYMENT.md)

2. **检查更新日志**：
   - [CHANGELOG.md](../CHANGELOG.md)

3. **提交Issue**：
   - 在GitHub上创建详细的Issue
   - 包含错误日志和系统信息
   - 描述复现步骤

4. **加入社区**：
   - QQ群：682145034
   - 提供日志和配置信息

### 3. Issue模板

提交Issue时请包含：

```markdown
## 问题描述
[详细描述遇到的问题]

## 环境信息
- 操作系统：
- Python版本：
- Docker版本：
- 项目版本：

## 复现步骤
1. 
2. 
3. 

## 错误日志
```
[粘贴完整的错误日志]
```

## 预期行为
[描述期望的正确行为]

## 额外信息
[任何其他相关信息]
```

---

## 📞 紧急联系

对于严重的生产环境问题：
- 立即回滚到上一个稳定版本
- 检查备份和数据完整性
- 联系技术支持团队

记住：大多数问题都有解决方案，保持耐心并系统性地排查问题！