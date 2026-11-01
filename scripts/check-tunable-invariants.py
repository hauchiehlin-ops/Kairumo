#!/usr/bin/env python3
"""彈性邊界守門員：區分「核心數學性質不變式」與「可調校產品手感參數」（Layer 2 擴充）。

# 為什麼需要它

在持續演進產品手感（例如微調筆刷 1–30 號粗細梯度、游標預覽比例、書寫中同步讓路冷卻秒數）時：
1. 若測試寫死單一視覺魔術數字（如 `assert_eq!(width, 2.75)`），任何合法的手感調優都會被誤判為紅燈，限制開發彈性。
2. 但若缺乏守門，調整某一段曲線時又可能不小心造成「1–5 號筆刷被夾成同一粗細（`max(6, ...)` / `.coerceIn(6f, ...)`）」或「Apple / Android / Rust 三端曲線脫鉤」。

因此，這支守門腳本專門執行「性質導向（Property-Based）與跨端結構守門」：
  P1. 筆刷 1–5 微調區間嚴禁出現將小尺寸壓平的下限截斷（如 `max(6, CGFloat(w))` 或 `.coerceIn(6f, 22f)`）。
  P2. Apple `BrushCursorTests.swift` 必須保有驗證 1..5 號各筆刷嚴格單調遞增的性質測試（`<` 遞增關係，而非寫死單一視覺常數）。
  P3. Apple (`ProInk.swift`、`BrushCursor.swift`、`EditorToolbars.swift`) 與 Android (`InkBrushRenderer.kt`、`InkToolbar.kt`) 必須維持小尺寸（1–5 號）不被截斷的線性/單調映射結構，同時允許自由調整斜率與端點手感參數。
  P4. 書寫中背景同步讓路機制（`isActivelyInking`）在 Apple (`ProInk.swift`、`FocusSyncController.swift`、`AutoSyncController.swift`) 與 Android (`InkEngine.kt`、`FocusSync.kt`、`AutoSync.kt`) 必須雙端成對存在，且允許冷卻時間參數自由調校。

用法：`python3 scripts/check-tunable-invariants.py`（有違規回 1）
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def check_brush_curve_properties(problems: list[str]) -> None:
    apple_proink = ROOT / "apple" / "Sources" / "ProInk.swift"
    apple_cursor = ROOT / "apple" / "Sources" / "BrushCursor.swift"
    apple_toolbar = ROOT / "apple" / "Sources" / "EditorToolbars.swift"
    apple_cursor_tests = ROOT / "apple" / "Tests" / "BrushCursorTests.swift"
    android_toolbar = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "ink" / "InkToolbar.kt"
    android_renderer = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "ink" / "InkBrushRenderer.kt"

    for p in (apple_proink, apple_cursor, apple_toolbar, apple_cursor_tests, android_toolbar, android_renderer):
        if not p.exists():
            problems.append(f"找不到核心筆刷檔案：{p.relative_to(ROOT)}")
            return

    proink_text = apple_proink.read_text(encoding="utf-8")
    cursor_text = apple_cursor.read_text(encoding="utf-8")
    apple_tb_text = apple_toolbar.read_text(encoding="utf-8")
    cursor_test_text = apple_cursor_tests.read_text(encoding="utf-8")
    android_tb_text = android_toolbar.read_text(encoding="utf-8")

    # P1: 禁止將 1..5 號筆刷或預覽點壓平的舊式下限截斷（如 `max(6, CGFloat(w))` 或 `coerceIn(6f, 22f)`）
    if re.search(r"frame\(\s*width:\s*max\(\s*[56](?:\.0)?\s*,\s*CGFloat\(w\)\)", apple_tb_text):
        problems.append(
            "apple/Sources/EditorToolbars.swift 出現將 1–5 號筆刷預覽圓點壓平的 `max(6, CGFloat(w))` 截斷寫法，違反嚴格遞增性質（P1）"
        )
    if re.search(r"coerceIn\(\s*[56](?:\.0)?f\s*,\s*22(?:\.0)?f\s*\)", android_tb_text):
        problems.append(
            "android/.../ink/InkToolbar.kt 出現將 1–5 號筆刷預覽直徑壓平的 `.coerceIn(6f, 22f)` 截斷寫法，違反嚴格遞增性質（P1）"
        )
    if re.search(r"max\(\s*4(?:\.0)?\s*,\s*width\s*\*\s*tipScale", cursor_text):
        problems.append(
            "apple/Sources/BrushCursor.swift 出現將 1–5 號筆尖游標壓平的 `max(4, width * tipScale)` 截斷寫法，違反嚴格遞增性質（P1）"
        )

    # P2: 單元測試必須保有驗證 1..5 號嚴格遞增性質（Property-Based）的測試斷言
    if "XCTAssertLessThan" not in cursor_test_text:
        problems.append(
            "apple/Tests/BrushCursorTests.swift 缺少使用 `XCTAssertLessThan` 驗證筆刷尺寸嚴格單調遞增的性質測試（P2）"
        )

    # P3: Apple ProInk 與 BrushCursor 必須維持小尺寸基底映射結構（允許斜率與倍率手感參數自由調校）
    if "static func baseWidth(" not in proink_text:
        problems.append("apple/Sources/ProInk.swift 缺少 `ProInk.baseWidth` 統一筆寬映射正門（P3）")
    if "static func tipDiameter(" not in cursor_text:
        problems.append("apple/Sources/BrushCursor.swift 缺少 `BrushCursor.tipDiameter` 統一游標直徑映射正門（P3）")


def check_active_inking_deferral_parity(problems: list[str]) -> None:
    # P4: 書寫中背景同步讓路機制（isActivelyInking）雙端對稱守門（允許冷卻時間參數自由調校）
    required_files = [
        ("Apple CanvasTouchState", ROOT / "apple" / "Sources" / "ContinuousPagesView.swift", "isActivelyInking"),
        ("Apple FocusSyncController", ROOT / "apple" / "Sources" / "FocusSyncController.swift", "isActivelyInking"),
        ("Apple AutoSyncController", ROOT / "apple" / "Sources" / "AutoSyncController.swift", "isActivelyInking"),
        ("Android InkEngine", ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "ink" / "InkEngine.kt", "isActivelyInking"),
        ("Android FocusSync", ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "sync" / "FocusSync.kt", "isActivelyInking"),
        ("Android AutoSync", ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "sync" / "AutoSync.kt", "isActivelyInking"),
    ]
    for label, path, token in required_files:
        if not path.exists():
            problems.append(f"找不到同步讓路守門檔案：{path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        if token not in text:
            problems.append(
                f"{label} ({path.relative_to(ROOT)}) 缺少 `{token}` 書寫讓路檢查，背景同步可能搶佔手寫關鍵資源（P4）"
            )


def main() -> int:
    problems: list[str] = []
    check_brush_curve_properties(problems)
    check_active_inking_deferral_parity(problems)
    if problems:
        print("❌ 彈性邊界與性質不變式檢驗未通過：", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1
    print("✅ 彈性邊界守門通過（性質不變式與可調手感參數分離、跨端結構同構）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
