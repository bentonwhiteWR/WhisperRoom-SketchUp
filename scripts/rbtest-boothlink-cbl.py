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
  4. the roof-mount fence passes a whole swap, refuses a genuinely half applied
     one with the count and the walls that disagree, and stays silent at rv = 0
  5. THE 2026-09-09 DEFECT: a roof-mounted design whose cable walls have been
     DRAGGED off the layout's default vent slots builds, because the rule is a
     count over the whole outer shell and not an identity check on slot ids
  6. THE 7 IN WIDE-ACCESS COMPANION (2026-09-10): the portal's literal
     'STDWL7 / WL16' translates to the 7 in wall on both shells - 7Panel and
     ENH 2.5Panel - and takes no option suffix. Before this it was
     untranslatable and every Enhanced 4016-type WA booth refused to build.

WHY GROUP 5 EXISTS
------------------
roof_vent_complaints used to require a CBL pack at each of the layout's own VNT
slot ids. booth-builder.html's doSwap moves wall packs between any two slots of
the same module width and applyRoofVent is position-blind, so a customer who
rearranges their booth ends up with cable walls on slots whose layout default is
SOLID. The portal's own invariant is (VNT + CBL) === layout.ventSets, a COUNT
(booth-builder.html:3496-3536 and :4195, observed). Benton hit the false refusal
on an MDL 96120 E, ADA door right, roof mount + VSS: "1 of 3 vent slot(s) carry
a cable-wall (CBL) pack", with N0 and N2 reading a plain STDWL46 because the
cable walls had moved. Nothing was built.

MUTATION-CHECKED when written, and again on the 2026-09-09 fix. Delete the
`when /\\ASTDWL(\\d+)\\s+CBL\\b/i` branch and checks 1 and 2 fail with nil; make
roof_vent_complaints return [] unconditionally and every check in groups 4 and 5
that expects a complaint fails; put the old per-slot identity check back and the
six group-5 checks that expect a build go red.
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

  # The second stub, same reason: outer_panel_ids reads the same file off disk.
  # $panels is every OUTER panel slot the model has, because a rearranged booth
  # can park a cable wall on a slot whose layout default is SOLID.
  def self.outer_panel_ids(_key)
    $panels
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

