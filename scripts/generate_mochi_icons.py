#!/usr/bin/env python3
"""Draw Mochi's pink robot mascot and populate the existing iOS icon catalog.

No dependencies beyond the Python standard library. RGB artwork has no
transparency, satisfying iOS marketing-icon requirements.
"""
import json
import math
import pathlib
import re
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
P = (250, 122, 178)
DARK = (76, 28, 70)
WHITE = (255, 248, 253)

def mix(a, b, t):
    return tuple(int(a[k] * (1-t) + b[k] * t) for k in range(3))

def ellipse(x, y, cx, cy, rx, ry):
    return ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1

def rounded(x, y, x1, y1, x2, y2, r):
    dx = max(x1 + r - x, 0, x - (x2-r))
    dy = max(y1 + r - y, 0, y - (y2-r))
    return x1+r <= x <= x2-r and y1 <= y <= y2 or (
        y1+r <= y <= y2-r and x1 <= x <= x2) or dx*dx+dy*dy <= r*r

def pixel(x, y):
    # Coordinates are normalized across all required icon sizes.
    bg = mix((255, 181, 213), (217, 62, 139), min(1, .25*x+.7*y))
    # Soft luminous halo
    dist = math.hypot((x-.50)/.60, (y-.47)/.60)
    if dist < 1: bg = mix(bg, (255, 228, 243), (1-dist)*.20)
    # Antenna and tiny heart.
    if rounded(x, y, .484, .17, .517, .29, .016):
        bg = (121, 40, 100)
    if (ellipse(x,y,.47,.157,.055,.06) or ellipse(x,y,.53,.157,.055,.06)
            or (abs(x-.5)*1.25 + (y-.17)*.7 < .071 and y>.17)):
        bg = (255, 75, 151)
    # Headphone headband and ear cups
    if ellipse(x, y, .5, .49, .37, .385) and not ellipse(x,y,.5,.54,.285,.31):
        bg = DARK
    if rounded(x,y,.11,.41,.235,.70,.065) or rounded(x,y,.765,.41,.89,.70,.065):
        bg = (116, 34, 92)
    if rounded(x,y,.145,.45,.24,.675,.04) or rounded(x,y,.76,.45,.855,.675,.04):
        bg = (255, 123, 185)
    # Main rounded mochi face
    if ellipse(x,y,.5,.575,.325,.30):
        bg = mix((255, 249, 254), (255, 192, 223), min(1, (y-.3)*.6))
    if ellipse(x,y,.5,.575,.29,.268):
        bg = mix((255, 252, 253), (255, 227, 241), (y-.3)*.22)
    # Blush
    if ellipse(x,y,.285,.664,.073,.043) or ellipse(x,y,.715,.664,.073,.043):
        bg = (255, 167, 204)
    # Eyes and little star glints
    if ellipse(x,y,.385,.554,.068,.095) or ellipse(x,y,.615,.554,.068,.095):
        bg = (85, 34, 83)
    if ellipse(x,y,.366,.520,.022,.029) or ellipse(x,y,.596,.520,.022,.029):
        bg = WHITE
    if ellipse(x,y,.406,.575,.010,.012) or ellipse(x,y,.636,.575,.010,.012):
        bg = (255, 185, 222)
    # Tiny smile
    if ellipse(x,y,.50,.68,.065,.035) and y>.682:
        bg = (143, 52, 106)
    if ellipse(x,y,.50,.69,.041,.016) and y>.688:
        bg = (255, 238, 247)
    # Glossy upper-left light reflection
    if ellipse(x,y,.37,.351,.10,.024):
        bg = mix(bg, WHITE, .6)
    return bg

def save_png(path, n):
    # 4x subpixel sampling for small icons gives smooth edges.
    rows = []
    samples = 2 if n < 256 else 1
    for j in range(n):
        row = bytearray([0])
        for i in range(n):
            colors = [pixel((i+(a+.5)/samples)/n,
                            (j+(b+.5)/samples)/n)
                      for a in range(samples) for b in range(samples)]
            row.extend(sum(c[cidx] for c in colors)//len(colors)
                       for cidx in range(3))
        rows.append(bytes(row))
    def chunk(name, data):
        return (struct.pack('>I',len(data))+name+data+
                struct.pack('>I',zlib.crc32(name+data)&0xffffffff))
    payload = (b'\\x89PNG\\r\\n\\x1a\\n'
        +chunk(b'IHDR',struct.pack('>2I5B',n,n,8,2,0,0,0))
        +chunk(b'IDAT',zlib.compress(b''.join(rows),6))
        +chunk(b'IEND',b''))
    path.write_bytes(payload)

def main():
    catalog = json.loads((ICON_DIR/'Contents.json').read_text())
    sizes = {}
    for asset in catalog['images']:
        scale = int(asset.get('scale','1x').removesuffix('x'))
        base = float(asset['size'].split('x')[0])
        sizes[asset['filename']] = int(base*scale)
    for name, side in sizes.items():
        save_png(ICON_DIR/name,side)
        print('Mochi icon',name,side)

if __name__ == '__main__':
    main()
