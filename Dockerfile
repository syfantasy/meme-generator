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

# ---- Stage 3: Prepare all data and source files ----
FROM node:18 AS data-prep-stage
WORKDIR /app
RUN apt-get update && apt-get install -y jq && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git ./contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git ./meme_emoji
RUN mkdir -p ./src/memes/ \
    && mv ./contrib/memes/* ./src/memes/ \
    && mv ./meme_emoji/emoji/* ./src/memes/ \
    && rm -rf ./contrib ./meme_emoji
RUN find ./src/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add' > /tmp/infos.json
RUN cat /tmp/infos.json \
    | jq 'to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) | add' > /tmp/keyMap.json

# ---- Final App Stage ----
FROM python:3.10
WORKDIR /app
ENV TZ=Asia/Shanghai LOG_LEVEL="INFO"

# 安装运行时的系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    fontconfig \
    fonts-noto-color-emoji \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# 从 data-prep-stage 复制所有准备好的文件
COPY --from=data-prep-stage /app/ /app/
COPY --from=data-prep-stage /tmp/infos.json /app/data/memes/infos.json
COPY --from=data-prep-stage /tmp/keyMap.json /app/data/memes/keyMap.json

# 复制字体并刷新缓存
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv /app/resources/fonts/* /usr/share/fonts/meme-fonts/ \
    && fc-cache -fv

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# 设置启动脚本权限
RUN chmod +x /app/docker/start.sh

EXPOSE 2233
CMD ["/app/docker/start.sh"]
