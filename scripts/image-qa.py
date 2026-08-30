# -*- coding: utf-8 -*-
"""GATE the images a proposal package produced, so a blown frame never ships.

    python image-qa.py DIR_OR_FILE [DIR_OR_FILE ...] [--json out.json]
    python image-qa.py --manifest rows.json [--json out.json]

WHY THIS EXISTS
---------------
On 30 Aug 2026 the first full end-to-end run produced a V-Ray render that
looked finished by every check the toolset had: the renderer reached
:idleDone, save_vfb_image returned true, a 330 KB PNG landed on disk at the
requested 1200x900, and the batch summary said "0 FAILED". The picture was
white. Booth panels clipped to paper with all texture gone, room floor and
walls clipped to an empty void — 89.3% of the frame was pure white and the
mean luminance was 0.964. Nothing in the pipeline could tell, because nothing
in the pipeline had ever looked at a pixel.

This looks at the pixels. Two numbers per image:

    mean luminance   Rec.709 luma of the sRGB values as stored, 0..1.
                     Catches the two failures that make an image useless
                     without making it missing: blown to white (high) and
                     rendered black (low, the EV 14.23 case).
    clipped fraction the fraction of pixels where R, G and B are ALL >= 250.
                     Mean luminance alone is not enough: a frame can average
                     acceptably while its subject is clipped to featureless
                     white. Clipping is where detail is destroyed, and it
                     cannot be recovered afterwards.

A row that crosses a threshold FAILS BY NAME, with the numbers and the
threshold it crossed. There is no "warning" verdict — a client image is
sendable or it is not.

PROFILES, and why there is more than one
----------------------------------------
A top-down plan export is mostly paper-white BY DESIGN (pass 1's plan measured
mean 0.966, clip 0.935 and was perfectly good), while a photographic render at
those numbers is destroyed. One threshold cannot serve both, so each image is
judged under a named profile and the profile used is reported with the result.

    render   V-Ray photographic output          mean 0.12..0.75, clip <= 0.40
    view     a shaded perspective image export  mean 0.12..0.75, clip <= 0.40
    plan     an orthographic plan or elevation  mean 0.10..0.995, clip <= 0.98

CALIBRATION (observed, 30 Aug 2026, on pass 1's own files):

    01 Booth Exterior render (BLOWN)    mean 0.964  clip 0.893  -> FAIL both
    room-view-EV09-BLOWN                mean 0.935  clip 0.797  -> FAIL both
    room-view-EV11 (still clipping)     mean 0.683  clip 0.449  -> FAIL clip
    room-view-EV12 (Benton: best)       mean 0.546  clip 0.270  -> PASS
    booth-interior-EV09 (best)          mean 0.410  clip 0.084  -> PASS
    booth-interior-EV14.23 (near black) mean 0.027  clip 0.006  -> FAIL mean
    _coldtest.png (the black frame)     mean 0.000  clip 0.000  -> FAIL mean

The clip ceiling sits at 0.40 precisely so the EV 11 frame — which Benton
judged "room walls and floor still clipping" — fails, and the EV 12 frame he
judged best passes. The thresholds are tuned to a human verdict on real files,
not chosen round.

THE MANIFEST FORM is what the proposal-package driver uses: a JSON array of
{"name", "path", "profile"} so the profile is DECLARED per row rather than
guessed. Without a manifest the profile is inferred from the filename (a name
containing "plan" or "elevation" is a plan) and the inference is stated in the
output, because a silent guess about which threshold applied would make a pass
meaningless.

EXIT CODES
    0  every image passed its gate
    1  at least one image FAILED (named, with its numbers)
    2  usage error, or an image that could not be read at all
"""
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

try:
    from PIL import Image
    import numpy as np
except ImportError as e:            # NO silent skip: a missing library means
    sys.stderr.write(               # the gate did not run, which is not a pass
        'image-qa: cannot run - %s. Install Pillow and numpy '
        '(pip install pillow numpy).\n' % e)
    sys.exit(2)

CLIP_LEVEL = 250        # of 255, on all three channels

PROFILES = {
    'render': {'mean_min': 0.12, 'mean_max': 0.75, 'clip_max': 0.40},
    'view':   {'mean_min': 0.12, 'mean_max': 0.75, 'clip_max': 0.40},
    'plan':   {'mean_min': 0.10, 'mean_max': 0.995, 'clip_max': 0.98},
}
PLAN_RE = re.compile(r'plan|elevation|top[- ]?down', re.I)


def infer_profile(path):
    """The profile a bare filename implies, and the fact that it was inferred."""
    base = os.path.basename(path)
    if PLAN_RE.search(base):
        return 'plan', 'inferred from the filename'
    if re.search(r'render', base, re.I):
        return 'render', 'inferred from the filename'
    return 'view', 'inferred from the filename (default)'


