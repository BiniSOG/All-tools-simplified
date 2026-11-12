"""Regenerates every Android and iOS launcher icon from assets/icon_source.jpg.

Run from the project root:  python3 tool/make_icons.py   (needs Pillow and numpy)
"""
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src = Image.open('assets/icon_source.jpg').convert('RGB')

# 1. Find the white area outside the rounded square by flood-filling from the corners.
probe = src.copy()
key = (255, 0, 255)
w, h = probe.size
for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]:
    ImageDraw.floodfill(probe, xy, key, thresh=60)
outside = Image.fromarray(((np.asarray(probe) == key).all(axis=2) * 255).astype('uint8'))
outside = outside.filter(ImageFilter.MaxFilter(9))  # swallow the pale halo around the edge
inside = Image.eval(outside, lambda v: 255 - v)

# 2. Crop to the artwork and make it square.
box = inside.getbbox()
side = max(box[2] - box[0], box[3] - box[1])
art = Image.new('RGBA', (side, side), (0, 0, 0, 0))
rgba = src.convert('RGBA')
rgba.putalpha(inside)
art.paste(rgba.crop(box), ((side - (box[2] - box[0])) // 2, (side - (box[3] - box[1])) // 2))
art = art.resize((1024, 1024), Image.LANCZOS)          # rounded square on transparency

# 3. Full-bleed version: extend the edge colours into the corners (alpha-weighted blur).
a = np.asarray(art).astype('float32') / 255
alpha = a[..., 3:4]
def blur(arr, r):
    return np.asarray(Image.fromarray((arr.clip(0, 1) * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(r))).astype('float32') / 255
num = np.dstack([blur(a[..., i] * alpha[..., 0], 40) for i in range(3)])
den = blur(alpha[..., 0], 40)[..., None].clip(1e-3, 1)
fill = num / den
full = Image.fromarray(((a[..., :3] * alpha + fill * (1 - alpha)).clip(0, 1) * 255).astype('uint8'), 'RGB')
full.save('assets/icon.png')

# Android: legacy icons keep the rounded shape; adaptive icons get a full-bleed foreground.
res = 'android/app/src/main/res'
for name, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    art.resize((px, px), Image.LANCZOS).save(f'{res}/mipmap-{name}/ic_launcher.png')
    fg_px = px * 108 // 48
    # Scale the artwork to 70% so launchers that crop to a circle keep the text visible.
    big = full.resize((int(fg_px / 0.70),) * 2, Image.BICUBIC).filter(ImageFilter.GaussianBlur(fg_px * 0.12))
    off = (big.width - fg_px) // 2
    fg = big.crop((off, off, off + fg_px, off + fg_px))
    inner = int(fg_px * 0.70)
    fg.paste(full.resize((inner, inner), Image.LANCZOS), ((fg_px - inner) // 2,) * 2)
    fg.save(f'{res}/mipmap-{name}/ic_launcher_foreground.png')

# iOS: square, opaque; the system applies its own corner mask.
ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for img in json.load(open(f'{ios}/Contents.json'))['images']:
    px = round(float(img['size'].split('x')[0]) * int(img['scale'][0]))
    full.resize((px, px), Image.LANCZOS).save(f"{ios}/{img['filename']}")
print('icons written')
