"""Merges Localization/staging/<lang>.json into CliDB/Localizable.xcstrings.

    python3 Localization/merge.py            # every staging file
    python3 Localization/merge.py de ja      # only these

Each staging file maps a string key to its translation: a string, or for counted strings in
languages without automatic grammar agreement, plural forms such as {"one": "%lld tool", "other": "%lld tools"}. Format specifiers are checked against
the English value (same count and kinds); a mismatch is reported and that string is skipped.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CATALOG = ROOT.parent / "CliDB" / "Localizable.xcstrings"
SPEC = re.compile(r"%(?:\d+\$)?(@|lld|ld|d|f|\.\d+f|%)")


def specifiers(text: str) -> Counter:
    return Counter(m.group(1) for m in SPEC.finditer(text) if m.group(1) != "%")


def main(langs: list[str]) -> None:
    catalog = json.loads(CATALOG.read_text())
    files = sorted((ROOT / "staging").glob("*.json"))
    if langs:
        files = [f for f in files if f.stem in langs]
    for path in files:
        lang = path.stem
        staged = json.loads(path.read_text())
        added = skipped = 0
        missing = []
        for key, entry in catalog["strings"].items():
            if entry.get("shouldTranslate") is False:
                continue
            value = staged.get(key)
            if not value:
                missing.append(key)
                continue
            english = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", key)
            forms = value if isinstance(value, dict) else {"": value}
            # Inflection markup (^[…](inflect: true)) is stripped before comparing specifiers.
            plain = lambda text: re.sub(r"\^\[(.*?)\]\(inflect: true\)", r"\1", text)
            if any(specifiers(plain(form)) != specifiers(plain(english)) for form in forms.values()):
                print(f"  {lang}: format mismatch, skipped: {key!r} -> {value!r}")
                skipped += 1
                continue
            if isinstance(value, dict):
                plural = {category: {"stringUnit": {"state": "translated", "value": text}} for category, text in value.items()}
                entry.setdefault("localizations", {})[lang] = {"variations": {"plural": plural}}
            else:
                entry.setdefault("localizations", {})[lang] = {"stringUnit": {"state": "translated", "value": value}}
            added += 1
        print(f"{lang}: {added} translated, {skipped} skipped, {len(missing)} missing" + (f" {missing[:5]}" if missing else ""))
    # Xcode writes the catalog with 2-space indentation and " : " separators.
    text = json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
    CATALOG.write_text(text + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
