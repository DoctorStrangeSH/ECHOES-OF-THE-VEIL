#!/usr/bin/env python3
"""Turn a tour bot run (tools/tour_bot.gd) into something to read.

Writes, next to report.json:
  tour.md            locations ranked by bare floor, what was used, errors
  sheet_<state>.png  contact sheets: every location's whole-map picture

Usage: python3 tools/tour_report.py /tmp/tour
"""
import json, os, sys
from PIL import Image, ImageDraw

THUMB = (480, 270)


def main(out):
    rep = json.load(open(os.path.join(out, 'report.json')))
    md = ['# Tour report', '']
    for state, regions in rep['states'].items():
        md += [f'## State: {state}', '',
               '| Location | Bare floor | Floor cells | Sprites | Textures | Used | Dialogue lines | Problems |',
               '|---|---|---|---|---|---|---|---|']
        rows = []
        for rid, info in regions.items():
            if not info.get('visited'):
                rows.append((2.0, f'| {rid} | not reachable | | | | | | |'))
                continue
            m = info['metrics']
            used = info.get('used', [])
            lines = sum(int(u.get('steps', 0)) for u in used)
            bad = [u for u in used if u.get('ok') is False or u.get('new_errors', 0) > 0]
            probs = len(info.get('errors', [])) + len(bad)
            rows.append((m['bare_ratio'], f"| {rid} | {int(m['bare_ratio'] * 100)}% | {m['floor_cells']} | {m['sprites']} | {m['unique_textures']} | {len(used)} | {lines} | {probs or ''} |"))
        rows.sort(key=lambda r: -r[0])
        md += [r[1] for r in rows] + ['']
        md += ['### Problems', '']
        for rid, info in regions.items():
            for e in info.get('errors', []):
                md.append(f'- **{rid}**: {e}')
            for u in info.get('used', []):
                if u.get('ok') is False:
                    md.append(f"- **{rid}**: door `{u['id']}` leads to unknown `{u.get('to')}`")
        md.append('')
        sheet(out, state, regions)
    open(os.path.join(out, 'tour.md'), 'w').write('\n'.join(md))
    print('wrote', os.path.join(out, 'tour.md'))


def sheet(out, state, regions):
    ids = [r for r, i in regions.items() if i.get('visited')]
    cols = 4
    rows = (len(ids) + cols - 1) // cols
    per_page = cols * 4
    for page in range(0, len(ids), per_page):
        chunk = ids[page:page + per_page]
        r = (len(chunk) + cols - 1) // cols
        img = Image.new('RGB', (cols * THUMB[0], r * (THUMB[1] + 20)), (16, 16, 22))
        d = ImageDraw.Draw(img)
        for k, rid in enumerate(chunk):
            p = os.path.join(out, f'{state}_{rid}_map.png')
            if not os.path.exists(p):
                continue
            t = Image.open(p).convert('RGB').resize(THUMB, Image.LANCZOS)
            x, y = (k % cols) * THUMB[0], (k // cols) * (THUMB[1] + 20)
            img.paste(t, (x, y + 20))
            m = regions[rid]['metrics']
            d.text((x + 4, y + 4), f"{rid}  bare {int(m['bare_ratio'] * 100)}%", fill=(230, 230, 230))
        img.save(os.path.join(out, f'sheet_{state}_{page // per_page + 1}.png'))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/tour')
