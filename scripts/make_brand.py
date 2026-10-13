#!/usr/bin/env python3
"""Generates the simple vector phoenix mark used inside the app.

The phoenix rises out of a broken ring: the walls around the internet,
broken by its wings. Outputs:

  assets/branding/phoenix.svg              the mark (transparent background)
  lib/core/branding/phoenix_paths.g.dart   path data for the small static mark
  android/.../drawable/ic_stat_vpn.xml     monochrome notification/tile icon
  android/.../drawable/ic_launcher_monochrome.xml  Android 13 themed icon

The full app icon (launcher, Windows, tray, the 1024 px app_icon.png) is a
separate photographic phoenix built by scripts/make_icon.py, and the animated
connect-button phoenix by scripts/make_phoenix.py; this script no longer
touches those so running it will not overwrite them.

Requires Pillow and cairosvg:  pip install pillow cairosvg
Usage:  python3 scripts/make_brand.py
"""

import io
import math
import os

import cairosvg
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'android/app/src/main/res')

FIRE = [('0', '#FFE08A'), ('0.5', '#FF8A2B'), ('1', '#E5305B')]
NIGHT = ('#141A3A', '#3B1650')


# --- geometry (512 x 512) -------------------------------------------------

def _pt(x, y):
    return f'{x:.1f},{y:.1f}'


def feather(bx, by, angle_deg, length, width, bend):
    """A flame-shaped feather from (bx, by) pointing at angle_deg
    (0 = right, -90 = up), curving by `bend` (fraction of its length)."""
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx

    def along(t, side, w, b):
        return (bx + dx * length * t + nx * (side * width * w + length * bend * b),
                by + dy * length * t + ny * (side * width * w + length * bend * b))

    tip = (bx + dx * length + nx * length * bend, by + dy * length + ny * length * bend)
    return (f'M{_pt(bx - nx * width * 0.2, by - ny * width * 0.2)} '
            f'C{_pt(*along(0.35, -1, 0.55, 0.15))} {_pt(*along(0.75, -1, 0.25, 0.55))} {_pt(*tip)} '
            f'C{_pt(*along(0.70, 1, 0.15, 0.6))} {_pt(*along(0.35, 1, 0.55, 0.15))} '
            f'{_pt(bx + nx * width * 0.2, by + ny * width * 0.2)} Z')


WING = [  # base x, base y, angle, length, width, bend (right wing)
    (278, 250, -66, 226, 52, 0.20),
    (286, 258, -42, 214, 50, 0.18),
    (292, 268, -18, 190, 46, 0.16),
    (294, 280, 6, 150, 40, 0.14),
]
TAIL = [
    (256, 320, 90, 164, 32, 0.0),
    (244, 312, 116, 150, 30, -0.55),
    (268, 312, 64, 150, 30, 0.55),
]


def phoenix_paths():
    paths = []
    for bx, by, angle, length, width, bend in WING:
        paths.append(feather(bx, by, angle, length, width, bend))
        paths.append(feather(512 - bx, by, 180 - angle, length, width, -bend))
    for f in TAIL:
        paths.append(feather(*f))
    # Chest.
    paths.append('M256,226 C278,226 286,252 283,280 C280,306 268,324 256,334 '
                 'C244,324 232,306 229,280 C226,252 234,226 256,226 Z')
    # Neck and the head turned to the right, with its beak.
    paths.append('M244,236 C238,200 240,164 252,140 C262,122 280,114 296,122 '
                 'L324,134 L296,142 C284,152 278,178 270,236 Z')
    # Crest flames streaming back.
    paths.append(feather(272, 126, -132, 74, 18, -0.28))
    paths.append(feather(266, 132, -154, 62, 15, -0.22))
    paths.append(feather(276, 124, -110, 54, 13, -0.28))
    return paths


RING = 'M128,162 A186,186 0 1,0 384,162'  # broken at the top


# --- SVG ------------------------------------------------------------------

def _stops(stops, opacity=None):
    return ''.join(
        f'<stop offset="{o}" stop-color="{c}"'
        f'{f" stop-opacity={chr(34)}{opacity}{chr(34)}" if opacity else ""}/>'
        for o, c in stops)


