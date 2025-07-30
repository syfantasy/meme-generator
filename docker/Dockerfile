FROM python:3.10 AS tmp

WORKDIR /tmp

RUN curl -sSL https://install.python-poetry.org | python -

ENV PATH="${PATH}:/root/.local/bin"

COPY ./requirements.txt /tmp/

FROM python:3.10-slim AS app

WORKDIR /app

EXPOSE 2233

VOLUME ["/data", "/app/config"]

ENV TZ=Asia/Shanghai \
    LOAD_BUILTIN_MEMES=true \
    MEME_DIRS="[\"/data/contrib\", \"/data/emoji\"]" \
    MEME_DISABLED_LIST="[]" \
    GIF_MAX_SIZE=10.0 \
    GIF_MAX_FRAMES=100 \
    LOG_LEVEL="INFO" \
    PYTHONPATH="/app:/app/core:/app/contrib:/app/emoji"

# 安装系统依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fontconfig \
        fonts-noto-color-emoji \
        libgl1-mesa-glx \
        libgl1-mesa-dri \
        libegl1-mesa \
        gettext \
        curl \
    && fc-cache -fv \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件并安装Python依赖
COPY --from=tmp /tmp/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# 复制字体文件
COPY ./core/resources/fonts/* /usr/share/fonts/meme-fonts/
RUN fc-cache -fv

# 复制核心代码
COPY ./core/meme_generator /app/meme_generator

# 复制扩展表情包
COPY ./contrib/memes /data/contrib
COPY ./emoji/emoji /data/emoji

# 复制配置文件和启动脚本
COPY ./docker/config.toml.template /app/config.toml.template
COPY ./docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# 预加载meme生成器
RUN python -c "import meme_generator; print('Meme generator loaded successfully')"

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:2233/docs || exit 1

CMD ["/app/start.sh"]