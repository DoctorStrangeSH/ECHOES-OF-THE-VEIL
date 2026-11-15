#!/usr/bin/env python3
"""Validate game content (data/, scenes/locations/) without running Godot.

Errors mean broken content (a dialogue jumps to a missing node, a door leads to
a missing spawn, a string is not translated, a job's repair spot is in no
scene...). Warnings are worth a look but may be intended (a flag read by a
condition that nothing sets yet, an unreachable dialogue node, an unused string).

Usage:  python3 tools/validate_content.py [--strict]   (--strict: warnings fail too)
Runs in CI; needs only the Python standard library.
"""
import glob, json, os, re, sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(ROOT)
errors, warnings = [], []
LANGS = ['en', 'ru']
# Flags whose names are built in code (prefix match), so no data sets them literally.
DYNAMIC_FLAGS = ('act.', 'rel.', 'repair.level_', 'home.', 'defeated.', 'junk.', 'met.', 'boss.', 'case.', 'job.')


def err(m): errors.append(m)
def warn(m): warnings.append(m)


def load(path):
    try:
        return json.load(open(path, encoding='utf-8'))
    except Exception as e:  # noqa: BLE001
        err(f'{path}: {e}')
        return {}


def defs(base):
    """Same rule as DataFiles.defs: base.json + base_*.json, '_' keys are comments."""
    d, prefix = os.path.dirname(base), os.path.basename(base)
    files = [f for f in [base + '.json'] if os.path.exists(f)]
    files += sorted(glob.glob(os.path.join(d, prefix + '_*.json')))
    out, origin = {}, {}
    for f in files:
        for k, v in load(f).items():
            if k.startswith('_'):
                continue
            if k in out:
                err(f'{f}: "{k}" already defined in {origin[k]}')
                continue
            out[k], origin[k] = v, f
    return out


# --- load ------------------------------------------------------------------
S, S_file = {}, {}
for f in sorted(glob.glob('data/localization/*.json')):
    for k, v in load(f).items():
        if k in S:
            err(f'{f}: string {k} already defined in {S_file[k]}')
        S[k], S_file[k] = v, f
D, D_file = {}, {}
for f in sorted(glob.glob('data/dialogue/*.json')):
    for k, v in load(f).items():
        if k in D:
            err(f'{f}: dialogue {k} already defined in {D_file[k]}')
        D[k], D_file[k] = v, f
J = {'evidence': {}, 'cases': {}, 'hypotheses': {}}
for f in sorted(glob.glob('data/journal/*.json')):
    data = load(f)
    for sec in J:
        for k, v in data.get(sec, {}).items():
            if k in J[sec]:
                err(f'{f}: {sec} {k} defined twice')
            J[sec][k] = v
N = defs('data/characters/npcs')
I = defs('data/items/items')
A = defs('data/progression/attunements')
FACT = defs('data/world/facts')
FACTION = defs('data/world/factions')
SHOPS = defs('data/economy/shops')
RECIPES = defs('data/economy/recipes')
JOBS = defs('data/economy/jobs')
UPG = defs('data/economy/home_upgrades')
ENEMIES = defs('data/enemies/enemies')
BACKGROUNDS = defs('data/characters/backgrounds')
PAL = load('data/tiles/palettes.json')
BUSINESS = load('data/economy/business.json')

LOCS = {os.path.basename(p)[:-5]: open(p, encoding='utf-8').read() for p in sorted(glob.glob('scenes/locations/*.tscn'))}

def key(k, where):
    if k and k not in S:
        err(f'{where}: string {k} not in data/localization')

# --- references collected from conditions/effects anywhere ----------------
refs = []
flags_read, flags_set = defaultdict(set), set()
RULE_KEYS = {
    'add_evidence': 'evidence', 'evidence': 'evidence', 'not_evidence': 'evidence',
    'quest_start': 'case', 'quest_active': 'case', 'quest_done': 'case', 'not_quest_started': 'case',
    'hypothesis': 'hyp', 'not_hypothesis': 'hyp', 'tell': 'fact', 'publish': 'fact', 'knows': 'fact', 'not_knows': 'fact',
}


