# ---- Final Stage: Build upon the official pre-built image ----
# This is the most reliable approach, avoiding all system dependency issues.
FROM memecrafters/meme-generator:latest

# Switch to root user to install build-time dependencies
USER root

# Install git and jq, which are needed for our data preparation steps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# The official image works in /app, so we'll use a temporary directory for cloning
WORKDIR /tmp

# Clone all three repositories
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git meme-generator-contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git meme_emoji

# Organize file structure:
# 1. Clear the original memes that came with the official image.
# 2. Move all memes from our cloned repos into the now-empty directory.
# The official image is configured to load memes from `/data/memes`.
RUN rm -rf /data/memes/* \
    && mv /tmp/meme-generator/meme_generator/memes/* /data/memes/ \
    && mv /tmp/meme-generator-contrib/memes/* /data/memes/ \
    && mv /tmp/meme_emoji/emoji/* /data/memes/

# Generate the static infos.json and keyMap.json from the unified meme directory
RUN find /data/memes -type f -name 'info.json' \
    | xargs -r -I {} jq . {} \
    | jq -s 'add' > /app/data/memes/infos.json
RUN cat /app/data/memes/infos.json \
    | jq 'to_entries | map(select(.value.keywords != null and (.value.keywords | length) > 0)) | map({(.value.keywords[]): .key}) | add' > /app/data/memes/keyMap.json

# Clean up cloned repos and build dependencies
RUN rm -rf /tmp/* \
    && apt-get purge -y --auto-remove git jq

# Switch back to the non-root user that the official image uses
USER user

# Set the working directory back to the app's default
WORKDIR /app

# The official image's CMD ["/app/start.sh"] will be inherited and used
