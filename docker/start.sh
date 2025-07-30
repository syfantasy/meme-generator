#!/bin/bash

# 设置错误时退出
set -e

echo "Starting Meme Generator Unified..."

# 创建必要的目录
mkdir -p /data/contrib /data/emoji /app/config

# 创建系统配置目录
mkdir -p /root/.config/meme_generator

# 强制重新创建系统配置文件
echo "Creating config file from template..."
# 设置Render平台的PORT环境变量，确保有默认值
if [ -z "$PORT" ]; then
    export PORT=2233
fi

echo "Using PORT: $PORT"

# 使用sed替换而不是envsubst，避免复杂的变量语法
# 设置默认值，但允许环境变量覆盖
TRANSLATOR_TYPE=${TRANSLATOR_TYPE:-openai}
BAIDU_TRANS_APPID=${BAIDU_TRANS_APPID:-}
BAIDU_TRANS_APIKEY=${BAIDU_TRANS_APIKEY:-}
OPENAI_API_BASE=${OPENAI_API_BASE:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
OPENAI_MODEL=${OPENAI_MODEL:-gpt-3.5-turbo}
OPENAI_TIMEOUT=${OPENAI_TIMEOUT:-30}
LOG_LEVEL=${LOG_LEVEL:-INFO}

sed -e "s/\${PORT:-2233}/$PORT/g" \
    -e "s/\${LOAD_BUILTIN_MEMES:-true}/true/g" \
    -e "s|\${MEME_DIRS:-\[\"/data/contrib\", \"/data/emoji\"\]}|[\"/data/contrib\", \"/data/emoji\"]|g" \
    -e "s/\${MEME_DISABLED_LIST:-\[\]}/[]/g" \
    -e "s/\${GIF_MAX_SIZE:-10.0}/10.0/g" \
    -e "s/\${GIF_MAX_FRAMES:-100}/100/g" \
    -e "s/\${TRANSLATOR_TYPE:-openai}/$TRANSLATOR_TYPE/g" \
    -e "s/\${BAIDU_TRANS_APPID:-}/$BAIDU_TRANS_APPID/g" \
    -e "s/\${BAIDU_TRANS_APIKEY:-}/$BAIDU_TRANS_APIKEY/g" \
    -e "s/\${OPENAI_API_BASE:-}/$OPENAI_API_BASE/g" \
    -e "s/\${OPENAI_API_KEY:-}/$OPENAI_API_KEY/g" \
    -e "s/\${OPENAI_MODEL:-gpt-3.5-turbo}/$OPENAI_MODEL/g" \
    -e "s/\${OPENAI_TIMEOUT:-30}/$OPENAI_TIMEOUT/g" \
    -e "s/\${LOG_LEVEL:-INFO}/$LOG_LEVEL/g" \
    /app/config.toml.template > /root/.config/meme_generator/config.toml

# 显示配置文件内容用于调试
echo "Generated config file content:"
cat /root/.config/meme_generator/config.toml

# 同时也创建本地配置文件（用于备份）
if [ ! -f /app/config/config.toml ]; then
    export PORT=${PORT:-2233}
    envsubst < /app/config.toml.template > /app/config/config.toml
fi

# 设置Python路径
export PYTHONPATH="/app:/app/core:/app/contrib:/app/emoji:$PYTHONPATH"

# 检查表情包目录
echo "Checking meme directories..."
if [ -d "/data/contrib" ]; then
    echo "Found contrib memes: $(find /data/contrib -name "*.py" | wc -l) files"
fi
if [ -d "/data/emoji" ]; then
    echo "Found emoji memes: $(find /data/emoji -name "*.py" | wc -l) files"
fi

# 启动服务
echo "Starting meme generator server..."
cd /app
exec python -m meme_generator.app