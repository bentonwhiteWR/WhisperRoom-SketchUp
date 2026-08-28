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
 10. subject_veto — the light-as-room incident guard: a 24"-tall subject
     and a shoebox floor are refused; a 6'+/9sqft+ room passes; the
     refusal text names the offending number.
 11. fallback_verdict — the multi-fallback rule: 0 or 1 fallback proceeds,
     2 or more refuses, and the refusal lists what fired and how many.
 12. light_words? — the pure core of vray_light?: BOTH "vray" and "light"
     must appear ("Daylight house" alone must not match).
 13. THE LIVE UTHSC ROOM (the 2026-08-27 "grid fully culled" refusal):
     239.25" x 268.25" (444.92 sf), 8' walls, Soft density. Must land the
     full 3x3 grid, and the new :diag accounting must show 9 candidates
     with zero rejections. Several lights, never one.
 14. Same room with a booth-sized keep-out (90x90 + 12" pad) in a corner:
     exactly one grid point dies, EIGHT remain — no centroid fallback.
 15. Same room with a wall-to-wall keep-out — what the room's own SUITE
     ancestor became when the old obstruction scan read model top level
     instead of the room's siblings. Fallback fires, and :diag must charge
     all nine candidates to the keep-out test, naming the culprit class.
 16. room_structure_child? — the obstruction child filter: floor/walls/
     doors are excluded by tag, or by name CASE-INSENSITIVELY (build-room
     writes "Walls", uthsc-audiology-rooms.rb writes "walls"); a booth
     child must NOT be excluded.
 17. doors_container? / door_child_kind — door detection matched to what
     the generators really write: build-room's "Doors">"Opening N"
     (WR-Doors) with "Door leaf N"/"Swing N" (WR-Doors-Leaf), and the
     UTHSC script's WR-Doors-tagged "doors" holding 'door leaf ...' solids
     and no Opening markers at all (the live "no door found" room).

MUTATION-CHECKED 2026-08-27 (each mutation applied to wr-drop-lights.rb,
this test run, FAIL confirmed, mutation reverted): centred formula
(2i+1)->(2i); point_in_poly? crossing short-circuit (inside=true); edge
threshold dropped to 0; in_keepout? forced false; CU 0.6->0.5; centroid
/6a -> /2a; opposite_edge nearest-instead-of-farthest; WASH_SPACING
1.5->1.0. Note: flipping the ray-cast comparison (px < x_at -> px > x_at)
is NOT catchable — left and right crossing parity are equal for any closed
polygon, so that mutant is semantically equivalent, not a survivor.

MUTATION-CHECKED 2026-08-27 (validation additions, same protocol):
MIN_ROOM_H 72.0->20.0 (veto stops firing on the 24" light); MIN_ROOM_AREA
1296.0->50.0 (shoebox floor passes); fallback_verdict size<=1 -> size<=2
(two fallbacks slip through); light_words? vray term dropped (Daylight
matches). Each made this test FAIL and was reverted.

MUTATION-CHECKED 2026-08-27 (UTHSC-incident additions, same protocol):
grid_points diag mis-charge (keep-out rejections counted as edge);
in_keepout? forced false; room_structure_child? name match made
case-sensitive; door_child_kind leaf regex made case-sensitive;
doors_container? name alternative dropped (tag only); grid nx ceil->floor.
All six KILLED (test failed) and were reverted. NOT coverable here: the
obstruction scan's siblings-not-model.entities fix and the reload guard
are SketchUp-API-side — the first is the actual incident fix and is
unverified until a live press.
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
           'booth_lumens', 'accent_axis', 'subject_veto',
           'fallback_verdict', 'light_words?', 'room_structure_child?',
           'doors_container?', 'door_child_kind']
SCALARS = ['DROP', 'EDGE_MIN', 'EDGE_CAP', 'KEEPOUT_PAD', 'HEADROOM',
           'TARGET_FC', 'BOOTH_FC', 'CU', 'WASH_STANDOFF', 'WASH_SPACING',
           'ACCENT_OUT', 'ACCENT_TILT', 'MIN_ROOM_H', 'MIN_ROOM_AREA']
BLOCKS = ['ROOM_CHILD_TAGS', 'ROOM_CHILD_NAMES']


def lift_block(lines, name):
    """Verbatim multi-line `  NAME = ...` constant, through its `.freeze`."""
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith('  %s = ' % name):
            start = i
            break
    if start is None:
        raise SystemExit('wr-drop-lights.rb: no constant %s' % name)
    for j in range(start, len(lines)):
        if lines[j].rstrip().endswith('.freeze'):
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-drop-lights.rb: %s never freezes' % name)

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
  # The LIVE room the 2026-08-27 refusal happened in: UTHSC Audiology
  # Room 1, 19'-11 1/4" x 22'-4 1/4" (444.92 sf), 8' walls.
  UROOM = [[0.0, 0.0], [239.25, 0.0], [239.25, 268.25], [0.0, 268.25]]

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

    # 10 — the light-as-room incident: Benton's 24"-tall rectangle light
    # (a) and a 100 sqin floor (b) are vetoed; 71.9" (c) is still below the
    # 72" bar; a 12'x20' room at 8' (d) passes. The veto text must carry
    # the offending number (the 24).
    out << 'veto ' + [subject_veto(24.0, 100000.0),
                      subject_veto(96.0, 100.0),
                      subject_veto(71.9, 100000.0),
                      subject_veto(96.0, 34560.0)]
                     .map { |v| v ? '1' : '0' }.join +
           ((v = subject_veto(24.0, 100000.0)) && v.include?('24') ? ' msg1' : ' msg0')

    # 11 — the multi-fallback rule: 0 and 1 proceed (nil), 2 and 3 refuse,
    # and the refusal names the count and the fired fallbacks.
    fv = fallback_verdict(%w[x y])
    out << 'fbv ' + [fallback_verdict([]), fallback_verdict(['a']),
                     fallback_verdict(%w[a b]), fallback_verdict(%w[a b c])]
                    .map { |v| v ? '1' : '0' }.join +
           (fv && fv.include?('x') && fv.include?('y') && fv.include?('2') ? ' list1' : ' list0')

    # 12 — light_words?: needs BOTH vray and light.
    out << 'lw ' + [light_words?('SketchUp VRay dict: lights'),
                    light_words?('V-Ray Rectangle Light'),
                    light_words?('Daylight house'),
                    light_words?('vray infinite plane')]
                   .map { |b| b ? '1' : '0' }.join

    # 13 — the live UTHSC room, no keep-outs: a 445 sqft room at Soft
    # density MUST land a full 3x3 grid, with the diagnostics accounting
    # for every candidate. The 2026-08-27 run reported "grid fully culled"
    # here, which this line proves is impossible without a phantom keep-out
    # (it was the room's own suite ancestor, swallowed by the old top-level
    # obstruction scan).
    g = grid_points(UROOM, 96.0, :soft, [])
    d = g[:diag]
    out << format('uroom n%d fb%d cand%d rej%d,%d,%d thr%s', g[:pts].size,
                  g[:fallback] ? 1 : 0, d[:cand], d[:out], d[:edge],
                  d[:keep], d[:thr].round(2))

    # 14 — a booth-sized keep-out in the SW corner (a 90x90 booth inflated
    # by the 12" pad): exactly one grid point dies, EIGHT lights remain —
    # never the single-centroid fallback.
    g = grid_points(UROOM, 96.0, :soft, [[-12.0, -12.0, 102.0, 102.0]])
    d = g[:diag]
    out << format('ubooth n%d fb%d keep%d', g[:pts].size,
                  g[:fallback] ? 1 : 0, d[:keep])

    # 15 — the incident replayed: one wall-to-wall keep-out (what the suite
    # group became). The centroid fallback fires and the diagnostics must
    # charge all nine candidates to the keep-out test, not the others.
    g = grid_points(UROOM, 96.0, :soft, [[-12.0, -12.0, 900.0, 900.0]])
    d = g[:diag]
    out << format('usuite %s fb%d rej%d,%d,%d', pts_s(g[:pts]),
                  g[:fallback] ? 1 : 0, d[:out], d[:edge], d[:keep])

    # 16 — room_structure_child?: the room's own floor/walls/doors are
    # NEVER keep-outs — by tag, or by name CASE-INSENSITIVELY (build-room
    # writes "Walls", the UTHSC script writes "walls") — while a wall-like
    # booth child MUST still become one.
    out << 'rsc ' + [room_structure_child?('WR-Room', 'walls'),
                     room_structure_child?('Layer0', 'walls'),
                     room_structure_child?('Layer0', 'Walls'),
                     room_structure_child?('WR-Room-Upper', 'whatever'),
                     room_structure_child?('Layer0', 'WhisperRoom 7272 E'),
                     room_structure_child?('WR-Booth-Walls', 'panel')]
                    .map { |b| b ? '1' : '0' }.join

    # 17 — the door classifiers against what the two generators REALLY
    # write: build-room.rb's untagged "Doors" container holding "Opening N"
    # (WR-Doors) / "Door leaf N" / "Swing N" (WR-Doors-Leaf), and the UTHSC
    # script's WR-Doors-tagged "doors" container holding 'door leaf ...'
    # solids and a loose swing arc — the live "no door found" room.
    out << 'dc ' + [doors_container?('Layer0', 'Doors'),
                    doors_container?('WR-Doors', 'doors'),
                    doors_container?('WR-Doors', 'Opening 3'),
                    doors_container?('Layer0', 'Floor')]
                   .map { |b| b ? '1' : '0' }.join
    out << 'dk ' + [door_child_kind('WR-Doors', 'Opening 3') == :opening,
                    door_child_kind('Layer0', 'door leaf 36" ASSUMED, swings in') == :leaf,
                    door_child_kind('WR-Doors-Leaf', 'Door leaf 3') == :leaf,
                    door_child_kind('WR-Doors-Leaf', 'Swing 3').nil?,
                    door_child_kind('Layer0', 'wall').nil?]
                   .map { |b| b ? '1' : '0' }.join

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
    'veto 1110 msg1',
    'fbv 0011 list1',
    'lw 1100',
    'uroom n9 fb0 cand9 rej0,0,0 thr36.0',
    'ubooth n8 fb0 keep1',
    'usuite 119.63,134.13 fb1 rej0,0,9',
    'rsc 111100',
    'dc 1100',
    'dk 11111',
])


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    consts = '\n'.join([lift_scalar(lines, c) for c in SCALARS] +
                       [lift_block(lines, c) for c in BLOCKS])
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
