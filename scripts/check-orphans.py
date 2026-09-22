#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""擋掉「實作好了但沒有任何人引用」的型別與函式。

# 為什麼需要這道閘門

功能寫完了、程式碼在那裡、看起來一切正常 —— 但沒有任何一條路徑會走到它。
使用者在介面上看不到，或者看得到卻按不出反應。編譯器不會警告（Swift 與
Kotlin 都不對 public 宣告報 dead code），測試也測不到（沒有人會為一個
接不上的功能寫測試）。

第一次跑抓到的：

  LassoPathOverlay        套索選取的外框，寫成 SwiftUI View 但從沒被放進任何畫面
  cutSelected             套索的「剪下」 ┐
  duplicateSelected       套索的「再製」 ├ 四個都只出現一次 —— 就是宣告自己
  moveSelected            套索的「移動」 │  （deleteSelected 有接線，所以不在列）
  recolorSelected         套索的「改色」 ┘
  ModelDownloadDelegate   下載進度回呼，從沒被掛到任何 URLSession
  exportNotebookPdf       public 的 PDF 匯出進入點，零呼叫
  setSyncedToolbarJSON    Apple 是 …JSON、Android 是 …Json，而 Apple 這個沒人叫

# 判定方式

宣告的**裸名**在整個程式庫（含 Examples／Tests／UITests／androidTest）
出現幾次；扣掉宣告自己之後是 0 就算孤兒。

用裸名而不是 `name(` 是因為函式可以不帶括號被傳遞
（`list.map(migrateSeedTitles)`、Kotlin 的 `::fn`）—— 只算呼叫點的話
那些會被誤判，實測有 23 個。

# 三種合法的例外

1. **框架回呼**：`makeUIView`、`onTouchEvent` 這些由系統呼叫，程式庫裡
   當然找不到呼叫點。列在 `FRAMEWORK_CALLBACKS`。
2. **同名多處**：覆寫與協定實作會有好幾個同名宣告，無法分辨是哪一個沒被用，
   直接跳過。
3. **刻意保留**：宣告上方三行內寫 `// orphan-ok: <理由>`。

# 為什麼有 baseline（棘輪）

理由與 `check-screen-parity.py`、`check-unused-params.py` 相同：一開始
就全紅的閘門會被關掉，然後一切照舊。只擋**新增**的孤兒。

用法：
    python3 scripts/check-orphans.py
    python3 scripts/check-orphans.py --update-baseline
    python3 scripts/check-orphans.py --update-baseline --accept-new
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASELINE = ROOT / "docs" / "gates" / "orphans-baseline.json"

# 宣告所在（會被檢查的範圍）
DECL_ROOTS = [
    (ROOT / "apple" / "Sources", "*.swift"),
    (ROOT / "android" / "app" / "src" / "main", "*.kt"),
]
# 引用所在（宣告範圍 + 這些）
REF_EXTRA = [
    (ROOT / "apple" / "Examples", "*.swift"),
    (ROOT / "apple" / "Tests", "*.swift"),
    (ROOT / "apple" / "UITests", "*.swift"),
    (ROOT / "android" / "app" / "src" / "androidTest", "*.kt"),
    (ROOT / "android" / "app" / "src" / "test", "*.kt"),
]

GENERATED = ("/Generated/", "/uniffi/", ".generated.")

# 由系統呼叫的回呼 —— 程式庫裡本來就找不到呼叫點。
FRAMEWORK_CALLBACKS = {
    # UIKit / SwiftUI
    "application", "makeUIView", "updateUIView", "makeUIViewController",
    "updateUIViewController", "makeCoordinator", "dismantleUIView",
    "dismantleUIViewController", "sizeThatFits", "placeSubviews", "body",
    "presentationAnchor", "pointerInteraction", "pencilInteraction",
    "pencilInteractionDidTap", "scrollViewDidScroll", "scrollViewDidZoom",
    "viewForZooming", "gestureRecognizer", "documentPicker", "connection",
    # PencilKit
    "canvasViewDrawingDidChange", "canvasViewSelectionDidChange",
    "canvasViewDidBeginUsingTool", "canvasViewDidEndUsingTool",
    # AVFoundation / URLSession
    "audioPlayerDidFinishPlaying", "audioPlayerDecodeErrorDidOccur", "urlSession",
    # Android
    "onCreate", "onResume", "onPause", "onDestroy", "onStart", "onStop",
    "onKeyDown", "onKeyUp", "onTouchEvent", "onLayout", "onDraw", "onWrite",
    "onAvailable", "onLost", "onClosed", "onOpen", "onFailure", "onMessage",
    "onDrawFrontBufferedLayer", "onDrawMultiBufferedLayer", "onBackPressed",
    "onConfigurationChanged", "onActivityResult", "onRequestPermissionsResult",
    "doWork", "isHover", "isHoverExit",
}

