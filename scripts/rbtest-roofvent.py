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
    (CLAUDE.md). unit_height quotes the MEASURED per-part height; Benton's
    stated 10 / 16.5 are the drawing figures. An HX roof-mount booth must
    carry the height extension INTO that total, and a booth that quotes the
    standard-height number is under-reporting the one constraint that must
    never be under-reported.
  * WHICH SIDE IS RIGHT. Four models (4284, 6084, 8484, 10284 — the 84-in-WIDE
    ones) seat their roof unit flush RIGHT instead of centred. Right is +x,
    the E wall booth-from-link.rb's WALL_WORD labels "Right". A mirrored rule
    passes every arithmetic check and puts the unit on the wrong side of four
    booths, so the tests below assert the gap is on the LEFT specifically.

WHAT IT ASSERTS
  1. digits/has_part accept every shape a model reaches us in, and the four
     sizes with no roof part are misses
  2. part_name gives the real .skp base for both variants, on all 22
  3. art_only excludes every scenery family and no buildable part
  4. unit_height takes the larger of stated and measured, both ways round
  5. ceiling_required adds the roof unit, the height extension, and the
     Enhanced clearance, and adds nothing at all when rv = 0
  6. roof_unit_blockers refuses an unsupported model and NOTHING else — the
     seating, EFS and HX are all answered — and the seating note explains
     which rule it applied
  7. impossible_roof_link fires only on rv = 1 with no part
  8. seat centres on the NOMINAL footprint, shifts the four 84-in-wide models
     to the RIGHT with the gap on the LEFT, closes its arithmetic on all 22
     measured parts, and refuses a part too big for the booth

MUTATION-CHECKED, 31 Aug 2026. Every mutation below was applied to
wr-roof-vent.rb, this test run, and the file restored:

  * MIRROR the flush-right shift (the gap moves to the right)  -> 17 failures
  * FLUSH_RIGHT_MODELS emptied, so nothing is ever shifted      ->  8 failures
  * shift the 84-in-DEEP models instead of the 84-in-wide ones  ->  9 failures
  * drop the height extension from ceiling_required             ->  6 failures
  * quote the STATED unit height instead of the measured part   -> 13 failures
  * put the HX refusal back, so an HX booth never seats         ->  2 failures
  * NOMINAL_INSET 1.0 -> 0.0 (seat off the exterior face)       -> 17 failures

The first of those is the one that matters most: a mirrored orientation is
arithmetically indistinguishable from the right one unless the test says which
SIDE the gap is on, which is why every flush-right check below names LEFT or
RIGHT rather than comparing two numbers to each other.

COERCION. This file's library is run in the minimal CRuby VM rbparse.py boots,
which does not define Float#to_f - so wr-roof-vent.rb writes `x * 1.0`, the same
convention and the same reason as wr-drop-lights.rb's pure section. A `.to_f`
there aborts the eval outright rather than raising, which reads as a broken
harness rather than as a broken line.
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

# 4 - the roof unit's height: the MEASURED part, always
check('flat quotes the measured 10.3125, not the stated 10',
      RV.unit_height('MDL 7272 S', false)[0], 10.3125)
check('and says where that came from',
      RV.unit_height('MDL 7272 S', false)[1].include?('measured'), true)
check('a VSS part that measures 10.3125 is quoted at 10.3125, not 16.5',
      RV.unit_height('MDL 96192 S', true)[0], 10.3125)
check('and still names the stated figure it did not use',
      RV.unit_height('MDL 96192 S', true)[1].include?('drawing figure'), true)
check('a VSS part that IS taller is quoted taller',
      RV.unit_height('MDL 4284 S', true)[0], 19.5)
check('every model quotes its own measured flat height',
      RV::PART_MODELS.reject { |m|
        RV.unit_height(m, false)[0] == RV::MEASURED[m][:flat][2]
      }, [])
check('every model quotes its own measured VSS height',
      RV::PART_MODELS.reject { |m|
        RV.unit_height(m, true)[0] == RV::MEASURED[m][:vss][2]
      }, [])
