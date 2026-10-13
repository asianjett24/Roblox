"""Builds assets/ui/ui_atlas.png (1024x1024) and src/client/UIAtlas.lua (where each sprite is).

Icons: game-icons.net (CC BY 3.0, see CREDITS.md), turned into outlined "sticker" icons.
Everything else (halftones, rays, glow, shadow, vignette, gloss, waves, stripes) is generated here.

Icons are drawn in light greys with a dark ink outline so the game can tint them to any colour
(ImageColor3 multiplies the image). Run:  pip install cairosvg pillow numpy && python build_atlas.py
"""
import io, math, os
import numpy as np
import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SIZE = 1024
INK = (22, 26, 48)
atlas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
sprites = {}  # name -> (x, y, w, h, extra)

# name in game -> icon file
ICONS = [
    ('bag', 'fish-bucket'), ('shop', 'trident'), ('book', 'open-book'), ('pearl', 'oyster-pearl'),
    ('coin', 'two-coins'), ('coins', 'coins-pile'), ('gem', 'gems'), ('fish', 'clownfish'),
    ('fishes', 'double-fish'), ('shark', 'shark-jaws'), ('fin', 'shark-fin'), ('bubbles', 'bubbles'),
    ('flippers', 'swimfins'), ('tank', 'scuba-tanks'), ('helmet', 'diving-helmet'), ('plus', 'health-normal'),
    ('check', 'check-mark'), ('alert', 'hazard-sign'), ('crown', 'crown'), ('sprint', 'sprint'),
    ('sack', 'swap-bag'), ('chest', 'open-treasure-chest'), ('dash', 'wind-slap'), ('trophy', 'trophy-cup'),
    ('lock', 'padlock'), ('sun', 'sun'), ('coral', 'coral'), ('angler', 'angler-fish'),
    ('tentacle', 'kraken-tentacle'), ('serpent', 'sea-serpent'), ('dragon', 'sea-dragon'), ('sparkles', 'sparkles'),
    ('help', 'help'), ('bite', 'shark-bite'), ('tag', 'price-tag'), ('star', 'beveled-star'),
]
CELL = 128


def svg_mask(name, px):
    svg = open(os.path.join(HERE, 'icons', name + '.svg')).read().replace('currentColor', '#ffffff')
    svg = svg.replace('<svg ', f'<svg width="{px}" height="{px}" ', 1)
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert('RGBA')
    return im.getchannel('A')


def dilate(mask, r):
    return mask.filter(ImageFilter.MaxFilter(r * 2 + 1))


def sticker(mask, px=CELL):
    """White-grey shaded icon with a thick ink outline, gloss and a soft drop shadow."""
    w, h = mask.size
    out = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    ox, oy = (px - w) // 2, (px - h) // 2 - 3
    m = Image.new('L', (px, px), 0)
    m.paste(mask, (ox, oy))
    m = m.point(lambda v: 255 if v > 110 else 0)
    outline = dilate(m, 6)
    shadow = outline.filter(ImageFilter.GaussianBlur(2))
    sh = Image.new('RGBA', (px, px), INK + (0,))
    sh.putalpha(shadow.point(lambda v: int(v * 0.45)))
    out.alpha_composite(sh, (0, 5))
    ink = Image.new('RGBA', (px, px), INK + (255,))
    ink.putalpha(outline)
    out.alpha_composite(ink)
    # fill: light grey gradient (top 236 -> bottom 168) so a tint keeps its shading
    grad = np.zeros((px, px, 4), np.uint8)
    for y in range(px):
        t = y / (px - 1)
        v = int(236 - 68 * t)
        grad[y, :, :3] = v
    grad[..., 3] = np.array(m)
    fill = Image.fromarray(grad, 'RGBA')
    out.alpha_composite(fill)
    # gloss: the top part of the shape, brighter
    gl = Image.new('L', (px, px), 0)
    ImageDraw.Draw(gl).ellipse((-px * 0.2, -px * 0.62, px * 1.2, px * 0.42), fill=255)
    gl = ImageChops.multiply(gl, m.filter(ImageFilter.MinFilter(5)))
    shine = Image.new('RGBA', (px, px), (255, 255, 255, 0))
    shine.putalpha(gl.point(lambda v: int(v * 0.55)))
    out.alpha_composite(shine)
    # inner edge highlight along the top-left
    return out


