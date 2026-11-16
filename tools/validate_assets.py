#!/usr/bin/env python3
"""Asset checks.

Always (CI, no art needed):
  * the public repository tracks no image/audio/archive files from the LimeZu
    packs (their license forbids redistribution) — only assets/audio/sfx/*.wav,
    which tools/generate_sfx.py synthesises, and the assets/limezu submodule link;
Only when the private art submodule is present (assets/limezu):
  * every texture a scene, palette or data file references exists;
  * a prop's placeholder size matches the real texture (so the game looks the
    same with and without art) and its region fits inside the texture;
  * every palette tile coordinate is inside its tileset.

Usage: python3 tools/validate_assets.py
"""
import glob, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(ROOT)
ART = 'assets/limezu'
errors, notes = [], []
# Original work generated in this repo may be tracked: the soundtrack.
ORIGINAL = re.compile(r'^assets/music/[a-z0-9_]+\.ogg$')
BINARY = re.compile(r'\.(png|jpe?g|gif|bmp|webp|aseprite|ase|psd|zip|rar|7z|exe|ogg|mp3|ttf|otf)$', re.I)

# --- license guard ---------------------------------------------------------
try:
    tracked = subprocess.check_output(['git', 'ls-files'], text=True).splitlines()
except Exception:  # noqa: BLE001 - not a git checkout (e.g. exported folder)
    tracked = []
for f in tracked:
    if f.startswith(ART + '/'):
        errors.append(f'{f}: art pack files must live only in the private submodule')
    elif ORIGINAL.match(f):
        pass  # our own generated music (tools/music/compose.py)
    elif BINARY.search(f):
        errors.append(f'{f}: binary asset tracked in the public repo (LimeZu files may not be redistributed)')
    elif f.endswith('.wav') and not f.startswith('assets/audio/sfx/'):
        errors.append(f'{f}: only generated sounds belong in assets/audio/sfx')

# --- art checks ------------------------------------------------------------
have_art = os.path.isdir(os.path.join(ART, 'modern_exteriors'))
if have_art:
    try:
        from PIL import Image
    except ImportError:
        Image = None
        notes.append('Pillow not installed: skipping texture size checks')
    sizes = {}

    def size_of(rel):
        p = os.path.join(ART, rel)
        if not os.path.exists(p):
            return None
        if rel not in sizes:
            sizes[rel] = Image.open(p).size if Image else (0, 0)
        return sizes[rel]

    for scene in sorted(glob.glob('scenes/**/*.tscn', recursive=True)):
        text = open(scene, encoding='utf-8').read()
        for block in text.split('\n[node ')[1:]:
            name = block.split('"')[1] if '"' in block else '?'
            m = re.search(r'texture_path = "([^"]+)"', block)
            if not m:
                continue
            tex = m.group(1)
            sz = size_of(tex)
            if sz is None:
                errors.append(f'{scene} {name}: missing texture {tex}')
                continue
            if not Image:
                continue
            reg = re.search(r'region = Rect2\(([\d., -]+)\)', block)
            ph = re.search(r'placeholder_size = Vector2i\((\d+), (\d+)\)', block)
            if reg:
                x, y, w, h = (float(v) for v in reg.group(1).split(','))
                if x + w > sz[0] or y + h > sz[1]:
                    errors.append(f'{scene} {name}: region outside {tex} ({sz[0]}x{sz[1]})')
                want = (int(w), int(h))
            else:
                want = sz
            if ph and (int(ph.group(1)), int(ph.group(2))) != tuple(want):
                errors.append(f'{scene} {name}: placeholder {ph.group(1)}x{ph.group(2)} but texture is {want[0]}x{want[1]}')
    pal = json.load(open('data/tiles/palettes.json', encoding='utf-8'))
    for pid, p in pal.items():
        if pid.startswith('_'):
            continue
        for ch, b in p.items():
            sz = size_of(b['texture'])
            if sz is None:
                errors.append(f'palette {pid}/{ch}: missing texture {b["texture"]}')
                continue
            if not Image:
                continue
            for c in b['tiles']:
                if (c[0] + 1) * 16 > sz[0] or (c[1] + 1) * 16 > sz[1]:
                    errors.append(f'palette {pid}/{ch}: tile {c} outside {b["texture"]}')
    for f in glob.glob('data/**/*.json', recursive=True):
        for tex in re.findall(r'"((?:modern_exteriors|modern_interiors)/[^"]+\.png)"', open(f, encoding='utf-8').read()):
            if size_of(tex) is None:
                errors.append(f'{f}: missing texture {tex}')
    for f in glob.glob('**/*.gd', recursive=True):
        if f.startswith(('assets/', '.godot/')):
            continue
        for tex in re.findall(r'"((?:modern_exteriors|modern_interiors)/[^"%]+\.png)"', open(f, encoding='utf-8').read()):
            if size_of(tex) is None:
                errors.append(f'{f}: missing texture {tex}')
else:
    notes.append('art submodule not present: only the license guard ran')

for n in notes:
    print('note:', n)
for e in errors:
    print('ERROR:', e)
art_note = f'{len(sizes)} textures checked' if have_art else 'absent'
print(f'assets: {len(tracked)} tracked files checked, art {art_note} — {len(errors)} errors')
sys.exit(1 if errors else 0)
