"""
assign_ranks.py — присваивает частотный ранг каждому слову словаря.

Источник частотности: OpenSubtitles Polish 50k (разговорный язык).
Логика:
  1. Строим freq_rank: слово → позиция в частотном списке (1 = самое частое)
  2. Для каждого слова из словаря ищем его форму в списке.
     Polish — флективный язык, поэтому пробуем несколько вариантов:
     - точное совпадение
     - глаголы: убираем -ć/-c (być→by, robić→robi...) — нет, это неверно
     Лучше: берём первое слово из translation как подсказку части речи,
     но проще — просто exact match + lowercase.
  3. Не найденные слова получают rank = 50001 (в конец уровня)
  4. Сортируем внутри каждого уровня по freq_rank
  5. Назначаем порядковый номер (1..N) внутри уровня
  6. Обновляем words.json

Запуск: python3 backend/scripts/assign_ranks.py
"""

import json
from pathlib import Path

FREQ_FILE  = Path('/tmp/pl_freq.txt')
WORDS_FILE = Path('Resources/words.json')
SET_SIZE   = 100   # слов в одном наборе
NOT_FOUND  = 50001

def load_freq(path):
    rank = {}
    for i, line in enumerate(path.read_text(encoding='utf-8').splitlines(), start=1):
        parts = line.strip().split()
        if parts:
            rank[parts[0].lower()] = i
    return rank

def freq_rank(word: str, freq: dict) -> int:
    """Ищем слово в частотном словаре. Для глаголов пробуем форму без -ć."""
    w = word.lower()
    if w in freq:
        return freq[w]
    # Глаголы в инфинитиве часто не встречаются в субтитрах — пробуем основу
    for suffix in ('ić', 'yć', 'ać', 'eć', 'ować', 'nąć', 'ść', 'źć', 'ec', 'ac'):
        if w.endswith(suffix):
            stem = w[:-len(suffix)]
            if stem in freq:
                return freq[stem]
    return NOT_FOUND

def set_label(level: str, set_num: int) -> str:
    return f"{level} · {set_num}"

def main():
    freq = load_freq(FREQ_FILE)
    words = json.loads(WORDS_FILE.read_text(encoding='utf-8'))

    # Присваиваем частотный ранг
    for w in words:
        w['_freq'] = freq_rank(w['polish'], freq)

    # Группируем по уровню, сортируем внутри по частоте
    from collections import defaultdict
    by_level = defaultdict(list)
    for w in words:
        by_level[w['level']].append(w)

    stats = {}
    for level in ('A1', 'A2', 'B1', 'B2'):
        group = sorted(by_level[level], key=lambda w: w['_freq'])
        found = sum(1 for w in group if w['_freq'] < NOT_FOUND)
        stats[level] = {'total': len(group), 'found': found, 'not_found': len(group) - found}

        for i, w in enumerate(group):
            set_num  = i // SET_SIZE + 1
            w['rank']     = i + 1           # позиция внутри уровня (1-based)
            w['category'] = set_label(level, set_num)

    # Убираем служебное поле
    for w in words:
        w.pop('_freq', None)

    WORDS_FILE.write_text(
        json.dumps(words, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8'
    )

    print('Frequency coverage:')
    for level, s in stats.items():
        pct = s['found'] / s['total'] * 100
        print(f"  {level}: {s['total']:4} words | found in corpus: {s['found']:4} ({pct:.0f}%)")

    print()
    # Показываем примеры наборов
    by_cat = {}
    for w in words:
        by_cat.setdefault(w['category'], []).append(w['polish'])

    print('Sample sets (first 5 words each):')
    for cat in sorted(by_cat)[:8]:
        sample = ', '.join(by_cat[cat][:5])
        print(f"  {cat:12} ({len(by_cat[cat]):3} words)  {sample}")

    print(f'\n✓ Updated {len(words)} words in {WORDS_FILE}')

if __name__ == '__main__':
    main()
