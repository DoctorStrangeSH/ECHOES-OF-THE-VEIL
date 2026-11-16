#!/usr/bin/env python3
"""Import privately owned RPG icon ZIPs into a consistent 32x32 inventory canvas.

Requires Pillow: python -m pip install Pillow
Generated sprites are third-party derivative art. NEVER commit the output to this
public repository. Original pack licenses remain in force.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path

from PIL import Image, ImageEnhance

PACKS = {
    "limezu_weapons": "16x16 Weapons Icons.zip",
    "limezu_swords": "24x24 Swords.zip",
    "limezu_shields": "24x24 Shields.zip",
    "limezu_arsenal": "RPG_ARSENAL_V1.1.zip",
    "raven": "Free - Raven Fantasy Icons.zip",
}


def slug(value: str) -> str:
    value = value.lower().replace(" ", "_")
    return re.sub(r"[^a-z0-9_]+", "_", value).strip("_")


def source_ok(pack: str, path: str, include_raven: bool) -> bool:
    name = path.lower()
    if not name.endswith(".png") or "__macosx" in name:
        return False
    if pack == "raven":
        return include_raven and "/separated files/16x16/" in name
    if pack == "limezu_weapons":
        return name.startswith("weapons/")
    if pack in ("limezu_swords", "limezu_shields"):
        return not Path(path).name.startswith("00")
    if pack == "limezu_arsenal":
        return name.startswith("icons_no_background/") and "complete_" not in name
    return False


def normalize(image: Image.Image, saturation: float) -> Image.Image:
    image = image.convert("RGBA")
    # Palette cohesion: subtle saturation normalization, alpha unchanged.
    alpha = image.getchannel("A")
    image = ImageEnhance.Color(image).enhance(saturation)
    image.putalpha(alpha)
    # Never smooth/resize the original pixels. Center on a fixed 32x32 UI slot.
    if image.width > 32 or image.height > 32:
        raise ValueError(f"Unexpectedly large icon: {image.size}")
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((32 - image.width) // 2, (32 - image.height) // 2))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archives", type=Path, required=True, help="Folder with five ZIP files")
    parser.add_argument("--output", type=Path, default=Path("assets/third_party_icons"))
    parser.add_argument("--include-raven", action="store_true", help="Also import 2,192 Raven 16x16 icons")
    parser.add_argument("--saturation", type=float, default=0.88)
    args = parser.parse_args()
    if not 0.0 <= args.saturation <= 2.0:
        parser.error("--saturation must be between 0 and 2")
    args.output.mkdir(parents=True, exist_ok=True)

    manifest = {"schema": 1, "canvas": [32, 32], "filter": "nearest",
                "saturation": args.saturation, "icons": []}
    for pack, filename in PACKS.items():
        archive_path = args.archives / filename
        if not archive_path.is_file():
            print(f"SKIP absent: {filename}")
            continue
        with zipfile.ZipFile(archive_path) as archive:
            for source in sorted(archive.namelist()):
                if not source_ok(pack, source, args.include_raven):
                    continue
                data = archive.read(source)
                try:
                    image = Image.open(io.BytesIO(data))
                    if image.size not in ((16, 16), (24, 24), (32, 32)):
                        continue
                    image = normalize(image, args.saturation)
                except (OSError, ValueError) as exc:
                    print(f"SKIP invalid: {source}: {exc}")
                    continue
                stem = slug(str(Path(source).with_suffix("")))
                # Distinguish similar filenames without leaking the original ZIPs.
                identifier = pack + "__" + stem
                relative = Path(pack) / (stem + ".png")
                destination = args.output / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                image.save(destination, optimize=True)
                manifest["icons"].append({
                    "id": identifier,
                    "source_pack": pack,
                    "source_file": source,
                    "original_size": list(Image.open(io.BytesIO(data)).size),
                    "ui_file": relative.as_posix(),
                    "sha256": hashlib.sha256(data).hexdigest(),
                })
    manifest_path = args.output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Imported {len(manifest['icons'])} icons into {args.output}.")
    print("NOTICE: Derivative art is private. Do not commit generated directory.")


if __name__ == "__main__":
    main()