def place(name, img, x, y, extra=None):
    atlas.alpha_composite(img, (x, y))
    sprites[name] = (x, y, img.size[0], img.size[1], extra)


# --- icons -----------------------------------------------------------------------------------
for i, (name, file) in enumerate(ICONS):
    x, y = (i % 8) * CELL, (i // 8) * CELL
    icon_px = 92 if name not in ('plus', 'check') else 80
    place(name, sticker(svg_mask(file, icon_px)), x, y)

# a clean "X" for close buttons: the plus rotated 45 degrees
plus_mask = svg_mask('health-normal', 78).rotate(45, resample=Image.BICUBIC, expand=False)
i = len(ICONS)
place('close', sticker(plus_mask), (i % 8) * CELL, (i // 8) * CELL)
i += 1
# a down arrow (depth)
arrow = Image.new('L', (90, 90), 0)
ad = ImageDraw.Draw(arrow)
ad.rounded_rectangle((33, 6, 57, 52), radius=8, fill=255)
ad.polygon([(10, 44), (80, 44), (45, 86)], fill=255)
place('down', sticker(arrow), (i % 8) * CELL, (i // 8) * CELL)
i += 1
# empty cells left: i .. 39

# --- textures (row 5+, y = 640) ----------------------------------------------------------------
Y0 = 640


def halftone_tile(n=128, step=16, r=4.2):
    im = Image.new('RGBA', (n * 4, n * 4), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    s = 4
    for gy in range(0, n, step):
        for gx in range(0, n, step):
            for ox in (0, step / 2):
                cx, cy = (gx + step / 2 + ox) * s, (gy + step / 2 + (step / 2 if ox else 0)) * s
                d.ellipse((cx - r * s, cy - r * s, cx + r * s, cy + r * s), fill=(255, 255, 255, 255))
    im = im.resize((n, n), Image.LANCZOS)
    return im


def halftone_fade(w=128, h=256, step=16):
    s = 4
    im = Image.new('RGBA', (w * s, h * s), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    rows = h // (step // 2)
    for j in range(rows + 1):
        cy = j * (step / 2)
        t = cy / h
        r = max(0.0, (t ** 1.4) * step * 0.55)
        off = (step / 2) if j % 2 else 0
        for gx in range(-1, w // step + 1):
            cx = gx * step + off + step / 2
            if r > 0.3:
                d.ellipse(((cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s), fill=(255, 255, 255, 255))
    return im.resize((w, h), Image.LANCZOS)


def burst(n=256, rays=16):
    s = 2
    im = Image.new('L', (n * s, n * s), 0)
    d = ImageDraw.Draw(im)
    c = n * s / 2
    for k in range(rays):
        a0 = (k / rays) * 2 * math.pi
        a1 = a0 + math.pi / rays
        d.polygon([(c, c), (c + math.cos(a0) * c * 1.5, c + math.sin(a0) * c * 1.5), (c + math.cos(a1) * c * 1.5, c + math.sin(a1) * c * 1.5)], fill=255)
    im = im.resize((n, n), Image.LANCZOS)
    yy, xx = np.mgrid[0:n, 0:n]
    dist = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    fall = np.clip(1 - dist, 0, 1) ** 1.2
    a = (np.array(im) * fall).astype(np.uint8)
    out = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out.putalpha(Image.fromarray(a))
    return out


def radial(n=128, power=1.6, invert=False):
    yy, xx = np.mgrid[0:n, 0:n]
    dist = np.sqrt((xx - (n - 1) / 2) ** 2 + (yy - (n - 1) / 2) ** 2) / (n / 2)
    if invert:
        a = np.clip((dist - 0.45) / 0.65, 0, 1) ** 1.5
    else:
        a = np.clip(1 - dist, 0, 1) ** power
    out = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    return out


def soft_shadow(n=128, radius=26, blur=12):
    m = Image.new('L', (n, n), 0)
    pad = blur * 2
    ImageDraw.Draw(m).rounded_rectangle((pad, pad, n - pad, n - pad), radius=radius, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new('RGBA', (n, n), INK + (0,))
    out.putalpha(m)
    return out


def gloss(n=128):
    yy = np.mgrid[0:n, 0:n][0] / (n - 1)
    a = np.clip(0.55 - yy * 0.9, 0, 1) * 255
    out = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out.putalpha(Image.fromarray(a.astype(np.uint8)))
    return out


def stripes(n=128, step=32):
    s = 4
    im = Image.new('L', (n * s, n * s), 0)
    d = ImageDraw.Draw(im)
    for k in range(-n * 2, n * 2, step):
        d.polygon([(k * s, 0), ((k + step / 2) * s, 0), ((k + step / 2 + n) * s, n * s), ((k + n) * s, n * s)], fill=255)
    im = im.resize((n, n), Image.LANCZOS)
    out = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out.putalpha(im)
    return out


def wave_strip(w=512, h=64, waves=4, amp=10, fill_below=True):
    s = 4
    im = Image.new('L', (w * s, h * s), 0)
    pts = []
    for x in range(0, w * s + 1, 4):
        t = x / (w * s) * waves * 2 * math.pi
        y = (h * 0.45 + math.sin(t) * amp) * s
        pts.append((x, y))
    poly = pts + [(w * s, h * s), (0, h * s)]
    ImageDraw.Draw(im).polygon(poly, fill=255)
    im = im.resize((w, h), Image.LANCZOS)
    out = Image.new('RGBA', (w, h), (255, 255, 255, 0))
    out.putalpha(im)
    return out


def ring(n=64, width=7):
    s = 4
    m = Image.new('L', (n * s, n * s), 0)
    ImageDraw.Draw(m).ellipse((width * s / 2, width * s / 2, (n - width / 2) * s, (n - width / 2) * s), outline=255, width=width * s)
    m = m.resize((n, n), Image.LANCZOS)
    out = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out.putalpha(m)
    return out


def bubble(n=64):
    s = 4
    im = Image.new('RGBA', (n * s, n * s), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((4 * s, 4 * s, (n - 4) * s, (n - 4) * s), fill=(255, 255, 255, 60), outline=(255, 255, 255, 230), width=4 * s)
    d.ellipse((16 * s, 13 * s, 28 * s, 23 * s), fill=(255, 255, 255, 230))
    return im.resize((n, n), Image.LANCZOS)


place('halftone', halftone_tile(), 0, Y0, {'tile': True})
place('halftone_fade', halftone_fade(), 128, Y0)
place('burst', burst(), 256, Y0)
place('glow', radial(), 512, Y0)
place('shadow', soft_shadow(), 640, Y0, {'slice': (40, 40, 88, 88)})
place('vignette', radial(invert=True), 768, Y0)
place('gloss', gloss(), 896, Y0)
place('stripes', stripes(), 0, 768, {'tile': True})
place('ring', ring(), 512, 768)
place('bubble', bubble(), 576, 768)
place('halftone_small', halftone_tile(64, 8, 2.1), 640, 768, {'tile': True})
place('wave', wave_strip(), 0, 896, {'tile': True})
place('wave_soft', wave_strip(512, 64, 3, 7), 0, 960, {'tile': True})

atlas.save(os.path.join(HERE, 'ui_atlas.png'))

# --- Lua table --------------------------------------------------------------------------------
lines = [
    '-- Generated by assets/ui/build_atlas.py. Where each sprite sits in assets/ui/ui_atlas.png.',
    '-- Upload ui_atlas.png to Roblox once and put its ID in Config.UIAtlasId (see README).',
    'return {',
    f'\tSize = {SIZE},',
    '\tSprites = {',
]
for name, (x, y, w, h, extra) in sprites.items():
    ext = ''
    if extra and extra.get('slice'):
        a, b, c, d2 = extra['slice']
        ext = f', Slice = {{ {a}, {b}, {c}, {d2} }}'
    if extra and extra.get('tile'):
        ext += ', Tile = true'
    key = name if name.isidentifier() else f'["{name}"]'
    lines.append(f'\t\t{key} = {{ {x}, {y}, {w}, {h}{ext} }},')
lines += ['\t},', '}', '']
open(os.path.join(ROOT, 'src', 'client', 'UIAtlas.lua'), 'w').write('\n'.join(lines))
print('atlas with', len(sprites), 'sprites')
