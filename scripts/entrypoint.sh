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
