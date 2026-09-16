#!/usr/bin/env python3
"""文件範本目錄的單一來源工具（工作項 S-61）。

# 為什麼要有這支工具

「新增筆記」要提供 39 種文件範本（商務書信、契約、公文、學術報告、個人應用），
每一種還有「完整案例」與「空白範本」兩個版本 —— 78 份文件。

這些文件如果照既有 `SeedContent.swift` / `SeedNotebooks.kt` 的做法，在兩個平台
各手寫一份、各自算 y 座標，會有兩個必然的後果：

1. **兩邊會漂移。** 78 份文件、每份十幾個區塊，改一邊忘另一邊是遲早的事，
   而症狀是「同一份契約範本在 iPad 與 Android 上長得不一樣」。
2. **座標要人算。** 手寫 y 座標的話，改一段文字就要重算它下面每一個區塊。

所以：內容寫在 `templates/src/*.json`（一個主題一個檔），**版面由這支工具算**，
輸出一份已經排好版的 `templates/document-templates.json`，兩個平台各自載入
同一份檔案。座標只算一次，兩邊必然相同。

# 為什麼輸出 JSON 而不是產生程式碼

78 份文件 × 2 個語系 × 十幾個區塊 ≈ 一千多筆區塊。產成 Swift/Kotlin 原始碼的話
是兩個上萬行的檔案，編譯時間與可讀性都很難看。JSON 走既有的資源打包路徑
（Apple 的 `Resources/Templates`、Android 的 `assets/templates`），與手冊、隱私
權政策同一條路。

用法：
  python3 scripts/doc_templates_tool.py build    # 由 src/ 排版產出目錄檔
  python3 scripts/doc_templates_tool.py verify   # 檢查產出與來源是否一致
"""
import json
import math
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "templates/src"
OUT = ROOT / "templates/document-templates.json"

# 內文語系。介面上的名稱與說明做滿六個語系，文件**內文**只做這兩個 ——
# 台灣的公文格式、勞基法勞動合同、存證信函、民事訴狀都是綁特定法域的東西，
# 逐字翻成泰文或韓文不會變成當地可用的文件，只會讓使用者以為可以照著用。
BODY_LANGS = ["zhHant", "en"]

# 介面字串（名稱、說明、分類）的語系，與 i18n/ui-strings.json 一致。
UI_LANGS = ["zhHant", "en", "zhHans", "ja", "ko", "th"]

# --- 版面常數 -------------------------------------------------------------
#
# 與 `apple/Sources/SeedContent.swift`、`SeedNotebooks.kt` 同一組。
# 頁面尺寸來自核心（`standard_page_size`），這裡不能自己定義另一套。
PAGE_W = 800.0
PAGE_H = 1132.0
MARGIN = 56.0
CONTENT_W = PAGE_W - MARGIN * 2
TOP_Y = 72.0
BOTTOM_Y = PAGE_H - 56.0

# 每一種區塊的字級、行高與後方留白。
STYLE = {
    #            字級  粗體   行距  區塊後留白
    "title":    (26.0, True,  6.0, 22.0),
    "heading":  (18.0, True,  5.0, 12.0),
    "body":     (15.0, False, 5.0, 16.0),
    "notice":   (13.0, False, 4.0, 18.0),
    "signoff":  (15.0, False, 5.0, 16.0),
}
TABLE_ROW_H = 34.0
TABLE_GAP = 20.0


def visual_width(text: str, font_size: float) -> float:
    """一段文字畫出來大約多寬。

    全形與半形要分開算 —— 全都當半形的話，中文段落的行數會少估一半，
    下一個區塊就會壓在它身上。0.55 這個比例與核心的 `greek_lines` 相同，
    兩邊對「一行放得下多少字」的判斷因此一致。
    """
    # 一段文字只要有一個非 ASCII 字元，PDF 匯出就會整段走 CJK 複合字型，
    # 裡面的數字與英文也照全形前進（見 padnote-export::pdf 的 glyph_width）。
    # 這裡若仍按 0.55 估，帶數字的中文句子行數會少估，下一個區塊就會壓上來。
    cjk_font = any(ord(ch) > 127 for ch in text)
    total = 0.0
    for ch in text:
        if cjk_font or unicodedata.east_asian_width(ch) in ("W", "F"):
            total += font_size
        else:
            total += font_size * 0.55
    return total


def text_height(text: str, font_size: float, line_spacing: float, width: float) -> float:
    """一段文字排進 `width` 寬之後大約多高。"""
    line_h = font_size * 1.35 + line_spacing
    lines = 0
    # 原文的換行是作者刻意分的段，不能併成一行算。
    for para in text.split("\n"):
        if not para.strip():
            lines += 1
            continue
        lines += max(1, math.ceil(visual_width(para, font_size) / width))
    return lines * line_h + 10.0


def parse_table(raw: str):
    """`a|b\\nc|d` → (rows, cols, cells)。短列補空字串。

    補而不是丟：`cells` 的長度必須剛好是 rows × cols，少一格核心的版面
    計算會讀到越界的索引。與兩個平台的 `parseTable` 同一套規則。
    """
    lines = [line.split("|") for line in raw.split("\n")]
    cols = max(len(line) for line in lines)
    cells = []
    for line in lines:
        cells.extend(line[i] if i < len(line) else "" for i in range(cols))
    return len(lines), cols, cells


