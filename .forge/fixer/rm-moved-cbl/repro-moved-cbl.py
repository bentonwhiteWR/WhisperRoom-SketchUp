# -*- coding: utf-8 -*-
"""The REPORTED bug, end to end on the REAL layout data — no stubbed slot lists.

    python .forge/fixer/rm-moved-cbl/repro-moved-cbl.py

Benton, 2026-09-09: MDL 96120 E, Enhanced, ADA door right, roof mount (rv = 1)
+ VSS, one structural mod. He had DRAGGED the cable walls off the Back wall.
booth-from-link.rb refused the whole build with "1 of 3 vent slot(s) carry a
cable-wall (CBL) pack ... N0: STDWL46 — expected a CBL pack here".

rbtest-boothlink-cbl.py pins the fence with stubbed slot lists. This one uses
the real wr-booth-data.rb, so it also proves the two things that test cannot:

  A. vent_slot_ids / outer_panel_ids read MDL 96120 E correctly off disk
     (3 vent slots, 10 outer panels) — the counts the fence now compares.
  B. the SLOT -> PART translation follows the PACK, not the layout default:
     the moved slots emit the cable-wall part and the vacated default vent
     slots emit a plain solid wall, on the Standard outer shell and the
     Enhanced inner shell alike. build-booth-components.rb:2175 places
     assign[p[:id]] per slot id and only falls back to the layout's own :sk
     when a slot was left unassigned, so this is what stands in the model.

Exit 0 = the reported design builds and builds the right booth.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'scripts'))
sys.path.insert(0, SCRIPTS)
import rbparse                      # noqa: E402
from rbtest import method_source    # noqa: E402

SRC = os.path.join(SCRIPTS, 'booth-from-link.rb')
DATA = os.path.join(SCRIPTS, 'wr-booth-data.rb').replace(os.sep, '/')

PROG = r'''
module WR_BoothLink
@@CONSTS@@
  DATA = "@@DATA@@"
@@ENH_WIDTH@@
@@COMPONENT_FOR@@
@@CBL_PACK@@
@@VENT_SLOT_IDS@@
@@OUTER_PANEL_IDS@@
@@OUTER_PANELS@@
@@ROOF_VENT_COMPLAINTS@@
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

KEY  = 'MDL 96120 E'
DOOR = 'WA STDDRFRM R'
# the arrangement Benton actually had: the three cable walls dragged onto the
# Front and Left walls, the layout's own vent slots left as plain solid walls.
MOVED = { 'N0' => 'STDWL46',     'N1' => 'STDWL22', 'N2' => 'STDWL46',
          'S0' => DOOR,          'S1' => 'STDWL22', 'S2' => 'STDWL46 CBL',
          'E0' => 'STDWL46 CBL', 'E1' => 'STDWL46',
          'W0' => 'STDWL46 CBL', 'W1' => 'STDWL46' }

# ---- A: the real layout reads the way the count rule needs it to -----------
check('vent slots of MDL 96120 E, off disk',
      WR_BoothLink.vent_slot_ids(KEY).sort, ['E0', 'N0', 'N2'])
check('outer panel slots of MDL 96120 E, off disk',
      WR_BoothLink.outer_panel_ids(KEY).sort,
      ['E0', 'E1', 'N0', 'N1', 'N2', 'S0', 'S1', 'S2', 'W0', 'W1'])

# ---- the refusal, on the real data ----------------------------------------
check('THE REPORTED DESIGN BUILDS (cable walls moved off the default slots)',
      WR_BoothLink.roof_vent_complaints(true, KEY, MOVED), [])
check('one cable wall turned back into a vent wall is STILL refused',
      WR_BoothLink.roof_vent_complaints(true, KEY, MOVED.merge('W0' => 'STDWL46 VNT')).empty?,
      false)
check('one cable wall missing outright is STILL refused',
      WR_BoothLink.roof_vent_complaints(true, KEY, MOVED.merge('W0' => 'STDWL46')).empty?,
      false)

# ---- B: the parts follow the PACK, not the layout default ------------------
O = { :vss => true, :efs => false, :casters => false, :ramp => true }
%w[S2 E0 W0].each do |sid|
  check("#{sid} (moved cable wall) -> outer part",
        WR_BoothLink.component_for(MOVED[sid], O, false), '46PanelCBL')
  check("#{sid}i (moved cable wall) -> inner IEP part",
        WR_BoothLink.component_for(MOVED[sid], O, true), 'ENH 41.5PanelCBL')
end
%w[N0 N2].each do |sid|
  check("#{sid} (vacated DEFAULT vent slot) -> plain solid outer part",
        WR_BoothLink.component_for(MOVED[sid], O, false), '46PanelSolid')
  check("#{sid}i (vacated DEFAULT vent slot) -> plain solid inner part",
        WR_BoothLink.component_for(MOVED[sid], O, true), 'ENH 41.5PanelSolid')
end
check('no vent part is emitted anywhere in this booth',
      MOVED.values.map { |p| WR_BoothLink.component_for(p, O, false) }
           .compact.any? { |n| n.include?('VNT') }, false)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    import re
    text = open(SRC, encoding='utf-8').read()
    m = re.search(r'^  ENH_WIDTH = .*?\.freeze$', text, re.S | re.M)
    n = re.search(r'^  PANEL_WIDTHS = .*?$', text, re.M)
    prog = PROG.replace('@@CONSTS@@', m.group(0) + '\n' + n.group(0))
    prog = prog.replace('@@DATA@@', DATA)
    for token, name in (('@@ENH_WIDTH@@', 'enh_width'),
                        ('@@COMPONENT_FOR@@', 'component_for'),
                        ('@@CBL_PACK@@', 'cbl_pack'),
                        ('@@VENT_SLOT_IDS@@', 'vent_slot_ids'),
                        ('@@OUTER_PANEL_IDS@@', 'outer_panel_ids'),
                        ('@@OUTER_PANELS@@', 'outer_panels'),
                        ('@@ROOF_VENT_COMPLAINTS@@', 'roof_vent_complaints')):
        prog = prog.replace(token, method_source(SRC, name))
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
