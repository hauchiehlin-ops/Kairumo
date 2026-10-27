#!/usr/bin/env python3
"""編輯器狀態的「唯一正門」守門（P0）。

# 為什麼要有

編輯器拆成十幾個模組之後，每個模組都摸得到同一批狀態。換工具、切模式這種動作都有一個
「正門」函式會把副作用一起做完（Android `applyInkTool` 會同步 `engine.isErasing`／
`engine.tool`、離開套索時清選取；Apple `applyEditorTool`／`transitionToMode` 會先切回手寫、
存檔、收掉物件焦點）。但只要有一個模組直接改狀態，那條副作用就斷了 —— 使用者看到的是
「工具列上選了橡皮擦，畫下去還是墨跡」（拆檔之後 Android 主工具列真的這樣出貨過）。

這支腳本擋住正門以外的寫入。正門那一行用 `// state-entry:` 標記。

用法：python3 scripts/check-state-entrypoints.py   （有違規回 1）
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (平台, 原始碼目錄, 副檔名, 狀態名, 正門名稱)
RULES = [
    ("Apple", "apple/Sources", ".swift", "selectedTool", "applyEditorTool / selectEditorTool"),
    ("Apple", "apple/Sources", ".swift", "editorMode", "transitionToMode"),
    ("Apple", "apple/Sources", ".swift", "currentPageIndex", "switchToPage / focusContinuousPage"),
    ("Android", "android/app/src/main/java", ".kt", "inkTool", "applyInkTool"),
    ("Android", "android/app/src/main/java", ".kt", "pageIndex", "switchToPage"),
    ("Android", "android/app/src/main/java", ".kt", "selectedTextId", "selectText / clearSelection"),
    ("Android", "android/app/src/main/java", ".kt", "selectedImageId", "selectImage / clearSelection"),
]

MARKER = "state-entry:"


def violations():
    out = []
    for platform, src, ext, name, entry in RULES:
        # 寫入：`name =`、`x.name =`（不含 `==`、`+=`）；`self.name =` 是別的型別在初始化自己的屬性。
        write = re.compile(r"(?<![\w$])((?:\w+\.)?)" + name + r"\s*=(?![=])")
        decl = re.compile(r"\b(var|val|let)\s+" + name + r"\b")
        for path in sorted((ROOT / src).rglob("*" + ext)):
            if path.name.startswith("._"):
                continue
            for no, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                code = line.split("//", 1)[0]
                m = write.search(code)
                if not m or MARKER in line or decl.search(code):
                    continue
                prefix = m.group(1)
                if prefix in ("self.", "this."):
                    continue
                # 非 context 前綴的物件屬性寫入（如 tape.pageIndex、view.pageIndex 等）非全域編輯器狀態
                if prefix and prefix != "ctx.":
                    continue
                # 檢查是否為函式呼叫的具名引數（如 `copy(pageIndex = ...)` 或多參數呼叫）
                start = m.start()
                before = code[:start].rstrip()
                if before.endswith("(") or before.endswith(","):
                    if not re.search(r"->\s*$", before):
                        continue
                # Kotlin 的具名參數（如 `pageIndex = x,` 或 `pageIndex = x, foo = y`）不是寫入。只看行首：
                # `onToolChange = { t -> ctx.inkTool = t },` 也以逗號結尾，但那是真的寫入
                # （拆檔後 Android 主工具列就是這一行繞過了 applyInkTool）。
                if ext == ".kt" and re.match(r"\s*" + name + r"\s*=", code) and (code.rstrip().endswith(",") or "," in code):
                    continue
                rel = path.relative_to(ROOT)
                out.append(f"{platform}  {rel}:{no}  直接改 `{name}`，請改走 {entry}\n    {line.strip()}")
    return out


def main():
    found = violations()
    if found:
        print("❌ 編輯器狀態繞過了正門（理由見 scripts/check-state-entrypoints.py 檔頭）：", file=sys.stderr)
        for v in found:
            print("  " + v, file=sys.stderr)
        return 1
    print("✅ 編輯器狀態都走正門（換工具、切模式、切頁面、選取）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
