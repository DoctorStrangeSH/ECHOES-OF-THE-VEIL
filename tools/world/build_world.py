#!/usr/bin/env python3
"""Build the open world's countryside (R14a, D-096).

Reads data/world/open_world.json (where each outdoor place sits) and fills
everything between and around the places:

  * each place's own edges are carried outwards: along a row from its west and
    east edges (so the avenue's road and pavements run on between towns), a few
    cells up and down from its north and south edges (lanes, quays, grass);
  * the sea rects are water, and so is anything a coastal edge carries north;
  * the rest is grass, dressed the way LimeZu dresses open ground: trees in
    loose clumps, bushes, flowers, a few rocks, nothing on the roads and a
    little breathing room around each place.

The result is cut into chunks (scenes/world/filler/filler_<cx>_<cy>.tscn),
each a Location in chunk mode with one cell of context around it so terrain
edges join across chunk borders. Needs the art pack (sprite sizes).

Usage: python3 tools/world/build_world.py [--check]
"""
import json, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'regions'))
os.chdir(ROOT)
import build_regions as br  # noqa: E402

SPEC = json.load(open(os.path.join(ROOT, 'data', 'world', 'open_world.json')))
OUT_DIR = os.path.join(ROOT, 'scenes', 'world', 'filler')
PALETTE = 'open_world'
H_BLEED = 64
V_BLEED = 5
LAND = 'g'

TREES = ['@ftree/Tree_Oak_Green_Big_16x16.png', '@ftree/Tree_Oak_Green_Medium_16x16.png', '@ftree/Tree_Birch_Green_Big_16x16.png',
         '@ftree/Tree_Pine_Green_Big_16x16.png', '@ftree/Tree_Pine_Dark_Green_Big_16x16.png', '@ftree/Tree_Oak_Blue_Green_Big_16x16.png',
         '@ftree/Tree_Birch_Green_Medium_16x16.png', '@ftree/Tree_Oak_Green_Huge_16x16.png']
BUSHES = ['@garden/Bush_%d.png' % i for i in (1, 2, 3, 4, 5, 6, 7, 8, 9)]
FLOWERS = ['@garden/Small_%s.png' % f for f in ('Pink_Flower', 'Red_Flower', 'White_Flower', 'Yellow_Flower', 'Light_Blue_Flower')] + \
          ['@garden/Medium_%s.png' % f for f in ('Pink_Flower', 'Red_Flower', 'White_Flower', 'Yellow_Flower')]


def region_rects():
    out = {}
    for rid, (x, y) in SPEC['regions'].items():
        rows = br.layout_of(br.load_spec(rid)).split('\n')
        out[rid] = (x, y, len(rows[0]), len(rows), rows)
    return out


def build_grid(regions):
    W, H = SPEC['size']
    grid = [[None] * W for _ in range(H)]
    dist = [[10 ** 6] * W for _ in range(H)]
    owner = [[None] * W for _ in range(H)]
    for rid, (x0, y0, w, h, rows) in regions.items():
        for y in range(h):
            for x in range(w):
                if 0 <= y0 + y < H and 0 <= x0 + x < W:
                    owner[y0 + y][x0 + x] = rid
    for sx, sy, sw, sh in SPEC['sea']:
        for y in range(sy, min(H, sy + sh)):
            for x in range(sx, min(W, sx + sw)):
                if owner[y][x] is None:
                    grid[y][x] = 'w'

    def carry(x, y, ch, d, along_row):
        if not (0 <= x < W and 0 <= y < H) or owner[y][x] is not None:
            return False
        # The sea wins over everything but the avenue running along a row.
        if grid[y][x] == 'w' and dist[y][x] == 10 ** 6 and not (along_row and ch in 'rs' and 108 <= y <= 132):
            return True
        if d < dist[y][x]:
            dist[y][x] = d
            grid[y][x] = ch
        return True

    def reach(col, y):
        """How far a row's edge cell carries sideways: roads and the
        pavements beside them run on; other paving soon gives way to grass."""
        ch = col[y]
        if ch in 'gwr':
            return H_BLEED
        if ch == 's' and any(col[yy] == 'r' for yy in range(max(0, y - 3), min(len(col), y + 4))):
            return H_BLEED
        return 3
    for rid, (x0, y0, w, h, rows) in regions.items():
        west = [r[0] for r in rows]
        east = [r[-1] for r in rows]
        for y in range(h):
            for d in range(1, reach(west, y) + 1):
                if not carry(x0 - d, y0 + y, rows[y][0], d, True):
                    break
            for d in range(1, reach(east, y) + 1):
                if not carry(x0 + w - 1 + d, y0 + y, rows[y][-1], d, True):
                    break
        def lane(row, x):
            """Paths and lanes carry on; a road or pavement running all along
            an edge (a street's side) does not spill outwards."""
            ch = row[x]
            if ch in 'gw':
                return True
            a = x
            while a > 0 and row[a - 1] == ch:
                a -= 1
            b = x
            while b < len(row) - 1 and row[b + 1] == ch:
                b += 1
            return b - a + 1 <= 6
        for x in range(w):
            for d in range(1, V_BLEED + 1):
                ch = rows[0][x]
                if not lane(rows[0], x):
                    break
                if not carry(x0 + x, y0 - d, ch, d + (0 if ch == 'w' else 2), False):
                    break
            for d in range(1, V_BLEED + 1):
                ch = rows[-1][x]
                if not lane(rows[-1], x):
                    break
                if not carry(x0 + x, y0 + h - 1 + d, ch, d + (0 if ch == 'w' else 2), False):
                    break
    for y in range(H):
        for x in range(W):
            if owner[y][x] is not None:
                grid[y][x] = ' '
            elif grid[y][x] is None or grid[y][x] not in 'gsrodpwb':
                grid[y][x] = LAND
    return grid, owner


