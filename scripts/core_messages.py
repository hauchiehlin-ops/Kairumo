#!/usr/bin/env python3
"""核心（Rust）診斷訊息 → 介面語系的對照表的來源工具。

核心的錯誤訊息是繁體中文（開發語系）。使用者看到的語言由介面決定，所以兩個平台在
「介面邊界」依樣式比對這些訊息、換成使用者語系的句子；沒收錄的訊息才退成通用錯誤。

* 樣式表：`i18n/core-patterns.json`  {鍵: "找不到頁面：{}"}（`{}` = 一個動態片段，依序編號 {1}{2}…）
* 譯文：   `i18n/ui-strings.json` 裡同一個鍵（六語；動態片段寫成 `%1@ %2@`，與介面字串一致）
* 閘門：   `python3 scripts/core_messages.py check` ——
    1. Rust 原始碼裡每一條會被使用者看到的中文訊息（`#[error("…")]` 與已登記的 `format!`）都在樣式表裡
    2. 樣式表裡每一條在目錄裡都有六語
    3. 每種語言的譯文用到的 `%n@` 與繁中一致

為什麼用樣式比對而不是錯誤碼：核心約有 170 條訊息分散在 30 個 crate，改成錯誤碼要動每一個
錯誤型別與兩個平台的橋接；樣式比對不改核心的行為，且閘門保證新增的訊息一定要補譯文。
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _literal_scan import literals  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = ROOT / "i18n/core-patterns.json"
CATALOG = ROOT / "i18n/ui-strings.json"
LANGS = ["zhHant", "en", "zhHans", "ja", "ko", "th"]
CJK = re.compile(r"[一-鿿]")
PLACEHOLDER = re.compile(r"\{[^{}]*\}")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')

# 不是「給使用者的訊息」的檔案或行（目錄資料、開發日誌、expect 訊息、測試）。
SKIP_FILES = ("padnote-i18n/", "padnote-shapes/", "padnote-bench/", "padnote-llm/src/tests.rs",
              "ffi_assets.rs", "ffi_model3d.rs", "padnote-text/src/convert.rs", "ffi_draft_example.rs",
              "padnote-relay/src/main.rs", "padnote-export/src/markdown.rs", "ffi_screens.rs", "padnote-chart/src/layout.rs")
SKIP_LINE = re.compile(r"\.expect\(|panic!|unreachable!|assert|debug_assert")


def normalize(template: str) -> str:
    """Rust 的 `{p}` `{0}` `{:?}` `{WORDLIST_LEN}` 一律視為一個動態片段 `{}`。"""
    return re.sub(r"\s+", " ", PLACEHOLDER.sub("{}", template)).strip()


def rust_unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def scan_rust() -> dict:
    """掃 Rust 非測試程式碼，回傳 {樣式: "檔:行"}。"""
    found = {}
    for f in sorted(ROOT.glob("crates/*/src/**/*.rs")):
        rel = str(f.relative_to(ROOT))
        if any(k in rel for k in SKIP_FILES):
            continue
        for i, line in enumerate(f.read_text().split("\n"), 1):
            if "#[cfg(test)]" in line:
                break
            s = line.strip()
            if s.startswith("//") or SKIP_LINE.search(line) or "tracing::" in line or "eprintln!" in line or "println!" in line:
                continue
            for m in LIT.finditer(line):
                lit = m.group(1)
                if CJK.search(lit):
                    found.setdefault(normalize(rust_unescape(lit)), f"{rel}:{i}")
    return found


def pattern_to_regex(pattern: str) -> str:
    parts = pattern.split("{}")
    return "^" + "(.*?)".join(re.escape(p) for p in parts) + "$"


# 同步日誌的來源檔：這些檔案裡的中文字面值會原樣寫進同步日誌，日誌畫面顯示時才依樣式翻譯，
# 所以每一條都必須出現在某個登記過的樣式裡（可以是完整樣式的一段 —— 有些行是分段串接的）。
LOG_SOURCES = [
    "apple/Sources/NotebookSyncCoordinator.swift", "apple/Sources/DriveHttpClient.swift",
    "apple/Sources/FocusSyncController.swift", "apple/Sources/StorageSweeper.swift",
    "apple/Sources/GoogleAuth.swift",
    "android/app/src/main/java/com/kairumo/padnote/library/CloudSync.kt",
    "android/app/src/main/java/com/kairumo/padnote/sync/FolderSync.kt",
    "android/app/src/main/java/com/kairumo/padnote/sync/FocusSync.kt",
    "android/app/src/main/java/com/kairumo/padnote/platform/StorageSweeper.kt",
    "android/app/src/main/java/com/kairumo/padnote/oauth/GoogleAuth.kt",
]
# 不是日誌訊息的字面值（列舉的顯示名稱等），由程式另外在地化。
LOG_IGNORE = {"iCloud / 資料夾", "系統"}


def scan_log_sources() -> dict:
    found = {}
    for rel in LOG_SOURCES:
        path = ROOT / rel
        if not path.exists():
            continue
        lang = "swift" if rel.endswith(".swift") else "kt"
        for line, lit in literals(path.read_text(), lang):
            if lit not in LOG_IGNORE:
                found.setdefault(lit, f"{rel}:{line}")
    return found


def cmd_check() -> int:
    patterns = json.loads(PATTERNS.read_text())
    catalog = json.loads(CATALOG.read_text())
    known = set(patterns.values())
    problems = []
    for tmpl, where in scan_rust().items():
        if tmpl not in known:
            problems.append(f"Rust 訊息沒有收錄：「{tmpl}」（{where}）— 到 i18n/core-patterns.json 加一條，並在 ui-strings.json 補六語")
    templates = list(patterns.values())
    for lit, where in scan_log_sources().items():
        # 結尾被分段串接切掉的片段（例如 "…確認："）也算收錄：只要是某個樣式的一段。
        if not any(lit in t for t in templates):
            problems.append(f"同步日誌訊息沒有收錄：「{lit}」（{where}）— 到 i18n/core-patterns.json 加一條樣式並補六語")
    for key, tmpl in patterns.items():
        row = catalog.get(key)
        if row is None:
            problems.append(f"{key}：目錄裡沒有")
            continue
        n = tmpl.count("{}")
        for lang in LANGS:
            text = row.get(lang)
            if not text:
                problems.append(f"{key}：缺 {lang}")
                continue
            used = sorted(set(re.findall(r"%(\d+)@", text)))
            want = [str(i) for i in range(1, n + 1)]
            if used != want:
                problems.append(f"{key}（{lang}）：片段應為 %{'@ %'.join(want) + '@' if want else '（無）'}，實際 {used}")
    for p in problems:
        print("❌", p)
    if problems:
        return 1
    print(f"✅ 核心訊息 {len(patterns)} 條，六語齊全，片段一致")
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        return cmd_check()
    if cmd == "scan":  # 列出 Rust 目前有哪些中文訊息（維護用）
        for t, w in scan_rust().items():
            print(f"{w}\t{t}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
