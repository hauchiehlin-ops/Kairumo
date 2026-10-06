#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""介面上不准出現硬寫死的文字（一致性閘門）。

# 為什麼需要它

2026-09-22 重拍操作手冊時，把 App 切成英文，畫面上一堆中文：
右上角「診斷」、「尚未設定同步（點擊進入設定）」、整個 Whisper 下載面板、
整個同步設定面板。**非中文的使用者看到的就是這樣**，而這件事沒有任何東西
擋得住 —— 盤點結果 Apple 端 59 處、Android 端 3 處。

字串表（`i18n/ui-strings.json` → 兩端的產生表）早就存在，而且 CI 會驗證
它們一致。問題從來不是「沒有機制」，是**沒有東西阻止你繞過那個機制**。
直接寫 `Text("診斷")` 一樣會編譯、一樣會跑，只是別的語言看不懂。

所以這裡把「不准繞過」寫成會擋下來的檢查。

# 它擋什麼

兩條規則：

1. `Text("…")`、`Label("…")`、`.accessibilityLabel("…")` 裡出現 CJK。
2. CJK 字面值被指派給看起來是給人看的欄位（title、message、snippet…）。

第二條是必要的：`previewSnippet: "建立於 …"` 是一個資料欄位，第一條看不到它，
而它就顯示在首頁的每一張筆記卡片上。
只看 CJK 是刻意的：純英文的字面值有可能是識別字、格式字串或除錯用的東西，
一律禁止會有大量誤報，而誤報多的閘門會被關掉。CJK 幾乎一定是給人看的字。

用法：
    python3 scripts/check-hardcoded-strings.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CJK = re.compile(r"[一-鿿぀-ヿ가-힯฀-๿]")
# 會把字串直接顯示出來的建構子／修飾詞。
#
# 名單是**逐次補出來的**，每一次都是在真實畫面上先看到中文才知道漏了誰：
# Text/Label（第一版）→ 資料欄位（previewSnippet）→ Button/Picker/Toggle…
# 這說明一件事：靜態規則永遠落後於畫面。它擋得住回歸，但找不完新洞。
CALL = re.compile(
    r"(?:Text|Label|Button|Toggle|TextField|SecureField|Picker|Section|Stepper|Link"
    r"|Menu|confirmationDialog|alert|navigationTitle|\.accessibilityLabel|\.help)"
    r'\(\s*"((?:[^"\\]|\\.)*)"'
)

# 第二條規則：CJK 字面值被指派給「看起來是給人看的」欄位或變數。
#
# 只看 `Text("…")` 是不夠的 —— 2026-09-22 拍截圖時看到筆記卡片上寫著
# 「建立於 Sep 22, 2026」，那是 `previewSnippet: "建立於 …"`，一個**資料欄位**，
# 第一條規則完全看不到它。同一天用這條規則又翻出 33 處：調色盤的標籤、
# 同步說明頁、範例筆記標題、逾時訊息、Android 的 toast。
#
# 欄位名單刻意挑得保守：太寬會把日誌訊息與內部識別字一起擋掉，
# 而誤報多的閘門會被關掉。
UI_FIELD = r"(?:title|subtitle|label|message|snippet|caption|placeholder|description|hint|text|name|summary|tip|note|prompt|error|status)"
ASSIGN = re.compile(rf'\b{UI_FIELD}\w*\s*[:=]\s*"((?:[^"\\]|\\.)*)"', re.I)

