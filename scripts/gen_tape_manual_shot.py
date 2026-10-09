#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/gen_tape_manual_shot.py
產生操作手冊中的遮蔽膠帶（Masking Tape）功能示意圖：
- docs/manual/img/zh_tape.png
- docs/manual/img/en_tape.png
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
IMG_DIR = os.path.join(ROOT, "docs/manual/img")

ZH_BASE = os.path.join(IMG_DIR, "zh_editor.png")
EN_BASE = os.path.join(IMG_DIR, "en_editor.png")

FONT_ZH = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_ZH_FALLBACK = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
FONT_EN = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_EN_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"

def get_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        try:
            return ImageFont.truetype(FONT_ZH_FALLBACK, size)
        except Exception:
            return ImageFont.load_default()

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = bbox
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)

def draw_tape_shot(lang="zh"):
    base_path = ZH_BASE if lang == "zh" else EN_BASE
    if not os.path.exists(base_path):
        base_path = ZH_BASE

    im = Image.open(base_path).convert("RGBA")
    W, H = im.size # 744, 1133

    # Overlay layer for alpha drawing
    overlay = ImageImage = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_over = ImageDraw.Draw(overlay)
    draw_base = ImageDraw.Draw(im)

    # Fonts
    if lang == "zh":
        font_h1 = get_font(FONT_ZH, 22)
        font_body = get_font(FONT_ZH, 16)
        font_code = get_font(FONT_ZH, 15)
        font_badge = get_font(FONT_ZH, 13)
        font_tip = get_font(FONT_ZH, 13)
    else:
        font_h1 = get_font(FONT_EN, 21)
        font_body = get_font(FONT_EN, 15)
        font_code = get_font(FONT_EN_REG, 14)
        font_badge = get_font(FONT_EN, 12)
        font_tip = get_font(FONT_EN, 12)

    # 1. Clear the paper canvas content area
    # In zh_editor, the main paper sheet has a border around x in [95, 685], y in [195, 1085]
    canvas_x0, canvas_y0, canvas_x1, canvas_y1 = 96, 195, 686, 1085
    # Fill with clean notebook paper white
    draw_base.rectangle([canvas_x0, canvas_y0, canvas_x1, canvas_y1], fill=(255, 255, 255, 255))
    # Outer sheet border
    draw_base.rectangle([canvas_x0, canvas_y0, canvas_x1, canvas_y1], fill=None, outline=(226, 232, 240, 255), width=1)

    # Printable area dashed rectangle
    p_x0, p_y0, p_x1, p_y1 = canvas_x0 + 16, canvas_y0 + 16, canvas_x1 - 16, canvas_y1 - 16
    for sx in range(p_x0, p_x1, 10):
        draw_base.line([(sx, p_y0), (min(sx + 5, p_x1), p_y0)], fill=(203, 213, 225, 255), width=1)
        draw_base.line([(sx, p_y1), (min(sx + 5, p_x1), p_y1)], fill=(203, 213, 225, 255), width=1)
    for sy in range(p_y0, p_y1, 10):
        draw_base.line([(p_x0, sy), (p_x0, min(sy + 5, p_y1))], fill=(203, 213, 225, 255), width=1)
        draw_base.line([(p_x1, sy), (p_x1, min(sy + 5, p_y1))], fill=(203, 213, 225, 255), width=1)

    # Draw ruled lines on notebook paper (ruled notebook style)
    rule_color = (241, 245, 249, 255)
    margin_line_color = (254, 205, 211, 255)
    margin_x = canvas_x0 + 72
    for y in range(canvas_y0 + 90, canvas_y1 - 20, 48):
        draw_base.line([(canvas_x0 + 20, y), (canvas_x1 - 20, y)], fill=rule_color, width=1)
    draw_base.line([(margin_x, canvas_y0 + 24), (margin_x, canvas_y1 - 24)], fill=margin_line_color, width=2)

    # Content Coordinates
    content_x = margin_x + 24
    curr_y = canvas_y0 + 42

    # Note Header
    if lang == "zh":
        title_text = "生物考點重點背誦（期末複習）"
        date_text = "2026/10/09 · 互動遮蔽背誦模式（點擊翻開／遮回）"
    else:
        title_text = "Biology Exam Memorization Review"
        date_text = "Oct 9, 2026 · Interactive Masking Tape (Tap to Peek)"

    draw_base.text((content_x, curr_y), title_text, fill=(30, 41, 59, 255), font=font_h1)
    curr_y += 32
    draw_base.text((content_x, curr_y), date_text, fill=(100, 116, 139, 255), font=font_tip)
    curr_y += 36

    # Header Divider
    draw_base.line([(content_x, curr_y), (canvas_x1 - 40, curr_y)], fill=(226, 232, 240, 255), width=2)
    curr_y += 32

    # Q1
    if lang == "zh":
        q1_label = "Q1. 細胞內負責產生 ATP 的「能量工廠」胞器："
        a1_text = "粒線體 (Mitochondria)"
    else:
        q1_label = "Q1. Organelle generating cellular energy (ATP):"
        a1_text = "Mitochondria"

    draw_base.text((content_x, curr_y), q1_label, fill=(51, 65, 85, 255), font=font_body)
    curr_y += 36
    ans1_x = content_x + 20
    ans1_y = curr_y
    draw_base.text((ans1_x + 16, ans1_y + 8), a1_text, fill=(30, 41, 59, 255), font=font_code)

    # Tape 1: Fully Opaque Warm Yellow Masking Tape (#FCEEAC)
    tape1_w = 260 if lang == "zh" else 210
    tape1_h = 36
    tape1_rect = [ans1_x, ans1_y, ans1_x + tape1_w, ans1_y + tape1_h]
    # Tape shadow
    draw_base.rounded_rectangle([tape1_rect[0] + 1, tape1_rect[1] + 2, tape1_rect[2] + 1, tape1_rect[3] + 2], radius=4, fill=(0, 0, 0, 25))
    # Tape body
    draw_base.rounded_rectangle(tape1_rect, radius=4, fill=(252, 238, 172, 255), outline=(235, 215, 120, 255), width=1)
    # Subtle washi tape pattern
    for sx in range(int(tape1_rect[0]), int(tape1_rect[2]), 14):
        draw_base.line([(sx, tape1_rect[1] + 3), (sx + 8, tape1_rect[3] - 3)], fill=(245, 228, 150, 160), width=1)

    curr_y += 82

    # Q2
    if lang == "zh":
        q2_label = "Q2. 綠色植物進行光合作用的主體場所："
        a2_text = "葉綠體 (Chloroplast) — 類囊體膜與基質"
    else:
        q2_label = "Q2. Primary site of photosynthesis in green plants:"
        a2_text = "Chloroplast — thylakoids & stroma"

    draw_base.text((content_x, curr_y), q2_label, fill=(51, 65, 85, 255), font=font_body)
    curr_y += 36
    ans2_x = content_x + 20
    ans2_y = curr_y
    # Draw text underneath first
    draw_base.text((ans2_x + 16, ans2_y + 8), a2_text, fill=(15, 23, 42, 255), font=font_code)

    # Tape 2: Revealed (Peeked) Mint Green Tape (#C8E6C9, alpha 25%)
    tape2_w = 330 if lang == "zh" else 285
    tape2_h = 36
    tape2_rect = [ans2_x, ans2_y, ans2_x + tape2_w, ans2_y + tape2_h]
    # Draw transparent tape overlay
    draw_over.rounded_rectangle(tape2_rect, radius=4, fill=(200, 230, 201, 75), outline=(140, 200, 145, 180), width=1)

    curr_y += 110

    # Q3
    if lang == "zh":
        q3_label = "Q3. 提出 DNA 雙螺旋立體結構模型的科學家："
        a3_text = "華生 (Watson) 與 克里克 (Crick) 於 1953 年"
    else:
        q3_label = "Q3. Proposed the double-helix DNA structure model:"
        a3_text = "Watson & Crick (1953)"

    draw_base.text((content_x, curr_y), q3_label, fill=(51, 65, 85, 255), font=font_body)
    curr_y += 36

    ans3_x = content_x + 20
    ans3_y = curr_y + 105  # Ensures floating toolbar (y_t - 64) is safely below q3_label with 40px margin!
    draw_base.text((ans3_x + 16, ans3_y + 8), a3_text, fill=(30, 41, 59, 255), font=font_code)

    # Tape 3: Selected Tape with Selection Border, Handles, and Floating Toolbar
    tape3_w = 330 if lang == "zh" else 270
    tape3_h = 36
    tape3_rect = [ans3_x, ans3_y, ans3_x + tape3_w, ans3_y + tape3_h]

    # Selected Tape Body (#FFE0B2 - apricot orange / pastel peach)
    draw_base.rounded_rectangle([tape3_rect[0] + 1, tape3_rect[1] + 3, tape3_rect[2] + 1, tape3_rect[3] + 3], radius=4, fill=(0, 0, 0, 25))
    draw_base.rounded_rectangle(tape3_rect, radius=4, fill=(255, 224, 178, 245), outline=(245, 200, 140, 255), width=1)

    # Blue Dashed Selection Outline
    accent_blue = (0, 122, 255, 255)
    x_l, y_t, x_r, y_b = tape3_rect
    for sx in range(int(x_l), int(x_r), 8):
        draw_base.line([(sx, y_t), (min(sx + 4, x_r), y_t)], fill=accent_blue, width=2)
        draw_base.line([(sx, y_b), (min(sx + 4, x_r), y_b)], fill=accent_blue, width=2)
    for sy in range(int(y_t), int(y_b), 8):
        draw_base.line([(x_l, sy), (x_l, min(sy + 4, y_b))], fill=accent_blue, width=2)
        draw_base.line([(x_r, sy), (x_r, min(sy + 4, y_b))], fill=accent_blue, width=2)

    # 4 Resize Handles: Left, Right, Top, Bottom
    def draw_handle(cx, cy):
        draw_base.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(255, 255, 255, 255), outline=accent_blue, width=2)

    draw_handle(x_l, (y_t + y_b) / 2) # Left
    draw_handle(x_r, (y_t + y_b) / 2) # Right
    draw_handle((x_l + x_r) / 2, y_t) # Top
    draw_handle((x_l + x_r) / 2, y_b) # Bottom

    # Rotation Stem & Handle (Top stem)
    stem_x = (x_l + x_r) / 2
    draw_base.line([(stem_x, y_t - 7), (stem_x, y_t - 22)], fill=accent_blue, width=2)
    draw_base.ellipse([stem_x - 7, y_t - 29, stem_x + 7, y_t - 15], fill=accent_blue, outline=(255, 255, 255, 255), width=2)

    # Floating Toolbar above Tape 3
    tb_w = 340
    tb_h = 42
    tb_cx = (x_l + x_r) / 2
    tb_x0 = tb_cx - tb_w / 2
    tb_x1 = tb_cx + tb_w / 2
    tb_y0 = y_t - 64
    tb_y1 = tb_y0 + tb_h

    # Shadow
    for off in range(1, 5):
        draw_over.rounded_rectangle([tb_x0 - off, tb_y0 - off + 2, tb_x1 + off, tb_y1 + off + 2], radius=21, fill=(0, 0, 0, 10))
    # Pill background
    draw_base.rounded_rectangle([tb_x0, tb_y0, tb_x1, tb_y1], radius=21, fill=(255, 255, 255, 255), outline=(220, 225, 232, 255), width=1)

    # 7 Morandi Preset Color Swatches
    presets = [
        (252, 238, 172), # 暖黃
        (255, 209, 220), # 柔粉
        (200, 230, 201), # 薄荷綠
        (187, 222, 251), # 晴空藍
        (255, 224, 178), # 淺杏橙 (Selected!)
        (225, 190, 231), # 薰衣草紫
        (207, 216, 220), # 莫蘭迪灰
    ]
    swatch_start_x = tb_x0 + 16
    for i, col in enumerate(presets):
        scx = swatch_start_x + i * 26
        scy = (tb_y0 + tb_y1) / 2
        draw_base.ellipse([scx - 9, scy - 9, scx + 9, scy + 9], fill=col)
        if i == 4: # Active orange
            draw_base.ellipse([scx - 11, scy - 11, scx + 11, scy + 11], outline=(30, 41, 59, 255), width=2)
        else:
            draw_base.ellipse([scx - 9, scy - 9, scx + 9, scy + 9], outline=(200, 205, 210, 255), width=1)

    # Divider 1
    div1_x = swatch_start_x + 7 * 26 + 4
    draw_base.line([(div1_x, tb_y0 + 12), (div1_x, tb_y1 - 12)], fill=(226, 232, 240, 255), width=1)

    # Rotate icon
    rot_cx = div1_x + 22
    rot_cy = (tb_y0 + tb_y1) / 2
    draw_base.arc([rot_cx - 7, rot_cy - 7, rot_cx + 7, rot_cy + 7], start=30, end=300, fill=accent_blue, width=2)
    draw_base.polygon([(rot_cx + 4, rot_cy - 9), (rot_cx + 8, rot_cy - 4), (rot_cx + 1, rot_cy - 4)], fill=accent_blue)

    # Divider 2
    div2_x = rot_cx + 22
    draw_base.line([(div2_x, tb_y0 + 12), (div2_x, tb_y1 - 12)], fill=(226, 232, 240, 255), width=1)

    # Eye icon
    eye_cx = div2_x + 22
    eye_cy = (tb_y0 + tb_y1) / 2
    draw_base.arc([eye_cx - 9, eye_cy - 8, eye_cx + 9, eye_cy + 6], start=30, end=150, fill=accent_blue, width=2)
    draw_base.arc([eye_cx - 9, eye_cy - 6, eye_cx + 9, eye_cy + 8], start=210, end=330, fill=accent_blue, width=2)
    draw_base.ellipse([eye_cx - 3, eye_cy - 3, eye_cx + 3, eye_cy + 3], fill=accent_blue)

    # Divider 3
    div3_x = eye_cx + 22
    draw_base.line([(div3_x, tb_y0 + 12), (div3_x, tb_y1 - 12)], fill=(226, 232, 240, 255), width=1)

    # Trash icon
    trash_cx = div3_x + 22
    trash_cy = (tb_y0 + tb_y1) / 2
    red_trash = (239, 68, 68, 255)
    draw_base.rectangle([trash_cx - 5, trash_cy - 3, trash_cx + 5, trash_cy + 7], fill=None, outline=red_trash, width=2)
    draw_base.line([(trash_cx - 7, trash_cy - 4), (trash_cx + 7, trash_cy - 4)], fill=red_trash, width=2)
    draw_base.line([(trash_cx - 3, trash_cy - 7), (trash_cx + 3, trash_cy - 7)], fill=red_trash, width=2)

    # Composite alpha overlay onto base
    im = Image.alpha_composite(im, overlay)
    draw = ImageDraw.Draw(im)

    # Elegant Callout Badges with pointer arrows
    def draw_callout(box_x, box_y, text, target_x, target_y, is_right=False):
        t_box = draw.textbbox((0, 0), text, font=font_badge)
        bw = (t_box[2] - t_box[0]) + 20
        bh = 28
        # Shadow
        draw.rounded_rectangle([box_x + 1, box_y + 2, box_x + bw + 1, box_y + bh + 2], radius=14, fill=(0, 0, 0, 30))
        # Pill
        draw.rounded_rectangle([box_x, box_y, box_x + bw, box_y + bh], radius=14, fill=(30, 41, 59, 245))
        # Text
        draw.text((box_x + 10, box_y + 6), text, fill=(255, 255, 255, 255), font=font_badge)
        # Guide line to target
        start_pt = (box_x if is_right else box_x + bw, box_y + bh / 2)
        # Dot on target
        draw.ellipse([target_x - 3, target_y - 3, target_x + 3, target_y + 3], fill=(30, 41, 59, 255))
        draw.line([start_pt, (target_x, target_y)], fill=(71, 85, 105, 200), width=1)

    if lang == "zh":
        # Badge 1: 輕點立即翻開 / 遮回 (placed on right side of tape 2)
        draw_callout(ans2_x + tape2_w + 14, ans2_y + 4, "輕點翻開／遮回背誦答案", ans2_x + tape2_w, ans2_y + 18, is_right=True)
        # Badge 2: 上下左右自由拉伸把手 (placed below tape 3)
        draw_callout(x_l + 20, y_b + 42, "上下左右拉伸與旋轉把手", (x_l + x_r) / 2, y_b, is_right=False)
        # Badge 3: 浮動工具條（快速換色、旋轉、刪除）(placed above floating bar, right under q3)
        draw_callout(tb_x0, tb_y0 - 38, "浮動列：6色快速換色 · 旋轉 · 刪除", tb_x0 + 70, tb_y0, is_right=False)
    else:
        # Badge 1: Tap to reveal or hide answers
        draw_callout(ans2_x + tape2_w + 12, ans2_y + 4, "Tap to reveal / hide key answer", ans2_x + tape2_w, ans2_y + 18, is_right=True)
        # Badge 2: 4-way resize & rotation handles
        draw_callout(x_l + 10, y_b + 42, "4-way resize handles & rotation", (x_l + x_r) / 2, y_b, is_right=False)
        # Badge 3: Floating toolbar: color swatches, rotate, delete
        draw_callout(tb_x0, tb_y0 - 38, "Floating bar: colors · rotate · delete", tb_x0 + 70, tb_y0, is_right=False)

    out_name = f"{lang}_tape.png"
    out_path = os.path.join(IMG_DIR, out_name)
    im.save(out_path, "PNG")
    print(f"✅ 已產生 {out_path} ({im.size[0]}x{im.size[1]})")

if __name__ == "__main__":
    draw_tape_shot("zh")
    draw_tape_shot("en")
