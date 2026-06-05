#!/usr/bin/env python3
"""
Polish vocabulary generator for Verbum app.

Phase 1: Scrape top-N words from Wiktionary Polish frequency list (Kazojć)
Phase 2: Enrich via Claude API (translation, IPA, category, examples)

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 generate_vocabulary.py [--scrape-only] [--enrich-only]
"""

import json
import os
import re
import ssl
import sys
import time
import argparse
import urllib.request

import certifi

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
SCRAPED_FILE  = os.path.join(SCRIPT_DIR, "words_scraped.json")
OUTPUT_FILE   = os.path.join(SCRIPT_DIR, "words_generated.json")
PROGRESS_FILE = os.path.join(SCRIPT_DIR, "words_progress.json")

WIKTIONARY_URL = (
    "https://pl.wiktionary.org/wiki/"
    "Indeks:Polski_-_Najpopularniejsze_s%C5%82owa_1-10000_wersja_Jerzego_Kazojcia"
)

TARGET_WORDS = 5000
SCRAPE_TOP_N = 5500
BATCH_SIZE   = 20

# ---------------------------------------------------------------------------
# PHASE 1: SCRAPE
# ---------------------------------------------------------------------------

def scrape_frequency_list(top_n: int) -> list[dict]:
    print(f"Fetching Wiktionary frequency list...")
    req = urllib.request.Request(
        WIKTIONARY_URL,
        headers={"User-Agent": "VerbumApp/1.0 vocab-generator (educational)"},
    )
    ctx = ssl.create_default_context(cafile=certifi.where())
    with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
        html = resp.read().decode("utf-8")

    # Format on page: <a ...>word</a>=frequency
    pattern = re.compile(
        r">([a-zA-ZÀ-ž\-]+)</a>[^\d<]{0,10}(\d[\d ]*)",
        re.UNICODE,
    )
    seen = {}
    for m in pattern.finditer(html):
        word = m.group(1).strip()
        freq_str = m.group(2).replace(" ", "")
        if len(word) < 2:
            continue
        try:
            freq = int(freq_str)
            if freq > 10 and word not in seen:
                seen[word] = freq
        except ValueError:
            pass

    sorted_words = sorted(seen.items(), key=lambda x: -x[1])
    top = sorted_words[:top_n]
    result = [{"polish": w, "frequency": f, "rank": i + 1}
              for i, (w, f) in enumerate(top)]
    print(f"  Got {len(result)} words")
    return result


# ---------------------------------------------------------------------------
# PHASE 2: ENRICH
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
Ты обогащаешь польский частотный словарь для приложения изучения польского языка.
Целевая аудитория: русскоязычные, украинцы, белорусы.
Возвращай ТОЛЬКО валидный JSON-массив — без markdown, без пояснений.

Для каждого слова верни объект:
{
  "polish": "базовая форма (им. ед.ч. для сущ., инфинитив для глаг.)",
  "translation": "перевод на русский, 1-4 слова",
  "transcription": "IPA в квадратных скобках",
  "partOfSpeech": "rzecz. / czas. / przym. / przysł. / przyim. / zaim. / licz. / spój. / part.",
  "category": "одна категория из списка",
  "level": "A1 / A2 / B1 / B2",
  "example": "живое польское предложение с этим словом",
  "examplesList": ["предложение1", "предложение2", "предложение3"],
  "imageName": "snake_case английское название иконки"
}

Категории:
Семья и люди, Еда и напитки, Дом и быт, Цвета и формы, Числа и количество,
Время и календарь, Животные, Тело и здоровье, Одежда и мода, Город и места,
Транспорт и путешествия, Природа и погода, Эмоции и чувства, Прилагательные,
Повседневные глаголы, Глаголы движения, Глаголы общения, Образование,
Работа и профессии, Развлечения и культура, Технологии, Спорт и активность,
Наречия, Служебные слова, Польские реалии

