#!/usr/bin/env python3
"""跨平台畫面對照閘門（階段 0）。

核心的 `ffi_screens` 描述每個畫面有哪些控制項；這支腳本檢查**兩端的程式碼
真的有把它們畫出來**：Apple 端找 `accessibilityIdentifier("…")`，
Android 端找 `testTag("…")`。

# 為什麼是掃原始碼，不是跑介面測試

跑介面要模擬器、要真的把每個畫面點開、而且會因為動畫與載入時序而間歇失敗
——間歇失敗的閘門會在第三次紅的時候被關掉。掃原始碼一秒跑完、在 Linux
runner 上也能跑，而它擋的正是實際發生過的那件事：**Apple 加了一個控制項，
Android 沒有跟上**。

代價是它驗不出「宣告了但沒真的顯示」。那一層由各平台自己的畫面測試顧，
不是這道閘門的工作。

# 為什麼有 baseline（棘輪）

現況本來就有一大批缺口（這正是整個計劃要修的）。閘門如果一開始就全紅，
它會被關掉，然後一切照舊。所以：已知的缺口寫在 `docs/parity/baseline.json`
裡，CI 只擋**新增**的缺口。每做完一個階段就把對應的項目從 baseline 移除，
`--update-baseline` 會自動把它縮到目前的實況 —— 但它只縮不長：
出現新缺口時腳本一定會紅，不會偷偷把 baseline 撐大。

用法：
    python3 scripts/check-screen-parity.py             # 檢查
    python3 scripts/check-screen-parity.py --update-baseline   # 只允許縮小
    python3 scripts/check-screen-parity.py --update-baseline --accept-new
                                    # 規格自己長大時（把 Apple 既有的控制項
                                    # 補進規格），明講一聲才准變長
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "docs" / "parity" / "baseline.json"

APPLE_SOURCES = ROOT / "apple" / "Sources"
ANDROID_SOURCES = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo"


def spec() -> dict:
    """跑核心那支程式拿規格。核心是唯一的來源，不要在這裡重寫一份。"""
    out = subprocess.run(
        ["cargo", "run", "-q", "-p", "padnote-core", "--bin", "screen-spec"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)


def identifiers(root: Path, patterns: list[str], suffix: str) -> set[str]:
    found: set[str] = set()
    regexes = [re.compile(p) for p in patterns]
    for path in root.rglob(f"*{suffix}"):
        # 產生的字串表有一萬行、而且不含任何控制項，掃它只是浪費時間。
        if "generated" in path.name.lower() or path.name == "LocalizationStrings.kt":
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for regex in regexes:
            found.update(regex.findall(text))
    return found


# 有些控制項不是視圖，掛不上識別字 —— Android 的系統返回鍵
# （`BackHandler`）就是。那種情況用一行 `// parity: <id>` 註解宣告，
# 它一樣進得了對照，而且在原始碼裡看得見「這一項是刻意對到規格的哪一條」。
PARITY_COMMENT = r'//\s*parity:\s*([\w.]+)'

# 用 ForEach / for 迴圈畫出來的一整組控制項（九支筆、六個配色…）不會有
# 十五行 `testTag("…")`，而是一張對照表：Swift 的 `case .pen: return "…"`、
# Kotlin 的 `Tool.PEN -> "…"`。那些字面值也算數 —— 不算的話，
# 為了通過閘門就得把迴圈拆成十五段複製貼上的程式碼。
# 識別字不一定寫在 `accessibilityIdentifier(...)` 裡：一整組控制項常常是
# 一張對照表（Swift 的 `case .pen: return "…"`、Kotlin 的 `PEN -> "…"`），
# 或是傳給共用版型的一個參數（`identifier: "home.action.record"`）。
# 那些都算數 —— 不算的話，為了通過閘門就得把迴圈拆成十五段複製貼上。
#
# 這一條掃的是**任何長得像規格 id 的字串字面值**，再與規格取交集。
# 交集之外的字面值（`kairumo.app.language` 之類）不會有任何作用。
IDENTIFIER_TABLE = [r'"([a-z][A-Za-z0-9_]*(?:\.[a-z][A-Za-z0-9_]*)+)"']


def apple_ids() -> set[str]:
    return identifiers(
        APPLE_SOURCES,
        [r'accessibilityIdentifier\(\s*"([^"]+)"\s*\)', PARITY_COMMENT, *IDENTIFIER_TABLE],
        ".swift",
    )


def android_ids() -> set[str]:
    return identifiers(
        ANDROID_SOURCES,
        [r'testTag\(\s*"([^"]+)"\s*\)', PARITY_COMMENT, *IDENTIFIER_TABLE],
        ".kt",
    )


def required(screens: dict, platform: str) -> list[tuple[str, str]]:
    """(畫面, 控制項 id)，排除 optional 與另一個平台專有的。"""
    out: list[tuple[str, str]] = []
    for screen, body in screens.items():
        for ctl in body["controls"]:
            if ctl["optional"]:
                continue
            if ctl["platforms"] not in ("both", platform):
                continue
            out.append((screen, ctl["id"]))
    return out


def load_baseline() -> dict[str, list[str]]:
    if not BASELINE.exists():
        return {"apple": [], "android": []}
    return json.loads(BASELINE.read_text(encoding="utf-8"))


def main() -> int:
    update = "--update-baseline" in sys.argv
    # 規格**本身**長大時（把 Apple 既有但還沒寫進規格的控制項補進來），
    # 缺口清單當然會變長。那不是退步，但也不該悄悄發生 —— 要明講。
    accept_new = "--accept-new" in sys.argv
    screens = spec()
    present = {"apple": apple_ids(), "android": android_ids()}
    base = load_baseline()

    missing: dict[str, list[str]] = {}
    for platform in ("apple", "android"):
        missing[platform] = sorted(
            cid for _, cid in required(screens, platform) if cid not in present[platform]
        )

    if update:
        # 第一次建立 baseline 時沒有東西可以比對「有沒有變大」——
        # 那是這個計劃開始的那一刻，缺口就是現況。
        seeding = not BASELINE.exists()
        grew = []
        for platform in ("apple", "android"):
            new = [m for m in missing[platform] if m not in base.get(platform, [])]
            grew.extend(f"{platform}: {m}" for m in new)
        if grew and not seeding and not accept_new:
            print("❌ baseline 只能縮小。這些是新出現的缺口，請補上而不是寫進 baseline：")
            for line in grew:
                print(f"   {line}")
            return 1
        if grew and accept_new:
            print(f"⚠️  規格新增了 {len(grew)} 項尚未實作的控制項（--accept-new）：")
            for line in grew[:20]:
                print(f"   {line}")
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(
            json.dumps(missing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        total = len(missing["apple"]) + len(missing["android"])
        print(f"✅ baseline 已更新：還差 {total} 項（Apple {len(missing['apple'])}、Android {len(missing['android'])}）")
        return 0

    failures: list[str] = []
    for platform in ("apple", "android"):
        allowed = set(base.get(platform, []))
        new = [m for m in missing[platform] if m not in allowed]
        failures.extend(f"{platform}: {m}" for m in new)
        # baseline 裡已經補好的項目要拿掉，否則棘輪會鬆掉。
        fixed = [m for m in allowed if m in present[platform]]
        if fixed:
            print(f"ℹ️  {platform} 有 {len(fixed)} 項已補上，請跑 --update-baseline 把它們從 baseline 移除：")
            for f in sorted(fixed)[:10]:
                print(f"   {f}")

    if failures:
        print("❌ 有控制項在核心規格裡，但平台程式碼中找不到對應的識別字：")
        for line in failures:
            print(f"   {line}")
        print()
        print("   Apple 端要 .accessibilityIdentifier(\"<id>\")；")
        print("   Android 端要 Modifier.testTag(\"<id>\")。")
        print("   刻意的平台差異請在 ffi_screens.rs 標成 AppleOnly / AndroidOnly，")
        print("   並寫進 docs/android-parity-plan.md 的白名單。")
        return 1

    remaining = sum(len(v) for v in base.values())
    print(f"✅ 畫面對照通過（baseline 尚欠 {remaining} 項，依計劃逐階段清空）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
