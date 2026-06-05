"""
sjp_enrich.py — два прохода по SJP морфобазе:
  1. Переиндексирует частотный корпус через леммы → улучшает rank
  2. Для каждого слова находит ключевые флексии → добавляет в words.json

Запуск: python3 backend/scripts/sjp_enrich.py

Зависимости: только stdlib
"""

import json, re
from pathlib import Path
from collections import defaultdict

ODM_FILE   = Path('/tmp/sjp-odm/odm.txt')
FREQ_FILE  = Path('/tmp/pl_freq.txt')
WORDS_FILE = Path('Resources/words.json')
SET_SIZE   = 100
NOT_FOUND  = 50001

# ─── 1. Парсинг SJP ──────────────────────────────────────────────────────────

def load_sjp(path):
    """
    Возвращает два словаря:
      lemma_forms: lemma → [форма, форма, ...]
      form_lemma:  форма → lemma  (каждая форма → её лемма)
    """
    lemma_forms = {}
    form_lemma  = {}

    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(',')]
        lemma = parts[0].lower()
        forms = [p.lower() for p in parts]   # включая саму лемму

        lemma_forms[lemma] = forms
        for f in forms:
            if f not in form_lemma:           # первая встреченная лемма побеждает
                form_lemma[f] = lemma

    return lemma_forms, form_lemma

# ─── 2. Частотный словарь ────────────────────────────────────────────────────

def load_freq(path):
    """форма → ранг (позиция в файле, 1 = самое частое)"""
    freq = {}
    for i, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        parts = line.strip().split()
        if parts:
            freq[parts[0].lower()] = i
    return freq

def lemma_freq_rank(lemma: str, freq: dict, form_lemma: dict, lemma_forms: dict) -> int:
    """
    Лучший (минимальный) ранг среди всех форм леммы.
    Если лемма есть в freq напрямую — берём её.
    Иначе перебираем все её формы из SJP.
    """
    w = lemma.lower()
    best = freq.get(w, NOT_FOUND)
    if best <= 1000:                          # достаточно точно, не ищем дальше
        return best
    for form in lemma_forms.get(w, []):
        r = freq.get(form, NOT_FOUND)
        if r < best:
            best = r
    return best

# ─── 3. Ключевые флексии ─────────────────────────────────────────────────────

