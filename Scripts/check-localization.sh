#!/usr/bin/env bash
#
# Localization guard for Verbum.
#
# Checks:
#   1. Key parity across ru/en/uk Localizable.strings (no missing translations).
#   2. No duplicate keys within a single .strings file.
#   3. Every L("key") used in Swift code has a matching key in the catalog.
#   4. No hardcoded Cyrillic UI copy left in SwiftUI wrappers under Views/.
#
# Exit code is non-zero if any check fails. Run from anywhere:
#   Scripts/check-localization.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RES="Resources"
RU="$RES/ru.lproj/Localizable.strings"
EN="$RES/en.lproj/Localizable.strings"
UK="$RES/uk.lproj/Localizable.strings"

# Native language names shown in their own language on the language picker — these
# are intentionally not localized. Add real exceptions here, sparingly.
ALLOWLIST_REGEX='"(Русский|Українська)"'

fail=0

# ── Checks 1–3: parity, duplicates, and L() usage (Python for robust parsing) ──
python3 - "$RU" "$EN" "$UK" <<'PY' || fail=1
import re, sys, glob, os

ru_path, en_path, uk_path = sys.argv[1:4]
key_line = re.compile(r'^\s*"([^"]+)"\s*=')

def load(path):
    keys, dups = [], []
    seen = set()
    for line in open(path, encoding='utf-8'):
        m = key_line.match(line)
        if not m:
            continue
        k = m.group(1)
        if k in seen:
            dups.append(k)
        seen.add(k)
        keys.append(k)
    return set(keys), dups

ok = True
sets = {}
for name, path in (('ru', ru_path), ('en', en_path), ('uk', uk_path)):
    s, dups = load(path)
    sets[name] = s
    if dups:
        ok = False
        print(f"[dup] {name}: duplicate keys: {sorted(set(dups))}")

union = sets['ru'] | sets['en'] | sets['uk']
for name in ('ru', 'en', 'uk'):
    missing = union - sets[name]
    if missing:
        ok = False
        print(f"[parity] {name} is missing {len(missing)} keys: {sorted(missing)}")

# Every L("key") in code must exist in the catalog (ru = source of truth).
use_re = re.compile(r'\bL\(\s*"([^"]+)"')
used = set()
for path in glob.glob('**/*.swift', recursive=True):
    if path.startswith('.') or '/.' in path or '/worktrees/' in path:
        continue
    with open(path, encoding='utf-8') as f:
        for line in f:
            used.update(use_re.findall(line))

undefined = sorted(k for k in used if k not in sets['ru'])
if undefined:
    ok = False
    print(f"[usage] {len(undefined)} L(...) keys not defined in catalog: {undefined}")

print(f"[ok] catalog: {len(sets['ru'])} keys x3, {len(used)} distinct keys used in code" if ok
      else "[FAIL] catalog checks failed")
sys.exit(0 if ok else 1)
PY

# ── Check 4: hardcoded Cyrillic in SwiftUI wrappers under Views/ ──
WRAPPERS='(Text|Button|Label|Section|Picker|TextField|SecureField|DatePicker|navigationTitle|tabItem|alert)\(\s*"[^"]*[А-Яа-яЁёІіЇїЄєҐґ]'
if hits="$(grep -rnE "$WRAPPERS" --include='*.swift' Views 2>/dev/null | grep -vE "$ALLOWLIST_REGEX" || true)"; [ -n "$hits" ]; then
    echo "[hardcoded] Cyrillic string literals found in SwiftUI wrappers (use L(\"key\")):"
    echo "$hits"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "❌ Localization check failed."
    exit 1
fi
echo "✅ Localization check passed."
