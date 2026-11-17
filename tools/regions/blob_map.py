#!/usr/bin/env python3
"""Derive the 47-tile blob layout of LimeZu's Godot autotile sheet.

The sheet (Modern Exteriors, Autotiles_16x16/Godot_Autotiles_16x16.png) holds
26 terrains, each a 12x4 block in Godot 3's "3x3 minimal" layout. We read the
neighbour mask of every tile from block 12 (grass on transparent), whose edges
are easy to see from alpha, and write data/tiles/blob47.json: mask -> [col, row]
inside a block. TilePainter uses it for every block of the sheet.

Mask bits: N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128 (a corner only counts when
both of its sides do).
"""
import json, os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHEET = 'modern_exteriors/Modern_Exteriors_16x16/Autotiles_16x16/Godot_Autotiles_16x16.png'


def main():
    im = Image.open(os.path.join(ROOT, 'assets', 'limezu', SHEET)).convert('RGBA')
    block = 12
    out = {}
    for r in range(4):
        for c in range(12):
            x0, y0 = c * 16, block * 64 + r * 16
            a = lambda x, y: im.getpixel((x0 + x, y0 + y))[3] > 128
            if not a(8, 8):
                continue
            n, s, w, e = a(8, 0), a(8, 15), a(0, 8), a(15, 8)
            m = 0
            for bit, v in [(1, n), (2, n and e and a(15, 0)), (4, e), (8, s and e and a(15, 15)),
                           (16, s), (32, s and w and a(0, 15)), (64, w), (128, n and w and a(0, 0))]:
                if v:
                    m |= bit
            out[str(m)] = [c, r]
    assert len(out) == 47, len(out)
    json.dump({'_doc': __doc__.strip().split('\n\n')[0], 'sheet': SHEET, 'block_size': [12, 4], 'tiles': out},
              open(os.path.join(ROOT, 'data', 'tiles', 'blob47.json'), 'w'), indent=1)
    print('blob47: 47 tiles')


if __name__ == '__main__':
    main()
