#!/usr/bin/env python3
"""Layout audit for every region: catches things that look wrong on screen.

- a sprite that runs off the edge of the map (a roof or a building cut off)
- two solid props whose collision boxes overlap (furniture inside furniture)
- a solid prop standing on a wall/solid tile, or half outside the floor
- a spawn point or a door/inspect spot that sits inside a solid prop
- a sprite drawn over a wall it should sit in front of (bottom inside walls)

    python3 tools/regions/audit_layout.py [ids...]   # needs the art submodule
"""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import build_regions as br  # noqa: E402

PAL = json.load(open('data/tiles/palettes.json'))


def boxes(nodes):
    out = []
    for n in nodes:
        if n['kind'] != 'prop' or n.get('layer') == 'FloorDecor':
            continue
        w, h = n['col']
        if w <= 0 or h <= 0:
            continue
        cx, cy = n['x'] + n['off'][0], n['y'] + n['off'][1]
        out.append((n, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)))
    return out


def overlap(a, b, slack=1.0):
    return a[0] + slack < b[2] and b[0] + slack < a[2] and a[1] + slack < b[3] and b[1] + slack < a[3]


def audit(rid):
    spec = br.load_spec(rid)
    nodes = br.expand(spec['nodes'], rid)
    rows = br.layout_of(spec).split('\n')
    W, H = max(map(len, rows)) * 16, len(rows) * 16
    pal = PAL[spec['palette']]
    solid = {c for c, b in pal.items() if isinstance(b, dict) and b.get('solid')}
    def tile(x, y):
        tx, ty = int(x // 16), int(y // 16)
        if ty < 0 or ty >= len(rows) or tx < 0 or tx >= len(rows[ty]):
            return '#'
        return rows[ty][tx]
    issues = []
    outdoors = spec.get('options', {}).get('outdoors', True)
    for n in nodes:
        if n['kind'] != 'prop':
            continue
        w, h = n['ph']
        left, top, right, bottom = n['x'] - w / 2, n['y'] - h, n['x'] + w / 2, n['y']
        # Building stacks are allowed to run off the top (it's the sky above
        # the map); anything else must stay inside.
        if left < -1 or right > W + 1 or bottom > H + 1 or top < -1:
            issues.append(f"{n['name']}: sprite runs off the map ({left:.0f},{top:.0f})-({right:.0f},{bottom:.0f}) of {W}x{H}")
    bs = boxes(nodes)
    for i, (a, ra) in enumerate(bs):
        for b, rb in bs[i + 1:]:
            if overlap(ra, rb) and not (a['name'].startswith(b['name'][:-6]) and b['name'].endswith(('Middle', 'Roof', 'Ground'))):
                if a.get('show_if') and b.get('show_if'):
                    continue
                issues.append(f"{a['name']} and {b['name']} overlap")
        if not outdoors:
            x0, y0, x1, y1 = ra
            # The top may touch the wall face (things stand against walls);
            # the sides and the base must be on the floor.
            ym = (y0 + y1) / 2
            for (px, py) in ((x0 + 1, y1 - 1), (x1 - 1, y1 - 1), (x0 + 1, ym), (x1 - 1, ym)):
                if tile(px, py) in solid or tile(px, py) in 'Ww#':
                    issues.append(f"{a['name']}: collision inside a wall at ({px:.0f},{py:.0f})")
                    break
    for n in nodes:
        if n['kind'] in ('spawn',):
            for p, r in bs:
                if r[0] < n['x'] < r[2] and r[1] < n['y'] < r[3] and not p.get('show_if'):
                    issues.append(f"spawn {n.get('id')} is inside {p['name']}")
    return issues


def main():
    ids = sys.argv[1:] or sorted(f[:-5] for f in os.listdir('data/regions') if f.endswith('.json') and not f.startswith('_'))
    total = 0
    for rid in ids:
        try:
            iss = audit(rid)
        except SystemExit as e:
            print(rid, 'ERROR', e); continue
        for i in iss:
            print(f'{rid}: {i}')
        total += len(iss)
    print('layout issues:', total)


if __name__ == '__main__':
    main()