Правила:
- Приводи к базовой форме
- Примеры разговорные, не учебные
- IPA точный
- Вернуть РОВНО столько объектов, сколько слов на входе
- Первый символ [, последний ]"""


def enrich_batch(client, words: list[str]) -> list[dict]:
    import anthropic

    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=16000,
        system=SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"Обогати {len(words)} слов:\n{json.dumps(words, ensure_ascii=False)}"
        }],
    )

    text = response.content[0].text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        end = -1 if lines[-1].startswith("```") else len(lines)
        text = "\n".join(lines[1:end])

    data = json.loads(text)
    if not isinstance(data, list):
        raise ValueError("Response is not a list")
    return data


# ---------------------------------------------------------------------------
# ORCHESTRATION
# ---------------------------------------------------------------------------

def load_progress(scraped_words: list[dict] | None = None) -> dict:
    # Resume from progress checkpoint if exists
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    # Resume from already-generated output (credits ran out mid-run).
    # Claude lemmatizes words so string matching fails — instead we assume
    # generation ran in rank order and mark the first N ranks as done,
    # where N ≈ words_generated * (SCRAPE_TOP_N / TARGET_WORDS) with a buffer.
    if os.path.exists(OUTPUT_FILE) and scraped_words:
        with open(OUTPUT_FILE) as f:
            existing = json.load(f)
        if existing:
            n = len(existing)
            # Attach sequential ranks/frequencies back for finalize step
            for i, w in enumerate(existing):
                if "rank" not in w and i < len(scraped_words):
                    w["rank"] = scraped_words[i]["rank"]
                    w["frequency"] = scraped_words[i]["frequency"]
            # Mark first n ranks as processed (generation is sequential)
            done_ranks = [w["rank"] for w in scraped_words[:n]]
            print(f"  Resuming from {OUTPUT_FILE}: {n} words done, "
                  f"marking ranks 1–{done_ranks[-1]} as processed")
            return {"processed_ranks": done_ranks, "words": existing}
    return {"processed_ranks": [], "words": []}


def save_progress(progress: dict):
    with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)


def run_scrape():
    words = scrape_frequency_list(SCRAPE_TOP_N)
    with open(SCRAPED_FILE, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"Saved to {SCRAPED_FILE}")
    return words


def run_enrich(scraped_words: list[dict]):
    import anthropic

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY not set")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)
    progress = load_progress(scraped_words)

    done_ranks = set(progress["processed_ranks"])
    all_enriched = progress["words"]

    remaining = [w for w in scraped_words[:SCRAPE_TOP_N] if w["rank"] not in done_ranks]
    print(f"To enrich: {len(remaining)} words (done: {len(all_enriched)})")

    batches = [remaining[i:i+BATCH_SIZE] for i in range(0, len(remaining), BATCH_SIZE)]

    for idx, batch in enumerate(batches):
        words_only = [w["polish"] for w in batch]
        ranks = [w["rank"] for w in batch]

        print(f"Batch {idx+1}/{len(batches)} (ranks {ranks[0]}-{ranks[-1]}) ... ", end="", flush=True)

        for attempt in range(1, 4):
            try:
                enriched = enrich_batch(client, words_only)

                for i, item in enumerate(enriched):
                    orig = batch[i] if i < len(batch) else batch[-1]
                    item["rank"] = orig["rank"]
                    item["frequency"] = orig["frequency"]

                all_enriched.extend(enriched)
                done_ranks.update(ranks)
                progress["processed_ranks"] = list(done_ranks)
                progress["words"] = all_enriched
                save_progress(progress)

                print(f"OK (total: {len(all_enriched)})")
                break

            except (json.JSONDecodeError, ValueError) as e:
                print(f"\n  attempt {attempt} failed (parse): {e}")
                if attempt == 3:
                    print("  skipped")
                else:
                    time.sleep(5 * attempt)
            except Exception as e:
                print(f"\n  attempt {attempt} failed: {type(e).__name__}: {e}")
                if attempt == 3:
                    print("  skipped")
                else:
                    time.sleep(10 * attempt)

        time.sleep(1)

    return all_enriched


def finalize(enriched: list[dict]) -> list[dict]:
    seen = {}
    for w in enriched:
        pol = w.get("polish", "").lower()
        if not pol:
            continue
        if pol not in seen or w.get("rank", 9999) < seen[pol].get("rank", 9999):
            seen[pol] = w

    sorted_words = sorted(seen.values(), key=lambda x: x.get("rank", 9999))
    top = sorted_words[:TARGET_WORDS]

    return [{
        "id": i,
        "category": w.get("category", "Повседневные глаголы"),
        "level": w.get("level", "A2"),
        "polish": w.get("polish", ""),
        "translation": w.get("translation", ""),
        "transcription": w.get("transcription", ""),
        "partOfSpeech": w.get("partOfSpeech", "rzecz."),
        "example": w.get("example", ""),
        "examplesList": (w.get("examplesList") or [])[:3],
        "imageName": w.get("imageName", ""),
    } for i, w in enumerate(top, 1)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scrape-only", action="store_true")
    parser.add_argument("--enrich-only", action="store_true")
    args = parser.parse_args()

    if not args.enrich_only:
        scraped = run_scrape()
    else:
        if not os.path.exists(SCRAPED_FILE):
            print(f"ERROR: {SCRAPED_FILE} not found. Run without --enrich-only first.")
            sys.exit(1)
        with open(SCRAPED_FILE) as f:
            scraped = json.load(f)
        print(f"Loaded {len(scraped)} scraped words")

    if args.scrape_only:
        return

    enriched = run_enrich(scraped)
    final = finalize(enriched)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final, f, ensure_ascii=False, indent=2)

    print(f"\nDone! {len(final)} words -> {OUTPUT_FILE}")
    if os.path.exists(PROGRESS_FILE):
        os.remove(PROGRESS_FILE)

    levels = {}
    for w in final:
        levels[w["level"]] = levels.get(w["level"], 0) + 1
    print("Levels:", dict(sorted(levels.items())))


if __name__ == "__main__":
    main()
