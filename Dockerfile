# 使用官方 Python 镜像作为基础
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装 git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 克隆所有仓库到各自独立的目录中
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git meme-generator-contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git meme_emoji

# 创建配置文件，告诉主程序去哪里加载所有表情包
# 注意：我们使用绝对路径，因为容器内的 CWD 可能会变化
RUN echo '[meme]' > /app/config.prod.toml
RUN echo 'meme_dirs = [' >> /app/config.prod.toml
RUN echo '  "/app/meme-generator/src/memes",' >> /app/config.prod.toml
RUN echo '  "/app/meme-generator-contrib/memes",' >> /app/config.prod.toml
RUN echo '  "/app/meme_emoji/emoji"' >> /app/config.prod.toml
RUN echo ']' >> /app/config.prod.toml

# 设置环境变量，让 meme-generator 加载我们的配置文件
ENV MEME_CONFIG_FILE="/app/config.prod.toml"

# 安装编译依赖和 Python 依赖
WORKDIR /app/meme-generator
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libjpeg-dev zlib1g-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/*

# 将工作目录切换回 /app
WORKDIR /app

# 设置容器启动命令
# 使用 `meme-generator` 目录中的 `app.py` 作为入口点
CMD ["python", "-m", "meme_generator"]