def dress(grid, owner, rng):
    """Trees in loose clumps, bushes, flowers. Returns prop nodes in world px."""
    W, H = SPEC['size']
    def clear(x, y, r):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if not (0 <= xx < W and 0 <= yy < H) or grid[yy][xx] != LAND:
                    return False
        return True
    nodes = []
    taken = set()
    # Woods and meadows: a coarse random field decides how thick the trees
    # grow; clumps are scattered more densely where it is high.
    gw, gh = W // 24 + 2, H // 24 + 2
    field = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    def wood(x, y):
        fx, fy = x / 24.0, y / 24.0
        ix, iy = int(fx), int(fy)
        tx, ty = fx - ix, fy - iy
        a = field[iy][ix] * (1 - tx) + field[iy][ix + 1] * tx
        b = field[iy + 1][ix] * (1 - tx) + field[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty
    for _ in range(W * H // 70):
        cx, cy = rng.randrange(W), rng.randrange(H)
        if rng.random() > wood(cx, cy) ** 2 or not clear(cx, cy, 3):
            continue
        for _t in range(rng.randint(2, 7)):
            x, y = cx + rng.randint(-4, 4), cy + rng.randint(-3, 3)
            if not clear(x, y, 2) or any((x + dx, y + dy) in taken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            taken.add((x, y))
            nodes.append({'kind': 'prop', 'tex': rng.choice(TREES), 'x': x * 16 + 8, 'y': y * 16 + 14,
                          'color': '#3f7f3f', 'col': [14, 8], 'off': [0, -4]})
    # Street lamps on the pavement along the open road, every so often.
    for y in range(1, H - 1):
        for x in range(0, W, 14):
            if grid[y][x] == 's' and grid[y + 1][x] == 'r' and owner[y][x] is None:
                nodes.append({'kind': 'prop', 'tex': '@city/Street_Lamp_5.png', 'x': x * 16 + 8, 'y': y * 16 + 10,
                              'color': '#555566', 'col': [6, 4], 'off': [0, -2]})
    for y in range(H):
        for x in range(W):
            if (x, y) in taken or not clear(x, y, 1):
                continue
            r = rng.random()
            if r < 0.012:
                nodes.append({'kind': 'prop', 'tex': rng.choice(BUSHES), 'x': x * 16 + 8, 'y': y * 16 + 15,
                              'color': '#4f8f4f', 'col': [12, 6], 'off': [0, -3]})
            elif r < 0.04:
                nodes.append({'kind': 'prop', 'tex': rng.choice(FLOWERS), 'x': x * 16 + 8, 'y': y * 16 + 15,
                              'color': '#c06080', 'col': [0, 0], 'off': [0, 0], 'layer': 'FloorDecor'})
    return nodes


def write_chunks(grid, nodes, check=False):
    W, H = SPEC['size']
    cw, ch = SPEC['chunk']
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = set()
    stale = []
    index = []
    for cy in range(0, H, ch):
        for cx in range(0, W, cw):
            # One cell of context all round: terrain edges see their neighbours.
            rows = []
            empty = True
            for y in range(cy - 1, min(H, cy + ch) + 1):
                row = ''
                for x in range(cx - 1, min(W, cx + cw) + 1):
                    c = grid[y][x] if 0 <= x < W and 0 <= y < H else ' '
                    row += c
                    if c != ' ' and cx <= x < cx + cw and cy <= y < cy + ch:
                        empty = False
                rows.append(row)
            if empty:
                continue
            name = 'filler_%d_%d' % (cx // cw, cy // ch)
            mine = []
            for i, n in enumerate(nodes):
                tx, ty = n['x'] // 16, (n['y'] - 1) // 16
                if cx <= tx < cx + cw and cy <= ty < cy + ch:
                    m = dict(n, x=n['x'] - (cx - 1) * 16, y=n['y'] - (cy - 1) * 16, name='N%d' % i)
                    mine.append(m)
            expanded = br.expand(mine, name)
            path = os.path.join(OUT_DIR, name + '.tscn')
            tmp = path + '.new'
            br.write_tscn(tmp, name, '', PALETTE, '\n'.join(rows), expanded, 0, {'outdoors': True})
            txt = open(tmp).read().replace('layout = "', 'context_margin = 1\nlayout = "', 1)
            os.remove(tmp)
            wanted.add(name)
            index.append({'id': name, 'pos': [cx - 1, cy - 1]})
            if check:
                if not os.path.exists(path) or open(path).read() != txt:
                    stale.append(name)
            else:
                open(path, 'w').write(txt)
    idx_path = os.path.join(ROOT, 'data', 'world', 'filler_index.json')
    idx_txt = json.dumps({'_doc': 'Generated by tools/world/build_world.py: filler chunk scenes and their tile positions.', 'chunks': index}, indent=1)
    if check:
        if not os.path.exists(idx_path) or open(idx_path).read() != idx_txt:
            stale.append('filler_index.json')
        for f in os.listdir(OUT_DIR):
            if f.endswith('.tscn') and f[:-5] not in wanted:
                stale.append(f)
        return stale
    open(idx_path, 'w').write(idx_txt)
    for f in os.listdir(OUT_DIR):
        if f.endswith('.tscn') and f[:-5] not in wanted:
            os.remove(os.path.join(OUT_DIR, f))
    return len(wanted)


def preview(grid, owner, nodes, regions, out):
    """A small overview picture: one pixel per tile."""
    from PIL import Image
    W, H = SPEC['size']
    col = {'g': (86, 150, 80), 's': (200, 196, 186), 'r': (90, 90, 96), 'o': (150, 120, 90), 'd': (170, 140, 100),
           'p': (140, 100, 70), 'w': (60, 110, 170), 'b': (120, 90, 70)}
    im = Image.new('RGB', (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if owner[y][x] is not None:
                rid = owner[y][x]
                x0, y0, w, h, rows = regions[rid]
                c = rows[y - y0][x - x0]
                px[x, y] = tuple(int(v * 0.8) for v in col.get(c, (200, 60, 200)))
            else:
                px[x, y] = col.get(grid[y][x], (255, 0, 255))
    for n in nodes:
        if n.get('layer') != 'FloorDecor':
            px[n['x'] // 16, min(H - 1, n['y'] // 16)] = (30, 80, 30)
    im = im.resize((W * 2, H * 2), Image.NEAREST)
    im.save(out)


def main():
    check = '--check' in sys.argv
    if not os.path.isdir(os.path.join(ROOT, 'assets', 'limezu', 'modern_farm')):
        print('build_world: art pack not present, skipped')
        return
    regions = region_rects()
    grid, owner = build_grid(regions)
    nodes = dress(grid, owner, random.Random(1962))
    if check:
        stale = write_chunks(grid, nodes, check=True)
        if stale:
            raise SystemExit('open world out of date: ' + ', '.join(stale[:8]) + ' (run tools/world/build_world.py)')
        print('open world up to date')
        return
    n = write_chunks(grid, nodes)
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    preview(grid, owner, nodes, regions, os.path.join(ROOT, 'build', 'open_world.png'))
    print('open world: %d filler chunks, %d props' % (n, len(nodes)))


if __name__ == '__main__':
    main()
