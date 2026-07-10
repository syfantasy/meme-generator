# Unified Meme Generator Image (GHCR)

This repo builds a unified Docker image that bundles:

- Main app: `MemeCrafters/meme-generator`
- Contrib pack: `MemeCrafters/meme-generator-contrib`
- Emoji pack: `anyliew/meme_emoji`
- Emoji NSFW pack: `anyliew/meme_emoji_nsfw`
- JJ pack: `jinjiao007/meme-generator-jj`
- Tudou pack: `LRZ9712/tudou-meme`
- Cute pack: `AIGC-Yunzai/meme-generator-cute`

During the Docker build, all packs are scanned and aggregated into two static JSON files for fast lookup:

- `infos.json`: detailed information for all packs and items
- `keyMap.json`: keyword -> item id mapping

The aggregated assets and JSON are placed under `/app/data` in the image.

## Runtime Upstream Updates

The image keeps a build-time snapshot of every upstream repository and updates
those working trees before the API starts. A Render redeploy/restart or a
Hugging Face Space restart therefore picks up normal meme code and asset
updates without rebuilding and publishing this image.

The bundled snapshot remains available as a fallback. If GitHub is temporarily
unavailable, startup logs a warning and continues with the version already in
the image.

Runtime controls:

- `MEME_SYNC_ENABLED` — enable startup sync, default `true`
- `MEME_SYNC_STRICT` — fail startup when the required main repository or a
  dependency refresh fails, default `false`
- `MEME_SYNC_INSTALL_DEPS` — install changed Python dependency manifests;
  `auto` by default, or set to `false` to require image rebuilds for deps
- `MEME_SYNC_GIT_TIMEOUT` — timeout for each Git operation in seconds, default
  `300`
- `MEME_APP_ROOT` — repository root inside the image, default `/app`

The `*_REPO` and `*_REF` variables shown in the Dockerfile can also be
overridden at runtime. Adding a completely new repository, changing native
system packages, or adapting to a breaking upstream API still requires a new
image build.

The live render API and the dynamic `infos.json` / `keyMap.json` endpoints use
the updated source trees. `/app/data/assets` is the build-time aggregate and is
kept mainly as a static fallback.

## Build Locally

Requires Docker with Buildx.

```
docker build \
  --build-arg MEME_GENERATOR_REF=main \
  --build-arg CONTRIB_REF=main \
  --build-arg EMOJI_REF=main \
  --build-arg NSFW_REF=main \
  --build-arg JJ_REF=main \
  --build-arg TUDOU_REF=main \
  --build-arg CUTE_REF=main \
  -t unified-meme:dev .
```

Run:

```
docker run --rm -p 8000:8000 unified-meme:dev
```

If the main app start script is not auto-detected, the container falls back to serving `/app/data` statically on port 8000 so you can inspect `infos.json`, `keyMap.json`, and assets under `/app/data/assets`.

FastAPI/Custom start override:

- Provide `APP_START_CMD` to force the start command, e.g.:

```
docker run --rm -p 8000:8000 \
  -e APP_START_CMD='uvicorn main:app --host 0.0.0.0 --port 8000' \
  unified-meme:dev
```

Static fallback paths:

- When auto-start fails, the entrypoint exposes the aggregated metadata under:
  - `http://localhost:8000/memes/static/infos.json`
  - `http://localhost:8000/memes/static/keyMap.json`
  - `http://localhost:8000/memes/static/assets/`

## GitHub Actions (GHCR)

This repo includes a workflow: `.github/workflows/build-and-push.yml`

Triggering:

- Push to `main`
- Manual run via "Run workflow"

Permissions:

- Uses the `GITHUB_TOKEN` with `packages: write` to push to `ghcr.io`

Tags pushed:

- `ghcr.io/<owner>/<repo>:sha-<git-sha>` (always)
- `ghcr.io/<owner>/<repo>:latest` (on `main`)

Customizing refs for the repos (manual run):

- `meme_generator_ref` (default: `main`)
- `contrib_ref` (default: `main`)
- `emoji_ref` (default: `main`)
- `nsfw_ref` (default: `main`)
- `jj_ref` (default: `main`)
- `tudou_ref` (default: `main`)
- `cute_ref` (default: `main`)

## Image Layout

- `/app/meme-generator` — cloned main app sources
- `/app/meme-generator-cute` — cloned AIGC-Yunzai cute meme pack
- `/app/data/assets/<pack>/...` — consolidated assets from all repos
- `/app/data/infos.json` — detailed metadata
- `/app/data/keyMap.json` — keyword -> item id mapping

`MEME_DATA_DIR` env var defaults to `/app/data`.

## Notes

- The Dockerfile attempts to install Node or Python dependencies for the main app if detected. If your app requires a specific start command, extend `scripts/entrypoint.sh` accordingly.
- Aggregation is heuristic-based (by file types and top-level directories). If your repos contain a formal metadata file, you can adapt `scripts/aggregate_packs.py` to parse and merge that instead.

## Translator (OpenAI-compatible)

The upstream `meme-generator` includes a Baidu translator used by some memes (e.g., `dianzhongdian`). This image can also use an OpenAI-compatible API (such as newapi) by providing the following environment variables. The entrypoint will write a minimal config to `XDG_CONFIG_HOME=/app/config/meme_generator/config.toml` automatically.

- `TRANSLATOR_PROVIDER` — `openai` or `baidu` (default: auto; picks `openai` if `OPENAI_API_KEY` is set, else `baidu` if Baidu creds are set)
- `OPENAI_BASE_URL` — e.g. `https://new1.588686.xyz/v1`
- `OPENAI_API_KEY` — your API key
- `OPENAI_MODEL` — e.g. `gemini-flash-lite-latest`
- `BAIDU_TRANS_APPID`, `BAIDU_TRANS_APIKEY` — if you still want Baidu

Example (OpenAI-compatible via newapi):

```
docker run --rm -p 8000:8000 \
  -e TRANSLATOR_PROVIDER=openai \
  -e OPENAI_BASE_URL=https://api.openai.com/v1 \
  -e OPENAI_API_KEY=sk-*** \
  -e OPENAI_MODEL=gpt-4.1-mini \
  unified-meme:dev
```
