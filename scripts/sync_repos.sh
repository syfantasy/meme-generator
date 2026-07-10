#!/usr/bin/env bash
set -uo pipefail

APP_ROOT="${MEME_APP_ROOT:-/app}"
SYNC_ENABLED="${MEME_SYNC_ENABLED:-true}"
SYNC_STRICT="${MEME_SYNC_STRICT:-false}"
INSTALL_DEPS="${MEME_SYNC_INSTALL_DEPS:-auto}"
GIT_TIMEOUT="${MEME_SYNC_GIT_TIMEOUT:-300}"

is_true() {
  case "$1" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

if ! is_true "$SYNC_ENABLED"; then
  echo "[sync] Runtime repository sync is disabled"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[sync] git is unavailable; using repositories bundled in the image" >&2
  if is_true "$SYNC_STRICT"; then exit 1; fi
  exit 0
fi

export GIT_TERMINAL_PROMPT=0

manifest_hash() {
  local dir="$1"
  shift
  local file
  local files=()
  for file in "$@"; do
    if [ -f "${dir}/${file}" ]; then
      files+=("${dir}/${file}")
    fi
  done
  if [ "${#files[@]}" -eq 0 ]; then
    echo "missing"
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${files[@]}" | sha256sum | awk '{ print $1 }'
  else
    shasum -a 256 "${files[@]}" | shasum -a 256 | awk '{ print $1 }'
  fi
}

run_git() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$GIT_TIMEOUT" git "$@"
  else
    git "$@"
  fi
}

fetch_ref() {
  local dir="$1"
  local ref="$2"

  if run_git -C "$dir" fetch --force --depth 1 origin "$ref"; then
    return 0
  fi

  if [ "$ref" = "main" ]; then
    echo "[sync] ${dir}: ref main unavailable, trying master"
    run_git -C "$dir" fetch --force --depth 1 origin master
    return $?
  fi

  return 1
}

sync_repo() {
  local name="$1"
  local repo="$2"
  local ref="$3"
  local required="$4"
  local dir="${APP_ROOT}/${name}"
  local old_commit="missing"
  local new_commit
  local tmp_dir

  if [ -d "${dir}/.git" ]; then
    old_commit="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    git config --global --add safe.directory "$dir" >/dev/null 2>&1 || true
    run_git -C "$dir" remote set-url origin "$repo" >/dev/null 2>&1 || true

    if fetch_ref "$dir" "$ref" && run_git -C "$dir" reset --hard FETCH_HEAD >/dev/null; then
      new_commit="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      echo "[sync] ${name}: ${old_commit} -> ${new_commit} (${ref})"
      return 0
    fi
  else
    echo "[sync] ${name}: bundled git metadata missing; cloning ${ref}"
    tmp_dir="${dir}.sync.$$"
    rm -rf "$tmp_dir"
    if run_git clone --depth 1 --branch "$ref" "$repo" "$tmp_dir" \
      || { [ "$ref" = "main" ] && run_git clone --depth 1 --branch master "$repo" "$tmp_dir"; }; then
      rm -rf "$dir"
      mv "$tmp_dir" "$dir"
      new_commit="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      echo "[sync] ${name}: cloned ${new_commit} (${ref})"
      return 0
    fi
    rm -rf "$tmp_dir"
  fi

  echo "[sync] ${name}: update failed; keeping bundled version ${old_commit}" >&2
  if [ "$required" = "required" ]; then
    return 1
  fi
  return 2
}

main_dep_before="$(manifest_hash "${APP_ROOT}/meme-generator" pyproject.toml requirements.txt setup.py)"
emoji_dep_before="$(manifest_hash "${APP_ROOT}/meme_emoji" requirements.txt pyproject.toml)"
nsfw_dep_before="$(manifest_hash "${APP_ROOT}/meme_emoji_nsfw" requirements.txt pyproject.toml)"
main_commit_before="$(git -C "${APP_ROOT}/meme-generator" rev-parse HEAD 2>/dev/null || echo missing)"
contrib_commit_before="$(git -C "${APP_ROOT}/meme-generator-contrib" rev-parse HEAD 2>/dev/null || echo missing)"
emoji_commit_before="$(git -C "${APP_ROOT}/meme_emoji" rev-parse HEAD 2>/dev/null || echo missing)"
nsfw_commit_before="$(git -C "${APP_ROOT}/meme_emoji_nsfw" rev-parse HEAD 2>/dev/null || echo missing)"
jj_commit_before="$(git -C "${APP_ROOT}/meme-generator-jj" rev-parse HEAD 2>/dev/null || echo missing)"
tudou_commit_before="$(git -C "${APP_ROOT}/tudou-meme" rev-parse HEAD 2>/dev/null || echo missing)"
cute_commit_before="$(git -C "${APP_ROOT}/meme-generator-cute" rev-parse HEAD 2>/dev/null || echo missing)"

