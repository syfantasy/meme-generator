ARG MEME_GENERATOR_REPO=https://github.com/MemeCrafters/meme-generator.git
ARG MEME_GENERATOR_REF=main
ARG CONTRIB_REPO=https://github.com/MemeCrafters/meme-generator-contrib.git
ARG CONTRIB_REF=main
ARG EMOJI_REPO=https://github.com/anyliew/meme_emoji.git
ARG EMOJI_REF=main
ARG NSFW_REPO=https://github.com/anyliew/meme_emoji_nsfw.git
ARG NSFW_REF=main
ARG JJ_REPO=https://github.com/jinjiao007/meme-generator-jj.git
ARG JJ_REF=main
ARG TUDOU_REPO=https://github.com/LRZ9712/tudou-meme.git
ARG TUDOU_REF=main
ARG CUTE_REPO=https://github.com/AIGC-Yunzai/meme-generator-cute.git
ARG CUTE_REF=main

# Builder stage: clone repos and aggregate pack metadata
FROM node:20-bookworm-slim AS builder

ARG MEME_GENERATOR_REPO
ARG MEME_GENERATOR_REF
ARG CONTRIB_REPO
ARG CONTRIB_REF
ARG EMOJI_REPO
ARG EMOJI_REF
ARG NSFW_REPO
ARG NSFW_REF
ARG JJ_REPO
ARG JJ_REF
ARG TUDOU_REPO
ARG TUDOU_REF
ARG CUTE_REPO
ARG CUTE_REF

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       ca-certificates \
       python3 \
       python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/src

# Clone the repos (shallow clones for speed); fall back to 'master' if branch not found
RUN set -eux; \
    git clone --depth 1 --branch "${MEME_GENERATOR_REF}" "${MEME_GENERATOR_REPO}" meme-generator; \
    git clone --depth 1 --branch "${CONTRIB_REF}" "${CONTRIB_REPO}" meme-generator-contrib; \
    git clone --depth 1 --branch "${EMOJI_REF}" "${EMOJI_REPO}" meme_emoji; \
    nsfw_ref="${NSFW_REF}"; \
    if ! git ls-remote --heads "${NSFW_REPO}" "${NSFW_REF}" | grep -q .; then nsfw_ref=master; fi; \
    git clone --depth 1 --branch "$nsfw_ref" "${NSFW_REPO}" meme_emoji_nsfw \
      || { echo "[WARN] NSFW repo clone failed, creating empty dir"; mkdir -p meme_emoji_nsfw; }; \
    jj_ref="${JJ_REF}"; \
    if ! git ls-remote --heads "${JJ_REPO}" "${JJ_REF}" | grep -q .; then jj_ref=master; fi; \
    git clone --depth 1 --branch "$jj_ref" "${JJ_REPO}" meme-generator-jj \
      || { echo "[WARN] JJ repo clone failed, creating empty dir"; mkdir -p meme-generator-jj; }; \
    tudou_ref="${TUDOU_REF}"; \
    if ! git ls-remote --heads "${TUDOU_REPO}" "${TUDOU_REF}" | grep -q .; then tudou_ref=master; fi; \
    git clone --depth 1 --branch "$tudou_ref" "${TUDOU_REPO}" tudou-meme \
      || { echo "[WARN] tudou-meme repo clone failed, creating empty dir"; mkdir -p tudou-meme/meme; }; \
    touch tudou-meme/meme/__init__.py; \
    cute_ref="${CUTE_REF}"; \
    if ! git ls-remote --heads "${CUTE_REPO}" "${CUTE_REF}" | grep -q .; then cute_ref=master; fi; \
    git clone --depth 1 --branch "$cute_ref" "${CUTE_REPO}" meme-generator-cute \
      || { echo "[WARN] meme-generator-cute clone failed, creating empty dir"; mkdir -p meme-generator-cute/memes; }

# Copy aggregation tool and run it to produce infos.json and keyMap.json
COPY scripts/aggregate_packs.py /opt/tools/aggregate_packs.py
RUN mkdir -p /opt/bundle \
 && python3 /opt/tools/aggregate_packs.py \
      --src /opt/src/meme-generator \
      --src /opt/src/meme-generator-contrib \
      --src /opt/src/meme_emoji \
      --src /opt/src/meme_emoji_nsfw \
      --src /opt/src/meme-generator-jj \
      --src /opt/src/tudou-meme \
      --src /opt/src/meme-generator-cute \
      --out-dir /opt/bundle