check('the six VSS parts that measure taller than their flat twin',
      RV::PART_MODELS.select { |m|
        RV.unit_height(m, true)[0] > RV.unit_height(m, false)[0]
      }, %w[4260 4284 4872 4896 6060 7272])

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
check('roof mount with VSS adds the VSS part measured height',
      rmv[:total], 83.0 + 10.499)
# HX ON A ROOF-MOUNTED BOOTH. Benton, 31 Aug 2026: the same part, sitting 10 in
# higher because the roof is 10 in higher. The room therefore has to give the
# EXTENDED clearance plus the unit - a figure that quotes the standard height
# here under-reports by exactly HX_ADD, which is the one error CLAUDE.md says
# must not happen.
rmh = RV.ceiling_required('MDL 7272 S', 'S', true, true, false)
check('HX + roof mount: the extension is in the booth half',
      rmh[:booth], 93.0)
check('HX + roof mount: and the unit still sits on top of it',
      rmh[:total], 93.0 + 10.3125)
check('an HX roof-mount booth needs exactly 10 more ceiling than the same '\
      'booth unextended', rmh[:total] - rm[:total], RV::HX_ADD)
rmhv = RV.ceiling_required('MDL 4284 S', 'S', true, true, true)
check('HX + roof mount + a genuinely taller VSS part',
      rmhv[:total], 83.0 + 10.0 + 19.5)
rmx = RV.ceiling_required('MDL 7272 E', 'E', true, true, true)
check('Enhanced + HX + roof mount + VSS', rmx[:total], 85.0 + 10.0 + 10.499)
check('rv = 0 adds nothing even on a model that has a roof part',
      RV.ceiling_required('MDL 7272 S', 'S', false, false, true)[:unit], 0.0)
check('an HX booth with rv = 0 gets no unit at all',
      RV.ceiling_required('MDL 7272 S', 'S', true, false, false)[:unit], 0.0)
check('the RM booth needs more ceiling than the portal fit card claims',
      rmv[:total] > 85.0, true)
nopart = RV.ceiling_required('MDL 4242 S', 'S', false, true, false)
check('rv = 1 on a model with no roof part adds no fictional unit height',
      [nopart[:unit], nopart[:total]], [0.0, 83.0])
check('and says why', nopart[:why].include?('no roof part'), true)
check('feet-and-inches formatting', RV.ft(99.5), "8'-3.5\"")

# 6 - the blockers, by name. Only one is left; HX, EFS and the seating are all
# answered, and a blocker that fires on any of those three now STOPS A BUILD
# THAT SHOULD HAPPEN.
plain = RV.roof_unit_blockers('MDL 7272 S', 'S', false, false, false)
check('a plain roof-mount booth has nothing left blocking it', plain, [])
check('HX no longer blocks - the same part just sits higher',
      RV.roof_unit_blockers('MDL 7272 S', 'S', true, false, false), [])
check('EFS no longer blocks - the shift is keyed to model width',
      RV.roof_unit_blockers('MDL 7272 S', 'S', false, true, false), [])
check('nor do they together',
      RV.roof_unit_blockers('MDL 7272 S', 'S', true, true, true), [])
check('no supported model is blocked',
      RV::PART_MODELS.reject { |m| RV.roof_unit_blockers(m, 'S', false, false, false).empty? },
      [])
nop = RV.roof_unit_blockers('MDL 4242 S', 'S', false, false, false)
check('an unsupported model stops at the missing part', nop.length, 1)
check('and names the model', nop[0].include?('4242'), true)
check('and names the file that is not there', nop[0].include?('RM4242.skp'), true)

# 7 - the fence
check('rv = 0 is never an impossible link',
      RV.impossible_roof_link('MDL 4242 S', false), [])
check('rv = 1 on a supported model is fine',
      RV.impossible_roof_link('MDL 7272 S', true), [])
check('rv = 1 on 4848 is refused',
      RV.impossible_roof_link('MDL 4848 S', true).length, 2)
check('and says the booth would end up with no ventilation',
      RV.impossible_roof_link('MDL 4848 S', true)[1].include?('NO ventilation'), true)