def measure(path):
    """mean luminance, clipped fraction, dark fraction, size. Raises on a bad file."""
    with Image.open(path) as im:
        w, h = im.size
        a = np.asarray(im.convert('RGB')).astype(np.float32) / 255.0
    lum = 0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1] + 0.0722 * a[:, :, 2]
    clipped = (a >= CLIP_LEVEL / 255.0).all(axis=2).mean()
    dark = (lum < 0.02).mean()
    return {'width': w, 'height': h,
            'mean_luminance': round(float(lum.mean()), 4),
            'clipped_fraction': round(float(clipped), 4),
            'dark_fraction': round(float(dark), 4),
            'bytes': os.path.getsize(path)}


def judge(m, profile):
    """[] when the image passes; otherwise every threshold it crossed, named."""
    t = PROFILES[profile]
    out = []
    if m['mean_luminance'] > t['mean_max']:
        out.append('BLOWN OUT: mean luminance %.4f is above the %s ceiling of %.2f'
                   % (m['mean_luminance'], profile, t['mean_max']))
    if m['mean_luminance'] < t['mean_min']:
        out.append('TOO DARK: mean luminance %.4f is below the %s floor of %.2f'
                   % (m['mean_luminance'], profile, t['mean_min']))
    if m['clipped_fraction'] > t['clip_max']:
        out.append('CLIPPED: %.1f%% of the frame is pure white, above the %s '
                   'ceiling of %.1f%% - that detail is gone and cannot be '
                   'recovered' % (m['clipped_fraction'] * 100.0, profile,
                                  t['clip_max'] * 100.0))
    return out


def check(name, path, profile=None):
    row = {'name': name, 'path': path}
    if profile is None:
        profile, how = infer_profile(path)
    else:
        how = 'declared by the caller'
        if profile not in PROFILES:
            row.update({'status': 'ERROR', 'profile': profile,
                        'reasons': ['unknown profile %r - known: %s'
                                    % (profile, ', '.join(sorted(PROFILES)))]})
            return row
    row['profile'] = profile
    row['profile_source'] = how
    row['thresholds'] = PROFILES[profile]
    if not os.path.isfile(path):
        row.update({'status': 'ERROR',
                    'reasons': ['no such file - the row produced no image']})
        return row
    try:
        m = measure(path)
    except Exception as e:                       # a file that cannot be read
        row.update({'status': 'ERROR',           # is never a pass
                    'reasons': ['could not read the image: %s: %s'
                                % (type(e).__name__, e)]})
        return row
    row.update(m)
    reasons = judge(m, profile)
    row['status'] = 'PASS' if not reasons else 'FAIL'
    row['reasons'] = reasons
    return row


def collect(args):
    """Every PNG named on the command line, directories expanded."""
    out = []
    for a in args:
        if os.path.isdir(a):
            for f in sorted(os.listdir(a)):
                if f.lower().endswith('.png'):
                    out.append((f, os.path.join(a, f), None))
        else:
            out.append((os.path.basename(a), a, None))
    return out


def main(argv):
    args = list(argv[1:])
    out_json = None
    manifest = None
    rest = []
    i = 0
    while i < len(args):
        if args[i] == '--json' and i + 1 < len(args):
            out_json = args[i + 1]
            i += 2
        elif args[i] == '--manifest' and i + 1 < len(args):
            manifest = args[i + 1]
            i += 2
        else:
            rest.append(args[i])
            i += 1

    if manifest:
        rows = [(r.get('name') or os.path.basename(r['path']), r['path'],
                 r.get('profile'))
                for r in json.load(open(manifest, encoding='utf-8'))]
    elif rest:
        rows = collect(rest)
    else:
        sys.stderr.write(__doc__.split('WHY THIS EXISTS')[0])
        return 2

    results = [check(n, p, prof) for n, p, prof in rows]
    width = max([len(r['name']) for r in results] + [10])
    for r in results:
        if r['status'] == 'PASS':
            print('  PASS   %-*s  %-6s mean %.4f  clip %.4f  %dx%d'
                  % (width, r['name'], r['profile'], r['mean_luminance'],
                     r['clipped_fraction'], r['width'], r['height']))
        else:
            head = ('  %-6s %-*s  %-6s' % (r['status'], width, r['name'],
                                           r.get('profile', '?')))
            if 'mean_luminance' in r:
                head += ('  mean %.4f  clip %.4f  %dx%d'
                         % (r['mean_luminance'], r['clipped_fraction'],
                            r['width'], r['height']))
            print(head)
            for why in r['reasons']:
                print('         %s' % why)

    bad = [r for r in results if r['status'] != 'PASS']
    print('')
    if bad:
        print('IMAGE QA - %d of %d FAILED: %s'
              % (len(bad), len(results), ', '.join(r['name'] for r in bad)))
    else:
        print('IMAGE QA - all %d image(s) passed.' % len(results))

    if out_json:
        with open(out_json, 'w', encoding='utf-8') as fh:
            json.dump({'clip_level': CLIP_LEVEL, 'profiles': PROFILES,
                       'results': results}, fh, indent=1)
        print('  wrote %s' % out_json)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
