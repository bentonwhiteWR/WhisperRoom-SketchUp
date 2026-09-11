# -*- coding: utf-8 -*-
"""MEASURE a render the way the booth-render rubric measures it.

    python rank-measure.py <file-or-dir> [<file-or-dir> ...] [--json] [--jsonl OUT]

WHY THIS FILE EXISTS, and it is not a convenience.

Three rank-loop runs in a row computed these same statistics from a throwaway
script in a session scratch directory. Each run re-derived them; none of them
committed the code. The last run's `measure.py` died with its scratch dir, so
`Z:\\Sketchup\\Proposals\\test2\\.rank\\measurements.jsonl` now holds numbers
whose method no longer exists anywhere on disk.

Worse, THE CROP RECTANGLES WERE NEVER WRITTEN DOWN. The same baseline plate is
recorded as face/floor 0.53 in `test1.scores.md` and 0.47 in DEVLOG 1.65.0 --
one number, two values, because somebody picked the crop by hand, differently,
twice. That is not a measurement, it is an opinion with a decimal point.

So: the crops are NAMED CONSTANTS at the top of this file, the formulas are
here in one place, and a row in a scores table can cite this script and be
recomputed years later. If a crop ever has to move, move it HERE, bump the
METHOD stamp below, and every affected row is visibly on a different method.

WHAT IS MEASURED, and which rubric dimension each one decides:

    mean, clip, dark    D1 exposure level      (image-qa's own gate)
    med                 D1 exposure level      (0..255 median luminance)
    clip, nb            D2 highlight control
    ff                  D3 booth as subject    (face crop / floor crop)
    rb, ceil_rb         D4 colour of neutrals
    linmean, linmed     none -- for LUMEN PREDICTION only

THE LINEAR PAIR IS NOT A RUBRIC NUMBER. The render pipeline is linear in
lumens and the file carries exactly one sRGB encode on top of it (established
over six controlled renders, `.forge/fixer/ROOTCAUSE-key-light-and-2x-2026-09-11.md`).
So doubling every light doubles `linmean`, and does NOT double `mean` or
`med`. Reason about a lumen change in the linear pair; score against the rest.

`mean`, `clip` and `dark` come from the committed gate in `image-qa.py`, not
from a second implementation of the same idea -- that gate has a calibration
table tuned against Benton's own verdicts on real files and it is the thing
the project already trusts. Everything else is computed here.

UNITS, because mixing them has already cost a round trip:
    mean / clip / dark / nb   0..1 fractions
    med                       0..255
    ff / rb / ceil_rb         ratios
`image-qa`'s mean is 0..1 and `med` is 0..255. NEVER put them in one column.
"""
import glob
import importlib
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
iq = importlib.import_module("image-qa")

# ---------------------------------------------------------------------------
# THE METHOD STAMP. Cite this in a scores row next to the numbers. Any change
# to a crop, a formula, or a threshold below BUMPS THIS, so two rows carrying
# different stamps are never silently compared.
METHOD = "rank-measure/1"

# ---------------------------------------------------------------------------
# THE CROPS -- fractions of height and width, half-open [lo, hi).
#
# These reproduce the DEVLOG 1.65.0 face/floor column exactly (0.470 / 0.491 /
# 0.586 / 0.519 against the logged 0.47 / 0.50 / 0.58 / 0.52) and that is the
# whole reason they are these numbers and not rounder ones. They were pinned
# in the rubric on 11 Sep 2026 and are copied here VERBATIM.
#
# THEY ARE VALID ONLY WHILE THE CAMERA IS FIXED. They are a fixed rectangle on
# a fixed plate, not a detector that finds the booth. Move the camera and
# `ff` stops meaning "booth over floor" -- it does not fail, it quietly lies.
# Any cycle that moves the camera invalidates every `ff` in the table.
FACE_CROP = (0.30, 0.70, 0.32, 0.60)   # y0, y1, x0, x1 -- the booth's front face
FLOOR_CROP = (0.85, 1.00, 0.00, 1.00)  # the floor in front of it
CEIL_BAND = (0.00, 0.10, 0.00, 1.00)   # the room's painted-white ceiling

# The flat-polygon / blown-patch signature: bright AND almost perfectly
# neutral, in a frame whose light is warm everywhere else. A real lit surface
# under a 3500-4200 K lamp is never both.
NB_L_MIN = 180.0    # luminance above which a pixel counts as "bright"
NB_RB_MAX = 8.0     # |R - B| below which it counts as "perfectly neutral"

DARK_L = 32.0       # the rubric's "squint into it" level

RENDER_GLOB = "*01-angled r.png"   # the one plate this loop renders


def _crop(a, box):
    h, w = a.shape[:2]
    y0, y1, x0, x1 = box
    return a[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]


def luminance(a):
    """Rec.709 luma on 0..255 sRGB-encoded values."""
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def to_linear(a):
    """Undo the sRGB transfer. a is 0..255; the result is 0..1 linear."""
    s = a / 255.0
    return np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)


def measure(path):
    m = iq.measure(path)
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    lum = luminance(a)
    lin = to_linear(a)
    lin_lum = 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]

    face = _crop(lum, FACE_CROP).mean()
    floor = _crop(lum, FLOOR_CROP).mean()
    ceil = _crop(a, CEIL_BAND)

    nb = ((lum > NB_L_MIN) & (np.abs(a[..., 0] - a[..., 2]) < NB_RB_MAX)).mean()

    return {
        "method": METHOD,
        "file": os.path.basename(path),
        "size": [int(a.shape[1]), int(a.shape[0])],
        # D1
        "mean": round(float(m["mean_luminance"]), 4),
        "med": round(float(np.median(lum)), 2),
        "dark": round(float((lum < DARK_L).mean()), 4),
        # D2
        "clip": round(float(m["clipped_fraction"]), 4),
        "nb": round(float(nb), 4),
        # D3
        "ff": round(float(face / floor), 4),
        "face_L": round(float(face), 2),
        "floor_L": round(float(floor), 2),
        # D4
        "rb": round(float(a[..., 0].mean() / a[..., 2].mean()), 4),
        "ceil_rb": round(float(ceil[..., 0].mean() / ceil[..., 2].mean()), 4),
        # lumen prediction only -- NOT a rubric number
        "linmean": round(float(lin.mean()), 5),
        "linmed": round(float(np.median(lin_lum)), 5),
    }


def targets(args):
    for a in args:
        if os.path.isdir(a):
            hit = sorted(glob.glob(os.path.join(a, RENDER_GLOB)))
            if not hit:
                print("%s: no file matching %r" % (a, RENDER_GLOB), file=sys.stderr)
            for f in hit:
                yield f
        elif os.path.isfile(a):
            yield a
        else:
            print("%s: not found" % a, file=sys.stderr)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    as_json = "--json" in sys.argv
    jsonl = None
    if "--jsonl" in sys.argv:
        jsonl = sys.argv[sys.argv.index("--jsonl") + 1]
    if not args:
        print(__doc__)
        return 2
    rows = []
    for f in targets(args):
        r = measure(f)
        rows.append(r)
        if as_json:
            print(json.dumps(r))
        else:
            print("%-34s mean %.4f  med %6.2f  clip %.4f  dark %.4f  "
                  "ff %.4f  rb %.4f  ceil_rb %.4f  nb %.4f  lin %.5f/%.5f"
                  % (r["file"], r["mean"], r["med"], r["clip"], r["dark"],
                     r["ff"], r["rb"], r["ceil_rb"], r["nb"],
                     r["linmean"], r["linmed"]))
    if jsonl:
        with open(jsonl, "a", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
