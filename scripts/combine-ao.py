"""Marry the two-pass AO exports from angled-component-art.rb.

For every X_aocolor.png (opaque, ambient occlusion ON) with a sibling X.png
(transparent, AO off), write X.png with the COLOUR of the AO shot and the
ALPHA of the transparent shot, then delete the _aocolor file.

Why two passes exist at all: ambient occlusion is the soft contact shading the
viewport shows, and it tints the ENTIRE frame — background included — so a
transparent export with AO on comes back with a dead alpha channel. Rendering
the colour and the mask separately gets both.

Run AFTER fix-angled-alpha.py, on already-recovered images. The exporter
sequences that automatically.

    python scripts/combine-ao.py <folder>
"""

import glob
import os
import sys

import numpy as np
from PIL import Image


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    folder = sys.argv[1]
    pairs = sorted(glob.glob(os.path.join(folder, "*_aocolor.png")))
    if not pairs:
        print("no _aocolor.png files in %s" % folder)
        return 0

    done = skipped = 0
    for cp in pairs:
        mp = cp[: -len("_aocolor.png")] + ".png"
        if not os.path.exists(mp):
            print("  %-50s no transparent mask beside it - left alone" % os.path.basename(cp))
            skipped += 1
            continue
        col = np.array(Image.open(cp).convert("RGBA"))
        msk = np.array(Image.open(mp).convert("RGBA"))
        if col.shape != msk.shape:
            print("  %-50s size mismatch vs mask - left alone" % os.path.basename(cp))
            skipped += 1
            continue
        out = col.copy()
        out[:, :, 3] = msk[:, :, 3]
        Image.fromarray(out).save(mp)
        os.remove(cp)
        done += 1
        print("  %-50s combined" % os.path.basename(mp))

    print("\n%d combined, %d left alone" % (done, skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