failures=0
sync_repo "meme-generator" "${MEME_GENERATOR_REPO:-https://github.com/MemeCrafters/meme-generator.git}" "${MEME_GENERATOR_REF:-main}" required || failures=$((failures + 1))
sync_repo "meme-generator-contrib" "${CONTRIB_REPO:-https://github.com/MemeCrafters/meme-generator-contrib.git}" "${CONTRIB_REF:-main}" optional || true
sync_repo "meme_emoji" "${EMOJI_REPO:-https://github.com/anyliew/meme_emoji.git}" "${EMOJI_REF:-main}" optional || true
sync_repo "meme_emoji_nsfw" "${NSFW_REPO:-https://github.com/anyliew/meme_emoji_nsfw.git}" "${NSFW_REF:-main}" optional || true
sync_repo "meme-generator-jj" "${JJ_REPO:-https://github.com/jinjiao007/meme-generator-jj.git}" "${JJ_REF:-main}" optional || true
sync_repo "tudou-meme" "${TUDOU_REPO:-https://github.com/LRZ9712/tudou-meme.git}" "${TUDOU_REF:-main}" optional || true
sync_repo "meme-generator-cute" "${CUTE_REPO:-https://github.com/AIGC-Yunzai/meme-generator-cute.git}" "${CUTE_REF:-main}" optional || true

# tudou-meme is loaded as a Python package by the bootstrap code.
mkdir -p "${APP_ROOT}/tudou-meme/meme"
touch "${APP_ROOT}/tudou-meme/meme/__init__.py"

rollback_repo() {
  local dir="$1"
  local commit="$2"
  local label="$3"
  if [ "$commit" != "missing" ] && git -C "$dir" cat-file -e "${commit}^{commit}" 2>/dev/null; then
    git -C "$dir" reset --hard "$commit" >/dev/null
    echo "[sync] ${label}: rolled back source to $(git -C "$dir" rev-parse --short HEAD)" >&2
  fi
}

install_if_changed() {
  local label="$1"
  local before="$2"
  local after="$3"
  local rollback_dir="$4"
  local rollback_commit="$5"
  shift 5

  if [ "$before" = "$after" ]; then
    return 0
  fi

  echo "[sync] ${label} dependency manifest changed: ${before} -> ${after}"
  if [ "$INSTALL_DEPS" = "auto" ] || is_true "$INSTALL_DEPS"; then
    if ! python -m pip install --disable-pip-version-check --no-cache-dir "$@"; then
      echo "[sync] ${label} dependency refresh failed" >&2
      if [ "$label" = "meme-generator" ]; then
        rollback_repo "${APP_ROOT}/meme-generator" "$main_commit_before" "meme-generator"
        rollback_repo "${APP_ROOT}/meme-generator-contrib" "$contrib_commit_before" "meme-generator-contrib"
        rollback_repo "${APP_ROOT}/meme_emoji" "$emoji_commit_before" "meme_emoji"
        rollback_repo "${APP_ROOT}/meme_emoji_nsfw" "$nsfw_commit_before" "meme_emoji_nsfw"
        rollback_repo "${APP_ROOT}/meme-generator-jj" "$jj_commit_before" "meme-generator-jj"
        rollback_repo "${APP_ROOT}/tudou-meme" "$tudou_commit_before" "tudou-meme"
        rollback_repo "${APP_ROOT}/meme-generator-cute" "$cute_commit_before" "meme-generator-cute"
      else
        rollback_repo "$rollback_dir" "$rollback_commit" "$label"
      fi
      failures=$((failures + 1))
    fi
  else
    echo "[sync] Dependency installation is disabled; a new image may be required"
  fi
}

main_dep_after="$(manifest_hash "${APP_ROOT}/meme-generator" pyproject.toml requirements.txt setup.py)"
emoji_dep_after="$(manifest_hash "${APP_ROOT}/meme_emoji" requirements.txt pyproject.toml)"
nsfw_dep_after="$(manifest_hash "${APP_ROOT}/meme_emoji_nsfw" requirements.txt pyproject.toml)"

if [ -f "${APP_ROOT}/meme-generator/pyproject.toml" ] || [ -f "${APP_ROOT}/meme-generator/setup.py" ]; then
  install_if_changed "meme-generator" "$main_dep_before" "$main_dep_after" "${APP_ROOT}/meme-generator" "$main_commit_before" "${APP_ROOT}/meme-generator"
elif [ -f "${APP_ROOT}/meme-generator/requirements.txt" ]; then
  install_if_changed "meme-generator" "$main_dep_before" "$main_dep_after" "${APP_ROOT}/meme-generator" "$main_commit_before" -r "${APP_ROOT}/meme-generator/requirements.txt"
fi

if [ -f "${APP_ROOT}/meme_emoji/requirements.txt" ]; then
  install_if_changed "meme_emoji" "$emoji_dep_before" "$emoji_dep_after" "${APP_ROOT}/meme_emoji" "$emoji_commit_before" -r "${APP_ROOT}/meme_emoji/requirements.txt"
fi

if [ -f "${APP_ROOT}/meme_emoji_nsfw/requirements.txt" ]; then
  install_if_changed "meme_emoji_nsfw" "$nsfw_dep_before" "$nsfw_dep_after" "${APP_ROOT}/meme_emoji_nsfw" "$nsfw_commit_before" -r "${APP_ROOT}/meme_emoji_nsfw/requirements.txt"
fi

if [ "$failures" -gt 0 ]; then
  echo "[sync] Completed with ${failures} required update/dependency failure(s)" >&2
  if is_true "$SYNC_STRICT"; then exit 1; fi
else
  echo "[sync] Repository synchronization complete"
fi

exit 0
