"""《Kairumo手冊》的版面與插圖。

全部內容都是筆畫（手繪）：標題是逐字手寫、插圖是一筆一筆畫的。這支腳本只輸出筆畫，
沒有任何文字方塊或形狀物件 —— 產物是 `assets/seed/kairumo-manual-ink.json`，
Apple 與 Android 各自讀它、用自己的筆刷畫進筆記本。

用法：python3 scripts/manual_ink/manual.py   # 產生 JSON 與預覽圖
"""
import json
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from ink import Page, draw_cjk, draw_latin, preview  # noqa: E402

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


def heading(page, text, x, y, size, color, width=4.0):
    draw_cjk(page, text, x, y, size - 2, color, width, gap=0.09)


def page1():
    p = Page(W, H)
    # 標題：Kairumo 優勢
    end = draw_latin(p, "Kairumo", 44, 52, 92, NAVY, 5.2, gap=9)
    draw_cjk(p, "優勢", end + 22, 56, 88, RED, 5.0, gap=0.04)
    pen = Pen(p, GOLD, 4)
    pen.wavy(48, 172, 740, amp=4, period=34)
    pen.star(760, 70, 20, w=3.2)
    pen.star(716, 138, 11, w=3, color=S2)
    pen.star(60, 30, 10, w=3, color=S1)
    pen.ellipse(700, 40, 6, 6, w=3, color=S3)

    # ---- 一、結構化的資訊呈現 ----
    heading(p, "一、結構化的資訊呈現", 44, 214, 54, S1)
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

    # ---- 二、視覺化的直觀設計 ----
    heading(p, "二、視覺化的直觀設計", 44, 690, 54, S2)
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
    return p


def page2():
    p = Page(W, H)
    # ---- 三、多語言的友善支援 ----
    heading(p, "三、多語言的友善支援", 44, 56, 54, S3)
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

    # ---- 總結 ----
    heading(p, "總結", 44, 836, 56, S4)
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
    # 三個勾（結構、視覺、語言）
    for i, yy in enumerate((950, 1010, 1070)):
        t.rect(80, yy - 24, 300, yy + 24, r=22, w=3, color=S4L)
        t.check(100, yy - 12, 26, w=4)
        t.wavy(144, yy, 144 + 120 - i * 12, amp=1.6, w=2.6)
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
    t.wavy(60, 1118, 330, amp=3, period=30, w=3.2, color=S4L)
    return p


def build():
    pages = [page1(), page2()]
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
    total = sum(len(pg.strokes) for pg in pages)
    pts = sum(len(s["points"]) for pg in pages for s in pg.strokes)
    print(f"{out.relative_to(ROOT)}  {total} 筆 / {pts} 點 / {out.stat().st_size // 1024} KB")
    preview(pages, "/private/tmp/claude-501/manual{0}.png", scale=0.9)
    return pages


if __name__ == "__main__":
    build()
