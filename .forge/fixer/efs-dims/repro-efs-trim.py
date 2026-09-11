# -*- coding: utf-8 -*-
"""Reproduce: the booth dimension stops at the vent box on an EFS wall.

    python .forge/fixer/efs-dims/repro-efs-trim.py

Benton, 11 Sep 2026, on a booth with a caster plate and exterior fan
silencers: "the dimension tool is not currently accounting for the EFS. The
dimensions should extend 10" total from the booth corner on booths with EFS."

Same harness as scripts/rbtest-boothdims.py: the PURE SECTION of
dimension-whisperroom.rb is lifted verbatim and run in SketchUp's own CRuby
3.2 through rbparse.py. One EFS wall part on the E wall of the 7296 E CP
fixture, its wall-parallel faces read the way face_levels reads them:

    97 / 98       the panel's two faces, 3726 sq in each
    103.5         the vent box's outer face, 1800 sq in    (5.5 past the 98 shell)
    108.125       the EFS silencer box's outer face, 220 sq in  (10.125 past)
    assembly edge 108.125

BEFORE the fix the 1.42.0 rule ("the vent box is the outboard level carrying
the most area; anything further out is a fitting") sets the E bound at
103.5, so the width reads 8' 7 1/2" and the silencer is outside the string.
AFTER, an EFS part is measured to its assembly's outboard edge and the width
reads 9' 0 1/8".

The 10.125 is DERIVED, not observed: _component-probe.tsv (measured off the
.skp files in SketchUp, 26 Aug 2026) boxes every 46-series EFS part 12.125 in
thick against 8.5468 for a plain 46VNT; minus the 1 in panel and the 1 in
the seals stand proud gives 10.125 IF all of the extra bulk is outboard. The
live run prints the real figure; this script only shows the RULE change.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, '..', '..', '..', 'scripts'))
sys.path.insert(0, SCRIPTS)
import rbparse  # noqa: E402

spec = importlib.util.spec_from_file_location('rbtest_boothdims', os.path.join(SCRIPTS, 'rbtest-boothdims.py'))
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)

PROG = r'''
@@DATA@@

module WR_BoothDims
@@PURE@@
end
BD = WR_BoothDims

levels = [[97.0, 3726.0], [98.0, 3726.0], [103.5, 1800.0], [108.125, 220.0]]
edge = 108.125
name = 'E0  46Vnt_VSS_EFS_CP'
res = BD.vent_box_level(levels, 1.0)

# The 1.42.0 rule as vent_box_bound applied it: move the bound in to the
# vent box face whenever that face is inboard of the assembly edge.
old = (edge - res[:box]) * 1.0 > 0.0 ? res[:box] : edge
# The rule under test, when the pure section carries it.
new = BD.respond_to?(:measure_to) ? BD.measure_to(name, edge, res, 1.0)[0] : nil

cp = [['S0  Right46Door',        [2.0, -30.0, 0.0, 48.0, 1.0, 81.0]],
      ['S1  46PanelSolid',       [50.0, 0.0, 0.0, 96.0, 1.0, 81.0]],
      ['N0  46PanelSolid',       [2.0, 73.0, 0.0, 48.0, 74.0, 81.0]],
      ['N1  46PanelSolid',       [50.0, 73.0, 0.0, 96.0, 74.0, 81.0]],
      ['E1  22PanelSolid',       [97.0, 50.0, 0.0, 98.0, 72.0, 81.0]],
      ['W0  46PanelSolid',       [0.0, 2.0, 0.0, 1.0, 48.0, 81.0]],
      ['W1  22PanelSolid',       [0.0, 50.0, 0.0, 1.0, 72.0, 81.0]],
      ['SW corner seal',         [0.0, 0.0, 0.0, 2.0, 2.0, 81.0]],
      ['SE corner seal',         [96.0, 0.0, 0.0, 98.0, 2.0, 81.0]],
      ['NW corner seal',         [0.0, 72.0, 0.0, 2.0, 74.0, 81.0]],
      ['NE corner seal',         [96.0, 72.0, 0.0, 98.0, 74.0, 81.0]]]
w = lambda { |x1| BD.extent_from_parts(cp + [[name, [97.0, 2.0, -4.75, x1, 60.0, 82.3125]]]) }
eo = w.call(old)
out = []
out << format('vent box face %.4f (%.0f sq in); beyond it: %s', res[:box], res[:box_area], res[:beyond].inspect)
out << format('BEFORE (1.42.0 rule): E bound %.4f -> width %.4f  (%s)', old, eo[:x1] - eo[:x0], eo[:x1_by])
if new.nil?
  out << 'AFTER: measure_to not present in the pure section - unfixed'
else
  en = w.call(new)
  out << format('AFTER  (EFS rule):    E bound %.4f -> width %.4f  (%s)', new, en[:x1] - en[:x0], en[:x1_by])
  out << format('the N wall (no EFS part) is untouched: y1 %.4f by %s', en[:y1], en[:y1_by])
end
out << ((new && (new - 108.125).abs < 1e-9) ? 'RESULT: FIXED' : 'RESULT: FAULT PRESENT')
out.join("\n")
'''


def main():
    src = open(suite.RB, encoding='utf-8').read()
    data = open(suite.DATA, encoding='utf-8').read()
    prog = PROG.replace('@@PURE@@', suite.pure_section(src)).replace('@@DATA@@', data)
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    return 0 if 'RESULT: FIXED' in got else 1


if __name__ == '__main__':
    sys.exit(main())
