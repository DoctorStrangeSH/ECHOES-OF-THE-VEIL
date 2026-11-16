#!/usr/bin/env python3
"""Tilled fields for the farm (R5): a W x H patch of soil cut from the Modern
Farm terrain autotile (corners, edges, centre), saved to the private art
submodule (assets/limezu/derived/farm/field_<W>x<H>.png). Derived images of
the pack never go into the public repo.

Usage: python3 tools/art/make_field.py 8 5
"""
import os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ART = os.path.join(ROOT, 'assets', 'limezu')
SHEET = ART + '/modern_farm/16x16/1_Terrains_16x16.png'
BLOCK = (0, 8)  # top-left tile of the dry tilled-soil 3x3 block


def make(w, h):
    src = Image.open(SHEET).convert('RGBA')
    out = Image.new('RGBA', (w * 16, h * 16))
    for y in range(h):
        for x in range(w):
            cx = 0 if x == 0 else (2 if x == w - 1 else 1)
            cy = 0 if y == 0 else (2 if y == h - 1 else 1)
            tx, ty = BLOCK[0] + cx, BLOCK[1] + cy
            out.alpha_composite(src.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16)), (x * 16, y * 16))
    os.makedirs(ART + '/derived/farm', exist_ok=True)
    path = ART + f'/derived/farm/field_{w}x{h}.png'
    out.save(path)
    return path


if __name__ == '__main__':
    print(make(int(sys.argv[1]), int(sys.argv[2])))
