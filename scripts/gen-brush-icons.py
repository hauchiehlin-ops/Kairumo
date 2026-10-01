#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/gen-brush-icons.py
--------------------------
產生 assets/brushes/*.svg —— 工具列上每支筆的向量圖示（兩個平台共用同一份）。

為什麼用腳本產生而不是手寫座標：每支筆都是同一個姿勢（筆尖在左下、筆身朝右上斜 45°），
用「沿筆軸的長度 u、垂直筆軸的偏移 v」描述形狀，再統一旋轉成頁面座標，
十幾支筆的角度與落點才會一致；手寫座標改一支就要重算整組。

規則（核心的 SVG 子集解析器只認這些，見 crates/padnote-core/src/ffi_brush.rs）：
  - 元素：path / polygon / circle / ellipse / rect / line，不用 transform、不用 arc。
  - 顏色：#rrggbb、none，或 currentColor（= 使用者目前選的筆色，圖示會跟著換色）。
  - 屬性：fill、stroke、stroke-width、opacity、stroke-linecap。
改了形狀請重新執行本腳本並提交產物。
"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "brushes")
TIP = (7.0, 41.0)               # 筆尖落點
A = (math.sqrt(0.5), -math.sqrt(0.5))   # 筆軸（朝右上）
P = (math.sqrt(0.5), math.sqrt(0.5))    # 垂直筆軸（朝右下）

def pt(u, v):
    return (TIP[0] + A[0] * u + P[0] * v, TIP[1] + A[1] * u + P[1] * v)

def f(n):
    return ("%.2f" % n).rstrip("0").rstrip(".")

def poly(points, fill, stroke=None, sw=0.8, opacity=None, extra=""):
    pts = " ".join(f"{f(x)},{f(y)}" for x, y in (pt(u, v) for u, v in points))
    attrs = f'fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linejoin="round"'
    if opacity is not None:
        attrs += f' opacity="{f(opacity)}"'
    return f'<polygon points="{pts}" {attrs}{extra}/>'

def rect(u0, u1, v0, v1, fill, stroke=None, sw=0.8, **kw):
    return poly([(u0, v0), (u1, v0), (u1, v1), (u0, v1)], fill, stroke, sw, **kw)

def line(u0, v0, u1, v1, stroke, sw=1.0, opacity=None):
    (x0, y0), (x1, y1) = pt(u0, v0), pt(u1, v1)
    o = f' opacity="{f(opacity)}"' if opacity is not None else ""
    return f'<line x1="{f(x0)}" y1="{f(y0)}" x2="{f(x1)}" y2="{f(y1)}" stroke="{stroke}" stroke-width="{f(sw)}" stroke-linecap="round"{o}/>'

def dot(x, y, r, fill, opacity=None):
    o = f' opacity="{f(opacity)}"' if opacity is not None else ""
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"{o}/>'

INK = "currentColor"
METAL, METAL_D = "#c9ced6", "#8d939d"
DARK, DARKER = "#34363b", "#1f2024"
WOOD, WOOD_D = "#c58f5c", "#8a5a33"

icons = {}

# ── 書寫 ────────────────────────────────────────────────
icons["pen"] = [   # 鋼筆：金屬筆尖＋墨水色環＋深色筆身
    poly([(0, 0), (11, -3.6), (13, 0), (11, 3.6)], METAL, METAL_D, 0.6),
    line(1.5, 0, 11, 0, METAL_D, 0.7),
    rect(13, 17, -4.2, 4.2, METAL_D),
    rect(17, 52, -4.8, 4.8, DARK),
    rect(40, 44, -4.9, 4.9, INK),
    line(19, -3.4, 50, -3.4, "#ffffff", 0.9, 0.22),
]
icons["ballpoint"] = [  # 原子筆：圓錐筆尖、淺色筆身、按壓鈕
    poly([(0, 0), (9, -2.6), (9, 2.6)], METAL, METAL_D, 0.6),
    rect(9, 46, -3.6, 3.6, "#e6e9ee", METAL_D, 0.6),
    rect(9, 20, -3.7, 3.7, INK),
    rect(46, 54, -2.2, 2.2, INK),
    line(30, 3.8, 46, 3.8, METAL_D, 1.2),
]
icons["fineliner"] = [  # 針筆：細長筆身、極細筆尖
    poly([(0, 0), (9, -1.5), (9, 1.5)], DARKER),
    rect(9, 14, -2.1, 2.1, METAL),
    rect(14, 52, -2.6, 2.6, "#f1f2f4", METAL_D, 0.5),
    rect(14, 24, -2.7, 2.7, INK),
    rect(30, 52, -2.7, -0.4, INK, opacity=0.18),
]
icons["brush"] = [  # 毛筆：飽墨的筆鋒＋金屬箍＋木桿
    '<path d="%s" fill="currentColor"/>' % (
        "M " + " L ".join(f"{f(x)},{f(y)}" for x, y in (pt(u, v) for u, v in
        [(0, 0), (3, -1.8), (9, -4.2), (15, -4.4), (15, 4.4), (9, 4.2), (3, 1.8)])) + " Z"),
    rect(15, 21, -4.6, 4.6, METAL, METAL_D, 0.6),
    poly([(21, -3.2), (52, -2), (52, 2), (21, 3.2)], WOOD_D),
    line(23, -1.8, 50, -1.2, "#ffffff", 0.8, 0.2),
]
icons["calligraphy"] = [  # 書法扁頭筆：斜切的扁筆尖
    poly([(0, -5.6), (7, -5.6), (11, -3.6), (11, 3.6), (7, 5.6), (0, 5.6), (3, 0)], INK),
    rect(11, 15, -4.2, 4.2, METAL, METAL_D, 0.6),
    rect(15, 52, -3.8, 3.8, DARK),
    rect(15, 20, -3.9, 3.9, "#b8892f"),
    line(22, -2.8, 50, -2.8, "#ffffff", 0.9, 0.22),
]
icons["pencil"] = [  # 鉛筆：削尖的木頭＋石墨＋六角筆身＋橡皮擦
    poly([(0, 0), (8, -4.2), (8, 4.2)], "#ecd2a4"),
    poly([(0, 0), (3.2, -1.7), (3.2, 1.7)], INK),
    rect(8, 44, -4.4, 4.4, "#f2b632"),
    line(8, 0, 44, 0, "#c98a12", 0.9),
    rect(44, 48, -4.5, 4.5, METAL, METAL_D, 0.5),
    rect(48, 53, -4.4, 4.4, "#ee8fa2"),
]

# ── 繪畫 ────────────────────────────────────────────────
icons["charcoal"] = [  # 炭筆：粗糙的炭條，半截包著紙
    poly([(0, -1.5), (3, -4.4), (6, -4.2), (8, -4.6), (8, 4.6), (5, 4.2), (2, 4.6), (0, 2.4)], INK),
    rect(8, 28, -4.8, 4.8, DARK),
    rect(26, 52, -5, 5, "#efe9dc", METAL_D, 0.6),
    line(30, -5, 30, 5, METAL_D, 0.6),
    line(38, -5, 38, 5, METAL_D, 0.6, 0.6),
    dot(*pt(4, -1), 0.7, "#ffffff", 0.35), dot(*pt(5.5, 2), 0.6, "#ffffff", 0.3),
]
icons["crayon"] = [  # 蠟筆：圓錐筆尖＋紙標籤
    poly([(0, 0), (3, -2.4), (11, -4.8), (11, 4.8), (3, 2.4)], INK),
    rect(11, 50, -4.9, 4.9, INK),
    rect(17, 44, -5.1, 5.1, "#ffffff", opacity=0.55),
    line(17, -5.1, 17, 5.1, "#ffffff", 0.8),
    line(44, -5.1, 44, 5.1, "#ffffff", 0.8),
    rect(24, 37, -2.4, 2.4, INK, opacity=0.5),
    rect(50, 52.5, -4.3, 4.3, INK),
]
icons["airbrush"] = [  # 噴槍：噴嘴＋槍身＋扳機，筆尖前噴出細點
    poly([(2, -1.6), (10, -2.6), (10, 2.6), (2, 1.6)], METAL, METAL_D, 0.6),
    rect(10, 38, -4.2, 4.2, DARK),
    rect(16, 24, -4.3, 4.3, INK),
    poly([(26, 4.2), (34, 4.2), (36, 8.6), (30, 9.4)], METAL_D),
    poly([(38, -3.4), (52, -2.2), (52, 2.2), (38, 3.4)], METAL, METAL_D, 0.6),
    dot(*pt(-2.2, 0), 1.1, INK, 0.85), dot(*pt(-4, -2.2), 0.8, INK, 0.7),
    dot(*pt(-4.2, 2.4), 0.8, INK, 0.7), dot(*pt(-6, 0.2), 0.65, INK, 0.5),
    dot(*pt(-3, -4.6), 0.55, INK, 0.45), dot(*pt(-3.4, 4.8), 0.55, INK, 0.45),
]
icons["oilpaint"] = [  # 油畫筆：扁平寬鬃毛＋筆刷箍＋長桿
    poly([(0, -4.4), (13, -5.6), (13, 5.6), (0, 4.4)], INK),
    line(4, -3.6, 13, -4.6, "#ffffff", 0.7, 0.35),
    line(4, 0, 13, 0, "#ffffff", 0.7, 0.3),
    line(4, 3.6, 13, 4.6, "#000000", 0.7, 0.25),
    rect(13, 20, -5.8, 5.8, METAL, METAL_D, 0.6),
    poly([(20, -3.4), (52, -2.2), (52, 2.2), (20, 3.4)], "#7a3b2a"),
    line(22, -1.8, 50, -1.2, "#ffffff", 0.8, 0.18),
]
icons["watercolor"] = [  # 水彩筆：圓頭筆鋒、水滴
    '<path d="%s" fill="currentColor"/>' % (
        "M " + " L ".join(f"{f(x)},{f(y)}" for x, y in (pt(u, v) for u, v in
        [(0, 0), (2, -1.6), (8, -3.9), (14, -4.0), (14, 4.0), (8, 3.9), (2, 1.6)])) + " Z"),
    rect(14, 20, -4.2, 4.2, METAL, METAL_D, 0.6),
    poly([(20, -3), (52, -1.8), (52, 1.8), (20, 3)], "#4d7fa8"),
    # 水滴
    '<path d="M 36,10 C 36,10 31,16 31,19.4 C 31,22.2 33.2,24.4 36,24.4 C 38.8,24.4 41,22.2 41,19.4 C 41,16 36,10 36,10 Z" fill="currentColor" opacity="0.55"/>',
]

# ── 標記 ────────────────────────────────────────────────
icons["marker"] = [  # 麥克筆：斜切粗筆尖＋深色筆身＋色環
    poly([(0, -1.2), (8, -4.4), (8, 4.4), (0, 2.6)], INK),
    rect(8, 12, -4.7, 4.7, METAL, METAL_D, 0.6),
    rect(12, 50, -5.1, 5.1, DARK),
    rect(12, 20, -5.2, 5.2, INK),
    line(24, -3.8, 48, -3.8, "#ffffff", 0.9, 0.2),
]
icons["highlighter"] = [  # 螢光筆：寬扁的斜切筆尖＋半透明色彩
    poly([(0, -2), (9, -6.4), (9, 6.4), (0, 3)], INK, opacity=0.85),
    rect(9, 14, -6.7, 6.7, "#f1f2f4", METAL_D, 0.6),
    rect(14, 46, -7, 7, "#f4f4ee", METAL_D, 0.6),
    rect(14, 46, -7, -3, INK, opacity=0.6),
    rect(46, 52, -6.2, 6.2, INK),
]

# ── 編輯模式（不沾墨）───────────────────────────────────
icons["eraser"] = [
    poly([(2, -8), (36, -8), (36, 8), (2, 8)], "#ee8fa2", "#b85c70", 0.7),
    rect(2, 14, -8, 8, "#f6f0f1", "#b85c70", 0.7),
    line(14, -8, 14, 8, "#b85c70", 0.7),
    rect(2, 36, 5, 8, "#000000", opacity=0.08),
]
icons["lasso"] = [
    '<path d="M 24,10 C 12,10 6,16 7,22 C 8,29 18,33 28,31 C 38,29 42,22 38,16 C 35,11 30,10 24,10 Z" fill="none" stroke="#5a6270" stroke-width="2.4" stroke-linecap="round"/>',
    '<path d="M 20,32 C 18,38 22,42 26,41" fill="none" stroke="#5a6270" stroke-width="2.4" stroke-linecap="round"/>',
    dot(26.5, 41, 2.2, "#5a6270"),
]
icons["maskingtape"] = [
    '<circle cx="24" cy="24" r="16" fill="#e8d7a8" stroke="#b79d5a" stroke-width="1.2"/>',
    '<circle cx="24" cy="24" r="7" fill="#ffffff" stroke="#b79d5a" stroke-width="1.2"/>',
    '<path d="M 40,24 L 46,31 L 38,33 Z" fill="#e8d7a8" stroke="#b79d5a" stroke-width="1"/>',
    '<circle cx="24" cy="24" r="11.5" fill="none" stroke="#b79d5a" stroke-width="0.6" opacity="0.6"/>',
]

os.makedirs(OUT, exist_ok=True)
for name, shapes in icons.items():
    body = "\n  ".join(shapes)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">\n'
           f'  {body}\n</svg>\n')
    with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as fh:
        fh.write(svg)
print(f"已產生 {len(icons)} 個圖示到 assets/brushes/")