def walk(v, where):
    if isinstance(v, list):
        for x in v:
            walk(x, where)
    elif isinstance(v, dict):
        for k, a in v.items():
            if k in ('tell', 'knows', 'not_knows'):
                refs.append(('npc', a[0], where))
                refs.append(('fact', a[1], where))
            elif k in RULE_KEYS:
                refs.append((RULE_KEYS[k], a, where))
            elif k in ('quest_stage', 'quest_complete'):
                refs.append(('case', a[0], where))
                if k == 'quest_stage':
                    refs.append(('stage', a, where))
                elif len(a) > 1:
                    refs.append(('outcome', a, where))
            elif k == 'travel':
                refs.append(('scene', a[0], where))
                if len(a) > 1:
                    refs.append(('spawn', a, where))
            elif k == 'scene':
                refs.append(('scene', a, where))
            elif k in ('give_item', 'take_item'):
                refs.append(('item', a[0] if isinstance(a, list) else a, where))
            elif k == 'has_item':
                refs.append(('item', a if isinstance(a, str) else a[0], where))
            elif k in ('relationship', 'remember', 'relationship_at_least', 'remembers'):
                refs.append(('npc', a[0], where))
                if k == 'remember':
                    key('MEM_' + a[1].upper(), where + ' (memory text)')
            elif k in ('faction', 'faction_at_least', 'faction_below'):
                refs.append(('faction', a[0], where))
            elif k == 'open_screen':
                refs.append(('screen', a, where))
            elif k in ('flag', 'not_flag', 'flag_equals'):
                flags_read[a[0] if isinstance(a, list) else a].add(where)
            elif k in ('set_flag', 'clear_flag'):
                flags_set.add(a[0] if isinstance(a, list) else a)
            elif k == 'toast':
                key(a[0] if isinstance(a, list) else a, where)
            walk(a, where)


# --- dialogue --------------------------------------------------------------
for did, d in D.items():
    nodes = d.get('nodes', {})
    where = f'dialogue {did}'
    entry = [d.get('start')] + [e.get('node') for e in d.get('entries', [])]
    edges = defaultdict(list)
    for nid, n in nodes.items():
        for k in (n.get('text', ''), n.get('speaker', '')):
            if k != 'player':
                key(k, f'{where}/{nid}')
        if n.get('next'):
            edges[nid].append(n['next'])
        for c in n.get('choices', []):
            key(c.get('text', ''), f'{where}/{nid} choice')
            if c.get('next'):
                edges[nid].append(c['next'])
    for tg in entry + [t for ts in edges.values() for t in ts]:
        if tg is not None and tg not in nodes:
            err(f'{where}: jumps to missing node {tg}')
    seen, todo = set(), [t for t in entry if t]
    while todo:
        x = todo.pop()
        if x in seen:
            continue
        seen.add(x)
        todo += edges.get(x, [])
    for nid in nodes:
        if nid not in seen:
            warn(f'{where}: node {nid} is unreachable')
    if 'hub' in nodes:
        # An entry that ends the conversation without changing anything repeats
        # forever while its condition holds and hides the hub (shop, jobs, new cases).
        for e in d.get('entries', []):
            n, seen, changes = e.get('node'), set(), False
            while n and n in nodes and n not in seen:
                seen.add(n)
                if n == 'hub' or nodes[n].get('effects') or nodes[n].get('choices'):
                    changes = True
                    break
                n = nodes[n].get('next')
            if not changes:
                err(f'{where}: entry {e.get("node")} ends the conversation without changing anything, so the hub is unreachable while it applies')
    walk(d, where)

# --- journal ---------------------------------------------------------------
for e, v in J['evidence'].items():
    for k in ('title', 'body', 'source_name'):
        key(v.get(k, ''), f'evidence {e}')
    if 'advance' in v:
        refs.append(('stage', v['advance'], f'evidence {e}'))
for c, v in J['cases'].items():
    for k in [v.get('title'), v.get('summary')] + list(v.get('stages', {}).values()) + list(v.get('outcomes', {}).values()):
        key(k, f'case {c}')
    for a, targets in v.get('transitions', {}).items():
        for t in [a] + targets:
            if t not in v.get('stages', {}):
                err(f'case {c}: transition uses unknown stage {t}')

CAMPAIGN = load('data/story/campaign.json')
for a in CAMPAIGN.get('acts', []):
    for k in ('title', 'subtitle'):
        key(a.get(k), f'act {a.get("id")}')
    walk(a.get('begins_if', {}), f'act {a.get("id")}')
    walk(a.get('effects', []), f'act {a.get("id")}')
