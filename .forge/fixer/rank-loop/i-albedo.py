# -*- coding: utf-8 -*-
"""RUN i, TASK 2 -- measure a floor material's TRUE linear albedo, and derive a
corrected diffuse map from it.

    python i-albedo.py measure <texture.png> [...]
    python i-albedo.py rescale <in.png> <out.png> <target_linear_luminance>

WHY THIS FILE EXISTS.

Run h concluded that SketchUp's own library `.skm` materials "render in V-Ray at
roughly twice their own albedo, hue preserved", and run i was told to verify that
before building on it. The claim had been derived by comparing a texture's
ENCODED mean (`L 78`) against a RENDERED band luminance (`L 169.7`) -- two
quantities in different units, one of which depends on how the surface is lit.
That comparison cannot establish a factor.

Two things had to be measured properly instead, and both are here:

1. **The true linear albedo of a texture.** `Sketchup::Material#color` returns the
   texture's average as an ENCODED sRGB triple. Decoding that average is NOT the
   same as averaging the decoded pixels, because the transfer curve is non-linear
   -- and a plank texture with dark grain lines has plenty of curvature to work
   with. Measured on the seven floors of run h, the bias runs 1.01 to 1.07, so it
   is small -- but it had to be measured rather than assumed, because if it had
   been 2.0 the whole finding would have been an averaging artifact.

2. **What V-Ray actually holds.** For every material in the model that has a real
   `BRDFVRayMtl`, its `diffuse_color` equals the texture's true linear albedo as
   computed here (observed, 11 Sep 2026):

       Concrete Simple C01 200cm   V-Ray 0.2549/0.2471/0.2471  measured 0.2398 lum
       Oak Honey Semigloss 300cm   V-Ray 0.2824/0.1765/0.0824  measured 0.2747/0.1801/0.0838
       WhisperRoom Floor Carpet    V-Ray 0.0296               measured 0.0305

   So this file's units and V-Ray's units are the same units, and a diffuse map
   written here lands in V-Ray at the value it was written for.

`rescale` is the build step: it decodes the map to linear, multiplies every pixel
by a single constant so the map's linear luminance hits a target, and re-encodes.
A CONSTANT MULTIPLY IS DELIBERATE -- it preserves hue exactly and preserves the
map's contrast ratio, which a gamma change would not. It prints the fraction of
pixels the multiply drives over 1.0; if that is not zero the target is too high
for this map and the result would be a clipped, detail-free floor.
"""
import os
import sys

import numpy as np
from PIL import Image

REC709 = (0.2126, 0.7152, 0.0722)


def to_linear(a):
    """Undo the sRGB transfer. a is 0..255; the result is 0..1 linear."""
    s = a / 255.0
    return np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)


def to_encoded(y):
    """Apply the sRGB transfer. y is 0..1 linear; the result is 0..255."""
    y = np.clip(y, 0.0, 1.0)
    return np.where(y <= 0.0031308, y * 12.92, 1.055 * y ** (1 / 2.4) - 0.055) * 255.0


def lum(rgb):
    return REC709[0] * rgb[0] + REC709[1] * rgb[1] + REC709[2] * rgb[2]


def measure(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    enc = a.reshape(-1, 3).mean(axis=0)
    lin = to_linear(a).reshape(-1, 3).mean(axis=0)
    enc_l = lum(enc)
    # the naive route: decode the ENCODED average, which is what reading
    # Material#color and decoding it would give you
    naive = float(to_linear(np.array([enc_l]))[0])
    return {
        "file": os.path.basename(path),
        "encoded_rgb": [round(v, 1) for v in enc],
        "encoded_L": round(enc_l, 1),
        "linear_albedo_rgb": [round(v, 4) for v in lin],
        "linear_albedo_lum": round(float(lum(lin)), 4),
        "decode_of_average": round(naive, 4),
        "averaging_bias": round(float(lum(lin)) / naive, 3),
        "linear_max_rgb": [round(v, 4) for v in to_linear(a).reshape(-1, 3).max(axis=0)],
        "R_over_B": round(float(lin[0] / lin[2]), 3),
    }


def rescale(src, dst, target):
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float64)
    lin = to_linear(a)
    have = float(lum(lin.reshape(-1, 3).mean(axis=0)))
    k = target / have
    scaled = lin * k
    over = float((scaled > 1.0).mean())
    Image.fromarray(np.clip(to_encoded(scaled), 0, 255).astype(np.uint8)).save(dst)
    back = measure(dst)
    print("source            linear albedo lum %.4f   R/B %.3f" % (have, lin.reshape(-1, 3).mean(axis=0)[0] / lin.reshape(-1, 3).mean(axis=0)[2]))
    print("target            %.4f   -> constant multiply k = %.4f" % (target, k))
    print("pixels over 1.0   %.4f%%  (must be 0 -- anything else clips the map)" % (100 * over))
    print("written           %s" % dst)
    print("VERIFY            linear albedo lum %.4f   R/B %.3f   encoded mean %.1f"
          % (back["linear_albedo_lum"], back["R_over_B"], lum(back["encoded_rgb"])))
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "measure":
        for p in sys.argv[2:]:
            m = measure(p)
            print("%-30s enc rgb %s L %6.1f | TRUE linear albedo %.4f (rgb %s) | "
                  "decode(avg) %.4f | averaging bias %.2f | R/B %.3f"
                  % (m["file"], m["encoded_rgb"], m["encoded_L"],
                     m["linear_albedo_lum"], m["linear_albedo_rgb"],
                     m["decode_of_average"], m["averaging_bias"], m["R_over_B"]))
        return 0
    if cmd == "rescale":
        if len(sys.argv) != 5:
            print(__doc__)
            return 2
        return rescale(sys.argv[2], sys.argv[3], float(sys.argv[4]))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