TYPE_DECL = re.compile(
    r"^[ \t]*(?:@\w+(?:\([^)]*\))?[ \t]+)*"
    r"(?:public |internal |private |fileprivate |open |final |abstract |sealed |data |)*"
    r"\b(class|struct|enum|actor|protocol|object|interface)\s+([A-Z]\w*)",
    re.M,
)
FUNC_DECL = re.compile(
    r"^[ \t]*(?:@\w+(?:\([^)]*\))?[ \t]+)*"
    r"(?:public |internal |open |static |final |override |private |fileprivate |)*"
    r"\b(?:func|fun)\s+([a-z]\w*)\s*[<(]",
    re.M,
)
WAIVER = re.compile(r"//\s*orphan-ok:")


def _generated(path: pathlib.Path) -> bool:
    p = "/" + str(path).replace("\\", "/")
    return any(m in p for m in GENERATED)


def _read(roots) -> dict[str, str]:
    out = {}
    for root, ext in roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob(ext)):
            if _generated(path):
                continue
            out[str(path.relative_to(ROOT))] = path.read_text(encoding="utf-8")
    return out


def collect() -> tuple[list[str], dict[str, str]]:
    sources = _read(DECL_ROOTS)
    universe = dict(sources)
    universe.update(_read(REF_EXTRA))

    # 宣告 -> [(檔案, 行, 類別)]；同名多處代表覆寫／多載，無法分辨，跳過
    decls: dict[str, list[tuple[str, int, str]]] = {}
    for rel, text in sources.items():
        for pattern, kind in ((TYPE_DECL, "type"), (FUNC_DECL, "func")):
            for m in pattern.finditer(text):
                name = m.groups()[-1]
                line = text[: m.start()].count("\n") + 1
                decls.setdefault(name, []).append((rel, line, kind))

    orphans, where = [], {}
    for name, sites in sorted(decls.items()):
        if len(sites) > 1:
            continue
        if name in FRAMEWORK_CALLBACKS:
            continue
        rel, line, kind = sites[0]

        lines = sources[rel].split("\n")
        window = "\n".join(lines[max(0, line - 4) : line])
        if WAIVER.search(window):
            continue
        if "override" in lines[line - 1]:
            continue

        pattern = re.compile(r"\b" + re.escape(name) + r"\b")
        refs = 0
        for g, text in universe.items():
            n = len(pattern.findall(text))
            if g == rel:
                n -= 1  # 扣掉宣告自己
            refs += n
        if refs <= 0:
            key = f"{rel}::{kind}::{name}"
            orphans.append(key)
            where[key] = f"{rel}:{line}"
    return sorted(orphans), where


def main() -> int:
    update = "--update-baseline" in sys.argv
    accept_new = "--accept-new" in sys.argv

    found, where = collect()
    known = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else []

    if update:
        merged = found if accept_new else sorted(set(found) & set(known))
        if not accept_new and set(found) - set(known):
            print("⚠️  有 baseline 之外的新項目，沒有 --accept-new 不會寫進去：")
            for k in sorted(set(found) - set(known)):
                print(f"   {k}")
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(
            json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"✅ baseline 已更新：{len(known)} → {len(merged)} 項")
        return 0

    new = sorted(set(found) - set(known))
    if new:
        print("❌ 這些實作好了但沒有任何人引用 —— 功能在那裡，卻沒有一條路徑會走到：")
        for key in new:
            rel, kind, name = key.split("::")
            print(f"   {where.get(key, rel)}  {kind} {name}")
        print()
        print("   修法三選一：接上它／刪掉它／在宣告上方寫")
        print("   // orphan-ok: <理由>")
        return 1

    stale = sorted(set(known) - set(found))
    print(f"✅ 沒有新的孤兒（baseline 尚欠 {len(found)} 項，逐步清空）")
    if stale:
        print(f"   （baseline 有 {len(stale)} 項已經處理掉了，可以跑 --update-baseline 縮小）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
