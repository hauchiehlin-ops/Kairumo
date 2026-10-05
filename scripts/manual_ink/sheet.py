"""字表預覽：把所有定義過的字排出來看。"""
from ink import Page, draw_cjk, draw_latin, preview
from glyphs import GLYPHS
chars = list(GLYPHS.keys())
page = Page(800, 700)
x, y = 20, 20
for i, ch in enumerate(chars):
    draw_cjk(page, ch, 20 + (i % 8) * 95, 20 + (i // 8) * 110, 80, "#222222", 3.2)
draw_latin(page, "Kairumo", 20, 560, 80, "#1a365d", 4)
preview([page], "/private/tmp/claude-501/sheet{0}.png", scale=1.2)