# 4 - the roof-mount fence: a COUNT rule, not a per-slot identity rule
$slots  = ['N0', 'E0']
$panels = ['N0', 'E0', 'S0']
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
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', half).empty?, false)
check('rv=1, half-apply names the leftover vent wall',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', half).join(' ').include?('E0'), true)
check('rv=1, half-apply counts the cable walls it DID find',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', half)[0].start_with?('1 of'), true)
check('rv=1, no swap at all -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', none)[0].start_with?('0 of'), true)
check('rv=1, vent slot missing from the link -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', gone).empty?, false)
check('rv=1, a link short of vent walls says so, not "wrong slot"',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 7272 S', gone).join(' ').include?('neither a vent nor a cable pack'), true)

$slots = nil
check('rv=1 but the layout cannot be read -> complains rather than passing',
      WR_BoothLink.roof_vent_complaints(true, 'MDL NOPE S', whole).length, 1)
$slots  = []
$panels = ['N0', 'E0', 'S0']
check('rv=1 on a booth with no vent walls -> complains',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 4242 S', whole).length, 1)

# 5 - THE REPORTED BUG (Benton, 2026-09-09). MDL 96120 E, Enhanced, ADA door,
# roof mount + VSS. The customer DRAGGED the cable walls off the two Back-wall
# slots the layout ventilates by default. booth-builder.html's doSwap moves the
# packs between any two same-module slots and applyRoofVent is position-blind,
# so this is an ordinary, buildable rearrangement — the portal's own invariant
# is (VNT + CBL) === layout.ventSets, a COUNT (booth-builder.html:3496-3536,
# observed). The fence used to demand a CBL pack at each of N0/N2/E0 by name and
# refused the whole build. Real ids and sizes from lib/pl-data/booth-layouts.json.
$slots  = ['N0', 'N2', 'E0']
$panels = ['N0', 'N1', 'N2', 'S0', 'S1', 'S2', 'E0', 'E1', 'W0', 'W1']
DOOR = 'WA STDDRFRM R'
moved = { 'N0' => 'STDWL46',      'N1' => 'STDWL22', 'N2' => 'STDWL46',
          'S0' => DOOR,           'S1' => 'STDWL22', 'S2' => 'STDWL46 CBL',
          'E0' => 'STDWL46 CBL',  'E1' => 'STDWL46',
          'W0' => 'STDWL46 CBL',  'W1' => 'STDWL46' }
# genuinely half applied: one of the three cable walls is still a VENT wall
halfmoved = moved.merge('W0' => 'STDWL46 VNT')
# and short outright: that wall carries no vent or cable pack at all
shortmoved = moved.merge('W0' => 'STDWL46')
# the layout default arrangement, untouched, still passes
default96 = { 'N0' => 'STDWL46 CBL', 'N1' => 'STDWL22', 'N2' => 'STDWL46 CBL',
              'S0' => DOOR,          'S1' => 'STDWL22', 'S2' => 'STDWL46',
              'E0' => 'STDWL46 CBL', 'E1' => 'STDWL46',
              'W0' => 'STDWL46',     'W1' => 'STDWL46' }

check('96120 E RM: cable walls MOVED off the default vent slots -> builds',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', moved), [])
check('96120 E RM: the default arrangement still builds',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', default96), [])
check('96120 E RM: genuinely half applied is STILL refused',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', halfmoved).empty?, false)
check('96120 E RM: half applied names the leftover vent wall by slot',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', halfmoved).join(' ').include?('W0'), true)
check('96120 E RM: half applied counts 2 of 3',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', halfmoved)[0].start_with?('2 of'), true)
check('96120 E RM: a link one cable wall SHORT is still refused',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', shortmoved).empty?, false)
check('96120 E RM: the refusal never claims a slot is the wrong slot',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', halfmoved).join(' ').include?('expected a CBL pack here'), false)
# and the count is over ALL outer panels, not just the layout's VNT slots: every
# cable wall here sits on a slot whose default kind is SOLID or DRFRM-adjacent.
allmoved = { 'N0' => 'STDWL46',     'N1' => 'STDWL22', 'N2' => 'STDWL46',
             'S0' => DOOR,          'S1' => 'STDWL22', 'S2' => 'STDWL46 CBL',
             'E0' => 'STDWL46',     'E1' => 'STDWL46 CBL',
             'W0' => 'STDWL46 CBL', 'W1' => 'STDWL46' }
check('96120 E RM: no cable wall on ANY default vent slot still builds',
      WR_BoothLink.roof_vent_complaints(true, 'MDL 96120 E', allmoved), [])

# 6 - the 7 in wide-access companion. booth-builder.html's shrinkPack emits
# exactly 'STDWL7 / WL16' for it (observed 2026-09-10); the packing list's Z02
# is a 7 + 16 bundle where the 7 stands in the slot. The Enhanced twin is the
# 2.5 the inner wall closes on beside the 44.5 ENH WA door.
check('7 in WA companion, Standard', WR_BoothLink.component_for('STDWL7 / WL16', O, false), '7Panel')
check('7 in WA companion, Enhanced', WR_BoothLink.component_for('STDWL7 / WL16', O, true), 'ENH 2.5Panel')
check('7 in WA companion ignores every option', WR_BoothLink.component_for('STDWL7 / WL16', OPT, true), 'ENH 2.5Panel')
check('7 in WA companion, spacing and case forgiven', WR_BoothLink.component_for('stdwl7/wl16', O, false), '7Panel')
check('a plain STDWL7 is still the 7 in wall', WR_BoothLink.component_for('STDWL7', O, false), '7Panel')
check('the companion string is not a prefix of anything', WR_BoothLink.component_for('STDWL7 / WL16 VNT', O, false), nil)

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
