"""
Gera o icone mestre do app (mesmo desenho do AppLogo em Dart: caixa com
fita + 3 barras de estoque/lucro dentro) em alta resolucao, pra depois
espalhar pros tamanhos de cada plataforma com flutter_launcher_icons.

Uso: python gerar_icone.py
Saida: app_icon.png (1024x1024, fundo roxo) e app_icon_fg.png (so o
       desenho, fundo transparente, pra icone adaptativo do Android)
"""
from PIL import Image, ImageDraw

SIZE = 1024
PRIMARY = (83, 74, 183, 255)   # #534AB7
WHITE = (255, 255, 255, 255)


def draw_box_with_bars(draw: ImageDraw.ImageDraw, w: int, h: int, color, stroke_scale=1.0):
    left, right = w * 0.18, w * 0.82
    top, bottom = h * 0.22, h * 0.80
    tape_y = top + (bottom - top) * 0.30
    stroke_w = max(2, int(w * 0.052 * stroke_scale))
    radius = w * 0.05

    draw.rounded_rectangle([left, top, right, bottom], radius=radius, outline=color, width=stroke_w)
    draw.line([(left, tape_y), (right, tape_y)], fill=color, width=stroke_w)

    inner_left, inner_right = left + w * 0.08, right - w * 0.08
    bar_gap = w * 0.03
    bar_width = (inner_right - inner_left - bar_gap * 2) / 3
    baseline = bottom - h * 0.07
    heights = [h * 0.10, h * 0.16, h * 0.22]
    alphas = [0.55, 0.55, 1.0]

    x = inner_left
    for i in range(3):
        bar_color = color[:3] + (int(255 * alphas[i]),)
        bar_h = heights[i]
        rect = [x, baseline - bar_h, x + bar_width, baseline]
        draw.rounded_rectangle(rect, radius=bar_width * 0.35, fill=bar_color)
        x += bar_width + bar_gap


# ── Ícone completo (fundo roxo + desenho branco) ──────────────────────────
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
radius = SIZE * 0.22
draw.rounded_rectangle([0, 0, SIZE, SIZE], radius=radius, fill=PRIMARY)
draw_box_with_bars(draw, SIZE, SIZE, WHITE)
img.save("app_icon.png")
print("app_icon.png gerado")

# ── Foreground transparente (pro ícone adaptativo do Android) ────────────
# Android adaptive icon usa uma área "safe zone" menor no centro (~66%)
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fg_draw = ImageDraw.Draw(fg)
safe = int(SIZE * 0.66)
offset = (SIZE - safe) // 2
inner = Image.new("RGBA", (safe, safe), (0, 0, 0, 0))
inner_draw = ImageDraw.Draw(inner)
draw_box_with_bars(inner_draw, safe, safe, WHITE, stroke_scale=1.0)
fg.paste(inner, (offset, offset), inner)
fg.save("app_icon_fg.png")
print("app_icon_fg.png gerado")
