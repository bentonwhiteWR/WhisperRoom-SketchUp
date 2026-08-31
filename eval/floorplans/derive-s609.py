# -*- coding: utf-8 -*-
"""Re-derive the S609-3 ground truth from the vector PDF, write truth.json.

    python eval/floorplans/derive-s609.py

Reads clients/uic-daley-library/plans/S609-3.pdf (machine-local, gitignored —
the PDF itself never enters the public repo; only these derived NUMBERS do,
per Benton's Q5 call, 31 Aug 2026). Deterministic: re-running reproduces the
three truth.json files byte-identical.

METHOD (verified against the researcher's probe, then re-run here):
  - The 3190 office band sits at page x 235..335 pt, y 75..115 pt.
  - The interior window-wall faces of the G+H pair are the two 16.02-pt
    vertical segments at x = 245.46 and 289.14; the removed partition's faces
    are the full-height verticals at 266.82 / 267.78.
  - ONE pen anchor scales everything: the 18'11" chain on IMG_7594 is the
    G+H interior width, 227 in across those two faces -> ~5.197 in/pt.
  - Everything else is that scale times a coordinate difference, cross-
    checked against the pen numbers below. Agreement is ~0-2 in, which is
    why every S609 truth value carries a +-2" (or wider) tolerance.

WHAT IS AND IS NOT GROUND TRUTH HERE — read before trusting a score:
  - G+H width 227" is exact BY CONSTRUCTION (it is the anchor).
  - G+H depth: pen says 14'4" = 172"; the PDF wall-face pairing gives
    171.8-174.6" depending on which linework face is the finish face. Truth
    uses the pen 172.0 +-2".
  - 3190J: width 97" (pen 8'1"; PDF ~95.7"). Its DEPTH is stated nowhere —
    the takeoff assumes the 172" band depth, so J's truth carries the same
    assumption and cannot catch a depth transcription error. Its door
    position 8'10" IS pen-measured (observed on IMG_7595 — the vertical
    corner->jamb chain).
  - 3190F: the 9'3"/9'6" pen chains differ by 3"; truth uses the jogged
    6-run interpretation recorded in the takeoff, tolerance 3", UNCONFIRMED
    until Gabe answers. A gross error (feet, the 31 Aug class) still scores.
"""
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PDF = os.path.join(ROOT, 'clients', 'uic-daley-library', 'plans', 'S609-3.pdf')

ANCHOR_IN = 227.0          # pen 18'11" — G+H interior width, IMG_7594
PEN_DEPTH_IN = 172.0       # pen 14'4" — band depth, IMG_7594/7596
CEIL_GH = 105.0            # pen 8'9" (H side; G side 8'8")
CEIL_F = 103.0             # pen 8'7"
BULKHEAD_HEAD = 99.0       # pen 8'3"


def wall_faces():
    import pymupdf
    doc = pymupdf.open(PDF)
    segs = []
    for path in doc[0].get_drawings():
        for it in path['items']:
            if it[0] == 'l':
                a, b = it[1], it[2]
                segs.append((a.x, a.y, b.x, b.y))
    # Vertical wall-length segments in the 3190 band (top cluster).
    vs = [s for s in segs
          if abs(s[0] - s[2]) < 0.05 and abs(s[3] - s[1]) >= 15
          and 235 < s[0] < 335 and 60 < min(s[1], s[3]) and max(s[1], s[3]) < 130]
    xs = sorted(set(round(s[0], 2) for s in vs))
    # The G+H interior faces: the 16.02-pt verticals nearest 245.5 / 289.1.
    west = min(xs, key=lambda x: abs(x - 245.46))
    east = min(xs, key=lambda x: abs(x - 289.14))
    part = [x for x in xs if 266 < x < 268.5]
    ys = [y for s in vs if 266 < s[0] < 268.5 for y in (s[1], s[3])]
    return west, east, (min(part), max(part)), (min(ys), max(ys))


def write(path, obj):
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, indent=2, sort_keys=True)
        f.write('\n')
    print('  wrote %s' % os.path.relpath(path, ROOT))


