# ---- Stage 1: Generate requirements.txt using Poetry ----
FROM python:3.10 AS builder
WORKDIR /tmp
# We need git to clone the repo to get the pyproject.toml
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH="/root/.local/bin:${PATH}"
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

# Install git and jq for build, and runtime dependencies, exactly as in the official Dockerfile
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

# Clone all repositories
# The main repo is cloned to the current directory /app
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git .
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git ./contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git ./emoji

# Create and unify the memes directory
RUN mkdir -p /data/memes \
    && mv ./src/memes/* /data/memes/ \
    && mv ./contrib/memes/* /data/memes/ \
    && mv ./emoji/emoji/* /data/memes/

# Generate static infos.json and keyMap.json
RUN find /data/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add // {}' \
    | tee /app/data/memes/infos.json \
    | jq '( to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) ) // [] | add' > /app/data/memes/keyMap.json

# Move fonts and startup scripts, set permissions, and clean up
RUN mkdir -p /usr/share/fonts/meme-fonts/ \
    && mv ./resources/fonts/* /usr/share/fonts/meme-fonts/ \
    && fc-cache -fv \
    && mv ./docker/start.sh /app/start.sh \
    && mv ./docker/config.toml.template /app/config.toml.template \
    && chmod +x /app/start.sh \
    && rm -rf ./src ./contrib ./emoji ./resources ./docker

# Copy requirements.txt from the builder stage
COPY --from=builder /tmp/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

CMD ["/app/start.sh"]
