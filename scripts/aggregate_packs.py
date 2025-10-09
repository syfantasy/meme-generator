#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Set, Tuple


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".tiff", ".tif"}
VIDEO_EXTS = {".mp4", ".webm", ".mov"}
ALLOWED_EXTS = IMAGE_EXTS | VIDEO_EXTS
SKIP_DIRS = {".git", "node_modules", "dist", "build", ".next", "__pycache__"}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def slugify(text: str) -> str:
    # Lowercase, replace non-alnum with hyphens, collapse repeats
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


def tokenize_keywords(stem: str) -> List[str]:
    parts = re.split(r"[\s_\-\.]+", stem.lower())
    parts = [p for p in parts if p]
    # Deduplicate keeping order
    seen: Set[str] = set()
    out: List[str] = []
    for p in parts:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


@dataclass
class Item:
    id: str
    pack: str
    repo: str
    filename: str
    rel_path: str
    ext: str
    size: int
    sha256: str
    keywords: List[str]


@dataclass
class Pack:
    key: str
    name: str
    repo: str
    count: int
    items: List[Item]


def find_files(root: Path) -> List[Path]:
    paths: List[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # prune directories
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix.lower() in ALLOWED_EXTS:
                paths.append(p)
    return paths


def detect_repo_name(path: Path) -> str:
    name = path.name
    if name == "meme_emoji":
        return "emoji"
    if name == "meme-generator-contrib":
        return "contrib"
    if name == "meme-generator":
        return "main"
    return name


def group_by_pack(root: Path, files: List[Path]) -> Dict[str, List[Path]]:
    groups: Dict[str, List[Path]] = {}
    for f in files:
        rel = f.relative_to(root)
        parts = rel.parts
        pack_key = rel.stem

        # Better heuristics for common layouts:
        # - emoji/<pack>/images/*.png  => pack
        # - memes/<pack>/images/*.png  => pack
        # - meme_generator/memes/<pack>/... => pack
        if len(parts) >= 3 and parts[0] in {"emoji", "memes"}:
            pack_key = parts[1]
        elif len(parts) >= 4 and parts[0] == "meme_generator" and parts[1] == "memes":
            pack_key = parts[2]
        elif len(parts) >= 2:
            # fallback: use first-level directory as pack
            pack_key = parts[0]

        groups.setdefault(pack_key, []).append(f)
    return groups


def aggregate_repo(repo_root: Path, out_assets: Path) -> Tuple[List[Pack], Dict[str, Set[str]]]:
    repo_label = detect_repo_name(repo_root)
    files = find_files(repo_root)
    packs: List[Pack] = []
    key_map: Dict[str, Set[str]] = {}

    by_pack = group_by_pack(repo_root, files)
    for pack_key, pack_files in sorted(by_pack.items()):
        items: List[Item] = []
        display_name = pack_key.replace("-", " ").replace("_", " ")
        display_name = display_name.title()

        for src in sorted(pack_files):
            rel = src.relative_to(repo_root)
            stem = src.stem
            item_key = slugify(stem)
            item_id = f"{pack_key}/{item_key}"
            ext = src.suffix.lower()
            size = src.stat().st_size
            digest = sha256_file(src)
            kws = list(set(tokenize_keywords(stem) + tokenize_keywords(pack_key)))

            # Copy file into assets directory
            dst = out_assets / pack_key / src.name
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not dst.exists():
                shutil.copy2(src, dst)

            items.append(Item(
                id=item_id,
                pack=pack_key,
                repo=repo_label,
                filename=src.name,
                rel_path=str(rel).replace(os.sep, "/"),
                ext=ext,
                size=size,
                sha256=digest,
                keywords=kws,
            ))

            for kw in kws:
                key_map.setdefault(kw, set()).add(item_id)

        packs.append(Pack(
            key=pack_key,
            name=display_name,
            repo=repo_label,
            count=len(items),
            items=items
        ))

    return packs, key_map


def write_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def main() -> int:
    ap = argparse.ArgumentParser(description="Aggregate meme packs and generate static metadata JSONs")
    ap.add_argument("--src", action="append", required=True, help="Source repo directory (repeatable)")
    ap.add_argument("--out-dir", required=True, help="Output directory for assets and JSON files")
    args = ap.parse_args()

    out_dir = Path(args.out_dir).resolve()
    out_assets = out_dir / "assets"
    out_infos = out_dir / "infos.json"
    out_keymap = out_dir / "keyMap.json"

    all_packs: List[Pack] = []
    global_km: Dict[str, Set[str]] = {}

    for src in args.src:
        root = Path(src).resolve()
        if not root.exists():
            print(f"[WARN] Skip missing source: {root}", file=sys.stderr)
            continue
        print(f"[INFO] Scanning {root}")
        packs, km = aggregate_repo(root, out_assets)
        all_packs.extend(packs)
        for k, v in km.items():
            global_km.setdefault(k, set()).update(v)

    # Sort packs by repo then key
    all_packs.sort(key=lambda p: (p.repo, p.key))

    total_items = sum(p.count for p in all_packs)
    generated_at = datetime.now(timezone.utc).isoformat()

    infos = {
        "generatedAt": generated_at,
        "totalPacks": len(all_packs),
        "totalItems": total_items,
        "packs": [
            {
                "key": p.key,
                "name": p.name,
                "repo": p.repo,
                "count": p.count,
                "items": [asdict(it) for it in p.items],
            }
            for p in all_packs
        ],
    }

    key_map_out = {k: sorted(list(v)) for k, v in sorted(global_km.items())}

    write_json(out_infos, infos)
    write_json(out_keymap, key_map_out)

    print(f"[OK] Wrote {out_infos} and {out_keymap}")
    print(f"[OK] Assets copied under: {out_assets}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
