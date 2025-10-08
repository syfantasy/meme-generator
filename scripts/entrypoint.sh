#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/app/meme-generator"
DATA_DIR="${MEME_DATA_DIR:-/app/data}"

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
  if [ -f "${APP_DIR}/requirements.txt" ] || [ -f "${APP_DIR}/pyproject.toml" ] || [ -f "${APP_DIR}/app.py" ]; then
    echo "[entrypoint] Attempting to run Python app"
    cd "${APP_DIR}"
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
  echo "[entrypoint] Visit http://localhost:8000 to browse /app/data"
  cd /app
  exec python3 -m http.server 8000
}

try_start_node || try_start_python || fallback_static

