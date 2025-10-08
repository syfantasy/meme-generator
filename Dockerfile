# ---- Stage 1: Clone the main repo to get dependency files ----
FROM alpine/git:latest AS clone-stage
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator

# ---- Stage 2: Generate requirements.txt using Poetry ----
FROM python:3.10 AS builder
WORKDIR /tmp

# 安装 Poetry
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"

# 从 clone-stage 复制依赖定义文件
COPY --from=clone-stage /tmp/meme-generator/pyproject.toml ./
COPY --from=clone-stage /tmp/meme-generator/poetry.lock* ./

# 导出 requirements.txt
RUN poetry self add poetry-plugin-export \
  && poetry export -f requirements.txt --output requirements.txt --without-hashes

# ---- Final App Stage ----
FROM python:3.10-slim
WORKDIR /app

# 设置时区和日志级别
ENV TZ=Asia/Shanghai \
    LOG_LEVEL="INFO"

# 安装构建和运行所需的系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# 组织文件结构：将所有扩展表情包移动到主程序的 memes 目录中
RUN mkdir -p ./src/memes/ \
    && mv ./contrib/memes/* ./src/memes/ \
    && mv ./meme_emoji/emoji/* ./src/memes/ \
    && rm -rf ./contrib ./meme_emoji

# 【重新添加】生成静态 infos.json 和 keyMap.json
# 这将在所有表情包都就位后运行
RUN find ./src/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add' \
    | tee /tmp/infos.json \
    | jq 'to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) | add' > /tmp/keyMap.json

# 将生成的静态文件移动到 meme.js 期望的位置
RUN mkdir -p /app/data/memes \
    && mv /tmp/infos.json /app/data/memes/infos.json \
    && mv /tmp/keyMap.json /app/data/memes/keyMap.json

# 复制字体
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv ./resources/fonts/* /usr/share/fonts/meme-fonts/ \
    && fc-cache -fv

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# 复制并执行启动脚本
COPY ./docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 2233

CMD ["/app/start.sh"]
