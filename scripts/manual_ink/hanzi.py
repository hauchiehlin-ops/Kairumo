"""用 makemeahanzi 的筆順中線寫字：每一筆照標準筆順的中線落筆，再加一點手寫的不完美。

資料：`third_party/makemeahanzi/strokes-subset.json`（Arphic Public License，見同資料夾
README 與 ARPHICPL.TXT）。座標是 1024 格、y 向上，字的上緣在 y=900、下緣在 y=-124。

全形標點（，。、：；「」（））資料集沒有，這裡手繪。
"""
import json
import math
import random
from pathlib import Path

from ink import catmull

ROOT = Path(__file__).resolve().parents[2]
_DATA = json.loads((ROOT / "third_party/makemeahanzi/strokes-subset.json").read_text(encoding="utf-8"))["chars"]

EM = 1024.0
TOP = 900.0
PUNCT = set("，。、：；「」（）")

_rng = random.Random(20261006)


def reset_jitter():
    """手寫的歪斜與抖動回到固定的起點：同樣的輸入每次產生逐位元組相同的筆畫。"""
    _rng.seed(20261006)


def _jit(a):
    return _rng.uniform(-a, a)


def _char_strokes(ch):
    """字的每一筆 → 0..1 方格內的折線（y 向下）。"""
    return [[(x / EM, (TOP - y) / EM) for x, y in med] for med in _DATA[ch]]


def _punct_strokes(ch):
    """標點的筆畫，0..1 方格（y 向下）。位置依全形標點的慣例：、。，在左下，：；置中。"""
    if ch == "、":
        return [[(0.20, 0.64), (0.34, 0.80)]]
    if ch == "，":
        return [[(0.26, 0.70), (0.28, 0.80), (0.20, 0.92)]]
    if ch == "。":
        cx, cy, r = 0.27, 0.80, 0.11
        return [[(cx + r * math.cos(a / 8 * 2 * math.pi), cy + r * math.sin(a / 8 * 2 * math.pi)) for a in range(9)]]
    if ch == "：":
        return [[(0.5, 0.34), (0.5, 0.36)], [(0.5, 0.70), (0.5, 0.72)]]
    if ch == "；":
        return [[(0.5, 0.34), (0.5, 0.36)], [(0.52, 0.66), (0.54, 0.76), (0.46, 0.90)]]
    if ch == "「":
        return [[(0.80, 0.16), (0.46, 0.16), (0.46, 0.50)]]
    if ch == "」":
        return [[(0.20, 0.84), (0.54, 0.84), (0.54, 0.50)]]
    if ch == "（":
        return [[(0.68, 0.06), (0.52, 0.30), (0.50, 0.55), (0.52, 0.80), (0.68, 1.02)]]
    if ch == "）":
        return [[(0.32, 0.06), (0.48, 0.30), (0.50, 0.55), (0.48, 0.80), (0.32, 1.02)]]
    raise KeyError(ch)


def char_width(ch, size, gap):
    return size * (1 + gap)


def write_char(page, ch, x, y, size, color, width, hand=1.0):
    """把一個字寫在 (x, y) 左上角、邊長 `size` 的方格。`hand` 控制手寫的歪斜與抖動（0 = 工整）。"""
    strokes = _punct_strokes(ch) if ch in PUNCT else _char_strokes(ch)
    rot = math.radians(_jit(2.2) * hand)
    sc = 1 + _jit(0.035) * hand
    ox, oy = _jit(size * 0.025) * hand, _jit(size * 0.025) * hand
    cx = cy = 0.5
    for st in strokes:
        pts = []
        for u, v in st:
            # 繞字心微轉、微縮放。
            du, dv = (u - cx) * sc, (v - cy) * sc
            ru = du * math.cos(rot) - dv * math.sin(rot)
            rv = du * math.sin(rot) + dv * math.cos(rot)
            pts.append((x + (cx + ru) * size + ox + _jit(size * 0.008) * hand,
                        y + (cy + rv) * size + oy + _jit(size * 0.008) * hand))
        dense = catmull(pts, step=max(2.0, size / 14)) if len(pts) >= 3 else pts
        # 每一筆的落筆粗細略有不同。
        w = width * (1 + _jit(0.10) * hand)
        page.strokes.append({"color": color, "width": round(w, 2),
                             "points": [(round(px, 1), round(py, 1)) for px, py in dense]})


def is_punct_closing(ch):
    """不可出現在行首的標點。"""
    return ch in "，。、：；」）"


def wrap(text, max_chars):
    """依字數折行；行首不放句讀（禁則：多掛一個字在行尾）。"""
    lines, cur = [], ""
    for ch in text:
        if len(cur) >= max_chars and not is_punct_closing(ch):
            lines.append(cur)
            cur = ""
        cur += ch
    if cur:
        lines.append(cur)
    return lines


def write_line(page, text, x, y, size, color, width, gap=0.10, hand=1.0):
    """一行字（不折行）。回傳行尾的 x。空白算半格。"""
    cx = x
    for ch in text:
        if ch == " ":
            cx += size * 0.5
            continue
        write_char(page, ch, cx, y, size, color, width, hand)
        cx += char_width(ch, size, gap)
    return cx


def write_paragraph(page, text, x, y, size, color, width, max_chars, pitch, gap=0.10, hand=1.0):
    """折行寫一段。回傳（下一行的 y）。"""
    for line in wrap(text, max_chars):
        write_line(page, line, x, y, size, color, width, gap, hand)
        y += pitch
    return y


def line_width(text, size, gap=0.10):
    return sum(size * 0.5 if ch == " " else char_width(ch, size, gap) for ch in text)
