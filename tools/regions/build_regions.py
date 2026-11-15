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
    return SRC[pack] + '/' + rest


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
            out.append(finish_prop(n) if n['kind'] == 'prop' else n)
    return out


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
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("14_boss")]',f'position = {v(n["x"],n["y"])}']
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
            if n.get('show_if') is not None:
                L+=['',f'[node name="Condition" type="Node" parent="Entities/{n["name"]}"]','script = ExtResource("10_cond")',f'show_if = {_j.dumps(n["show_if"])}']
        elif k=='encounter':
            L+=[f'[node name="Encounter" type="Node" parent="."]','script = ExtResource("13_encounter")',f'clear_flag = &"{n["flag"]}"']
        elif k=='npc':
            L+=[f'[node name="{n["name"]}" parent="Entities" instance=ExtResource("8_npc")]',f'position = {v(n["x"],n["y"])}',
                f'npc_id = &"{n["id"]}"',f'name_key = "{n["speaker"]}"',f'premade = "{n["premade"]}"',f'facing = {n["facing"]}',
                f'lines = {psa(n["lines"])}', f'repeat_lines = {psa(n["repeat"])}', f'sets_flag = &"{n["flag"]}"']
    open(path,'w').write('\n'.join(L)+'\n')


def preview(out, palette, layout, nodes):
    """Debug picture: tiles, props, NPCs, interaction areas and markers."""
    rows=layout.split('\n'); W=max(map(len,rows)); H=len(rows)
    img=Image.new('RGBA',(W*16,H*16),(20,20,28,255)); P=PAL[palette]; cache={}
    for y,row in enumerate(rows):
        for x,ch in enumerate(row):
            if ch in ' .': continue
            b=P[ch]; t=b['texture']
            if t not in cache: cache[t]=Image.open(local(t)).convert('RGBA')
            opts=b['tiles']; g=b.get('grid'); h=(x*73856093)^(y*19349663)
            c=opts[(y%g[1])*g[0]+(x%g[0])] if g else (opts[abs(h)%len(opts)] if len(opts)>1 else opts[0])
            img.alpha_composite(cache[t].crop((c[0]*16,c[1]*16,c[0]*16+16,c[1]*16+16)),(x*16,y*16))
    drawables=[]
    for n in nodes:
        if n['kind']=='prop':
            im=Image.open(local(n['tex'])).convert('RGBA')
            if n.get('region'): r=n['region']; im=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
            drawables.append((n['layer']!='FloorDecor', n['y'], im, n['x']-im.width//2, n['y']-im.height))
        if n['kind']=='npc':
            im=Image.open(SRC['modern_interiors']+f'/2_Characters/Character_Generator/0_Premade_Characters/16x16/{n["premade"]}.png').convert('RGBA')
            col={0:0,1:6,2:12,3:18}[n['facing']]; fr=im.crop((col*16,32,col*16+16,64)); drawables.append((True,n['y'],fr,n['x']-8,n['y']-32))
    drawables.sort(key=lambda d:(d[0],d[1]))
    for _,_,im,x,y in drawables: img.alpha_composite(im,(int(x),int(y)))
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
