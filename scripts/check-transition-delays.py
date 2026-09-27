#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 6 項靜態代碼關卡：偵測並防範 UI 轉場／Sheet 彈窗中寫死的任意延遲常數。

在 iOS / iPadOS 上，若在 UIMenu / ContextMenu 或關閉當前 Sheet 後，
直接使用裸寫的 `DispatchQueue.main.asyncAfter(deadline: .now() + 0.15)` 來
設定 `showXxxSheet = true`，容易因動畫時間微調、裝置效能落差而在慢速裝置上
引發 Sheet 競態衝突（"already presenting a view controller"）或在快速裝置上出現
明顯的點擊延遲與無響應。

所有跨選單與次級視窗的彈窗排程，必須統一透過 `SheetCoordinator.shared.presentFromMenu { ... }`
或透過 `SheetCoordinator.shared.present(...)` 進行有序排程。

檢查規則：
- 掃描 apple/Sources 下所有 .swift 檔案。
- 尋找在 `asyncAfter` 區塊中直接切換 `show.*Sheet = true` 或 `isPresented = true` 的寫法。
- 排除已在 SheetCoordinator.swift 本身內的排程實作。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN = [ROOT / "apple" / "Sources"]

# 匹配在 asyncAfter 內直接修改 Sheet 彈窗旗標的裸調度
SHEET_FLAG_PATTERN = re.compile(r"asyncAfter\b[^{]*\{[^}]*(?:show\w*Sheet|isPresented)\s*=\s*true", re.DOTALL)

hits = []

for root in SCAN:
    for path in sorted(root.rglob("*.swift")):
        if path.name == "SheetCoordinator.swift":
            continue
        content = path.read_text(encoding="utf-8")
        for match in SHEET_FLAG_PATTERN.finditer(content):
            # 計算行號
            lineno = content[:match.start()].count("\n") + 1
            matched_text = match.group(0).strip().splitlines()[0]
            hits.append((path.relative_to(ROOT), lineno, matched_text))

if hits:
    print("❌ 偵測到在 UI 轉場中寫死的任意延遲常數（Raw asyncAfter Sheet Presentation）：")
    for rel, lineno, text in hits:
        print(f"   {rel}:{lineno}  {text}")
    print()
    print("   請改用 SheetCoordinator.shared.presentFromMenu { ... } 統一協調，以確保彈窗生命週期安全。")
    sys.exit(1)

print("✅ apple/Sources 沒有在 asyncAfter 中裸寫 Sheet 彈窗的任意延遲常數")
