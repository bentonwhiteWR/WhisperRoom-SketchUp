# -*- coding: utf-8 -*-
"""RUN wr-drop-lights.rb's pure placement logic outside SketchUp.

    python rbtest-lights.py

Same idea and same VM as rbtest.py / rbtest-overlays.py (read their headers):
the method sources are lifted VERBATIM from wr-drop-lights.rb on every run,
so the test cannot drift from the code — editing a method changes what runs
here.

WHAT IS EXERCISED — the whole pure section of wr-drop-lights.rb, against the
worked examples in .forge/researcher/interior-lighting-design.md:

  1. axis_points — the centred formula x_i = L(2i+1)/(2n).
  2. grid_points on the researcher's 12x15 room, 8' ceiling: Soft density
     must land exactly 4 lights at (3',3.75') offsets; Showroom must land
     all 12 (edge gaps 22.5" — the natural-gap cap on the edge threshold is
     what admits them; see edge_threshold's comment in the .rb).
  3. THE L-SHAPE: same room with a 6'x6' notch. The bbox grid point inside
     the notch must be culled by point_in_poly? alone — no special L case
     exists, the polygon tests ARE the L handling.
  4. Keep-out: a 7'x8' booth footprint (inflated 12") must cull exactly the
     four grid points over/next to it and re-flow nothing.
  5. Tiny room (30"x30"): every candidate fails the 18" edge floor — the
     single-centroid clause answers with one light, flagged.
  6. Wall-to-wall keep-out: everything culled — centroid fallback again,
     and the centroid is the AREA centroid (81, 76.5 on the L), never the
     bbox centre.
  7. Wall wash: opposite_edge picks the far antiparallel wall; 24" standoff;
     n = clamp(ceil(len/36"), 2, 4); positions centred; culled by keep-outs.
  8. Lumens: 180 sqft x 40 fc / 0.6 = 12,000 lm -> 3,000 each at Soft (4),
     1,000 each at Showroom (12); Bright x2 / Dim x0.5; booth 24 sqft x
     30 fc / 0.6 = 1,200.
  9. accent_axis — the rotation axis that tips -Z toward the booth face.

MUTATION-CHECKED 2026-08-27 (each mutation applied to wr-drop-lights.rb,
this test run, FAIL confirmed, mutation reverted): centred formula
(2i+1)->(2i); point_in_poly? crossing short-circuit (inside=true); edge
threshold dropped to 0; in_keepout? forced false; CU 0.6->0.5; centroid
/6a -> /2a; opposite_edge nearest-instead-of-farthest; WASH_SPACING
1.5->1.0. Note: flipping the ray-cast comparison (px < x_at -> px > x_at)
is NOT catchable — left and right crossing parity are equal for any closed
polygon, so that mutant is semantically equivalent, not a survivor.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

SRC = os.path.join(HERE, 'wr-drop-lights.rb')


def lift_method(lines, name):
    """Verbatim `def self.<name>` .. its closing two-space `end`."""
    pat = re.compile(r'^  def self\.%s(?![A-Za-z0-9_?!])' % re.escape(name))
    start = None
    for i, ln in enumerate(lines):
        if pat.match(ln):
            start = i
            break
    if start is None:
        raise SystemExit('wr-drop-lights.rb: no method self.%s' % name)
    for j in range(start + 1, len(lines)):
        if lines[j] == '  end':
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-drop-lights.rb: self.%s never closes' % name)


def lift_scalar(lines, name):
    """Verbatim single-line `  NAME = <number>` assignment (comment ok)."""
    pat = re.compile(r'^  %s\s*=\s*[-\d.]+\s*(#.*)?$' % re.escape(name))
    for ln in lines:
        if pat.match(ln):
            return ln
    raise SystemExit('wr-drop-lights.rb: no scalar constant %s' % name)


METHODS = ['grid_spacing', 'axis_points', 'point_in_poly?', 'seg_dist',
           'edge_dist', 'poly_signed_area', 'poly_area', 'poly_centroid',
           'in_keepout?', 'edge_threshold', 'grid_points', 'nearest_edge',
           'opposite_edge', 'wash_points', 'downlight_lumens',
           'booth_lumens', 'accent_axis']
SCALARS = ['DROP', 'EDGE_MIN', 'EDGE_CAP', 'KEEPOUT_PAD', 'HEADROOM',
           'TARGET_FC', 'BOOTH_FC', 'CU', 'WASH_STANDOFF', 'WASH_SPACING',
           'ACCENT_OUT', 'ACCENT_TILT']

FIXTURE = r'''
module WR_DropLights
__CONSTS__

__METHODS__

  # The researcher's worked room: 12' x 15', 8' ceiling.
  RECT = [[0.0, 0.0], [144.0, 0.0], [144.0, 180.0], [0.0, 180.0]]
  # Same room with a 6' x 6' notch out of the top-left: a first-class L.
  LPOLY = [[0.0, 0.0], [144.0, 0.0], [144.0, 180.0], [72.0, 180.0],
           [72.0, 108.0], [0.0, 108.0]]
  TINY = [[0.0, 0.0], [30.0, 0.0], [30.0, 30.0], [0.0, 30.0]]

  def self.pts_s(pts)
    pts.map { |p| p.map { |v| v.round(2) }.join(',') }.join(';')
  end

  def self.check
    out = []

    out << 'axis ' + axis_points(144.0, 3).map { |v| v.round(2) }.join(',')

    g = grid_points(RECT, 96.0, :soft, [])
    out << format('soft4 %s s%s fb%d', pts_s(g[:pts]), g[:s].round(2),
                  g[:fallback] ? 1 : 0)

    g = grid_points(RECT, 96.0, :showroom, [])
    has = g[:pts].any? { |p| (p[0] - 24.0).abs < 1e-6 && (p[1] - 22.5).abs < 1e-6 }
    out << format('show12 n%d has%d s%s', g[:pts].size, has ? 1 : 0, g[:s].round(2))

    g = grid_points(LPOLY, 96.0, :soft, [])
    out << format('Lsoft %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    # A 7'x8' booth at (6,6)-(90,90), pre-inflated by KEEPOUT_PAD = 12.
    g = grid_points(RECT, 96.0, :showroom, [[-6.0, -6.0, 102.0, 102.0]])
    miss = g[:pts].none? { |p| p[0] < 102.0 && p[1] < 102.0 }
    out << format('keepout n%d clear%d', g[:pts].size, miss ? 1 : 0)

    g = grid_points(TINY, 96.0, :soft, [])
    out << format('tiny %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    g = grid_points(RECT, 96.0, :soft, [[-1000.0, -1000.0, 1000.0, 1000.0]])
    out << format('cullall %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    out << 'Lcentroid ' + poly_centroid(LPOLY).map { |v| v.round(2) }.join(',')

    out << format('edist %s %s', edge_dist(36.0, 45.0, LPOLY).round(2),
                  edge_dist(70.0, 110.0, LPOLY).round(2))

    out << 'inpoly ' + [point_in_poly?(36.0, 135.0, LPOLY),
                        point_in_poly?(108.0, 135.0, LPOLY),
                        point_in_poly?(81.0, 76.5, LPOLY)]
                       .map { |b| b ? '1' : '0' }.join(' ')

    out << format('near %d', nearest_edge(RECT, 72.0, 0.5))
    out << format('opp %d %d', opposite_edge(RECT, 0), opposite_edge(LPOLY, 0))

    out << 'washR ' + pts_s(wash_points(RECT, 2, []))
    out << 'washL ' + pts_s(wash_points(LPOLY, 2, []))
    out << 'washK ' + pts_s(wash_points(RECT, 2, [[120.0, 150.0, 132.0, 162.0]]))

    a = poly_area(RECT)
    out << format('lm %d %d %d %d %d',
                  downlight_lumens(a, 4, 1.0), downlight_lumens(a, 12, 1.0),
                  downlight_lumens(a, 4, 2.0), downlight_lumens(a, 4, 0.5),
                  booth_lumens(3456.0, 1.0))

    out << format('thr %s %s %s', edge_threshold(48.0, 24.0, 22.5).round(2),
                  edge_threshold(96.0, 36.0, 45.0).round(2),
                  edge_threshold(96.0, 15.0, 15.0).round(2))

    out << 'axis35 ' + accent_axis(-1, 0).map { |v| v.round(2) }.join(',') +
           ' ' + accent_axis(0, -3).map { |v| v.round(2) }.join(',')

    out.join(' | ')
  end
end
WR_DropLights.check
'''

EXPECT = ' | '.join([
    'axis 24.0,72.0,120.0',
    'soft4 36.0,45.0;36.0,135.0;108.0,45.0;108.0,135.0 s96.0 fb0',
    'show12 n12 has1 s48.0',
    'Lsoft 36.0,45.0;108.0,45.0;108.0,135.0 fb0',
    'keepout n8 clear1',
    'tiny 15.0,15.0 fb1',
    'cullall 72.0,90.0 fb1',
    'Lcentroid 81.0,76.5',
    'edist 36.0 2.0',
    'inpoly 0 1 1',
    'near 0',
    'opp 2 2',
    'washR 126.0,156.0;90.0,156.0;54.0,156.0;18.0,156.0',
    'washL 126.0,156.0;90.0,156.0',
    'washK 90.0,156.0;54.0,156.0;18.0,156.0',
    'lm 3000 1000 6000 1500 1200',
    'thr 22.5 36.0 18.0',
    'axis35 0.0,1.0 -1.0,0.0',
])


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    consts = '\n'.join(lift_scalar(lines, c) for c in SCALARS)
    prog = (FIXTURE
            .replace('__CONSTS__', consts)
            .replace('__METHODS__', '\n\n'.join(lift_method(lines, m) for m in METHODS)))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('wr-drop-lights pure placement: grid, L-shape, keep-outs, centroid,'
          ' wash, lumens')
    if got == EXPECT:
        print('  PASS  (%d checks in one transcript)' % len(EXPECT.split(' | ')))
        return 0
    ge = got.split(' | ')
    ee = EXPECT.split(' | ')
    for i in range(max(len(ge), len(ee))):
        g = ge[i] if i < len(ge) else '(missing)'
        e = ee[i] if i < len(ee) else '(unexpected)'
        mark = 'ok  ' if g == e else 'FAIL'
        print('  %s got %-60s want %s' % (mark, g, e))
    return 1


if __name__ == '__main__':
    sys.exit(main())