# 第三條規則（2026-10-06 補上）：CJK 字面值被**傳給會顯示給使用者的地方**，而不是直接寫在 Text 裡 ——
# 錯誤訊息（NSError、throw、onError、failures、lastMessage…）、狀態字串、無障礙描述。
#
# 為什麼要再補：前兩條抓得到 `Text("診斷")`，抓不到 `homeGoogleMessage = "同步逾時…"`、
# `throw NSError(…"音訊檔案不存在")`、`onError?("裝置未連接麥克風")` —— 這些字一樣會出現在畫面上
# （狀態卡、警示對話框、錄音錯誤），而且整批都是中文，切到英文就看到。實際查出約 140 處。
#
# 不擋的：寫進同步日誌／啟動日誌／NSLog 的字（開發者看的）、`case x = "中文"` 這種已落盤的識別字，
# 以及行尾帶 `i18n-ok` 的（要寫明為什麼）。
MESSAGE_SINKS = re.compile(
    r"(?:NSLocalizedDescriptionKey\s*:|\bdetail\s*:|\bonError\??\(|\.server\(|\.coreRejected\(|LocationError\.\w+\("
    r"|\.recognitionFailed\(|\breason\s*:|\bdesc\s*:|\bfailures\[[^\]]*\]\s*=|\blastMessage\s*=|\b\w*(?:Message|Status|Error)Text?\w*\s*=(?!=)"
    r"|\bthrow\s+\w+(?:\.\w+)?\(|\berror\(|requireNotNull\([^)]*\)\s*\{|contentDescription\s*=|\.failure\(\.?\w+\()"
    r'\s*"((?:[^"\\]|\\.)*)"'
)
LOGGING = re.compile(
    r"SyncLogger|StartupLogger|NSLog|print\(|os_log|Logger\.|\.logAsync|\.log\(|Log\.[dwiev]\(|println|fatalError|assert|precondition"
)
PERSISTED_ID = re.compile(r'^\s*case\s+\w+\s*=\s*"')

# 第四條：英文句子寫死在會顯示的地方（`.help("Open in Browser")`、`Text("Stack")`）。
# 只擋「看起來是句子或標籤」的：含空白的多個單字，或首字母大寫的單一英文詞。品牌與技術縮寫放行。
ENGLISH_CALL = re.compile(
    r'(?:Text|Label|Button|Toggle|Section|Menu|\.help|\.accessibilityLabel|\.accessibilityHint|\.navigationTitle|contentDescription\s*=)'
    r'\(?\s*"([A-Z][A-Za-z]+(?: [A-Za-z0-9&/.\-]+)*)"'
)
ENGLISH_OK = {"Kairumo", "Google Drive", "iCloud", "Apache-2.0", "RGB", "HSB", "HEX", "OK", "Drive", "PDF", "PNG", "SVG", "JSON"}

TARGETS = [
    (ROOT / "apple/Sources", "*.swift", {"LocalizationStrings.generated.swift", "padnote_core.swift"}),
    (ROOT / "android/app/src/main/java/com/kairumo/padnote", "*.kt", {"LocalizationStrings.kt"}),
]


def main() -> int:
    hits = []
    for base, pattern, skip in TARGETS:
        for path in sorted(base.rglob(pattern)):
            if path.name in skip:
                continue
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if line.strip().startswith(("//", "*", "///")):
                    continue  # 這個 repo 的註解本來就是中文的
                for rule in (CALL, ASSIGN):
                    for m in rule.finditer(line):
                        if CJK.search(m.group(1)):
                            rel = path.relative_to(ROOT)
                            hits.append(f"{rel}:{n}  {m.group(1)[:60]}")
                if "i18n-ok" in line or LOGGING.search(line) or PERSISTED_ID.match(line):
                    continue
                for m in MESSAGE_SINKS.finditer(line):
                    if CJK.search(m.group(1)):
                        hits.append(f"{path.relative_to(ROOT)}:{n}  {m.group(1)[:60]}")
                for m in ENGLISH_CALL.finditer(line):
                    text = m.group(1)
                    if text not in ENGLISH_OK and not re.fullmatch(r"[A-Z][a-z]*", text) is None and len(text) < 3:
                        continue
                    if text in ENGLISH_OK or text.split(" ")[0] in ENGLISH_OK and len(text.split(" ")) == 1:
                        continue
                    hits.append(f"{path.relative_to(ROOT)}:{n}  {text[:60]}  (英文)")

    if hits:
        print(f"❌ 介面上有 {len(hits)} 處硬寫死的文字：", file=sys.stderr)
        for h in hits:
            print("   " + h, file=sys.stderr)
        print(
            "\n這些字只有中文使用者看得懂，其他五個語系的人看到的就是中文。\n"
            "把它加進 i18n/ui-strings.json，跑 python3 scripts/i18n_tool.py generate，\n"
            "再改用 localized(\"鍵名\")。",
            file=sys.stderr,
        )
        return 1

    print("✅ 介面上沒有硬寫死的文字")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
