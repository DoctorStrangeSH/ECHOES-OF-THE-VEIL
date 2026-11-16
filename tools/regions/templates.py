"""Reusable region building blocks.

Each template takes keyword arguments from a region spec and returns a list of
nodes (which may themselves call templates). Keep them generic: anything
specific to one place belongs in that region's JSON, not here.
"""


def _cond(n, show_if):
    if show_if is not None:
        n['show_if'] = show_if
    return n


def layout(generator, **kw):
    """Tile layouts built from parameters instead of hand-typed rows."""
    if generator == 'bands':
        # bands: [[tile, rows], ...] top to bottom; carve: [[tile, x, y, w, h], ...]
        rows = []
        for tile, count in kw['bands']:
            rows += [tile * kw['width'] for _ in range(count)]
        grid = [list(r) for r in rows]
        for tile, x, y, w, h in kw.get('carve', []):
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    grid[yy][xx] = tile
        return [''.join(r) for r in grid]
    if generator == 'room':
        # Interior shell: walls, wall face, floor, a doorway in the bottom wall.
        w, h, door_x = kw['width'], kw['height'], kw['door_x']
        door_w = kw.get('door_width', 2)
        rows = ['#' * w, '#' + 'W' * (w - 2) + '#', '#' + 'w' * (w - 2) + '#']
        rows += ['#' + 'f' * (w - 2) + '#' for _ in range(h - 4)]
        rows.append('#' * door_x + 'f' * door_w + '#' * (w - door_x - door_w))
        return rows
    raise SystemExit(f'unknown layout generator {generator}')


def building(tex, x, y, name=None, color='#8a7f99', depth=None, inset=0, door=None, inspect=None, show_if=None):
    """A building single with full-width collision, plus an optional door or inspect at its front.

    door:    {"id", "scene", "spawn", "width"?, "required_flag"?, "locked"?, "spawn_id"?}
             "spawn_id" also adds a spawn point in front, for the way back.
    inspect: {"id", "dialogue"? | "lines"?, "width"?, "prompt"?}
    """
    name = name or tex.rsplit('/', 1)[-1].replace('.png', '')
    p = {'kind': 'prop', 'name': name, 'tex': tex, 'x': x, 'y': y, 'color': color}
    p['_building'] = {'inset': inset, 'depth': depth}  # collision sized from the texture
    nodes = [_cond(p, show_if)]
    if door:
        d = {'kind': 'door', 'name': name + 'Door', 'id': door['id'], 'x': door.get('x', x), 'y': y + 6,
             'area': [door.get('width', 20), 14], 'scene': door['scene'], 'spawn': door['spawn']}
        for k in ('required_flag', 'locked', 'prompt'):
            if k in door:
                d[k] = door[k]
        nodes.append(_cond(d, show_if))
        if door.get('spawn_id'):
            nodes.append({'kind': 'spawn', 'name': name + 'Front', 'id': door['spawn_id'], 'x': door.get('x', x), 'y': y + 20, 'facing': [0, 1]})
    if inspect:
        i = {'kind': 'inspect', 'name': name + 'Look', 'id': inspect['id'], 'x': inspect.get('x', x), 'y': y + 6,
             'area': [inspect.get('width', 30), 14]}
        for k in ('dialogue', 'lines', 'prompt', 'priority'):
            if k in inspect:
                i[k] = inspect[k]
        nodes.append(_cond(i, show_if))
    return nodes


def row(prop, at, name, **overrides):
    """The same prop at several points: at = [[x, y], ...] or {"xs": [...], "y": n}."""
    points = [[x, at['y']] for x in at['xs']] if isinstance(at, dict) else at
    out = []
    for i, (x, y) in enumerate(points):
        n = dict(prop, kind='prop', name=f'{name}{i + 1}', x=x, y=y)
        n.update(overrides)
        out.append(n)
    return out


def anchors(points):
    """NPC schedule anchors: {"anchor_id": [x, y], ...}."""
    return [{'kind': 'anchor', 'name': 'A_' + aid, 'id': aid, 'x': p[0], 'y': p[1]} for aid, p in points.items()]


def sign(tex, x, y, id, name, lines=None, dialogue=None, color='#d0d0d0', show_if=None, width=18):
    """A readable sign, poster or notice: a prop plus a "Read" interaction."""
    p = _cond({'kind': 'prop', 'name': name, 'tex': tex, 'x': x, 'y': y, 'col': [0, 0], 'off': [0, 0], 'color': color}, show_if)
    i = {'kind': 'inspect', 'name': name + 'Read', 'id': id, 'x': x, 'y': y + 6, 'area': [width, 12], 'prompt': 'PROMPT_READ'}
    if lines:
        i['lines'] = lines
    if dialogue:
        i['dialogue'] = dialogue
    return [p, _cond(i, show_if)]