def svg(background=True, ring=True, fill=None, scale=1.0, size=512):
    """`fill` replaces the fire gradient with one colour; `scale` shrinks the
    artwork around the centre (for adaptive icon safe zones)."""
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
             'viewBox="0 0 512 512"><defs>'
             '<linearGradient id="fire" gradientUnits="userSpaceOnUse" x1="0" y1="40" x2="0" y2="490">'
             f'{_stops(FIRE)}</linearGradient>'
             '<radialGradient id="glow" cx="0.5" cy="0.48" r="0.5">'
             '<stop offset="0" stop-color="#FF8A2B" stop-opacity="0.5"/>'
             '<stop offset="1" stop-color="#FF8A2B" stop-opacity="0"/></radialGradient>'
             '<linearGradient id="night" x1="0" y1="0" x2="1" y2="1">'
             f'<stop offset="0" stop-color="{NIGHT[0]}"/><stop offset="1" stop-color="{NIGHT[1]}"/>'
             '</linearGradient>'
             '<linearGradient id="glass" gradientUnits="userSpaceOnUse" x1="0" y1="120" x2="0" y2="500">'
             '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>'
             '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0.12"/></linearGradient>'
             '</defs>']
    if background:
        parts.append('<rect width="512" height="512" rx="112" fill="url(#night)"/>')
        parts.append('<circle cx="256" cy="256" r="230" fill="url(#glow)"/>')
    s = scale
    parts.append(f'<g transform="translate({256 - 256 * s:.1f},{256 - 256 * s:.1f}) scale({s})">')
    if ring:
        stroke = fill or 'url(#glass)'
        parts.append(f'<path d="{RING}" fill="none" stroke="{stroke}" stroke-width="14" '
                     'stroke-linecap="round"/>')
    color = fill or 'url(#fire)'
    parts.append(f'<g fill="{color}">' + ''.join(f'<path d="{d}"/>' for d in phoenix_paths()) + '</g>')
    parts.append('</g></svg>')
    return ''.join(parts)


def png(svg_text, size):
    data = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert('RGBA')


def write(path, data, mode='w'):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, mode) as f:
        f.write(data)


def save_png(image, path):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def save_ico(svg_text, path, sizes):
    images = [png(svg_text, s) for s in sizes]
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    images[-1].save(path, format='ICO', sizes=[(s, s) for s in sizes],
                    append_images=images[:-1])


def vector_drawable(paths, ring=False, size_dp=24):
    body = ''.join(
        f'\n    <path android:fillColor="#FFFFFFFF" android:pathData="{d}" />' for d in paths)
    if ring:
        body += (f'\n    <path android:strokeColor="#FFFFFFFF" android:strokeWidth="14" '
                 f'android:strokeLineCap="round" android:pathData="{RING}" />')
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- GENERATED by scripts/make_brand.py: the phoenix mark. -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="{size_dp}dp"\n    android:height="{size_dp}dp"\n'
            '    android:viewportWidth="512"\n    android:viewportHeight="512">'
            f'{body}\n</vector>\n')


def main():
    write('assets/branding/phoenix.svg', svg(background=False, ring=True))

    paths = phoenix_paths()
    dart = ['// GENERATED by scripts/make_brand.py - do not edit.',
            '//',
            '// The phoenix mark on a 512 x 512 canvas: wings, tail, chest, head',
            '// and crest (filled), plus the broken ring (stroked, 14 wide).',
            '',
            'const phoenixPaths = <String>[']
    dart += [f"  '{d}'," for d in paths]
    dart += ['];', '', f"const phoenixRingPath = '{RING}';", '']
    write('lib/core/branding/phoenix_paths.g.dart', '\n'.join(dart))

    # Monochrome Android glyphs (notification + themed icon) stay a flat
    # silhouette, so they come from this vector mark.
    write('android/app/src/main/res/drawable/ic_stat_vpn.xml', vector_drawable(paths))
    mono = vector_drawable(paths, ring=True, size_dp=108).replace(
        'android:viewportWidth="512"\n    android:viewportHeight="512">',
        'android:viewportWidth="512"\n    android:viewportHeight="512">\n'
        '    <group android:scaleX="0.62" android:scaleY="0.62"\n'
        '        android:pivotX="256" android:pivotY="256">').replace(
        '\n</vector>', '\n    </group>\n</vector>')
    write('android/app/src/main/res/drawable/ic_launcher_monochrome.xml', mono)
    print('brand mark written (app icons: scripts/make_icon.py)')


if __name__ == '__main__':
    main()