# 8 - THE SEATING. The exterior footprint of each model, x (left-right) then y
# (front-back), read out of scripts/wr-booth-data.rb's :w and :h (observed).
# Nominal is this minus 2 - 1 in per side - which is exactly the model number.
EXT = {
  '4260' => [62.0, 44.0],   '4284' => [86.0, 44.0],   '4872' => [74.0, 50.0],
  '4896' => [98.0, 50.0],   '6060' => [62.0, 62.0],   '6084' => [86.0, 62.0],
  '7272' => [74.0, 74.0],   '7296' => [98.0, 74.0],   '8484' => [86.0, 86.0],
  '84102' => [104.0, 86.0], '84126' => [128.0, 86.0], '9696' => [98.0, 98.0],
  '96120' => [122.0, 98.0], '96144' => [146.0, 98.0], '96168' => [170.0, 98.0],
  '96192' => [194.0, 98.0], '102102' => [104.0, 104.0], '102126' => [128.0, 104.0],
  '102144' => [146.0, 104.0], '102168' => [170.0, 104.0], '102186' => [188.0, 104.0],
  '10284' => [86.0, 104.0]
}
seat_of = lambda do |m, vss|
  box = RV::MEASURED[m][vss ? :vss : :flat]
  RV.seat(m, EXT[m][0], EXT[m][1], box[0], box[1])
end

check('every model has an exterior footprint to seat against',
      RV::PART_MODELS.reject { |m| EXT.key?(m) }, [])

# --- which models shift, and it must be the 84-in-WIDE ones ---------------
check('the flush-right list is exactly the models 84 in WIDE',
      RV::PART_MODELS.select { |m| EXT[m][0] == 86.0 }.sort,
      RV::FLUSH_RIGHT_MODELS.sort)
check('84102 and 84126 are 84 in DEEP, not wide, and are NOT shifted',
      [RV.flush_right('84102'), RV.flush_right('84126')], [false, false])
check('flush_right takes a payload model too',
      RV.flush_right('MDL 8484 S'), true)
check('and a plain model is centred', RV.flush_right('MDL 7272 S'), false)

# --- the default: centred on the nominal footprint -------------------------
c = seat_of.call('7272', false)
check('7272 centres: 3.25 of gap each side',      [c[:left], c[:right]], [3.25, 3.25])
check('7272 centres front to back: 4.0 each end', [c[:front], c[:back]], [4.0, 4.0])
check('7272 low corner lands 1 + 3.25 off the exterior', [c[:x], c[:y]], [4.25, 5.0])
check('7272 says which rule it applied', c[:rule].include?('centred'), true)
check('7272 is not flagged flush right', c[:flush_right], false)
check('every centred model is symmetric left-to-right',
      RV::PART_MODELS.reject { |m|
        next true if RV.flush_right(m)
        s = seat_of.call(m, false)
        (s[:left] - s[:right]).abs < 1e-9
      }.reject { |m| RV.flush_right(m) }, [])
check('every model is symmetric front-to-back, shifted or not',
      RV::PART_MODELS.reject { |m|
        s = seat_of.call(m, false)
        (s[:front] - s[:back]).abs < 1e-9
      }, [])
check('centring reproduces the stated 4 in front and back on 18 of the 22',
      RV::PART_MODELS.select { |m| seat_of.call(m, false)[:front] == 4.0 }.length, 18)
check('and 3 in on the four parts authored to the 84 series rule',
      RV::PART_MODELS.select { |m| seat_of.call(m, false)[:front] == 3.0 }.sort,
      %w[4284 84102 84126 8484])