def pick_inflections(lemma: str, pos: str, forms: list[str]) -> dict:
    """
    Выбирает самые важные формы для карточки.
    pos — partOfSpeech из нашего словаря (czas., rzecz., przym., przysł., ...)
    """
    if not forms:
        return {}

    lemma = lemma.lower()

    # Суффиксы которые маркируют НЕ личные формы (причастия, герундии, кондиционал)
    PARTICIPLE = ('ący', 'ąca', 'ące', 'ącego', 'ącej', 'ącemu', 'ącym', 'ącymi',
                  'any', 'ana', 'ane', 'anego', 'anej', 'anemu', 'anych', 'anym',
                  'ony', 'ona', 'one', 'onego', 'onej', 'onemu', 'onych', 'onym',
                  'ani', 'iani', 'ieni',
                  'eni', 'enie', 'enia', 'eniem', 'eniom', 'eniu', 'eń',
                  'awszy', 'ąwszy', 'wszy',
                  # герундии (verbal nouns)
                  'anie', 'ania', 'aniem', 'aniom', 'aniu', 'ań',
                  'ycie', 'ycia', 'yciem', 'yciu',
                  'icie', 'icia', 'iciem', 'iciu',
                  # прошедшее время (личные формы)
                  'łam', 'łem', 'łaś', 'łeś', 'łom',
                  # кондиционал
                  'łby', 'łaby', 'łoby', 'łyby', 'liby', 'łbym', 'łbyś',
                  'łabym', 'łabyś', 'łobyśmy', 'łobyście',
                  'by', 'byś', 'bym', 'byśmy', 'byście',
                  # эмфатические формы (только -że, не -ż чтобы не ломать imp)
                  'że')

    def is_personal(x):
        return (not x.startswith('nie')
                and not any(x.endswith(s) for s in PARTICIPLE)
                and len(x) > 1)

    # ── Глагол (czas.) ───────────────────────────────────────────────────────
    if 'czas.' in pos:
        result = {}

        # 1sg (ę/am/em/uję)
        for ending in ('uję', 'uję', 'ę', 'am', 'em'):
            cands = [x for x in forms if x.endswith(ending) and is_personal(x) and x != lemma]
            if cands:
                result['1sg'] = min(cands, key=len)
                break

        # 3sg — исключаем: 2pl imp (-cie/-ście), 3pl past (-ły/-li),
        #         инструменталь мн.ч. (-ami/-ymi/-imi/-mi), кондиционал (-by)
        EXCLUDE_3SG = ('cie', 'ście', 'ły', 'li', 'ła', 'ąc', 'wszy', 'my',
                       'ami', 'ymi', 'imi', 'mi', 'że', 'łam', 'łem',
                       'łaś', 'łeś', 'łom')
        def ok_3sg(x):
            return (is_personal(x) and x != lemma
                    and not any(x.endswith(s) for s in EXCLUDE_3SG)
                    and abs(len(x) - len(lemma)) <= 4)

        for ending in ('uje', 'aje', 'ie', 'y', 'i', 'e', 'a'):
            if ending == 'ie':
                cands = [x for x in forms if x.endswith('ie') and ok_3sg(x)
                         and not x.endswith('cie')]
            elif ending == 'a':
                # -a: только если форма ≤ длины леммы + 1 (исключает длинные причастные формы)
                cands = [x for x in forms if x.endswith('a') and ok_3sg(x)
                         and len(x) <= len(lemma) + 1]
            else:
                cands = [x for x in forms if x.endswith(ending) and ok_3sg(x)]
            if cands:
                result['3sg'] = min(cands, key=len)
                break

        # past masc sg (форма на -ł без причастных суффиксов)
        cands = [x for x in forms if x.endswith('ł') and is_personal(x)
                 and not x.endswith(('ały', 'ęły'))]
        if cands:
            result['past'] = min(cands, key=len)

        # imperative — предпочитаем -aj/-ej/-ij, затем самую короткую личную форму
        imp_aj = [x for x in forms if x.endswith(('aj', 'ej', 'ij'))
                  and is_personal(x) and not x.startswith('nie')
                  and len(x) <= len(lemma) + 1]
        if imp_aj:
            result['imp'] = min(imp_aj, key=len)
        else:
            cands = [x for x in forms if is_personal(x) and x != lemma
                     and len(x) <= len(lemma) - 1
                     and not x.endswith(('my', 'cie', 'ły', 'ła', 'li'))]
            if cands:
                result['imp'] = min(cands, key=len)

        return result

    # ── Существительное (rzecz.) — Gen.sg + Nom.pl ───────────────────────────
    if 'rzecz.' in pos:
        result = {}
        base = [x for x in forms if not x.startswith('nie') and x != lemma and len(x) > 1]

        # Gen.sg — вторая форма в SJP почти всегда Gen.sg (стандарт словаря)
        # Ищем форму близкую по длине к lemma (±2) с типичным окончанием
        gen_cands = [x for x in base if x.endswith(('a', 'i', 'y', 'u', 'e'))
                     and abs(len(x) - len(lemma)) <= 2]
        if gen_cands:
            result['gen'] = min(gen_cands, key=lambda x: abs(len(x) - len(lemma)))

        # Nom.pl — ищем форму с типичными окончаниями мн.ч.
        for ending in ('owie', 'ie', 'y', 'i', 'e', 'a'):
            pl_cands = [x for x in base if x.endswith(ending) and x != result.get('gen')
                        and len(x) >= len(lemma) - 2]
            if pl_cands:
                result['pl'] = min(pl_cands, key=lambda x: abs(len(x) - len(lemma)))
                break

        return result

    # ── Прилагательное (przym.) — fem.sg + virile pl ─────────────────────────
    if 'przym.' in pos:
        result = {}
        base = [x for x in forms if not x.startswith('nie') and x != lemma]

        fem = [x for x in base if x.endswith(('na', 'wa', 'ka', 'ga', 'da', 'ta',
                                               'ra', 'la', 'ma', 'pa', 'ba', 'fa'))
               and abs(len(x) - len(lemma)) <= 1]
        if not fem:
            fem = [x for x in base if x.endswith('a') and abs(len(x) - len(lemma)) <= 1]
        if fem:
            result['fem'] = min(fem, key=len)

        # Virile plural (мужской личный) — оканчивается на -i или -si/ci/dzi/ni
        vir = [x for x in base if x.endswith('i') and len(x) >= len(lemma) - 2]
        if vir:
            result['pl'] = min(vir, key=len)

        return result

    return {}

