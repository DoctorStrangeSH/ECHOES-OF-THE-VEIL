#!/usr/bin/env python3
"""Localization workflow for data/localization/*.json.

  python3 tools/loc.py status                    # coverage per language, problems
  python3 tools/loc.py export ru strings_ru.csv  # spreadsheet for a translator
  python3 tools/loc.py export ru todo.csv --missing   # only untranslated strings
  python3 tools/loc.py import strings_ru.csv     # write a translated CSV back
  python3 tools/loc.py format                    # one string per line in every file

CSV columns: key, file, en (source), <lang>, note. Translators edit only the
<lang> column; import writes it back into the file that owns each key and
refuses rows whose %s/%d placeholders differ from English.
Adding a language: add it to SUPPORTED_LOCALES in systems/localization/localization.gd,
then export --missing for it.
"""
import csv, glob, json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LOC = os.path.join(ROOT, 'data', 'localization')
SOURCE = 'en'
PH = re.compile(r'%[-+0-9.]*[sdif]')


def languages():
    src = open(os.path.join(ROOT, 'systems', 'localization', 'localization.gd'), encoding='utf-8').read()
    m = re.search(r'SUPPORTED_LOCALES[^=]*= *\[([^\]]*)\]', src)
    return re.findall(r'"([a-z_A-Z]+)"', m.group(1)) if m else ['en', 'ru']


def load_all():
    files = {}
    for f in sorted(glob.glob(os.path.join(LOC, '*.json'))):
        files[os.path.basename(f)] = json.load(open(f, encoding='utf-8'))
    return files


def dump(entries):
    lines = ['{']
    items = list(entries.items())
    for i, (k, v) in enumerate(items):
        lines.append(f'  {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}' + (',' if i < len(items) - 1 else ''))
    lines.append('}')
    return '\n'.join(lines) + '\n'


def save(name, entries):
    open(os.path.join(LOC, name), 'w', encoding='utf-8').write(dump(entries))


def placeholders(text):
    return sorted(PH.findall(text or ''))


def status():
    files, langs = load_all(), languages()
    total = sum(len(e) for e in files.values())
    print(f'{total} strings in {len(files)} files; languages: {", ".join(langs)}')
    bad = 0
    for lang in langs:
        missing = [k for e in files.values() for k, v in e.items() if not str(v.get(lang, '')).strip()]
        print(f'  {lang}: {total - len(missing)}/{total}' + (f'  missing: {", ".join(missing[:8])}{" ..." if len(missing) > 8 else ""}' if missing else ''))
        bad += len(missing)
    for name, e in files.items():
        for k, v in e.items():
            ref = placeholders(v.get(SOURCE))
            for lang in langs:
                if lang in v and placeholders(v[lang]) != ref:
                    print(f'  placeholder mismatch {k} [{lang}] in {name}: {placeholders(v[lang])} vs {ref}')
                    bad += 1
    return 1 if bad else 0


def export(lang, out, missing_only):
    files = load_all()
    n = 0
    with open(out, 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['key', 'file', SOURCE, lang, 'note'])
        for name, e in files.items():
            for k, v in e.items():
                if missing_only and str(v.get(lang, '')).strip():
                    continue
                note = 'keep ' + ' '.join(placeholders(v.get(SOURCE))) if placeholders(v.get(SOURCE)) else ''
                w.writerow([k, name, v.get(SOURCE, ''), v.get(lang, ''), note])
                n += 1
    print(f'exported {n} strings to {out}')


def import_csv(path):
    files = load_all()
    owner = {k: name for name, e in files.items() for k in e}
    with open(path, newline='', encoding='utf-8') as fh:
        rows = list(csv.reader(fh))
    header = rows[0]
    if header[:3] != ['key', 'file', SOURCE] or len(header) < 4:
        raise SystemExit(f'unexpected header {header}; expected key, file, {SOURCE}, <lang>')
    lang = header[3]
    changed, problems = set(), []
    for row in rows[1:]:
        if len(row) < 4 or not row[0]:
            continue
        k, text = row[0], row[3]
        if k not in owner:
            problems.append(f'unknown key {k}')
            continue
        if not text.strip():
            continue
        entry = files[owner[k]][k]
        if placeholders(text) != placeholders(entry.get(SOURCE)):
            problems.append(f'{k}: placeholders {placeholders(text)} must match {placeholders(entry.get(SOURCE))}')
            continue
        if entry.get(lang) != text:
            entry[lang] = text
            changed.add(owner[k])
    for name in changed:
        save(name, files[name])
    for p in problems:
        print('skipped:', p)
    print(f'imported {lang}: {len(changed)} files changed, {len(problems)} rows skipped')
    return 1 if problems else 0


def fmt():
    for name, e in load_all().items():
        save(name, e)
    print('formatted')


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return 0
    cmd = argv[0]
    if cmd == 'status':
        return status()
    if cmd == 'export' and len(argv) >= 3:
        export(argv[1], argv[2], '--missing' in argv)
        return 0
    if cmd == 'import' and len(argv) == 2:
        return import_csv(argv[1])
    if cmd == 'format':
        fmt()
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
