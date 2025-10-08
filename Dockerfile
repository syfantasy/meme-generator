# ---- Stage 1: Clone the main repo to get dependency files ----
FROM alpine/git:latest AS clone-stage
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator

# ---- Stage 2: Generate requirements.txt using Poetry ----
FROM python:3.10 AS builder
WORKDIR /tmp
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"
COPY --from=clone-stage /tmp/meme-generator/pyproject.toml ./
COPY --from=clone-stage /tmp/meme-generator/poetry.lock* ./
RUN poetry self add poetry-plugin-export \
  && poetry export -f requirements.txt --output requirements.txt --without-hashes

# ---- Final App Stage ----
FROM python:3.10
WORKDIR /app
ENV TZ=Asia/Shanghai LOG_LEVEL="INFO"

# 安装最核心、最不可能失败的系统依赖
# 【修正】重新添加 libegl1-mesa 以解决 skia 的 ImportError
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    jq \
    fontconfig \
    libegl1-mesa \
    && rm -rf /var/lib/apt/lists/*

# 克隆所有仓库
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git ./contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git ./meme_emoji

# 组织文件结构
RUN mkdir -p ./src/memes/ \
    && mv ./contrib/memes/* ./src/memes/ \
    && mv ./meme_emoji/emoji/* ./src/memes/ \
    && rm -rf ./contrib ./meme_emoji

# 生成静态 infos.json 和 keyMap.json
RUN find ./src/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add // {}' \
    | tee /tmp/infos.json \
    | jq '( to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) ) // [] | add' > /tmp/keyMap.json

# 将生成的静态文件移动到 data 目录
RUN mkdir -p /app/data/memes \
    && mv /tmp/infos.json /app/data/memes/infos.json \
    && mv /tmp/keyMap.json /app/data/memes/keyMap.json

# 移动字体、启动脚本和配置文件模板，并设置权限
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv ./resources/fonts/* /usr/share/fonts/meme-fonts/ \
    && fc-cache -fv \
    && mv ./docker/start.sh /app/start.sh \
    && mv ./docker/config.toml.template /app/config.toml.template \
    && chmod +x /app/start.sh

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

EXPOSE 2233
CMD ["/app/start.sh"]
