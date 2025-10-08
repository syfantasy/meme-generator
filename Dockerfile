# ---- Builder Stage: Prepare files and dependencies ----
FROM python:3.10 AS builder

WORKDIR /tmp

# 安装 Poetry
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"

# 复制主项目的依赖定义文件
# 我们需要先从 git 克隆才能获取这些文件
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator
COPY --from=builder /tmp/meme-generator/pyproject.toml ./
COPY --from=builder /tmp/meme-generator/poetry.lock* ./

# 导出 requirements.txt
RUN poetry self add poetry-plugin-export \
  && poetry export -f requirements.txt --output requirements.txt --without-hashes

# ---- Final App Stage ----
FROM python:3.10-slim

WORKDIR /app

# 设置时区和日志级别
ENV TZ=Asia/Shanghai \
    LOG_LEVEL="INFO"

# 安装 git 以便克隆仓库
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 克隆所有仓库
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git ./contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git ./meme_emoji

# 组织文件结构：将所有扩展表情包移动到主程序的 memes 目录中
# 这是关键步骤，确保所有表情包都在一个地方
RUN mv ./contrib/memes/* ./src/memes/ \
    && mv ./meme_emoji/emoji/* ./src/memes/ \
    && rm -rf ./contrib ./meme_emoji

# 复制字体
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv ./resources/fonts/* /usr/share/fonts/meme-fonts/

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 安装系统依赖、字体，然后安装 Python 依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends fontconfig fonts-noto-color-emoji libgl1-mesa-glx libgl1-mesa-dri libegl1-mesa gettext \
  && fc-cache -fv \
  && pip install --no-cache-dir --upgrade -r /app/requirements.txt \
  && apt-get purge -y --auto-remove git \
  && rm -rf /var/lib/apt/lists/*

# 复制并执行启动脚本
COPY ./docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 2233

CMD ["/app/start.sh"]
