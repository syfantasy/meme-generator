#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/app/meme-generator"
# Ensure meme_generator reads config from a predictable location
export XDG_CONFIG_HOME="/app/config"
CONFIG_DIR="${XDG_CONFIG_HOME}/meme_generator"
CONFIG_FILE="${CONFIG_DIR}/config.toml"
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

    # Build a minimal config.toml for translator and control meme loading order
    mkdir -p "$CONFIG_DIR"
    : > "$CONFIG_FILE.tmp"
    PROV="${TRANSLATOR_PROVIDER:-}"
    if [ -z "$PROV" ]; then
      if [ -n "${OPENAI_API_KEY:-}" ]; then PROV="openai"; fi
      if [ -n "${BAIDU_TRANS_APPID:-}" ] && [ -n "${BAIDU_TRANS_APIKEY:-}" ]; then PROV="${PROV:-baidu}"; fi
    fi
    OPENAI_KEY_STATE="missing"
    if [ -n "${OPENAI_API_KEY:-}" ]; then OPENAI_KEY_STATE="present"; fi
    echo "[entrypoint] Translator env: provider=${PROV:-auto} OPENAI_BASE_URL=${OPENAI_BASE_URL:-<empty>} OPENAI_MODEL=${OPENAI_MODEL:-<empty>} OPENAI_API_KEY=${OPENAI_KEY_STATE}"
    echo "[meme]" >> "$CONFIG_FILE.tmp"
    echo "load_builtin_memes = false" >> "$CONFIG_FILE.tmp"
    echo "meme_dirs = []" >> "$CONFIG_FILE.tmp"

    echo "[translate]" >> "$CONFIG_FILE.tmp"
    if [ -n "$PROV" ]; then echo "provider = \"$PROV\"" >> "$CONFIG_FILE.tmp"; fi
    if [ -n "${OPENAI_BASE_URL:-}" ]; then echo "openai_base_url = \"${OPENAI_BASE_URL}\"" >> "$CONFIG_FILE.tmp"; fi
    if [ -n "${OPENAI_API_KEY:-}" ]; then echo "openai_api_key = \"${OPENAI_API_KEY}\"" >> "$CONFIG_FILE.tmp"; fi
    if [ -n "${OPENAI_MODEL:-}" ]; then echo "openai_model = \"${OPENAI_MODEL}\"" >> "$CONFIG_FILE.tmp"; fi
    if [ -n "${BAIDU_TRANS_APPID:-}" ]; then echo "baidu_trans_appid = \"${BAIDU_TRANS_APPID}\"" >> "$CONFIG_FILE.tmp"; fi
    if [ -n "${BAIDU_TRANS_APIKEY:-}" ]; then echo "baidu_trans_apikey = \"${BAIDU_TRANS_APIKEY}\"" >> "$CONFIG_FILE.tmp"; fi
    echo "[server]" >> "$CONFIG_FILE.tmp"
    echo "host = \"0.0.0.0\"" >> "$CONFIG_FILE.tmp"
    echo "port = 8000" >> "$CONFIG_FILE.tmp"
    echo "[log]" >> "$CONFIG_FILE.tmp"
    echo "log_level = \"INFO\"" >> "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "[entrypoint] Wrote config to ${CONFIG_FILE}"
    cd "${APP_DIR}"
    # Prefer packaged FastAPI app if present
    if [ -f "${APP_DIR}/meme_generator/app.py" ]; then
      echo "[entrypoint] Detected meme_generator.app; priming routers then starting uvicorn"
      exec python - <<'PY'
import os
import importlib
from pathlib import Path
import httpx

# Import package with builtin memes disabled (controlled by config.toml)
from meme_generator.config import meme_config
import meme_generator.utils as _utils
from meme_generator import load_meme, load_memes
from meme_generator.app import app, register_routers
from starlette.staticfiles import StaticFiles
from fastapi import HTTPException
from pydantic import BaseModel
from typing import Literal, Optional, List
import filetype
from meme_generator.manager import get_meme, get_memes
from meme_generator.exception import NoSuchMeme, MemeFeedback
from meme_generator.utils import MemeProperties, render_meme_list
import uvicorn

print(f"[bootstrap] XDG_CONFIG_HOME={os.environ.get('XDG_CONFIG_HOME')} CONFIG_DIR=/app/config/meme_generator", flush=True)
tc = getattr(meme_config, 'translate', None)
if tc:
    print(
        f"[bootstrap] meme_config.translate provider={getattr(tc,'provider',None)} base_url={getattr(tc,'openai_base_url',None)} "
        f"model={getattr(tc,'openai_model',None)} api_key_present={bool(getattr(tc,'openai_api_key',None))}",
        flush=True,
    )
else:
    print("[bootstrap] meme_config.translate missing", flush=True)

_orig_translate = _utils.translate