# ─── main ─────────────────────────────────────────────────────────────────────

def main():
    print('→ Loading SJP morphological database...')
    lemma_forms, form_lemma = load_sjp(ODM_FILE)
    print(f'  {len(lemma_forms):,} lemmas, {len(form_lemma):,} forms')

    print('→ Loading frequency corpus...')
    freq = load_freq(FREQ_FILE)
    print(f'  {len(freq):,} entries')

    print('→ Processing vocabulary...')
    words = json.loads(WORDS_FILE.read_text(encoding='utf-8'))

    from collections import Counter
    by_level = defaultdict(list)
    not_in_sjp = 0
    pos_stats = Counter()

    for w in words:
        lemma = w['polish'].lower()
        pos   = w.get('partOfSpeech', '')

        # Флексии
        forms = lemma_forms.get(lemma)
        if forms:
            inflections = pick_inflections(lemma, pos, forms)
            w['inflections'] = inflections
        else:
            w['inflections'] = {}
            not_in_sjp += 1

        # Частотный ранг через леммы
        w['_freq'] = lemma_freq_rank(lemma, freq, form_lemma, lemma_forms)
        by_level[w['level']].append(w)
        pos_stats[pos] += 1

    # Пересортировка и переназначение категорий
    for level in ('A1', 'A2', 'B1', 'B2'):
        group = sorted(by_level[level], key=lambda w: w['_freq'])
        for i, w in enumerate(group):
            w['rank']     = i + 1
            w['category'] = f"{level} · {i // SET_SIZE + 1}"

    for w in words:
        w.pop('_freq', None)

    WORDS_FILE.write_text(
        json.dumps(words, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8'
    )

    # ─── Статистика ───────────────────────────────────────────────────────────
    print(f'\nCoverage:')
    for level in ('A1', 'A2', 'B1', 'B2'):
        group = by_level[level]
        found = sum(1 for w in group if w.get('_freq', NOT_FOUND) < NOT_FOUND
                    or lemma_freq_rank(w['polish'].lower(), freq, form_lemma, lemma_forms) < NOT_FOUND)
        # пересчитаем честно
        covered = sum(1 for w in group
                      if lemma_freq_rank(w['polish'].lower(), freq, form_lemma, lemma_forms) < NOT_FOUND)
        print(f'  {level}: {len(group):4} words | freq coverage: {covered:4} ({covered/len(group)*100:.0f}%)')

    with_infl = sum(1 for w in words if w.get('inflections'))
    print(f'\nInflections: {with_infl}/{len(words)} words have forms ({with_infl/len(words)*100:.0f}%)')
    print(f'Not in SJP:  {not_in_sjp} words')

    # Примеры
    print('\nSample inflections:')
    for w in words[:200]:
        if w.get('inflections') and w['inflections']:
            infl_str = ', '.join(f"{k}={v}" for k,v in w['inflections'].items())
            print(f"  {w['polish']:20} [{w.get('partOfSpeech',''):8}] → {infl_str}")
            if sum(1 for x in words[:200] if x.get('inflections')) >= 8:
                break

    print(f'\n✓ Updated {len(words)} words in {WORDS_FILE}')

if __name__ == '__main__':
    main()
