"""Undo SketchUp 2024's dark composite on exported PNGs.

SketchUp 24.0.553's new graphics engine composites a uniform 75% black layer
over anything write_image produces — in the colour channels AND the alpha
channel. The viewport looks correct; only the export is affected.

    out_rgb   = 0.25 * src_rgb
    out_alpha = 191.25 + 0.25 * src_alpha

Both were measured exactly, not fitted:

  * a wireframe export contains only the values {0, 4, 8, ... 64} — multiples
    of four, capped at 64 = 255 * 0.25. A linear multiply, so not gamma.
  * alpha never falls below 191 and never exceeds 255, and every anti-aliased
    edge pixel lands on the value the formula predicts.

So the transform is exactly invertible, and this script inverts it.

THE REAL FIX IS UPSTREAM. Before relying on this, try:

    Window > Preferences > Graphics > use the Classic graphics engine,
    restart SketchUp, re-export.

If that clears it, delete this script — recovering 8-bit channels from a
quarter of their range costs two bits of colour depth, which is invisible on
line art and mild but real banding on shaded fabric.

    python scripts/fix-angled-alpha.py <folder> [--inplace]

Writes <name>_fixed.png beside each file, or overwrites with --inplace.
Files that do not carry the signature are reported and left alone.
"""

import os
import sys
import glob

import numpy as np
from PIL import Image

SCALE = 4.0            # 1 / 0.25
ALPHA_FLOOR = 191.25   # 255 * 0.75


def has_signature(a):
    """Only touch files that actually carry the composite."""
    rgb_max = int(a[:, :, :3].max())
    alpha_min = int(a[:, :, 3].min())
    # The tell is a hard colour ceiling at ~64 together with an alpha floor
    # at ~191. Either alone could be a legitimately dark or opaque image.
    return rgb_max <= 70 and alpha_min >= 188


def fix(path, inplace=False):
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(np.float64)

    if not has_signature(a):
        return False, "no signature — left alone"

    rgb = np.clip(a[:, :, :3] * SCALE, 0, 255)
    alpha = np.clip((a[:, :, 3] - ALPHA_FLOOR) * SCALE, 0, 255)

    out = np.dstack([rgb, alpha]).round().astype(np.uint8)
    dst = path if inplace else path[:-4] + "_fixed.png"
    Image.fromarray(out).save(dst)
    clear = float((alpha < 1).mean() * 100)
    return True, "%s  (%.1f%% now fully transparent)" % (os.path.basename(dst), clear)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    inplace = "--inplace" in sys.argv
    if not args:
        print(__doc__)
        return 1

    folder = args[0]
    files = sorted(glob.glob(os.path.join(folder, "*.png")))
    files = [f for f in files if not f.endswith("_fixed.png")]
    if not files:
        print("no PNGs in %s" % folder)
        return 1

    done = skipped = 0
    for f in files:
        ok, note = fix(f, inplace)
        print("  %-44s %s" % (os.path.basename(f), note))
        done += 1 if ok else 0
        skipped += 0 if ok else 1

    print("\n%d recovered, %d left alone" % (done, skipped))
    if done:
        print("Reminder: the upstream fix is the Classic graphics engine in")
        print("Window > Preferences > Graphics. This is the salvage path.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
