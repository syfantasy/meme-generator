# ---- Builder Stage: Generate requirements.txt ----
FROM python:3.10 AS builder

WORKDIR /tmp

# 安装 Poetry
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"

# 复制主项目的依赖定义文件
COPY meme-generator/pyproject.toml ./
COPY meme-generator/poetry.lock* ./

# 导出 requirements.txt
RUN poetry self add poetry-plugin-export \
  && poetry export -f requirements.txt --output requirements.txt --without-hashes

# ---- Final App Stage ----
FROM python:3.10-slim

WORKDIR /app

# 设置时区和默认的表情包加载目录
# 我们将把所有表情包都放在 /data/memes 中
ENV TZ=Asia/Shanghai \
    LOAD_BUILTIN_MEMES=true \
    MEME_DIRS="[\"/data/memes\"]" \
    LOG_LEVEL="INFO"

# 创建统一的表情包数据目录
RUN mkdir -p /data/memes

# 从 builder 阶段复制 requirements.txt
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# 复制所有仓库的代码到临时目录，以便后续整理
COPY meme-generator/ /tmp/meme-generator/
COPY meme-generator-contrib/ /tmp/meme-generator-contrib/
COPY meme_emoji/ /tmp/meme_emoji/

# 复制主程序代码到工作目录
COPY --from=builder /tmp/meme-generator/meme_generator /app/meme_generator

# 复制所有表情包到统一的数据目录
COPY --from=builder /tmp/meme-generator/meme_generator/memes /data/memes/
COPY --from=builder /tmp/meme-generator-contrib/memes /data/memes/
COPY --from=builder /tmp/meme_emoji/emoji /data/memes/

# 复制字体
COPY --from=builder /tmp/meme-generator/resources/fonts /usr/share/fonts/meme-fonts/

# 安装系统依赖、字体，然后安装 Python 依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends fontconfig fonts-noto-color-emoji libgl1-mesa-glx libgl1-mesa-dri libegl1-mesa gettext \
  && fc-cache -fv \
  && pip install --no-cache-dir --upgrade -r /app/requirements.txt \
  && apt-get purge -y --auto-remove \
  && rm -rf /var/lib/apt/lists/*

# 复制并执行启动脚本
COPY --from=builder /tmp/meme-generator/docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 2233

CMD ["/app/start.sh"]
