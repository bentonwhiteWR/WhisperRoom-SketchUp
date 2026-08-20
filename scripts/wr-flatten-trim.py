# -*- coding: utf-8 -*-
"""Flatten a transparent SketchUp export onto white and trim dead margins.

    python wr-flatten-trim.py <in.png> <out.png> [--no-trim]

Called from wr-pack-export.rb with system(), the same way wr-shading.rb calls
fix-angled-alpha.py — a small Python step a Ruby script shells out to rather
than reimplementing image processing in Ruby.

SketchUp exports arrive as transparent PNGs (reference/proposal-playbook.md
section 5), and a transparent PNG must never reach a proposal pack — the
generator has no backdrop and the result over a dark page is unpredictable.
This is the automated half of that step: flatten the alpha channel onto white,
then trim the canvas down to its content bounding box plus a little padding,
because a raw SketchUp export is often 30-40% empty space around the drawing.

--no-trim is for the hero plate (01-exterior in a proposal pack): its
background IS the picture, so cropping it is wrong. Every other plate gets
trimmed. This mirrors the exact rule in the playbook — do not trim the hero.

This does NOT do the resize-to-~1900px / JPEG-quality-88 step from the same
playbook section. That is a print-prep decision made when the actual proposal
PDF gets built (see the whisperroom-proposal skill), not something a one-button
pack export should silently commit a client pack to.
"""

import sys

from PIL import Image


def flatten_trim(src, dst, trim=True, pad_frac=0.02, thresh=250):
    im = Image.open(src).convert('RGBA')
    bg = Image.new('RGB', im.size, (255, 255, 255))
    bg.paste(im, mask=im.split()[3])

    if trim:
        gray = bg.convert('L')
        # Anything at or brighter than thresh counts as empty background —
        # a little below pure white so faint dimension lines are not clipped.
        mask = gray.point(lambda p: 0 if p >= thresh else 255)
        bbox = mask.getbbox()
        if bbox:
            w, h = bg.size
            padx = int(w * pad_frac)
            pady = int(h * pad_frac)
            left = max(0, bbox[0] - padx)
            top = max(0, bbox[1] - pady)
            right = min(w, bbox[2] + padx)
            bottom = min(h, bbox[3] + pady)
            bg = bg.crop((left, top, right, bottom))

    bg.save(dst, 'PNG')
    return bg.size


def main():
    args = sys.argv[1:]
    trim = '--no-trim' not in args
    args = [a for a in args if a != '--no-trim']
    if len(args) != 2:
        print('usage: python wr-flatten-trim.py <in.png> <out.png> [--no-trim]')
        sys.exit(2)
    src, dst = args
    try:
        w, h = flatten_trim(src, dst, trim=trim)
    except Exception as e:  # noqa: BLE001 -- reported to the caller, not swallowed
        print('FAILED: %s: %s' % (type(e).__name__, e))
        sys.exit(1)
    note = '' if trim else '  (not trimmed -- hero plate)'
    print('%s -> %s  %dx%d%s' % (src, dst, w, h, note))


if __name__ == '__main__':
    main()
