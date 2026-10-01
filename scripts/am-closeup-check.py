# -*- coding: utf-8 -*-
"""CHECK a close-up export folder against its own _closeups.json.

    python scripts/am-closeup-check.py [FOLDER] [--ref SPRITE.png] [--tol 6]

FOLDER defaults to Z:/Sketchup/BoothBuilderViews/AssemblyCloseups. Per image row:

    file     the PNG exists and is exactly w x h
    blank    some of the frame is opaque (>= 0.5%) and the opaque pixels are
             neither black nor blown (mean luma 0.08 .. 0.97) — the two ways a
             SketchUp export fails without failing
    style    the row says it was rendered in the Interior style
    anchors  every in-frame anchor has a red dot in _anchorcheck/<file> within
             --tol px (default 6) of the pixel the JSON gives. The dots were
             drawn at the anchors' 3D points by the exporter, so this measures
             whether its projection maths matches what SketchUp rendered.
    scale    every variant of one shot shares one in/px (the constant-scale rule)
    luma     with --ref, the mean luma of the opaque pixels is within 10% of the
             reference sprite's (e.g. a DoorCombos Iso30 image of the same part)

Exits 0 only when every check passes. Prints one line per check, named.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

DEF = 'Z:/Sketchup/BoothBuilderViews/AssemblyCloseups'


def luma_stats(path):
    a = np.asarray(Image.open(path).convert('RGBA')).astype(np.float64)
    alpha = a[:, :, 3]
    opaque = alpha > 127
    cover = float(opaque.mean())
    if not opaque.any():
        return a.shape[1], a.shape[0], cover, None
    rgb = a[:, :, :3][opaque] / 255.0
    y = 0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]
    return a.shape[1], a.shape[0], cover, float(y.mean())


def red_pixels(path):
    a = np.asarray(Image.open(path).convert('RGBA')).astype(np.int32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    m = (al > 100) & (r > 40) & (r > 2.5 * g) & (r > 2.5 * b)
    ys, xs = np.nonzero(m)
    return np.stack([xs, ys], axis=1).astype(np.float64) if len(xs) else np.zeros((0, 2))


def dot_near(px, want):
    """Centroid of the red blob nearest the expected pixel, and its distance."""
    if len(px) == 0:
        return None, None
    d = np.hypot(px[:, 0] - want[0], px[:, 1] - want[1])
    i = int(d.argmin())
    seed = px[i]
    blob = px[np.hypot(px[:, 0] - seed[0], px[:, 1] - seed[1]) <= 14.0]
    c = blob.mean(axis=0)
    return (float(c[0]), float(c[1])), float(np.hypot(c[0] - want[0], c[1] - want[1]))


def main(argv):
    folder, tol, ref, rest, i = DEF, 6.0, None, [], 0
    while i < len(argv):
        if argv[i] == '--tol':
            tol = float(argv[i + 1])
            i += 2
        elif argv[i] == '--ref':
            ref = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    if rest:
        folder = rest[0]
    jpath = os.path.join(folder, '_closeups.json')
    if not os.path.isfile(jpath):
        print('FAIL  no _closeups.json in %s (has the pilot been rendered?)' % folder)
        return 1
    rows = json.load(open(jpath, encoding='utf-8')).get('images', [])
    ref_l = luma_stats(ref)[3] if ref else None
    fails = 0

    def say(ok, what):
        nonlocal fails
        if not ok:
            fails += 1
        print('%-4s %s' % ('ok' if ok else 'FAIL', what))

    scales = {}
    for r in rows:
        f = r['file']
        p = os.path.join(folder, f)
        if not os.path.isfile(p):
            say(False, '%s: file missing' % f)
            continue
        w, h, cover, mean = luma_stats(p)
        say((w, h) == (r['w'], r['h']), '%s: %dx%d (json %sx%s)' % (f, w, h, r['w'], r['h']))
        say(cover >= 0.005 and mean is not None and 0.08 <= mean <= 0.97,
            '%s: opaque %.1f%%, mean luma %s' % (f, cover * 100, 'n/a' if mean is None else '%.3f' % mean))
        say(str(r.get('style')) == 'Interior', '%s: style %r' % (f, r.get('style')))
        if ref_l is not None and mean is not None:
            say(abs(mean - ref_l) <= 0.10 * ref_l,
                '%s: luma %.3f vs reference %.3f (%+.1f%%)' % (f, mean, ref_l, (mean / ref_l - 1) * 100))
        if r.get('in_per_px') is not None:
            scales.setdefault(r['shot'], set()).add(round(float(r['in_per_px']), 6))
        meta = r.get('anchors_meta') or {}
        inframe = {k: v for k, v in (r.get('anchors') or {}).items()
                   if v is not None and (meta.get(k) or {}).get('in_frame')}
        for k in r.get('anchors_missing') or []:
            say(False, '%s: anchor %s did not resolve in the model' % (f, k))
        if not inframe:
            continue
        cp = os.path.join(folder, '_anchorcheck', f)
        if not os.path.isfile(cp):
            say(False, '%s: no anchor-check image (%s)' % (f, cp))
            continue
        px = red_pixels(cp)
        for k, want in sorted(inframe.items()):
            got, d = dot_near(px, want)
            if got is None:
                say(False, '%s: anchor %s — no red dot anywhere in the check image' % (f, k))
            else:
                say(d <= tol, '%s: anchor %-14s json (%.1f, %.1f)  dot (%.1f, %.1f)  off %.2f px'
                    % (f, k, want[0], want[1], got[0], got[1], d))
    for shot, s in sorted(scales.items()):
        say(len(s) == 1, '%s: one scale across its variants (%s in/px)' % (shot, ', '.join(map(str, sorted(s)))))
    print('PASS' if fails == 0 else 'FAIL (%d)' % fails)
    return 0 if fails == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