def fixture(tex, x, y, name, use, color='#8a7f99', col=None, show_if=None):
    """A prop with something to do at it. use = {"kind": "spot"|"screen"|"junk"|"inspect", ...}."""
    p = _cond({'kind': 'prop', 'name': name, 'tex': tex, 'x': x, 'y': y, 'color': color}, show_if)
    if col is not None:
        p['col'] = col
    u = dict(use)
    u.setdefault('name', name + 'Use')
    u.setdefault('x', x)
    u.setdefault('y', y + 8)
    if u['kind'] == 'inspect':
        u.setdefault('area', [24, 12])
    return [p, _cond(u, show_if)]


def scatter(tex, name, points, color='#8a7f99', col=(0, 0), layer=None):
    """Decoration with no collision (shells, flowers, litter)."""
    out = []
    for i, (x, y) in enumerate(points):
        n = {'kind': 'prop', 'name': f'{name}{i + 1}', 'tex': tex, 'x': x, 'y': y, 'col': list(col), 'off': [0, 0], 'color': color}
        if layer:
            n['layer'] = layer
        out.append(n)
    return out


FENCE_SHEET = 'modern_farm/16x16/2_Fences_16x16.png'


def fence(x, y, w, h, name, gate=(), gate_side='bottom'):
    """A rail-fence pen, w x h tiles, top-left tile at (x, y) in tiles.
    gate: tile indices left open along gate_side ('bottom' or 'top')."""
    def piece(tx, ty, sx, sy, col, off, n):
        return {'kind': 'prop', 'name': f'{name}{n}', 'tex': FENCE_SHEET, 'region': [sx * 16, sy * 16, 16, 16],
                'x': tx * 16 + 8, 'y': ty * 16 + 16, 'col': col, 'off': off, 'color': '#8a6040'}
    out, n = [], 0
    for i in range(w):
        last = i == w - 1
        for row, sy, side in ((y, 6, 'top'), (y + h - 1, 8, 'bottom')):
            if side == gate_side and i in gate:
                continue
            n += 1
            out.append(piece(x + i, row, 7 if last else 6, sy, [16, 4], [0, -2], n))
    for j in range(1, h - 1):
        n += 1
        out.append(piece(x, y + j, 6, 7, [4, 16], [-6, -8], n))
        n += 1
        out.append(piece(x + w - 1, y + j, 7, 7, [4, 16], [6, -8], n))
    return out


def field(x, y, cols, rows, name, prefix):
    """A tilled field (tools/art/make_field.py makes its picture) with farm
    plots on every inner square. x, y: top-left tile."""
    out = [{'kind': 'prop', 'name': name, 'tex': f'derived/farm/field_{cols}x{rows}.png', 'x': x * 16 + cols * 8,
            'y': (y + rows) * 16, 'col': [0, 0], 'off': [0, 0], 'layer': 'FloorDecor', 'color': '#7a5030'}]
    k = 0
    for j in range(1, rows - 1):
        for i in range(1, cols - 1):
            k += 1
            out.append({'kind': 'plot', 'name': f'{name}Plot{k}', 'id': f'{prefix}_{k}', 'x': (x + i) * 16 + 8, 'y': (y + j) * 16 + 8})
    return out


MODULAR = 'modern_exteriors/Modern_Exteriors_16x16/ME_Theme_Sorter_16x16/5_Floor_Modular_Building_Singles_16x16/ME_Singles_Floor_Modular_Building_16x16_'


def townhouse(x, y, ground, middle, roof, name, door=None, inspect=None, color='#8a6a5a'):
    """A town building from the modular pack: a ground floor (base at y), one
    middle floor and a roof stacked on it. door / inspect as for `building`."""
    import os
    from PIL import Image
    art = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'limezu')
    def h(part):
        return Image.open(os.path.join(art, MODULAR + part + '.png')).size[1]
    hg, hm, hr = h(ground), h(middle), h(roof)
    out = [{'kind': 'prop', 'name': name + 'Ground', 'tex': MODULAR + ground + '.png', 'x': x, 'y': y, 'col': [112, hg - 8], 'off': [0, -(hg - 8) / 2], 'color': color},
           {'kind': 'prop', 'name': name + 'Middle', 'tex': MODULAR + middle + '.png', 'x': x, 'y': y - hg, 'col': [112, hm], 'off': [0, -hm / 2], 'color': color},
           {'kind': 'prop', 'name': name + 'Roof', 'tex': MODULAR + roof + '.png', 'x': x, 'y': y - hg - hm, 'col': [112, hr], 'off': [0, -hr / 2], 'color': '#504040'}]
    if door:
        out.append({'kind': 'door', 'name': name + 'Door', 'id': door['id'], 'x': door.get('x', x), 'y': y + 6, 'area': [door.get('width', 24), 10],
                    'scene': door['scene'], 'spawn': door['spawn'], 'prompt': door.get('prompt', 'PROMPT_ENTER_SHOP')})
        if door.get('spawn_id'):
            out.append({'kind': 'spawn', 'name': name + 'Front', 'id': door['spawn_id'], 'x': door.get('x', x), 'y': y + 18, 'facing': [0, 1]})
    if inspect:
        out.append({'kind': 'inspect', 'name': name + 'Look', 'id': inspect['id'], 'x': inspect.get('x', x), 'y': y + 6, 'area': [inspect.get('width', 60), 10], 'lines': inspect['lines']})
    return out
