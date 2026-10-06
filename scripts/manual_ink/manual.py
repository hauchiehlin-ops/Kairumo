"""《Kairumo手冊》的版面與插圖。

全部內容都是筆畫（手繪）：標題與內文是用 makemeahanzi 的標準筆順中線逐字手寫
（`hanzi.py`；資料與授權見 `third_party/makemeahanzi/`），插圖是一筆一筆畫的。這支腳本只輸出筆畫，
沒有任何文字方塊或形狀物件 —— 產物是 `assets/seed/kairumo-manual-ink.json`，
Apple 與 Android 各自讀它、用自己的筆刷畫進筆記本。

四頁：封面＋一、二、三、總結（每頁一個主題：標題、導語、三個要點、插圖、頁尾）。

用法：python3 scripts/manual_ink/manual.py   # 產生 JSON 與預覽圖
"""
import json
import math
import random
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import hanzi  # noqa: E402
import manual_text as T  # noqa: E402
from ink import Page, draw_latin, preview  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
W, H = 800, 1132

# 每個段落一個主色（+ 同色系的淺一階）。
NAVY = "#1A365D"
RED = "#E53E3E"
S1, S1L = "#2B6CB0", "#63B3ED"   # 一、結構化 —— 藍
S2, S2L = "#DD6B20", "#F6AD55"   # 二、視覺化 —— 橘
S3, S3L = "#2F855A", "#68D391"   # 三、多語言 —— 綠
S4, S4L = "#6B46C1", "#B794F4"   # 總結 —— 紫
GOLD = "#D69E2E"

rng = random.Random(5807)


# ---- 手繪筆觸：直線與曲線都帶一點抖動 ----------------------------------


def _wobble(points, amp=1.1):
    """在折線上加一點低頻的偏移，看起來像手畫的、不是尺畫的。"""
    out = []
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    for i, (x, y) in enumerate(points):
        t = i / max(1, len(points) - 1)
        dx = amp * math.sin(t * 7 + ph1) + 0.3 * amp * math.sin(t * 19 + ph2)
        dy = amp * math.cos(t * 6 + ph2) + 0.3 * amp * math.sin(t * 17 + ph1)
        out.append((x + dx, y + dy))
    return out


