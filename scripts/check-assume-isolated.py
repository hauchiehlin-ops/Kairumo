#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""擋掉 `MainActor.assumeIsolated`。

它的意思是「我保證這裡是主執行緒」，而編譯器會照單全收 —— 保證錯了不會有
警告，只會在執行期 `dispatch_assert_queue_fail` / SIGTRAP。

實際踩到的樣子：把同步的匯出搬離 MainActor（H-SYNC-MAINACTOR）時，
`PageGeometry.width` 在背景執行緒上直接讓行程消失，沒有任何編譯期線索。
拆完第一顆，下一行的 `height(forPage:)` 的**預設參數**又是同一顆。

替代做法：
  * 唯讀的靜態表 → `nonisolated`（例：`LocalizationManager.localizedUnsafe`）
  * 會變的全域 → 一把鎖 + `nonisolated(unsafe)`（例：`PageGeometry.size`）
  * 真的需要主執行緒 → `await MainActor.run { }`，讓呼叫端知道要等

真的必要時在該行加 `// assumeIsolated-ok: <理由>` 放行。
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
hits = []
for path in sorted((ROOT / "apple").rglob("*.swift")):
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "assumeIsolated" not in line:
            continue
        stripped = line.strip()
        # 註解裡提到它（例如這次修正留下的說明）不算。
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        if "assumeIsolated-ok:" in line:
            continue
        hits.append((path.relative_to(ROOT), lineno, stripped))

if hits:
    print("❌ 用了 MainActor.assumeIsolated —— 保證錯了只會在執行期炸：")
    for rel, lineno, text in hits:
        print(f"   {rel}:{lineno}  {text}")
    print()
    print("   改用 nonisolated 的查表、鎖，或 await MainActor.run；")
    print("   真的必要就在該行加 // assumeIsolated-ok: <理由>")
    sys.exit(1)

print("✅ apple/ 沒有 MainActor.assumeIsolated")
