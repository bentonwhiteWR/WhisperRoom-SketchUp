# -*- coding: utf-8 -*-
"""RUN wr-overlays.rb's pure placement logic outside SketchUp.

    python rbtest-overlays.py

Same idea and same VM as rbtest.py (read its header for why this exists): the
method sources are lifted VERBATIM from wr-overlays.rb on every run, so the
test cannot drift from the code — editing the method changes what runs here.

WHAT IS EXERCISED — the whole pure section of wr-overlays.rb:

  1. kind_of / wears_foam? / wears_duct_covers? — the panel-selection
     predicates, including the traps: '46Panel3236WDO' contains 'Panel' and
     must read WINDOW; '40NV_HX' must read NV; the 43 in panel wears nothing;
     an HX booth ships NO duct covers while its foam is untouched.
  2. slot_frame / port_run_pos — the wall-local frame and the left-edge-seen-
     from-inside conversion of the measured duct-port x on all four walls.
  3. foam_targets / duct_targets on a real MDL 7272 E fixture (polys lifted
     from wr-booth-data.rb, post-E/W-rebalance widths): the Enhanced move puts
     every overlay face on the IEP inner band's room edge, which the data
     guarantees is 2.25 in roomward of the standard interior face.
  4. desk_host / mjp_host — the portal's host-selection precedence.
  5. axes_for — the measured-extents axis matcher.
  6. THE CASTER-PLATE DATUM AND SELECTION — booth_lift / cp_candidates and
     the CP_* constants. Benton's figures (2026-08-27, direct — they
     supersede the portal's marketing 5 in): net lift 4.75, tray 0.75,
     plate 5.50 derived. The single highest-risk pin here is booth_lift's
     FALSE branch: a booth without casters must lift 0.0 EXACTLY, because a
     leak into the default path silently moves every drawing Benton has.
     main() also asserts, at source level, that the group transform is
     touched nowhere outside wr-overlays' caster pass.

Every expected number below traces to .forge/researcher/portal-part-placement.md
(the port table, the 2.25 IEP move), to wr-booth-data.rb (the slot polygons),
or to Benton directly (the caster datum trio).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402


SRC = os.path.join(HERE, 'wr-overlays.rb')


def lift_method(lines, name):
    """Verbatim `def self.<name>` .. its closing two-space `end`."""
    pat = re.compile(r'^  def self\.%s(?![A-Za-z0-9_?!])' % re.escape(name))
    start = None
    for i, ln in enumerate(lines):
        if pat.match(ln):
            start = i
            break
    if start is None:
        raise SystemExit('wr-overlays.rb: no method self.%s' % name)
    for j in range(start + 1, len(lines)):
        if lines[j] == '  end':
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-overlays.rb: self.%s never closes' % name)


def lift_const(lines, name):
    """Verbatim `  NAME = ...` through the line that ends `.freeze`."""
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith('  %s =' % name):
            start = i
            break
    if start is None:
        raise SystemExit('wr-overlays.rb: no constant %s' % name)
    for j in range(start, len(lines)):
        if lines[j].rstrip().endswith('.freeze'):
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-overlays.rb: %s never freezes' % name)


METHODS = ['kind_of', 'wears_foam?', 'wears_duct_covers?', 'slot_frame',
           'port_run_pos', 'wall_of', 'host_frame', 'foam_targets',
           'duct_targets', 'desk_accepts_inside?', 'desk_accepts_outside?',
           'desk_host', 'mjp_host', 'axes_for', 'booth_lift', 'cp_candidates']
CONSTS = ['DUCT_PORTS', 'OPPOSITE_WALL']
# Scalar constants (no .freeze line to anchor on): lifted verbatim as their
# single assignment line.
SCALARS = ['CP_BOOTH_LIFT', 'CP_TRAY_DEPTH', 'CP_PLATE_HEIGHT']


def lift_scalar(lines, name):
    """Verbatim single-line `  NAME = <number>` assignment."""
    pat = re.compile(r'^  %s\s*=\s*[-\d.]+\s*$' % re.escape(name))
    for ln in lines:
        if pat.match(ln):
            return ln
    raise SystemExit('wr-overlays.rb: no scalar constant %s' % name)

SHIMS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
end
'''

# NOTE: templated by str.replace, NOT %-formatting — the Ruby inside is full
# of its own %s / %.2f format strings (rbtest.py escapes them as %%; here the
# fixture is long enough that replace is the safer tool).
FIXTURE = r'''
module WR_Overlays
__CONSTS__

__METHODS__

  # MDL 7272 E, panels only, polygons straight out of wr-booth-data.rb with
  # the E/W widths as rebalance_walls leaves them (the ASSIGN swap puts the
  # 46 on E1/W1): outer E0 22 at y 2..24, E1 46 at y 26..72; inner E0i 17.5
  # at 4.25..21.75, E1i 41.5 at 28.25..69.75 (17.5 + 6.5 seal + 41.5 = 65.5).
  def self.fixture_7272e
    [
      { :id => 'N0', :name => '46VNT_VSS',      :inner => false,
        :poly => [[2.0, 72.0], [48.0, 72.0], [48.0, 73.0], [2.0, 73.0]] },
      { :id => 'N1', :name => '22PanelSolid',   :inner => false,
        :poly => [[50.0, 72.0], [72.0, 72.0], [72.0, 73.0], [50.0, 73.0]] },
      { :id => 'S0', :name => 'Right46Door',    :inner => false,
        :poly => [[2.0, 1.0], [48.0, 1.0], [48.0, 2.0], [2.0, 2.0]] },
      { :id => 'S1', :name => '22PanelSolid',   :inner => false,
        :poly => [[50.0, 1.0], [72.0, 1.0], [72.0, 2.0], [50.0, 2.0]] },
      { :id => 'E0', :name => '22PanelSolid',   :inner => false,
        :poly => [[72.0, 2.0], [73.0, 2.0], [73.0, 24.0], [72.0, 24.0]] },
      { :id => 'E1', :name => '46VNT_VSS',      :inner => false,
        :poly => [[72.0, 26.0], [73.0, 26.0], [73.0, 72.0], [72.0, 72.0]] },
      { :id => 'W0', :name => '22PanelSolid',   :inner => false,
        :poly => [[1.0, 2.0], [2.0, 2.0], [2.0, 24.0], [1.0, 24.0]] },
      { :id => 'W1', :name => '46Panel3236WDO', :inner => false,
        :poly => [[1.0, 26.0], [2.0, 26.0], [2.0, 72.0], [1.0, 72.0]] },
      { :id => 'N0i', :name => 'ENH 41.5VNT',          :inner => true,
        :poly => [[4.25, 69.75], [45.75, 69.75], [45.75, 71.75], [4.25, 71.75]] },
      { :id => 'N1i', :name => 'ENH 17.5PanelSolid',   :inner => true,
        :poly => [[52.25, 69.75], [69.75, 69.75], [69.75, 71.75], [52.25, 71.75]] },
      { :id => 'S0i', :name => 'ENH Right41.5Door',    :inner => true,
        :poly => [[4.25, 2.25], [45.75, 2.25], [45.75, 4.25], [4.25, 4.25]] },
      { :id => 'S1i', :name => 'ENH 17.5PanelSolid',   :inner => true,
        :poly => [[52.25, 2.25], [69.75, 2.25], [69.75, 4.25], [52.25, 4.25]] },
      { :id => 'E0i', :name => 'ENH 17.5PanelSolid',   :inner => true,
        :poly => [[69.75, 4.25], [71.75, 4.25], [71.75, 21.75], [69.75, 21.75]] },
      { :id => 'E1i', :name => 'ENH 41.5VNT',          :inner => true,
        :poly => [[69.75, 28.25], [71.75, 28.25], [71.75, 69.75], [69.75, 69.75]] },
      { :id => 'W0i', :name => 'ENH 17.5PanelSolid',   :inner => true,
        :poly => [[2.25, 4.25], [4.25, 4.25], [4.25, 21.75], [2.25, 21.75]] },
      { :id => 'W1i', :name => 'ENH 41.5Panel3236WDO', :inner => true,
        :poly => [[2.25, 28.25], [4.25, 28.25], [4.25, 69.75], [2.25, 69.75]] }
    ]
  end

  # A Standard booth with vents on S and W, to pin the left-edge-seen-from-
  # inside mirroring on the two walls the 7272 fixture does not cover.
  def self.fixture_sw
    [
      { :id => 'S0', :name => '40VNT', :inner => false,
        :poly => [[2.0, 1.0], [42.0, 1.0], [42.0, 2.0], [2.0, 2.0]] },
      { :id => 'W0', :name => '40VNT', :inner => false,
        :poly => [[1.0, 2.0], [2.0, 2.0], [2.0, 42.0], [1.0, 42.0]] }
    ]
  end

  def self.check
    c = [37.0, 37.0]
    out = []

    # 1 — predicates, the traps spelled out.
    out << 'kinds ' + ['46Panel3236WDO', '40NV_HX', 'Right46Door', '46VNT_VSS_CP',
                       '43Panel', 'ENH 41.5VNT', '40PanelSolid_HX',
                       '46PanelCBL'].map { |n| kind_of(n).to_s }.join(',')
    foam = [['40PanelSolid', 40], ['46VNT_VSS', 46], ['46PanelCBL', 46],
            ['40NV', 40], ['43Panel', 43], ['46Panel3236WDO', 46],
            ['Right46Door', 46], ['40PanelSolid_HX', 40], ['22PanelSolid', 22]]
    out << 'foam ' + foam.map { |n, w| wears_foam?(n, w) ? '1' : '0' }.join
    duct = [['40VNT', 40, false], ['46VNT_VSS_CP', 46, false],
            ['40VNT', 40, true], ['46PanelCBL', 46, false],
            ['40PanelSolid', 40, false], ['43Panel', 43, false]]
    out << 'duct ' + duct.map { |n, w, hx| wears_duct_covers?(n, w, hx) ? '1' : '0' }.join

    # 2+3 — targets on the 7272 E.
    p72 = fixture_7272e
    ft = foam_targets(p72, c, 81.0)
    out << 'foamN ' + ft.length.to_s
    ft.each do |t|
      out << format('foam %s->%s run %.2f face %.2f z %.1f %s',
                    t[:id], t[:host_id], t[:run_c], t[:face], t[:z_c],
                    t[:moved] ? 'IEP' : 'STD')
    end
    dt = duct_targets(p72, c, false)
    out << 'ductN ' + dt.length.to_s
    dt.each do |t|
      out << format('duct %s %s run %.2f face %.2f z %.2f %s',
                    t[:id], t[:pos], t[:run_c], t[:face], t[:z_c],
                    t[:moved] ? 'IEP' : 'STD')
    end
    out << 'ductHX ' + duct_targets(p72, c, true).length.to_s

    # 2 — S and W mirroring on a Standard booth: S ports run from the HIGH x
    # end (left seen from inside is east), W from the LOW y end.
    dsw = duct_targets(fixture_sw, c, false)
    dsw.each do |t|
      out << format('sw %s %s run %.2f face %.2f z %.2f',
                    t[:id], t[:pos], t[:run_c], t[:face], t[:z_c])
    end

    # 4 — host selection.
    h, m, _why = desk_host(p72, '', false, false)
    out << format('desk auto %s %s', h ? h[:id] : '-', m)
    h, m, _why = desk_host(p72, 'W1', false, true)
    out << format('desk W1out %s %s', h ? h[:id] : '-', m)
    h, m, _why = desk_host(p72, 'S0', false, false)   # a door — must fall to auto
    out << format('desk S0 %s %s', h ? h[:id] : '-', m)
    h, _why = mjp_host(p72, '')
    out << format('mjp auto %s', h ? h[:id] : '-')
    h, _why = mjp_host(p72, 'E1')                     # a vent — falls to the window
    out << format('mjp E1 %s', h ? h[:id] : '-')

    # 5 — axis matcher on the foam manifest figures.
    ax = axes_for([2.13, 22.97, 47.88], 24.0, 48.0, 2.0)
    out << format('axes w%d h%d t%d', ax[:wi], ax[:hi], ax[:ti])
    # The desk rule: height is NOT supplied, so the two MEASURED numbers pick
    # their axes and the LEFTOVER axis is vertical. Extents below are a
    # wall-mounted desk authored with width on x, depth on y and its (small,
    # unmeasured) vertical extent on z — the answer must be w0 t1, h2, and it
    # must NOT depend on how tall the part happens to be. Both rows are the
    # same part at two different heights and both must land identically;
    # under the old guessed-20 height the taller row flipped depth into the
    # vertical slot and stood the work surface on edge against the wall.
    a1 = axes_for([30.0, 14.0, 6.0], 30.0, nil, 14.0)
    a2 = axes_for([30.0, 14.0, 26.0], 30.0, nil, 14.0)
    out << format('desk axes %d%d%d %d%d%d', a1[:wi], a1[:hi], a1[:ti],
                  a2[:wi], a2[:hi], a2[:ti])

    # 6 — caster datum arithmetic (Benton direct) and plate selection.
    out << format('cp const %.2f %.2f %.2f %s', CP_BOOTH_LIFT, CP_TRAY_DEPTH,
                  CP_PLATE_HEIGHT,
                  (CP_PLATE_HEIGHT - (CP_BOOTH_LIFT + CP_TRAY_DEPTH)).abs < 1e-9 ? 'sum-ok' : 'SUM-BROKEN')
    # THE no-regression pin: no casters means ZERO lift, whatever the floor
    # measures. With casters, a floor underside at -1.0 (the nominal slab
    # below DECK_TOP_Z 0) lifts 5.75 so the underside lands at 4.75.
    out << format('cp lift off %.2f %.2f on %.2f', booth_lift(false, -1.0),
                  booth_lift(false, 3.25), booth_lift(true, -1.0))
    # Plate selection per footprint, one-for-one with the floor tiling:
    # 4872 single; 7272 48+24; 96120 48+24+48; the 84 series' odd 18 middle;
    # a 102 SIDE end. Every expected name exists in the P: library (listed
    # 2026-08-27).
    out << 'cp names ' + [
      cp_candidates(48, 72, 1, 0).first,
      cp_candidates(72, 48, 2, 0).first, cp_candidates(72, 24, 2, 1).first,
      cp_candidates(96, 48, 3, 0).first, cp_candidates(96, 24, 3, 1).first,
      cp_candidates(96, 48, 3, 2).first,
      cp_candidates(84, 18, 4, 2).first,
      cp_candidates(102, 42, 3, 0).first
    ].join(',')
    out << 'cp fall ' + cp_candidates(96, 24, 3, 0).join('/')

    out.join(' | ')
  end
end

(begin
  WR_Overlays.check
rescue Exception => e
  'FAIL ' + e.message + ' @ ' + (e.backtrace || []).first(3).join(' / ')
end).dup
'''

# Every figure is portal-sourced (the port table, the IEP band) or read from
# wr-booth-data.rb (the polygons):
#   foam: N0 and E1 only (46 in vents; the door, window, 22s and 43 all fail).
#     N0 host N0i: run centre 25.0, face 69.75 (= 72.0 standard interior face
#     minus the 2.25 IEP move), z 81/2 = 40.5.
#     E1 host E1i: run centre 49.0 (26..72), face 69.75, z 40.5.
#   duct on a 46 wall: hi [16.15, 71.45], lo [29.9, 9.45].
#     N: left edge seen from inside is LOW x -> hi at 2 + 16.15 = 18.15.
#     E: left edge is HIGH y -> hi at 72 - 16.15 = 55.85.
#     S: left edge is HIGH x (40 wall: 42 - 13.9 = 28.1), W: LOW y (2 + 13.9
#     = 15.9); Standard, so the face is the interior band edge (2.0).
#   desk auto: N0 (46 in vent on the wall opposite the S door; E1 ties on
#     kind and width but loses the opposite-the-door preference).
#   desk S0 chosen: a door never accepts, falls to auto -> N0.
#   mjp: W1 is the only window/cable wall, chosen or not.
EXPECT = (
    'kinds window,nv,door,vnt,solid,vnt,solid,cbl'
    ' | foam 111100010'
    ' | duct 110000'
    ' | foamN 2'
    ' | foam N0->N0i run 25.00 face 69.75 z 40.5 IEP'
    ' | foam E1->E1i run 49.00 face 69.75 z 40.5 IEP'
    ' | ductN 4'
    ' | duct N0 hi run 18.15 face 69.75 z 71.45 IEP'
    ' | duct N0 lo run 31.90 face 69.75 z 9.45 IEP'
    ' | duct E1 hi run 55.85 face 69.75 z 71.45 IEP'
    ' | duct E1 lo run 42.10 face 69.75 z 9.45 IEP'
    ' | ductHX 0'
    ' | sw S0 hi run 28.10 face 2.00 z 71.10'
    ' | sw S0 lo run 14.30 face 2.00 z 9.10'
    ' | sw W0 hi run 15.90 face 2.00 z 71.10'
    ' | sw W0 lo run 29.70 face 2.00 z 9.10'
    ' | desk auto N0 inside'
    ' | desk W1out W1 outside'
    ' | desk S0 N0 inside'
    ' | mjp auto W1'
    ' | mjp E1 W1'
    ' | axes w1 h2 t0'
    ' | desk axes 021 021'
    ' | cp const 4.75 0.75 5.50 sum-ok'
    ' | cp lift off 0.00 0.00 on 5.75'
    ' | cp names CP4872,CP7248 SIDE,CP7224 SIDE,CP9648 SIDE,CP9624 CTR,'
    'CP9648 SIDE,CP8418 CTR,CP10242 SIDE'
    ' | cp fall CP9624 SIDE/CP9624 CTR/CP9624'
)


def lift_leak_check():
    """The booth lift must be applied in exactly ONE place: wr-overlays'
    caster pass. If `booth.transformation` appears anywhere else in the
    builder chain, the no-caster datum can move — which is the regression
    this whole test file exists to prevent."""
    fails = []
    ov = open(SRC, encoding='utf-8').read()
    n = ov.count('booth.transformation')
    # Exactly 2: the read and the write of the single compose-and-assign line
    # in place_casters ("booth.transformation = ... * booth.transformation").
    if n != 2:
        fails.append('wr-overlays.rb touches booth.transformation %d time(s), '
                     'expected exactly 2 (one compose-and-assign in '
                     'place_casters)' % n)
    if 'booth.transformation' not in ov.split('def self.place_casters')[-1]:
        fails.append('the booth lift is no longer inside place_casters')
    for other in ('build-booth-components.rb', 'wr-deck.rb'):
        body = open(os.path.join(HERE, other), encoding='utf-8').read()
        for tok in ('booth.transformation', 'CP_BOOTH_LIFT'):
            if tok in body:
                fails.append('%s mentions %s — the lift is leaking out of the '
                             'caster pass' % (other, tok))
    return fails


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    consts = ('\n'.join(lift_const(lines, c) for c in CONSTS) + '\n'
              + '\n'.join(lift_scalar(lines, c) for c in SCALARS))
    prog = (SHIMS + FIXTURE
            .replace('__CONSTS__', consts)
            .replace('__METHODS__', '\n\n'.join(lift_method(lines, m) for m in METHODS)))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('wr-overlays pure logic: predicates, port mirroring, IEP move, hosts,'
          ' caster datum')
    leaks = lift_leak_check()
    for f in leaks:
        print('  FAIL (lift leak) %s' % f)
    ok = got == EXPECT and not leaks
    if ok:
        print('  PASS  (%d checks in one transcript + lift-leak scan)'
              % len(EXPECT.split(' | ')))
        return 0
    ge = got.split(' | ')
    ee = EXPECT.split(' | ')
    for i in range(max(len(ge), len(ee))):
        g = ge[i] if i < len(ge) else '(missing)'
        e = ee[i] if i < len(ee) else '(unexpected)'
        mark = 'ok  ' if g == e else 'FAIL'
        print('  %s got %-55s want %s' % (mark, g, e))
    return 1


if __name__ == '__main__':
    sys.exit(main())
