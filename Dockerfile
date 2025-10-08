# ---- Stage 1: Generate requirements.txt using Poetry ----
FROM python:3.10 AS builder
WORKDIR /tmp
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"
COPY meme-generator/pyproject.toml ./
COPY meme-generator/poetry.lock* ./
RUN poetry self add poetry-plugin-export \
  && poetry export -f requirements.txt --output requirements.txt --without-hashes

# ---- Final App Stage ----
FROM python:3.10-slim
WORKDIR /app
EXPOSE 2233
ENV TZ=Asia/Shanghai \
    LOAD_BUILTIN_MEMES=true \
    MEME_DIRS="[\"/data/memes\"]" \
    LOG_LEVEL="INFO"

# 安装 git 和 jq 用于构建，以及与官方 Dockerfile 完全一致的运行时依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    jq \
    fontconfig \
    fonts-noto-color-emoji \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    gettext \
  && rm -rf /var/lib/apt/lists/*

# 克隆所有仓库
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git ./contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git ./meme_emoji

# 创建并统一表情包目录
RUN mkdir -p /data/memes \
    && mv ./src/memes/* /data/memes/ \
    && mv ./contrib/memes/* /data/memes/ \
    && mv ./emoji/emoji/* /data/memes/ \
    && rm -rf ./src ./contrib ./emoji

# 生成静态 infos.json 和 keyMap.json
RUN find /data/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add // {}' \
    | tee /app/data/memes/infos.json \
    | jq '( to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) ) // [] | add' > /app/data/memes/keyMap.json

# 复制字体并刷新缓存
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv ./resources/fonts/* /usr/share/fonts/meme-fonts/ \
    && fc-cache -fv

# 复制主程序代码
COPY meme_generator /app/meme_generator

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# 移动并设置启动脚本
RUN mv ./docker/start.sh /app/start.sh \
    && mv ./docker/config.toml.template /app/config.toml.template \
    && chmod +x /app/start.sh

CMD ["/app/start.sh"]
