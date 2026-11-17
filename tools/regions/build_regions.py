#!/usr/bin/env python3
"""Build location scenes from region specs (data/regions/*.json).

A region spec is data: a tile layout (rows of palette characters), scene options
and a list of nodes. A node is either a plain node (kind = prop, door, inspect,
spawn, npc, enemy, ...) or a template call ({"template": "building", ...}) that
expands into several nodes; templates live in templates.py.

Texture paths may start with an alias from data/regions/_aliases.json, e.g.
"@city/Fountain_1.png". Prop sizes are read from the LimeZu art, so this tool
needs the private art submodule (assets/limezu); the game itself does not.

Usage:
  python3 tools/regions/build_regions.py                 # build every region
  python3 tools/regions/build_regions.py harbour --preview
  python3 tools/regions/build_regions.py --check         # fail if scenes are stale
  python3 tools/regions/build_regions.py --format        # rewrite specs canonically
"""
import argparse, json, os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.dirname(__file__))
import templates  # noqa: E402

ART = os.path.join(ROOT, 'assets', 'limezu')
REGIONS = os.path.join(ROOT, 'data', 'regions')
PREVIEWS = os.path.join(ROOT, 'build', 'region_previews')
PAL = json.load(open(os.path.join(ROOT, 'data', 'tiles', 'palettes.json')))
ALIASES = json.load(open(os.path.join(REGIONS, '_aliases.json')))
SRC = {'modern_exteriors': ART + '/modern_exteriors', 'modern_interiors': ART + '/modern_interiors'}
_sizes = {}


def local(p):
    pack, rest = p.split('/', 1)
    return SRC.get(pack, ART + '/' + pack) + '/' + rest


def size(p):
    if p not in _sizes:
        _sizes[p] = Image.open(local(p)).size
    return _sizes[p]


def resolve_tex(t):
    if t.startswith('@'):
        alias, rest = t[1:].split('/', 1)
        if alias not in ALIASES:
            raise SystemExit(f'unknown texture alias @{alias}')
        return ALIASES[alias] + rest
    return t


FURNITURE = None


def furn_to_prop(n, ctx):
    """A furniture-library item (data/world/furniture.json) as a prop whose
    collision hugs the sprite's visible pixels."""
    global FURNITURE
    if FURNITURE is None:
        FURNITURE = {k: v for k, v in json.load(open('data/world/furniture.json')).items() if not k.startswith('_')}
    fid = n['furn']
    if fid not in FURNITURE:
        raise SystemExit(f'{ctx}: unknown furniture {fid}')
    f = FURNITURE[fid]
    p = {k: v for k, v in n.items() if k not in ('furn', 'kind', 'depth')}
    p['kind'] = 'prop'
    p['tex'] = f['tex']
    p.setdefault('name', fid.title().replace('_', '') + '_%d_%d' % (n['x'], n['y']))
    p.setdefault('color', '#8a7a6a')
    if f.get('layer'):
        p.setdefault('layer', f['layer'])
    path = local(resolve_tex(f['tex']))
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    bb = im.getchannel('A').getbbox() or (0, 0, w, h)
    depth = int(n.get('depth', f.get('depth', 8)))
    if depth <= 0:
        p['col'], p['off'] = [0, 0], [0, 0]
    else:
        bw = bb[2] - bb[0]
        p['col'] = [max(4, bw - 2), depth]
        p['off'] = [(bb[0] + bb[2]) / 2 - w / 2, -h + bb[3] - depth / 2]
    return p


def finish_prop(n):
    """Fill prop defaults: real texture path, placeholder size, collision box."""
    n = dict(n)
    n['tex'] = resolve_tex(n['tex'])
    if not os.path.exists(local(n['tex'])):
        raise SystemExit(f'missing texture for {n.get("name")}: {n["tex"]}')
    w, h = (n['region'][2], n['region'][3]) if n.get('region') else size(n['tex'])
    b = n.pop('_building', None)
    if b is not None:
        d = b['depth'] or h
        n['col'], n['off'] = [w - b['inset'], d], [0, -d / 2]
    col = n.get('col') or [w - 4, 8]
    n['col'] = col
    n.setdefault('off', [0, -col[1] / 2])
    n['ph'] = (w, h)
    n.setdefault('color', '#8a7f99')
    n.setdefault('layer', 'Entities')
    n.setdefault('children', ())
    n.setdefault('show_if', None)
    n.setdefault('region', None)
    return n


