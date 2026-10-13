#!/usr/bin/env python3
"""Generates lib/core/branding/phoenix_anim.g.dart for the animated connect
button: a front-facing phoenix whose wings are a separate piece that pivots
at the shoulder, so the painter can fold them (VPN off) or spread and flap
them (connecting/connected).

Usage:  python3 scripts/make_phoenix.py

Front-facing phoenix for the connect button. Each wing is a separate
piece (shoulder at the local origin) made of overlapping CURVED feathers so
it sweeps like a real wing; the painter rotates/scales it for fold & flap
and mirrors it for the other side. Body is absolute on a 512x512 canvas."""
import math

CX = 256.0
PIVOT = (212.0, 250.0)
FOLD_DEG = 56.0
FOLD_SCALE = 0.55


def _pt(x, y):
    return f'{x:.1f},{y:.1f}'


def feather(bx, by, angle_deg, length, width, bend=0.14, waist=0.5):
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx

    def P(t, side, w, b):
        return (bx + dx * length * t + nx * (side * width * w + length * bend * b),
                by + dy * length * t + ny * (side * width * w + length * bend * b))

    tip = (bx + dx * length + nx * length * bend, by + dy * length + ny * length * bend)
    return (f'M{_pt(bx - nx * width * 0.18, by - ny * width * 0.18)} '
            f'C{_pt(*P(0.32, -1, 0.62, 0.1))} {_pt(*P(waist, -1, 0.5, 0.4))} {_pt(*tip)} '
            f'C{_pt(*P(waist, 1, 0.5, 0.4))} {_pt(*P(0.32, 1, 0.62, 0.1))} '
            f'{_pt(bx + nx * width * 0.18, by + ny * width * 0.18)} Z')