def _openai_translate(text: str, lang_from: str = "auto", lang_to: str = "zh") -> str:
    tc = getattr(meme_config, "translate", None)
    if not tc:
        return _orig_translate(text, lang_from, lang_to)
    provider = getattr(tc, "provider", "").lower()
    base_url = getattr(tc, "openai_base_url", "").strip()
    api_key = getattr(tc, "openai_api_key", "").strip()
    model = getattr(tc, "openai_model", "").strip()

    use_openai = provider == "openai" or (not provider and bool(api_key))
    if not use_openai:
        print(f"[translate] fallback to original provider (provider={provider})", flush=True)
        return _orig_translate(text, lang_from, lang_to)

    if not base_url or not api_key or not model:
        raise MemeFeedback("OpenAI 翻译未配置完整：请设置 openai_base_url / openai_api_key / openai_model")

    lang_map = {
        "zh": "Chinese",
        "zh-cn": "Chinese",
        "zh-hans": "Chinese",
        "en": "English",
        "jp": "Japanese",
        "ja": "Japanese",
        "ko": "Korean",
        "fr": "French",
        "de": "German",
        "ru": "Russian",
        "es": "Spanish",
    }
    target_lang = lang_map.get((lang_to or "").lower(), lang_to)

    url = base_url.rstrip("/") + "/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": model,
        "temperature": 0,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a professional translation engine. "
                    f"Translate the user text to {target_lang}. "
                    "Only output the translated text without any extra words, quotes, or explanations. "
                    "Preserve numbers, emoji, and links."
                ),
            },
            {"role": "user", "content": text},
        ],
    }
    try:
        print(
            f"[translate/openai] request target={target_lang} model={model} base_url={base_url} text_len={len(text)}",
            flush=True,
        )
        r = httpx.post(url, headers=headers, json=payload, timeout=60)
        print(f"[translate/openai] response status={r.status_code}", flush=True)
        r.raise_for_status()
        data = r.json()
        choices = data.get("choices") or []
        content = choices[0].get("message", {}).get("content") if choices else None
        if not content:
            raise MemeFeedback("OpenAI 翻译失败：空结果")
        result = str(content).strip()
        print(f"[translate/openai] success result_len={len(result)}", flush=True)
        return result
    except Exception as e:
        raise MemeFeedback(f"OpenAI 翻译失败: {e}")

# Patch in place so memes using translate() pick it up (e.g., dianzhongdian)
_utils.translate = _openai_translate
print("[bootstrap] translate() monkey-patched for OpenAI provider", flush=True)

# Manually load builtin memes AFTER patching translate
pkg_dir = Path(importlib.import_module('meme_generator').__file__).parent
memes_dir = pkg_dir / 'memes'
if memes_dir.exists():
    for path in memes_dir.iterdir():
        if path.is_dir():
            load_meme(f"meme_generator.memes.{path.name}")

# Prepend an override for /memes/render_list that computes the list at request time
class MemeKeyWithProperties(BaseModel):
    meme_key: str
    disabled: bool = False
    labels: List[Literal["new", "hot"]] = []

class RenderMemeListRequest(BaseModel):
    meme_list: Optional[List[MemeKeyWithProperties]] = None
    text_template: str = "{keywords}"
    add_category_icon: bool = True

@app.post("/memes/render_list")
def render_list(params: RenderMemeListRequest = RenderMemeListRequest()):
    try:
        if params.meme_list:
            meme_list = [
                (
                    get_meme(p.meme_key),
                    MemeProperties(disabled=p.disabled, labels=p.labels),
                )
                for p in params.meme_list
            ]
        else:
            # Build from current loaded memes to include contrib + emoji
            meme_list = [
                (m, MemeProperties()) for m in sorted(get_memes(), key=lambda m: m.key)
            ]
    except NoSuchMeme as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)

    result = render_meme_list(
        meme_list,
        text_template=params.text_template,
        add_category_icon=params.add_category_icon,
    )
    content = result.getvalue()
    media_type = str(filetype.guess_mime(content)) or "text/plain"
    from fastapi import Response
    return Response(content=content, media_type=media_type)

# Register API routers from meme_generator (after our override so it remains first)
load_memes("/app/meme-generator-contrib/memes")
load_memes("/app/meme_emoji/emoji")
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
      echo "[entrypoint] Starting 'python app.py'"
      exec python app.py
    fi
    if [ -f main.py ]; then
      echo "[entrypoint] Starting 'python main.py'"
      exec python main.py
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
  exec python -m http.server 8000
}

# Allow explicit override
if [ -n "${APP_START_CMD:-}" ]; then
  echo "[entrypoint] Using APP_START_CMD: ${APP_START_CMD}"
  exec bash -lc "${APP_START_CMD}"
fi

try_start_node || try_start_python || fallback_static