class Pen:
    def __init__(self, page, color, width=3.0):
        self.page, self.color, self.width = page, color, width

    def stroke(self, pts, smooth=True, w=None, color=None):
        from ink import polyline
        dense = polyline(list(pts), smooth=smooth, step=4.0)
        self.page.strokes.append({
            "color": color or self.color,
            "width": w or self.width,
            "points": [(round(x, 1), round(y, 1)) for x, y in _wobble(dense)],
        })

    def line(self, a, b, **kw):
        self.stroke([a, b], smooth=False, **kw)

    def poly(self, pts, close=False, **kw):
        pts = list(pts) + ([pts[0]] if close else [])
        self.stroke(pts, smooth=False, **kw)

    def rect(self, x0, y0, x1, y1, r=0, **kw):
        if r <= 0:
            self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], close=True, **kw)
            return
        pts = []
        for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
            for k in range(7):
                a = math.radians(a0 + 90 * k / 6)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        self.stroke(pts + [pts[0]], smooth=False, **kw)

    def ellipse(self, cx, cy, rx, ry, a0=0, a1=360, **kw):
        n = max(10, int(abs(a1 - a0) / 12))
        pts = [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
                cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
        self.stroke(pts, smooth=True, **kw)

    def dot(self, x, y, r=3, **kw):
        self.ellipse(x, y, r, r, w=(kw.get("w") or self.width) * 1.6, **{k: v for k, v in kw.items() if k != "w"})

    def wavy(self, x0, y, x1, amp=2.5, period=26, **kw):
        n = max(2, int((x1 - x0) / 6))
        self.stroke([(x0 + (x1 - x0) * i / n, y + amp * math.sin(i * 6 / period * 2 * math.pi / 2)) for i in range(n + 1)], **kw)

    def text_lines(self, x, y, widths, gap=16, **kw):
        """一排排的波浪線，表示「這裡有字」（內文不寫，只示意版面）。"""
        for i, w in enumerate(widths):
            self.wavy(x, y + i * gap, x + w, amp=1.6, period=20, **kw)

    def star(self, cx, cy, r, **kw):
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = r if i % 2 == 0 else r * 0.42
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        self.poly(pts, close=True, **kw)

    def check(self, x, y, s, **kw):
        self.stroke([(x, y + s * 0.5), (x + s * 0.35, y + s * 0.85), (x + s, y)], smooth=False, **kw)

    def arrow(self, a, b, head=11, **kw):
        self.line(a, b, **kw)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        for d in (2.5, -2.5):
            self.line(b, (b[0] - head * math.cos(ang + d / 6 * 2.2 - 0.0 * d), b[1] - head * math.sin(ang + d / 6 * 2.2)), **kw)

    def hatch(self, x0, y0, x1, y1, gap=9, **kw):
        """斜線填色（用細斜線排出來，手繪的上色）。"""
        k = x0 - (y1 - y0)
        while k < x1:
            ax, ay = k, y1
            bx, by = k + (y1 - y0), y0
            # 裁到矩形內
            if ax < x0:
                ay -= (x0 - ax)
                ax = x0
            if bx > x1:
                by += (bx - x1)
                bx = x1
            if ay > by and ax < bx:
                self.line((ax, ay), (bx, by), **kw)
            k += gap


# ---- 版面 ----------------------------------------------------------------



INK = "#2D3748"          # 內文墨色
INK_W = 2.3
SOFT = "#718096"


def new_page():
    pg = Page(W, H)
    pg.boxes = []   # 排版模式：這一頁的文字方塊
    return pg


# ---- 排版模式（非繁中語言）-----------------------------------------------
#
# `TY` 是目前語言的文字（manual_text.TYPED[lang]）；為 None 就是原本的手寫模式。
# 排版模式下所有「手寫的字」改成記錄一個文字方塊，位置與繁中版的手寫字一一對應，所以
# 插圖與留白完全一樣、只要存一份。
TY = None


def _weight(ch):
    """估算一個字相對於字級的寬度（只用來估行數與縮字級，不要求精準）。"""
    o = ord(ch)
    if ch == " ":
        return 0.30
    if 0x0E31 <= o <= 0x0E3A or 0x0E47 <= o <= 0x0E4E:   # 泰文上下標記：不佔寬
        return 0.0
    if 0x0E00 <= o <= 0x0E7F:
        return 0.52
    if o >= 0x2E80 or 0xAC00 <= o <= 0xD7A3 or 0xFF00 <= o <= 0xFFEF:
        return 1.0
    return 0.70 if ch.isupper() else 0.56


def est_width(text, font):
    return sum(_weight(c) for c in text) * font


def est_lines(text, font, width):
    return max(1, -(-int(est_width(text, font) * 1.08) // int(width)))


def box(page, text, x, y, w, size, color, h=None, bold=False, align="left", min_size=11, max_h=None):
    """記錄一個文字方塊；放不下就縮字級（最小 `min_size`）。回傳實際高度。"""
    f = float(size)
    if max_h is not None:
        while f > min_size and est_lines(text, f, w) * f * 1.5 > max_h:
            f -= 0.5
    lines = est_lines(text, f, w)
    height = h if h is not None else lines * f * 1.5 + 4
    page.boxes.append({"text": text, "x": round(x, 1), "y": round(y, 1), "w": round(w, 1),
                       "h": round(height, 1), "size": round(f, 1), "color": color,
                       "bold": bold, "align": align})
    return height


def merge(dst, src, dx=0.0, dy=0.0, s=1.0):
    """把 src 的筆畫平移＋縮放後併進 dst。插圖用原本的座標畫，再搬到這一頁要放的位置。"""
    for st in src.strokes:
        dst.strokes.append({
            "color": st["color"], "width": round(st["width"] * (0.5 + 0.5 * s), 2),
            "points": [(round(x * s + dx, 1), round(y * s + dy, 1)) for x, y in st["points"]],
        })


# ---- 版面元件 ------------------------------------------------------------


def heading(page, text, x, y, size, color, width=3.5, key=None):
    """段落標題：標準筆順手寫，字距略寬。排版模式改成粗體文字方塊。"""
    if TY is not None:
        t = TY["headings"][key]
        f = size * 0.80
        while f > 14 and est_width(t, f) * 1.05 > 744 - x:
            f -= 0.5
        box(page, t, x, y + size * 0.08, 744 - x, f, color, bold=True)
        return
    hanzi.write_line(page, text, x, y, size, color, width, gap=0.10, hand=0.7)


def double_rule(page, y, color, x0=56, x1=744):
    """經典的雙線：一條粗短的重點線壓在一條細長線上。"""
    pen = Pen(page, color, 2.0)
    pen.line((x0, y), (x1, y), w=1.6, color=color)
    pen.line((x0, y + 7), (x0 + 150, y + 7), w=4.2, color=GOLD)
    pen.line((x0 + 158, y + 7), (x0 + 176, y + 7), w=4.2, color=GOLD)


def diamond(page, cx, cy, r, color):
    pen = Pen(page, color, 2.4)
    pen.poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], close=True, w=2.4)
    pen.dot(cx, cy, 1.4, w=1.6)


def section_text(page, key, color, y, lead_size=31, size=25, pitch=39, gap_after=16, with_marks=True):
    """導語＋三個要點。回傳下一個可用的 y。"""
    sec = T.SECTIONS[key]
    ty = TY["sections"][key] if TY is not None else None
    x_text = 90
    if ty is not None:
        box(page, ty["lead"], 56, y + 2, 688, lead_size * 0.84, color, bold=True, max_h=lead_size + 14)
    else:
        hanzi.write_line(page, sec["lead"], 56, y, lead_size, color, 2.9, gap=0.10, hand=0.8)
    y += lead_size + 22
    max_chars = int((744 - x_text) / (size * 1.10))
    for i, point in enumerate(sec["points"]):
        lines = hanzi.wrap(point, max_chars)
        y0 = y
        if with_marks:
            diamond(page, 68, y + size * 0.55, 6, color)
        for ln in lines:
            if ty is None:
                hanzi.write_line(page, ln, x_text, y, size, INK, INK_W, gap=0.10, hand=1.0)
            y += pitch
        if ty is not None:
            # 這個要點在繁中版佔 (y - y0) 高；排版文字縮到放得進去。
            box(page, ty["points"][i], x_text, y0 + 1, 744 - x_text, size * 0.84, INK,
                max_h=max(pitch, y - y0 - 2))
        y += gap_after
    return y


def footer(page, index):
    pen = Pen(page, SOFT, 1.6)
    pen.line((56, 1070), (744, 1070), w=1.4, color=SOFT)
    draw_latin(page, "Kairumo", 56, 1084, 20, SOFT, 1.8, gap=6)
    if TY is not None:
        box(page, TY["footer"][index], 544, 1080, 200, 15, SOFT, align="right")
        return
    label = T.FOOTER_PAGE[index]
    w = hanzi.line_width(label, 20, 0.2)
    hanzi.write_line(page, label, 744 - w, 1084, 20, SOFT, 1.8, gap=0.2, hand=0.5)


def seal(page, cx, cy, text, size=74):
    """朱紅印章：方框＋上下兩個字，微微歪一點。"""
    pen = Pen(page, RED, 3.0)
    half = size / 2
    pen.rect(cx - half, cy - half, cx + half, cy + half, r=5, w=3.4)
    pen.rect(cx - half + 5, cy - half + 5, cx + half - 5, cy + half - 5, r=3, w=1.4)
    cs = size * 0.40
    if TY is not None:
        t = TY["sections"]["s4"]["seal"]
        f = 17.0
        while f > 9 and est_width(t, f) > size - 14:
            f -= 0.5
        box(page, t, cx - half + 2, cy - f * 0.8, size - 4, f, RED, bold=True, align="center")
        return
    for i, ch in enumerate(text[:2]):
        hanzi.write_char(page, ch, cx - cs / 2, cy - half + 8 + i * (cs + 2), cs, RED, 2.8, hand=0.6)


# ---- 插圖（用原本的座標畫在暫存頁，再搬到各頁） ---------------------------


def art1(p):
    s = Pen(p, S1, 3.0)
    # 左：文件頁（標題層級、段落、有序步驟）
    s.rect(70, 318, 380, 640, r=12)
    s.poly([(330, 318), (380, 368), (330, 368)], close=True, w=2.6)           # 摺角
    s.stroke([(96, 350), (120, 344), (230, 348), (250, 344)], w=7)           # H1
    s.line((96, 372), (205, 372), w=3.6, color=S1L)                          # 底線
    s.stroke([(96, 404), (112, 402), (185, 405)], w=5, color=S1L)            # H2
    s.text_lines(96, 428, [250, 220, 240], gap=17, w=2.2)
    s.stroke([(96, 492), (112, 490), (170, 493)], w=5, color=S1L)            # H2
    for i in range(3):                                                       # ol.steps：1 2 3
        yy = 522 + i * 34
        s.ellipse(106, yy, 10, 10, w=2.6)
        if i == 0:
            s.line((106, yy - 5), (106, yy + 5), w=2.6)
        elif i == 1:
            s.stroke([(100, yy - 4), (106, yy - 6), (111, yy - 2), (100, yy + 6), (112, yy + 6)], smooth=False, w=2.2)
        else:
            s.stroke([(100, yy - 5), (111, yy - 5), (106, yy), (111, yy + 4), (100, yy + 6)], smooth=False, w=2.2)
        s.wavy(132, yy, 132 + 170 - i * 18, amp=1.5, w=2.2)
    # 右：目錄（IntersectionObserver：目前讀到哪裡就亮起來）
    s.rect(430, 318, 740, 640, r=12)
    s.stroke([(458, 352), (470, 346), (560, 350)], w=6)
    s.line((458, 372), (700, 372), w=2.4, color=S1L)
    items = [(410, 150), (452, 182), (494, 130), (536, 168), (578, 142)]
    for i, (yy, wd) in enumerate(items):
        yy += 0
        s.ellipse(470, yy + 10, 5, 5, w=3)
        s.wavy(488, yy + 10, 488 + wd, amp=1.4, w=2.4)
    s.hatch(448, 444, 716, 484, gap=8, w=1.8, color=S1L)                      # 目前這一節亮起
    s.rect(448, 444, 716, 484, r=8, w=3)
    s.arrow((730, 520), (722, 470), w=3)
    s.stroke([(690, 600), (690, 560)], w=3.5)                                 # 捲動位置標
    s.rect(682, 560, 698, 592, r=6, w=3)
    # 連結：目錄 → 文件的錨點 ID
    s.stroke([(446, 464), (418, 480), (400, 420), (384, 408)], w=2.8, color=S1L)
    s.arrow((392, 410), (382, 408), w=2.8, color=S1L)
    s.stroke([(404, 590), (414, 612)], w=2.4, color=S1L)
    # 井號 ID
    s.line((402, 548), (398, 580), w=3.2)
    s.line((416, 548), (412, 580), w=3.2)
    s.line((394, 558), (424, 556), w=3.2)
    s.line((392, 572), (422, 570), w=3.2)


def art2(p):
    o = Pen(p, S2, 3.0)
    # 眼睛
    o.stroke([(70, 830), (150, 770), (250, 770), (330, 830), (250, 890), (150, 890), (70, 830)], w=3.4)
    o.ellipse(200, 830, 44, 44, w=3.2)
    o.ellipse(200, 830, 19, 19, w=3.2)
    o.hatch(181, 811, 219, 849, gap=5, w=2, color=S2L)
    o.ellipse(186, 818, 7, 7, w=2.4, color=S2L)
    for a in (-70, -50, -30, -110, -130):                                     # 睫毛
        r = math.radians(a)
        o.line((200 + 118 * math.cos(r), 830 + 66 * math.sin(r)), (200 + 148 * math.cos(r), 830 + 94 * math.sin(r)), w=2.8)
    # 圖與圖說
    o.rect(380, 760, 730, 940, r=10)
    o.ellipse(470, 820, 24, 24, w=3.2, color=S2L)
    for k in range(10):
        r = math.radians(k * 36)
        o.line((470 + 32 * math.cos(r), 820 + 32 * math.sin(r)), (470 + 44 * math.cos(r), 820 + 44 * math.sin(r)), w=2.6, color=S2L)
    o.stroke([(380, 940), (470, 868), (540, 910), (610, 836), (730, 940)], smooth=False, w=3.4)
    o.stroke([(540, 910), (570, 890), (600, 916)], smooth=False, w=2.6)
    o.wavy(440, 968, 670, amp=1.8, w=2.6)                                       # figcaption
    o.line((455, 988), (655, 988), w=1.4, color=S2L)
    # 調色盤
    o.stroke([(90, 1010), (82, 960), (140, 930), (230, 940), (270, 985), (240, 1040), (190, 1030), (180, 1000), (140, 1000), (110, 1040), (90, 1010)], w=3.2)
    for (cx, cy, c) in ((130, 962, RED), (172, 950, S1), (214, 962, S3), (240, 992, GOLD)):
        o.ellipse(cx, cy, 11, 11, w=3, color=c)
    o.ellipse(170, 1000, 8, 8, w=2.6)                                           # 拇指孔
    # 圓角卡片式的按鈕（chips）
    for i, (x0, x1) in enumerate(((330, 440), (456, 566), (582, 692))):
        o.rect(x0, 1030, x1, 1076, r=22, w=3.2, color=S2 if i != 1 else S2L)
        o.wavy(x0 + 22, 1053, x1 - 22, amp=1.2, w=2.2)
    # 提示區塊（燈泡）
    o.stroke([(330, 1014), (320, 1000), (318, 984), (334, 964), (354, 964), (370, 984), (368, 1000), (358, 1014)], w=3.2)
    o.line((334, 1022), (354, 1022), w=3)
    o.line((338, 1030), (350, 1030), w=3)
    for a in (-90, -50, -130):
        r = math.radians(a)
        o.line((344 + 38 * math.cos(r), 982 + 38 * math.sin(r)), (344 + 52 * math.cos(r), 982 + 52 * math.sin(r)), w=2.6, color=S2L)


def art3(p):
    g = Pen(p, S3, 3.0)
    cx, cy = 250, 340
    g.ellipse(cx, cy, 120, 120, w=3.4)
    g.ellipse(cx, cy, 52, 120, w=2.6)
    g.ellipse(cx, cy, 100, 120, a0=90, a1=270, w=0.1) if False else None
    g.line((cx, cy - 120), (cx, cy + 120), w=2.4)
    for dy, rx in ((-60, 104), (0, 120), (60, 104)):
        g.stroke([(cx - rx, cy + dy), (cx, cy + dy + 10), (cx + rx, cy + dy)], w=2.6, color=S3L)
    # 陸地（手繪的幾塊）
    g.stroke([(cx - 70, cy - 40), (cx - 40, cy - 70), (cx - 10, cy - 50), (cx - 30, cy - 20), (cx - 60, cy - 10), (cx - 70, cy - 40)], w=2.6)
    g.stroke([(cx + 20, cy + 10), (cx + 60, cy), (cx + 70, cy + 40), (cx + 40, cy + 80), (cx + 24, cy + 40), (cx + 20, cy + 10)], w=2.6)
    # 對話框
    def bubble(x, y, w_, h_, tail_left=True, c=S3):
        g.rect(x, y, x + w_, y + h_, r=14, w=3, color=c)
        tx = x + 22 if tail_left else x + w_ - 22
        g.stroke([(tx, y + h_), (tx + (-10 if tail_left else 10), y + h_ + 16), (tx + 14 * (1 if tail_left else -1), y + h_)], smooth=False, w=3, color=c)
    bubble(400, 190, 120, 70)
    bubble(560, 150, 130, 70, False)
    bubble(420, 330, 130, 70)
    bubble(590, 300, 120, 70, False)
    bubble(480, 450, 140, 66)
    # 氣泡裡的「字」：A、文，其餘用波浪示意不同文字
    g.stroke([(436, 244), (458, 200), (480, 244)], smooth=False, w=3.6)
    g.line((444, 228), (472, 228), w=3.2)
    for (x, y, w_) in ((580, 172, 90), (586, 198, 70)):
        g.wavy(x, y, x + w_, amp=2, period=14, w=2.6)
    for (x, y, w_) in ((440, 352, 80), (446, 376, 60), (616, 322, 70), (610, 346, 56), (506, 470, 90), (514, 494, 66)):
        g.wavy(x, y, x + w_, amp=2.2, period=12, w=2.6)
    # 「文」
    # 下拉選單（langbar）
    g.rect(90, 500, 500, 540, r=10, w=3, color=S3L) if False else None
    g.rect(80, 560, 320, 604, r=10, w=3.2)
    g.wavy(100, 632, 230, amp=1.6, w=2.6)
    g.stroke([(274, 576), (288, 590), (302, 576)], smooth=False, w=3.2)
    g.rect(80, 610, 320, 800, r=10, w=3.2)
    for i in range(6):
        yy = 636 + i * 28
        g.wavy(104, yy, 104 + 100 + (i % 3) * 20, amp=1.4, w=2.4)
        if i == 0:
            g.check(278, yy - 8, 18, w=3.2)
    g.hatch(86, 618, 314, 650, gap=8, w=1.8, color=S3L)
    # 國旗般的小旗子 / 地標釘
    g.stroke([(470, 550), (470, 730)], w=3.4)
    g.stroke([(470, 554), (560, 574), (470, 600)], smooth=False, w=3.2)
    g.hatch(474, 560, 548, 594, gap=8, w=1.8, color=S3L)
    g.stroke([(620, 650), (600, 690), (640, 690), (620, 650)], smooth=False, w=3.0)
    g.ellipse(620, 650, 20, 20, a0=-200, a1=20, w=3.2)
    g.dot(620, 650, 5, w=2)
    g.stroke([(560, 750), (680, 750)], w=3.0, color=S3L)
    g.ellipse(620, 750, 60, 12, w=2.6, color=S3L)



def art4(p):
    """獎盃與彩紙（原座標：獎盃中心 x=520）。"""
    t = Pen(p, S4, 3.2)
    # 獎盃
    tx = 520
    t.stroke([(tx - 70, 930), (tx - 60, 1030), (tx - 20, 1068), (tx + 20, 1068), (tx + 60, 1030), (tx + 70, 930)], w=3.6)
    t.line((tx - 70, 930), (tx + 70, 930), w=3.6)
    t.stroke([(tx - 70, 950), (tx - 108, 948), (tx - 110, 990), (tx - 62, 1004)], w=3.2)
    t.stroke([(tx + 70, 950), (tx + 108, 948), (tx + 110, 990), (tx + 62, 1004)], w=3.2)
    t.line((tx, 1068), (tx, 1096), w=3.4)
    t.rect(tx - 50, 1096, tx + 50, 1116, r=5, w=3.4)
    t.hatch(tx - 56, 936, tx + 56, 1000, gap=11, w=1.8, color=S4L)
    t.star(tx, 985, 30, w=3.4)
    # 彩帶與彩紙
    for (x, y, k) in ((640, 910, 0), (700, 960, 1), (730, 1030, 2), (410, 920, 3), (690, 1090, 0), (420, 1060, 1), (350, 1000, 2)):
        if k == 0:
            t.line((x, y), (x + 16, y - 14), w=3, color=[RED, S2, S3, S1][(x // 7) % 4])
        elif k == 1:
            t.ellipse(x, y, 6, 6, w=3, color=[S2L, S3L, S1L][(x // 9) % 3])
        elif k == 2:
            t.poly([(x, y), (x + 12, y + 4), (x + 4, y + 14)], close=True, w=2.8, color=S4L)
        else:
            t.star(x, y, 9, w=2.8, color=GOLD)


# ---- 四頁 ----------------------------------------------------------------


def cover():
    p = new_page()
    # 標題：Kairumo 優勢
    end = draw_latin(p, "Kairumo", 44, 52, 92, NAVY, 5.2, gap=9)
    if TY is not None:
        f = 62.0
        while f > 24 and est_width(TY["title"], f) * 1.05 > 748 - (end + 22):
            f -= 1
        box(p, TY["title"], end + 22, 52 + (92 - f * 1.3) / 2 + 4, 748 - (end + 22), f, RED, bold=True)
    else:
        hanzi.write_line(p, T.TITLE_CJK, end + 22, 56, 88, RED, 5.6, gap=0.04, hand=0.5)
    pen = Pen(p, GOLD, 4)
    pen.wavy(48, 172, 740, amp=4, period=34)
    pen.star(760, 70, 20, w=3.2)
    pen.star(716, 138, 11, w=3, color=S2)
    pen.star(60, 30, 10, w=3, color=S1)
    pen.ellipse(700, 40, 6, 6, w=3, color=S3)
    if TY is not None:
        box(p, TY["subtitle"], 56, 192, 688, 22, SOFT, max_h=60)
    else:
        hanzi.write_line(p, T.SUBTITLE, 56, 190, 26, SOFT, 2.4, gap=0.12, hand=0.8)
    # 一、
    heading(p, T.HEADINGS["s1"], 56, 262, 46, S1, key="s1")
    double_rule(p, 322, S1L)
    y = section_text(p, "s1", S1, 346)
    q = new_page()
    art1(q)
    merge(p, q, dx=0, dy=max(y + 20, 690) - 318)
    footer(p, 0)
    return p


def page_s2():
    p = new_page()
    heading(p, T.HEADINGS["s2"], 56, 56, 46, S2, key="s2")
    double_rule(p, 116, S2L)
    y = section_text(p, "s2", S2, 140)
    q = new_page()
    art2(q)
    # 插圖放大一點，並置中在「要點下緣」到「頁尾線」之間（原圖 x 70..730、y 760..1076）。
    sc = 1.08
    top, bottom = y + 20, 1050
    merge(p, q, dx=(W - 660 * sc) / 2 - 70 * sc, dy=(top + bottom) / 2 - 318 * sc / 2 - 760 * sc, s=sc)
    footer(p, 1)
    return p


def page_s3():
    p = new_page()
    heading(p, T.HEADINGS["s3"], 56, 56, 46, S3, key="s3")
    double_rule(p, 116, S3L)
    y = section_text(p, "s3", S3, 140)
    q = new_page()
    art3(q)
    s = min(0.85, (1060 - (y + 10)) / 640)
    merge(p, q, dx=(W - 640 * s) / 2 - 80 * s, dy=y + 10 - 150 * s, s=s)
    footer(p, 2)
    return p


def page_summary():
    p = new_page()
    heading(p, T.HEADINGS["s4"], 56, 56, 52, S4, key="s4")
    double_rule(p, 120, S4L)
    sec = T.SECTIONS["s4"]
    if TY is not None:
        box(p, TY["sections"]["s4"]["lead"], 56, 148, 688, 23, S4, bold=True, max_h=70)
    else:
        hanzi.write_line(p, sec["lead"], 56, 146, 31, S4, 2.9, gap=0.10, hand=0.8)
    # 三個勾：每列一個圓角框＋勾＋手寫的一句
    pen = Pen(p, S4L, 3)
    y = 232
    for i, line in enumerate(sec["points"]):
        pen.rect(56, y - 14, 744, y + 58, r=24, w=3, color=S4L)
        pen.check(84, y + 8, 30, w=4.4, color=S4)
        if TY is not None:
            box(p, TY["sections"]["s4"]["points"][i], 134, y - 6, 590, 23, INK, max_h=64)
        else:
            hanzi.write_line(p, line, 134, y + 4, 28, INK, 2.5, gap=0.10, hand=1.0)
        y += 100
    # 獎盃
    q = new_page()
    art4(q)
    merge(p, q, dx=-120, dy=-300)
    # 結語與印章
    if TY is not None:
        box(p, TY["sections"]["s4"]["closing"], 56, 868, 688, 25, NAVY, bold=True, max_h=80)
    else:
        cx = hanzi.write_line(p, "讓每個人，都能輕鬆上手", 56, 872, 32, NAVY, 2.8, gap=0.10, hand=0.8)
        cx = draw_latin(p, "Kairumo", cx + 10, 876, 34, RED, 3.0, gap=6)
        hanzi.write_line(p, "。", cx - 2, 872, 32, NAVY, 2.8, hand=0.8)
    seal(p, 676, 975, sec["seal"])
    footer(p, 3)
    return p


def _strokes_json(pages):
    return [[{"color": s["color"], "width": s["width"], "points": [[x, y] for x, y in s["points"]]}
             for s in pg.strokes] for pg in pages]


def build_typed():
    """非繁中語言：同一套手繪插圖＋各語言的文字方塊 → `assets/seed/kairumo-manual-typed.json`。

    每個語言各跑一次版面；插圖的筆畫在各語言之間必須逐點相同（位置都對應繁中版），不同就是
    版面程式出了錯，所以直接斷言。
    """
    global TY
    illustration = None
    texts = {}
    for lang, data in T.TYPED.items():
        TY = data
        random.seed(5807)
        rng.seed(5807)
        pages = [cover(), page_s2(), page_s3(), page_summary()]
        strokes = _strokes_json(pages)
        if illustration is None:
            illustration = strokes
        elif illustration != strokes:
            raise SystemExit(f"{lang} 的插圖筆畫與其他語言不同：版面不應該隨語言改變")
        texts[lang] = [pg.boxes for pg in pages]
    TY = None
    out = ROOT / "assets/seed/kairumo-manual-typed.json"
    out.write_text(json.dumps({
        "version": 1, "page": {"width": W, "height": H},
        "pages": [{"strokes": st} for st in illustration],
        "texts": texts,
    }, ensure_ascii=False, separators=(",", ":")))
    (ROOT / "apple/Resources/Templates/kairumo-manual-typed.json").write_text(out.read_text())
    print(f"{out.relative_to(ROOT)}  {len(T.TYPED)} 種語言 / {out.stat().st_size // 1024} KB")


def build():
    random.seed(5807)
    rng.seed(5807)
    pages = [cover(), page_s2(), page_s3(), page_summary()]
    data = {
        "version": 1,
        "title": "Kairumo手冊",
        "page": {"width": W, "height": H},
        "pages": [{"strokes": [
            {"color": s["color"], "width": s["width"], "points": [[x, y] for x, y in s["points"]]}
            for s in pg.strokes]} for pg in pages],
    }
    out = ROOT / "assets/seed/kairumo-manual-ink.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    # Apple 端從 app bundle 讀（`Resources/Templates` 是資料夾參照，不必動專案檔）；
    # Android 由 gradle 從 assets/seed 複製。**只改 assets/seed 那份，其餘由這支腳本寫。**
    apple = ROOT / "apple/Resources/Templates/kairumo-manual-ink.json"
    apple.write_text(out.read_text())
    # 筆順資料的授權（Arphic Public License）要隨成品一起散布：全文未改動 + 修改聲明。
    # 兩個平台的 App 都把它們一起打包（Android 由 gradle 複製 assets/seed，Apple 讀 Templates）。
    src = ROOT / "third_party/makemeahanzi"
    for name in ("ARPHICPL.TXT", "NOTICE.txt"):
        for dest in (out.parent, apple.parent):
            shutil.copyfile(src / name, dest / name)
    # 匯出 PDF 時嵌入的泰文字型（Noto Sans Thai，SIL OFL）：授權全文同樣隨 App 散布。
    for dest in (out.parent, apple.parent):
        shutil.copyfile(ROOT / "third_party/notosansthai/OFL.txt", dest / "OFL-NotoSansThai.txt")   # 逐位元組複製：授權全文不能被改動（連換行都不行）
    total = sum(len(pg.strokes) for pg in pages)
    pts = sum(len(s["points"]) for pg in pages for s in pg.strokes)
    print(f"{out.relative_to(ROOT)}  {len(pages)} 頁 / {total} 筆 / {pts} 點 / {out.stat().st_size // 1024} KB")
    preview(pages, "/private/tmp/claude-501/manual{0}.png", scale=0.9)
    return pages


if __name__ == "__main__":
    build()
    build_typed()
