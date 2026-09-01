# -*- coding: utf-8 -*-
"""RUN booth-from-link's pack translation and roof-mount fence outside SketchUp.

    python rbtest-boothlink-cbl.py

Same discipline as rbtest-doorswing.py: boots SketchUp's own CRuby 3.2 through
rbparse.py and lifts `component_for`, `enh_width`, `cbl_pack` and
`roof_vent_complaints` VERBATIM out of booth-from-link.rb, so this test cannot
drift from the code it tests.

WHY IT EXISTS
-------------
booth-builder.html's applyRoofVent() rewrites every ' VNT' pack to ' CBL'
before a share link is serialised, so a roof-mounted design arrives carrying
'STDWL46 CBL'. component_for had no CBL branch: the pack was untranslatable,
the slot was left unassigned, and build-booth-components' guess_component
refilled it from the layout's own :sk => 'VNT'. A roof-mounted booth built
VENT walls, while the console said only that the roof unit was out of scope.
Reproduced live on 31 Aug 2026 (.forge/fixer/roof-vent-cbl/repro-rm-cbl.py):
slots N0 and E0 of an MDL 7272 S roof-mount link both built 46VNT.

WHAT IT ASSERTS
  1. a CBL pack translates to the real library name, Standard and Enhanced,
     for both vent-capable widths (40/46 -> 35.5/41.5)
  2. no VSS / EFS / caster suffix is ever appended to a cable wall — those name
     vent hardware a cable wall does not have, and no such .skp exists
  3. the VNT branch is untouched, suffixes and all
  4. the roof-mount fence passes a whole swap and names every slot of a half
     applied one, in both directions, and stays silent when rv = 0

MUTATION-CHECKED when written. Delete the `when /\\ASTDWL(\\d+)\\s+CBL\\b/i`
branch and checks 1 and 2 fail with nil; make roof_vent_complaints return []
unconditionally and every check in group 4 that expects a complaint fails.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

PROG = r'''
module WR_BoothLink
@@CONSTS@@

@@ENH_WIDTH@@

@@COMPONENT_FOR@@

@@CBL_PACK@@

  # The one stub: the real vent_slot_ids reads wr-booth-data.rb off disk, which
  # is a file-system fact, not the logic under test. $slots is set per case.
  def self.vent_slot_ids(_key)
    $slots
  end

@@ROOF_VENT_COMPLAINTS@@
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

O = { :vss => false, :efs => false, :casters => false, :ramp => false }
OPT = { :vss => true, :efs => true, :casters => true, :ramp => true }

# 1 - the cable wall translates, both variants, both vent-capable widths
check('STD 46 CBL',  WR_BoothLink.component_for('STDWL46 CBL', O, false), '46PanelCBL')
check('STD 40 CBL',  WR_BoothLink.component_for('STDWL40 CBL', O, false), '40PanelCBL')
check('ENH 46 CBL',  WR_BoothLink.component_for('STDWL46 CBL', O, true),  'ENH 41.5PanelCBL')
check('ENH 40 CBL',  WR_BoothLink.component_for('STDWL40 CBL', O, true),  'ENH 35.5PanelCBL')
check('CBL lowercase pack', WR_BoothLink.component_for('stdwl46 cbl', O, false), '46PanelCBL')

# 2 - and takes NO vent-hardware suffix, whatever the options say
check('STD 46 CBL ignores VSS/EFS/CP', WR_BoothLink.component_for('STDWL46 CBL', OPT, false), '46PanelCBL')
check('ENH 46 CBL ignores VSS/EFS/CP', WR_BoothLink.component_for('STDWL46 CBL', OPT, true),  'ENH 41.5PanelCBL')

# 3 - the vent branch is exactly as it was
check('STD 46 VNT plain',  WR_BoothLink.component_for('STDWL46 VNT', O, false), '46VNT')
check('STD 46 VNT loaded', WR_BoothLink.component_for('STDWL46 VNT', OPT, false), '46VNT_VSS_EFS_CP')
check('ENH 46 VNT plain',  WR_BoothLink.component_for('STDWL46 VNT', OPT, true), 'ENH 41.5VNT')
check('plain 46 wall',     WR_BoothLink.component_for('STDWL46', O, false), '46PanelSolid')
check('CBL is not a pack prefix of anything else',
      WR_BoothLink.component_for('STDWL46 CBLX', O, false), nil)

# 4 - the roof-mount fence
$slots = ['N0', 'E0']
whole  = { 'N0' => 'STDWL46 CBL', 'E0' => 'STDWL46 CBL', 'S0' => 'STDWL46 DRFRM R' }
half   = { 'N0' => 'STDWL46 CBL', 'E0' => 'STDWL46 VNT', 'S0' => 'STDWL46 DRFRM R' }
none   = { 'N0' => 'STDWL46 VNT', 'E0' => 'STDWL46 VNT', 'S0' => 'STDWL46 DRFRM R' }
gone   = { 'S0' => 'STDWL46 DRFRM R' }

check('rv=0 never complains, whatever the packs',
      WR_BoothLink.roof_vent_complaints(false, 'MDL 7272 S', none), [])
check('rv=0 with cable walls is not a complaint either',
      WR_BoothLink.roof_vent_complaints(false, 'MDL 7272 S', whole), [])
check('rv=1, swap whole -> silent',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', whole), [])
check('rv=1, one vent wall left -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', half).length, 2)
check('rv=1, half-apply names the offending slot',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', half)[1].include?('E0'), true)
check('rv=1, no swap at all -> complains about both',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', none).length, 3)
check('rv=1, vent slot missing from the link -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', gone).length, 3)
check('rv=1, vent slot missing says so by name',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', gone)[1].include?('no pack in the link'), true)

$slots = nil
check('rv=1 but the layout cannot be read -> complains rather than passing',
      WR_BoothLink.roof_vent_complaints(true, 'MDL NOPE S', whole).length, 1)
$slots = []
check('rv=1 on a booth with no vent walls -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 4242 S', whole).length, 1)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def consts(path):
    """ENH_WIDTH and PANEL_WIDTHS lifted verbatim, for the same reason the
    methods are: retyping the width table here would let it drift from the
    one that names the real files."""
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^  ENH_WIDTH = .*?\.freeze$', text, re.S | re.M)
    n = re.search(r'^  PANEL_WIDTHS = .*?$', text, re.M)
    if not m or not n:
        raise SystemExit('booth-from-link.rb: ENH_WIDTH / PANEL_WIDTHS not found')
    return m.group(0) + '\n' + n.group(0)


def main():
    src = os.path.join(HERE, 'booth-from-link.rb')
    prog = PROG.replace('@@CONSTS@@', consts(src))
    for token, name in (('@@ENH_WIDTH@@', 'enh_width'),
                        ('@@COMPONENT_FOR@@', 'component_for'),
                        ('@@CBL_PACK@@', 'cbl_pack'),
                        ('@@ROOF_VENT_COMPLAINTS@@', 'roof_vent_complaints')):
        prog = prog.replace(token, method_source(src, name))
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
