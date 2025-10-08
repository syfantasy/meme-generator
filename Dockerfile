ARG MEME_GENERATOR_REPO=https://github.com/MemeCrafters/meme-generator.git
ARG MEME_GENERATOR_REF=main
ARG CONTRIB_REPO=https://github.com/MemeCrafters/meme-generator-contrib.git
ARG CONTRIB_REF=main
ARG EMOJI_REPO=https://github.com/anyliew/meme_emoji.git
ARG EMOJI_REF=main

# Builder stage: clone repos and aggregate pack metadata
FROM node:20-bookworm-slim AS builder

ARG MEME_GENERATOR_REPO
ARG MEME_GENERATOR_REF
ARG CONTRIB_REPO
ARG CONTRIB_REF
ARG EMOJI_REPO
ARG EMOJI_REF

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       ca-certificates \
       python3 \
       python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/src

# Clone the three repos (shallow clones for speed)
RUN git clone --depth 1 --branch ${MEME_GENERATOR_REF} ${MEME_GENERATOR_REPO} meme-generator \
 && git clone --depth 1 --branch ${CONTRIB_REF} ${CONTRIB_REPO} meme-generator-contrib \
 && git clone --depth 1 --branch ${EMOJI_REF} ${EMOJI_REPO} meme_emoji

# Copy aggregation tool and run it to produce infos.json and keyMap.json
COPY scripts/aggregate_packs.py /opt/tools/aggregate_packs.py
RUN mkdir -p /opt/bundle \
 && python3 /opt/tools/aggregate_packs.py \
      --src /opt/src/meme-generator \
      --src /opt/src/meme-generator-contrib \
      --src /opt/src/meme_emoji \
      --out-dir /opt/bundle

# Runtime stage: include main app + aggregated assets and metadata
FROM node:20-bookworm-slim AS runner

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       python3-pip \
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
       libgl1 \
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
COPY --from=builder /opt/bundle /app/data

# Try to install Node dependencies if present
RUN if [ -f /app/meme-generator/package.json ]; then \
      cd /app/meme-generator \
      && npm ci --omit=dev || npm install --omit=dev \
      && (npm run build || true); \
    fi

 # Python deps: ensure uvicorn + app install (pyproject or setup)
RUN python3 -m pip install --no-cache-dir --upgrade pip \
 && python3 -m pip install --no-cache-dir 'uvicorn[standard]' fastapi || true
RUN if [ -f /app/meme-generator/requirements.txt ]; then \
      python3 -m pip install --no-cache-dir -r /app/meme-generator/requirements.txt || true; \
    fi \
    && if [ -f /app/meme-generator/pyproject.toml ] || [ -f /app/meme-generator/setup.py ]; then \
      python3 -m pip install --no-cache-dir /app/meme-generator || true; \
    fi

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV MEME_DATA_DIR=/app/data
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 3000 5173 8000
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