def lay_out(blocks, lang):
    """把一連串區塊由上而下排進頁面，回傳帶座標的區塊與總頁數。

    放不下就換頁。**不會把一個區塊切成兩半** —— 一張表或一段文字被頁緣
    切斷的話，列印出來會是半張表，比讓它整塊移到下一頁難看得多。
    """
    out = []
    page = 0
    y = TOP_Y

    for block in blocks:
        kind = block["type"]

        if kind == "pagebreak":
            page += 1
            y = TOP_Y
            continue

        if kind == "spacer":
            y += float(block.get("height", 16))
            continue

        text = block.get("text", {})
        content = text.get(lang) or text.get("zhHant") or ""
        if not content:
            continue

        if kind == "table":
            rows, cols, cells = parse_table(content)
            height = rows * TABLE_ROW_H
            gap = TABLE_GAP
            payload = {"rows": rows, "cols": cols, "cells": cells,
                       "headerRow": block.get("headerRow", True)}
        else:
            font_size, bold, line_spacing, gap = STYLE[kind]
            height = text_height(content, font_size, line_spacing, CONTENT_W - _pad(kind) * 2)
            payload = {"text": content, "fontSize": font_size, "bold": bold,
                       "lineSpacing": line_spacing}

        # 放不下就整塊搬到下一頁。
        if y + height > BOTTOM_Y and y > TOP_Y:
            page += 1
            y = TOP_Y

        out.append({
            "kind": kind, "page": page,
            "x": MARGIN, "y": round(y, 1),
            "width": CONTENT_W, "height": round(height, 1),
            **payload,
        })
        y += height + gap

    return out, page + 1


def _pad(kind: str) -> float:
    """有底框的區塊，文字要往內縮，不然字會貼在框線上。"""
    return 12.0 if kind == "notice" else 0.0


def load_sources():
    if not SRC_DIR.is_dir():
        sys.exit(f"找不到來源目錄：{SRC_DIR}")
    themes = []
    for path in sorted(SRC_DIR.glob("*.json")):
        with path.open(encoding="utf-8") as handle:
            themes.append(json.load(handle))
    return themes


def build():
    themes = load_sources()
    result = {"version": 1, "pageWidth": PAGE_W, "pageHeight": PAGE_H,
              "bodyLangs": BODY_LANGS, "themes": []}

    seen_ids = set()
    for theme in themes:
        out_theme = {"id": theme["id"], "name": theme["name"],
                     "icon": theme["icon"], "categories": []}
        for category in theme["categories"]:
            out_cat = {"id": category["id"], "name": category["name"], "templates": []}
            for tmpl in category["templates"]:
                if tmpl["id"] in seen_ids:
                    sys.exit(f"範本 id 重複：{tmpl['id']}")
                seen_ids.add(tmpl["id"])
                out_tmpl = {
                    "id": tmpl["id"],
                    "name": tmpl["name"],
                    "description": tmpl["description"],
                    "pageStyle": tmpl.get("pageStyle", "blank"),
                    "variants": {},
                }
                for variant in ("example", "blank"):
                    blocks = tmpl["variants"][variant]
                    per_lang = {}
                    for lang in BODY_LANGS:
                        laid, pages = lay_out(blocks, lang)
                        # 某個語系整份沒有內容就不輸出，讓執行期退回 zh-Hant。
                        if not laid:
                            continue
                        per_lang[lang] = {"pageCount": pages, "blocks": laid}
                    out_tmpl["variants"][variant] = per_lang
                out_cat["templates"].append(out_tmpl)
            out_theme["categories"].append(out_cat)
        result["themes"].append(out_theme)

    check_ui_langs(result)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=1, sort_keys=False)
        handle.write("\n")
    total = sum(len(c["templates"]) for t in result["themes"] for c in t["categories"])
    print(f"==> {len(result['themes'])} 個主題、{total} 種範本、{total * 2} 份文件")
    return result


def check_ui_langs(result):
    """介面上會看到的字必須六個語系都在。

    少一個語系的話，那個語系的使用者會看到別種語言的範本名稱夾在中間 ——
    不會壞，但看起來像沒做完。這裡擋下來比上架後才發現好。
    """
    missing = []

    def check(where, table):
        for lang in UI_LANGS:
            if not table.get(lang):
                missing.append(f"{where}：缺 {lang}")

    for theme in result["themes"]:
        check(f"主題 {theme['id']}", theme["name"])
        for category in theme["categories"]:
            check(f"分類 {category['id']}", category["name"])
            for tmpl in category["templates"]:
                check(f"範本 {tmpl['id']} 名稱", tmpl["name"])
                check(f"範本 {tmpl['id']} 說明", tmpl["description"])
    if missing:
        sys.exit("介面字串沒有做滿六個語系：\n  " + "\n  ".join(missing))


def verify():
    if not OUT.exists():
        sys.exit(f"目錄檔還沒產生：{OUT}（先跑 build）")
    current = json.loads(OUT.read_text(encoding="utf-8"))
    rebuilt = build()
    if current != rebuilt:
        sys.exit("目錄檔與來源不一致 —— 有人改了產物而不是來源，或忘了重跑 build")
    print("==> 目錄檔與來源一致")


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "build"
    if action == "build":
        build()
    elif action == "verify":
        verify()
    else:
        sys.exit(__doc__)
