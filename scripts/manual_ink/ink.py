"""筆畫的基本運算：平滑、文字排版、預覽。全部只用標準函式庫 + PIL（預覽用）。"""
import math

from glyphs import LATIN


def catmull(points, step=3.0):
    """Catmull-Rom 平滑，並重新取樣到大約每 `step` 一點。兩點的線原樣回傳。"""
    if len(points) < 3:
        return _resample(list(points), step)
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg = max(2, int(math.dist(p1, p2) / step))
        for k in range(seg):
            t = k / seg
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(points[-1])
    return out


def _resample(points, step):
    if len(points) < 2:
        return points
    out = [points[0]]
    for a, b in zip(points, points[1:]):
        n = max(1, int(math.dist(a, b) / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def polyline(points, smooth=False, step=3.0):
    """折線：`smooth` 為真用曲線，否則保留轉角（只補點）。"""
    return catmull(points, step) if smooth else _resample(list(points), step)


class Page:
    """一頁的筆畫收集器。每筆畫帶顏色與粗細。"""

    def __init__(self, w=800, h=1132):
        self.w, self.h = w, h
        self.strokes = []  # dict(color, width, points)

    def add(self, points, color, width, smooth=False):
        pts = polyline(points, smooth=smooth)
        if len(pts) >= 2:
            self.strokes.append({"color": color, "width": width, "points": [(round(x, 1), round(y, 1)) for x, y in pts]})

    def add_all(self, strokes, color, width, smooth=False):
        for s in strokes:
            self.add(s, color, width, smooth)


def draw_latin(page, text, x, y, size, color, width, gap=10):
    k = size / 100.0
    cx = x
    for ch in text:
        adv, strokes = LATIN[ch]
        for s in strokes:
            page.add([(cx + px * k, y + py * k) for px, py in s], color, width, smooth=True)
        cx += (adv + gap) * k
    return cx


def preview(pages, path, scale=0.8):
    from PIL import Image, ImageDraw
    for index, page in enumerate(pages):
        img = Image.new("RGB", (int(page.w * scale), int(page.h * scale)), "white")
        d = ImageDraw.Draw(img)
        for s in page.strokes:
            pts = [(x * scale, y * scale) for x, y in s["points"]]
            w = max(1, round(s["width"] * scale))
            d.line(pts, fill=s["color"], width=w, joint="curve")
            for p in (pts[0], pts[-1]):
                d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=s["color"])
        img.save(path.format(index))
