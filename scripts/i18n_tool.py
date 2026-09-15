#!/usr/bin/env python3
"""介面字串的單一來源工具（工作包 WP3c）。

為什麼需要它：430 條介面字串原本只活在 Swift 的字典字面值裡。Android 一旦
自己再寫一份，同一句話就有兩個版本，改了一邊忘了另一邊是遲早的事。
這支工具把字串收斂成 i18n/ui-strings.json，再產生兩個平台的字串表 ——
**產生出來的內容與原本逐字相同**，所以 Apple 端的行為不會有任何變化。

用法：
  python3 scripts/i18n_tool.py extract   # 從 Swift 抽出 → i18n/ui-strings.json
  python3 scripts/i18n_tool.py generate  # 由 JSON 產生 Swift 與 Kotlin 字串表
  python3 scripts/i18n_tool.py verify    # 檢查產生結果與來源是否完全一致
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_SRC = ROOT / "apple/Sources/LocalizationManager.swift"
CATALOG = ROOT / "i18n/ui-strings.json"
SWIFT_OUT = ROOT / "apple/Sources/LocalizationStrings.generated.swift"
KOTLIN_OUT = ROOT / "android/app/src/main/java/com/kairumo/padnote/LocalizationStrings.kt"

LANGS = ["zhHant", "en", "zhHans", "ja", "ko", "th"]
LANG_CODES = {
    "zhHant": "zh-Hant", "en": "en", "zhHans": "zh-Hans",
    "ja": "ja", "ko": "ko", "th": "th",
}

ENTRY_RE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*:\s*\[(.*?)\n\s*\]', re.S)
PAIR_RE = re.compile(r'\.(\w+)\s*:\s*"((?:[^"\\]|\\.)*)"')


def swift_unescape(s: str) -> str:
    """把 Swift 字面值裡的跳脫還原成真正的字元。

    不做這一步，`\\"` 會被當成兩個字元帶進 catalog，產生時再跳脫一次就變成
    `\\\\"` —— 畫面上會多出反斜線。這個 bug 是 verify 抓到的。
    """
    out = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def parse_swift_table(text: str) -> dict:
    """從 Swift 的字典字面值抽出 {key: {lang: value}}。"""
    start = text.index("private let stringDictionary")
    body = text[start:]
    out = {}
    for key, block in ENTRY_RE.findall(body):
        pairs = {lang: swift_unescape(value) for lang, value in PAIR_RE.findall(block)}
        if pairs:
            out[swift_unescape(key)] = pairs
    return out


def swift_escape(s: str) -> str:
    return (s.replace("\\", "\\\\").replace('"', '\\"')
             .replace("\n", "\\n").replace("\t", "\\t"))


def kotlin_escape(s: str) -> str:
    return (s.replace("\\", "\\\\").replace('"', '\\"')
             .replace("\n", "\\n").replace("\t", "\\t")
             .replace("$", "\\$"))


def cmd_extract():
    """一次性遷移：把原本寫死在 LocalizationManager 裡的字典搬進 catalog。

    遷移完成後 LocalizationManager 已經不再帶字串表，所以這個子命令會明確
    失敗 —— 這是對的：catalog 才是來源，不該再從 Swift 反向抽取。
    """
    src = SWIFT_SRC.read_text()
    if "private let stringDictionary" not in src:
        print("ℹ️ LocalizationManager 已改用產生表，遷移完成，不需要再 extract。")
        print(f"   要改字串請直接編輯 {CATALOG.relative_to(ROOT)} 後跑 generate。")
        return 0
    table = parse_swift_table(src)
    missing = {k: [l for l in LANGS if l not in v] for k, v in table.items()}
    missing = {k: v for k, v in missing.items() if v}
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps(table, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"抽出 {len(table)} 條字串 → {CATALOG.relative_to(ROOT)}")
    if missing:
        print(f"⚠️ {len(missing)} 條缺語系（保持原樣，不自動補）：{list(missing)[:5]}")


def cmd_generate():
    table = json.loads(CATALOG.read_text())
    keys = sorted(table)

    swift = ['//',
             '//  LocalizationStrings.generated.swift',
             '//  Kairumo',
             '//',
             '//  ⚠️ 這是產生檔，不要手改。',
             '//  來源：i18n/ui-strings.json —— 改字串請改那裡，再跑：',
             '//      python3 scripts/i18n_tool.py generate',
             '//',
             '//  為什麼要產生：同一句話若在 Swift 與 Kotlin 各寫一份，改了一邊',
             '//  忘了另一邊是遲早的事。單一來源 + 產生器讓兩個平台永遠一致。',
             '//',
             '',
             'import Foundation',
             '',
             'extension LocalizationManager {',
             '    /// 由 i18n/ui-strings.json 產生的完整字串表（六國語系）',
             '    static let generatedStrings: [String: [AppLanguage: String]] = [']
    for k in keys:
        swift.append(f'        "{swift_escape(k)}": [')
        rows = [f'            .{lang}: "{swift_escape(table[k][lang])}"'
                for lang in LANGS if lang in table[k]]
        swift.append(",\n".join(rows))
        swift.append('        ],')
    swift[-1] = swift[-1].rstrip(",")
    swift += ['    ]', '}', '']
    SWIFT_OUT.write_text("\n".join(swift))

    kotlin = ['package com.kairumo.padnote',
              '',
              '/**',
              ' * ⚠️ 這是產生檔，不要手改。',
              ' *',
              ' * 來源：i18n/ui-strings.json —— 改字串請改那裡，再跑：',
              ' *     python3 scripts/i18n_tool.py generate',
              ' *',
              ' * 與 Apple 版共用同一份來源，所以兩個平台的用語永遠一致。',
              ' */',
              'object LocalizationStrings {',
              '    val table: Map<String, Map<String, String>> by lazy {',
              '        buildMap {']
    chunk_size = 80
    chunks = [keys[i:i + chunk_size] for i in range(0, len(keys), chunk_size)]
    for idx in range(len(chunks)):
        kotlin.append(f'            putAll(part{idx}())')
    kotlin += ['        }',
               '    }',
               '']

    for idx, chunk in enumerate(chunks):
        kotlin.append(f'    private fun part{idx}(): Map<String, Map<String, String>> = mapOf(')
        for k in chunk:
            rows = [f'            "{LANG_CODES[lang]}" to "{kotlin_escape(table[k][lang])}"'
                    for lang in LANGS if lang in table[k]]
            kotlin.append(f'        "{kotlin_escape(k)}" to mapOf(')
            kotlin.append(",\n".join(rows))
            kotlin.append('        ),')
        kotlin[-1] = kotlin[-1].rstrip(",")
        kotlin.append('    )')
        kotlin.append('')

    kotlin += ['    /** 取字串：找不到語系就退回英文，再退回繁中，最後回傳 key 本身。 */',
               '    fun localized(key: String, language: String): String {',
               '        val entry = table[key] ?: return key',
               '        return entry[language] ?: entry["en"] ?: entry["zh-Hant"] ?: key',
               '    }',
               '}',
               '']
    KOTLIN_OUT.parent.mkdir(parents=True, exist_ok=True)
    KOTLIN_OUT.write_text("\n".join(kotlin))
    print(f"產生 {len(keys)} 條 → {SWIFT_OUT.relative_to(ROOT)}")
    print(f"產生 {len(keys)} 條 → {KOTLIN_OUT.relative_to(ROOT)}")


KOTLIN_ENTRY_RE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*to\s*mapOf\((.*?)\n\s*\)', re.S)
KOTLIN_PAIR_RE = re.compile(r'"([\w-]+)"\s*to\s*"((?:[^"\\]|\\.)*)"')
CODE_TO_LANG = {v: k for k, v in LANG_CODES.items()}


def kotlin_unescape(s: str) -> str:
    return swift_unescape(s)


def parse_kotlin_table(text: str) -> dict:
    """把 Kotlin 產生檔讀回來，確認它與 catalog 帶的是同一批字。"""
    out = {}
    for key, block in KOTLIN_ENTRY_RE.findall(text):
        pairs = {CODE_TO_LANG[code]: kotlin_unescape(v)
                 for code, v in KOTLIN_PAIR_RE.findall(block) if code in CODE_TO_LANG}
        if pairs:
            out[kotlin_unescape(key)] = pairs
    return out


def check_keys_exist(catalog):
    """程式碼裡用到的鍵必須在 catalog 裡。

    產生表與 catalog 一致，不代表程式碼用的鍵都在裡面 —— 打錯一個字
    （`action_done` vs `done`），介面上就直接顯示那個原始鍵名。編譯不會
    報錯、verify 也不會，只有使用者看得到。實際發生過：形狀樣式面板的
    「完成」鈕上印著 action_done。
    """
    missing = {}
    roots = [ROOT / "apple" / "Sources", ROOT / "android" / "app" / "src" / "main" / "java"]
    pattern = re.compile(r'(?:localized|l10n|\bl)\(\s*"([a-z0-9_]+)"')
    for root in roots:
        if not root.exists():
            continue
        for path in list(root.rglob("*.swift")) + list(root.rglob("*.kt")):
            if "Localization" in path.name:
                continue
            for key in pattern.findall(path.read_text(encoding="utf-8")):
                if key not in catalog:
                    missing.setdefault(key, set()).add(path.name)
    if missing:
        print(f"❌ 程式碼用到 {len(missing)} 個 catalog 裡沒有的鍵："
              "介面上會直接印出鍵名")
        for key, files in sorted(missing.items()):
            print(f"    {key}  ← {', '.join(sorted(files))}")
        return 1
    return 0


def cmd_verify():
    """產生的 Swift 表必須與 catalog 逐字相同 —— 這是 Apple 行為不變的憑據。"""
    catalog = json.loads(CATALOG.read_text())
    if check_keys_exist(catalog) != 0:
        return 1
    generated = parse_swift_table(
        SWIFT_OUT.read_text().replace("static let generatedStrings",
                                      "private let stringDictionary"))
    kotlin = parse_kotlin_table(KOTLIN_OUT.read_text())
    if catalog == generated and catalog == kotlin:
        print(f"✅ Swift 與 Kotlin 產生表都與 catalog 完全一致（{len(catalog)} 條）")
        return 0
    if catalog != kotlin:
        only = set(catalog) ^ set(kotlin)
        diff_k = [k for k in set(catalog) & set(kotlin) if catalog[k] != kotlin[k]]
        print(f"❌ Kotlin 表不一致：鍵差異 {len(only)}、內容不同 {len(diff_k)}")
        for k in (list(only)[:3] + diff_k[:3]):
            print("   ", k)
    if catalog == generated:
        return 1
    only_cat = set(catalog) - set(generated)
    only_gen = set(generated) - set(catalog)
    diff = [k for k in set(catalog) & set(generated) if catalog[k] != generated[k]]
    print(f"❌ 不一致：catalog 獨有 {len(only_cat)}、產生檔獨有 {len(only_gen)}、內容不同 {len(diff)}")
    for k in list(only_cat)[:3] + list(only_gen)[:3] + diff[:3]:
        print("   ", k)
    return 1


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "verify"
    sys.exit({"extract": cmd_extract, "generate": cmd_generate, "verify": cmd_verify}[cmd]() or 0)
