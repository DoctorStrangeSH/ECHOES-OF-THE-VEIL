#!/usr/bin/env python3
"""Proofreading pass over every player-facing string (data/localization).

Errors (fail CI): doubled spaces, space before punctuation, a word mixing
Latin and Cyrillic letters (a classic typo: Latin 'o' in a Russian word),
unbalanced quotes/brackets, a doubled word ("the the", "и и"), a missing
translation that is identical to the English in the Russian column.
Warnings: three or more very short sentences in a row ("Ночь. Темно. Тихо."),
the flat style the narrative guide (docs/narrative/style-guide.ru.md) avoids.
Narrator voice (D-079): Russian narration and UI address the player as "вы".
Lines spoken by a character (a dialogue node with a speaker, a player
choice, passer-by chatter) and text inside «» or „“ may say "ты"; anything
else that uses "ты"/"твой" or a 2nd-person-singular verb is an error.

    python3 tools/text_lint.py          # report
"""
import glob, json, re, sys

MIXED = re.compile(r'\b(?=\w*[a-zA-Z])(?=\w*[а-яА-ЯёЁ])\w+\b')
DOUBLE_WORD = re.compile(r'\b(\w{2,})\s+\1\b', re.I)
SENT = re.compile(r'[^.!?…]+[.!?…]+')
SKIP_SHORT = re.compile(r'^(HUD_|SETTINGS_|MENU_|PROMPT_|GUIDE_|WAIT_|PERIOD_|CC_|JOURNAL_|ITEM_|LOC_|BOSS_|NPC_|EXP_MOD_|INC_|TOAST_|BG_)')


def check(key, lang, s, errors, warnings):
    where = f'{key} [{lang}]'
    if '  ' in s.replace('\n', ' \n').replace(' \n', '\n'):
        errors.append(f'{where}: double space')
    if re.search(r' [,.!?;:…](?!\.)', s) and not re.search(r' \.\.\.', s):
        errors.append(f'{where}: space before punctuation')
    m = MIXED.search(s)
    if m and lang == 'ru':
        errors.append(f'{where}: mixed Latin/Cyrillic word "{m.group(0)}"')
    for a, b in ('()', '[]', '«»'):
        if s.count(a) != s.count(b):
            errors.append(f'{where}: unbalanced {a}{b}')
    if s.count('"') % 2:
        errors.append(f'{where}: odd number of "')
    if lang == 'ru':
        # Quotes inside quotes are „лапки“ (style guide), never «« »».
        depth = 0
        for ch in s:
            if ch == '«':
                depth += 1
                if depth > 1:
                    errors.append(f'{where}: «» inside «»; use „“ for a quote within a quote')
                    break
            elif ch == '»':
                depth = max(0, depth - 1)
        if re.search(r'Лантерн|ЛАНТЕРН', s):
            errors.append(f'{where}: Lantern Row is «Фонарный ряд» in Russian')
    d = DOUBLE_WORD.search(s)
    if d and d.group(1).lower() not in ('ha', 'ха', 'no', 'нет', 'да', 'yes', 'tick', 'тик', 'ш'):
        errors.append(f'{where}: doubled word "{d.group(0)}"')
    if not SKIP_SHORT.match(key):
        sents = [x.strip() for x in SENT.findall(s)]
        run = 0
        for x in sents:
            run = run + 1 if len(x.split()) <= 2 else 0
            if run >= 3:
                warnings.append(f'{where}: three very short sentences in a row: "{s[:60]}…"')
                break


TY = re.compile(r'(?<![а-яёА-ЯЁ])(ты|тебя|тебе|тобой|твой|твоя|твоё|твои|твоих|твоей|твоему|твоим|твою)(?![а-яёА-ЯЁ])', re.I)
V2SG = re.compile(r'(?<![а-яёА-ЯЁ])[а-яё]{3,}(ешь|ёшь|ишь)(ся)?(?![а-яёА-ЯЁ])', re.I)
NOT_VERB = {'лишь', 'мышь', 'тишь', 'глушь', 'вишь', 'камыш', 'малыш', 'шалаш', 'гараж'}
SPOKEN_PREFIX = ('CHATTER_',)


def spoken_keys():
    """Keys a character says (speaker set) or the player picks (choices)."""
    out = set()
    for f in glob.glob('data/dialogue/*.json'):
        for d in json.load(open(f)).values():
            if not isinstance(d, dict):
                continue
            for n in d.get('nodes', {}).values():
                if n.get('speaker') and 'text' in n:
                    out.add(n['text'])
                for c in n.get('choices', []):
                    out.add(c.get('text'))
    return out


def check_voice(key, ru, spoken, errors):
    if key in spoken or key.startswith(SPOKEN_PREFIX):
        return
    narr = re.sub(r'«[^»]*»|„[^“]*“', '', ru)
    m = TY.search(narr)
    v = [x.group(0) for x in V2SG.finditer(narr) if x.group(0).lower() not in NOT_VERB]
    if m or v:
        errors.append(f'{key} [ru]: narration says "ты" ("{m.group(0) if m else v[0]}"); the narrator uses "вы"')


def main():
    errors, warnings = [], []
    spoken = spoken_keys()
    for f in sorted(glob.glob('data/localization/*.json')):
        for k, v in json.load(open(f)).items():
            if not isinstance(v, dict):
                continue
            for lang in ('en', 'ru'):
                if isinstance(v.get(lang), str):
                    check(k, lang, v[lang], errors, warnings)
            en, ru = v.get('en', ''), v.get('ru', '')
            if isinstance(ru, str):
                check_voice(k, ru, spoken, errors)
            if en and ru and en == ru and not k.endswith('END_TITLE') and re.search(r'[a-zA-Z]{4,}', en) and not SKIP_SHORT.match(k) and ' ' in en:
                errors.append(f'{k}: Russian text is still English')
    for w in warnings:
        print('warning:', w)
    for e in errors:
        print('ERROR:', e)
    print(f'text: {len(errors)} errors, {len(warnings)} warnings')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
