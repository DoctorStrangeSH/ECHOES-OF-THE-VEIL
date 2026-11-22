"""Applies a prose-pass part (a Python file defining T = {key: (ru, en)}) to
the localization files, keeping each key in the file it lives in; new keys go
to the file given by --new (default m2_story.json)."""
import glob, json, sys

def main():
    part = sys.argv[1]
    new_file = sys.argv[2] if len(sys.argv) > 2 else 'data/localization/m2_story.json'
    scope = {}
    exec(open(part, encoding='utf-8').read(), scope)
    T = scope['T']
    where = {}
    for f in glob.glob('data/localization/*.json'):
        for k in json.load(open(f, encoding='utf-8')):
            where[k] = f
    files = {}
    for k, (ru, en) in T.items():
        f = where.get(k, new_file)
        d = files.setdefault(f, json.load(open(f, encoding='utf-8')))
        d[k] = {"en": en, "ru": ru}
    for f, d in files.items():
        with open(f, 'w', encoding='utf-8') as out:
            out.write('{\n' + ',\n'.join('  ' + json.dumps(k, ensure_ascii=False) + ': ' + json.dumps(v, ensure_ascii=False) for k, v in d.items()) + '\n}\n')
    print(len(T), 'strings in', len(files), 'files')

main()