def expand(nodes, ctx):
    out = []
    for n in nodes:
        if 'template' in n:
            fn = getattr(templates, n['template'], None)
            if fn is None or n['template'].startswith('_'):
                raise SystemExit(f'{ctx}: unknown template {n["template"]}')
            args = {k: v for k, v in n.items() if k != 'template'}
            out += expand(fn(**args), ctx)
        else:
            if n['kind'] == 'furn':
                n = furn_to_prop(n, ctx)
            out.append(finish_prop(n) if n['kind'] == 'prop' else n)
    return out


# Wall hangings and plants for the dressing pass, by room theme. LimeZu's own
# sample rooms never leave a stretch of wall bare and put plants in free
# corners; this does the same for rooms that ask for it with "dress".
_ART = 'modern_interiors/1_Interiors/16x16/Theme_Sorter_Singles/'
_P = {'pic': [_ART + '7_Art_Singles/Art_Singles_%d.png' % i for i in range(41, 47)],
      'collage': [_ART + '4_Bedroom_Singles/Bedroom_Singles_452.png'],
      'shelf': [_ART + '2_Living_Room_Singles/Living_Room_Singles_%d.png' % i for i in (59, 60, 61, 62)],
      'lights': [_ART + '2_Living_Room_Singles/Living_Room_Singles_12.png', _ART + '4_Bedroom_Singles/Bedroom_Singles_463.png'],
      'bunting': [_ART + '4_Bedroom_Singles/Bedroom_Singles_461.png', _ART + '4_Bedroom_Singles/Bedroom_Singles_462.png'],
      'board': [_ART + '5_Classroom_and_Library_Singles/Classroom_and_Library_Singles_%d.png' % i for i in (32, 33)],
      'map': [_ART + '5_Classroom_and_Library_Singles/Classroom_and_Library_Singles_31.png'],
      'frame': [_ART + '4_Bedroom_Singles/Bedroom_Singles_%d.png' % i for i in (427, 428)],
      'lamp': [_ART + '4_Bedroom_Singles/Bedroom_Singles_471.png'],
      'plant': [_ART + '2_Living_Room_Singles/Living_Room_Singles_%d.png' % i for i in (13, 14, 16, 17, 18)]}
THEMES = {
    'home': ['pic', 'shelf', 'collage', 'pic', 'lamp', 'shelf', 'pic', 'lights'],
    'shop': ['board', 'shelf', 'pic', 'bunting', 'shelf', 'pic'],
    'cafe': ['pic', 'bunting', 'shelf', 'board', 'pic', 'lights'],
    'tavern': ['pic', 'shelf', 'lights', 'pic', 'shelf', 'lamp'],
    'office': ['board', 'pic', 'map', 'shelf', 'pic', 'frame'],
    'bare': ['frame', 'pic'],
}


