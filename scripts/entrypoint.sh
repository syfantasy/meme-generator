#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/app/meme-generator"
DATA_DIR="${MEME_DATA_DIR:-/app/data}"
WEBROOT="/app/webroot"
STATIC_PREFIX="/memes/static"
STATIC_DIR="${WEBROOT}${STATIC_PREFIX}"

echo "[entrypoint] MEME_DATA_DIR=${DATA_DIR}"

try_start_node() {
  if [ -f "${APP_DIR}/package.json" ]; then
    echo "[entrypoint] Detected Node app in ${APP_DIR}"
    cd "${APP_DIR}"
    if npm run --silent start >/dev/null 2>&1; then
      echo "[entrypoint] Starting via 'npm start'"
      exec npm start
    fi
    for f in server.js index.js app.js; do
      if [ -f "$f" ]; then
        echo "[entrypoint] Starting via 'node ${f}'"
        exec node "$f"
      fi
    done
  fi
  return 1
}

try_start_python() {
  if [ -f "${APP_DIR}/requirements.txt" ] || [ -f "${APP_DIR}/pyproject.toml" ] || [ -f "${APP_DIR}/app.py" ] || [ -f "${APP_DIR}/main.py" ]; then
    echo "[entrypoint] Attempting to run Python app"
    cd "${APP_DIR}"
    # Prefer packaged FastAPI app if present
    if [ -f "${APP_DIR}/meme_generator/app.py" ]; then
      echo "[entrypoint] Detected meme_generator.app; priming routers then starting uvicorn"
      exec python3 - <<'PY'
import os
from meme_generator.app import app, register_routers
from meme_generator import load_memes
from starlette.staticfiles import StaticFiles
from fastapi import HTTPException
import uvicorn

# Register API routers from meme_generator
load_memes("/app/meme-generator-contrib/memes")
register_routers()

# Mount static aggregated data under /memes/static
data_dir = os.environ.get("MEME_DATA_DIR", "/app/data")

# Dynamic infos.json and keyMap.json built from loaded memes
from meme_generator.manager import get_memes
from meme_generator.app import MemeInfoResponse, MemeParamsResponse

def build_infos_and_keymap():
    infos = {}
    keymap = {}
    for meme in sorted(get_memes(), key=lambda m: m.key):
        args_type_response = None
        if meme.params_type.args_type:
            args_model = meme.params_type.args_type.args_model
            args_type_response = {
                "args_model": args_model.model_json_schema() if hasattr(args_model, "model_json_schema") else {},
                "args_examples": [
                    getattr(x, "model_dump", lambda: x)() if hasattr(x, "model_dump") else x
                    for x in meme.params_type.args_type.args_examples
                ],
                "parser_options": meme.params_type.args_type.parser_options,
            }
        infos[meme.key] = {
            "key": meme.key,
            "params_type": {
                "min_images": meme.params_type.min_images,
                "max_images": meme.params_type.max_images,
                "min_texts": meme.params_type.min_texts,
                "max_texts": meme.params_type.max_texts,
                "default_texts": meme.params_type.default_texts,
                "args_type": args_type_response,
            },
            "keywords": meme.keywords,
            "shortcuts": meme.shortcuts,
            "tags": list(meme.tags),
            "date_created": meme.date_created,
            "date_modified": meme.date_modified,
        }
        for kw in meme.keywords:
            keymap[kw] = meme.key
    return infos, keymap

@app.get("/memes/static/infos.json")
def infos_json():
    infos, _ = build_infos_and_keymap()
    return infos

@app.get("/memes/static/keyMap.json")
def keymap_json():
    _, keymap = build_infos_and_keymap()
    return keymap

app.mount("/memes/static", StaticFiles(directory=data_dir), name="static")

uvicorn.run(app, host="0.0.0.0", port=8000)
PY
    fi
    # Prefer FastAPI via uvicorn if detected
    if [ -f app.py ] && grep -q "FastAPI(" app.py; then
      echo "[entrypoint] Detected FastAPI in app.py; starting uvicorn app:app"
      exec uvicorn app:app --host 0.0.0.0 --port 8000
    fi
    if [ -f main.py ] && grep -q "FastAPI(" main.py; then
      echo "[entrypoint] Detected FastAPI in main.py; starting uvicorn main:app"
      exec uvicorn main:app --host 0.0.0.0 --port 8000
    fi
    # Generic python entry
    if [ -f app.py ]; then
      echo "[entrypoint] Starting 'python3 app.py'"
      exec python3 app.py
    fi
    if [ -f main.py ]; then
      echo "[entrypoint] Starting 'python3 main.py'"
      exec python3 main.py
    fi
  fi
  return 1
}

fallback_static() {
  echo "[entrypoint] No recognizable app start found. Serving aggregated data statically."
  echo "[entrypoint] Exposing ${STATIC_PREFIX}/infos.json and keyMap.json"
  mkdir -p "${STATIC_DIR}"
  ln -sf "${DATA_DIR}/infos.json" "${STATIC_DIR}/infos.json"
  ln -sf "${DATA_DIR}/keyMap.json" "${STATIC_DIR}/keyMap.json"
  if [ -d "${DATA_DIR}/assets" ]; then
    ln -snf "${DATA_DIR}/assets" "${STATIC_DIR}/assets"
  fi
  echo "[entrypoint] Visit http://localhost:8000${STATIC_PREFIX}/infos.json"
  cd "${WEBROOT}"
  exec python3 -m http.server 8000
}

# Allow explicit override
if [ -n "${APP_START_CMD:-}" ]; then
  echo "[entrypoint] Using APP_START_CMD: ${APP_START_CMD}"
  exec bash -lc "${APP_START_CMD}"
fi

try_start_node || try_start_python || fallback_static