def main():
    if not os.path.exists(PDF):
        print('S609-3.pdf is not at %s — it is machine-local (gitignored). '
              'Copy it from Downloads (never move it) and re-run.' % PDF)
        return 2
    west, east, part, band_y = wall_faces()
    k = ANCHOR_IN / (east - west)
    part_center = ((part[0] + part[1]) / 2.0 - west) * k
    part_thick = (part[1] - part[0]) * k
    g_width = (part[0] - west) * k
    pdf_depth = (band_y[1] - band_y[0]) * k
    print('S609-3 vector derivation (anchor: pen 18\'11" across x %.2f..%.2f pt '
          '-> %.4f in/pt)' % (west, east, k))
    print('  G interior width  %.1f"   (pen class 9\'3" = 111")' % g_width)
    print('  partition center  %.1f" from the west wall (pen 9\'5" = 113")'
          % part_center)
    print('  partition thick   %.1f"' % part_thick)
    print('  band depth (PDF)  %.1f"   (pen 14\'4" = 172" — truth uses the pen)'
          % pdf_depth)
    for label, got, want, tol in [('G width', g_width, 111.0, 2.0),
                                  ('partition center', part_center, 113.0, 2.0),
                                  ('band depth', pdf_depth, 172.0, 3.0)]:
        ok = abs(got - want) <= tol
        print('  %-4s %s: %.1f" vs pen %.1f" (tol %.0f")'
              % ('ok' if ok else 'FAIL', label, got, want, tol))
        if not ok:
            print('  derivation disagrees with the pen beyond tolerance — '
                  'NOT writing truth files; investigate first.')
            return 1

    r = lambda v: round(v, 1)
    src = ('S609-3.pdf vectors + pen anchor 18\'11" (this script); '
           'pen depth 14\'4"')
    write(os.path.join(HERE, 's609-3190gh', 'truth.json'), {
        'rooms': [{
            'room': '3190G+H', 'source': src, 'tolerance_in': 2.0,
            'polygon': [[0.0, 0.0], [227.0, 0.0], [227.0, -172.0], [0.0, -172.0]],
            'ceiling_in': CEIL_GH,
            'pdf_depth_in': r(pdf_depth),
            'doors': [
                {'run': 2, 'w_in': 38.0, 'jambs_in': None, 'expect_flag': 'assumed'},
                {'run': 2, 'w_in': 38.0, 'jambs_in': None, 'expect_flag': 'assumed'}],
            'features': [{'type': 'heater', 'count': 2},
                         {'type': 'bulkhead', 'count': 1,
                          'from_in': r(part_center), 'head_in': BULKHEAD_HEAD}]}]})
    write(os.path.join(HERE, 's609-3190j', 'truth.json'), {
        'rooms': [{
            'room': '3190J', 'source': 'pen IMG_7595 (width, door chain); '
            'depth is the ASSUMED band depth — see README, not ground truth',
            'tolerance_in': 2.0,
            'polygon': [[0.0, 0.0], [-97.0, 0.0], [-97.0, -172.0], [0.0, -172.0]],
            'ceiling_in': CEIL_GH,
            'doors': [{'run': 1, 'w_in': 38.0, 'jambs_in': [106.0, 144.0],
                       'expect_flag': None}],
            'features': []}]})
    write(os.path.join(HERE, 's609-3190f', 'truth.json'), {
        'rooms': [{
            'room': '3190F', 'source': 'pen IMG_7596; jogged 6-run '
            'interpretation of the 9\'3"/9\'6" pair — UNCONFIRMED, see README',
            'tolerance_in': 3.0,
            'polygon': [[0.0, 0.0], [111.0, 0.0], [111.0, -109.0],
                        [114.0, -109.0], [114.0, -172.0], [0.0, -172.0]],
            'ceiling_in': CEIL_F,
            'doors': [{'run': 4, 'w_in': 38.0, 'jambs_in': None,
                       'expect_flag': 'assumed'}],
            'features': [{'type': 'heater', 'count': 1}]}]})
    return 0


if __name__ == '__main__':
    sys.exit(main())