def dress(nodes, layout, opts, rid):
    """Extra props: hangings along every free stretch of the back wall and
    plants in free floor corners. Deterministic for a given room."""
    rows = layout.split('\n')
    wall_rows = [y for y, r in enumerate(rows) if 'W' in r or 'w' in r]
    if not wall_rows:
        return []
    top, bot = wall_rows[0] * 16, (wall_rows[-1] + 1) * 16
    cols = [x for x, ch in enumerate(rows[wall_rows[0]]) if ch == 'W']
    theme = THEMES[opts.get('theme', 'home')]
    gap_px = int(opts.get('spacing', 40))
    seed = sum(map(ord, rid)) + int(opts.get('seed', 0))

    def sprite_box(n):
        w, h = n['ph']
        if n.get('region'):
            return (n['x'] - w / 2, n['y'] - h, n['x'] + w / 2, n['y'])
        im = Image.open(local(n['tex'])).convert('RGBA')
        bb = im.getchannel('A').getbbox() or (0, 0, w, h)
        return (n['x'] - w / 2 + bb[0], n['y'] - h + bb[1], n['x'] - w / 2 + bb[2], n['y'] - h + bb[3])

    props = [n for n in nodes if n['kind'] == 'prop']
    boxes = [sprite_box(n) for n in props]
    taken = sorted((b[0] - 4, b[2] + 4) for b in boxes if b[1] < bot - 2 and b[3] > top + 2)
    for n in nodes:  # doors cut into the back wall
        if n['kind'] == 'door' and n['y'] < bot + 8:
            taken.append((n['x'] - n['area'][0] / 2 - 4, n['x'] + n['area'][0] / 2 + 4))
    out = []
    k = seed
    segs = []
    x0 = None
    for x in range(min(cols), max(cols) + 2):
        if x in cols and x0 is None:
            x0 = x
        if x not in cols and x0 is not None:
            segs.append((x0 * 16 + 6, x * 16 - 6))
            x0 = None
    for a, b in segs:
        free = [(a, b)]
        for t0, t1 in sorted(taken):
            nxt = []
            for f0, f1 in free:
                if t1 <= f0 or t0 >= f1:
                    nxt.append((f0, f1))
                else:
                    if t0 > f0: nxt.append((f0, t0))
                    if t1 < f1: nxt.append((t1, f1))
            free = nxt
        for f0, f1 in free:
            width = f1 - f0
            slots = int((width + gap_px / 2) // gap_px)
            for i in range(slots):
                kind = theme[k % len(theme)]
                k += 1
                tex = _P[kind][k % len(_P[kind])]
                w, h = size(tex)
                if w > width - 2:
                    tex = _P['pic'][k % len(_P['pic'])]
                    w, h = size(tex)
                    if w > width - 2:
                        continue
                cx = f0 + width * (i + 0.5) / slots
                im = Image.open(local(tex)).convert('RGBA')
                bb = im.getchannel('A').getbbox()
                mid = (top + bot) / 2 - 1
                y = int(mid + h - (bb[1] + bb[3]) / 2)
                out.append({'kind': 'prop', 'name': 'Dress%d_%d' % (int(cx), y), 'tex': tex, 'x': int(cx), 'y': y,
                            'col': [0, 0], 'off': [0, 0], 'color': '#7a6a5a', 'layer': 'FloorDecor'})
    # Plants in free floor corners.
    floor = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'f']
    if floor and opts.get('plants', 2):
        fx0 = min(x for x, _ in floor) * 16; fx1 = (max(x for x, _ in floor) + 1) * 16
        fy1 = max(y for _, y in floor if y < len(rows) - 1) * 16 + 16
        spots = [(fx0 + 10, fy1 - 2), (fx1 - 10, fy1 - 2), (fx0 + 10, bot + 18), (fx1 - 10, bot + 18)]
        placed = 0
        for sx, sy in spots:
            if placed >= int(opts.get('plants', 2)):
                break
            clear = all(not (b[0] - 10 < sx < b[2] + 10 and b[1] - 6 < sy < b[3] + 14) for b in boxes)
            clear = clear and all(abs(n['x'] - sx) > 26 or abs(n['y'] - sy) > 26 for n in nodes
                                  if n['kind'] in ('door', 'spawn', 'inspect', 'rest', 'anchor', 'pickup'))
            if clear:
                tex = _P['plant'][(seed + placed) % len(_P['plant'])]
                out.append({'kind': 'prop', 'name': 'DressPlant%d' % placed, 'tex': tex, 'x': sx, 'y': sy,
                            'col': [10, 6], 'off': [0, -3], 'color': '#3f6f4f'})
                boxes.append((sx - 8, sy - 24, sx + 8, sy))
                placed += 1
    return [finish_prop(n) for n in out]


def layout_of(spec):
    lay = spec['layout']
    if isinstance(lay, dict):
        lay = templates.layout(**lay)
    return '\n'.join(lay)


def options_of(spec):
    opts = {}
    for k, v in spec.get('options', {}).items():
        opts[k] = tuple(v['color']) if isinstance(v, dict) and set(v) == {'color'} else v
    return opts


def scene_path(rid):
    return os.path.join(ROOT, 'scenes', 'locations', rid + '.tscn')


