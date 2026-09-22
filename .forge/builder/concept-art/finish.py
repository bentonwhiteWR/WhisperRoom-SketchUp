# -*- coding: utf-8 -*-
"""Display-encode a V-Ray frame saved by render.rb, and measure it.

    python finish.py IN_BASE OUT.png [--stops S] [--shoulder K] [--jpg OUT.jpg]

IN_BASE is the path render.rb saved without extension (IN_BASE.exr preferred,
IN_BASE.png as fallback). save_vfb_image writes the LINEAR buffer (measured in
this repo, proposal-package.rb "THE DARK RENDERS"): a straight sRGB encode is
what the VFB shows. This adds only two things on top, both reported:
  --stops S     exposure trim in stops (default 0)
  --shoulder K  highlight roll-off start, 0..1 of display white (default 0.8;
                1.0 = a hard clip exactly like the VFB)
Prints one JSON line: source, mean luminance, clipped fraction, sizes.
"""
import json
import os
import sys

os.environ.setdefault('OPENCV_IO_ENABLE_OPENEXR', '1')
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402


def load_linear(base):
    """The frame as linear float RGB. V-Ray writes its render elements beside
    each save (observed 22 Sep 2026: OUT.denoiser.* and OUT.effectsResult.*
    next to OUT.*); the DENOISED element is preferred, float .hdr before the
    8-bit linear .png. This OpenCV has no OpenEXR, so .exr is never read."""
    import cv2
    for suffix in ('.denoiser', '.effectsResult', ''):
        hdr = base + suffix + '.hdr'
        if os.path.exists(hdr):
            a = cv2.imread(hdr, cv2.IMREAD_UNCHANGED)
            if a is not None and a.ndim == 3:
                return np.clip(a[:, :, :3][:, :, ::-1].astype(np.float32), 0, None), 'hdr' + suffix
    for suffix in ('.denoiser', '.effectsResult', ''):
        png = base + suffix + '.png'
        if os.path.exists(png):
            a = np.asarray(Image.open(png).convert('RGB')).astype(np.float32) / 255.0
            return a, 'png8-linear' + suffix
    raise SystemExit('no frame at ' + base)


def shoulder(x, k):
    if k >= 1.0:
        return np.clip(x, 0, 1)
    y = x.copy()
    hi = x > k
    y[hi] = k + (1 - k) * (1 - np.exp(-(x[hi] - k) / (1 - k)))
    return y


def srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def main(argv):
    base, out = argv[0], argv[1]
    stops = float(argv[argv.index('--stops') + 1]) if '--stops' in argv else 0.0
    k = float(argv[argv.index('--shoulder') + 1]) if '--shoulder' in argv else 0.8
    jpg = argv[argv.index('--jpg') + 1] if '--jpg' in argv else None
    lin, src = load_linear(base)
    lin = lin * (2.0 ** stops)
    disp = srgb(shoulder(lin, k))
    img = (disp * 255.0 + 0.5).astype(np.uint8)
    im = Image.fromarray(img)
    im.save(out, optimize=True)
    lum = (0.2126 * disp[..., 0] + 0.7152 * disp[..., 1] + 0.0722 * disp[..., 2])
    clip = float(np.mean(np.all(img >= 250, axis=2)))
    res = {'src': src, 'out': out, 'size': list(im.size), 'stops': stops, 'shoulder': k,
           'mean_lum': round(float(lum.mean()), 4), 'clipped': round(clip, 4),
           'dark_frac': round(float(np.mean(lum < 0.03)), 4)}
    if jpg:
        w = 2000
        h = int(round(im.height * w / im.width))
        j = im.resize((w, h), Image.LANCZOS)
        q = 85
        while True:
            j.save(jpg, 'JPEG', quality=q, optimize=True, progressive=True)
            if os.path.getsize(jpg) < 1.5 * 1024 * 1024 or q <= 60:
                break
            q -= 5
        res['jpg'] = jpg
        res['jpg_kb'] = round(os.path.getsize(jpg) / 1024.0, 1)
        res['jpg_q'] = q
    print(json.dumps(res))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
