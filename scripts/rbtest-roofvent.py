# -*- coding: utf-8 -*-
"""RUN wr-roof-vent.rb outside SketchUp.

    python rbtest-roofvent.py

Same discipline as rbtest-boothlink-cbl.py: boots SketchUp's own CRuby 3.2
through rbparse.py and loads wr-roof-vent.rb VERBATIM, whole. The file touches
no SketchUp API, so nothing has to be lifted or stubbed and the test cannot
drift from the code it tests.

WHY IT EXISTS
-------------
Roof-mounted ventilation is one change made in two places, and the wall half
already shipped (plugin 1.12.11). This is the roof half's knowledge: which of
the 22 models has a part, which .skp that part is, how much ceiling the booth
then needs, and every reason the unit is still not seated. Three of those are
traps with a wrong answer sitting right next to the right one:

  * the VSS NAMING TRAP. The portal's ART tables give a VSS variant only to 60
    and 72 (RM_VSS_SET); the per-model PARTS have one on all 22. Borrowing the
    art rule names the flat part on 20 booths.
  * ART SCENERY. RM60, RM72_VSS, RM144_BACK, RMVentilationLeftSideView and the
    rest sit in the same folder as the buildable parts and must never be
    composed into a build.
  * CEILING HEIGHT, which disqualifies a booth faster than anything else
    (CLAUDE.md). Benton's stated roof-unit height and the measured parts
    disagree in both directions, so unit_height takes the larger; a change that
    made it take the stated figure would under-report every flat booth by 5/16
    in, and one that took the measured figure would under-report a VSS booth by
    over 6 in.

WHAT IT ASSERTS
  1. digits/has_part accept every shape a model reaches us in, and the four
     sizes with no roof part are misses
  2. part_name gives the real .skp base for both variants, on all 22
  3. art_only excludes every scenery family and no buildable part
  4. unit_height takes the larger of stated and measured, both ways round
  5. ceiling_required adds the roof unit, the height extension, and the
     Enhanced clearance, and adds nothing at all when rv = 0
  6. roof_unit_blockers names HX, EFS and the unconfirmed seating, refuses an
     unsupported model outright, and the seating note explains itself
  7. impossible_roof_link fires only on rv = 1 with no part

MUTATION-CHECKED when written; every mutation below was applied, the test run,
and the file restored:
  * drop the 'VSS' suffix in part_name             -> 3 failures, all in group 2
  * return `stated` unconditionally in unit_height -> 4 failures, groups 4 and 5
  * make art_only return false                     -> 15 failures, group 3
  * drop the hx branch of roof_unit_blockers       -> 3 failures, group 6
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

PROG = r'''
@@LIB@@

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

RV = WR_RoofVent

# 1 - model identification
check('digits from a payload model',  RV.digits('MDL 7272'),   '7272')
check('digits from a layout key',     RV.digits('MDL 7272 S'), '7272')
check('digits from an Enhanced key',  RV.digits('MDL 96168 E'), '96168')
check('digits from bare digits',      RV.digits('102186'),     '102186')
check('digits of a non-model',        RV.digits('127 LP'),     '')
check('has_part on a supported model',   RV.has_part('MDL 7272 S'), true)
check('has_part on 4230 (RM_NO_SIZES)',  RV.has_part('MDL 4230 S'), false)
check('has_part on 4242 (RM_NO_SIZES)',  RV.has_part('MDL 4242 S'), false)
check('has_part on 4848 (RM_NO_SIZES)',  RV.has_part('MDL 4848 S'), false)
check('has_part on 127 LP',              RV.has_part('MDL 127 LP S'), false)
check('all 22 models are measured',
      RV::PART_MODELS.reject { |m| RV::MEASURED.key?(m) }, [])
check('nothing measured that is not a model',
      RV::MEASURED.keys.reject { |m| RV::PART_MODELS.include?(m) }, [])

# 2 - the part name, and the VSS trap
check('flat part name',        RV.part_name('MDL 7272 S', false), 'RM7272')
check('VSS part name',         RV.part_name('MDL 7272 S', true),  'RM7272VSS')
check('VSS on a model outside the art set',
      RV.part_name('MDL 102186 E', true), 'RM102186VSS')
check('every model has a VSS part name (the art rule would skip 20)',
      RV::PART_MODELS.reject { |m| RV.part_name(m, true) == "RM#{m}VSS" }, [])
check('no part name for an unsupported model',
      RV.part_name('MDL 4242 S', false), nil)

# 3 - art scenery never reaches a build
%w[RM60 RM72 RM84 RM96 RM192 RM60_BACK RM144_BACK RM60_VSS RM72_VSS_BACK
   RMVentilationIntakeBox RMVentilationExhaustBox RMVentilationLeftSideView
   RMVentilationVSSRightSideView RMVSS_Stack_LeftSideView].each do |n|
  check("art_only #{n}", RV.art_only(n), true)
end
%w[RM7272 RM7272VSS RM102186 RM10284VSS RM4260 RM96192VSS].each do |n|
  check("art_only #{n} is a real part", RV.art_only(n), false)
end
check('art_only forgives a .skp extension', RV.art_only('RM60.skp'), true)

# 4 - the roof unit's height: the LARGER of stated and measured, always
check('flat takes the measured 10.3125 over the stated 10',
      RV.unit_height('MDL 7272 S', false)[0], 10.3125)
check('and says where that came from',
      RV.unit_height('MDL 7272 S', false)[1].include?('measured'), true)
check('VSS takes the stated 16.5 where the part measures only 10.3125',
      RV.unit_height('MDL 96192 S', true)[0], 16.5)
check('and says the part measures less',
      RV.unit_height('MDL 96192 S', true)[1].include?('measures only'), true)
check('VSS takes the measured 19.5 where the part IS taller',
      RV.unit_height('MDL 4284 S', true)[0], 19.5)
check('no roof unit is ever reported shorter than Benton stated',
      RV::PART_MODELS.reject { |m|
        RV.unit_height(m, false)[0] >= 10.0 && RV.unit_height(m, true)[0] >= 16.5
      }, [])

# 5 - the ceiling a room must give
std = RV.ceiling_required('MDL 7272 S', 'S', false, false, false)
check('a plain Standard booth needs the catalogue clearance and no more',
      [std[:booth], std[:unit], std[:total]], [83.0, 0.0, 83.0])
enh = RV.ceiling_required('MDL 7272 E', 'E', false, false, false)
check('Enhanced is 85', enh[:total], 85.0)
hx = RV.ceiling_required('MDL 7272 S', 'S', true, false, false)
check('the height extension adds 10', hx[:total], 93.0)
rm = RV.ceiling_required('MDL 7272 S', 'S', false, true, false)
check('roof mount adds the unit', rm[:total], 93.3125)
rmv = RV.ceiling_required('MDL 7272 S', 'S', false, true, true)
check('roof mount with VSS adds 16.5', rmv[:total], 99.5)
rmx = RV.ceiling_required('MDL 7272 E', 'E', true, true, true)
check('Enhanced + HX + roof mount + VSS', rmx[:total], 85.0 + 10.0 + 16.5)
check('rv = 0 adds nothing even on a model that has a roof part',
      RV.ceiling_required('MDL 7272 S', 'S', false, false, true)[:unit], 0.0)
check('the RM booth needs more ceiling than the portal fit card claims',
      rmv[:total] > 85.0, true)
nopart = RV.ceiling_required('MDL 4242 S', 'S', false, true, false)
check('rv = 1 on a model with no roof part adds no fictional unit height',
      [nopart[:unit], nopart[:total]], [0.0, 83.0])
check('and says why', nopart[:why].include?('no roof part'), true)
check('feet-and-inches formatting', RV.ft(99.5), "8'-3.5\"")

# 6 - the blockers, by name
plain = RV.roof_unit_blockers('MDL 7272 S', 'S', false, false, false)
check('a plain roof-mount booth is blocked only on the seating', plain.length, 1)
check('the seating note points at the probe that produced the numbers',
      RV.seating_note.any? { |l| l.include?('measure-rm.py') }, true)
check('the seating note says the reference face is the NOMINAL footprint',
      RV.seating_note.any? { |l| l.include?('NOMINAL') }, true)
check('the seating note stays inside 78 columns',
      RV.seating_note.reject { |l| l.length <= 78 }, [])
check('and names the part it measured', plain[0].include?('RM7272'), true)
check('and quotes the measured box', plain[0].include?('65.500'), true)
hxb = RV.roof_unit_blockers('MDL 7272 S', 'S', true, false, false)
check('HX is refused by name', hxb.length, 2)
check('HX names the file that does not exist',
      hxb[0].include?('RM7272_HX.skp'), true)
efsb = RV.roof_unit_blockers('MDL 7272 S', 'S', false, true, false)
check('EFS is refused by name rather than choosing an edge', efsb.length, 2)
check('EFS quotes the word that makes it unconfirmed',
      efsb[0].include?('might'), true)
both = RV.roof_unit_blockers('MDL 7272 S', 'S', true, true, true)
check('HX and EFS and the seating are all named', both.length, 3)
nop = RV.roof_unit_blockers('MDL 4242 S', 'S', false, false, false)
check('an unsupported model stops at the missing part', nop.length, 1)
check('and names the model', nop[0].include?('4242'), true)

# 7 - the fence
check('rv = 0 is never an impossible link',
      RV.impossible_roof_link('MDL 4242 S', false), [])
check('rv = 1 on a supported model is fine',
      RV.impossible_roof_link('MDL 7272 S', true), [])
check('rv = 1 on 4848 is refused',
      RV.impossible_roof_link('MDL 4848 S', true).length, 2)
check('and says the booth would end up with no ventilation',
      RV.impossible_roof_link('MDL 4848 S', true)[1].include?('NO ventilation'), true)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    lib = open(os.path.join(HERE, 'wr-roof-vent.rb'), encoding='utf-8').read()
    got = rbparse.rb_eval(rbparse.boot(), PROG.replace('@@LIB@@', lib))
    print(got)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