def write_tscn(path, loc_id, name_key, palette, layout, nodes, margin=0, opts=None):
    import json as _j
    opts=opts or {}
    ext=[('Script','res://scripts/world/location.gd','1_loc'),('Script','res://scripts/world/tile_painter.gd','2_paint'),
         ('PackedScene','res://scenes/props/world_prop.tscn','3_prop'),('Script','res://scripts/world/spawn_point.gd','4_spawn'),
         ('Script','res://scripts/interaction/inspect_interactable.gd','5_inspect'),('Script','res://scripts/interaction/door_interactable.gd','6_door'),
         ('Script','res://scripts/interaction/rest_interactable.gd','7_rest'),('PackedScene','res://scenes/npcs/npc.tscn','8_npc'),
         ('Script','res://scripts/world/veil_shimmer.gd','9_shimmer'),('Script','res://scripts/world/conditional_visibility.gd','10_cond'),
         ('Script','res://scripts/world/npc_anchor.gd','11_anchor'),('PackedScene','res://scenes/combat/echo_enemy.tscn','12_enemy'),
         ('Script','res://scripts/combat/encounter.gd','13_encounter'),('PackedScene','res://scenes/combat/census_taker.tscn','14_boss'),
         ('Script','res://scripts/combat/boss_arena.gd','15_arena'),('PackedScene','res://scenes/world/item_pickup.tscn','16_pickup'),
         ('PackedScene','res://scenes/world/repair_spot.tscn','17_spot'),('PackedScene','res://scenes/world/screen_interactable.tscn','18_screen'),
         ('PackedScene','res://scenes/world/junk_pile.tscn','19_junk')]
    if any(n['kind'] == 'plot' for n in nodes):
        ext.append(('Script', 'res://scripts/farm/farm_plot.gd', '%d_plot' % (len(ext) + 1)))
    if any(n['kind'] == 'forage' for n in nodes):
        ext.append(('Script', 'res://scripts/farm/forage_spot.gd', '%d_forage' % (len(ext) + 1)))
    if any(n['kind'] == 'critter' for n in nodes):
        ext.append(('Script', 'res://scripts/farm/critter.gd', '%d_critter' % (len(ext) + 1)))
    for n in nodes:  # bosses other than the Census Taker bring their own scene
        if n['kind'] == 'boss' and n.get('scene') and not any(e[1] == n['scene'] for e in ext):
            ext.append(('PackedScene', n['scene'], f'{len(ext) + 1}_boss_{n["name"].lower()}'))
    L=['[gd_scene format=3]','']
    for t,p,i in ext: L.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
    L+=['',f'[node name="{loc_id.title().replace("_","")}" type="Node2D"]','script = ExtResource("1_loc")',f'location_id = &"{loc_id}"',f'name_key = "{name_key}"']
    if margin: L.append(f'camera_margin_tiles = {margin}')
    for k,v in opts.items():
        if isinstance(v,bool): L.append(f'{k} = {"true" if v else "false"}')
        elif isinstance(v,dict): L.append(f'{k} = {_j.dumps(v)}')
        elif isinstance(v,tuple): L.append(f'{k} = Color({v[0]}, {v[1]}, {v[2]}, {v[3]})')
        elif isinstance(v,str) and k.endswith('_id'): L.append(f'{k} = &"{v}"')
        else: L.append(f'{k} = {_j.dumps(v)}')
    lay=layout
    L+=['','[node name="Ground" type="TileMapLayer" parent="."]','script = ExtResource("2_paint")',f'palette_id = "{palette}"',f'layout = "{lay}"']
    L+=['','[node name="FloorDecor" type="Node2D" parent="."]','','[node name="Entities" type="Node2D" parent="."]','y_sort_enabled = true','','[node name="SpawnPoints" type="Node2D" parent="."]','','[node name="NpcAnchors" type="Node2D" parent="."]']
    def psa(a): return 'PackedStringArray(' + ', '.join(f'"{s}"' for s in a) + ')'
    def v(x,y): return f'Vector2({x:g}, {y:g})'
    for n in nodes:
        k=n['kind']; L.append('')
        if k=='prop':
            L.append(f'[node name="{n["name"]}" parent="{n["layer"]}" instance=ExtResource("3_prop")]')
            L+= [f'position = {v(n["x"],n["y"])}', f'texture_path = "{n["tex"]}"', f'placeholder_size = Vector2i({n["ph"][0]}, {n["ph"][1]})',
                 f'placeholder_color = Color.html("{n["color"]}")' if False else f'placeholder_color = Color({",".join(f"{c/255:.3f}" for c in bytes.fromhex(n["color"][1:]))}, 1)',
                 f'collision_size = {v(*n["col"])}', f'collision_offset = {v(*n["off"])}']
            if n.get('region'): L.append('region = Rect2(%d, %d, %d, %d)' % tuple(n['region']))
            for ch in n['children']:
                L+=['',f'[node name="{ch}" type="Node" parent="{n["layer"]}/{n["name"]}"]','script = ExtResource("9_shimmer")']
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="{n["layer"]}/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k=='spawn':
            L+=[f'[node name="{n["name"]}" type="Marker2D" parent="SpawnPoints"]',f'position = {v(n["x"],n["y"])}','script = ExtResource("4_spawn")',f'spawn_id = &"{n["id"]}"',f'facing = {v(*n["facing"])}']
        elif k in ('inspect','door','rest'):
            sid={'inspect':'5_inspect','door':'6_door','rest':'7_rest'}[k]
            L+=[f'[node name="{n["name"]}" type="Area2D" parent="Entities"]',f'position = {v(n["x"],n["y"])}',f'script = ExtResource("{sid}")',
                f'interaction_id = &"{n["id"]}"', f'area_size = {v(*n["area"])}']
            if 'prompt' in n: L.append(f'prompt_key = "{n["prompt"]}"')
            if 'priority' in n: L.append(f'interaction_priority = {n["priority"]}')
            if k=='inspect':
                if n.get('dialogue'): L.append(f'dialogue_id = &"{n["dialogue"]}"')
                if n.get('speaker'): L.append(f'speaker_key = "{n["speaker"]}"')
                if n.get('lines'): L.append(f'lines = {psa(n["lines"])}')
                if n.get('flag'): L.append(f'sets_flag = &"{n["flag"]}"')
                if n.get('repeat'): L.append(f'repeat_lines = {psa(n["repeat"])}')
            if k=='door':
                L+=[f'target_scene_id = &"{n["scene"]}"',f'target_spawn_id = &"{n["spawn"]}"']
                if n.get('required_flag'): L.append(f'required_flag = &"{n["required_flag"]}"')
                if n.get('locked'): L.append(f'locked_lines = {psa(n["locked"])}')
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="Entities/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k=='anchor':
            L+=[f'[node name="{n["name"]}" type="Marker2D" parent="NpcAnchors"]',f'position = {v(n["x"],n["y"])}','script = ExtResource("11_anchor")',f'anchor_id = &"{n["id"]}"']
        elif k=='enemy':
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("12_enemy")]',f'position = {v(n["x"],n["y"])}',f'enemy_id = &"{n["id"]}"']
            if n.get('variant'): L.append(f'variant = "{n["variant"]}"')
        elif k=='boss':
            bid = next(e[2] for e in ext if e[1] == n['scene']) if n.get('scene') else '14_boss'
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("{bid}")]',f'position = {v(n["x"],n["y"])}']
            for k, val in n.get('set', {}).items():  # per-instance exports, e.g. a boss's pattern
                L.append(f'{k} = ' + (f'"{val}"' if isinstance(val, str) else json.dumps(val)))
        elif k=='arena':
            L+=[f'[node name="BossArena" type="Area2D" parent="."]',f'position = {v(n["x"],n["y"])}','script = ExtResource("15_arena")',
                f'boss_path = NodePath("../Entities/{n["boss"]}")',f'engaged_flag = &"{n["flag"]}"',f'area_size = {v(*n["size"])}']
        elif k=='pickup':
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("16_pickup")]',f'position = {v(n["x"],n["y"])}',
                f'interaction_id = &"{n["flag"].replace(".","_")}"',f'item_id = &"{n["item"]}"',f'pickup_flag = &"{n["flag"]}"']
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="Entities/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k in ('spot','screen','junk'):
            rid={'spot':'17_spot','screen':'18_screen','junk':'19_junk'}[k]
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("{rid}")]',f'position = {v(n["x"],n["y"])}',f'interaction_id = &"{n["id"]}"']
            if k=='spot': L.append(f'spot_id = &"{n["spot"]}"')
            if k=='screen': L.append(f'screen = "{n["screen"]}"')
            if n.get('prompt'): L.append(f'prompt_key = "{n["prompt"]}"')
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="Entities/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k=='plot':
            pid = next(e[2] for e in ext if e[1].endswith('farm_plot.gd'))
            L+=[f'[node name="{n["name"]}" type="Area2D" parent="Entities"]',f'position = {v(n["x"],n["y"])}',f'script = ExtResource("{pid}")',
                f'interaction_id = &"plot_{n["id"]}"', f'plot_id = &"{n["id"]}"']
        elif k=='forage':
            fid = next(e[2] for e in ext if e[1].endswith('forage_spot.gd'))
            L+=[f'[node name="{n["name"]}" type="Area2D" parent="Entities"]',f'position = {v(n["x"],n["y"])}',f'script = ExtResource("{fid}")',
                f'interaction_id = &"forage_{n["id"]}"', f'forage_id = &"{n["id"]}"', f'item_id = &"{n["item"]}"', f'amount = {n.get("amount", 1)}',
                f'texture_path = "{resolve_tex(n["tex"])}"']
            if n.get('picked'): L.append(f'picked_texture_path = "{resolve_tex(n["picked"])}"')
        elif k=='critter':
            cid = next(e[2] for e in ext if e[1].endswith('critter.gd'))
            L+=[f'[node name="{n["name"]}" type="Node2D" parent="Entities"]',f'position = {v(n["x"],n["y"])}',f'script = ExtResource("{cid}")',
                f'texture_path = "{resolve_tex(n["tex"])}"', f'frame_size = {n.get("frame", 16)}',
                'pen = Rect2(%g, %g, %g, %g)' % tuple(n.get('pen', [-24, -16, 48, 32])), f'speed = {n.get("speed", 10.0)}']
            if n.get('hen'): L.append(f'hen = {n["hen"]}')
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="Entities/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k=='encounter':
            L+=[f'[node name="Encounter" type="Node" parent="."]','script = ExtResource("13_encounter")',f'clear_flag = &"{n["flag"]}"']
        elif k=='npc':
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("8_npc")]',f'position = {v(n["x"],n["y"])}',
                f'npc_id = &"{n["id"]}"',f'name_key = "{n["speaker"]}"',f'premade = "{n["premade"]}"',f'facing = {n["facing"]}',
                f'lines = {psa(n["lines"])}', f'repeat_lines = {psa(n["repeat"])}', f'sets_flag = &"{n["flag"]}"']
    open(path,'w').write('\n'.join(L)+'\n')


