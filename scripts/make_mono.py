#!/usr/bin/env python3
"""Monochrome Android icons, as a white silhouette of the real phoenix art.

Generates the notification / quick-settings-tile icon (`ic_stat_vpn`) and the
Android 13+ themed icon layer (`ic_launcher_monochrome`) from the phoenix
image, so they match the app icon instead of a separate drawn glyph. They are
tinted by the system, so they are a flat white silhouette on transparent.

Run from the repo root:  python3 scripts/make_mono.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw

SOURCE = 'assets/branding/phoenix_mark.png'
RES = 'android/app/src/main/res'

# dp sizes per density bucket.
BUCKETS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
STAT_DP = 24      # notification / tile icon
MONO_DP = 108     # adaptive (themed) icon canvas
STAT_FILL = 0.86  # glyph's long side within the icon
MONO_FILL = 0.62  # glyph within the adaptive safe zone


def glyph():
    """A clean, smooth silhouette of the phoenix.

    Keeps only the bird's own connected region (so the faint ring and the
    loose embers around it drop away) and reuses the artwork's soft,
    anti-aliased alpha inside it instead of a hard 1-bit cut — so the feather
    detail and smooth edges survive down to the small sizes.
    """
    src = Image.open(SOURCE).convert('RGBA')
    alpha = np.array(src)[:, :, 3]
    binary = Image.fromarray(((alpha > 40) * 255).astype('uint8'), 'L')

    a = np.array(binary)
    ys, xs = np.where(a > 0)
    seed = (int(round(xs.mean())), int(round(ys.mean())))
    if a[seed[1], seed[0]] == 0:  # centre fell on a gap: snap to nearest ink
        i = int(np.argmin((xs - seed[0]) ** 2 + (ys - seed[1]) ** 2))
        seed = (int(xs[i]), int(ys[i]))
    flood = binary.copy()
    ImageDraw.floodfill(flood, seed, 128, thresh=10)
    bird = np.array(flood) == 128

    out = Image.fromarray((alpha * bird).astype('uint8'), 'L')
    return out.crop(out.getbbox())


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
