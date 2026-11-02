#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""守門機制 Layer 5：畫布核心純度與重型次系統隔離檢查（Canvas Isolation Gatekeeper）。

最高指導原則：
1. 「穩定（零崩潰）」與「即時（120Hz/60Hz 手寫超低延遲 <16ms）」。
2. 手寫核心關鍵路徑（ProInk, CanvasRepresentable, InkSurfaceView）必須保持極致純粹，
   嚴禁依賴或嵌入任何重型業務編輯器（Table, Chart, Math, 3D 等）。
3. 主畫布容器（NotebookEditorView）嚴禁直接在 View 階層中內聯實例化重型次系統視圖，
   必須透過 EditorSubsystemCoordinator 隨需喚醒，避免 SwiftUI 視圖樹型別爆炸（Type Explosion）
   與狀態 Diffing 侵蝕 120Hz 筆跡幀預算。

放行標記：
  // canvas-isolation-ok: <理由>
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# 重型次系統視圖名稱清單
HEAVY_SUBSYSTEM_VIEWS = [
    "TableStudioView",
    "TablePropertiesSheet",
    "ChartStudioView",
    "MathCalculatorSheet",
    "ShapeStudioView",
    "ThreeDStudioView",
    "WordTextStudioView",
]

# 手寫關鍵路徑檔案（嚴格禁止任何重型次系統引用）
CRITICAL_INK_PATHS = [
    ROOT / "apple/Sources/ProInk.swift",
    ROOT / "apple/Sources/CanvasRepresentable.swift",
    ROOT / "android/app/src/main/java/com/kairumo/padnote/InkSurfaceView.kt",
]

# 主畫布容器檔案（禁止直接在 View body 內聯建構重型次系統，需走 Coordinator）
CANVAS_CONTAINERS = [
    ROOT / "apple/Sources/NotebookEditorView.swift",
]

violations = []

# 檢查 1：手寫關鍵路徑純度
for file_path in CRITICAL_INK_PATHS:
    if not file_path.exists():
        continue
    rel = file_path.relative_to(ROOT)
    for lineno, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        if "canvas-isolation-ok:" in line:
            continue
        for view_name in HEAVY_SUBSYSTEM_VIEWS:
            if view_name in line:
                violations.append(
                    f"{rel}:{lineno} [手寫關鍵路徑污染] 嚴禁在手寫渲染層引用重型次系統 `{view_name}`"
                )

# 檢查 2：主畫布容器隔離（禁止內聯直接建構）
# 在 NotebookEditorView 裡，重型視圖必須移入 EditorSubsystemCoordinator
DISALLOWED_IN_NOTEBOOK_EDITOR = [
    "TablePropertiesSheet(",
    "TableStudioView(",
]

for file_path in CANVAS_CONTAINERS:
    if not file_path.exists():
        continue
    rel = file_path.relative_to(ROOT)
    for lineno, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        if "canvas-isolation-ok:" in line:
            continue
        for disallowed in DISALLOWED_IN_NOTEBOOK_EDITOR:
            if disallowed in line:
                violations.append(
                    f"{rel}:{lineno} [視圖樹膨脹違規] 嚴禁在主畫布容器直接建構 `{disallowed[:-1]}`，請透過 `EditorSubsystemCoordinator` 動態調度"
                )

if violations:
    print(f"❌ Canvas Isolation Gatekeeper: 發現 {len(violations)} 項違規！", file=sys.stderr)
    for v in violations:
        print(f"  - {v}", file=sys.stderr)
    print("\n修復指南：", file=sys.stderr)
    print("  1. 重型次系統視圖請移至 `EditorSubsystemCoordinator.swift` 並以 ViewModifier 或隨需協議包裝。", file=sys.stderr)
    print("  2. 若為必要用途，可在該行末尾註記 `// canvas-isolation-ok: <理由>` 放行。", file=sys.stderr)
    sys.exit(1)

print("✅ Canvas Isolation Gatekeeper: 手寫核心與畫布容器次系統隔離檢查通過。")
sys.exit(0)
