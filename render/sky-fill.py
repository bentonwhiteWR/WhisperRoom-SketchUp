"""Flood the blue V-Ray sky behind a 03 overhead cutaway to white, from the corners and edge midpoints.
Generalised from the KCUR job's one-off fill (same seeds, test and threshold). The first run keeps the unfilled
frame as raw/<name>-unfilled.png, and every run fills from that copy, so it is safe to repeat.
    python render/sky-fill.py --dir "<WORK>/<client>-renders" "R1A-03-overhead-cutaway.png" ...
Only blue-ish, non-white seed pixels are filled (b > 225 and b - r > 15), never floor or wall."""
import os, shutil, sys
from PIL import Image, ImageDraw


def opt(a, k, d):
    return a[a.index(k) + 1] if k in a else d


def main(a):
    d = opt(a, '--dir', None)
    if not d:
        sys.exit('sky-fill.py: --dir <renders folder> is required')
    names = [x for i, x in enumerate(a) if x != '--dir' and (i == 0 or a[i - 1] != '--dir')]
    for n in names:
        p = os.path.join(d, n)
        stem = os.path.splitext(n)[0]
        raw = os.path.join(d, 'raw', '%s-unfilled.png' % stem)
        os.makedirs(os.path.dirname(raw), exist_ok=True)
        if not os.path.exists(raw):
            shutil.copyfile(p, raw)
        im = Image.open(raw).convert('RGB'); w, h = im.size; seeds = 0
        for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1)):
            r, g, b = im.getpixel(xy)
            if b > 225 and b - r > 15 and (r, g, b) != (255, 255, 255):   # sky only, never floor/wall
                ImageDraw.floodfill(im, xy, (255, 255, 255), thresh=28); seeds += 1
        im.save(p); print(n, 'seeds', seeds)


if __name__ == '__main__':
    main(sys.argv[1:])
