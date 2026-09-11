# -*- coding: utf-8 -*-
"""RUN dimension-whisperroom.rb's pure section outside SketchUp.

    python rbtest-boothdims.py

Same VM and same discipline as rbtest-roofvent.py: SketchUp's own CRuby 3.2
booted through rbparse.py. The PURE SECTION of dimension-whisperroom.rb is
lifted VERBATIM between its two markers on every run, so the test cannot
drift from the code — edit the extent rule and this runs the edit.

WHY IT EXISTS
-------------
The tool measures a booth off its parts and places three strings at one of
four corners. Every one of those decisions is arithmetic on names and boxes,
and every one has a wrong answer that LOOKS right on screen:

  * a door part voting on the footprint (its open leaf pushes the front
    edge out and the width string floats off the seals);
  * a wall part voting on the height (a 46VNT is 81.86 tall, a Standard
    ceiling tops at 82 — the string would overshoot by nothing you could see
    and read the wrong number);
  * a mirrored corner table (FL drawn as FR: the "rotated" set lands on the
    same side it left);
  * a catalogue reconciliation that adds the vent projection to the wrong
    axis, so a real mismatch is reported on the axis that agrees.

Each is pinned below by NAME — which side, which part, which axis — never by
comparing two numbers to each other, because a mirror passes that.

WHAT IT ASSERTS
  1. classify: walls and vent housings vote; doors, the inner IEP shell,
     mid-wall seals, placeholders, roof unit, caster plates and EFP do not;
     STD/ENH/FLi/CLi deck parts are floor or ceiling.
  2. door_wall / vents_from_names / booth_name? — the identification regexes.
  3. extent_from_parts on a synthetic 7296 E built from wr-booth-data.rb's
     own polygons: 98 x 79.5 x 84.3125, with the part that set each side
     named; a door-only front wall falls to the corner seals; no deck means
     the walls carry the height and the flag is set; nothing means nil.
  4. layout: all four rows of the spec §7 table for a south door, exactly;
     a north door mirrors the frame (right = W).
  5. next_corner FR -> FL -> RL -> RR -> FR; press_of.
  6. side_slab and aabb_overlap? — the obstruction test.
  7. catalogue_extent and reconcile — the printed cross-check, its 1/4 in
     tolerance and its axis naming.
  9. THE VENT BOX AND THE CASTER PLATE (1.42.0): a wall part's outboard
     extent is its vent-box FACE (the outboard level carrying the most
     area beyond the panel band), never its assembly box; a caster plate
     is in the height. Fixture: Benton's 7296 E on a CP, 8' 7 1/2" x
     6' 7 1/2"; the height reads what the plate adds. ONE DATUM SINCE
     1.49.0: the plate's tray floor stands 4.75 (WR_Overlays::CP_BOOTH_LIFT)
     under the booth's FLOOR STACK, so an Enhanced booth on a plate reads
     84.3125 + 4.75 = 89.0625 = 7'-5 1/16" — Benton, 10 Sep 2026, which
     supersedes both his earlier 7'-4 1/16" (a 3.75 plate under the mat,
     retracted and no longer pinned anywhere) and the 7'-4 3/4" the old
     seating produced. The superseded seating is still exercised, by name,
     so a regression to it is a FAIL rather than a silently smaller number.
  8. ONE AXIS PER WALL (1.40.0): a protrusion on each of the four walls
     extends exactly the bound normal to that wall and never the other
     axis; the shell corners come from the corner seals; each protrusion
     is reported as proud (its own axis) and overhang (the other axis, not
     counted). Benton's EFS hanging off a back wall past the corner made
     the width read 9' 10 5/8" — the union box of every part.

MUTATION-CHECKED, 10 Sep 2026. Each mutation was applied to
dimension-whisperroom.rb, this test run, FAIL confirmed, the file restored:

  * corner_signs 'FL' -> [1, 1] (rotation becomes a no-op)        -> 4 failures
  * CORNERS order reversed (first press goes to the rear)          -> 6 failures
  * height pushed GAP instead of GAP_RISE                          -> 4 failures
  * classify lets a door vote on the footprint                     -> 5 failures
  * floor parts no longer set z0 (walls do)                        -> 4 failures
  * catalogue_extent adds the N face to X                          -> 2 failures
  * reconcile tolerance x10                                        -> 6 failures
  * walls push all four bounds again (the union box, 1.37.0 rule)  -> 10 failures
  * vent_box_level takes the OUTERMOST level (the assembly edge)    -> 4 failures
  * caster plate no longer lowers z0                                 -> 4 failures
  * (10 Sep 2026, 1.49.0) the CP fixture's plate put back where the
    pre-1.49.0 builder seated it - 4.75 under the STANDARD floor, so
    its bottom is -5.75 - which is the geometry a regressed builder
    would produce and reads 7' 4 3/4" instead of 7' 5 1/16"        -> 3 failures
    (the builder side of that same regression is mutation-checked in
     rbtest-overlays.py, where it costs 3 more)
  * panel band collapses to one level (panel face becomes the box)   -> 4 failures

The last one first died by crashing the harness (r[0] on an empty list) rather
than by a FAIL line; the nil guards on those checks exist so a mutant is
reported, not tripped over.

COERCION. The minimal VM has no Float#to_f, so the pure section writes
`x * 1.0` — the same convention as wr-roof-vent.rb and for the same reason.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

RB = os.path.join(HERE, 'dimension-whisperroom.rb')
DATA = os.path.join(HERE, 'wr-booth-data.rb')

PROG = r'''
@@DATA@@

module WR_BoothDims
@@PURE@@
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

BD = WR_BoothDims

# 1 - classify
check('a vent housing is a wall part',      BD.classify('N0  46VNT'), :wall)
check('a solid panel is a wall part',       BD.classify('S1  46PanelSolid'), :wall)
check('an HX panel is a wall part',         BD.classify('E1  46PanelSolid_HX'), :wall)
check('a door does not vote',               BD.classify('S0  Right46Door'), nil)
check('a wide-access door does not vote',   BD.classify('S0  Right49WADoorWithRamp'), nil)
check('the inner IEP shell does not vote',  BD.classify('N0i  ENH 41.5VNT'), nil)
check('a mid-wall seal does not vote',      BD.classify('N-seal0  STDSS8'), nil)
check('a corner seal votes',                BD.classify('SW corner seal'), :corner)
check('an inner corner seal is a corner too (inboard, so it never sets an extreme)',
      BD.classify('SW corner seal i  ENH CornerSeamSeal'), :corner)
check('a placeholder does not vote',        BD.classify('MISSING  S0  Right46Door.skp'), nil)
check('a placeholder label does not vote',  BD.classify('MISSING label  S0'), nil)
check('the roof unit does not vote',        BD.classify('RM7296 roof unit'), nil)
check('a caster plate votes on the height bottom only', BD.classify('CP7296  caster plate'), :caster)
check('the roof unit under its other names does not vote',
      ['RFU', 'RM96', 'RM7296 roof unit'].map { |n| BD.classify(n) }, [nil, nil, nil])
check('an EFP slab does not vote',          BD.classify('EFP7296 elevated floor'), nil)
check('a STD floor is a floor',             BD.classify('STD9648FL SIDE'), :floor)
check('a STD ceiling is a ceiling',         BD.classify('STD9648CL SIDE R'), :ceiling)
check('an ENH floor is a floor',            BD.classify('ENH 9648FL CTR'), :floor)
check('the IEP mat is a floor',             BD.classify('FLi  ENH 9648FL SIDE'), :floor)
check('the IEP tray is a ceiling',          BD.classify('CLi  ENH 9648CL SIDE'), :ceiling)
check('a block-out floor group is nothing', BD.classify('floor'), nil)
check('an empty name is nothing',           BD.classify(''), nil)

# 2 - identification regexes
names_7296 = ['N0  46VNT', 'N1  46VNT', 'S0  Right46Door', 'S1  46PanelSolid',
              'E0  46PanelSolid', 'E1  22PanelSolid', 'W0  46PanelSolid', 'W1  22PanelSolid']
check('door wall read off the parts',    BD.door_wall(names_7296), 'S')
check('no door part -> nil',             BD.door_wall(['N0  46VNT', 'E0  46PanelSolid']), nil)
check('door on the east wall',           BD.door_wall(['E0  Right46Door', 'S0  46PanelSolid']), 'E')
check('vents: N only on the 7296',       BD.vents_from_names(names_7296), [['N'], false])
check('vents: 46NV is a blank, not a vent',
      BD.vents_from_names(['N0  46NV', 'E0  46VNT']), [['E'], false])
check('vents: EFS is flagged',
      BD.vents_from_names(['N0  46VNT_EFS', 'E0  46Vent']), [['E', 'N'], true])
check('vents: inner shell vents are not counted twice',
      BD.vents_from_names(['N0  46VNT', 'N0i  ENH 41.5VNT']), [['N'], false])
check('booth_name? on the components builder name', BD.booth_name?('MDL 96120 E (components)'), true)
check('booth_name? on a block-out',                  BD.booth_name?('MDL 4260 S'), true)
check('booth_name? on a bare key',                   BD.booth_name?('7296 S'), true)
check('booth_name? refuses a room wall',             BD.booth_name?('N wall'), false)
check('booth_name? refuses Room',                    BD.booth_name?('Room'), false)

# 3 - the extent, from the catalogue's own polygons for the 7296 E
spec = WR_BOOTH_DATA::BOOTHS['MDL 7296 E']
parts = []
spec[:parts].each do |p|
  next unless p[:sh] == 'out'
  xs = p[:poly].map { |q| q[0] * 1.0 }
  ys = p[:poly].map { |q| q[1] * 1.0 }
  name = case p[:k]
         when 'panel'
           kind = case p[:sk]
                  when 'VNT'   then '46VNT'
                  when 'DRFRM' then 'Right46Door'
                  else              '46PanelSolid'
                  end
           "#{p[:id]}  #{kind}"
         when 'corner' then p[:id]
         else "#{p[:id]}  STDSS8"
         end
  y1 = ys.max
  # The built vent housing stands 5.5 proud of the catalogue box (74), the
  # way the reference image's 6' 7 1/2" says it does.
  y1 = 74.0 + 5.5 if p[:sk] == 'VNT' && p[:id][0, 1] == 'N'
  parts << [name, [xs.min, ys.min, 0.0, xs.max, y1, 81.0]]
end
# The open door leaf, modelled inside the door component, pokes out the
# front. It must not move the front edge.
parts.map! { |n, b| n =~ /Door/ ? [n, [b[0], -30.0, 0.0, b[3], b[4], 81.0]] : [n, b] }
parts << ['STD9648FL SIDE', [1.0, 1.0, -1.0, 49.0, 73.0, 0.0]]
parts << ['STD9648FL SIDE', [49.0, 1.0, -1.0, 97.0, 73.0, 0.0]]
parts << ['FLi  ENH 9648FL SIDE', [3.25, 3.25, -1.3125, 94.75, 70.75, -1.0]]
parts << ['STD9648CL SIDE', [1.0, 1.0, 81.0, 49.0, 73.0, 82.0]]
parts << ['STD9648CL SIDE', [49.0, 1.0, 81.0, 97.0, 73.0, 82.0]]
parts << ['CLi  ENH 9648CL SIDE', [3.25, 3.25, 81.25, 94.75, 70.75, 83.0]]
parts << ['RM7296 roof unit', [20.0, 20.0, 82.0, 78.0, 54.0, 92.3125]]
parts << ['N0i  ENH 41.5VNT', [4.25, 69.75, 0.0, 45.75, 71.75, 79.5]]

ext = BD.extent_from_parts(parts)
check('7296 E: across X is 98',             [ext[:x0], ext[:x1]], [0.0, 98.0])
check('7296 E: across Y is 79.5 (vent)',    [ext[:y0], ext[:y1]], [0.0, 79.5])
check('7296 E: height is mat to tray',      [ext[:z0], ext[:z1]], [-1.3125, 83.0])
check('7296 E: 84.3125 overall',            ext[:z1] - ext[:z0], 84.3125)
check('7296 E: y1 was set by a vent housing', ext[:y1_by], 'N0  46VNT')
check('7296 E: x0 was set by a corner seal',  ext[:x0_by] =~ /corner seal/ ? true : false, true)
check('7296 E: z0 was set by the IEP mat',    ext[:z0_by], 'FLi  ENH 9648FL SIDE')
check('7296 E: z1 was set by the IEP tray',   ext[:z1_by], 'CLi  ENH 9648CL SIDE')
check('7296 E: the open door leaf did not move the front', ext[:y0], 0.0)
check('7296 E: the roof unit did not raise the top',       ext[:z1] < 90.0, true)
check('7296 E floor-standing: no plate in the height',       ext[:plate], nil)
check('7296 E: mode is parts',              ext[:mode], :parts)
check('7296 E: height not from walls',      ext[:height_from_walls], nil)

small = [['S0  Right46Door', [2.0, -30.0, 0.0, 42.0, 2.0, 81.0]],
         ['N0  46VNT',       [2.0, 42.0, 0.0, 42.0, 48.5, 81.0]],
         ['E0  46PanelSolid', [42.0, 2.0, 0.0, 43.0, 42.0, 81.0]],
         ['W0  46PanelSolid', [1.0, 2.0, 0.0, 2.0, 42.0, 81.0]],
         ['SW corner seal',  [0.0, 0.0, 0.0, 4.875, 4.875, 81.0]],
         ['SE corner seal',  [39.125, 0.0, 0.0, 44.0, 4.875, 81.0]],
         ['NW corner seal',  [0.0, 39.125, 0.0, 4.875, 44.0, 81.0]],
         ['NE corner seal',  [39.125, 39.125, 0.0, 44.0, 44.0, 81.0]]]
e2 = BD.extent_from_parts(small)
check('door-only front wall: the corner seals set the front', [e2[:y0], e2[:y0_by]], [0.0, 'SW corner seal'])
check('no deck: walls carry the height and it is flagged', [e2[:z0], e2[:z1], e2[:height_from_walls]], [0.0, 81.0, true])
check('no deck: the by-names say so', e2[:z0_by].include?('NO FLOOR PART'), true)
check('nothing voting -> nil', BD.extent_from_parts([['floor', [0, 0, 0, 62, 44, 1]]]), nil)
eb = BD.extent_from_bounds([['floor', [0.0, 0.0, 0.0, 62.0, 44.0, 1.0]],
                            ['walls', [0.0, 0.0, 0.0, 62.0, 44.0, 83.0]],
                            ['RM4260 roof unit', [10.0, 10.0, 83.0, 50.0, 30.0, 93.0]]])
check('group bounds: everything but overlays', [eb[:x1], eb[:y1], eb[:z1], eb[:mode]], [62.0, 44.0, 83.0, :bounds])
check('group bounds: says so per side', eb[:x0_by], 'GROUP BOUNDS')

# 8 - ONE AXIS PER WALL. Shell 0..44 x 0..44 from the seals; `small` already
# carries an N0 46VNT standing 4.5 proud (y1 48.5). A fat EFS box on each
# wall in turn, reaching well past the corners along its wall.
check('wall_axis: N pushes y1, S y0, E x1, W x0',
      %w[N S E W].map { |l| BD.wall_axis(l) }, [:y1, :y0, :x1, :x0])
efs_n = small + [['N1  46VNT_EFS', [2.0, 42.0, 0.0, 60.0, 52.0, 81.0]]]
en = BD.extent_from_parts(efs_n)
check('N EFS: extends Y only (y1 52), X untouched (x1 stays 44)',
      [en[:x0], en[:x1], en[:y0], en[:y1]], [0.0, 44.0, 0.0, 52.0])
check('N EFS: y1 set by the EFS, x1 still by a corner seal',
      [en[:y1_by], en[:x1_by]], ['N1  46VNT_EFS', 'SE corner seal'])
check('N EFS: reported proud 8 on the N wall, beside the 4.5 the plain vent already stood',
      en[:proud], [['N0  46VNT', 'N', 4.5], ['N1  46VNT_EFS', 'N', 8.0]])
check('N EFS: reported 16 overhang along X, not counted', en[:overhang], [['N1  46VNT_EFS', 'N', 'X', 16.0]])
efs_s = small + [['S1  46VNT_EFS', [-20.0, -10.0, 0.0, 40.0, 2.0, 81.0]]]
es = BD.extent_from_parts(efs_s)
check('S EFS: extends -Y only (y0 -10), X untouched (x0 stays 0)',
      [es[:x0], es[:x1], es[:y0], es[:y1]], [0.0, 44.0, -10.0, 48.5])
check('S EFS: proud 10 on S, overhang 20 along X',
      [es[:proud], es[:overhang]],
      [[['N0  46VNT', 'N', 4.5], ['S1  46VNT_EFS', 'S', 10.0]], [['S1  46VNT_EFS', 'S', 'X', 20.0]]])
efs_e = small + [['E1  46VNT_EFS', [42.0, 2.0, 0.0, 55.0, 70.0, 81.0]]]
ee = BD.extent_from_parts(efs_e)
check('E EFS: extends X only (x1 55), Y untouched (y1 stays 48.5)',
      [ee[:x0], ee[:x1], ee[:y0], ee[:y1]], [0.0, 55.0, 0.0, 48.5])
check('E EFS: proud 11 on E, overhang 21.5 along Y past the vented y1',
      [ee[:proud], ee[:overhang]],
      [[['N0  46VNT', 'N', 4.5], ['E1  46VNT_EFS', 'E', 11.0]], [['E1  46VNT_EFS', 'E', 'Y', 21.5]]])
efs_w = small + [['W1  46VNT_EFS', [-7.0, -15.0, 0.0, 2.0, 42.0, 81.0]]]
ew = BD.extent_from_parts(efs_w)
check('W EFS: extends -X only (x0 -7), Y untouched (y0 stays 0)',
      [ew[:x0], ew[:x1], ew[:y0], ew[:y1]], [-7.0, 44.0, 0.0, 48.5])
check('W EFS: proud 7 on W, overhang 15 along Y',
      [ew[:proud], ew[:overhang]],
      [[['N0  46VNT', 'N', 4.5], ['W1  46VNT_EFS', 'W', 7.0]], [['W1  46VNT_EFS', 'W', 'Y', 15.0]]])
check('the plain shell reports only its vent proud, and no overhang',
      [e2[:proud], e2[:overhang]], [[['N0  46VNT', 'N', 4.5]], []])
check('the shell is the seals', e2[:shell], { :x0 => 0.0, :y0 => 0.0, :x1 => 44.0, :y1 => 44.0 })
noseal = [['N0  46VNT', [2.0, 42.0, 0.0, 42.0, 48.5, 81.0]],
          ['E0  46PanelSolid', [42.0, 2.0, 0.0, 43.0, 42.0, 81.0]],
          ['W0  46PanelSolid', [1.0, 2.0, 0.0, 2.0, 42.0, 81.0]],
          ['S1  46PanelSolid', [2.0, 1.0, 0.0, 42.0, 2.0, 81.0]]]
ns = BD.extent_from_parts(noseal)
check('no seals: each wall sets its own side and nothing else',
      [ns[:x0], ns[:x1], ns[:y0], ns[:y1], ns[:shell], ns[:proud]], [1.0, 43.0, 1.0, 48.5, nil, []])
check('no seals, no wall on one side: the union fills it and says so',
      BD.extent_from_parts(noseal.first(3))[:y0_by].include?('union used'), true)
check('the door leaf reaching out the front still moves nothing (S is the door wall, excluded)',
      BD.extent_from_parts(small)[:y0], 0.0)

# 9 - THE VENT BOX, NOT THE ASSEMBLY BOX; THE PLATE IN THE HEIGHT.
# An E-wall vent part read off its faces, booth frame: the panel's two
# faces at 97 and 98 (3726 sq in each), the vent box's outer face at 103.5,
# a duct collar rim at 104.4375 and a small bracket at 100.
lv_e = [[97.0, 3726.0], [98.0, 3726.0], [103.5, 1800.0], [104.4375, 30.0], [100.0, 5.0]]
ve = BD.vent_box_level(lv_e, 1.0)
check('vent box: the panel band ends at its OUTER face (98), not its biggest face',
      ve[:panel], 98.0)
check('vent box: the outboard level with the most area is the box (103.5)',
      [ve[:box], ve[:box_area]], [103.5, 1800.0])
check('vent box: the collar rim beyond it is a fitting, reported',
      ve[:beyond], [[104.4375, 30.0]])
check('vent box: a bracket between panel and box is not beyond', ve[:beyond].length, 1)
lv_w = [[1.0, 3726.0], [0.0, 3726.0], [-5.5, 1800.0], [-6.4375, 30.0], [-2.0, 5.0]]
vw = BD.vent_box_level(lv_w, -1.0)
check('vent box on a W wall: outboard is -X, panel outer face 0, box at -5.5, rim beyond',
      [vw[:panel], vw[:box], vw[:beyond]], [0.0, -5.5, [[-6.4375, 30.0]]])
vs = BD.vent_box_level([[97.0, 3726.0], [98.0, 3726.0]], 1.0)
check('a solid panel: no outboard level, the box IS the panel face', [vs[:box], vs[:beyond]], [98.0, []])
check('grille faces within a sixteenth merge into one level',
      BD.level_totals([[103.5, 100.0], [103.53, 200.0], [104.0, 1.0]]), [[103.5, 300.0], [104.0, 1.0]])
check('no faces -> nil', BD.vent_box_level([], 1.0), nil)

# Benton's booth: MDL 7296 E on a CP, door S, vents N and E (EFS), the vent
# boxes trimmed to their faces the way dimension() does before the extent.
cp = [['S0  Right46Door',        [2.0, -30.0, 0.0, 48.0, 1.0, 81.0]],
      ['S1  46PanelSolid',       [50.0, 0.0, 0.0, 96.0, 1.0, 81.0]],
      ['N0  46Vnt_VSS_EFS_CP',   [2.0, 73.0, -4.75, 60.0, 79.5, 82.3125]],
      ['N1  46PanelSolid',       [50.0, 73.0, 0.0, 96.0, 74.0, 81.0]],
      ['E0  46Vnt_VSS_EFS_CP',   [97.0, 2.0, -4.75, 103.5, 60.0, 82.3125]],
      ['E1  22PanelSolid',       [97.0, 50.0, 0.0, 98.0, 72.0, 81.0]],
      ['W0  46PanelSolid',       [0.0, 2.0, 0.0, 1.0, 48.0, 81.0]],
      ['W1  22PanelSolid',       [0.0, 50.0, 0.0, 1.0, 72.0, 81.0]],
      ['SW corner seal',         [0.0, 0.0, 0.0, 2.0, 2.0, 81.0]],
      ['SE corner seal',         [96.0, 0.0, 0.0, 98.0, 2.0, 81.0]],
      ['NW corner seal',         [0.0, 72.0, 0.0, 2.0, 74.0, 81.0]],
      ['NE corner seal',         [96.0, 72.0, 0.0, 98.0, 74.0, 81.0]],
      ['STD9648FL SIDE',         [1.0, 1.0, -1.0, 49.0, 73.0, 0.0]],
      ['STD9648FL SIDE',         [49.0, 1.0, -1.0, 97.0, 73.0, 0.0]],
      ['FLi  ENH 9648FL SIDE',   [3.25, 3.25, -1.3125, 94.75, 70.75, -1.0]],
      ['STD9648CL SIDE',         [1.0, 1.0, 81.0, 49.0, 73.0, 82.0]],
      ['STD9648CL SIDE',         [49.0, 1.0, 81.0, 97.0, 73.0, 82.0]],
      ['CLi  ENH 9648CL SIDE',   [3.25, 3.25, 81.25, 94.75, 70.75, 83.0]],
      ['RM7296 roof unit',       [20.0, 20.0, 82.0, 78.0, 54.0, 92.3125]]]
# The builder's plate, 1.49.0: its tray floor is CP_BOOTH_LIFT 4.75 under the
# FLOOR STACK underside — the IEP mat at -1.3125 on this Enhanced booth — so
# the plate bottom is -6.0625 and its rim 5.5 up at -0.5625. wr-overlays.rb
# seats it there (place_casters: z_bot = stack_bot - CP_BOOTH_LIFT) and lifts
# the group by 6.0625 so that bottom lands on the ground.
plate_builder = ['CP9648 SIDE  caster plate', [1.0, 1.0, -6.0625, 97.0, 73.0, -0.5625]]
eb = BD.extent_from_parts(cp + [plate_builder])
check("Benton's 7296 E on a CP: width 8' 7 1/2\" (103.5) — the E vent box, not the assembly",
      [eb[:x0], eb[:x1], eb[:x1] - eb[:x0]], [0.0, 103.5, 103.5])
check("Benton's 7296 E on a CP: depth 6' 7 1/2\" (79.5) — the N vent box",
      [eb[:y0], eb[:y1], eb[:y1] - eb[:y0]], [0.0, 79.5, 79.5])
check('CP: the silencer foot hanging to -4.75 on the vent parts does not touch the height (walls never vote on z)',
      eb[:z1], 83.0)
check('CP: the plate bottom is the bottom of the booth', [eb[:z0], eb[:z0_by]], [-6.0625, 'CP9648 SIDE  caster plate'])
check('CP: the plate adds a FULL 4.75 below the floor stack (the mat seats on the tray floor)',
      eb[:plate], 4.75)
check("CP: an Enhanced booth on a plate reads Benton's 7' 5 1/16\" (89.0625 = 84.3125 drawn + 4.75)",
      eb[:z1] - eb[:z0], 89.0625)
# THE SUPERSEDED SEATING, kept as a regression pin and nothing else: until
# 1.49.0 the plate was seated 4.75 under the STANDARD floor (-1.0), which put
# its bottom at -5.75, buried the IEP mat 0.3125 inside its tray floor and read
# 7'-4 3/4". If the builder ever measures to the standard floor again this is
# the number that comes back, and the cross-check below refuses it.
plate_old = ['CP9648 SIDE  caster plate', [1.0, 1.0, -5.75, 97.0, 73.0, -0.25]]
eb2 = BD.extent_from_parts(cp + [plate_old])
check("CP: the pre-1.49.0 seating reads the superseded 7' 4 3/4\" (88.75), a full 0.3125 short",
      [eb2[:z1] - eb2[:z0], eb2[:plate]], [88.75, 4.4375])
check('CP: and a booth seated that way FAILS the catalogue cross-check (0.3125 is over the 0.25 tolerance)',
      BD.reconcile([103.5, 79.5, 88.75], [103.5, 79.5, 84.3125 + 4.75], ['E0', 'N0', 'plate']).length, 1)
check('CP: the plate never touches the footprint', [eb[:x0_by], eb[:y0_by]], ['SW corner seal', 'SW corner seal'])
check('CP: cross-check adds the plate to the catalogue height, so no *** on a plate that is where the builder put it',
      BD.reconcile([103.5, 79.5, 89.0625], [103.5, 79.5, 84.3125 + 4.75], ['E0', 'N0', 'plate']), [])
check('CP: catalogue for a 7296 E vented N and E is 103.5 x 79.5 x 84.3125',
      BD.catalogue_extent(98.0, 74.0, ['E', 'N'], true), [103.5, 79.5, 84.3125])
check('CP: the untrimmed assembly boxes would have read 104.4375 x 80.4375 — the fault as reported',
      (lambda {
        raw = cp.map { |n, bx| n =~ /EFS/ ? [n, (n[0, 1] == 'N' ? [bx[0], bx[1], bx[2], bx[3], 80.4375, bx[5]] : [bx[0], bx[1], bx[2], 104.4375, bx[4], bx[5]])] : [n, bx] }
        e = BD.extent_from_parts(raw)
        [e[:x1], e[:y1]]
      }).call, [104.4375, 80.4375])
check('a plate on a floor-standing fixture that sits ABOVE the floor underside adds nothing',
      BD.extent_from_parts(cp + [['CPx  caster plate', [1.0, 1.0, -0.5, 97.0, 73.0, 5.0]]])[:plate], nil)

# 4 - THE PLACEMENT TABLE (spec §7), door on S, extent 0..98 x 0..79.5 x 0..84.3125
box = { :x0 => 0.0, :x1 => 98.0, :y0 => 0.0, :y1 => 79.5, :z0 => 0.0, :z1 => 84.3125 }
row = lambda do |c|
  l = BD.layout(box, 'S', c)
  [l[:width][:a], l[:width][:b], l[:width][:off],
   l[:depth][:a], l[:depth][:b], l[:depth][:off],
   l[:height][:a], l[:height][:b], l[:height][:off]]
end
check('FR: width on the front edge pushed -Y 24, depth on the RIGHT edge pushed +X 24, height at rear-RIGHT pushed +X 36',
      row.call('FR'),
      [[0.0, 0.0, 0.0], [98.0, 0.0, 0.0], [0.0, -24.0, 0.0],
       [98.0, 0.0, 0.0], [98.0, 79.5, 0.0], [24.0, 0.0, 0.0],
       [98.0, 79.5, 0.0], [98.0, 79.5, 84.3125], [36.0, 0.0, 0.0]])
check('FL: width on the front edge, depth on the LEFT edge pushed -X, height at rear-LEFT pushed -X 36',
      row.call('FL'),
      [[0.0, 0.0, 0.0], [98.0, 0.0, 0.0], [0.0, -24.0, 0.0],
       [0.0, 0.0, 0.0], [0.0, 79.5, 0.0], [-24.0, 0.0, 0.0],
       [0.0, 79.5, 0.0], [0.0, 79.5, 84.3125], [-36.0, 0.0, 0.0]])
check('RL: width on the REAR edge pushed +Y, depth on the left edge, height at front-LEFT pushed -X 36',
      row.call('RL'),
      [[0.0, 79.5, 0.0], [98.0, 79.5, 0.0], [0.0, 24.0, 0.0],
       [0.0, 0.0, 0.0], [0.0, 79.5, 0.0], [-24.0, 0.0, 0.0],
       [0.0, 0.0, 0.0], [0.0, 0.0, 84.3125], [-36.0, 0.0, 0.0]])
check('RR: width on the rear edge, depth on the right edge, height at front-RIGHT pushed +X 36',
      row.call('RR'),
      [[0.0, 79.5, 0.0], [98.0, 79.5, 0.0], [0.0, 24.0, 0.0],
       [98.0, 0.0, 0.0], [98.0, 79.5, 0.0], [24.0, 0.0, 0.0],
       [98.0, 0.0, 0.0], [98.0, 0.0, 84.3125], [36.0, 0.0, 0.0]])
check('an unknown corner draws as FR', row.call('??'), row.call('FR'))
check('the height string is pushed further than the depth string it shares a corner with',
      BD::GAP_RISE > BD::GAP, true)
ln = BD.layout(box, 'N', 'FR')
check('north door: width runs along the north edge, pushed +Y',
      [ln[:width][:a][1], ln[:width][:b][1], ln[:width][:off]], [79.5, 79.5, [0.0, 24.0, 0.0]])
check('north door: RIGHT when facing it from outside is the WEST wall, pushed -X',
      [ln[:depth][:a][0], ln[:depth][:off]], [0.0, [-24.0, 0.0, 0.0]])
check('north door: the height stands at the far (south) end of the west wall',
      ln[:height][:a], [0.0, 0.0, 0.0])
le = BD.layout(box, 'E', 'FR')
check('east door: right is NORTH, so the depth runs along y1 and is pushed +Y',
      [le[:depth][:a][1], le[:depth][:off]], [79.5, [0.0, 24.0, 0.0]])
check('frame: r is always (-f) x z',
      %w[N S E W].map { |w| f = BD.frame_for(w); [f[:f], f[:r]] },
      [[[0.0, 1.0], [-1.0, 0.0]], [[0.0, -1.0], [1.0, 0.0]],
       [[1.0, 0.0], [0.0, 1.0]], [[-1.0, 0.0], [0.0, -1.0]]])

# 5 - the rotation
check('FR -> FL (the other side, first press)', BD.next_corner('FR'), 'FL')
check('FL -> RL',                               BD.next_corner('FL'), 'RL')
check('RL -> RR',                               BD.next_corner('RL'), 'RR')
check('RR -> FR (round the booth)',             BD.next_corner('RR'), 'FR')
check('an absent corner rotates from FR',       BD.next_corner(nil), 'FL')
check('four presses come home',
      (1..4).inject('FR') { |c, _| BD.next_corner(c) }, 'FR')
check('press_of', %w[FR FL RL RR].map { |c| BD.press_of(c) }, [0, 1, 2, 3])
check('side words', %w[FR FL RL RR].map { |c| BD.side_word(c) }, %w[right left left right])

# 6 - obstruction
check('FR slab is 36 in off the RIGHT (x1) face, full depth, full height',
      BD.side_slab(box, 'S', 'FR'), [98.0, 0.0, 0.0, 134.0, 79.5, 84.3125])
check('FL slab is 36 in off the LEFT (x0) face',
      BD.side_slab(box, 'S', 'FL'), [-36.0, 0.0, 0.0, 0.0, 79.5, 84.3125])
check('RR slab is the same side as FR', BD.side_slab(box, 'S', 'RR'), BD.side_slab(box, 'S', 'FR'))
check('a west wall 1 in off the booth blocks FL',
      BD.aabb_overlap?(BD.side_slab(box, 'S', 'FL'), [-5.0, -20.0, 0.0, -1.0, 120.0, 96.0]), true)
check('and does not block FR',
      BD.aabb_overlap?(BD.side_slab(box, 'S', 'FR'), [-5.0, -20.0, 0.0, -1.0, 120.0, 96.0]), false)
check('touching faces do not overlap',
      BD.aabb_overlap?([0, 0, 0, 1, 1, 1], [1, 0, 0, 2, 1, 1]), false)

# 7 - the catalogue cross-check
check('7296 N-vented Enhanced expects 98 x 79.5 x 84.3125',
      BD.catalogue_extent(98.0, 74.0, ['N'], true), [98.0, 79.5, 84.3125])
check('96120 N+E vented Standard expects 127.5 x 103.5 x 83',
      BD.catalogue_extent(122.0, 98.0, ['E', 'N'], false), [127.5, 103.5, 83.0])
check('no vents: the box itself', BD.catalogue_extent(62.0, 44.0, [], false), [62.0, 44.0, 83.0])
check('W and S project too', BD.catalogue_extent(62.0, 44.0, ['S', 'W'], false), [67.5, 49.5, 83.0])
by = ['SW corner seal / SE corner seal', 'S0 / N0  46VNT', 'FLi / CLi']
check('agreement prints nothing',
      BD.reconcile([98.0, 79.5, 84.3125], [98.0, 79.5, 84.3125], by), [])
check('exactly 1/4 in is still agreement',
      BD.reconcile([98.25, 79.5, 84.3125], [98.0, 79.5, 84.3125], by), [])
r = BD.reconcile([128.4375, 103.5, 83.0], [127.5, 103.5, 83.0], ['E0  46VNT / W0', 'S / N', 'FL / CL'])
check('a vent 15/16 too proud is one line',     r.length, 1)
check('and it names ACROSS X',                  (r[0] || '').include?('ACROSS X'), true)
check('and both figures',                       (r[0] || '').include?('128.4375') && (r[0] || '').include?('127.5000'), true)
check('and the part',                           (r[0] || '').include?('E0  46VNT'), true)
h = BD.reconcile([98.0, 79.5, 83.0], [98.0, 79.5, 84.3125], by)
check('a Standard height on an Enhanced key is a HEIGHT line', [h.length, (h[0] || '').include?('HEIGHT')], [1, true])
check('the sign says which way', (h[0] || '').include?('-1.3125'), true)
check('three axes wrong is three lines',
      BD.reconcile([1.0, 1.0, 1.0], [10.0, 10.0, 10.0], by).length, 3)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def pure_section(src):
    """The text between the PURE SECTION banner and the END PURE marker."""
    lines = src.splitlines()
    start = end = None
    for i, ln in enumerate(lines):
        # The banner line mentions END PURE in prose, so the end marker is
        # the ruled comment line only — "# ---- END PURE ----".
        if start is None and 'PURE SECTION' in ln and ln.lstrip().startswith('#'):
            start = i
        if start is not None and i > start and ln.lstrip().startswith('# ---- END PURE'):
            end = i
            break
    if start is None or end is None:
        raise SystemExit('dimension-whisperroom.rb: PURE SECTION / END PURE markers not found')
    return '\n'.join(lines[start:end])


def main():
    src = open(RB, encoding='utf-8').read()
    data = open(DATA, encoding='utf-8').read()
    prog = PROG.replace('@@PURE@@', pure_section(src)).replace('@@DATA@@', data)
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
