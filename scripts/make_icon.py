#!/usr/bin/env python3
"""Builds the raster app-icon assets from the phoenix artwork.

Source: assets/branding/phoenix-source.png — a fiery phoenix on a black
field. The black is composited away with a `lighten` blend over the night
gradient, so it never shows as a square; for the transparent foreground and
tray marks the black is keyed to alpha from brightness.

Outputs:
  assets/branding/app_icon.png                       1024, rounded
  assets/branding/phoenix_mark.png                   transparent, connect button
  android/.../mipmap-*/ic_launcher.png               legacy launcher
  android/.../mipmap-*/ic_launcher_foreground.png    adaptive foreground
  windows/runner/resources/app_icon.ico
  assets/tray/tray_{connected,disconnected}.ico

The monochrome Android drawables (ic_stat_vpn, ic_launcher_monochrome) stay
a flat silhouette and are produced by scripts/make_brand.py, not here.

Requires Pillow:  pip install pillow
Usage:  python3 scripts/make_icon.py
"""

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SOURCE = os.path.join(ROOT, 'assets/branding/phoenix-source.png')

NIGHT_TOP = (0x16, 0x1C, 0x40)
NIGHT_BOTTOM = (0x3B, 0x16, 0x50)
EMBER = (0xFF, 0x7A, 0x2B)
ASH = (0x9A, 0xA3, 0xB2)


def _bright(im):
    r, g, b = im.split()
    return ImageChops.lighter(ImageChops.lighter(r, g), b)


def load_bird(thresh=40):
    """The phoenix cropped tight to the real bird (fire on black)."""
    im = Image.open(SOURCE).convert('RGB')
    return im.crop(_bright(im).point(lambda v: 255 if v > thresh else 0).getbbox())


def bird_rgba(lo=34, hi=110, gamma=0.85, feather=1.2):
    """The phoenix with the black keyed to transparency (soft edges)."""
    im = load_bird()
    def curve(v):
        if v <= lo:
            return 0
        if v >= hi:
            return 255
        return int(255 * (((v - lo) / (hi - lo)) ** gamma))
    im.putalpha(_bright(im).point(curve).filter(ImageFilter.GaussianBlur(feather)))
    return im


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius, fill=255)
    return m


def night_bg(size):
    bg = Image.new('RGB', (size, size))
    px = bg.load()
    for y in range(size):
        for x in range(size):
            t = x / size * 0.45 + y / size * 0.55
            px[x, y] = tuple(
                int(NIGHT_TOP[i] + (NIGHT_BOTTOM[i] - NIGHT_TOP[i]) * t) for i in range(3))
    glow = Image.new('L', (size, size), 0)
    r = size * 0.4
    ImageDraw.Draw(glow).ellipse(
        [size * 0.5 - r, size * 0.5 - r, size * 0.5 + r, size * 0.5 + r], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.13)).point(lambda v: int(v * 0.5))
    warm = Image.new('RGB', (size, size), EMBER)
    return Image.composite(warm, bg, glow)


def full_icon(size, radius, height_frac=0.86):
    """The complete icon: phoenix over the night gradient, rounded."""
    bird = load_bird()
    th = int(size * height_frac)
    tw = int(bird.size[0] * th / bird.size[1])
    canvas = Image.new('RGB', (size, size), (0, 0, 0))
    canvas.paste(bird.resize((tw, th), Image.LANCZOS), ((size - tw) // 2, (size - th) // 2))
    out = ImageChops.lighter(night_bg(size), canvas).convert('RGBA')
    out.putalpha(rounded_mask(size, radius))
    return out


def foreground(size, height_frac=0.60):
    """Adaptive-icon foreground: the keyed phoenix centred, transparent."""
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bird = bird_rgba()
    th = int(size * height_frac)
    tw = int(bird.size[0] * th / bird.size[1])
    fg.alpha_composite(bird.resize((tw, th), Image.LANCZOS), ((size - tw) // 2, (size - th) // 2))
    return fg


def mark(height=720):
    """The phoenix on its own (transparent), for the in-app connect button."""
    b = bird_rgba()
    return b.resize((round(b.size[0] * height / b.size[1]), height), Image.LANCZOS)


def tray(size, grey=False):
    bird = bird_rgba()
    if grey:
        a = bird.getchannel('A')
        tinted = ImageOps.colorize(ImageOps.grayscale(bird), (0, 0, 0), ASH, mid=(90, 95, 110))
        bird = tinted.convert('RGBA')
        bird.putalpha(a)
    th = int(size * 0.94)
    tw = int(bird.size[0] * th / bird.size[1])
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(bird.resize((tw, th), Image.LANCZOS), ((size - tw) // 2, (size - th) // 2))
    return out


def save_png(image, path):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def save_ico(image_for_size, path, sizes):
    imgs = [image_for_size(s) for s in sizes]
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    imgs[-1].save(path, format='ICO', sizes=[(s, s) for s in sizes], append_images=imgs[:-1])


DENSITIES = [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]


def main():
    save_png(full_icon(1024, 224), 'assets/branding/app_icon.png')
    save_png(mark(), 'assets/branding/phoenix_mark.png')
    for density, size in DENSITIES:
        save_png(full_icon(size, round(size * 0.22)),
                 f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
        save_png(foreground(round(size * 108 / 48)),
                 f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png')
    save_ico(lambda s: full_icon(s, round(s * 0.22)),
             'windows/runner/resources/app_icon.ico', [16, 24, 32, 48, 64, 128, 256])
    save_ico(lambda s: tray(s), 'assets/tray/tray_connected.ico', [16, 24, 32, 48])
    save_ico(lambda s: tray(s, grey=True), 'assets/tray/tray_disconnected.ico', [16, 24, 32, 48])
    print('icon assets written from', os.path.relpath(SOURCE, ROOT))


if __name__ == '__main__':
    main()