# --- the exception: flush RIGHT, gap on the LEFT --------------------------
#
# THE DIRECTION IS THE POINT. Right is +x (booth-from-link.rb's WALL_WORD: the
# E wall is "Right", and wr-booth-data.rb puts E panels at high x). So the part
# is pushed to HIGH x, which leaves the slack at LOW x - the LEFT. Every one of
# these fails if the shift is mirrored, because :left and :right swap and :x
# drops back to 1 + slack/2 or to 1.
RV::FLUSH_RIGHT_MODELS.each do |m|
  s84 = seat_of.call(m, false)
  check("#{m}: the part measures 80.750 against an 84 nominal",
        RV::MEASURED[m][:flat][0], 80.75)
  check("#{m}: ALL 3.25 of the gap is on the LEFT", s84[:left], 3.25)
  check("#{m}: NO gap on the right", s84[:right], 0.0)
  check("#{m}: so the part's low x is 1 + 3.25, not 1 + 1.625", s84[:x], 4.25)
  check("#{m}: and its high x is flush with the nominal edge",
        s84[:x] + RV::MEASURED[m][:flat][0], EXT[m][0] - RV::NOMINAL_INSET)
  check("#{m}: the rule says RIGHT out loud", s84[:rule].include?('RIGHT'), true)
  check("#{m}: and is flagged", s84[:flush_right], true)
  check("#{m}: front and back are untouched by the shift",
        (s84[:front] - s84[:back]).abs < 1e-9, true)
end
check('the shift is NOT centring in disguise - it moves the part 1.625',
      seat_of.call('8484', false)[:x] -
        (RV::NOMINAL_INSET + (84.0 - 80.75) / 2.0), 1.625)
check('a centred model of the same 84 family is NOT shifted',
      seat_of.call('84102', false)[:left], 3.0)

# The 4284 VSS part measures 84.000 - the full nominal width - so its shift is
# a no-op and both gaps are zero. Asserted so a future measurement change that
# gives it slack is noticed rather than silently seated.
v4284 = seat_of.call('4284', true)
check('RM4284VSS fills the nominal width, so flush right moves it nowhere',
      [v4284[:left], v4284[:right]], [0.0, 0.0])

# --- every one of the 44 parts closes its own arithmetic -------------------
check('all 22 flat parts seat inside the footprint with the gaps summing right',
      RV::PART_MODELS.reject { |m|
        s = seat_of.call(m, false)
        s[:error].nil? &&
          (s[:left] + RV::MEASURED[m][:flat][0] + s[:right] -
           (EXT[m][0] - 2.0)).abs < 1e-9 &&
          (s[:front] + RV::MEASURED[m][:flat][1] + s[:back] -
           (EXT[m][1] - 2.0)).abs < 1e-9 &&
          s[:left] >= -1e-9 && s[:right] >= -1e-9
      }, [])
check('and all 22 VSS parts do too',
      RV::PART_MODELS.reject { |m|
        s = seat_of.call(m, true)
        s[:error].nil? &&
          (s[:left] + RV::MEASURED[m][:vss][0] + s[:right] -
           (EXT[m][0] - 2.0)).abs < 1e-9 &&
          s[:left] >= -1e-9 && s[:right] >= -1e-9
      }, [])

# --- a part that does not fit is refused, not hung over the edge ----------
bad = RV.seat('MDL 7272 S', 74.0, 74.0, 99.0, 40.0)
check('a part wider than the footprint refuses', bad[:error].nil?, false)
check('and says so by name', bad[:error].include?('does not'), true)
check('and hands back no coordinates', bad[:x], nil)

# --- the seating note says which rule was applied, in Benton's words -------
n84 = RV.seating_note('MDL 8484 S', false, false)
check('the 84-wide note says FLUSH RIGHT', n84.any? { |l| l.include?('FLUSH RIGHT') }, true)
check('and says the gap is on the LEFT', n84.any? { |l| l.include?('LEFT') }, true)
check('and defines which side +x is', n84.any? { |l| l.include?('+x') }, true)
check('and says the shift is keyed to model width, not to EFS',
      n84.any? { |l| l.include?('MODEL WIDTH') }, true)
check('and reports whether THIS booth has EFS',
      RV.seating_note('MDL 8484 S', false, true).any? { |l| l.include?('HAS EFS') }, true)
nc = RV.seating_note('MDL 7272 S', false, false)
check('the ordinary note says CENTRED', nc.any? { |l| l.include?('CENTRED') }, true)
check('and never claims a flush edge', nc.any? { |l| l.include?('FLUSH') }, false)
check('every note points at the probe that produced the numbers',
      (n84 + nc).any? { |l| l.include?('measure-rm.py') }, true)
check('every note line stays inside 78 columns',
      (n84 + nc + RV.seating_note('MDL 6084 S', true, true)).reject { |l| l.length <= 78 },
      [])

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