EPI = load('data/story/epilogues.json') if os.path.exists('data/story/epilogues.json') else {}
for e in EPI.get('endings', []):
    key(e.get('title'), 'epilogue'); key(e.get('text'), 'epilogue')
    if e.get('id') not in J['cases'].get('case_anchor', {}).get('outcomes', {}):
        err(f'epilogue ending {e.get("id")} is not an outcome of case_anchor')
groups = defaultdict(list)
for c in EPI.get('cards', []):
    key(c.get('title'), 'epilogue card'); key(c.get('text'), 'epilogue card')
    walk(c.get('if', {}), 'epilogue card')
    groups[c.get('group')].append(c)
for g, cs in groups.items():
    if any('if' not in c for c in cs[:-1]):
        err(f'epilogue group {g}: a card without a condition must come last')

# --- D-052: no progress by waiting; every stage reachable by player action ----
targets = set()  # (case, stage) moved to by an effect, evidence or hypothesis


def effect_targets(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ('effects', 'do', 'reward') and isinstance(v, list):
                for e in v:
                    if isinstance(e, dict) and 'quest_stage' in e:
                        targets.add(tuple(e['quest_stage']))
            effect_targets(v)
    elif isinstance(o, list):
        for x in o:
            effect_targets(x)


for blob in (D, J, CAMPAIGN, JOBS, N):
    effect_targets(blob)
for e, v in J['evidence'].items():
    if isinstance(v.get('advance'), list):
        targets.add(tuple(v['advance']))
for c, v in J['cases'].items():
    if 'fail_forward' in v:
        err(f'case {c}: fail_forward is not allowed — nothing may advance by waiting (D-052)')
    for st in v.get('stages', {}):
        if st != v.get('first_stage') and (c, st) not in targets:
            err(f'case {c}: no player action ever moves it to stage {st}')
    for rule in v.get('deadlines', []):
        key(rule.get('note'), f'case {c} deadline')
        if rule.get('stage') not in v.get('stages', {}) or rule.get('outcome') not in v.get('outcomes', {}):
            err(f'case {c}: deadline needs a known stage and a failure outcome')
        walk(rule.get('effects', []), f'case {c} deadline')
    for st, objs in v.get('objectives', {}).items():
        if st not in v.get('stages', {}):
            err(f'case {c}: objectives for unknown stage {st}')
        ids = [o.get('id') for o in objs]
        if len(set(ids)) != len(ids):
            err(f'case {c}: duplicate objective ids at {st}')
        for o in objs:
            key(o.get('text'), f'case {c} objective')
            walk(o.get('done_if', {}), f'case {c} objective')
            walk(o.get('progress', []), f'case {c} objective')
            walk(o.get('reward', []), f'case {c} objective')
            if o.get('reward') and not o.get('optional'):
                warn(f'case {c}: objective {o.get("id")} pays a reward but is required')

for h, v in J['hypotheses'].items():
    key(v.get('title'), f'hypothesis {h}')
    key(v.get('body'), f'hypothesis {h}')
    for e in v.get('requires_all', []) + v.get('requires_any', []):
        if e not in J['evidence']:
            err(f'hypothesis {h}: unknown evidence {e}')
    walk(v, f'hypothesis {h}')

# --- characters, items, progression, world ---------------------------------
for nid, n in N.items():
    key(n.get('name'), f'npc {nid}')
    if n.get('dialogue') and n['dialogue'] not in D:
        err(f'npc {nid}: unknown dialogue {n["dialogue"]}')
    for fa in n.get('factions', []):
        if fa not in FACTION:
            err(f'npc {nid}: unknown faction {fa}')
    walk(n, f'npc {nid}')
for i, v in I.items():
    key(v.get('name'), f'item {i}')
    key(v.get('desc'), f'item {i}')
    if 'evidence' in v and v['evidence'] not in J['evidence']:
        err(f'item {i}: unknown evidence {v["evidence"]}')
for a, v in A.items():
    key(v.get('name'), f'attunement {a}')
    key(v.get('desc'), f'attunement {a}')
    if 'requires' in v and v['requires'] not in A:
        err(f'attunement {a}: unknown requirement {v["requires"]}')
for f, v in FACTION.items():
    key(v.get('name'), f'faction {f}')
for f, v in FACT.items():
    walk(v, f'fact {f}')
for b, v in BACKGROUNDS.items():
    walk(v, f'background {b}')
for e, v in ENEMIES.items():
    key(v.get('name'), f'enemy {e}')
    for k in ('max_health', 'move_speed', 'chase_speed', 'lunge_speed', 'windup_time', 'attack_range', 'resonance'):
        if k not in v:
            err(f'enemy {e}: missing {k}')
    if len(v.get('tint', [1, 1, 1, 1])) != 4:
        err(f'enemy {e}: tint must be [r, g, b, a]')

# --- economy ---------------------------------------------------------------
for sid, shop in SHOPS.items():
    key(shop.get('name'), f'shop {sid}')
    if shop.get('npc') and shop['npc'] not in N:
        err(f'shop {sid}: unknown npc {shop["npc"]}')
    for e in shop.get('stock', []):
        if 'item' in e and e['item'] not in I:
            err(f'shop {sid}: unknown item {e["item"]}')
        if 'upgrade' in e and e['upgrade'] not in UPG:
            err(f'shop {sid}: unknown home upgrade {e["upgrade"]}')
        if 'item' in e and e.get('price', 0) < I.get(e['item'], {}).get('value', 0) * 0.5:
            err(f'shop {sid}: {e["item"]} sells below buy-back value')
for r, v in RECIPES.items():
    for it in list(v.get('inputs', {})) + [r]:
        if it not in I:
            err(f'recipe {r}: unknown item {it}')
for u, v in UPG.items():
    key(v.get('name'), f'home upgrade {u}')
    key(v.get('desc'), f'home upgrade {u}')
spots = defaultdict(list)
for loc, t in LOCS.items():
    for s in re.findall(r'spot_id = &"([^"]+)"', t):
        spots[s].append(loc)
for j, v in JOBS.items():
    key(v.get('name'), f'job {j}')
    key(v.get('desc'), f'job {j}')
    if v.get('spot') not in spots:
        err(f'job {j}: repair spot {v.get("spot")} is in no scene')
    if v.get('client') and v['client'] not in N:
        err(f'job {j}: unknown client {v["client"]}')
    walk(v, f'job {j}')
for s, locs in spots.items():
    if not any(v.get('spot') == s for v in JOBS.values()):
        warn(f'repair spot {s} ({locs[0]}) has no job')
for u in BUSINESS.get('upgrades', {}).values() if isinstance(BUSINESS.get('upgrades'), dict) else []:
    walk(u, 'business')

# --- expeditions (M8a) --------------------------------------------------------
RUNTIME_LOCATIONS = {'expedition_room'}  # built from data/expeditions at runtime

def _walkable(rows, pal, start, goal):
    solid = {c for c, b in pal.items() if isinstance(b, dict) and b.get('solid')}
    h = len(rows)
    sx, sy = int(start[0]) // 16, int(start[1]) // 16
    gx, gy = int(goal[0]) // 16, int(goal[1]) // 16
    seen, todo = {(sx, sy)}, [(sx, sy)]
    ok = lambda x, y: 0 <= y < h and 0 <= x < len(rows[y]) and rows[y][x] not in solid and rows[y][x] not in ' .'
    if not ok(sx, sy) or not ok(gx, gy):
        return False
    while todo:
        x, y = todo.pop()
        if (x, y) == (gx, gy):
            return True
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if (nx, ny) not in seen and ok(nx, ny):
                seen.add((nx, ny)); todo.append((nx, ny))
    return False

EXP = {n: {k: v for k, v in load(f'data/expeditions/{n}.json').items() if not k.startswith('_')}
       for n in ('sites', 'modifiers', 'rematches', 'pages')} if os.path.isdir('data/expeditions') else {}
if EXP:
    cleared_keys = set()
    for sid, site in EXP['sites'].items():
        cleared_keys.add(f'site:{sid}')
        key(site.get('name', ''), f'expedition site {sid}')
        if site.get('palette') not in PAL:
            err(f'expedition site {sid}: unknown palette {site.get("palette")}')
            continue
        for e in site.get('enemies', []):
            if e not in ENEMIES:
                err(f'expedition site {sid}: unknown enemy variant {e}')
        rooms = list(site.get('rooms', [])) + [site.get('arena')]
        if not site.get('arena') or 'boss' not in site['arena']:
            err(f'expedition site {sid}: needs an arena with a boss position')
        for i, r in enumerate(r for r in rooms if r):
            if not _walkable(r['rows'], PAL[site['palette']], r['start'], r['exit']):
                err(f'expedition site {sid} room {i}: exit not reachable from start')
            if 'boss' in r and not _walkable(r['rows'], PAL[site['palette']], r['start'], r['boss']):
                err(f'expedition site {sid} room {i}: boss spot not reachable')
    for mid, m in EXP['modifiers'].items():
        cleared_keys.add(f'mod:{mid}')
        key(m.get('name', ''), f'modifier {mid}'); key(m.get('desc', ''), f'modifier {mid}')
    for bid, b in EXP['rematches'].items():
        cleared_keys.add(f'boss:{bid}')
        key(b.get('name', ''), f'rematch {bid}')
        if not os.path.exists(b.get('scene', '').replace('res://', '')):
            err(f'rematch {bid}: scene {b.get("scene")} not found')
    for pid, pg in EXP['pages'].items():
        key(pg.get('title', ''), f'page {pid}'); key(pg.get('text', ''), f'page {pid}')
        if pg.get('needs') and pg['needs'] not in cleared_keys:
            err(f'page {pid}: needs {pg["needs"]} can never be cleared')

# --- scenes ----------------------------------------------------------------
spawns = {loc: set(re.findall(r'spawn_id = &"([^"]+)"', t)) for loc, t in LOCS.items()}
anchors = {loc: set(re.findall(r'anchor_id = &"([^"]+)"', t)) for loc, t in LOCS.items()}
enemy_ids = defaultdict(list)
for loc, t in LOCS.items():
    m = re.search(r'location_id = &"([^"]+)"', t)
    if not m or m.group(1) != loc:
        err(f'{loc}.tscn: location_id must equal the file name')
    m = re.search(r'name_key = "([^"]+)"', t)
    key(m.group(1) if m else '', f'{loc}.tscn')
    m = re.search(r'palette_id = "([^"]+)"', t)
    if m and m.group(1) not in PAL:
        err(f'{loc}.tscn: unknown palette {m.group(1)}')
    if not os.path.exists(f'data/regions/{loc}.json') and loc not in RUNTIME_LOCATIONS:
        warn(f'{loc}.tscn has no region spec in data/regions (hand-made scene?)')
    for cond in re.findall(r'(?:show_if|enter_condition) = (\{.*\})', t):
        walk(json.loads(cond), loc)
    for it in re.findall(r'item_id = &"(\w+)"', t):
        refs.append(('item', it, loc))
    for f in re.findall(r'(?:sets_flag|pickup_flag|clear_flag|engaged_flag) = &"([^"]+)"', t):
        flags_set.add(f)
    for f in re.findall(r'required_flag = &"([^"]+)"', t):
        flags_read[f].add(loc)
    for d in re.findall(r'(?:dialogue_id|enter_dialogue_id) = &"([^"]+)"', t):
        if d not in D:
            err(f'{loc}.tscn: unknown dialogue {d}')
    for k in re.findall(r'(?:prompt_key|speaker_key) = "([^"]+)"', t):
        key(k, f'{loc}.tscn')
    for arr in re.findall(r'(?:lines|repeat_lines|locked_lines) = PackedStringArray\(([^)]*)\)', t):
        for k in re.findall(r'"([^"]+)"', arr):
            key(k, f'{loc}.tscn')
    for sc, sp in re.findall(r'target_scene_id = &"([^"]+)"\ntarget_spawn_id = &"([^"]+)"', t):
        if sc not in LOCS:
            err(f'{loc}.tscn: door to unknown scene {sc}')
        elif sp not in spawns[sc]:
            err(f'{loc}.tscn: door to missing spawn {sc}/{sp}')
    for v in re.findall(r'variant = "([^"]+)"', t):
        if v not in ENEMIES:
            err(f'{loc}.tscn: unknown enemy variant {v}')
    for e in re.findall(r'enemy_id = &"([^"]+)"', t):
        enemy_ids[e].append(loc)
    ids = re.findall(r'interaction_id = &"([^"]+)"', t)
    for i in {x for x in ids if ids.count(x) > 1}:
        err(f'{loc}.tscn: interaction_id {i} used twice')
    for s in re.findall(r'screen = "([^"]+)"', t):
        refs.append(('screen', s, loc))
for e, locs in enemy_ids.items():
    if len(locs) > 1:
        err(f'enemy_id {e} used more than once ({", ".join(locs)}): defeat flags would collide')
for nid, n in N.items():
    for e in n.get('schedule', []):
        if e.get('scene') not in LOCS:
            err(f'npc {nid}: schedule scene {e.get("scene")} does not exist')
        elif e.get('anchor') not in anchors[e['scene']]:
            err(f'npc {nid}: anchor {e.get("anchor")} not in {e["scene"]}')

# --- check collected references --------------------------------------------
def screen_ok(s):
    if s.startswith('shop:'):
        return s[5:] in SHOPS
    if s.startswith('repair:'):
        return s[7:] in JOBS
    return s in ('jobs', 'workbench', 'business', 'epilogue', 'expeditions')

CHECK = {
    'evidence': lambda a: a in J['evidence'], 'case': lambda a: a in J['cases'], 'hyp': lambda a: a in J['hypotheses'],
    'scene': lambda a: a in LOCS, 'spawn': lambda a: a[1] in spawns.get(a[0], ()),
    'stage': lambda a: a[1] in J['cases'].get(a[0], {}).get('stages', {}),
    'outcome': lambda a: a[1] in J['cases'].get(a[0], {}).get('outcomes', {}),
    'item': lambda a: a in I, 'npc': lambda a: a in N or a == 'player', 'faction': lambda a: a in FACTION,
    'fact': lambda a: a in FACT, 'screen': screen_ok,
}
for kind, a, where in refs:
    if not CHECK[kind](a):
        err(f'{where}: unknown {kind} {a}')

# --- code: string keys, sounds, literal flags --------------------------------
code = {f: open(f, encoding='utf-8').read() for f in glob.glob('**/*.gd', recursive=True) if not f.startswith(('assets/', 'build/', '.godot/'))}
for f, t in code.items():
    for k in re.findall(r'^(?!\s*##).*?tr\("([A-Z][A-Z0-9_]+)"\)', t, re.M):
        key(k, f)
    for k in re.findall(r'Sfx\.play\(&"(\w+)"', t):
        if not os.path.exists(f'assets/audio/sfx/{k}.wav'):
            err(f'{f}: missing sound {k}')
    for fl in re.findall(r'set_flag\(&"([^"]+)"', t):
        flags_set.add(fl)
for fl, where in sorted(flags_read.items()):
    if fl not in flags_set and not fl.startswith(DYNAMIC_FLAGS):
        warn(f'flag {fl} is read ({sorted(where)[0]}) but nothing sets it')

# --- localization ----------------------------------------------------------
PH = re.compile(r'%[-+0-9.]*[sdif%]')
for k, v in S.items():
    for lang in LANGS:
        if lang not in v or not str(v.get(lang, '')).strip():
            err(f'string {k}: missing {lang} ({S_file[k]})')
    if all(lang in v for lang in LANGS):
        ph = {lang: sorted(p for p in PH.findall(v[lang]) if p != '%%') for lang in LANGS}
        if len({tuple(x) for x in ph.values()}) > 1:
            err(f'string {k}: placeholders differ between languages {ph}')
used = set()
corpus = '\n'.join(code.values()) + '\n'.join(LOCS.values())
data_corpus = '\n'.join(open(f, encoding='utf-8').read() for f in glob.glob('data/**/*.json', recursive=True) if 'localization' not in f)
dynamic_prefixes = set(re.findall(r'"([A-Z][A-Z0-9]+_(?:[A-Z0-9]+_)*)%s"', corpus)) | set(re.findall(r'"([A-Z][A-Z0-9]+_(?:[A-Z0-9]+_)*)" ?\+', corpus))
for k in S:
    if f'"{k}"' in corpus or f'"{k}"' in data_corpus or k.startswith(tuple(dynamic_prefixes)):
        used.add(k)
unused = sorted(set(S) - used)
if unused:
    warn(f'{len(unused)} strings look unused: {", ".join(unused[:12])}{" ..." if len(unused) > 12 else ""}')

# --- report ----------------------------------------------------------------
for w in warnings:
    print('warning:', w)
for e in errors:
    print('ERROR:', e)
print(f'content: {len(D)} dialogues, {len(J["cases"])} cases, {len(N)} NPCs, {len(I)} items, {len(JOBS)} jobs, '
      f'{len(ENEMIES)} enemy variants, {len(LOCS)} locations, {len(S)} strings — {len(errors)} errors, {len(warnings)} warnings')
strict = '--strict' in sys.argv
sys.exit(1 if errors or (strict and warnings) else 0)