BLOB = json.load(open(os.path.join(ROOT, 'data', 'tiles', 'blob47.json')))


def blob_mask(rows, x, y, joins):
    """Same as TilePainter.blob_mask."""
    def same(dx, dy):
        yy, xx = y + dy, x + dx
        if yy < 0 or yy >= len(rows) or xx < 0 or xx >= len(rows[yy]):
            return True
        return rows[yy][xx] in joins
    n, e, s, w = same(0, -1), same(1, 0), same(0, 1), same(-1, 0)
    m = (1 if n else 0) | (4 if e else 0) | (16 if s else 0) | (64 if w else 0)
    if n and e and same(1, -1): m |= 2
    if s and e and same(1, 1): m |= 8
    if s and w and same(-1, 1): m |= 32
    if n and w and same(-1, -1): m |= 128
    return m


def under_char(rows, x, y, joins, fallback):
    for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0), (1, -1), (1, 1), (-1, 1), (-1, -1)]:
        yy, xx = y + dy, x + dx
        if 0 <= yy < len(rows) and 0 <= xx < len(rows[yy]):
            c = rows[yy][xx]
            if c not in joins and c not in ' .':
                return c
    return fallback


def preview(out, palette, layout, nodes, clean=False):
    """Debug picture: tiles, props, NPCs, interaction areas and markers.
    clean=True: only tiles and always-visible props (for the city map)."""
    rows=layout.split('\n'); W=max(map(len,rows)); H=len(rows)
    img=Image.new('RGBA',(W*16,H*16),(20,20,28,255)); P=PAL[palette]; cache={}
    def tile(t, c, x, y):
        if t not in cache: cache[t]=Image.open(local(t)).convert('RGBA')
        img.alpha_composite(cache[t].crop((c[0]*16,c[1]*16,c[0]*16+16,c[1]*16+16)),(x*16,y*16))
    def plain(b, x, y):
        opts=b['tiles']; g=b.get('grid'); h=(x*73856093)^(y*19349663)
        c=opts[(y%g[1])*g[0]+(x%g[0])] if g else (opts[abs(h)%len(opts)] if len(opts)>1 else opts[0])
        tile(b['texture'], c, x, y)
    over=[]
    for y,row in enumerate(rows):
        for x,ch in enumerate(row):
            if ch in ' .': continue
            b=P[ch]
            if 'blob' in b:
                joins=ch+b.get('joins','')
                m=blob_mask(rows,x,y,joins)
                c=BLOB['tiles'].get(str(m),BLOB['tiles']['255'])
                over.append((BLOB['sheet'],(c[0],b['blob']*4+c[1]),x,y))
                if m!=255 or not b.get('opaque'):
                    u=under_char(rows,x,y,joins,b.get('under',''))
                    if u in P and 'blob' not in P[u]: plain(P[u],x,y)
                d=b.get('decor')
                if d and m==255 and (abs((x*92837111)^(y*689287499)^0x5bd1e995)%1000)<int(d['density']*1000):
                    o=d['tiles']; over.append((d['texture'],o[abs((y*73856093)^(x*19349663))%len(o)] if len(o)>1 else o[0],x,y))
                continue
            plain(b,x,y)
    over.sort(key=lambda o: o[0]!=BLOB['sheet'])
    for t,c,x,y in over: tile(t,c,x,y)
    drawables=[]
    for n in nodes:
        if n['kind']=='prop' and not (clean and n.get('show_if')):
            im=Image.open(local(n['tex'])).convert('RGBA')
            if n.get('region'): r=n['region']; im=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
            drawables.append((n['layer']!='FloorDecor', n['y'], im, n['x']-im.width//2, n['y']-im.height))
        if n['kind']=='npc':
            im=Image.open(SRC['modern_interiors']+f'/2_Characters/Character_Generator/0_Premade_Characters/16x16/{n["premade"]}.png').convert('RGBA')
            col={0:0,1:6,2:12,3:18}[n['facing']]; fr=im.crop((col*16,32,col*16+16,64)); drawables.append((True,n['y'],fr,n['x']-8,n['y']-32))
        if n['kind']=='forage':
            im=Image.open(local(resolve_tex(n['tex']))).convert('RGBA')
            drawables.append((True,n['y']+6,im,n['x']-im.width//2,n['y']+6-im.height))
        if n['kind']=='critter':
            im=Image.open(local(resolve_tex(n['tex']))).convert('RGBA'); s=n.get('frame',16)
            drawables.append((True,n['y'],im.crop((3*s,0,4*s,s)),n['x']-s//2,n['y']-s))
    drawables.sort(key=lambda d:(d[0],d[1]))
    for _,_,im,x,y in drawables: img.alpha_composite(im,(int(x),int(y)))
    if clean:
        img.save(out)
        return
    from PIL import ImageDraw; d=ImageDraw.Draw(img)
    for n in nodes:
        if n['kind'] in ('inspect','door','rest'):
            ax,ay=n['area']; d.rectangle([n['x']-ax/2,n['y']-ay/2,n['x']+ax/2,n['y']+ay/2],outline=(255,255,0,255))
        if n['kind']=='prop' and n['col'][0]>0:
            cx,cy=n['x']+n['off'][0],n['y']+n['off'][1]; w,h=n['col']; d.rectangle([cx-w/2,cy-h/2,cx+w/2,cy+h/2],outline=(255,0,0,160))
        if n['kind']=='spawn': d.ellipse([n['x']-3,n['y']-3,n['x']+3,n['y']+3],fill=(0,255,255,255))
        if n['kind']=='anchor': d.rectangle([n['x']-3,n['y']-3,n['x']+3,n['y']+3],fill=(255,140,0,255)); d.text((n['x']+4,n['y']-10),n['id'][:10],fill=(255,200,0,255))
        if n['kind'] in ('spot','screen','junk'): d.rectangle([n['x']-5,n['y']-5,n['x']+5,n['y']+5],outline=(0,200,255,255))
        if n['kind'] in ('boss','pickup'): d.rectangle([n['x']-6,n['y']-14,n['x']+6,n['y']],outline=(255,0,255,255))
        if n['kind']=='enemy': d.ellipse([n['x']-5,n['y']-5,n['x']+5,n['y']+5],outline=(255,60,60,255))
    img.resize((img.width*2,img.height*2),Image.NEAREST).save(out)


def load_spec(rid):
    return json.load(open(os.path.join(REGIONS, rid + '.json')))


def all_ids():
    return sorted(f[:-5] for f in os.listdir(REGIONS) if f.endswith('.json') and not f.startswith('_'))


def build(rid, out_path, want_preview=False):
    spec = load_spec(rid)
    if spec['id'] != rid:
        raise SystemExit(f'{rid}.json: id is {spec["id"]}')
    nodes = expand(spec['nodes'], rid)
    lay = layout_of(spec)
    if spec.get('dress'):
        nodes += dress(nodes, lay, spec['dress'], rid)
    write_tscn(out_path, rid, spec['name_key'], spec['palette'], lay, nodes,
               margin=spec.get('camera_margin_tiles', 0), opts=options_of(spec))
    if want_preview:
        os.makedirs(PREVIEWS, exist_ok=True)
        preview(os.path.join(PREVIEWS, rid + '.png'), spec['palette'], lay, nodes)
    return nodes


def dump_canonical(spec):
    """One node per line: diffs stay readable."""
    lines = ['{']
    keys = [k for k in spec if k not in ('layout', 'nodes')]
    for k in keys:
        lines.append(f' {json.dumps(k)}: {json.dumps(spec[k], ensure_ascii=False)},')
    lay = spec['layout']
    if isinstance(lay, list):
        lines.append(' "layout": [')
        lines += [f'  {json.dumps(r)},' for r in lay]
        lines[-1] = lines[-1].rstrip(',')
        lines.append(' ],')
    else:
        lines.append(f' "layout": {json.dumps(lay)},')
    lines.append(' "nodes": [')
    lines += [f'  {json.dumps(n, ensure_ascii=False)},' for n in spec['nodes']]
    lines[-1] = lines[-1].rstrip(',')
    lines += [' ]', '}']
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ids', nargs='*')
    ap.add_argument('--preview', action='store_true', help='also write build/region_previews/<id>.png')
    ap.add_argument('--check', action='store_true', help='compare with committed scenes, write nothing')
    ap.add_argument('--format', action='store_true', help='rewrite the JSON specs canonically')
    a = ap.parse_args()
    ids = a.ids or all_ids()
    if a.format:
        for rid in ids:
            p = os.path.join(REGIONS, rid + '.json')
            text = dump_canonical(json.load(open(p)))
            open(p, 'w').write(text)
        print(f'formatted {len(ids)} specs')
        return
    if not os.path.isdir(SRC['modern_exteriors']):
        raise SystemExit('LimeZu art not found in assets/limezu (git submodule update --init)')
    stale = []
    for rid in ids:
        target = scene_path(rid)
        if a.check:
            tmp = target + '.check'
            build(rid, tmp)
            same = os.path.exists(target) and open(tmp).read() == open(target).read()
            os.remove(tmp)
            if not same:
                stale.append(rid)
        else:
            nodes = build(rid, target, a.preview)
            print(f'{rid}: {len(nodes)} nodes')
    if a.check:
        if stale:
            raise SystemExit('stale scenes (run tools/regions/build_regions.py): ' + ', '.join(stale))
        print(f'{len(ids)} scenes up to date')


if __name__ == '__main__':
    main()
