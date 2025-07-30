# 部署指南

本文档介绍如何部署 Meme Generator Unified 项目。

## 🐳 Docker 部署（推荐）

### 快速开始

1. **克隆仓库**
```bash
git clone --recursive https://github.com/your-username/meme-generator-unified.git
cd meme-generator-unified
```

2. **配置环境变量**
```bash
cp .env.example .env
# 编辑 .env 文件，设置你的API密钥
```

3. **启动服务**
```bash
docker-compose up -d
```

4. **访问服务**
- API文档: http://localhost:2233/docs
- 健康检查: http://localhost:2233/health

### 环境变量配置

| 变量名 | 描述 | 默认值 | 必需 |
|--------|------|--------|------|
| `TRANSLATOR_TYPE` | 翻译服务类型 (`baidu` 或 `openai`) | `baidu` | 否 |
| `BAIDU_TRANS_APPID` | 百度翻译APP ID | - | 使用百度翻译时必需 |
| `BAIDU_TRANS_APIKEY` | 百度翻译API Key | - | 使用百度翻译时必需 |
| `OPENAI_API_BASE` | OpenAI API基础URL | - | 使用OpenAI时必需 |
| `OPENAI_API_KEY` | OpenAI API密钥 | - | 使用OpenAI时必需 |
| `OPENAI_MODEL` | OpenAI模型名称 | `gpt-3.5-turbo` | 否 |
| `HOST` | 服务监听地址 | `0.0.0.0` | 否 |
| `PORT` | 服务端口 | `2233` | 否 |
| `LOG_LEVEL` | 日志级别 | `INFO` | 否 |

### Docker Compose 配置

```yaml
version: '3.8'
services:
  meme-generator:
    image: ghcr.io/your-username/meme-generator-unified:latest
    ports:
      - "2233:2233"
    volumes:
      - ./data:/data
      - ./config:/app/config
    environment:
      - TRANSLATOR_TYPE=openai
      - OPENAI_API_BASE=https://api.openai.com/v1
      - OPENAI_API_KEY=your_api_key_here
    restart: unless-stopped
```

## 🖥️ 手动部署

### 系统要求

- Python 3.9+
- Git
- 至少 2GB RAM
- 至少 5GB 磁盘空间

### 安装步骤

1. **克隆仓库**
```bash
git clone --recursive https://github.com/your-username/meme-generator-unified.git
cd meme-generator-unified
```

2. **运行设置脚本**
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

3. **配置服务**
```bash
# 编辑配置文件
vim config/config.toml

# 或者使用环境变量
cp .env.example .env
vim .env
```

4. **启动服务**
```bash
cd core
python -m meme_generator.cli --host 0.0.0.0 --port 2233
```

### 系统服务配置

创建 systemd 服务文件：

```bash
sudo tee /etc/systemd/system/meme-generator.service > /dev/null <<EOF
[Unit]
Description=Meme Generator Unified
After=network.target

[Service]
Type=simple
User=meme
WorkingDirectory=/opt/meme-generator-unified/core
Environment=PYTHONPATH=/opt/meme-generator-unified/core:/opt/meme-generator-unified/contrib:/opt/meme-generator-unified/emoji
ExecStart=/usr/bin/python3 -m meme_generator.cli --host 0.0.0.0 --port 2233
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable meme-generator
sudo systemctl start meme-generator
```

## 🌐 反向代理配置

### Nginx

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:2233;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 支持大文件上传
        client_max_body_size 50M;
        
        # WebSocket支持（如果需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Caddy

```caddy
your-domain.com {
    reverse_proxy 127.0.0.1:2233
    
    # 支持大文件上传
    request_body {
        max_size 50MB
    }
}
```

## 📊 监控和日志

### 健康检查

服务提供健康检查端点：
```bash
curl http://localhost:2233/health
```

### 日志配置

日志级别可以通过环境变量或配置文件设置：
- `DEBUG`: 详细调试信息
- `INFO`: 一般信息（默认）
- `WARNING`: 警告信息
- `ERROR`: 错误信息

### Prometheus 监控

如果需要 Prometheus 监控，可以添加以下配置：

```yaml
# docker-compose.yml
services:
  meme-generator:
    # ... 其他配置
    environment:
      - ENABLE_METRICS=true
      - METRICS_PORT=9090
    ports:
      - "2233:2233"
      - "9090:9090"  # Prometheus metrics
```

## 🔧 故障排除

### 常见问题

1. **端口被占用**
```bash
# 检查端口占用
netstat -tlnp | grep 2233
# 或者
lsof -i :2233
```

2. **权限问题**
```bash
# 确保用户有权限访问文件
chown -R meme:meme /opt/meme-generator-unified
chmod +x scripts/*.sh
```

3. **依赖问题**
```bash
# 重新安装依赖
pip install --upgrade -r requirements.txt
```

4. **子模块问题**
```bash
# 更新子模块
git submodule update --init --recursive
```

### 日志查看

```bash
# Docker 日志
docker-compose logs -f meme-generator

# 系统服务日志
journalctl -u meme-generator -f

# 应用日志
tail -f logs/meme-generator.log
```

## 🔄 更新和维护

### 自动更新

项目配置了 GitHub Actions 自动同步上游仓库，无需手动干预。

### 手动更新

```bash
# 更新子模块
./scripts/sync-repos.sh

# 重新构建 Docker 镜像
docker-compose build --no-cache

# 重启服务
docker-compose restart
```

### 备份

重要数据备份：
```bash
# 备份配置
cp -r config/ backup/config-$(date +%Y%m%d)/

# 备份自定义表情包
cp -r data/ backup/data-$(date +%Y%m%d)/
```

## 🔐 安全建议

1. **API 密钥安全**
   - 使用环境变量存储敏感信息
   - 定期轮换 API 密钥
   - 不要在代码中硬编码密钥

2. **网络安全**
   - 使用 HTTPS（通过反向代理）
   - 配置防火墙规则
   - 限制访问来源

3. **系统安全**
   - 定期更新系统和依赖
   - 使用非 root 用户运行服务
   - 配置适当的文件权限

## 📞 支持

如果遇到部署问题，请：
1. 查看日志文件
2. 检查配置文件
3. 在 GitHub 上创建 Issue
4. 加入 QQ 群：682145034