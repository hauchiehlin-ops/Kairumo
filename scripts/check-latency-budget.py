#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""守門機制 Layer 6：延遲預算量測點檢查（Latency Budget Gatekeeper）。

PerfProbe.swift 的每個 `PerfPoint` 都必須在 Sources 內至少有一處
`PerfProbe.shared.measure(.<case>)`，否則「有預算、沒量測」等於沒有預算。
反向：measure 用到的 case 必須存在於 PerfPoint。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "apple" / "Sources"
probe = (SRC / "PerfProbe.swift").read_text(encoding="utf-8")
cases = set(re.findall(r"^\s*case ([a-zA-Z]+)\s*$", probe.split("enum PerfPoint")[1].split("var budgetMs")[0], re.M))
used = set()
for f in SRC.glob("*.swift"):
    if f.name.startswith("._") or f.name == "PerfProbe.swift":
        continue
    used |= set(re.findall(r"PerfProbe\.shared\.measure\(\.([a-zA-Z]+)\)", f.read_text(encoding="utf-8")))
bad = False
for c in sorted(cases - used):
    print(f"❌ PerfPoint.{c} 沒有任何量測點（PerfProbe.shared.measure(.{c}) ）"); bad = True
for c in sorted(used - cases):
    print(f"❌ measure(.{c}) 不在 PerfPoint 清單"); bad = True
if not cases:
    print("❌ 讀不到 PerfPoint 清單"); bad = True
if not bad:
    print(f"✅ 延遲預算量測點齊全（{len(cases)} 個）")
sys.exit(1 if bad else 0)
