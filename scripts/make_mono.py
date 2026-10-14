#!/usr/bin/env python3
"""Monochrome Android icons, as a white silhouette of the real phoenix art.

Generates the notification / quick-settings-tile icon (`ic_stat_vpn`) and the
Android 13+ themed icon layer (`ic_launcher_monochrome`) from the phoenix
image, so they match the app icon instead of a separate drawn glyph. They are
tinted by the system, so they are a flat white silhouette on transparent.

Run from the repo root:  python3 scripts/make_mono.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

SOURCE = 'assets/branding/phoenix_mark.png'
RES = 'android/app/src/main/res'

# dp sizes per density bucket.
BUCKETS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
STAT_DP = 24      # notification / tile icon
MONO_DP = 108     # adaptive (themed) icon canvas
STAT_FILL = 0.86  # glyph's long side within the icon
MONO_FILL = 0.62  # glyph within the adaptive safe zone


def glyph():
    """A clean white silhouette of the phoenix: drop the faint ring and the
    stray embers, keep only the bird."""
    src = Image.open(SOURCE).convert('RGBA')
    alpha = src.split()[-1]
    mask = alpha.point(lambda v: 255 if v > 55 else 0).convert('L')
    # Opening removes the thin ring and specks; a light blur rounds the edges.
    mask = mask.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(7))
    mask = mask.filter(ImageFilter.GaussianBlur(0.6)).point(
        lambda v: 255 if v > 128 else 0
    )
    # Keep only the component the bird's centre sits in (drops loose embers).
    px = mask.load()
    w, h = mask.size
    sx = sy = n = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y]:
                sx += x
                sy += y
                n += 1
    seed = (sx // n, sy // n)
    if not px[seed[0], seed[1]]:
        seed = next(
            (x, y)
            for y in range(h)
            for x in range(w)
            if px[x, y]
        )
    ImageDraw.floodfill(mask, seed, 128, thresh=10)
    bird = mask.point(lambda v: 255 if v == 128 else 0).convert('L')
    return bird.crop(bird.getbbox())


def white(a):
    out = Image.new('RGBA', a.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def place(g, canvas, fill):
    scale = (canvas * fill) / max(g.size)
    gw, gh = max(1, round(g.size[0] * scale)), max(1, round(g.size[1] * scale))
    g = g.resize((gw, gh), Image.LANCZOS)
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(white(g), ((canvas - gw) // 2, (canvas - gh) // 2))
    return out


def main():
    g = glyph()
    for bucket, mult in BUCKETS.items():
        d = os.path.join(RES, f'drawable-{bucket}')
        os.makedirs(d, exist_ok=True)
        place(g, round(STAT_DP * mult), STAT_FILL).save(
            os.path.join(d, 'ic_stat_vpn.png')
        )
        place(g, round(MONO_DP * mult), MONO_FILL).save(
            os.path.join(d, 'ic_launcher_monochrome.png')
        )
        print('wrote', d)


if __name__ == '__main__':
    main()
