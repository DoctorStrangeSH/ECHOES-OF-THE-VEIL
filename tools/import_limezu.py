#!/usr/bin/env python3
"""Import purchased LimeZu packs into the local Godot project.

The packs are licensed for use in your game but NOT for redistribution, so the
extracted files go to `assets/limezu/` and `resources/tilesets/limezu/`, which
are both git-ignored. Every developer runs this script once on their own
machine with their own copies of the archives.

Usage:
    python tools/import_limezu.py --source "C:/path/to/zips"
    python tools/import_limezu.py --source ~/limezu --scales 16 32

What it does:
1. Detects each pack by archive name (prefixes such as "2b1f25e5-" are fine).
2. Extracts every file of the requested scale(s), keeping the original folder
   layout, so provenance stays obvious. Skips installers, Aseprite sources,
   GIF previews, nested ZIPs, RPG Maker variants and Windows metadata.
   Sheets above Godot's 16384 px texture limit are split into _partN files.
3. Copies each pack's license file next to the extracted files.
4. Writes assets/limezu/MANIFEST.json (pack, archive SHA-256, file count).
5. Generates one Godot TileSet (.tres) per tile sheet, registering every
   non-empty 16x16 cell, so sheets can be painted in the editor right away.

Requires Python 3.9+. Pillow is optional; without it TileSets register every
cell instead of only non-empty ones.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

try:
    from PIL import Image  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    Image = None

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSET_ROOT_REL = "assets/limezu"
TILESET_ROOT_REL = "resources/tilesets/limezu"

# pack_id -> (archive name regex, license file names inside the archive)
PACKS = {
    "modern_interiors": (r"moderninteriors", ["LICENSE.txt"]),
    "modern_exteriors": (r"modernexteriors", ["Modern_Exteriors_License.pdf"]),
    "modern_ui": (r"modernuserinterface", ["LICENSE.txt"]),
    "modern_farm": (r"modern_farm", ["LICENSE.txt"]),
    "modern_office": (r"modern_office", ["LICENSE.txt"]),
}

SKIP_EXTENSIONS = {".exe", ".ase", ".aseprite", ".gif", ".zip", ".ini", ".db"}
SKIP_NAMES = {"desktop.ini", "thumbs.db", ".ds_store"}
SKIP_DIR_PATTERN = re.compile(r"rpg_maker", re.IGNORECASE)  # files for another engine
MAX_TEXTURE_SIDE = 16384  # Godot's texture size limit
ALL_SCALES = (16, 32, 48)

# Tile sheets that become TileSets, as glob patterns relative to the pack root.
TILESET_SHEETS = {
    "modern_exteriors": [
        "Modern_Exteriors_{s}x{s}/ME_Theme_Sorter_{s}x{s}/*.png",
        "Modern_Exteriors_{s}x{s}/Autotiles_{s}x{s}/Godot_Autotiles_{s}x{s}.png",
    ],
    "modern_interiors": [
        "1_Interiors/{s}x{s}/Room_Builder_{s}x{s}.png",
        "1_Interiors/{s}x{s}/Interiors_{s}x{s}*.png",
        "1_Interiors/{s}x{s}/Theme_Sorter*/*.png",
    ],
    "modern_farm": [
        "{s}x{s}/*.png",
        "{s}x{s}/Autotiles_{s}x{s}/Autotiles_Godot_{s}x{s}.png",
    ],
    "modern_office": [
        "1_Room_Builder_Office/Room_Builder_Office_{s}x{s}.png",
        "2_Modern_Office_Black_Shadow/*.png",
        "3_Modern_Office_Shadowless/*_{s}x{s}.png",
    ],
}


def detect_pack(archive: Path) -> str | None:
    name = archive.name.lower()
    for pack_id, (pattern, _) in PACKS.items():
        if re.search(pattern, name):
            return pack_id
    return None


def entry_scale(path: str) -> int | None:
    """Return the scale a zip entry belongs to, or None if it has no marker."""
    found = re.findall(r"(16|32|48)x(16|32|48)", path)
    scales = {int(a) for a, b in found if a == b}
    if not scales:
        return None
    return max(scales)  # e.g. ".../16x16/foo_48x48.png" is a 48 asset


def should_extract(path: str, scales: set[int]) -> bool:
    p = PurePosixPath(path)
    if path.endswith("/") or p.name.lower() in SKIP_NAMES:
        return False
    if p.suffix.lower() in SKIP_EXTENSIONS:
        return False
    if any(part.startswith("__MACOSX") or SKIP_DIR_PATTERN.search(part) for part in p.parts):
        return False
    scale = entry_scale(path)
    if scale is None:
        # Unmarked files: in Modern Office "Modern_Office_Black_Shadow.png" is the 16 px sheet.
        return 16 in scales or p.suffix.lower() not in {".png"}
    return scale in scales


def safe_target(root: Path, member: str) -> Path:
    target = (root / member).resolve()
    if root.resolve() not in target.parents and target != root.resolve():
        raise ValueError(f"Unsafe path in archive: {member}")
    return target


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def extract_pack(archive: Path, pack_id: str, scales: set[int], project: Path) -> dict:
    dest = project / ASSET_ROOT_REL / pack_id
    dest.mkdir(parents=True, exist_ok=True)
    count = 0
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            name = info.filename.replace("\\", "/")
            if not should_extract(name, scales):
                continue
            target = safe_target(dest, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, target.open("wb") as out:
                out.write(src.read())
            count += 1
        # License files are always kept, whatever the scale filter says.
        for lic in PACKS[pack_id][1]:
            if lic in zf.namelist():
                (dest / lic).write_bytes(zf.read(lic))
    return {"pack": pack_id, "archive": archive.name, "sha256": sha256_of(archive), "files": count}


def split_oversized(pack_dir: Path, tile: int = 48) -> list[str]:
    """Split sheets larger than Godot's texture limit into stacked parts.

    Cuts on tile boundaries (48 is a multiple of 16, 32 and 48), writes
    <name>_part1.png, <name>_part2.png ... and removes the oversized original
    from the local copy (the purchased archive is untouched).
    """
    done = []
    for png in pack_dir.rglob("*.png"):
        w, h = png_size(png)
        if w <= MAX_TEXTURE_SIDE and h <= MAX_TEXTURE_SIDE:
            continue
        if Image is None:
            print(f"WARNING: {png.name} is {w}x{h}, above Godot's {MAX_TEXTURE_SIDE}px limit. "
                  "Install Pillow and re-run to split it automatically.")
            continue
        step = (MAX_TEXTURE_SIDE // tile) * tile
        with Image.open(png) as im:
            vertical = h > MAX_TEXTURE_SIDE
            length = h if vertical else w
            for i, start in enumerate(range(0, length, step), start=1):
                box = (0, start, w, min(h, start + step)) if vertical else (start, 0, min(w, start + step), h)
                im.crop(box).save(png.with_name(f"{png.stem}_part{i}.png"))
        png.unlink()
        done.append(png.name)
    return done


def non_empty_cells(png: Path, tile: int) -> list[tuple[int, int]]:
    if Image is None:
        return []
    with Image.open(png) as im:
        im = im.convert("RGBA")
        cols, rows = im.width // tile, im.height // tile
        alpha = im.getchannel("A")
        cells = []
        for y in range(rows):
            for x in range(cols):
                if alpha.crop((x * tile, y * tile, (x + 1) * tile, (y + 1) * tile)).getbbox():
                    cells.append((x, y))
        return cells


def png_size(png: Path) -> tuple[int, int]:
    with png.open("rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def write_tileset(png: Path, res_path: str, out: Path, tile: int) -> int:
    cells = non_empty_cells(png, tile)
    if not cells and Image is None:
        w, h = png_size(png)
        cells = [(x, y) for y in range(h // tile) for x in range(w // tile)]
    if not cells:
        return 0
    lines = [
        '[gd_resource type="TileSet" format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{res_path}" id="1_tex"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_1"]',
        'texture = ExtResource("1_tex")',
        f"texture_region_size = Vector2i({tile}, {tile})",
    ]
    lines += [f"{x}:{y}/0 = 0" for x, y in cells]
    lines += [
        "",
        "[resource]",
        f"tile_size = Vector2i({tile}, {tile})",
        "physics_layer_0/collision_layer = 1",
        'sources/0 = SubResource("TileSetAtlasSource_1")',
        "",
    ]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    return len(cells)


def generate_tilesets(project: Path, scales: set[int]) -> int:
    made = 0
    for pack_id, patterns in TILESET_SHEETS.items():
        pack_root = project / ASSET_ROOT_REL / pack_id
        if not pack_root.exists():
            continue
        for s in sorted(scales):
            seen: set[Path] = set()
            for pattern in patterns:
                for png in sorted(pack_root.glob(pattern.format(s=s))):
                    if png in seen or entry_scale(png.as_posix()) not in (s, None):
                        continue
                    seen.add(png)
                    w, h = png_size(png)
                    if w < s * 4 or h < s * 2:
                        continue  # too small to be a sheet
                    rel = png.relative_to(project).as_posix()
                    slug = re.sub(r"[^a-z0-9]+", "_", png.stem.lower()).strip("_")
                    out = project / TILESET_ROOT_REL / f"{s}x{s}" / pack_id / f"{slug}.tres"
                    if write_tileset(png, f"res://{rel}", out, s):
                        made += 1
    return made


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, type=Path, help="folder with the LimeZu .zip archives")
    parser.add_argument("--project", type=Path, default=PROJECT_ROOT, help="Godot project root")
    parser.add_argument("--scales", type=int, nargs="+", default=[16], choices=ALL_SCALES,
                        help="tile scales to import (default: 16, the project's canonical scale)")
    parser.add_argument("--no-tilesets", action="store_true", help="skip TileSet generation")
    args = parser.parse_args()

    if not args.source.is_dir():
        print(f"Source folder not found: {args.source}", file=sys.stderr)
        return 1
    if not (args.project / "project.godot").exists():
        print(f"Not a Godot project root: {args.project}", file=sys.stderr)
        return 1

    scales = set(args.scales)
    manifest = {"generated": datetime.now(timezone.utc).isoformat(), "scales": sorted(scales), "packs": []}
    for archive in sorted(args.source.glob("*.zip")):
        pack_id = detect_pack(archive)
        if pack_id is None:
            print(f"skip  {archive.name} (not a known LimeZu pack)")
            continue
        print(f"unzip {archive.name} -> {ASSET_ROOT_REL}/{pack_id} ...", flush=True)
        info = extract_pack(archive, pack_id, scales, args.project)
        info["split"] = split_oversized(args.project / ASSET_ROOT_REL / pack_id)
        manifest["packs"].append(info)
        print(f"      {info['files']} files" + (f", split oversized: {', '.join(info['split'])}" if info["split"] else ""))

    if not manifest["packs"]:
        print("No LimeZu archives found.", file=sys.stderr)
        return 1

    manifest_path = args.project / ASSET_ROOT_REL / "MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    if not args.no_tilesets:
        if Image is None:
            print("Pillow not installed: TileSets will include empty cells (pip install pillow to fix).")
        made = generate_tilesets(args.project, scales)
        print(f"TileSets generated: {made} -> {TILESET_ROOT_REL}/")

    print("Done. Open the project in Godot; the first import of all textures can take a few minutes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