def sweep(base, tip, width, bulge=0.22, waist=0.46):
    """A curved (sickle) feather from base to tip, bowing by `bulge` of its
    length and widest at `waist`. Pointed tip, rounded root."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy) or 1
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux            # left of travel
    k = bulge * L

    def P(t, side):
        # spine bows toward +n; half-width tapers to 0 at tip, round at root
        w = width * math.sin(min(t / waist, 1) * math.pi / 2) if t <= waist \
            else width * math.cos((t - waist) / (1 - waist) * math.pi / 2) ** 1.3
        cx = bx + dx * t + nx * k * math.sin(t * math.pi)
        cy = by + dy * t + ny * k * math.sin(t * math.pi)
        return (cx + nx * side * w, cy + ny * side * w)

    left = [P(t / 10, 1) for t in range(1, 10)]
    right = [P(t / 10, -1) for t in range(9, 0, -1)]
    pts = [base] + left + [tip] + right
    d = f'M{_pt(*pts[0])} ' + ' '.join(f'L{_pt(*p)}' for p in pts[1:]) + ' Z'
    return d


def wing_feathers():
    """Right wing, shoulder at origin, OPEN pose: overlapping curved feathers
    fanning up-and-out, all swept the same way."""
    arm = (74.0, -26.0)                     # wrist
    # (radius, angle_deg) of each feather tip from the wrist; width
    spec = [
        (170, -104, 30),   # top primary (up), longest reach
        (188, -82, 33),
        (196, -58, 34),
        (190, -34, 33),
        (172, -12, 31),
        (146, 10, 27),
        (116, 30, 23),
    ]
    out = []
    n = len(spec)
    for i, (r, ang, w) in enumerate(spec):
        base = (arm[0] * i / (n - 1) * 0.5, arm[1] * i / (n - 1) * 0.5)
        a = math.radians(ang)
        tip = (arm[0] + r * math.cos(a), arm[1] + r * math.sin(a))
        out.append(sweep(base, tip, w, bulge=0.16, waist=0.5))
    # a small filled arm so the roots merge
    out.insert(0, 'M-14,-2 C14,-16 54,-14 96,-6 C112,-2 112,18 92,20 '
                  'C52,24 16,18 -12,14 C-24,10 -24,2 -14,-2 Z')
    return out


def right_wing_local():
    return wing_feathers()


def body_paths():
    out = [
        f'M{CX},206 C236,206 224,236 226,268 C228,302 240,324 {CX},342 '
        f'C272,324 284,302 286,268 C288,236 276,206 {CX},206 Z',
        f'M246,214 C242,182 244,152 {CX},144 C268,152 270,182 266,214 Z',
        f'M{CX},120 C244,120 236,131 236,145 C236,159 245,169 {CX},171 '
        f'C267,169 276,159 276,145 C276,131 268,120 {CX},120 Z',
        f'M{CX},152 L272,161 L{CX},169 Z',
    ]
    out.append(feather(CX, 122, -90, 72, 15, bend=0.0))
    out.append(feather(249, 126, -106, 58, 12, bend=-0.1))
    out.append(feather(263, 126, -74, 58, 12, bend=0.1))
    out.append(feather(CX, 332, 90, 152, 30, bend=0.0, waist=0.45))
    out.append(feather(242, 326, 104, 134, 24, bend=-0.5, waist=0.45))
    out.append(feather(270, 326, 76, 134, 24, bend=0.5, waist=0.45))
    return out


def wing_transform(side, spread, flap_deg):
    ang = (1 - spread) * FOLD_DEG + flap_deg
    sc = FOLD_SCALE + (1 - FOLD_SCALE) * spread
    if side > 0:
        px, py = PIVOT
        return f'translate({px:.1f},{py:.1f}) rotate({ang:.2f}) scale({sc:.3f})'
    px, py = 2 * CX - PIVOT[0], PIVOT[1]
    return f'translate({px:.1f},{py:.1f}) scale(-1,1) rotate({ang:.2f}) scale({sc:.3f})'


def svg(spread=1.0, flap_deg=0.0, bg=True, fill='url(#fire)'):
    wing = ''.join(f'<path d="{d}"/>' for d in right_wing_local())
    body = ''.join(f'<path d="{d}"/>' for d in body_paths())
    rt = wing_transform(1, spread, flap_deg)
    lt = wing_transform(-1, spread, flap_deg)
    bgrect = ('<rect width="512" height="512" rx="112" fill="#141A3A"/>'
              '<circle cx="256" cy="262" r="210" fill="url(#glow)"/>') if bg else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<defs>
<linearGradient id="fire" gradientUnits="userSpaceOnUse" x1="0" y1="60" x2="0" y2="470">
<stop offset="0" stop-color="#FFE08A"/><stop offset="0.5" stop-color="#FF8A2B"/><stop offset="1" stop-color="#E5305B"/></linearGradient>
<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
<stop offset="0" stop-color="#FF8A2B" stop-opacity="0.45"/><stop offset="1" stop-color="#FF8A2B" stop-opacity="0"/></radialGradient>
</defs>
{bgrect}
<g fill="{fill}">
<g transform="{lt}">{wing}</g>
<g transform="{rt}">{wing}</g>
{body}
</g></svg>'''


def _dart():
    L = []
    L.append('// GENERATED by scripts/make_phoenix.py - do not edit.')
    L.append('//')
    L.append('// Front-facing phoenix on a 512x512 canvas for the animated connect')
    L.append('// button. The body is absolute; each wing is in LOCAL coordinates with')
    L.append('// the shoulder at the origin, so the painter rotates and scales it to')
    L.append('// fold (VPN off) or spread and flap (connecting/connected), mirroring it')
    L.append('// for the other side.')
    L.append('')
    L.append('/// Centre line of the 512 canvas.')
    L.append('const double phoenixCenterX = %.1f;' % CX)
    L.append('')
    L.append('/// Right shoulder (the wing pivot); the left mirrors across the centre.')
    L.append('const double phoenixPivotX = %.1f;' % PIVOT[0])
    L.append('const double phoenixPivotY = %.1f;' % PIVOT[1])
    L.append('')
    L.append('/// How far a wing swings down, and how much it tucks in, when folded.')
    L.append('const double phoenixFoldDegrees = %.1f;' % FOLD_DEG)
    L.append('const double phoenixFoldScale = %.2f;' % FOLD_SCALE)
    L.append('')
    L.append('/// Right wing, local coordinates (shoulder at origin), open pose.')
    L.append('const phoenixWingPaths = <String>[')
    L += ["  '%s'," % d for d in right_wing_local()]
    L.append('];')
    L.append('')
    L.append('/// Body: chest, neck, head, beak, crest and tail (absolute 512 coords).')
    L.append('const phoenixBodyPaths = <String>[')
    L += ["  '%s'," % d for d in body_paths()]
    L.append('];')
    L.append('')
    return '\n'.join(L)


if __name__ == '__main__':
    import os
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    path = os.path.join(root, 'lib/core/branding/phoenix_anim.g.dart')
    with open(path, 'w') as f:
        f.write(_dart())
    print('wrote', os.path.relpath(path, root))
