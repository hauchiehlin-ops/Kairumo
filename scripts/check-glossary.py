#!/usr/bin/env python3
"""檢查介面字串是否符合詞彙表規範（i18n/glossary.json）。

確保在 `i18n/ui-strings.json` 中沒有殘留已淘汰的同義詞與歧義用語。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GLOSSARY_PATH = ROOT / "i18n/glossary.json"
CATALOG_PATH = ROOT / "i18n/ui-strings.json"


def check_glossary():
    if not GLOSSARY_PATH.exists():
        print(f"❌ 找不到詞彙表：{GLOSSARY_PATH}")
        sys.exit(1)
    if not CATALOG_PATH.exists():
        print(f"❌ 找不到字串表：{CATALOG_PATH}")
        sys.exit(1)

    glossary = json.loads(GLOSSARY_PATH.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    terms = glossary.get("terms", [])
    errors = []

    for term in terms:
        primary_key = term.get("primary_key")
        canonical = term.get("canonical", {})
        deprecated = term.get("deprecated_or_avoid", [])

        # 1. 檢查主鍵標題是否完全等於或符合 canonical 規範
        if primary_key and primary_key in catalog:
            entry = catalog[primary_key]
            for lang, expected_val in canonical.items():
                if lang in entry and entry[lang] != expected_val:
                    errors.append(
                        f"[{primary_key}.{lang}] 應為「{expected_val}」，目前為「{entry[lang]}」"
                    )

        # 2. 檢查所有 key 是否出現了 deprecated 詞彙
        for dep in deprecated:
            is_regex = dep.startswith("regex:")
            pattern = re.compile(dep[6:]) if is_regex else None
            for k, entry in catalog.items():
                if k.startswith("asset_") or "polar" in k:
                    continue
                for lang, text in entry.items():
                    if not isinstance(text, str):
                        continue
                    if is_regex:
                        if pattern.search(text):
                            errors.append(
                                f"[{k}.{lang}] 符合淘汰詞規則「{dep[6:]}」: \"{text}\""
                            )
                    else:
                        if dep in text:
                            errors.append(
                                f"[{k}.{lang}] 包含已淘汰同義詞「{dep}」: \"{text}\""
                            )

    if errors:
        print(f"❌ 發現 {len(errors)} 個詞彙表不符項目：")
        for err in errors:
            print(f"  - {err}")
        return False

    print("✅ 介面字串符合詞彙表規範（i18n/glossary.json）")
    return True


if __name__ == "__main__":
    success = check_glossary()
    sys.exit(0 if success else 1)
