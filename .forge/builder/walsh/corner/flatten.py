# Flatten transparent PNGs onto white and trim dead margins (playbook s5). Usage: python flatten.py <png>...
import sys
from PIL import Image, ImageChops
for p in sys.argv[1:]:
    im = Image.open(p).convert('RGBA')
    bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
    flat = Image.alpha_composite(bg, im).convert('RGB')
    diff = ImageChops.difference(flat, Image.new('RGB', flat.size, (255, 255, 255)))
    box = diff.getbbox()
    if box:
        pad = 24
        box = (max(0, box[0]-pad), max(0, box[1]-pad), min(flat.width, box[2]+pad), min(flat.height, box[3]+pad))
        flat = flat.crop(box)
    flat.save(p)
    print('flattened', p, flat.size)