# Runtime stage: include main app + aggregated assets and metadata
FROM node:20-bookworm-slim AS runner

ARG MEME_GENERATOR_REPO
ARG MEME_GENERATOR_REF
ARG CONTRIB_REPO
ARG CONTRIB_REF
ARG EMOJI_REPO
ARG EMOJI_REF
ARG NSFW_REPO
ARG NSFW_REF
ARG JJ_REPO
ARG JJ_REF
ARG TUDOU_REPO
ARG TUDOU_REF
ARG CUTE_REPO
ARG CUTE_REF

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       ca-certificates \
       python3 \
       python3-pip \
       python3-venv \
       python3-toml \
       tini \
       # Fonts and font config
       fontconfig \
       libfontconfig1 \
       libfreetype6 \
       fonts-noto \
       fonts-noto-cjk \
       fonts-noto-color-emoji \
       # Common image libs for Pillow
       libjpeg62-turbo \
       libpng16-16 \
       libtiff6 \
       libwebp7 \
       # GL/X11 runtime for skia-python
       libegl1 \
       libopengl0 \
       libglx0 \
       libgl1 \
       libgl1-mesa-dri \
       libglib2.0-0 \
       libsm6 \
       libxext6 \
       libxrender1 \
       libx11-6 \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# App source and aggregated data
COPY --from=builder /opt/src/meme-generator /app/meme-generator
COPY --from=builder /opt/src/meme-generator-contrib /app/meme-generator-contrib
# Optional: keep raw repo for reference or future use
COPY --from=builder /opt/src/meme_emoji /app/meme_emoji
COPY --from=builder /opt/src/meme_emoji_nsfw /app/meme_emoji_nsfw
COPY --from=builder /opt/src/meme-generator-jj /app/meme-generator-jj
COPY --from=builder /opt/src/tudou-meme /app/tudou-meme
COPY --from=builder /opt/src/meme-generator-cute /app/meme-generator-cute
COPY --from=builder /opt/bundle /app/data

# Try to install Node dependencies if present
RUN if [ -f /app/meme-generator/package.json ]; then \
      cd /app/meme-generator \
      && npm ci --omit=dev || npm install --omit=dev \
      && (npm run build || true); \
    fi

 # Python: create venv to avoid PEP 668 externally-managed error
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Python deps: ensure uvicorn + app install (pyproject or setup)
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir uvicorn fastapi toml \
 && if [ -f /app/meme-generator/requirements.txt ]; then \
      pip install --no-cache-dir -r /app/meme-generator/requirements.txt; \
    fi \
 && if [ -f /app/meme_emoji/requirements.txt ]; then \
      pip install --no-cache-dir -r /app/meme_emoji/requirements.txt; \
    fi \
 && if [ -f /app/meme-generator/pyproject.toml ] || [ -f /app/meme-generator/setup.py ]; then \
      pip install --no-cache-dir /app/meme-generator; \
    fi

COPY scripts/sync_repos.sh /usr/local/bin/sync-meme-repos
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/sync-meme-repos /entrypoint.sh

ENV MEME_DATA_DIR=/app/data
ENV MEME_GENERATOR_REPO=${MEME_GENERATOR_REPO} \
    MEME_GENERATOR_REF=${MEME_GENERATOR_REF} \
    CONTRIB_REPO=${CONTRIB_REPO} \
    CONTRIB_REF=${CONTRIB_REF} \
    EMOJI_REPO=${EMOJI_REPO} \
    EMOJI_REF=${EMOJI_REF} \
    NSFW_REPO=${NSFW_REPO} \
    NSFW_REF=${NSFW_REF} \
    JJ_REPO=${JJ_REPO} \
    JJ_REF=${JJ_REF} \
    TUDOU_REPO=${TUDOU_REPO} \
    TUDOU_REF=${TUDOU_REF} \
    CUTE_REPO=${CUTE_REPO} \
    CUTE_REF=${CUTE_REF} \
    MEME_SYNC_ENABLED=true \
    MEME_SYNC_STRICT=false \
    MEME_SYNC_INSTALL_DEPS=auto
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 3000 5173 8000
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
