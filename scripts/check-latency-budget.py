#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""守門機制 Layer 6：延遲預算量測點檢查（Latency Budget Gatekeeper）。

Apple（PerfProbe.swift）與 Android（perf/PerfProbe.kt）各有一份 `PerfPoint` 與預算：
1. 每個 case 都必須在原始碼內至少有一處量測點，否則「有預算、沒量測」等於沒有預算；
2. measure 用到的 case 必須存在於清單；
3. 兩個平台的 case 名稱與預算數字必須一致（同一個動作的標準不該因平台而異，I6 跨端對齊）。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPLE = ROOT / "apple" / "Sources"
ANDROID = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote"

bad = False


def fail(msg):
    global bad
    print("❌ " + msg)
    bad = True


def lower_first(name):
    return name[0].lower() + name[1:]


# ── Apple ──
probe = (APPLE / "PerfProbe.swift").read_text(encoding="utf-8")
point_block = probe.split("enum PerfPoint")[1].split("var budgetMs")[0]
apple_cases = set(re.findall(r"^\s*case ([a-zA-Z]+)\s*$", point_block, re.M))
budget_block = probe.split("var budgetMs")[1].split("final class PerfProbe")[0]
apple_budgets = {m[0]: float(m[1]) for m in re.findall(r"case \.([a-zA-Z]+): return ([0-9.]+)", budget_block)}
apple_used = set()
for f in APPLE.glob("*.swift"):
    if f.name.startswith("._") or f.name == "PerfProbe.swift":
        continue
    apple_used |= set(re.findall(r"PerfProbe\.shared\.measure\(\.([a-zA-Z]+)\)", f.read_text(encoding="utf-8")))

for c in sorted(apple_cases - apple_used):
    fail(f"[Apple] PerfPoint.{c} 沒有任何量測點（PerfProbe.shared.measure(.{c}) ）")
for c in sorted(apple_used - apple_cases):
    fail(f"[Apple] measure(.{c}) 不在 PerfPoint 清單")
if not apple_cases:
    fail("[Apple] 讀不到 PerfPoint 清單")

# ── Android ──
kprobe = (ANDROID / "perf" / "PerfProbe.kt").read_text(encoding="utf-8")
enum_block = kprobe.split("enum class PerfPoint")[1].split("}")[0]
android_budgets = {lower_first(n): float(b) for n, b in re.findall(r"^\s*([A-Za-z]+)\(([0-9.]+)\)", enum_block, re.M)}
android_used = set()
for f in ANDROID.rglob("*.kt"):
    if f.name.startswith("._") or f.name == "PerfProbe.kt":
        continue
    text = f.read_text(encoding="utf-8")
    android_used |= {lower_first(m) for m in re.findall(r"PerfPoint\.([A-Za-z]+)", text)}

for c in sorted(set(android_budgets) - android_used):
    fail(f"[Android] PerfPoint.{c[0].upper() + c[1:]} 沒有任何量測點")
for c in sorted(android_used - set(android_budgets)):
    fail(f"[Android] 用到不存在的 PerfPoint.{c[0].upper() + c[1:]}")
if not android_budgets:
    fail("[Android] 讀不到 PerfPoint 清單")

# ── 跨端對齊 ──
if set(apple_budgets) != set(android_budgets):
    fail(f"兩端的 PerfPoint 名單不同：Apple {sorted(apple_budgets)} / Android {sorted(android_budgets)}")
else:
    for k in sorted(apple_budgets):
        if apple_budgets[k] != android_budgets[k]:
            fail(f"預算不一致 {k}：Apple {apple_budgets[k]} ms / Android {android_budgets[k]} ms")

if not bad:
    print(f"✅ 延遲預算量測點齊全且兩端對齊（Apple {len(apple_cases)} / Android {len(android_budgets)} 個）")
sys.exit(1 if bad else 0)
