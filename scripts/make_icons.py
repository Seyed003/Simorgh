# Usage: python3 scripts/make_icons.py .   (requires Pillow with raqm)
"""Generates the Aghelan Ghiamat app, tray and launcher icons."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = sys.argv[1]
FONT = os.path.join(ROOT, 'assets/fonts/Vazirmatn-Bold.ttf')
TEAL = (20, 184, 166)
TEAL_DARK = (15, 118, 110)
NAVY = (11, 18, 32)
GRAY = (120, 132, 150)


def shield_points(size, inset):
    s = size
    w = s - 2 * inset
    top = inset
    left, right = inset, s - inset
    mid = s / 2
    return [
        (mid, top),
        (right, top + w * 0.14),
        (right, top + w * 0.50),
        (mid + w * 0.30, top + w * 0.82),
        (mid, top + w * 0.98),
        (mid - w * 0.30, top + w * 0.82),
        (left, top + w * 0.50),
        (left, top + w * 0.14),
    ]


def make_icon(size=1024, accent=TEAL, background=True):
    scale = 4
    S = size * scale
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if background:
        # Rounded square with a subtle vertical gradient.
        grad = Image.new('RGBA', (S, S))
        gd = ImageDraw.Draw(grad)
        for y in range(S):
            t = y / S
            c = tuple(int(NAVY[i] * (1 - t) + (NAVY[i] * 0.6) * t) for i in range(3))
            gd.line([(0, y), (S, y)], fill=c + (255,))
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
        img.paste(grad, (0, 0), mask)
    # Shield with gradient fill.
    shield = Image.new('L', (S, S), 0)
    ImageDraw.Draw(shield).polygon(shield_points(S, S * 0.17), fill=255)
    fill = Image.new('RGBA', (S, S))
    fd = ImageDraw.Draw(fill)
    dark = tuple(int(c * 0.62) for c in accent)
    for y in range(S):
        t = y / S
        c = tuple(int(accent[i] * (1 - t) + dark[i] * t) for i in range(3))
        fd.line([(0, y), (S, y)], fill=c + (255,))
    glow = shield.filter(ImageFilter.GaussianBlur(S * 0.03))
    glow_layer = Image.new('RGBA', (S, S), accent + (0,))
    glow_layer.putalpha(glow.point(lambda v: int(v * 0.55)))
    img = Image.alpha_composite(img, glow_layer)
    img.paste(fill, (0, 0), shield)
    # Persian letter "ع" (Aghelan) in white.
    font = ImageFont.truetype(FONT, int(S * 0.46))
    d = ImageDraw.Draw(img)
    text = 'ع'
    bbox = d.textbbox((0, 0), text, font=font, direction='rtl', language='fa')
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (S - tw) / 2 - bbox[0]
    y = S * 0.50 - th / 2 - bbox[1] - S * 0.02
    d.text((x, y), text, font=font, fill=(255, 255, 255, 255), direction='rtl', language='fa')
    return img.resize((size, size), Image.LANCZOS)


def save_ico(img, path, sizes):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, format='ICO', sizes=[(s, s) for s in sizes])


os.makedirs(os.path.join(ROOT, 'assets/branding'), exist_ok=True)
icon = make_icon(1024)
icon.save(os.path.join(ROOT, 'assets/branding/app_icon.png'))

# Windows executable icon.
save_ico(make_icon(256), os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'), [16, 24, 32, 48, 64, 128, 256])

# Tray icons: no background, teal when connected, gray when idle.
save_ico(make_icon(256, TEAL, background=False), os.path.join(ROOT, 'assets/tray/tray_connected.ico'), [16, 20, 24, 32, 48, 64])
save_ico(make_icon(256, GRAY, background=False), os.path.join(ROOT, 'assets/tray/tray_disconnected.ico'), [16, 20, 24, 32, 48, 64])

# Android legacy launcher icons.
for folder, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    make_icon(px).save(os.path.join(ROOT, f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png'))

# Android adaptive icon foreground (108dp canvas, art inside the 66dp safe zone).
for folder, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    art = make_icon(int(px * 0.80), background=False)
    canvas.paste(art, ((px - art.width) // 2, (px - art.height) // 2), art)
    out = os.path.join(ROOT, f'android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png')
    canvas.save(out)
print('ok')
