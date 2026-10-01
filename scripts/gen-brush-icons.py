#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/gen-brush-icons.py
--------------------------
產生 assets/brushes/*.svg —— 工具列上每支筆的向量圖示（兩個平台共用同一份）。

# 設計原則：畫的是**真的東西**

每個圖示都依真實物件的構造畫：鋼筆有筆尖、呼吸孔、握位、金屬環、亮面筆身；鉛筆是六角柱、
有金屬箍與橡皮擦；毛筆有竹竿的節、銅箍、狼毫的筆鋒；噴槍有色杯、扳機、氣管接頭。
金屬、塑膠、木頭、毛髮靠**漸層**表現 —— 圓柱的筆身要「暗—亮—暗」才像圓柱，平塗只會像剪紙。
上了色的部分（墨水、顏料、蠟筆紙）用 `currentColor`（再加深／提亮），跟著使用者選的筆色走。

# 做法

每支筆都在同一個姿勢：筆尖在左下、筆身朝右上斜 45°。形狀用「沿筆軸的長度 u、垂直筆軸的
偏移 v」描述，再統一旋轉成頁面座標；漸層的方向也以這兩個軸定義（橫跨筆身 = 沿 v）。

# 規則（核心的 SVG 子集解析器只認這些，見 crates/padnote-core/src/ffi_brush.rs）

  - 元素：path / polygon / circle / ellipse / rect / line，加上 linearGradient / radialGradient / stop。
  - 不用 transform、arc、clipPath、filter。
  - 顏色：#rrggbb、none、currentColor、url(#漸層)；色標可用 `stop-color="currentColor"`
    再以 `data-shade`（-1 向黑，+1 向白）調明暗。
改了形狀請重新執行本腳本並提交產物。
"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "brushes")
TIP = (6.5, 41.5)
# 全部零件的長度與粗細一起縮放，讓最長、最寬的筆也放得進 48×48（不被裁掉）。
S = 0.9
A = (math.sqrt(0.5), -math.sqrt(0.5))   # 筆軸（朝右上）
N = (math.sqrt(0.5), math.sqrt(0.5))    # 垂直筆軸（朝右下）


def pt(u, v):
    u, v = u * S, v * S
    return (TIP[0] + A[0] * u + N[0] * v, TIP[1] + A[1] * u + N[1] * v)


def f(x):
    return ("%.2f" % x).rstrip("0").rstrip(".")


class Icon:
    def __init__(self):
        self.defs = []
        self.shapes = []
        self._n = 0

    # ── 漸層 ──
    def _stops(self, stops):
        out = []
        for st in stops:
            off, color = st[0], st[1]
            opacity = st[2] if len(st) > 2 else 1
            shade = st[3] if len(st) > 3 else None
            if color == "ink":
                attrs = 'stop-color="currentColor"'
                if shade is not None:
                    attrs += f' data-shade="{f(shade)}"'
            else:
                attrs = f'stop-color="{color}"'
            if opacity != 1:
                attrs += f' stop-opacity="{f(opacity)}"'
            out.append(f'<stop offset="{f(off)}" {attrs}/>')
        return "".join(out)

    def lin(self, p0, p1, stops):
        """頁面座標的線性漸層。回傳 `url(#id)`。"""
        self._n += 1
        gid = f"g{self._n}"
        self.defs.append(
            f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
            f'x1="{f(p0[0])}" y1="{f(p0[1])}" x2="{f(p1[0])}" y2="{f(p1[1])}">{self._stops(stops)}</linearGradient>')
        return f"url(#{gid})"

    def across(self, u, r, stops):
        """橫跨筆身（沿 v，從 -r 到 +r）的漸層 —— 圓柱的明暗。"""
        return self.lin(pt(u, -r), pt(u, r), stops)

    def along(self, u0, u1, stops, v=0):
        return self.lin(pt(u0, v), pt(u1, v), stops)

    def rad(self, c, r, stops):
        self._n += 1
        gid = f"g{self._n}"
        self.defs.append(
            f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{f(c[0])}" cy="{f(c[1])}" r="{f(r)}">'
            f'{self._stops(stops)}</radialGradient>')
        return f"url(#{gid})"

    # ── 形狀 ──
    def poly(self, uv, fill, stroke=None, sw=0.5, opacity=None):
        pts = " ".join(f"{f(x)},{f(y)}" for x, y in (pt(u, v) for u, v in uv))
        self.shapes.append(self._el("polygon", f'points="{pts}"', fill, stroke, sw, opacity))

    def raw_poly(self, xy, fill, stroke=None, sw=0.5, opacity=None):
        pts = " ".join(f"{f(x)},{f(y)}" for x, y in xy)
        self.shapes.append(self._el("polygon", f'points="{pts}"', fill, stroke, sw, opacity))

    def path(self, d, fill, stroke=None, sw=0.5, opacity=None, cap=None):
        self.shapes.append(self._el("path", f'd="{d}"', fill, stroke, sw, opacity, cap))

    def curve_uv(self, segs, fill, stroke=None, sw=0.5, opacity=None):
        """用 (u,v) 描述的路徑：segs = [('M',u,v),('L',u,v),('C',u1,v1,u2,v2,u,v),('Z',)]。"""
        d = []
        for s in segs:
            if s[0] == "Z":
                d.append("Z")
                continue
            coords = []
            for i in range(1, len(s), 2):
                x, y = pt(s[i], s[i + 1])
                coords.append(f"{f(x)},{f(y)}")
            d.append(s[0] + " " + " ".join(coords))
        self.path(" ".join(d), fill, stroke, sw, opacity)

    def line(self, uv0, uv1, stroke, sw=0.6, opacity=None, cap="round"):
        (x0, y0), (x1, y1) = pt(*uv0), pt(*uv1)
        self.shapes.append(
            f'<line x1="{f(x0)}" y1="{f(y0)}" x2="{f(x1)}" y2="{f(y1)}" stroke="{Icon._c(stroke)}" '
            f'stroke-width="{f(sw)}" stroke-linecap="{cap}"' + (f' opacity="{f(opacity)}"' if opacity is not None else "") + "/>")

    def raw_line(self, p0, p1, stroke, sw=0.6, opacity=None, cap="round"):
        self.shapes.append(
            f'<line x1="{f(p0[0])}" y1="{f(p0[1])}" x2="{f(p1[0])}" y2="{f(p1[1])}" stroke="{Icon._c(stroke)}" '
            f'stroke-width="{f(sw)}" stroke-linecap="{cap}"' + (f' opacity="{f(opacity)}"' if opacity is not None else "") + "/>")

    def dot(self, x, y, r, fill, opacity=None, stroke=None, sw=0.4):
        self.shapes.append(self._el("circle", f'cx="{f(x)}" cy="{f(y)}" r="{f(r)}"', fill, stroke, sw, opacity))

    def dot_uv(self, u, v, r, fill, opacity=None):
        x, y = pt(u, v)
        self.dot(x, y, r, fill, opacity)

    def ellipse(self, cx, cy, rx, ry, fill, stroke=None, sw=0.5, opacity=None):
        self.shapes.append(self._el("ellipse", f'cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}"', fill, stroke, sw, opacity))

    @staticmethod
    def _c(color):
        """`"ink"` 是筆色的簡寫，輸出成標準的 currentColor。"""
        return "currentColor" if color == "ink" else color

    @staticmethod
    def _el(tag, geom, fill, stroke, sw, opacity, cap=None):
        fill = Icon._c(fill)
        stroke = Icon._c(stroke) if stroke else stroke
        a = f'fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linejoin="round"'
            if cap:
                a += f' stroke-linecap="{cap}"'
        elif cap:
            a += f' stroke-linecap="{cap}"'
        if opacity is not None:
            a += f' opacity="{f(opacity)}"'
        return f"<{tag} {geom} {a}/>"

    # ── 零件 ──
    def cyl(self, u0, u1, r0, r1, stops, stroke=None, sw=0.35):
        """圓柱／圓錐：沿軸的梯形，橫跨筆身上漸層。"""
        fill = self.across((u0 + u1) / 2, max(r0, r1), stops)
        self.poly([(u0, -r0), (u1, -r1), (u1, r1), (u0, r0)], fill, stroke, sw)

    def shine(self, u0, u1, v, w=0.7, opacity=0.4, color="#ffffff"):
        self.line((u0, v), (u1, v), color, w, opacity)

    def svg(self):
        defs = f"<defs>{''.join(self.defs)}</defs>" if self.defs else ""
        body = "\n  ".join(self.shapes)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">\n'
                f'  {defs}\n  {body}\n</svg>\n')


# ── 材質 ────────────────────────────────────────────────
STEEL = [(0, "#4a4e56"), (0.2, "#a9aeb8"), (0.38, "#f1f3f6"), (0.55, "#aeb3bc"), (0.8, "#6a6f78"), (1, "#3a3d44")]
CHROME = [(0, "#303338"), (0.25, "#8b9099"), (0.42, "#ffffff"), (0.6, "#9aa0aa"), (1, "#2b2e33")]
GOLD = [(0, "#6e4e12"), (0.22, "#c99a2c"), (0.42, "#fff0a8"), (0.6, "#c59326"), (1, "#5a3e0c")]
GLOSS_BLACK = [(0, "#08080a"), (0.18, "#2a2b30"), (0.36, "#8a8c95"), (0.46, "#2c2d32"), (0.8, "#111114"), (1, "#050506")]
RUBBER = [(0, "#101113"), (0.3, "#2c2e32"), (0.5, "#4a4d53"), (1, "#0d0e10")]
PINK_ERASER = [(0, "#c46a7a"), (0.3, "#f4a8b6"), (0.5, "#ffd3dc"), (1, "#b5586a")]
BAMBOO = [(0, "#8a6224"), (0.25, "#d2a752"), (0.45, "#f3dd96"), (0.7, "#c79a45"), (1, "#7a5319")]
PAPER = [(0, "#cfc6b0"), (0.3, "#f3ecd8"), (0.5, "#fffaf0"), (1, "#c3b99f")]


def ink_cyl(lo=-0.55, mid=0.0, hi=0.4):
    return [(0, "ink", 1, lo), (0.3, "ink", 1, mid), (0.45, "ink", 1, hi), (0.7, "ink", 1, mid - 0.1), (1, "ink", 1, lo - 0.1)]


icons = {}

# ── 鋼筆 ──────────────────────────────────────────────
ic = Icon()
# 筆尖：鋼製、有肩、細長的尖，中間一條切縫與呼吸孔，筆尖沾著墨水。
nib = ic.across(8, 4.0, STEEL)
ic.curve_uv([("M", 0, 0), ("C", 3, -0.8, 7, -3.4, 12, -3.9), ("L", 16, -3.9), ("L", 16, 3.9), ("L", 12, 3.9),
             ("C", 7, 3.4, 3, 0.8, 0, 0), ("Z",)], nib, "#3a3d44", 0.3)
ic.line((0.6, 0), (11.5, 0), "#1c1d20", 0.45)
ic.dot_uv(10.6, 0, 0.8, "#1c1d20")
ic.line((12, -3.5), (15.5, -3.5), "#ffffff", 0.5, 0.5)
ic.curve_uv([("M", 0, 0), ("C", 1, -0.3, 2.2, -0.9, 3.2, -1.3), ("L", 3.2, 1.3), ("C", 2.2, 0.9, 1, 0.3, 0, 0), ("Z",)],
            "ink", None, 0, 0.95)
# 握位（section）：黑色亮面，由細漸粗。
ic.poly([(16, -3.7), (25, -4.7), (25, 4.7), (16, 3.7)], ic.across(20, 4.7, GLOSS_BLACK))
# 金屬環與筆桿。
ic.cyl(25, 27, 5.0, 5.0, CHROME)
ic.cyl(27, 49, 5.0, 5.2, GLOSS_BLACK)
ic.cyl(40, 42, 5.25, 5.25, ink_cyl())            # 墨色環：看得出選了什麼顏色
ic.shine(28, 48, -2.9, 0.9, 0.38)
ic.cyl(49, 51, 5.3, 5.3, GOLD)
ic.curve_uv([("M", 51, -5.0), ("C", 53.5, -4.6, 54.5, -2.5, 54.5, 0), ("C", 54.5, 2.5, 53.5, 4.6, 51, 5.0), ("Z",)],
            ic.across(52, 5, GLOSS_BLACK))
icons["pen"] = ic

# ── 原子筆（透明筆管的按壓式）──────────────────────────
ic = Icon()
ic.cyl(0.6, 7.5, 0.5, 2.1, STEEL, "#3a3d44", 0.25)            # 筆尖錐
ic.dot_uv(0.5, 0, 0.55, ic.rad(pt(0.3, -0.2), 0.8, [(0, "#ffffff"), (1, "#7b8089")]))   # 滾珠
ic.cyl(7.5, 13, 2.1, 3.7, [(0, "#8d9199"), (0.4, "#f2f4f7"), (1, "#8a8e96")], "#6f737b", 0.25)
# 透明筆管：看得到裡面的墨管（墨色）。
ic.poly([(13, -3.9), (45, -3.9), (45, 3.9), (13, 3.9)], ic.across(29, 3.9,
        [(0, "#9aa0aa", 0.9), (0.3, "#eef1f5", 0.75), (0.5, "#ffffff", 0.7), (1, "#8b9099", 0.9)]), "#7d828b", 0.3)
ic.poly([(13, -1.15), (44, -1.15), (44, 1.15), (13, 1.15)], ic.across(28, 1.15, ink_cyl(-0.5, -0.05, 0.45)))
ic.poly([(13, -2.4), (44, -2.4), (44, -1.9), (13, -1.9)], "#ffffff", None, 0, 0.5)
ic.cyl(45, 49, 3.9, 3.9, ink_cyl())                           # 尾蓋（同色）
ic.cyl(49, 54, 1.7, 1.7, CHROME)                              # 按壓鈕
ic.poly([(38, 4.0), (52, 4.0), (52.6, 5.0), (38, 4.8)], ic.across(45, 5, CHROME), "#5b5f67", 0.2)   # 夾子
icons["ballpoint"] = ic

# ── 針筆 ──────────────────────────────────────────────
ic = Icon()
ic.cyl(0.5, 5, 0.5, 1.3, [(0, "#1a1b1e"), (0.4, "#5c6068"), (1, "#16171a")])      # 塑膠筆尖
ic.cyl(5, 9, 1.3, 2.5, [(0, "#2a2c30"), (0.4, "#8b9099"), (1, "#25272b")])
ic.cyl(9, 10.4, 2.7, 2.7, CHROME)
ic.cyl(10.4, 41, 2.7, 2.9, [(0, "#b9bec7"), (0.25, "#fbfcfd"), (0.5, "#ffffff"), (0.8, "#d4d8de"), (1, "#a4a9b3")], "#9aa0aa", 0.25)
ic.poly([(14, -2.9), (24, -2.9), (24, 2.9), (14, 2.9)], ic.across(19, 2.9, ink_cyl(-0.4, 0.05, 0.45)))
ic.line((26, -1.4), (38, -1.4), "#2b2e33", 0.55, 0.85)
ic.line((26, 0.2), (36, 0.2), "#2b2e33", 0.4, 0.7)
ic.cyl(41, 51, 2.95, 3.05, ink_cyl())                                              # 筆蓋
ic.cyl(40.6, 41.4, 3.1, 3.1, CHROME)
ic.poly([(42, 3.0), (52, 3.0), (52.5, 4.2), (42, 3.9)], ic.across(47, 4.2, CHROME), "#5b5f67", 0.2)   # 夾子
ic.curve_uv([("M", 51, -3.05), ("C", 53, -2.8, 53.5, -1.4, 53.5, 0), ("C", 53.5, 1.4, 53, 2.8, 51, 3.05), ("Z",)],
            ic.across(52, 3, ink_cyl()))
ic.shine(11, 40, -1.6, 0.6, 0.55)
icons["fineliner"] = ic

# ── 毛筆（狼毫）────────────────────────────────────────
ic = Icon()
hair = ic.along(0, 16, [(0, "ink", 1, -0.35), (0.5, "ink", 1, -0.1), (0.62, "#efe2c2"), (1, "#d9c79b")])
ic.curve_uv([("M", 0, 0), ("C", 2.5, -1.2, 6, -3.4, 10.5, -3.9), ("C", 13, -4.0, 14.8, -3.8, 16, -3.6),
             ("L", 16, 3.6), ("C", 14.8, 3.8, 13, 4.0, 10.5, 3.9), ("C", 6, 3.4, 2.5, 1.2, 0, 0), ("Z",)], hair, "#3a2c14", 0.25)
for v in (-2.4, -1.0, 0.4, 1.8, 2.8):
    ic.line((3.5 + abs(v), v * 0.55), (14.5, v), "#ffffff", 0.35, 0.28)
ic.cyl(16, 20.5, 3.75, 3.5, GOLD, "#6e4e12", 0.25)
ic.line((17, -3.4), (17, 3.4), "#6e4e12", 0.3, 0.5)
ic.line((19, -3.3), (19, 3.3), "#6e4e12", 0.3, 0.5)
ic.poly([(20.5, -3.4), (55, -2.3), (55, 2.3), (20.5, 3.4)], ic.across(38, 3.4, BAMBOO), "#6b4a14", 0.25)
for u in (30, 41, 51):                                                              # 竹節
    ic.line((u, -3.0 + (u - 20) * 0.02), (u, 3.0 - (u - 20) * 0.02), "#6b4a14", 0.55, 0.8)
    ic.line((u + 0.7, -3.0 + (u - 20) * 0.02), (u + 0.7, 3.0 - (u - 20) * 0.02), "#ffffff", 0.3, 0.35)
ic.shine(22, 54, -1.7, 0.6, 0.45)
icons["brush"] = ic

# ── 書法扁頭筆（寬尖沾水筆）────────────────────────────
ic = Icon()
nib = ic.across(7, 5.9, STEEL)
ic.curve_uv([("M", 0, -5.9), ("L", 9, -5.9), ("C", 11.5, -5.9, 13, -5, 14, -4.2), ("L", 14, 4.2),
             ("C", 13, 5, 11.5, 5.9, 9, 5.9), ("L", 0, 5.9), ("Z",)], nib, "#3a3d44", 0.3)
ic.line((0.8, 0), (12, 0), "#1c1d20", 0.45)
ic.dot_uv(11, 0, 0.9, "#1c1d20")
ic.poly([(0, -5.9), (1.6, -5.9), (1.6, 5.9), (0, 5.9)], "ink", None, 0, 0.95)              # 沾墨的切口
ic.line((1.8, -5.4), (9, -5.4), "#ffffff", 0.5, 0.55)
ic.cyl(14, 18, 4.3, 4.4, GOLD, "#6e4e12", 0.25)
ic.poly([(18, -4.4), (55, -3.7), (55, 3.7), (18, 4.4)], ic.across(36, 4.4, GLOSS_BLACK))
ic.cyl(34, 35.6, 4.2, 4.2, GOLD)
ic.cyl(52, 55, 3.9, 3.9, GOLD)
ic.shine(20, 51, -2.3, 0.8, 0.35)
icons["calligraphy"] = ic

# ── 鉛筆 ──────────────────────────────────────────────
ic = Icon()
ic.poly([(0, 0), (9.5, -4.6), (9.5, 4.6)], ic.across(5, 4.6, [(0, "#b98450"), (0.35, "#f2d6a6"), (0.55, "#fff0cf"), (1, "#a97740")]), "#8a5f32", 0.25)
ic.poly([(0, 0), (3.6, -1.75), (3.6, 1.75)], ic.across(2, 1.75, ink_cyl(-0.65, -0.35, 0.05)))    # 鉛筆芯
ic.line((3.3, -1.8), (9.2, -4.4), "#8a5f32", 0.3, 0.7)
# 六角柱：三個面，各自明暗。
ic.poly([(9.5, -4.6), (45, -4.6), (45, -1.55), (9.5, -1.55)], "#f9d04a", "#c9961a", 0.2)
ic.poly([(9.5, -1.55), (45, -1.55), (45, 1.55), (9.5, 1.55)], "#f2b01e", "#c9961a", 0.2)
ic.poly([(9.5, 1.55), (45, 1.55), (45, 4.6), (9.5, 4.6)], "#c98a0c", "#a06c08", 0.2)
ic.shine(11, 44, -3.1, 0.7, 0.45)
ic.cyl(45, 50, 4.8, 4.8, STEEL, "#3a3d44", 0.25)
for u in (46.2, 47.5, 48.8):
    ic.line((u, -4.6), (u, 4.6), "#3a3d44", 0.35, 0.6)
ic.curve_uv([("M", 50, -4.6), ("L", 53, -4.6), ("C", 54.3, -4.6, 54.8, -3, 54.8, 0), ("C", 54.8, 3, 54.3, 4.6, 53, 4.6),
             ("L", 50, 4.6), ("Z",)], ic.across(52, 4.6, PINK_ERASER), "#a84a5c", 0.25)
icons["pencil"] = ic

# ── 炭筆（壓縮炭條，半截包著紙）───────────────────────
ic = Icon()
coal = ic.across(18, 4.6, [(0, "#050505"), (0.3, "#2b2b2c"), (0.5, "#4a4a4c"), (0.8, "#171718"), (1, "#050505")])
ic.curve_uv([("M", 0.5, -1.2), ("L", 1.8, -3.0), ("L", 3.0, -2.6), ("L", 4.6, -4.2), ("L", 7, -4.4), ("L", 26, -4.7),
             ("L", 26, 4.7), ("L", 7, 4.5), ("L", 5, 4.2), ("L", 3.4, 3.2), ("L", 2.0, 3.6), ("L", 0.4, 1.4), ("Z",)], coal)
for (u, v, r) in ((2.6, -1.0, 0.45), (4.8, 1.8, 0.4), (6.5, -2.6, 0.5), (9, 0.8, 0.4), (12, -2, 0.35), (15, 2.4, 0.4)):
    ic.dot_uv(u, v, r, "#8a8a8c", 0.35)
ic.curve_uv([("M", 0.5, -1.2), ("L", 1.8, -3.0), ("L", 3.0, -2.6), ("L", 4.6, -4.2), ("L", 6, -4.3), ("L", 6, 4.4), ("L", 3.4, 3.2),
             ("L", 2.0, 3.6), ("L", 0.4, 1.4), ("Z",)], "ink", None, 0, 0.55)               # 沾上的炭粉（筆色）
for (u, v, r) in ((-0.8, 2.6, 0.5), (-1.6, 0.4, 0.4), (1.0, 5.4, 0.45), (-0.2, -2.8, 0.4)):
    ic.dot_uv(max(u, 0.1), v, r, "ink", 0.6)
# 包紙：螺旋撕開的邊。
paper = ic.across(40, 4.9, PAPER)
ic.curve_uv([("M", 24, -4.9), ("L", 38, -4.9), ("L", 40, -3.6), ("L", 38.5, -1.9), ("L", 41, 0.2), ("L", 39, 2.4), ("L", 41, 4.9),
             ("L", 55, 4.9), ("L", 55, -4.9), ("L", 41.5, -4.9), ("Z",)], paper, "#8c8470", 0.25)
ic.poly([(24, -4.9), (28.5, -4.9), (24, 4.9)], "#000000", None, 0, 0)  # (保留座標系用，不可見)
ic.curve_uv([("M", 24, -4.8), ("L", 41.5, -4.8), ("L", 38.5, -1.9), ("L", 41, 0.2), ("L", 39, 2.4), ("L", 41, 4.8), ("L", 24, 4.8), ("Z",)],
            ic.across(32, 4.8, PAPER), "#8c8470", 0.25)
ic.line((26, -2.4), (36, -2.4), "#6f6a5a", 0.35, 0.5)
ic.line((26, 2.2), (35, 2.2), "#6f6a5a", 0.35, 0.5)
icons["charcoal"] = ic

# ── 蠟筆 ──────────────────────────────────────────────
ic = Icon()
ic.curve_uv([("M", 0, 0), ("C", 0.5, -1.6, 2.5, -2.8, 4.5, -3.6), ("L", 10, -4.9), ("L", 10, 4.9), ("L", 4.5, 3.6),
             ("C", 2.5, 2.8, 0.5, 1.6, 0, 0), ("Z",)], ic.across(5, 4.9, ink_cyl(-0.3, 0.05, 0.4)), "#222", 0.15)
ic.line((3, -2.2), (9, -3.8), "#ffffff", 0.45, 0.4)
ic.poly([(10, -5.0), (47, -5.0), (47, 5.0), (10, 5.0)], ic.across(28, 5.0, ink_cyl(-0.55, -0.05, 0.35)), "#222", 0.15)   # 紙套（筆色）
ic.poly([(17, -5.0), (40, -5.0), (40, 5.0), (17, 5.0)], ic.across(28, 5.0,
        [(0, "ink", 1, 0.25), (0.3, "ink", 1, 0.62), (0.5, "ink", 1, 0.78), (1, "ink", 1, 0.2)]), None, 0, 0.95)   # 標籤（較淡的筆色）
ic.poly([(17, -5.0), (18, -5.0), (18, 5.0), (17, 5.0)], "ink", None, 0, 0.9)
ic.poly([(39, -5.0), (40, -5.0), (40, 5.0), (39, 5.0)], "ink", None, 0, 0.9)
for (u0, u1, v, op) in ((21, 36, -2.4, 0.95), (21, 32, -0.5, 0.85), (21, 35, 1.4, 0.85), (21, 28, 3.2, 0.75)):
    ic.line((u0, v), (u1, v), "#ffffff", 1.0, op)
ic.shine(11, 46, -4.1, 0.7, 0.3)
ic.cyl(47, 49, 4.9, 4.9, ink_cyl(-0.7, -0.3, 0.05))
icons["crayon"] = ic

# ── 噴槍（重力式雙動）──────────────────────────────────
ic = Icon()
ic.cyl(0.5, 5, 0.45, 1.5, STEEL, "#3a3d44", 0.2)                       # 噴嘴與針
ic.line((0, 0), (0.4, 0), "#9aa0aa", 0.3)
ic.cyl(5, 8, 1.5, 2.6, CHROME)
ic.cyl(8, 34, 2.7, 3.5, STEEL, "#3a3d44", 0.25)                        # 槍身
ic.line((8.5, -1.9), (33, -2.5), "#ffffff", 0.7, 0.55)
ic.cyl(14, 16, 3.0, 3.0, CHROME)
# 色杯：槍身上方，杯裡是顏料（筆色）。
ic.poly([(17, -3.2), (25, -3.2), (26.2, -8.6), (15.8, -8.6)], ic.lin(pt(15, -6), pt(27, -6), STEEL), "#3a3d44", 0.25)
ic.poly([(16.2, -8.6), (25.8, -8.6), (25.2, -7.0), (16.8, -7.0)], "ink", None, 0, 1)
ic.ellipse(*pt(21, -8.4), 3.2 * S, 1.0 * S, "ink", "#2b2e33", 0.3, 0.95)
# 扳機與握把。
ic.poly([(15, 3.4), (27, 3.4), (28, 5.0), (14, 5.0)], ic.lin(pt(15, 4), pt(28, 4.5), CHROME), "#3a3d44", 0.2)
ic.dot_uv(22, 6.2, 1.5, ic.rad(pt(21.6, 5.8), 2, [(0, "#ffffff"), (1, "#6a6f78")]), None)
ic.poly([(34, -3.4), (46, -3.0), (46, 3.0), (34, 3.4)], ic.across(40, 3.4, RUBBER))
for u in (36, 38, 40, 42, 44):
    ic.line((u, -3.2), (u, 3.2), "#000000", 0.35, 0.5)
ic.cyl(46, 50, 1.9, 1.9, CHROME)
ic.curve_uv([("M", 50, 0), ("C", 52, 0, 54, 2, 54, 5)], "none", "#2b2e33", 1.0, 0.95)
# 噴出的霧。
for (u, v, r, o) in ((-1.8, 0, 1.3, 0.8), (-3.6, -1.6, 0.9, 0.65), (-3.8, 1.8, 0.9, 0.65), (-5.6, 0.1, 0.7, 0.5),
                     (-5.0, -3.4, 0.55, 0.4), (-5.2, 3.5, 0.55, 0.4), (-7.0, -1.5, 0.45, 0.3), (-7.2, 1.7, 0.45, 0.3)):
    x, y = pt(max(u, -7), v)
    ic.dot(x, y, r, "ink", o)
icons["airbrush"] = ic

# ── 油畫筆（平頭）──────────────────────────────────────
ic = Icon()
ic.curve_uv([("M", 0.2, -4.4), ("C", 0, -5.2, 1.6, -5.7, 3, -5.8), ("L", 15, -6.2), ("L", 15, 6.2), ("L", 3, 5.8),
             ("C", 1.6, 5.7, 0, 5.2, 0.2, 4.4), ("Z",)], ic.across(8, 6.2, ink_cyl(-0.45, -0.05, 0.3)), "#222", 0.15)
for v in (-4.6, -3.0, -1.4, 0.2, 1.8, 3.4, 5.0):                                   # 鬃毛的紋路
    ic.line((1.2, v * 0.95), (15, v), "#000000" if int(v * 10) % 2 else "#ffffff", 0.35, 0.22)
ic.dot_uv(0.6, -1.2, 1.3, "ink", 0.9)                                                   # 沾上的顏料
ic.poly([(15, -6.3), (26, -5.2), (26, 5.2), (15, 6.3)], ic.across(20, 6.3, STEEL), "#3a3d44", 0.3)  # 鍍鎳鐵箍
for u in (17.5, 20, 22.5):
    ic.line((u, -6.0 + (u - 15) * 0.1), (u, 6.0 - (u - 15) * 0.1), "#3a3d44", 0.45, 0.65)
ic.poly([(26, -4.4), (56, -2.4), (56, 2.4), (26, 4.4)], ic.across(40, 4.4,
        [(0, "#3a0d0b"), (0.2, "#8e2a22"), (0.38, "#e0705f"), (0.5, "#9c2f26"), (1, "#2e0a08")]), "#2e0a08", 0.25)   # 紅漆長桿
ic.shine(28, 55, -2.2, 0.7, 0.5)
ic.cyl(52, 56, 2.5, 2.4, [(0, "#101010"), (0.4, "#4a4a4a"), (1, "#0a0a0a")])
icons["oilpaint"] = ic

# ── 水彩筆（圓頭）──────────────────────────────────────
ic = Icon()
ic.curve_uv([("M", 0, 0), ("C", 2, -1.6, 6, -3.4, 10.5, -3.8), ("C", 13, -3.9, 14.6, -3.7, 15.5, -3.4),
             ("L", 15.5, 3.4), ("C", 14.6, 3.7, 13, 3.9, 10.5, 3.8), ("C", 6, 3.4, 2, 1.6, 0, 0), ("Z",)],
            ic.across(8, 3.9, ink_cyl(-0.4, 0.0, 0.5)), "#222", 0.15)                       # 吸飽水的筆肚
ic.curve_uv([("M", 2.5, -1.2), ("C", 5, -2.6, 8, -3.0, 11, -3.0)], "none", "#ffffff", 0.6, 0.55)
ic.cyl(15.5, 21.5, 3.5, 3.0, STEEL, "#3a3d44", 0.25)
for u in (17, 19):
    ic.line((u, -3.3), (u, 3.3), "#3a3d44", 0.4, 0.6)
ic.poly([(21.5, -3.0), (55, -1.9), (55, 1.9), (21.5, 3.0)], ic.across(38, 3.0,
        [(0, "#17314c"), (0.2, "#2f6aa3"), (0.38, "#8cc3ee"), (0.5, "#3571ad"), (1, "#122a42")]), "#12263b", 0.25)   # 藍漆
ic.shine(23, 54, -1.5, 0.6, 0.5)
# 水滴。
ic.path("M 36,9 C 36,9 30.5,15.5 30.5,19.3 C 30.5,22.4 33,24.8 36,24.8 C 39,24.8 41.5,22.4 41.5,19.3 C 41.5,15.5 36,9 36,9 Z",
        ic.lin((31, 12), (41, 24), [(0, "ink", 0.85, 0.35), (1, "ink", 0.95, -0.3)]), "#ffffff", 0.4, 0.95)
ic.path("M 33.4,17.4 C 33.6,19.6 34.6,21.2 36,22", "none", "#ffffff", 0.7, 0.7, "round")
icons["watercolor"] = ic

# ── 麥克筆（雙頭尖）──────────────────────────────────
ic = Icon()
ic.curve_uv([("M", 0, -0.6), ("L", 1.2, -3.4), ("L", 6.5, -4.3), ("L", 6.5, 4.3), ("L", 1.2, 3.6), ("L", 0, 2.4), ("Z",)],
            ic.across(3.5, 4.3, ink_cyl(-0.35, 0.0, 0.3)), "#222", 0.15)                    # 斜切的氈尖
for (u, v) in ((2, -1.2), (3.6, 1.4), (4.8, -2.4), (5.4, 2.6)):
    ic.dot_uv(u, v, 0.28, "#000000", 0.25)
ic.cyl(6.5, 11, 4.4, 4.9, [(0, "#16171a"), (0.35, "#6a6e76"), (0.5, "#9a9ea6"), (1, "#101113")])
ic.cyl(11, 40, 5.0, 5.2, GLOSS_BLACK)
ic.poly([(14, -5.05), (28, -5.05), (28, 5.05), (14, 5.05)], ic.across(21, 5.05, ink_cyl(-0.4, 0.05, 0.45)))   # 彩色標籤
ic.line((16, -2.4), (26, -2.4), "#ffffff", 0.55, 0.85)
ic.line((16, -0.6), (24, -0.6), "#ffffff", 0.45, 0.7)
ic.line((16, 1.4), (25, 1.4), "#ffffff", 0.45, 0.6)
ic.shine(29, 39, -2.9, 0.8, 0.4)
ic.cyl(40, 52, 5.4, 5.5, ink_cyl(-0.45, -0.05, 0.4))                                         # 套在尾端的筆蓋
ic.cyl(39.6, 40.8, 5.6, 5.6, CHROME)
ic.poly([(42, 5.5), (53, 5.5), (53.6, 7.0), (42, 6.4)], ic.across(48, 6.5, CHROME), "#5b5f67", 0.2)   # 夾子
ic.curve_uv([("M", 52, -5.5), ("C", 54, -5.2, 54.6, -2.8, 54.6, 0), ("C", 54.6, 2.8, 54, 5.2, 52, 5.5), ("Z",)],
            ic.across(53, 5.5, ink_cyl(-0.5, -0.1, 0.3)))
icons["marker"] = ic

# ── 螢光筆（斜切寬頭）──────────────────────────────────
ic = Icon()
ic.curve_uv([("M", 0, -2.8), ("L", 2.2, -6.0), ("L", 9, -6.4), ("L", 9, 6.4), ("L", 2.2, 6.0), ("L", 0, 3.6), ("Z",)],
            ic.across(4.5, 6.4, [(0, "ink", 0.95, -0.15), (0.4, "ink", 0.8, 0.25), (1, "ink", 0.95, -0.25)]), "#222", 0.12)
for (u, v) in ((2.4, -3.8), (4, 2), (6, -1.2), (7.6, 4.6), (7.2, -5.2)):
    ic.dot_uv(u, v, 0.3, "#ffffff", 0.35)
ic.cyl(9, 12.5, 6.5, 6.8, [(0, "#d5d8dd"), (0.4, "#ffffff"), (1, "#aeb2ba")], "#9aa0aa", 0.2)
# 透明外殼，看得到裡面吸飽墨水的纖維棒。
ic.poly([(12.5, -6.9), (46, -6.9), (46, 6.9), (12.5, 6.9)], ic.across(29, 6.9,
        [(0, "ink", 0.55, -0.1), (0.3, "ink", 0.35, 0.5), (0.5, "#ffffff", 0.5), (1, "ink", 0.6, -0.2)]), "#8d939d", 0.25)
ic.poly([(14, -4.2), (44, -4.2), (44, 4.2), (14, 4.2)], ic.across(29, 4.2, ink_cyl(-0.3, 0.05, 0.4)), None, 0, 0.85)
ic.poly([(14, -6.1), (44, -6.1), (44, -5.2), (14, -5.2)], "#ffffff", None, 0, 0.5)
ic.cyl(44, 54, 7.0, 7.1, [(0, "ink", 1, -0.5), (0.35, "ink", 1, 0.0), (0.5, "ink", 1, 0.35), (1, "ink", 1, -0.55)])
for u in (46, 48, 50, 52):
    ic.line((u, -6.7), (u, 6.7), "#000000", 0.4, 0.22)
icons["highlighter"] = ic

# ── 橡皮擦（紙套的塊狀橡皮）────────────────────────────
ic = Icon()
# 以頁面座標直接畫：斜 -35°、略帶立體。
ang = math.radians(-32)
ca, sa = math.cos(ang), math.sin(ang)
def R(x, y, cx=24, cy=26):
    dx, dy = x - cx, y - cy
    return (cx + dx * ca - dy * sa, cy + dx * sa + dy * ca)
def box(x0, y0, x1, y1):
    return [R(x0, y0), R(x1, y0), R(x1, y1), R(x0, y1)]
ic.raw_poly([R(x, y + 3.2) for x, y in [(7, 14), (41, 14), (41, 34), (7, 34)]], "#7d3a4a", None, 0, 0.55)   # 底面厚度（陰影）
ic.raw_poly(box(7, 14, 41, 34), ic.lin(R(7, 14), R(7, 34), [(0, "#ffe3e8"), (0.5, "#ffc3cf"), (1, "#e48ba0")]), "#b8586c", 0.35)
ic.raw_poly(box(7, 14, 27, 34), ic.lin(R(7, 14), R(7, 34), [(0, "#3f6fb5"), (0.5, "#2c5aa0"), (1, "#1f4278")]), "#16305a", 0.3)   # 藍色紙套
ic.raw_poly(box(27, 14, 31.5, 34), "#ffffff", None, 0, 0.95)
ic.raw_poly(box(7, 14, 9.2, 34), "#ffffff", None, 0, 0.25)
for (y, w) in ((19, 12), (24, 9), (29, 11)):
    a0, a1 = R(11, y), R(11 + w, y)
    ic.raw_line(a0, a1, "#ffffff", 0.9, 0.9)
ic.raw_line(R(8, 15.2), R(40, 15.2), "#ffffff", 0.6, 0.45)
for (x, y, r) in ((43.4, 20, 0.6), (45, 26, 0.5), (43, 31, 0.55), (46.2, 22.6, 0.4)):   # 橡皮屑
    cx, cy = R(x, y)
    ic.dot(cx, cy, r, "#f5c0cb", 0.9)
icons["eraser"] = ic

# ── 套索（繩圈）────────────────────────────────────────
ic = Icon()
cx, cy, rx, ry = 24.0, 19.0, 15.5, 10.5
loop = "M {0},{1} C {0},{2} {3},{4} {5},{4} C {6},{4} {7},{2} {7},{1} C {7},{8} {6},{9} {5},{9} C {3},{9} {0},{8} {0},{1} Z".format(
    f(cx - rx), f(cy), f(cy - ry * 0.56), f(cx - rx * 0.56), f(cy - ry), f(cx), f(cx + rx * 0.56), f(cx + rx), f(cy + ry * 0.56), f(cy + ry))
rope = ic.lin((8, 8), (40, 30), [(0, "#6b4a22"), (0.35, "#c79a55"), (0.55, "#e8cc94"), (0.8, "#a67a3a"), (1, "#5a3c18")])
ic.path(loop, "none", "#3f2a10", 4.2, 0.9)
ic.path(loop, "none", rope, 3.0, 1.0)
# 繩的絞紋：沿圈每隔一段斜斜一刀。
for i in range(46):
    t = i / 46 * 2 * math.pi
    x, y = cx + rx * math.cos(t), cy + ry * math.sin(t)
    tx, ty = -rx * math.sin(t), ry * math.cos(t)
    m = math.hypot(tx, ty)
    tx, ty = tx / m, ty / m
    nx, ny = -ty, tx
    a0 = (x - tx * 0.5 + nx * 1.5, y - ty * 0.5 + ny * 1.5)
    a1 = (x + tx * 0.5 - nx * 1.5, y + ty * 0.5 - ny * 1.5)
    ic.raw_line(a0, a1, "#4a3214", 0.5, 0.55, "butt")
ic.raw_line((9, 16), (14, 11), "#ffffff", 0.5, 0.35)
# 活結（honda knot）與垂下的繩尾。
ic.path("M 21.5,28 C 21,26.6 22.4,25.6 24,25.6 C 25.8,25.6 27,26.8 26.6,28.4 C 26.4,29.6 25,30.4 23.6,30.2 C 22.4,30 21.7,29 21.5,28 Z",
        ic.rad((23.6, 27.6), 3.4, [(0, "#e8cc94"), (1, "#7a5524")]), "#3f2a10", 0.5)
ic.path("M 24,30 C 24,33 22,35 21,38 C 20,41 22,43 21,45", "none", "#3f2a10", 3.6, 0.9, "round")
ic.path("M 24,30 C 24,33 22,35 21,38 C 20,41 22,43 21,45", "none", rope, 2.4, 1.0, "round")
for (a, b) in (((20.2, 44.4), (19.2, 46.4)), ((21, 45), (21.4, 47)), ((21.8, 44.4), (23, 46.2))):
    ic.raw_line(a, b, "#c79a55", 0.5, 0.95)
icons["lasso"] = ic

# ── 遮蔽膠帶（捲）──────────────────────────────────────
ic = Icon()
ic.ellipse(26.2, 27, 17.5, 16.5, "#8d7a4a", None, 0, 0.45)                                   # 影子
ic.ellipse(25, 25, 17.5, 17.0, ic.lin((8, 8), (42, 42), [(0, "#b69a5c"), (0.5, "#8e7640"), (1, "#6b5628")]), "#5a4720", 0.3)   # 捲的側面
ic.ellipse(23.5, 23.5, 17.0, 17.0, ic.rad((17, 16), 26, [(0, "#fbf0cb"), (0.45, "#ecd9a0"), (1, "#c9b070")]), "#9a8548", 0.4)
for r in (14.8, 12.8, 10.8):
    ic.ellipse(23.5, 23.5, r, r, "none", "#b49b5a", 0.35, 0.8)
ic.ellipse(23.5, 23.5, 8.0, 8.0, ic.lin((16, 16), (31, 31), [(0, "#a98652"), (0.5, "#cfae78"), (1, "#8a6a38")]), "#6b5128", 0.4)   # 紙芯
ic.ellipse(23.5, 23.5, 6.2, 6.2, ic.lin((18, 18), (29, 29), [(0, "#3a2e18"), (1, "#8a7448")]), "#4b3b1e", 0.3)               # 中空
ic.path("M 12,12 C 15,8.5 20,6.8 25,7", "none", "#ffffff", 0.9, 0.55, "round")
# 撕開的膠帶尾巴。
ic.raw_poly([(37, 30), (46, 33), (45.2, 35), (46.6, 36.6), (44.8, 38), (45.6, 40), (38, 38), (35.5, 33)],
            ic.lin((36, 30), (46, 40), [(0, "#f6e8b4"), (1, "#dcc684")]), "#9a8548", 0.35)
ic.raw_line((38, 33.4), (44, 35.4), "#ffffff", 0.5, 0.5)
icons["maskingtape"] = ic

os.makedirs(OUT, exist_ok=True)
for name, ic in icons.items():
    with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as fh:
        fh.write(ic.svg())
print(f"已產生 {len(icons)} 個圖示到 assets/brushes/")
