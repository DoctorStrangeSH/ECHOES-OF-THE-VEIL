#!/usr/bin/env python3
"""Renders the city map pictures: every street district in
data/world/city_map.json, drawn from its region spec (tiles and props, no
debug marks) and scaled down. The pictures contain LimeZu art, so they go to
the PRIVATE art submodule (assets/limezu/derived/maps/), never the public repo.

    python3 tools/regions/render_maps.py
"""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import build_regions as br  # noqa: E402

OUT = 'assets/limezu/derived/maps'
SCALE = 4


def main():
    os.makedirs(OUT, exist_ok=True)
    cm = json.load(open('data/world/city_map.json'))
    for did, d in cm['districts'].items():
        rid = d['scenes'][0]
        spec = br.load_spec(rid)
        nodes = br.expand(spec['nodes'], rid)
        tmp = os.path.join(OUT, rid + '_full.png')
        br.preview(tmp, spec['palette'], br.layout_of(spec), nodes, clean=True)
        im = Image.open(tmp)
        im = im.resize((im.width // SCALE, im.height // SCALE), Image.BOX)
        im.save(os.path.join(OUT, rid + '.png'))
        os.remove(tmp)
        print(did, rid, im.size)


if __name__ == '__main__':
    main()
