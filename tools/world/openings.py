#!/usr/bin/env python3
"""Walkable runs of cells along each edge of an outdoor region: where a road,
path or quay meets the edge of the map. These are the places the open world
can join regions to each other."""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'regions'))
import build_regions as br

PAL = json.load(open(os.path.join(br.ROOT, 'data', 'tiles', 'palettes.json')))


def openings(rid):
    spec = br.load_spec(rid)
    rows = br.layout_of(spec).split('\n')
    pal = PAL[spec['palette']]
    H, W = len(rows), len(rows[0])
    def walk(ch):
        return ch not in ' .' and ch in pal and not pal[ch].get('solid', False)
    out = []
    edges = {'N': [(x, 0) for x in range(W)], 'S': [(x, H - 1) for x in range(W)],
             'W': [(0, y) for y in range(H)], 'E': [(W - 1, y) for y in range(H)]}
    for side, cells in edges.items():
        run = []
        for (x, y) in cells + [(-1, -1)]:
            ok = x >= 0 and walk(rows[y][x])
            if ok:
                run.append((x, y))
            elif run:
                a, b = run[0], run[-1]
                chars = ''.join(sorted(set(rows[c[1]][c[0]] for c in run)))
                out.append({'side': side, 'from': a[1] if side in 'WE' else a[0], 'to': b[1] if side in 'WE' else b[0], 'chars': chars})
                run = []
    return W, H, out


if __name__ == '__main__':
    for rid in sys.argv[1:]:
        W, H, ops = openings(rid)
        print(rid, W, H)
        for o in ops:
            print('   ', o)
