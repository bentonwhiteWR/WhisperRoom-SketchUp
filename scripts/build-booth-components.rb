# @title Build a booth from real parts...
# @cat Build the booth
# @rank 2
#
# Builds a booth out of the REAL component .skp files instead of extruded boxes.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/build-booth-components.rb"
#
# build-booth.rb draws each panel as a rectangle and push-pulls it into a
# featureless slab. That is fine for a plan check and useless for a render: a
# door frame is a grey box with no door in it. This places the actual component,
# so the booth has doors that swing, windows with glass, and vents with ducts.
#
# Layout comes from the same wr-booth-data.rb — every panel's position, run
# length, wall and kind. Nothing about the layout changes. All that changes is
# what gets put in each slot.
#
# ============================================================================
# HOW A COMPONENT IS ORIENTED, AND WHY IT IS MEASURED RATHER THAN TABULATED
#
# The components are not authored to one convention. Measured across all 182:
#
#   * HEIGHT runs along the definition's own Y — 81.000 standard, 91.000 for HX.
#     Not Z. Every wall part agrees on this.
#   * WIDTH is on Z for solid panels, doors and both seam seals, and on X for
#     the WDO window panels and the vents. Two families, no flag to tell them
#     apart.
#   * ORIGINS ARE NOT CONSISTENT. Only 73 of 182 sit at their bounding box's
#     minimum corner; 34 sit at no recognisable anchor at all. 40PanelSolid's
#     origin is a full inch outside its own box on two axes while 7Panel's is on
#     the corner.
#
# So placement CANNOT use the insertion point, and orientation cannot use a
# lookup table that someone has to keep in step with the model. Both are derived
# per part from the definition's own bounding box:
#
#     height axis    = whichever axis measures about 81 or 91
#     width axis     = the larger of the remaining two
#     thickness axis = the smaller of the remaining two
#
# That is true for both families and stays true if a part is re-exported.
# ============================================================================
#
# HX PANELS SIT ON THE SAME CENTRELINE. An HX panel measures 1.125 thick against
# a standard panel's 1.000. The extra eighth is a black H strip that stands proud
# equally on both faces — a sixteenth each side — so the panel's mounting plane
# has not moved. Thin parts are therefore centred on the wall centreline, never
# butted to a face. Butting would throw the wall out by a sixteenth and read as a
# rounding bug.

require 'sketchup.rb'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')
# Floor and ceiling placement. Kept separate because its rules are measured
# and documented in reference/floor-ceiling-geometry.md, with their own
# constants; inlining them here would bury them in a 900-line file.
load File.join(File.dirname(__FILE__), 'wr-deck.rb')

module WR_BuildBoothComponents
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')
  PREF = 'WR_BuildBoothComponents'.freeze
  DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'.freeze

  ORIGIN = Geom::Point3d.new(0, 0, 0)
  VX = Geom::Vector3d.new(1, 0, 0)
  VY = Geom::Vector3d.new(0, 1, 0)
  VZ = Geom::Vector3d.new(0, 0, 1)

  SEAL_COMP   = 'MidWallSeamSeal'.freeze
  CORNER_COMP = 'CornerSeamSeal'.freeze

  # ---------------------------------------------------------------- ENHANCED --
  #
  # An Enhanced booth is TWO shells: the Standard one, and the IEP inner shell
  # standing 2.25 in inboard of it. The layout data tags every part :sh=>'out'
  # or :sh=>'in' and this file switches component family on that tag alone. An
  # inner part NEVER takes a Standard name and an outer part never takes an ENH
  # one - substituting either way builds a booth that renders perfectly and is
  # the wrong product.
  ENH_SEAL_COMP   = 'ENH MidWallSeamSeal'.freeze
  ENH_CORNER_COMP = 'ENH CornerSeamSeal'.freeze

  # Every ENH wall part measures 79.5 tall against a Standard 81 - 89.5 against
  # 91 on HX (observed, P: library probe, no exceptions in 112 parts). The 1.5
  # is not a discrepancy: an Enhanced wall is CAPTURED between the floor lip and
  # the ceiling lip rather than stood on the deck the way a Standard wall is.
  ENH_WALL_H    = 79.5
  ENH_WALL_H_HX = 89.5

  # HOW THAT 1.5 SPLITS BETWEEN THE TWO LIPS IS NOT MEASURED, and this constant
  # is the whole of the assumption. It is how far the inner wall's underside
  # sits ABOVE the outer wall's; the rest of the 1.5 falls at the top.
  #
  # IT WAS 0.3125 AND THAT REASONING IS DEAD. The 0.3125 came from the measured
  # thickness of every ENH floor part, on the reading that the inner wall stands
  # on that sheet. Benton, 2026-08-25, looking at a real build: the ENH floor
  # part is "the 5/16 black rubber mat that sits UNDER the standard floor". The
  # inner wall does not stand on it, so the number had no reason left.
  #
  # 0.0 was tried next, and checked by eye. Benton, off that build: "all of
  # the IEP components need to go up .75". So 0.75 up, 0.75 short at the top -
  # the 1.5 splits evenly. MEASURED, by the only method that has worked on
  # this shell: build it, look, say the number.
  #
  # THEN THE 6060 E SAID 0.6875, AND A THIRD BOOTH BROKE THE TIE THE OTHER WAY.
  # THE LIFT IS PER BOOTH. Three booths have been measured, they do not agree,
  # and a single constant is therefore the wrong shape. This is a table.
  #
  #   0.7500  MDL 4872 E, 2026-08-25. Benton's eye first - "all of the IEP
  #           components need to go up .75" - then a probe of his corrected full
  #           booth that agreed with the build to 0.0001 (v1.6.17). The only
  #           probe-backed figure in the set, and the strongest evidence here.
  #   0.6875  MDL 6060 E, 2026-08-26. Benton's eye on a corrected inner shell:
  #           "the IEP inner shell just needs to drop 1/16 and its perfect."
  #           No probe.
  #   0.7500  MDL 102144 E, 2026-08-26. Built at 0.6875. Benton, asked which
  #           booth the 1/16 report was about: "This was only for the 102144 E.
  #           Im not sure about any others. But the IEP shell was 1/16 too low."
  #           0.6875 + 0.0625 = 0.7500. Eye only, no probe.
  #
  # A TABLE, NOT A RULE. Three points and two values do not make a rule, and
  # Benton's own words on scope are "Im not sure about any others" - so nothing
  # is extrapolated here. 0.7500 is the DEFAULT because two of the three measure
  # it and one of those two is the probe-backed one. But a booth that is not
  # named below has not been LOOKED at, and the build says so by name in its
  # warning block, exactly the way IEP_ROOM_PROUD warns for a width it has no
  # figure for. An unmeasured booth is a guess wearing a number.
  #
  # WHAT THE DEFAULT COSTS on a booth nobody has checked: an inner wall runs
  # 0.75 to 80.25 in an 81 nominal, so 0.75 falls at the top and the 1.5 splits
  # evenly. On the 6060 E it splits 0.6875 / 0.8125 instead. THE EVEN SPLIT IS A
  # CONSEQUENCE, NEVER THE REASON - it is what the 4872 E measured, not what any
  # of this was derived from, and the 6060 E is the standing proof that "it
  # splits evenly" is not a law.
  #
  # IEP_TRAY_DROP WAS NOT MOVED for any of this. A booth whose lift is below the
  # 4872's has its wall-top-to-tray gap wider by exactly that difference.
  #
  # AND THE LESSON AT IEP_VENT_YAW APPLIES TO EVERY ROW ADDED HERE: a Ruby
  # module keeps its constants until SketchUp restarts. Before a report of "the
  # shell is 1/16 off" becomes a row in this table, establish that the process
  # was restarted after the figure it was built at shipped.
  IEP_WALL_LIFT_DEFAULT = 0.7500
  IEP_WALL_LIFT = {
    'MDL 4872 E'   => 0.7500,   # eye, then a full-booth probe   2026-08-25
    'MDL 6060 E'   => 0.6875,   # eye only                       2026-08-26
    'MDL 102144 E' => 0.7500,   # eye only, 0.6875 built + 1/16  2026-08-26
  }.freeze

  # This booth's lift, and whether that figure was measured ON THIS BOOTH or
  # fell through to the default. Keyed on the full layout key - 'MDL 4872 E' -
  # which is what build_booth is handed and what wr-booth-data.rb names its
  # layouts. An outer wall's lift is 0.0 and never comes through here.
  def self.iep_wall_lift(key)
    IEP_WALL_LIFT[key.to_s] || IEP_WALL_LIFT_DEFAULT
  end

  def self.iep_wall_lift_measured?(key)
    IEP_WALL_LIFT.key?(key.to_s)
  end

  # ---- THE VENT WALL SITS 1/16 BELOW THE REST OF THE INNER SHELL ----
  #
  # IEP_WALL_LIFT is one figure for a whole inner shell, and that was right
  # until a booth disagreed with itself. Benton, 2026-08-27, off a built
  # MDL 102144 E (and the same booth in HX): "The IEP vent walls need to lower
  # 1/16. Just the IEP vent walls." Everything else on that shell he called
  # good, so this is NOT the shell lift moving - the shell lift stays 0.7500
  # and the vent parts alone come down to 0.6875.
  #
  # WHY A SEPARATE TABLE INSTEAD OF SPLITTING IEP_WALL_LIFT: the shell figure
  # and the vent offset answer different questions. The shell figure is how the
  # 1.5 of capture splits between the floor lip and the ceiling lip. This is one
  # family of part hanging lower than its neighbours in the same run, which is a
  # property of the vent part, not of the booth's capture. Folding them into one
  # number would mean re-measuring the whole shell every time a vent moved.
  #
  # SCOPE, and the discipline here is the same as IEP_WALL_LIFT's: ONE BOOTH HAS
  # BEEN LOOKED AT. Eye only, no probe - no probe can see it either, for the
  # same reason IEP_VENT_YAW cannot, since the room-proud block re-seats the box
  # afterwards. A booth not named below gets 0.0, meaning its vent sits flush
  # with the rest of its inner shell, and that is the pre-2026-08-27 behaviour
  # rather than a claim about that booth. Nothing is extrapolated from one point.
  #
  # AND THE RESTART RULE APPLIES. This constant ships in v1.6.33. A report that
  # the vent is still 1/16 low is only evidence about this table if SketchUp was
  # restarted after 1.6.33 was installed - see the long note at IEP_VENT_YAW for
  # the version this lesson already cost.
  IEP_VENT_LIFT_DROP_DEFAULT = 0.0
  IEP_VENT_LIFT_DROP = {
    'MDL 102144 E' => 0.0625,   # eye only, E and HX both  2026-08-27
  }.freeze

  def self.iep_vent_lift_drop(key)
    IEP_VENT_LIFT_DROP[key.to_s] || IEP_VENT_LIFT_DROP_DEFAULT
  end

  def self.iep_vent_lift_drop_measured?(key)
    IEP_VENT_LIFT_DROP.key?(key.to_s)
  end

  # A VENT PART, read off the COMPONENT NAME THAT WAS ASSIGNED - the same test
  # iep_room_proud and iep_trim_end already use, deliberately the same regex so
  # the three cannot drift apart and disagree about what a vent is. Never read
  # from the slot's :sk: a customer moving ventilation in the booth builder
  # changes the assigned component and does not change the layout's slot kind.
  # THE WORD BOUNDARY IS A REAL BYTE, NOT AN ESCAPE, AND IT WAS BROKEN FOR
  # TWENTY VERSIONS. From v1.6.12 (9474d4b) until v1.6.33 the three vent tests
  # below carried a literal 0x08 BACKSPACE where the \b belongs - a shell
  # heredoc ate the escape when the constant was first written, and the file has
  # carried an unprintable control character ever since. Reproduced deliberately
  # on 2026-08-27 while adding this helper: the same heredoc collapses \\b to
  # \b, which Python then writes as the control character.
  #
  # WHAT IT COST, and it is smaller than it looks: the VNT alternative was
  # unaffected, and every vent part in the catalogue is named ...VNT, so no
  # booth ever built wrong because of it. The NV alternative could never match
  # anything - nothing is followed by a backspace - so a natural-ventilation
  # part would silently have taken the panel family room-proud figure instead of
  # the vent one, and iep_trim_end would have called it :lo instead of :sym.
  #
  # The harness asserts no control character survives in this file. If that
  # check ever fails again, something wrote this file through a shell.
  def self.iep_vent_part?(name)
    !(name.to_s =~ /VNT|NV\b/i).nil?
  end

  # The IEP mid-wall seam seal's stem - the joint between two inner panels.
  # 6.5 where the Standard seal is 2. Needed here because rebalance_walls
  # re-walks a run from real part widths and has to use the right joint.
  IEP_SEAL_W = 6.5

  # How far a part's bounding box may disagree with its slot, when wall_slab
  # found no panel inside it, before rebalance_walls believes the part really
  # is a different size. See the note in rebalance_walls: ENH parts carry trim
  # and void proud of the panel, worth an eighth to a quarter inch, while the
  # substitution this exists to catch - a wide-access door - is three inches.
  SLAB_NOISE = 1.0

  # ---- INNER-SHELL ORIENTATION, both from Benton looking at a real build ----
  #
  # The IEP seam seals are not the Standard ones turned around. A Standard seal
  # wraps a CONVEX corner from outside the booth; an IEP seal sits in a CONCAVE
  # corner and is fitted from inside the room. corner_yaw aims the L's centre of
  # mass at the booth's middle, which is right for the outer shell and a quarter
  # turn short for the inner one.
  #
  # Both are degrees about the vertical, applied only to inner parts and only
  # after the normal placement. They are ONE NUMBER EACH on purpose - if a build
  # shows them still off, change the number here rather than reasoning about
  # where a part's origin sits.
  # IEP_CORNER_YAW is gone. Inner corners are placed directly from the part's
  # authored frame (see the corner block in build_booth); no heuristic, no
  # correction on top of one.
  IEP_SEAL_YAW   = 180.0   # the mid-wall seal, end for end

  # THE INNER VENT WALL, end for end. 180, AND IT HAS NOW BEEN CONFIRMED TWICE
  # ON A RESTARTED SKETCHUP.
  #
  # This flipped to 0.0 for one version (v1.6.24) on a false premise, and the
  # false premise is the thing worth remembering, not the number.
  #
  # Benton reported the vents wrong on a 6060 E, so v1.6.21 set 180. He then
  # reported them wrong AGAIN on a 96144 E, and the reasoning was: the 180 is
  # live, this block keys off the assigned component name, that booth's vents
  # all resolve to ENH ...VNT, so it must be firing - and a half turn is its
  # own inverse, so asking for another 180 means the answer is 0. Every step of
  # that was sound EXCEPT the first. SketchUp had not been restarted, so the
  # 180 was NOT in memory; he was looking at pre-v1.6.21 code. The premise was
  # about the STATE OF THE RUNNING PROCESS and it was never checked.
  #
  # With 0.0 genuinely live on a restarted SketchUp, Benton on a 102144 E:
  # "now all the IEP vent walls are flipped backwards." That is the first
  # observation of this constant that is known to have been made against the
  # code it names. 180 is correct.
  #
  # THE LESSON, because it will recur: a Ruby module keeps its constants until
  # SketchUp restarts. "The file on disk says X" is not evidence that the
  # running build does. Before treating a report as evidence about a constant,
  # establish that the process was restarted after that constant shipped.
  #
  # No probe can check this either way: the turn is about the slot polygon's
  # own centre and the room-proud block below re-seats the box afterwards, so
  # the bounding box is identical at 0 and at 180. Benton's eye is the only
  # instrument.
  # 2026-08-26, v1.6.32: THE CONSTANT IS GONE. It was never one number. See
  # iep_vent_yaw() below and .forge/fixer/ROOTCAUSE-iep-vent-yaw-2026-08-26.md.
  # Keep everything above: the "restart before you believe a report" lesson is
  # still true, but it was ALSO used to dismiss a report that was real. Benton's
  # 96144 E report was not stale state - the 96144 E's inner vent is
  # ENH 41.5VNT, a DIFFERENT part from the 6060 E's ENH 35.5VNT, and the two
  # parts genuinely want opposite turns. Two true reports were read as one
  # contradictory report about one constant.

  # ACROSS THE WALL, an inner panel whose slab cannot be found stands its
  # bounding box this far into the room past the panel band's room face.
  #
  # place() centres such a box in its 2.0 band, and the boxes are not
  # symmetric about the panel: ENH 41.5VNT is 2.375 thick with 0.125 of trim
  # on the room side and 0.25 behind. Benton's hand-assembled 4872 E wall has
  # the vent box at 2.7500 against a band at 2.8750 - 0.125 proud, exactly -
  # and the 17.5 at 2.7812, which he called "about a sixteenth in, not
  # exact". One rule, 1/8, lands the vent to four places and the 17.5 to a
  # thirty-second. Parts with a findable slab (the door) are placed off the
  # slab and never touch this.
  #
  # TWO NUMBERS, NOT ONE. Benton, next probe: the 17.5 at 2.7500 is "exactly
  # 1/32 too far in". His hand assembly had it at 2.7812, and that is the
  # figure - so the 2.0625-thick panel family stands 3/32 proud where the
  # 2.375-thick vent family stands 1/8. Both measured, neither derived.
  #
  # Then the E and W walls: 41.5PanelSolid at 3/32 was "1/32 too far in" on
  # both, so the panel family is 1/16. That contradicts the 17.5 at 3/32 by
  # exactly the 1/32 Benton's first hand placement of the 17.5 was "not exact"
  # by. One number for the family, and the next N-wall probe decides it: the
  # 17.5 should read 2.8125, and if it truly wants 2.7812 this splits by width.
  #
  # THE TEST CAME BACK: "both the 17.5 panels need to go inwards 1/32". So the
  # 17.5 really is 3/32 and the 41.5 really is 1/16 - the same 2.0625 box
  # thickness, different trim on the room side. Measured per width, and
  # anything not yet measured takes the 41.5's figure and is named in the
  # build report so it does not pass as measured.
  IEP_ROOM_PROUD = { :vent => 0.125, '17.5' => 0.09375, '41.5' => 0.0625 }.freeze
  IEP_ROOM_PROUD_DEFAULT = 0.0625

  # ALONG THE WALL, the panel family's bounding box overshoots the panel by
  # 0.125 - and all of it is at ONE end, the definition's low-width end.
  #
  # Benton, E and W walls of the probed 4872 E, both carrying a centred
  # 41.5PanelSolid: "E needs to go north 1/16, W needs to go south 1/16".
  # Opposite world directions, but the two walls hold the same part turned
  # 180 in plan - on E its +width axis points south, on W north (worked
  # through place() and rotation(), not assumed) - so both are the SAME move
  # in the part's own frame: 1/16 toward its low end. A symmetric trim would
  # need no move at all; the vent's is symmetric and centring landed it
  # exactly, so the vent family is :sym and the panel family is :lo.
  def self.iep_trim_end(name)
    name.to_s =~ /VNT|NV\b/i ? :sym : :lo
  end

  def self.iep_room_proud(name)
    n = name.to_s
    return IEP_ROOM_PROUD[:vent] if n =~ /VNT|NV\b/i
    w = n[/ENH\s+([\d.]+)/, 1]
    IEP_ROOM_PROUD[w] || IEP_ROOM_PROUD_DEFAULT
  end

  def self.iep_room_proud_measured?(name)
    n = name.to_s
    return true if n =~ /VNT|NV\b/i
    IEP_ROOM_PROUD.key?(n[/ENH\s+([\d.]+)/, 1])
  end

  # THE MODULE WIDTH AN ENH PART'S NAME DECLARES, or nil for a part whose name
  # carries no width ('ENH Right41.5Door' deliberately does not match - a door
  # has a findable slab and never needs this).
  #
  # Why this exists: rebalance_walls has to know how wide a part really is, and
  # for an ENH part wall_slab finds nothing, so the only measurement left was
  # the whole definition's bounding box. That box includes trim and void
  # standing proud of the panel - ENH 35.5VNT measures 35.750 and
  # ENH 35.5PanelSolid 35.625, both on a 35.5 module - and re-walking a wall
  # from those packaged figures overruns the run by the sum of the packaging.
  # On the 6060 E's E inner wall that overrun is 0.250, past the 0.15 closure
  # tolerance, so the whole wall bailed out and kept its stale slot polygons;
  # place() then centred a 35.75 part on an 11.5 slot and put it at booth
  # y -7.875, outside the booth. The W wall of the same booth overran only
  # 0.125, squeaked under the tolerance, and rebalanced 1/8 long instead.
  #
  # The name's number is the module width. It is what the layout polygons are
  # cut to and what the Standard slab measures on the same wall, so using it
  # here makes the inner shell rebalance exactly as well as the outer one
  # already does. Packaging is still reported in the FIT column, untouched.
  def self.iep_nominal_width(name)
    w = name.to_s[/ENH\s+([\d.]+)/, 1]
    w && w.to_f
  end
  IEP_DOOR_YAW   = 180.0   # the inner door - see below
  # And the door moves INTO THE ROOM by this much after its half turn. The
  # door is the one inner part with a findable slab, so place() puts that
  # 1.0-thick slab on the band's centreline; Benton, off the built S wall:
  # "the door should push inwards 1/2". Measured, not derived.
  IEP_DOOR_IN    = 0.5

  # The inner door was the one part in the whole booth facing opposite to its
  # neighbours: the dry run reported S0i ENH Right41.5Door as Y- OUT where the
  # outer S0 Right46Door of the same hand came out Y+ IN, and every other inner
  # part came out IN. Both were oriented by measured bulk, so the two
  # definitions carry their leaf on opposite sides. Benton confirmed it off a
  # real build.
  #
  # A HALF TURN, NOT A MIRROR. The REVERSED list would also flip it, but a
  # mirror turns a right-hand door into a left-hand one, and the hand is a
  # customer choice that arrives from the quote. A rotation moves the leaf to
  # the room side without touching which way the part is handed.

  def self.inner?(part)
    part[:sh].to_s == 'in'
  end

  # The nominal the part is MEASURED against - which axis is its height.
  def self.part_height(part, hx)
    if inner?(part)
      hx ? ENH_WALL_H_HX : ENH_WALL_H
    else
      hx ? 91.0 : 81.0
    end
  end

  # The z the part's TOP is placed at. Same figure for an outer part; lifted by
  # this booth's IEP wall lift for an inner one, which puts its underside on the
  # lip.
  #
  # THE LIFT ARRIVES AS A NUMBER, resolved once per build by build_booth and
  # passed down. It is deliberately NOT read from a module-level "current booth":
  # SketchUp is long-lived, this module survives a build, and anything stashed on
  # it would be silently inherited by the next build in the same session. A
  # required argument cannot go stale, and there is exactly one call site.
  def self.part_top_z(part, hx, lift)
    part_height(part, hx) + (inner?(part) ? lift : 0.0)
  end

  # ------------------------------------------------------------ IEP DECK --
  #
  # The inner shell's own floor and ceiling. Benton, 2026-08-25, off a real
  # build, and these two sentences are the whole specification:
  #
  #   FLOOR    "the 5/16 black rubber mat that sits UNDER the standard floor"
  #   CEILING  "the tray faces downwards, and it sits on top of the standard
  #             ceiling, completely engulfing it"
  #
  # BOTH ARE PLACED RELATIVE TO THE STANDARD DECK THAT WAS JUST PLACED, not to
  # a z constant of their own. wr-deck.rb's vertical datums are measured, fit
  # tested and documented in reference/floor-ceiling-geometry.md; re-deriving
  # them here would be a second copy to keep in step. Reading the placed
  # instance's own bounding box also means the one figure nobody has measured -
  # exactly where the standard ceiling's underside lands - is never needed.
  #
  # THE TILING IS NOT THIS FILE'S QUESTION EITHER, AND THAT IS THE POINT.
  #
  # This used to compose one name, 'ENH <digits>FL' / 'ENH <digits>CL', and
  # refuse anything else - the 4230 through 4896 ship a single piece, everything
  # larger tiles across CTR / SIDE / SIDE L / SIDE R, and the comment here said
  # that tiling was "a layout question this file has no answer for".
  #
  # IT HAD AN ANSWER ALL ALONG, IN wr-deck.rb. The ENH deck library has exact
  # parity with the Standard one - 42 codes each, identical sets, verified off
  # the real folder listing on 2026-08-26 (see the note on WR_Deck::ENH_NAME).
  # So the arrangement an inner deck needs is the arrangement wr-deck already
  # solves, fit-tested, for the outer one: which widths tile the run, where the
  # odd tile goes, which hand sits at which end. It is read from the same
  # catalogue with 'ENH ' in front of it, and NOTHING about the tiling is
  # decided here.
  #
  # WHAT STAYS HERE IS THE VERTICAL, because that is the part the IEP does
  # differently: wr-deck seats a deck on its own measured datums, and the inner
  # deck is seated against the STANDARD DECK THAT WAS JUST PLACED. See below.
  #
  # STILL REFUSED BY NAME. If wr-deck cannot tile the inner deck, the reason it
  # gives is reported along with the single-piece name that would have covered
  # it, and nothing is substituted - no Standard part, no near-miss size.
  # ======================================================================
  # WHICH WAY UP THE INNER TRAY GOES IN. MEASURED PER PART, NOT DECLARED.
  # ======================================================================
  #
  # Benton, 2026-08-26, off a freshly built MDL 102144 E: "the IEP ceiling
  # needs to be flipped upside down. The tray part was pointing up, it needs
  # to point down."
  #
  # THE OBVIOUS FIX - set this to true - IS WRONG, AND HERE IS WHY. Three
  # different CL families have been in front of Benton on this same code:
  #
  #   ENH 4872CL                  MDL 4872 E    closed, tray ACCEPTED
  #   ENH 9648CL SIDE / CTR       MDL 96144 E   scrutinised, tray NOT reported
  #   ENH 10242CL SIDE / CTR
  #     + ENH 10218CL CTR         MDL 102144 E  tray REPORTED opening upward
  #
  # At least one of those families is authored the right way up and at least
  # one is not. A single global boolean cannot express that; flipping it would
  # trade the 102144 for the 4872, which is closed and must not move.
  #
  # SO THE ORIENTATION IS MEASURED OFF THE PART'S OWN GEOMETRY, which is what
  # the Standard deck has done since v1.6.x - WR_Deck.contact_z's second return
  # value, added because "all ceilings are upside down on MDL 96168 S". The IEP
  # path was the only deck path still placing parts as authored and hoping.
  #
  # nil   MEASURE it, per part, per build. The default and the only setting
  #       that can be right for a library authored to more than one convention.
  # true  force every tile flipped.
  # false force every tile as authored - the pre-v1.6.25 behaviour, one word
  #       to revert to if the measurement turns out to read a family wrong.
  #
  # Whatever it decides is PRINTED PER TILE with the reason, so a wrong call is
  # visible in the console rather than only on the screen.
  IEP_CL_UPSIDE_DOWN = nil

  # THE FLOOR MAT IS NOT A TRAY AND IS LEFT ALONE. An ENH FL part measures
  # 0.3125 thick (_enhanced-probe.tsv, all 22 of them) - a flat sheet with no
  # mouth to point anywhere - and no floor mat has ever been reported the wrong
  # way up. Measuring an orientation that does not exist would only invent a
  # coin flip, so this stays a declared false.
  IEP_FL_UPSIDE_DOWN = false

  # ===== THE THREE FIGURES THE MOUTH TELL TURNS ON (v1.6.30) =====
  #
  # These REPLACE IEP_LEVEL_MIN_SHARE (0.05) and IEP_MOUTH_RATIO (2.0). The old
  # pair could not answer, because the 5% share filter deleted the very level the
  # ratio needed - the rim - on 11 of the 23 ENH CL parts. Every figure below is
  # set off the real spread in _face-levels.tsv (2026-08-26, all 370 parts), with
  # the gap between the two populations stated so a future part can be judged
  # against it rather than against a taste.
  #
  # A tray PLATE is its whole footprint. Measured, ENH CL plates run 64% to 100%
  # of the part's biggest level (the 64% is ENH 127LPCL, which is not
  # rectangular). Nothing else in the library sits between 25% and 50%, so the
  # threshold has a wide moat on both sides.
  IEP_PLATE_MIN_SHARE = 0.50

  # A tray RIM is a 1 in ring on the outer edges. Measured, ENH CL rims run 1.9%
  # to 6.6% of the plate - the widest is the single-piece ENH 4872CL, which has a
  # ring on all four sides. Nothing measured is anywhere near 25%.
  IEP_RIM_MAX_SHARE = 0.25

  # AND IT HAS TO BE A REAL FACE. This is the guard that keeps the rule
  # ENHANCED-ONLY in effect as well as in name. A Standard ceiling carries a
  # chamfer of 1 to 3 sq in at each end of its box, which is a tiny share of its
  # plate and would read as a mouth on share alone; the smallest genuine ENH rim
  # is 36 sq in (ENH 10218CL CTR, ENH 8418 CL). 10 sq in sits in that gap with an
  # order of magnitude either side, and with it the rule abstains on all 23
  # Standard ceilings - the property .forge/builder/replay-iep-deck.py asserts.
  IEP_RIM_MIN_AREA = 10.0

  # HOW FAR THE TRAY DROPS OVER THE STANDARD CEILING. Its bottom edge sits
  # this far below the standard ceiling's TOP face - so it caps the ceiling
  # rather than hanging under it. MEASURED: Benton probed a fully corrected
  # 4872 E on 2026-08-25 and the tray's bottom was 0.7500 below the standard
  # ceiling's top, to four places. The first placement had it at the
  # ceiling's underside, 2.358 too low.
  IEP_TRAY_DROP = 0.75

  # Union of the bounding boxes of everything the deck pass just added.
  def self.union_bounds(list)
    bb = Geom::BoundingBox.new
    (list || []).each { |e| bb.add(e.bounds) rescue nil }
    bb.valid? ? bb : nil
  end

  # Lay a flat part into a RECTANGLE OF THE BOOTH'S PLAN: turn it a quarter if
  # its footprint is the other way round, turn it end for end if asked, flip it
  # if asked, then sit it where the caller wants.
  #
  # rx, ry is the rectangle's low corner in booth coordinates and rw, rh its
  # size. It used to take the booth's own bw, bh and centre in that, which is
  # the one-tile case written out: a single-piece deck's rectangle is
  # [INSET, INSET + along] x [INSET, INSET + cross], and since along = w - 2 and
  # cross = h - 2 on every single-tile part in the library, its centre is
  # (w/2, h/2) - exactly where the old call put it. THAT IS WHY THE CLOSED
  # MDL 4872 E DOES NOT MOVE, and .forge/builder/replay-iep-deck.py asserts it
  # over all 25 E layouts rather than leaving it as a claim.
  #
  # THE ROTATION ORDER IS wr-deck's, not the old one here. wr-deck applies flip,
  # then the half turn, then the quarter; this applied the quarter then the
  # flip. The two differ only when a part is both flipped and turned, and both
  # flip constants are false, so nothing moves today - but there is no reason to
  # keep two conventions for the same operation, and wr-deck's is the fit-tested
  # one.
  #
  # HOW IT SITS IN THE RECTANGLE IS THE CALLER'S CHOICE, PER AXIS.
  #
  # :centre splits any difference between the part and the rectangle, which is
  # what this always did and what every FL tile and every single-piece deck still
  # wants. :min seats the part's low edge on the rectangle's low edge and :max
  # its high edge on the rectangle's high edge, so anything the part carries
  # BEYOND the rectangle hangs off the far side.
  #
  # That is the whole of the ENH ceiling tray's lip. See iep_deck for the
  # measurements and why centring an ENH CL tile overlapped its neighbour by
  # exactly half an inch.
  #
  # Returns [transform, note] or [nil, why].
  def self.flat_placement(defn, rx, ry, rw, rh, flip, half, z_mode, z_target,
                          seat_x = :centre, seat_y = :centre)
    bb = defn.bounds
    return [nil, 'no valid bounds'] unless bb.valid?
    px = bb.max.x.to_f - bb.min.x.to_f
    py = bb.max.y.to_f - bb.min.y.to_f
    notes = []

    # Which way round is its footprint? Compare both readings against the
    # rectangle and keep the better one rather than assuming the parts are
    # authored to a convention - ENH 4872CL measures 50 x 74 against a booth
    # that is 74 x 50.
    as_is   = (px - rw).abs + (py - rh).abs
    turned  = (py - rw).abs + (px - rh).abs
    quarter = turned < as_is - 0.001

    tr = Geom::Transformation.new
    tr = Geom::Transformation.rotation(ORIGIN, VX, 180.degrees) * tr if flip
    if half
      tr = Geom::Transformation.rotation(ORIGIN, VZ, 180.degrees) * tr
      notes << 'end for end'
    end
    if quarter
      tr = Geom::Transformation.rotation(ORIGIN, VZ, 90.degrees) * tr
      notes << 'turned a quarter'
    end

    # Where the part's own box lands once rotated.
    xs = []
    ys = []
    zs = []
    8.times do |i|
      q = bb.corner(i).transform(tr)
      xs << q.x.to_f
      ys << q.y.to_f
      zs << q.z.to_f
    end
    dx = seat(seat_x, rx, rw, xs.min, xs.max)
    dy = seat(seat_y, ry, rh, ys.min, ys.max)
    dz = z_mode == :top ? z_target - zs.max : z_target - zs.min
    [Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, dz)) * tr,
     notes.empty? ? nil : notes.join(', ')]
  end

  # One axis of that choice. Returns the translation that puts the part's
  # measured span [lo, hi] where `mode` says it belongs in [r0, r0 + rlen].
  #
  #   :centre  split the difference        - the old and still-default behaviour
  #   :min     part's low edge  on r0      - overhang hangs off the HIGH side
  #   :max     part's high edge on r0+rlen - overhang hangs off the LOW side
  #
  # A part that measures exactly rlen lands identically under all three, which is
  # why every FL tile is unmoved by any of this: the ENH floor mats measure their
  # nominal name to four places.
  def self.seat(mode, r0, rlen, lo, hi)
    case mode
    when :min then r0 - lo
    when :max then (r0 + rlen) - hi
    else           r0 + rlen / 2.0 - (lo + hi) / 2.0
    end
  end

  # The booth-plan rectangle one tile owns: [rx, ry, rw, rh].
  #
  # wr-deck's plan hands back :at (the running position along the tiling axis,
  # measured from the deck's low edge), :along, :cross and :along_is_x. INSET is
  # wr-deck's own - the deck stops 1 in short of the exterior per side - and it
  # is read from there rather than copied, so the two can never drift apart.
  def self.tile_rect(t)
    a     = WR_Deck::INSET + t[:at].to_f
    along = t[:along].to_f
    cross = t[:cross].to_f
    t[:along_is_x] ? [a, WR_Deck::INSET, along, cross] : [WR_Deck::INSET, a, cross, along]
  end

  # Does this inner tile need turning end for end?
  #
  # THIS IS A DELIBERATE SECOND COPY OF A THREE-LINE RULE, and the alternative
  # was worse. The rule lives inside WR_Deck.build - measure the bracket line on
  # the FL twin, turn whenever it would otherwise end up inboard, fall back to
  # the positional "turn the high-end tile" when the part is symmetric and
  # yields no cue. Extracting it would mean editing a path that is live,
  # fit-tested on real booths, and IMPOSSIBLE TO RUN ON THIS MACHINE. Copying
  # three lines is the smaller risk; if the rule ever changes, both copies do.
  #
  # THE MEASUREMENT IS OF THE ENH PART ITSELF, not the STD one. bracket_edge
  # walks the geometry standing proud of the given definition's rim, so nothing
  # is transferred from the Standard twin - which matters, because whether ENH
  # deck parts even carry a bracket line is NOT KNOWN HERE and cannot be known
  # without opening them in SketchUp. If they do not, bracket_edge returns nil
  # and this falls back to the positional rule, which is what the Standard deck
  # does for every CTR panel and for the 6042 SIDE pair.
  #
  # ONE TILE NEVER TURNS. The caller gates on tiles.length > 1: a single-piece
  # deck has no end to sit at, and the MDL 4872 E was closed with no turn.
  def self.iep_half_turn?(model, cat, t, defn)
    twin = WR_Deck.fl_twin(cat, t[:part])
    td = if twin[:file] == t[:part][:file]
           defn
         else
           (model.definitions.load(twin[:path]) rescue nil)
         end
    edge = td ? WR_Deck.bracket_edge(td) : nil
    return !t[:at_low_end] if edge.nil?
    t[:at_low_end] ? edge > 0.5 : edge < 0.5
  end

  # Which way up did this inner deck part come in? Returns [flip?, why].
  #
  # ================== THE STANDARD RULE IS ASKED FIRST ==================
  #
  # WR_Deck.contact_z(defn, kind) already answers "is this part modelled upside
  # down" for the Standard deck, it is fit-tested on real booths, and its
  # comments carry two scars worth reading before touching any of this
  # (wr-deck.rb ~lines 574-680): the height and the orientation are separate
  # questions, and THE ROOM-SIDE TELL MUST LIE OUTSIDE THE SLAB, NOT INSIDE IT.
  # It is called here, read-only, and wr-deck.rb is NOT edited - the Standard
  # path is live and cannot be run on this machine.
  #
  # ============ AND IT WILL OFTEN HAVE NOTHING TO SAY HERE ==============
  #
  # contact_z looks for a face pair 1.0000 apart - the Standard slab - and then
  # for a minor level OUTSIDE that pair. An ENH deck part is built nothing like
  # a Standard one. Measured, off the component folder's _enhanced-probe.tsv
  # (2026-08-24) and _face-levels.tsv (2026-08-14), observed:
  #
  #   every STD deck part   box_z 3.1080   slab 1.0000 plus trim and brackets
  #   every ENH CL part     box_z 1.7500   ONE band, 10 faces, 34 entities
  #   every ENH FL part     box_z 0.3125   one band
  #
  # Ten faces is four walls inside and out plus one plate: a tray. There is no
  # 1.0000 pair in a 1.7500 part unless it happens to carry one, and when there
  # is none contact_z falls back to [lowest, highest], finds no level outside
  # that, and returns false - which is its NO-CUE answer, not a measurement.
  # Its false therefore cannot be trusted on its own here.
  #
  # ==================== SO A TRAY GETS A TRAY'S TELL ====================
  #
  # A tray is closed at one end and open at the other. The closed end is a
  # PLATE carrying the part's whole footprint; the open end is a RIM carrying a
  # thin ring. Which end holds the big face IS which way the mouth points, and
  # it needs no slab, no minor level and no convention.
  #
  # The tray must point DOWN - DEVLOG, Benton: "the tray faces downwards, and
  # it sits on top of the standard ceiling, completely engulfing it." So: plate
  # at the HIGH end is right, plate at the LOW end is upside down. That is the
  # whole rule.
  #
  # THE LEVELS COME FROM WR_Deck.flat_levels, not from a second face walker.
  # Only the two EXTREME levels are compared, so the trap that turned every
  # floor CTR panel over - a 1/32 lip read as the room-side tell because it sat
  # inside the slab - cannot arise: there is no slab here and nothing interior
  # is consulted.
  #
  # ============ MEASURED 2026-08-26. THE ABSTENTION IS LIFTED. =============
  #
  # The note that stood here said "UNRUN - _face-levels.tsv contains ZERO ENH
  # rows". That is no longer true. Benton re-ran scripts/probe-levels.rb over
  # the WHOLE parts folder with a blank filter on 2026-08-26 19:38, and
  # P:\Sketchup\NewMasterComponentList\_face-levels.tsv now carries 1761 ENH
  # rows across 6625 lines. Every ENH CL part in the library has been read
  # (observed, straight off the TSV; see
  # .forge/fixer/TRAY-ORIENTATION-2026-08-26.md for the full table).
  #
  # WHAT THE MEASUREMENT SAYS. An ENH CL tray has exactly THREE flat levels and
  # no others - no chamfers, no screw bosses - and they are always the same
  # three things:
  #
  #   PLATE   the closed end, area == box_x * box_y, the whole footprint
  #   FIELD   the plate's underside, the footprint less the lip inset
  #   RIM     the open mouth, a 1 in ring on the OUTER edges only
  #
  # ENH 4872CL   box 50 x 74   z 1.7500 -> 3700 (plate)  0.7500 -> 3456  0.0000 -> 244 (rim)
  # ENH 10242CL CTR  box 42 x 104  z 1.7500 -> 84 (rim)  1.0000 -> 4284  0.0000 -> 4368 (plate)
  #
  # Those two are MIRROR IMAGES IN Z. The library is authored to two
  # conventions, which is exactly what this function was written to survive,
  # and FOUR parts of the 23 carry the plate at the LOW end:
  #
  #   ENH 10218CL CTR   ENH 10242CL CTR   ENH 10242CL SIDE   ENH 8442CL SIDE
  #
  # Note that ENH 8442CL CTR is authored the RIGHT way up while ENH 8442CL SIDE
  # is not, so this is per-part authoring drift and no family rule would catch
  # it. Nine of the 25 E layouts tile at least one of the four: 8484, 10284,
  # 84102, 84126, 102102, 102126, 102144, 102168, 102186. MDL 6060 E and
  # MDL 4872 E tile NONE of them and do not move.
  #
  # ===== WHY THE OLD RULE ABSTAINED, WHICH IS THE ROOT CAUSE =====
  #
  # IEP_LEVEL_MIN_SHARE (0.05) DELETED THE RIM BEFORE THE RATIO COULD SEE IT.
  # The rim of a CTR or a long tile is 2 x cross x 1 in against a plate of
  # cross x run: 84 against 4368 on ENH 10242CL CTR, 1.9% of peak. Under a 5%
  # filter the rim is dropped as a chamfer, the rule is left comparing the PLATE
  # against the plate's own UNDERSIDE - 4368 and 4284, two near-equal areas -
  # and it returns NO ORIENTATION CUE. It did that on 11 of the 23 ENH CL parts,
  # including all four that actually needed turning over. The threshold sat
  # right on top of the answer: the rims that survived 5% (ENH 4872CL at 6.6%,
  # ENH 6042CL SIDE at 5.5%) are the single-piece and short tiles, which is why
  # the closed MDL 4872 E read correctly and the MDL 102144 E did not.
  #
  # ===== THE RULE NOW: WHICH BOX END HOLDS THE PLATE =====
  #
  # Compare the levels at the two ENDS OF THE BOX - the lowest and highest flat
  # faces, with NO share filter, because the filter was the bug. One end must
  # hold a plate (>= IEP_PLATE_MIN_SHARE of the biggest level) and the other a
  # rim (<= IEP_RIM_MAX_SHARE of it, AND at least IEP_RIM_MIN_AREA square
  # inches so a chamfer cannot pose as a mouth). Plate high = mouth down = as
  # authored. Plate low = mouth up = FLIPPED.
  #
  # Checked against the fresh TSV, offline, in .forge/fixer/verify-tray.py:
  # it decides all 23 ENH CL parts (19 down, 4 flipped) and STILL ABSTAINS ON
  # ALL 23 STANDARD CEILINGS, which is the safety property the replay harness
  # asserts. The absolute area floor is what preserves it - a Standard ceiling's
  # extreme levels carry 1 to 3 sq in of chamfer where the smallest real ENH rim
  # is 36 sq in.
  #
  # UNRUN IN SKETCHUP. Every number above is off the TSV, which is what
  # WR_Deck.flat_levels would build from the same geometry (derived: probe-
  # levels.rb's `levels` and wr-deck.rb's `flat_levels_with_exact` use the same
  # 0.999 flat test, the same 1/64 bin and the same face walk). A build is still
  # the proof, and every tile prints its verdict and its reason.
  def self.iep_upside_down?(defn, kind, forced)
    unless forced.nil?
      return [forced ? true : false,
              format('%s by IEP_%s_UPSIDE_DOWN',
                     forced ? 'forced flipped' : 'left as authored', kind)]
    end

    # ===== THE PRECEDENCE IS REVERSED AS OF v1.6.30, AND HERE IS WHY =====
    #
    # It used to read "contact_z's TRUE wins outright ... the two cannot fight".
    # THEY DO FIGHT, on exactly one part, and contact_z is the one that is wrong.
    #
    # ENH 127LPCL measures z 1.7500 -> 2196.47 (the plate), 1.0000 -> 2017.09
    # (its underside) and 0.0000 -> 179.38 (the rim). contact_z hunts for a face
    # pair 1.0000 apart, finds RIM-to-UNDERSIDE at 0.0000/1.0000, calls that the
    # slab, and is then left with the PLATE at 1.7500 as a "minor level above the
    # slab" - which for a ceiling is its upside-down verdict. So it turns over
    # the one ENH tray whose plate-to-underside happens to measure 0.7500 instead
    # of 1.0000. Confirmed by re-running contact_z offline over the fresh TSV:
    # ENH 127LPCL is the ONLY one of the 23 ENH CL parts it answers true on.
    #
    # contact_z is a STANDARD-SLAB detector and an ENH tray has no Standard slab;
    # the comment above already warned its false could not be trusted here, and
    # this is the same defect in the other direction. The mouth tell reads the
    # part's actual shape - a closed plate at one end, an open ring at the other -
    # and needs no slab, so where the two disagree the mouth tell is the better
    # evidence and now goes FIRST. contact_z is kept as the fallback for a future
    # part that shows no plate/rim at all.
    #
    # WHAT THIS CHANGES ON A REAL BUILD TODAY: nothing. ENH 127LPCL is an orphan -
    # no E layout tiles it (all 25 enumerated, .forge/fixer/TRAY-ORIENTATION-
    # 2026-08-26.md). It is fixed because it is wrong, not because a booth needs it.
    #
    # wr-deck.rb is still called READ-ONLY and still not edited. The Standard
    # path cannot see any of this.

    # ======== THE MOUTH TELL IS A CEILING RULE. THIS GATE IS LOAD-BEARING.
    #
    # .forge/builder/replay-iep-deck.py section 9 runs the tell over the real
    # _face-levels.tsv and it FIRES 'mouth UP' on 17 of the 22 STANDARD FLOOR
    # panels - STD4896FL reads 4608 sq in low against 632 high. A floor panel is
    # a field face at the bottom with a thin perimeter STRIP on top, which is
    # the same area shape as an upside-down tray and has nothing to do with
    # orientation. Ungated, this rule would stand every floor on its head. The
    # harness asserts both halves: abstains on all 16 STD ceilings, misfires on
    # the floors.
    return [false, 'flat sheet, no mouth to point'] unless kind == 'CL'

    tally = begin
              WR_Deck.flat_levels(defn)
            rescue StandardError
              nil
            end
    if tally.nil? || tally.empty?
      return [false, 'no flat faces to measure - left as authored']
    end

    # NO SHARE FILTER ON THE LEVEL LIST. Filtering it is what deleted the rim
    # and caused the abstention; see the header. The two ends of the box are
    # taken raw and the plate/rim test below does the discriminating.
    levels = tally.keys.sort
    return [false, 'one flat level only - left as authored'] if levels.length < 2

    peak = tally.values.max.to_f
    zlo = levels.first
    zhi = levels.last
    alo = tally[zlo].to_f
    ahi = tally[zhi].to_f

    plate_hi = ahi >= peak * IEP_PLATE_MIN_SHARE
    plate_lo = alo >= peak * IEP_PLATE_MIN_SHARE
    # A rim must be BOTH a small share of the plate AND a real face. The second
    # half is what keeps a Standard ceiling's 1-3 sq in chamfer from posing as a
    # tray mouth, and it is the reason this rule still abstains on all 23 of them.
    rim_lo = alo <= peak * IEP_RIM_MAX_SHARE && alo >= IEP_RIM_MIN_AREA
    rim_hi = ahi <= peak * IEP_RIM_MAX_SHARE && ahi >= IEP_RIM_MIN_AREA

    if plate_hi && rim_lo
      return [false, format('tray mouth reads DOWN (plate %.0f sq in at z %.4f, ' \
                            'rim %.0f at z %.4f)', ahi, zhi, alo, zlo)]
    elsif plate_lo && rim_hi
      return [true, format('tray mouth reads UP (plate %.0f sq in at z %.4f, ' \
                           'rim %.0f at z %.4f) - FLIPPED', alo, zlo, ahi, zhi)]
    end

    # No plate/rim reading. NOW ask wr-deck, which is the fallback rather than
    # the first word - see the note above. Its false is also how it says nothing,
    # so either way this ends up as "left as authored", but a true here is worth
    # taking because nothing else has an opinion.
    std = begin
            _cz, ud = WR_Deck.contact_z(defn, kind)
            ud
          rescue StandardError
            nil
          end
    if std
      return [true, 'no plate/rim cue - wr-deck contact_z reads it upside down']
    end

    [false, format('NO ORIENTATION CUE: box ends carry %.0f sq in low and %.0f ' \
                   'high against a biggest level of %.0f, and contact_z has ' \
                   'nothing either - left as authored, CHECK IT', alo, ahi, peak)]
  end

  # Places both inner decks and returns [count, notes, warnings].
  def self.iep_deck(model, booth, key, spec, dir, cache, host_bounds)
    digits = key[/MDL\s+(\d+)/, 1]
    return [0, [], ["cannot read a model number out of #{key}"]] if digits.nil?
    count = 0
    notes = []
    warns = []

    # The ENH half of the deck library, read through wr-deck's own parser.
    cat = WR_Deck.catalogue(dir, 'ENH')
    if cat.empty?
      return [0, notes,
              ["no 'ENH <digits>FL/CL' parts in #{dir} - the whole inner deck is " \
               'skipped. Nothing was substituted from the Standard library.']]
    end

    [['FL', IEP_FL_UPSIDE_DOWN, :top,
      'the mat goes under the standard floor'],
     ['CL', IEP_CL_UPSIDE_DOWN, :bottom,
      'the tray drops over the standard ceiling']].each do |kind, forced, mode, why|
      host = host_bounds[kind]
      if host.nil?
        warns << "inner #{kind}: no standard #{kind} was placed, so there is " \
                 'nothing to sit against'
        next
      end

      # THE TILING, FROM wr-deck. Same solver, same catalogue shape, same
      # odd-tile and hand rules the outer deck uses.
      tiles, plan_note = WR_Deck.plan(spec, cat, kind)
      if tiles.nil?
        warns << "inner #{kind} REFUSED BY NAME: #{plan_note}. A single-piece " \
                 "deck would be 'ENH #{digits}#{kind}.skp'; it is not in the " \
                 'library and nothing was substituted.'
        next
      end

      # FL: the mat's TOP meets the standard floor's underside (measured:
      #     the mat landed to four places on the first try).
      # CL: the tray's BOTTOM sits IEP_TRAY_DROP below the standard
      #     ceiling's TOP, capping it.
      #
      # ONE z FOR EVERY TILE OF A DECK, and it is read off the standard deck's
      # placed bounding box rather than a constant. The tiles of one deck are
      # one sheet cut up, so they share a thickness and therefore a face; if a
      # library ever ships tiles of differing thickness this is the line that
      # would have to become per-tile, and a build would show it as a step.
      z_target = kind == 'FL' ? host.min.z.to_f : host.max.z.to_f - IEP_TRAY_DROP
      notes << "#{kind}i #{plan_note}, z #{format('%.4f', z_target)} - #{why}"

      tiles.each_with_index do |t, ti|
        file = t[:part][:file]
        defn = load_def(model, dir, file, cache)
        if defn.nil?
          warns << "#{file}.skp would not load - the inner #{kind} tile at " \
                   "#{format('%g', t[:at])} is EMPTY, nothing substituted"
          next
        end

        # Say so when an end could not get the hand it wanted - the same
        # silence on the Standard path once let an MDL 7296 S come out with
        # SIDE L at both ends and still read as a clean build.
        if t[:substituted]
          warns << format('%s used at the %s end of the inner %s - the library ' \
                          'has no SIDE %s of that size, so the other hand went ' \
                          'in. Check the joint.',
                          file, t[:at_low_end] ? 'low' : 'high', kind,
                          t[:at_low_end] ? 'L' : 'R')
        end

        half = tiles.length > 1 && iep_half_turn?(model, cat, t, defn)

        # WHICH WAY UP, MEASURED OFF THIS PART. Was a global boolean until
        # v1.6.25, which is how an MDL 102144 E came out with its tray opening
        # upward on the same code that placed the MDL 4872 E's correctly.
        flip, flipwhy = iep_upside_down?(defn, kind, forced)
        rx, ry, rw, rh = tile_rect(t)

        # ====================================================================
        # THE TRAY'S LIP HANGS OUTWARD, SO SEAT THE TILE ON ITS OUTER EDGE.
        # ====================================================================
        #
        # Benton, 2026-08-26, off a built MDL 6060 E: the two IEP ceiling tiles
        # overlap, and each needs to push OUT half an inch. That is not a 6060
        # number and it is not a nudge; it is a property of every ENH CL part in
        # the library, and this is the measurement.
        #
        # An ENH FL part measures its nominal name - exactly, on 21 of the 22,
        # and 1/16 UNDER on ENH 8418 FL (17.9375, the same figure its Standard
        # twin STD8418 FL carries). An ENH CL part is BIGGER, by an amount that
        # depends on how many OUTER edges it has
        # (P:\Sketchup\NewMasterComponentList\_enhanced-probe.tsv, observed):
        #
        #   ENH 6042FL SIDE L   42.0000 x 60.0000   nominal
        #   ENH 6018FL SIDE R   18.0000 x 60.0000   nominal
        #   ENH 6042CL SIDE L   43.0000 x 62.0000   +1 along, +2 across
        #   ENH 6018CL SIDE R   19.0000 x 62.0000   +1 along, +2 across
        #   ENH 10242CL CTR     42.0000 x 104.000   +0 along, +2 across
        #   ENH 10242CL SIDE    43.0000 x 104.000   +1 along, +2 across
        #   ENH 9648CL CTR/SIDE 48 / 49 x 98.0000   +0 / +1 along, +2 across
        #   ENH 8418 CL         18.0000 x 86.0000   +0 along, +2 across
        #   ENH 4230CL (single) 32.0000 x 44.0000   +2 along, +2 across
        #
        # 'ENH 8418 CL' IS A MIDDLE TILE despite carrying neither a CTR nor a
        # SIDE token - it is the odd 18 in strip in the 84 series - and it
        # measures +0 along exactly like every other CTR. What separates a whole
        # deck from a middle tile is whether the library has a SIDE part at that
        # cross at all: crosses 42 and 48 have none, so those are whole decks.
        # This code never has to make that call - `tiles.length` already answers
        # it - but the rule check in the replay harness does.
        #
        # THE PARTS DO NOT AGREE ON WHICH AXIS IS THE RUN. ENH 6042CL SIDE L is
        # 43 x 62 with definition X along the run; ENH 4230CL and every other
        # single-piece 42xx / 48xx tray is authored the other way round. That is
        # the same disagreement wr-deck.rb's `plan` records about STD4230FL, and
        # it is why nothing below reads a span off a named axis.
        #
        # ONE RULE COVERS ALL OF IT: the tray carries a 1 in lip on each edge
        # that faces OUT of the booth, because it "sits on top of the standard
        # ceiling, completely engulfing it". A SIDE tile has one outer edge along
        # the run and a CTR tile has none; across the run every tile has two; a
        # single-piece tray has two on both axes. Every measured figure above is
        # that rule and nothing else.
        #
        # THE STANDARD DECK HAS NO LIP AT ALL, so WR_Deck.build never had this
        # problem to solve and there is NO EXISTING HANDLING TO REUSE - which
        # was the first thing checked, because if the Standard path already
        # solved it then the right fix would have been to call that rather than
        # write a second rule. It does not. All 21 STD ceiling parts measure
        # their nominal name to 0.0001: STD6042CL SIDE L is 42.0000 x 60.0000
        # and STD10242CL SIDE 42.0000 x 102.0000, dead nominal, exactly like
        # their FL twins.
        #
        # THE SOURCE FOR THAT IS _face-levels.tsv, NOT _component-probe.tsv.
        # The component probe carries the 183 WALL panels and not one deck part,
        # which is why an earlier attempt to read Standard deck widths out of it
        # found nothing at all. _face-levels.tsv carries box_x / box_y / box_z
        # for every part in the folder, decks and seam seals included.
        #
        # So the lip is an Enhanced-only feature, the fix belongs here in the
        # Enhanced path, and the live fit-tested Standard path is not touched.
        #
        # WHY CENTRING WAS WRONG BY EXACTLY 1/2. tile_rect hands back the tile's
        # NOMINAL slot, and centring a 43 in part on a 42 in slot hangs 1/2 off
        # each end. The outer 1/2 is half the lip it should have; the inner 1/2
        # is on top of the neighbouring tile. Seating the outer edge instead
        # gives the outer end its full 1 in and leaves the inner face flush at
        # the joint - the two tiles now meet, and each moved out 1/2. That is
        # Benton's number, derived rather than dialled in.
        #
        # ACROSS THE RUN STAYS CENTRED and that is correct, not an oversight:
        # both cross edges are outer, so splitting the +2 gives each the 1 in it
        # wants. A single-tile deck is centred on BOTH axes for the same reason,
        # which is why the closed MDL 4872 E cannot move.
        #
        # THE FLOOR IS UNMOVED BY ANY OF THIS. An ENH FL part measures its slot,
        # so :max, :min and :centre all put it in the same place - and the floor
        # is the deck Benton did NOT report as wrong.
        seat_along = if tiles.length < 2 then :centre        # both ends outer
                     elsif t[:at_low_end] then :max          # outer edge is LOW
                     elsif ti == tiles.length - 1 then :min  # outer edge is HIGH
                     else :centre                            # interior, no outer edge
                     end
        seat_x, seat_y = t[:along_is_x] ? [seat_along, :centre] : [:centre, seat_along]

        # The tripwire. The lip is at most 2 in on the along axis (a single-piece
        # tray) and 1 in on a SIDE tile, so anything larger is not a lip - it is a
        # bracket or a silencer widening the box, and seating a box like that on
        # its outer edge would throw the tile by whatever that overhang measures.
        # wr-deck.rb learned this the hard way on STD7224FL SIDE R, whose box is
        # 37.938 on a 24 in panel. No ENH deck part in the library does it today
        # (checked, all 44), so this should never fire; if it does, the tile
        # falls back to centring and says so.
        #
        # WHICH OF THE PART'S TWO FOOTPRINT SPANS IS THE RUN is decided the same
        # way flat_placement decides its quarter turn - by which reading fits the
        # rectangle - rather than by assuming definition X is the run. It cannot
        # simply take the booth-x span, because a booth that tiles along its own
        # Y gets a quarter turn and the definition's X lands on booth Y. Taking
        # whichever span is nearer the slot width is the same question with the
        # rotation already answered.
        bb_t = defn.bounds
        along_span = [(bb_t.max.x - bb_t.min.x).to_f,
                      (bb_t.max.y - bb_t.min.y).to_f].min_by { |v| (v - t[:along].to_f).abs }
        overhang = along_span - t[:along].to_f
        if seat_along != :centre && overhang.abs > 2.5
          warns << format('%s measures %.4f along a %g in slot - %.4f of ' \
                          'overhang is too much to be the tray lip, so it was ' \
                          'CENTRED rather than seated on its outer edge. ' \
                          'Something in that part is standing proud of the ' \
                          'tray; measure it before trusting this tile.',
                          file, along_span, t[:along].to_f, overhang)
          seat_x = seat_y = :centre
          seat_along = :centre
        end

        tr, tnote = flat_placement(defn, rx, ry, rw, rh, flip, half, mode, z_target,
                                   seat_x, seat_y)
        if tr.nil?
          warns << "#{file}: #{tnote}"
          next
        end
        # Say when a tile was pushed out onto its lip, and by how much. A
        # silent half inch is exactly the kind of move that gets re-derived from
        # scratch in six months.
        marks = [tnote]
        # ALWAYS say which way up it went in and on what evidence. A silent
        # orientation is the whole of this bug: the old code never printed one
        # because there was nothing per-part to print.
        marks << (flip ? "FLIPPED - #{flipwhy}" : "as authored - #{flipwhy}")
        unless seat_along == :centre || overhang.abs < 0.0005
          marks << format('lip %.4f, pushed %.4f out onto it', overhang,
                          overhang / 2.0)
        end
        marks.compact!

        inst = booth.entities.add_instance(defn, tr)
        inst.name = "#{kind}i  #{file}"
        count += 1
        landed = (inst.valid? ? inst.bounds : nil)
        notes << format('  %-24s %-4s at %6.2f  ->  %7.2f %7.2f %7.2f to %7.2f %7.2f %7.2f%s',
                        file, t[:at_low_end] ? 'low' : 'high', t[:at].to_f,
                        landed ? landed.min.x.to_f : 0.0,
                        landed ? landed.min.y.to_f : 0.0,
                        landed ? landed.min.z.to_f : 0.0,
                        landed ? landed.max.x.to_f : 0.0,
                        landed ? landed.max.y.to_f : 0.0,
                        landed ? landed.max.z.to_f : 0.0,
                        marks.empty? ? '' : "   (#{marks.join(', ')})")
      end
    end
    [count, notes, warns]
  end

  # How far a mid-wall seam seal stands PROUD of the wall face it sits between,
  # in inches. Positive is outward, negative is into the booth.
  #
  # It is zero, and it is still named. The seal position was tuned live against
  # a real build: out 1/4", then back in 1/4", and it landed exactly flush. A
  # bare 0.0 at the call site would read as "nothing to see here" and the next
  # person would have to re-derive that the flush position was measured rather
  # than assumed.
  #
  # THIS LINE WENT MISSING ONCE, and the way it failed is worth knowing. Ruby
  # constants live on the MODULE, not the file, so a constant defined by an
  # earlier `load` survives every later one. The session that tuned the seals
  # had it in memory and kept working perfectly; the definition never made it
  # into the committed file. Every fresh SketchUp since then died with
  # "uninitialized constant SEAL_PROUD" on the first seal of any booth. A green
  # run right after an edit does not prove the file is complete — only a fresh
  # SketchUp does.
  SEAL_PROUD = 0.0

  # Per-booth slot assignments. The layout data says a slot is a VNT or a DRFRM;
  # it does not say WHICH vent or WHICH door, and that is a customer choice. This
  # is where a decoded booth-builder link's "a" field will land once that route
  # is wired up — same shape, slot id to component name.
  #
  # A booth may list only the slots that need saying. Anything absent falls to
  # guess_component and is reported as guessed, which is the honest outcome for a
  # vent or a door nobody has specified — picking VSS over plain here would be
  # inventing a customer's choice.
  #
  # ============================================================================
  # THE E/W SWAP, AND WHY IT IS DONE HERE RATHER THAN IN THE LAYOUT
  #
  # The generated layout puts the BIG run on the high half of each E and W wall
  # and the short one on the low half, on all four split-run booths — 6060, 6084,
  # 7272, 7296. The door is on S at the low end, and the deck panels' own hinge
  # slots (24.125 in) sit on the LOW half. So the panels have always disagreed
  # with the layout, and the panels are right: the big wall belongs at the door
  # end. Benton reported the same thing independently.
  #
  # Swapping the two names end-for-end fixes it without touching generated data.
  # The slot polygons still carry the module widths, so the big part lands in the
  # short slot and vice versa — which is precisely what rebalance_walls exists
  # for. It re-walks each wall from the real part widths, and short+2+big sums to
  # the same interior run as big+2+short, so the wall closes exactly and the seam
  # seal shifts along by the difference. That shift is 24 in on all four booths:
  # 46/22 on the 7272 and 7296, 40/16 on the 6060 and 6084.
  #
  # All four are swapped below. Every other model is symmetric on E and W — the
  # 96168 is 46+46, the 102126 is 40+16+40 — so there is nothing to reverse.
  # ============================================================================
  ASSIGN = {
    # 6060 — E and W run 40 + seal + 16. E0 is the layout's vent slot, so the
    # vent moves with the 40 to the door end. '40VNT' is not a choice being made
    # here: it is the exact name guess_component already produced for that slot,
    # written out only because the slot is being relocated.
    'MDL 6060 S' => {
      'E0' => '16PanelSolid',
      'E1' => '40VNT',
      'W0' => '16PanelSolid',
      'W1' => '40PanelSolid'
    },
    # 6084 — same 40 + seal + 16 runs, and both walls are plain solids: this
    # booth's vents are both on N. The swap moves only the seam.
    'MDL 6084 S' => {
      'E0' => '16PanelSolid',
      'E1' => '40PanelSolid',
      'W0' => '16PanelSolid',
      'W1' => '40PanelSolid'
    },
    'MDL 7272 S' => {
      'N0' => '46VNT_VSS',        # vent wall, VSS
      'N1' => '22PanelSolid',
      'S0' => 'Right46Door',      # right-hand door, at the data's own end of the wall
      'S1' => '22PanelSolid',
      # E and W swapped: the 46 in part takes slot 1 (y 2..24), the 22 in panel
      # slot 0 (y 26..72). Window and vent stay opposite each other.
      'E0' => '22PanelSolid',
      'E1' => '46VNT_VSS',        # second vent slot, VSS
      'W0' => '22PanelSolid',
      'W1' => '46Panel3236WDO'    # 32x36 window, opposite the E vent
    },
    # 7296 carries the identical 46/22 inversion on E and W. Both walls are plain
    # solids here — no window or vent has been specified for this booth — so the
    # swap moves only the seam, from 24 in off the north end to 24 in off the
    # door end, and puts the 46 in run where the deck hinges expect it. N and S
    # are deliberately absent: they resolve by guess to 46VNT, Right46Door and
    # 46PanelSolid, all of which exist in the library.
    'MDL 7296 S' => {
      'E0' => '22PanelSolid',
      'E1' => '46PanelSolid',
      'W0' => '22PanelSolid',
      'W1' => '46PanelSolid'
    },

    # ------------------------------------------------------------- ENHANCED --
    #
    # The same four booths in Enhanced. The E/W swap is a property of the
    # LAYOUT, not of the variant - the generated data puts the big run on the
    # high half of E and W on every 6060/6084/7272/7296 whichever shell you are
    # looking at - so an Enhanced build needs the identical reversal or its
    # walls disagree with the deck hinges exactly as the Standard ones did.
    #
    # Each entry names BOTH shells: the outer slot keeps its Standard part and
    # the '<slot>i' inner slot takes the ENH twin. Written out rather than
    # derived from the ' S' rows at load time, because deriving means a second
    # implementation of the Standard-to-ENH name rule living here, drifting from
    # the one in booth-from-link.rb. Every name below was checked against the
    # real folder.
    #
    # Note '46VNT_VSS' has no '_VSS' on its inner twin: Enhanced takes no vent
    # option variants - Benton, 2026-08-24, 'the 35.5 VNT wall fits them all for
    # the inner walls'.
    'MDL 6060 E' => {
      'E0' => '16PanelSolid',   'E0i' => 'ENH 11.5PanelSolid',
      'E1' => '40VNT',          'E1i' => 'ENH 35.5VNT',
      'W0' => '16PanelSolid',   'W0i' => 'ENH 11.5PanelSolid',
      'W1' => '40PanelSolid',   'W1i' => 'ENH 35.5PanelSolid'
    },
    'MDL 6084 E' => {
      'E0' => '16PanelSolid',   'E0i' => 'ENH 11.5PanelSolid',
      'E1' => '40PanelSolid',   'E1i' => 'ENH 35.5PanelSolid',
      'W0' => '16PanelSolid',   'W0i' => 'ENH 11.5PanelSolid',
      'W1' => '40PanelSolid',   'W1i' => 'ENH 35.5PanelSolid'
    },
    'MDL 7272 E' => {
      'N0' => '46VNT_VSS',      'N0i' => 'ENH 41.5VNT',
      'N1' => '22PanelSolid',   'N1i' => 'ENH 17.5PanelSolid',
      'S0' => 'Right46Door',    'S0i' => 'ENH Right41.5Door',
      'S1' => '22PanelSolid',   'S1i' => 'ENH 17.5PanelSolid',
      'E0' => '22PanelSolid',   'E0i' => 'ENH 17.5PanelSolid',
      'E1' => '46VNT_VSS',      'E1i' => 'ENH 41.5VNT',
      'W0' => '22PanelSolid',   'W0i' => 'ENH 17.5PanelSolid',
      'W1' => '46Panel3236WDO', 'W1i' => 'ENH 41.5Panel3236WDO'
    },
    'MDL 7296 E' => {
      'E0' => '22PanelSolid',   'E0i' => 'ENH 17.5PanelSolid',
      'E1' => '46PanelSolid',   'E1i' => 'ENH 41.5PanelSolid',
      'W0' => '22PanelSolid',   'W0i' => 'ENH 17.5PanelSolid',
      'W1' => '46PanelSolid',   'W1i' => 'ENH 41.5PanelSolid'
    }
  }.freeze

  # Fallback when a slot has no explicit assignment: build a name from the slot's
  # kind and its measured run length. Reported whenever it is used, because a
  # guessed component is not the same as a specified one.
  #
  # ON THE INNER SHELL the widths are the IEP ones and they are not whole
  # inches, so the Standard round-to-inch would compose "42VNT" for a 41.5 wall
  # and find nothing. Inner runs are formatted to the half inch instead, and the
  # Panel / PanelSolid split is carried over from the Standard twin: the -4.5
  # shift preserves it, so ENH 14.5/23.5/26.5/38.5 are Panel and ENH
  # 11.5/17.5/35.5/41.5 are PanelSolid (checked against the real filenames).
  ENH_PLAIN_PANEL = %w[14.5 23.5 26.5 38.5].freeze

  def self.guess_component(kind, run, inner = false)
    if inner
      w = (run * 2).round / 2.0
      ws = format('%g', w)
      return case kind
             when 'VNT'    then "ENH #{ws}VNT"
             when 'NV'     then "ENH #{ws}NV"
             when 'DRFRM'  then "ENH Right#{ws}Door"
             when 'CBL'    then "ENH #{ws}PanelCBL"
             when 'SEAL'   then ENH_SEAL_COMP
             when 'CORNER' then ENH_CORNER_COMP
             else
               ENH_PLAIN_PANEL.include?(ws) ? "ENH #{ws}Panel" : "ENH #{ws}PanelSolid"
             end
    end
    w = run.round
    case kind
    when 'VNT'   then "#{w}VNT"
    when 'DRFRM' then "Right#{w}Door"
    when 'CBL'   then "#{w}PanelCBL"
    when 'SEAL'  then SEAL_COMP
    when 'CORNER' then CORNER_COMP
    else
      # 7, 19, 28, 31, 43 are plain "nPanel"; 16, 22, 40, 46 are "nPanelSolid".
      %w[7 19 28 31 43].include?(w.to_s) ? "#{w}Panel" : "#{w}PanelSolid"
    end
  end

  # ------------------------------------------------------------------- input --

  def self.ask
    unless File.exist?(DATA)
      UI.messagebox("Booth data not found:\n#{DATA}\n\nRun:  python gen-booth.py --all")
      return nil
    end
    load DATA

    keys = WR_BOOTH_DATA::BOOTHS.keys.sort_by { |k| [(k[/\d+/] || '0').to_i, k] }
    return nil if keys.empty?

    last = read_pref('booth', keys.include?('MDL 7272 S') ? 'MDL 7272 S' : keys.first)
    last = keys.first unless keys.include?(last)
    dir  = read_pref('dir', DEFAULT_DIR)

    # 'parts' is shared with booth-from-link.rb and probe-components.rb — all
    # three read the same component library, so a folder found once in any of
    # them is offered by all three.
    dir, dlist = WR_Folder.field('parts', dir)

    # THE THREE ARRAYS ARE POSITIONAL AND MUST STAY THE SAME LENGTH. UI.inputbox
    # matches prompt[i] to default[i] to list[i] by index and says nothing when
    # they disagree — it just reads the wrong field into the wrong variable. The
    # 'Floor and ceiling' row was removed from all three together for that
    # reason; res is now 0 booth, 1 folder, 2 height, 3 dry run.
    # FOUR ROWS SINCE 2026-08-25. Adding one means editing all THREE arrays and
    # every res[] index below - UI.inputbox matches them by position and says
    # nothing when they disagree, it just reads the wrong field into the wrong
    # variable. res is now 0 booth, 1 folder, 2 height, 3 shell, 4 dry run.
    res = UI.inputbox(['Booth', 'Component folder', 'Height', 'Shell',
                       'Dry run — report only'],
                      [last, dir, 'Standard (81 in)', 'Both', 'No'],
                      [keys.join('|'), dlist, 'Standard (81 in)|HX (91 in)',
                       'Both|Inner (IEP) only|Outer (Standard) only',
                       'Yes|No'],
                      'Build Booth from Components')
    return nil unless res

    # create = false: an INPUT folder. Creating an empty one would turn a
    # mistyped drive letter into "every component missing".
    d = WR_Folder.resolve(res[1], 'parts', 'Folder of component .skp files', false)
    return nil if d.nil?
    write_pref('booth', res[0])
    # The stored 'deck' preference is deliberately left where it is rather than
    # deleted. Nothing reads or writes it any more, it is a few bytes in the
    # registry, and migration code for a preference no user will ever see again
    # is more risk than the tidiness is worth.
    shell = if res[3].to_s.start_with?('Inner') then 'inner'
            elsif res[3].to_s.start_with?('Outer') then 'outer'
            else 'all'
            end
    { 'booth' => res[0], 'dir' => d, 'hx' => res[2].to_s.start_with?('HX'),
      'shell' => shell, 'dry' => res[4] == 'Yes' }
  end

  # read_default EVALS the stored string and write_default does not escape quotes
  # in it, so a stored value with a quote raises SyntaxError — not a
  # StandardError, so it escapes an ordinary rescue.
  def self.read_pref(k, fallback)
    v = Sketchup.read_default(PREF, k, fallback).to_s
    v.empty? ? fallback : v
  rescue Exception
    fallback
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  # ------------------------------------------------------------- definitions --

  def self.load_def(model, dir, name, cache)
    return cache[name] if cache.key?(name)
    path = File.join(dir, "#{name}.skp")
    unless File.exist?(path)
      # The set is not consistently cased — 40VNT_VSS but 40Vnt_VSS_CP.
      hit = Dir.glob(File.join(dir, '*.skp')).find { |f| File.basename(f, '.skp').downcase == name.downcase }
      path = hit
    end
    if path.nil? || !File.exist?(path)
      cache[name] = nil
      return nil
    end
    cache[name] = (model.definitions.load(path) rescue nil)
  end

  # height / width / thickness axis indices, measured from the definition itself.
  # Extents are taken as max minus min, per axis, and NOT from BoundingBox's
  # width/height/depth. Which of those three means Y and which means Z is a
  # coin-flip anyone reading the code has to look up, and getting it backwards
  # swaps a part's height with its width — which is exactly what laid the window
  # panel flat on the floor in the first build. max-min needs no lookup.
  # want is the height the part is EXPECTED to measure - 81/91 on the Standard
  # shell, 79.5/89.5 on the IEP inner one. It was a hardcoded 81/91 until the
  # inner shell existed; a 79.5 part still passed the +/-6 test, but every
  # downstream figure that leans on :want was then 1.5 out.
  def self.classify(defn, hx, want = nil)
    bb = defn.bounds
    return nil unless bb.valid?
    mn = bb.min
    mx = bb.max
    e = [mx.x.to_f - mn.x.to_f, mx.y.to_f - mn.y.to_f, mx.z.to_f - mn.z.to_f]
    want ||= hx ? 91.0 : 81.0
    hi = (0..2).min_by { |i| (e[i] - want).abs }
    # A vent housing stands a little proud of 81; anything within 6 in is still
    # the height axis. Beyond that the part is not a wall part and is reported.
    return nil if (e[hi] - want).abs > 6.0
    rest = (0..2).to_a - [hi]
    wi, ti = e[rest[0]] >= e[rest[1]] ? [rest[0], rest[1]] : [rest[1], rest[0]]
    { :e => e, :hi => hi, :wi => wi, :ti => ti, :want => want,
      :h => e[hi], :w => e[wi], :t => e[ti], :bb => bb }
  end

  # ------------------------------------------------------------------ placing --

  def self.axis_vec(sym)
    sym == :x ? VX : (sym == :y ? VY : VZ)
  end

  # Which orderings of (height, thickness, width) are an even permutation of the
  # definition's own X, Y, Z. Used to get the handedness right by construction.
  EVEN = [[0, 1, 2], [1, 2, 0], [2, 0, 1]].freeze

  # THE INNER VENT'S HALF TURN, DERIVED FROM THE PART'S MEASURED AXES.
  #
  # rotation() below pins height->up and thickness->the wall normal, then
  # DERIVES the along-wall width direction from the parity of the definition's
  # own (height, thickness, width) axis permutation. Parity is an accident of
  # how the part was authored, so two parts with opposite parity land END FOR
  # END from each other on the same wall. That is the whole defect.
  #
  # Of the eight ENH vent parts, ENH 35.5VNT is the only one whose width runs
  # X; the other seven - both 41.5s, all four _HX, and the NVs - run Y. So the
  # blanket 180 was calibrated against the one odd part and was wrong for the
  # rest. Five of Benton's in-SketchUp reports fit this rule at face value and
  # none contradict it; the write-up lists them.
  #
  # A part authored end for end IN ITS OWN FRAME would defeat this, exactly as
  # four ENH ceiling parts are authored upside down (IEP tray, v1.6.30). Only
  # ENH 35.5VNT and the _HX 35.5 have been seen in a built model.
  #
  # DO NOT generalise this to every inner part. The inner DOOR family is all
  # Y-running and empirically wants 180 (IEP_DOOR_YAW), which is the OPPOSITE
  # convention; the mid-wall seal runs X and wants 180, which agrees with the
  # vents. Convention is per family, and it is measured per family.
  def self.iep_vent_yaw(cls)
    return 0.0 if cls.nil?
    EVEN.include?([cls[:hi], cls[:ti], cls[:wi]]) ? 0.0 : 180.0
  end

  # Rotation only. Two constraints are pinned and the third is DERIVED:
  #
  #     the height axis  -> world up
  #     the thickness axis -> the wall's outward normal
  #     the width axis   -> whatever a right-handed system then requires
  #
  # The first version pinned all three and then "fixed" the handedness by
  # reversing the normal when the determinant came out negative. That produced a
  # valid right-handed transform and a part rotated 180 degrees about its own
  # height — inside face pointing out. It happened on exactly the two walls whose
  # run and normal directions made the determinant negative, which is why half
  # the booth looked right and half was reversed.
  #
  # Deriving the width direction instead cannot do that. Whether the result faces
  # exterior-out or exterior-in is then ONE global convention rather than a
  # per-wall accident, which is what the Face outward option flips.
  def self.rotation(cls, nrm_vec)
    hi = cls[:hi]
    ti = cls[:ti]
    wi = cls[:wi]
    s = EVEN.include?([hi, ti, wi]) ? 1 : -1
    ax = [nil, nil, nil]
    ax[hi] = VZ
    ax[ti] = nrm_vec
    ax[wi] = s > 0 ? VZ.cross(nrm_vec) : nrm_vec.cross(VZ)
    Geom::Transformation.axes(ORIGIN, ax[0], ax[1], ax[2])
  end

  # World-space extents of the definition once rotated.
  def self.rotated_bounds(cls, rot)
    bb = cls[:bb]
    xs = []
    ys = []
    zs = []
    8.times do |i|
      p = bb.corner(i).transform(rot)
      xs << p.x.to_f
      ys << p.y.to_f
      zs << p.z.to_f
    end
    { :x => [xs.min, xs.max], :y => [ys.min, ys.max], :z => [zs.min, zs.max] }
  end

  THIN = 3.0     # anything thicker than this has a leaf, a duct or a housing
  IDENTITY = Geom::Transformation.new

  # ---------------------------------------------------------- facing --------
  #
  # Which way a definition's own thickness axis points relative to the booth.
  # There is no dialog for this — nobody wants a booth built inside out — but it
  # IS a single flag, because it cannot be derived from geometry. A panel is a
  # slab; nothing about its bounding box says which face is the room side.
  #
  # FACE_OUT = true  means the definition's +thickness points AWAY from the booth
  # FACE_OUT = false means it points INTO the booth
  #
  # If every part comes out reversed, change this one word and rebuild. Do not
  # add per-part exceptions to compensate — a mix of a global flag and a list of
  # exceptions is how this ended up flipping back and forth. Get the global one
  # right first, and only then add a name here if a genuinely odd part remains.
  FACE_OUT = false

  # Parts whose thickness axis is authored opposite to everything else. The
  # mid-wall seam seal is the one confirmed case: it read correctly in the run
  # where every panel read backwards, on both settings of the global flag.
  REVERSED = %w[MidWallSeamSeal MidWallSeamSeal_HX].freeze

  # Every vertex in a definition, in the definition's own coordinates, following
  # nested groups and components. A door's leaf and a vent's duct are nested, so
  # a non-recursive walk sees almost nothing.
  def self.collect_points(ents, tr, out, depth = 0)
    return if depth > 8
    ents.each do |e|
      if e.is_a?(Sketchup::Edge)
        out << e.start.position.transform(tr)
        out << e.end.position.transform(tr)
      elsif e.is_a?(Sketchup::ComponentInstance)
        collect_points(e.definition.entities, tr * e.transformation, out, depth + 1)
      elsif e.is_a?(Sketchup::Group)
        collect_points(e.entities, tr * e.transformation, out, depth + 1)
      end
    end
  end

  # Every face in a definition as an axis-aligned box in the definition's own
  # coordinates, following nested groups and components.
  def self.collect_faces(ents, tr, out, depth = 0)
    return if depth > 8
    ents.each do |e|
      if e.is_a?(Sketchup::Face)
        xs = []
        ys = []
        zs = []
        e.vertices.each do |v|
          p = v.position.transform(tr)
          xs << p.x.to_f
          ys << p.y.to_f
          zs << p.z.to_f
        end
        next if xs.empty?
        out << [[xs.min, xs.max], [ys.min, ys.max], [zs.min, zs.max]]
      elsif e.is_a?(Sketchup::ComponentInstance)
        collect_faces(e.definition.entities, tr * e.transformation, out, depth + 1)
      elsif e.is_a?(Sketchup::Group)
        collect_faces(e.entities, tr * e.transformation, out, depth + 1)
      end
    end
  end

  def self.coord(p, i)
    i.zero? ? p.x.to_f : (i == 1 ? p.y.to_f : p.z.to_f)
  end

  # ============================================================================
  # FINDING THE WALL PANEL INSIDE A THICK PART
  #
  # A door measures 32 inches through its thickness axis because the leaf is
  # modelled standing open. Only about an inch of that is the frame that sits in
  # the wall. Placing such a part by its bounding box is therefore meaningless,
  # and the first attempt — inner face of the box to the inner face of the wall —
  # is what pushed the door a whole leaf-depth outboard of its neighbours.
  #
  # The wall panel is findable, though, and without a table. It is the only part
  # of the component that spans nearly the FULL width and FULL height. A leaf, a
  # duct, a handle or a hinge spans neither.
  #
  # So: slice the part along its thickness in quarter-inch bins, ask of each bin
  # whether the geometry in it covers most of the part's width and height, and
  # take the longest run of bins that does. That run is the wall panel, and its
  # midpoint is what gets placed on the wall centreline.
  #
  # This makes ONE rule cover panels, doors and vents alike, and it satisfies the
  # HX centreline requirement for free — the slab it finds on an HX panel is the
  # panel, so centring the slab centres the panel.
  # ============================================================================
  def self.wall_slab(defn, cls)
    boxes = []
    collect_faces(defn.entities, IDENTITY, boxes)
    return nil if boxes.empty?

    ti = cls[:ti]
    wi = cls[:wi]
    hi = cls[:hi]
    want = cls[:want]

    # The panel is found by HEIGHT, and only by height. Nothing here may assume
    # the panel spans the part's width: an EFS vent's exterior silencer stands
    # BESIDE the panel and widens the part's box by ten inches and more
    # (40VNT_VSS_EFS_HX boxes 56.2 in around its 40 in panel). The old finder
    # demanded near-full-width faces, so on every EFS part it found nothing and
    # the vent fell back to bounding-box placement — which is exactly what
    # shoved the 102126's vent panels sideways into the neighbouring wall.
    #
    # A wall panel is the one thing that spans the wall's height. Of the tall
    # faces, the widest cluster is the panel; a silencer or VSS stack is tall
    # but narrow, a door leaf is wide but short.
    tall = boxes.select { |b| (b[hi][1] - b[hi][0]) >= 0.8 * want }
    return nil if tall.empty?
    wmax = tall.map { |b| b[wi][1] - b[wi][0] }.max
    panel = tall.select { |b| (b[wi][1] - b[wi][0]) >= wmax - 1.0 }
    t0 = panel.map { |b| b[ti][0] }.min
    t1 = panel.map { |b| b[ti][1] }.max
    w0 = panel.map { |b| b[wi][0] }.min
    w1 = panel.map { |b| b[wi][1] }.max
    return nil if (t1 - t0) > 3.0        # caught something that is not a panel

    # Bulk vote: which side of the panel carries the leaf / housing / trim.
    above = 0.0
    below = 0.0
    boxes.each do |b|
      above += [b[ti][1] - t1, 0.0].max
      below += [t0 - b[ti][0], 0.0].max
    end
    bulk = if (above - below).abs < 0.5
             0
           else
             above > below ? 1 : -1
           end

    # THE FLOOR RULE, which outranks the bulk vote. What hangs below the
    # panel's bottom edge stands on the host-room floor — a fan unit, a ramp —
    # and the host-room floor is OUTSIDE the booth. A VSS/EFS vent carries bulk
    # on BOTH sides (housing out, silencer stack in), so the bulk vote flips
    # with authoring; the fan cannot.
    hb = panel.map { |b| b[hi][0] }.min
    mid = (t0 + t1) / 2.0
    plus = 0.0
    minus = 0.0
    boxes.each do |b|
      depth = hb - b[hi][0]
      next if depth <= 0.25
      c = (b[ti][0] + b[ti][1]) / 2.0
      c > mid ? plus += depth : minus += depth
    end
    floor_side = 0
    floor_side = 1  if plus > minus + 0.1
    floor_side = -1 if minus > plus + 0.1

    { :t0 => t0, :t1 => t1, :w0 => w0, :w1 => w1, :bulk => bulk, :floor => floor_side,
      :va => above, :vb => below, :fp => plus, :fm => minus }
  end

  def self.place(cls, poly, centre, reversed = false, nominal = 81.0, slab = nil,
                 proud = 0.0, flush = false, bulk_out = true)
    xs = poly.map { |p| p[0].to_f }
    ys = poly.map { |p| p[1].to_f }
    x0 = xs.min
    x1 = xs.max
    y0 = ys.min
    y1 = ys.max

    if (x1 - x0) >= (y1 - y0)
      run_sym = :x
      nrm_sym = :y
      slot = [x0, x1]
      band = [y0, y1]
      out  = ((y0 + y1) / 2.0) >= centre[1] ? 1.0 : -1.0
    else
      run_sym = :y
      nrm_sym = :x
      slot = [y0, y1]
      band = [x0, x1]
      out  = ((x0 + x1) / 2.0) >= centre[0] ? 1.0 : -1.0
    end

    # Facing. A part carrying real bulk beyond its wall panel — a door leaf, a
    # vent housing, a window trim — is oriented so the bulk faces OUT of the
    # booth, measured from its own geometry. Only symmetric parts (plain
    # panels, seals) fall back to the authored convention, which observation
    # says is consistent for them even though it is not for the thick parts.
    band_depth = band[1] - band[0]
    use_slab = slab && (cls[:t] - band_depth) > 0.2
    bulk = use_slab && slab ? slab[:bulk] : 0
    floor_side = use_slab && slab ? slab[:floor] : 0
    # Facing priority: the floor rule (what hangs below the wall stands on the
    # host floor, outside) beats the bulk vote, which beats the convention.
    # bulk_out is false for DOOR slots: both approved booths regressed when the
    # leaf was pointed out of the booth, so a door's bulk — its swung-open leaf —
    # belongs on the room side of the wall, the opposite of a vent's housing.
    # Still measured per part, so a door authored either way round builds alike.
    sense = if floor_side != 0
              floor_side
            elsif bulk != 0
              bulk_out ? bulk : -bulk
            else
              s = FACE_OUT ? 1.0 : -1.0
              reversed ? -s : s
            end
    o = out * sense
    nrm_vec = Geom::Vector3d.new(*(nrm_sym == :x ? [o, 0, 0] : [0, o, 0]))

    rot = rotation(cls, nrm_vec)
    rb  = rotated_bounds(cls, rot)

    r = rb[run_sym]
    # Along the wall, the PANEL box decides — never the part box. An EFS
    # silencer widens the part sideways, and flushing the part box to the slot
    # would shove the panel into the neighbouring wall by the overhang.
    if slab
      lo  = [cls[:bb].min.x.to_f, cls[:bb].min.y.to_f, cls[:bb].min.z.to_f]
      hi2 = [cls[:bb].max.x.to_f, cls[:bb].max.y.to_f, cls[:bb].max.z.to_f]
      lo[cls[:ti]]  = slab[:t0]
      hi2[cls[:ti]] = slab[:t1]
      lo[cls[:wi]]  = slab[:w0]
      hi2[cls[:wi]] = slab[:w1]
      xs = []
      ys = []
      [lo[0], hi2[0]].each do |x|
        [lo[1], hi2[1]].each do |y|
          [lo[2], hi2[2]].each do |z|
            pt = Geom::Point3d.new(x, y, z).transform(rot)
            xs << pt.x.to_f
            ys << pt.y.to_f
          end
        end
      end
      r = run_sym == :x ? [xs.min, xs.max] : [ys.min, ys.max]
    end
    n = rb[nrm_sym]
    thickness = n[1] - n[0]

    # Along the wall, a wall PANEL is pushed hard against the corner rather than
    # centred in its slot.
    #
    # Centring splits any difference between the slot and the real part evenly
    # across both ends, so a panel a hundredth under its nominal width leaves
    # half a hundredth of daylight where it meets the wall at right angles to it.
    # That is invisible in a plan and obvious when you zoom into the corner.
    # Pushing each panel toward the nearer corner puts the whole of that
    # difference at the panel's inboard end instead, where a seam seal covers it.
    #
    # Seals and corner pieces stay centred: they bridge joints rather than
    # terminate against anything, and they are symmetric.
    slot_c = (slot[0] + slot[1]) / 2.0
    booth_c = run_sym == :x ? centre[0] : centre[1]
    # ...unless the only width there is to flush is a BOUNDING BOX that is
    # wider than the slot. With no slab the box includes trim standing proud
    # of the panel at both ends - ENH 41.5VNT is 41.7337 on a 41.5 slot - and
    # flushing the box to the corner puts the PANEL 0.1169 short of it.
    # Measured on Benton's hand-assembled 4872 E wall: the panel edge sits at
    # the slot edge, so the trim is symmetric and centring the box lands the
    # panel exactly. A box that measures its slot flushes as before.
    box_trim = slab.nil? && ((r[1] - r[0]) - (slot[1] - slot[0])).abs > 0.02
    d_run = if !flush || box_trim
              slot_c - ((r[0] + r[1]) / 2.0)
            elsif slot_c < booth_c
              slot[0] - r[0]
            else
              slot[1] - r[1]
            end
    d_up  = nominal - rb[:z][1]           # top of the part to the top of the wall

    # Across the wall, two cases, decided by comparing the part's own thickness
    # against the depth its layout polygon reserves for it.
    #
    # WHEN THEY MATCH, the polygon already describes the whole part and the part
    # is simply centred in it. A 1 in panel in a 1 in band. A 2 in seam seal in
    # the 2 in band the layout gives it — one inch coincident with the wall and
    # one inch proud of it, which is what the seal is. An HX panel's 1.125 in a
    # 1 in band, centred, which keeps the H strip's sixteenth even on both faces.
    #
    # WHEN THE PART IS MUCH THICKER than its band, the extra is a door leaf or a
    # fan housing and centring is meaningless — then the wall panel found inside
    # the part goes on the centreline instead.
    #
    # Centring the slab in BOTH cases is what set the seam seals half an inch too
    # far into the booth: the slab is the seal's flange, not the seal.
    # (band_depth and use_slab are computed above, where facing needed them.)
    d_nrm = if use_slab
              c = [0.0, 0.0, 0.0]
              c[cls[:ti]] = (slab[:t0] + slab[:t1]) / 2.0
              p = Geom::Point3d.new(c[0], c[1], c[2]).transform(rot)
              ((band[0] + band[1]) / 2.0) - (nrm_sym == :x ? p.x.to_f : p.y.to_f)
            else
              ((band[0] + band[1]) / 2.0) - ((n[0] + n[1]) / 2.0)
            end
    d_nrm += out * proud       # `out` is +1 away from the booth, so this is outward

    dx = run_sym == :x ? d_run : d_nrm
    dy = run_sym == :x ? d_nrm : d_run
    move = Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, d_up))
    # Reported so a facing fault can be read off the console instead of guessed
    # at from a screenshot: which world direction this part's own +thickness axis
    # ended up pointing, and whether that is out of the booth or into it.
    facing = format('%s%s %s%s', nrm_sym.to_s.upcase, o > 0 ? '+' : '-',
                    o == out ? 'OUT' : 'IN',
                    floor_side != 0 ? '·floor' : (bulk != 0 ? '·bulk' : ''))
    [move * rot, slot[1] - slot[0], thickness, rb[:z][1] - rb[:z][0], facing]
  end

  # Corner seals are an L, and which way the L faces cannot be read from a
  # bounding box — it is square. It IS readable from the geometry: the L hugs one
  # corner of that square, so the average of its vertices sits off centre toward
  # that corner. Compare that against the corner the layout wants and rotate.
  # Measured in WORLD space, after the placement transform has been applied.
  #
  # The first version measured the L's lean in the definition's own width and
  # thickness axes and compared that to the target. That is only correct when
  # those two axes map to world in the orientation you assumed, and on two of the
  # four corners they do not — which is exactly why two corners came out right
  # and two came out reversed.
  #
  # Transforming the centroid first removes the assumption. Where the L actually
  # leans, once placed, against where it should lean. No handedness to reason
  # about.
  # A corner seal is an L that must hug the booth's outside corner. There are
  # only FOUR orientations it can legally have, so rather than compute an angle
  # and trust it, try all four and keep whichever puts the L's centre of mass
  # nearest the corner it is supposed to wrap.
  #
  # Computing the angle from a centroid, which is what this did before, is off by
  # 45 degrees whenever the L's mass sits diagonally but the reference vector
  # does not — and it lands nowhere near a right angle, which a corner seal must
  # always be at. Four candidates cannot do that: every answer is square with the
  # walls by construction.
  def self.corner_yaw(defn, tr, pivot, target)
    pts = []
    collect_points(defn.entities, tr, pts)
    return 0.0 if pts.empty?
    sx = 0.0
    sy = 0.0
    pts.each do |p|
      sx += p.x.to_f
      sy += p.y.to_f
    end
    cen = Geom::Point3d.new(sx / pts.length, sy / pts.length, 0)

    best = 0.0
    bestd = nil
    4.times do |i|
      yaw = i * Math::PI / 2.0
      c = cen.transform(Geom::Transformation.rotation(pivot, VZ, yaw))
      d = Math.hypot(c.x.to_f - target[0], c.y.to_f - target[1])
      if bestd.nil? || d < bestd
        bestd = d
        best = yaw
      end
    end
    best
  end

  # ------------------------------------------------- wide-access rebalance --
  #
  # A wide-access door frame is 49 in — wider than the 46 or 40 module slot the
  # layout reserves for it. The portal shrinks the companion panel beside it
  # (46+22 -> 49+19, 40+40 -> 49+31) and those shrunk packs arrive in the
  # link's assignments — but the LAYOUT polygons still hold the module widths.
  # So each wall is re-derived from the real part widths: boundaries walk from
  # the wall's first slot edge, every panel takes its true width, every seal
  # its 2 in joint. Beside a WA door the seal therefore shifts 3 in on a
  # 46-series wall and 9 in on a 40-series — Benton's own figures.
  #
  # Applied only when some panel differs from its slot by over 0.1 in, and only
  # when the re-derived wall still lands on the original end within 0.15 in;
  # otherwise the wall is left as generated and said so.
  def self.rebalance_walls(rows)
    by_wall = {}
    rows.each do |r|
      p = r[:part]
      next if p[:k] == 'corner'
      w = p[:id].to_s[0, 1]
      next unless %w[N S E W].include?(w)
      # KEYED ON THE WALL AND THE SHELL, not the wall alone. An Enhanced booth
      # has two runs on every wall - the Standard one and the IEP one 2.25 in
      # inboard of it - and their slot ids differ only by a trailing 'i'.
      # Keyed on the wall alone the two interleave when the list is sorted
      # along the wall, the re-walk sums both shells' panel widths into a
      # single run, and the wall cannot close. That either bails out for the
      # wrong reason or rewrites both shells from a nonsense cursor.
      (by_wall[[w, inner?(p)]] ||= []) << r
    end

    by_wall.each do |key, list|
      w, inn = key
      run_x = %w[N S].include?(w)
      joint = inn ? IEP_SEAL_W : 2.0
      ext = lambda do |poly|
        vs = poly.map { |q| (run_x ? q[0] : q[1]).to_f }
        [vs.min, vs.max]
      end
      # WITHOUT A SLAB, THE PART'S WIDTH IS AN ESTIMATE, NOT A MEASUREMENT -
      # and an estimate must not be allowed to move a wall.
      #
      # wall_slab finds the actual wall panel inside a definition. It succeeds on
      # every Standard part and fails on most ENH ones: an IEP panel is 4 to 15
      # nested containers with a fill / shell / trim / void band profile, and the
      # search does not recognise it. The old fallback then used the whole
      # definition's bounding box, which on an ENH part includes trim and void
      # standing proud of the panel - measured on a real 4872 E, 41.625 against a
      # 41.500 slot on ENH 41.5PanelSolid and 41.734 on ENH 41.5VNT.
      #
      # That is 1/8 to 1/4 in of packaging, and it was enough to make one wall
      # fail to close and silently stretch two others by 0.125. Meanwhile the
      # thing rebalance_walls exists for - a wide-access door - changes a panel by
      # THREE INCHES or more. The two are nowhere near each other, so when there
      # is no slab, a discrepancy under an inch is read as measurement noise and
      # the slot is trusted. Anything larger is still a real substitution and
      # still rebalances.
      #
      # The FIT column in the main table keeps reporting the raw difference, so
      # the discrepancy stays visible - it just stops moving geometry.
      #
      # AND WHEN THERE IS NO SLAB BUT THE NAME DECLARES A MODULE WIDTH, that
      # number is the measurement - see iep_nominal_width. The bounding box is
      # the part plus its packaging, and re-walking a wall from packaging is
      # what put the 6060 E's E inner wall 0.25 out of closure.
      pw_of = lambda do |r|
        next (r[:slab][:w1] - r[:slab][:w0]) if r[:slab]
        slot = ext.call(r[:part][:poly])
        want = slot[1] - slot[0]
        have = iep_nominal_width(r[:name]) || r[:cls][:w]
        (have - want).abs <= SLAB_NOISE ? want : have
      end
      list.sort_by! { |r| ext.call(r[:part][:poly])[0] }

      need = list.any? do |r|
        next false unless r[:part][:k] == 'panel'
        s = ext.call(r[:part][:poly])
        (pw_of.call(r) - (s[1] - s[0])).abs > 0.1
      end
      next unless need

      first = ext.call(list.first[:part][:poly])[0]
      last  = ext.call(list.last[:part][:poly])[1]

      pos = first
      old_end = first
      plan = []
      list.each do |r|
        p = r[:part]
        s = ext.call(p[:poly])
        if p[:k] == 'panel'
          pw = pw_of.call(r)
          plan << [r, pos, pw, s]
          pos += pw
          old_end = s[1]
        else
          plan << [r, pos - old_end, nil, s]   # joint start moves by this much
          pos += joint
        end
      end

      if (pos - last).abs > 0.15
        puts format('  *** %s %s wall does not close after rebalancing to real ' \
                    'widths (off %+.3f in) - leaving it as generated.',
                    w, inn ? 'inner' : 'outer', pos - last)
        next
      end

      plan.each do |r, a, pw, s|
        p = r[:part]
        if p[:k] == 'panel'
          next if (a - s[0]).abs < 0.001 && (pw - (s[1] - s[0])).abs < 0.001
          n = p[:poly].map { |q| (run_x ? q[1] : q[0]).to_f }
          n0 = n.min
          n1 = n.max
          p[:poly] = if run_x
                       [[a, n0], [a + pw, n0], [a + pw, n1], [a, n1]]
                     else
                       [[n0, a], [n0, a + pw], [n1, a + pw], [n1, a]]
                     end
          puts format('  rebalanced %-8s %-24s %.3f..%.3f  (slot was %.3f..%.3f)',
                      p[:id], r[:name], a, a + pw, s[0], s[1])
        elsif a.abs > 0.001
          p[:poly] = p[:poly].map { |q| run_x ? [q[0].to_f + a, q[1]] : [q[0], q[1].to_f + a] }
          puts format('  rebalanced %-8s seal shifted %+.3f in along the wall', p[:id], a)
        end
      end
    end
  end

  # -------------------------------------------------------------------- run --

  def self.run
    # Printed before anything can go wrong, so "no output at all" means the file
    # never loaded or the Ruby Console was not open when it ran — as against the
    # script running and finding nothing to say.
    puts ''
    puts "build-booth-components.rb loaded at #{Time.now.strftime('%H:%M:%S')}"

    cfg = ask
    if cfg.nil?
      puts '  cancelled at the dialog — nothing was built.'
      return
    end

    build_booth(cfg['booth'], ASSIGN[cfg['booth']] || {}, cfg)
  end

  # The programmatic entry point: everything the dialog flow does, callable with
  # an explicit slot->component map. This is where a decoded booth-builder link
  # lands (booth-from-link.rb), with `assign` built from the customer's packs.
  # cfg needs 'dir', 'hx' (bool) and 'dry' (bool).
  def self.build_booth(key, assign, cfg)
    load DATA   # every build: rebalance_walls edits the loaded polygons in place
    spec = WR_BOOTH_DATA::BOOTHS[key]
    if spec.nil?
      UI.messagebox("#{key} is not in the data file. " +
                    "Regenerate it with:  python scripts/gen-booth.py --all")
      return
    end

    model = Sketchup.active_model
    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    assign ||= {}
    # BUILD ONE SHELL AT A TIME. An Enhanced booth is 24 parts in two
    # interleaved shells, and looking at a wrong inner corner through a
    # complete outer shell is most of the difficulty. 'inner' places the IEP
    # parts and nothing else - no outer walls, no deck - so what is left in the
    # model is exactly the thing being fixed.
    #
    # Defaults to 'all', so booth-from-link and every existing caller that
    # passes no 'shell' key behave exactly as before.
    shell = (cfg['shell'] || 'all').to_s.downcase
    # ONCE PER BUILD, not once per part and not on the module. part_top_z takes
    # this as an argument so a second build in the same SketchUp session cannot
    # inherit it. Outer-only builds resolve it too and simply never use it.
    lift = iep_wall_lift(key)
    lift_measured = iep_wall_lift_measured?(key)
    vent_drop = iep_vent_lift_drop(key)
    vent_drop_measured = iep_vent_lift_drop_measured?(key)
    centre = [spec[:w] / 2.0, spec[:h] / 2.0]
    cache  = {}
    rows   = []
    missing = []
    guessed = []

    puts ''
    puts '=' * 78
    puts "BUILD FROM COMPONENTS — #{key}   #{spec[:label]}"
    puts "  exterior #{spec[:w]}\" x #{spec[:h]}\"   interior #{spec[:iw]}\" x #{spec[:ih]}\""
    if spec[:eiw]
      inner_n = spec[:parts].count { |q| inner?(q) }
      puts "  ENHANCED - a second (IEP) shell inside it: #{inner_n} parts, room #{spec[:eiw]}\" x #{spec[:eih]}\""
      lift_src = lift_measured ? "MEASURED ON THIS BOOTH" : "DEFAULT - NOT MEASURED ON THIS BOOTH (measured: #{IEP_WALL_LIFT.keys.join(', ')})"
      puts "  inner walls #{cfg['hx'] ? ENH_WALL_H_HX : ENH_WALL_H}\" tall, underside lifted #{lift}\" - #{lift_src}. See IEP_WALL_LIFT"
      if vent_drop > 0.0
        puts "  inner VENT walls #{vent_drop}\" lower still - underside at #{lift - vent_drop}\". See IEP_VENT_LIFT_DROP"
      else
        puts "  inner vent walls flush with the rest of the inner shell - this booth has no IEP_VENT_LIFT_DROP figure (measured: #{IEP_VENT_LIFT_DROP.keys.join(', ')})"
      end
      puts "  inner rotations: corners placed directly (SW 0 / SE 90 / NE 180 / NW 270), mid-wall seal #{IEP_SEAL_YAW}deg, door #{IEP_DOOR_YAW}deg"
    end
    puts "  height   #{cfg['hx'] ? 'HX, 91 in panels' : 'Standard, 81 in panels'}"
    puts "  parts    #{cfg['dir']}"
    puts "  SHELL    #{shell.upcase} ONLY - the other shell and the deck are not placed" unless shell == 'all'
    puts '=' * 78

    # ---- pass 1: resolve and measure everything before touching the model.
    spec[:parts].each do |p|
      next if shell == 'inner' && !inner?(p)
      next if shell == 'outer' && inner?(p)
      inn  = inner?(p)
      name = if p[:k] == 'corner' then (inn ? ENH_CORNER_COMP : CORNER_COMP)
             elsif p[:k] == 'seal' then (inn ? ENH_SEAL_COMP : SEAL_COMP)
             else assign[p[:id]]
             end
      if name.nil?
        xs = p[:poly].map { |q| q[0].to_f }
        ys = p[:poly].map { |q| q[1].to_f }
        run = [xs.max - xs.min, ys.max - ys.min].max
        name = guess_component(p[:sk], run, inn)
        guessed << "#{p[:id]} (#{p[:sk]}#{inn ? ', inner' : ''}) -> #{name}"
      end
      # A Standard name in an inner slot is the one substitution that must never
      # happen silently: it builds, it renders, and it is the wrong booth. It is
      # caught here rather than trusted upstream, because assign arrives from a
      # customer link.
      if inn && !name.to_s.start_with?('ENH ')
        missing << "#{p[:id]}  #{name} - inner shell slot was handed a STANDARD part"
        next
      end
      name = "#{name}_HX" if cfg['hx'] && !name.end_with?('_HX')

      defn = load_def(model, cfg['dir'], name, cache)
      if defn.nil?
        missing << "#{p[:id]}  #{name}.skp"
        next
      end
      want_h = part_height(p, cfg['hx'])
      cls = classify(defn, cfg['hx'], want_h)
      if cls.nil?
        missing << "#{p[:id]}  #{name} — no axis measures #{cfg['hx'] ? 91 : 81} in, not a wall part"
        next
      end
      slab = wall_slab(defn, cls)
      # A part that projects FURTHER from the wall than its frame is wide fools
      # the larger-remaining-axis-is-width guess: the WA ramp door reaches
      # about 60 in out of a 49 in frame, so "width" landed on the ramp axis
      # and the whole part came in rotated 90 degrees in plan. The tell is the
      # panel search failing or finding nonsense — so retry with width and
      # thickness swapped and keep whichever yields a real wall panel.
      if slab.nil? || (slab[:w1] - slab[:w0]) < 5.0
        alt = cls.merge(:wi => cls[:ti], :ti => cls[:wi], :w => cls[:t], :t => cls[:w])
        slab2 = wall_slab(defn, alt)
        if slab2 && (slab2[:w1] - slab2[:w0]) >= 5.0
          puts "  axis swap  #{name}: width is the #{alt[:wi]} axis, not #{cls[:wi]} — " \
               'the part projects further than it is wide'
          cls = alt
          slab = slab2
        end
      end
      rows << { :part => p, :name => name, :defn => defn, :cls => cls, :slab => slab }
    end

    unless missing.empty?
      puts ''
      puts "  *** #{missing.length} part(s) could not be resolved. Nothing has been built."
      missing.each { |m| puts "      #{m}" }
      puts ''
      UI.messagebox("#{missing.length} component(s) missing or unusable.\n\n" \
                    "Nothing was built. The list is in the Ruby Console.")
      return
    end

    unless guessed.empty?
      puts ''
      puts "  #{guessed.length} slot(s) had no explicit assignment and were guessed from kind + run:"
      guessed.each { |g| puts "      #{g}" }
    end

    rebalance_walls(rows)

    # ---- pass 2: place.
    puts ''
    puts "  FACE_OUT = #{FACE_OUT}  — if EVERY part is reversed, flip that one constant."
    puts ''
    puts format('  %-16s %-22s %8s %8s  %-11s %-9s %-9s %s',
                'SLOT', 'COMPONENT', 'SLOT in', 'PART in', 'FIT',
                'PANEL', 'FACING', 'BELOW WALL')
    puts '  ' + '-' * 100

    model.start_operation("Build #{key} from components", true) unless cfg['dry']
    begin
      tag = lambda do |nm, rgb|
        next nil if cfg['dry']
        l = model.layers[nm] || model.layers.add(nm)
        (l.color = Sketchup::Color.new(*rgb)) rescue nil
        l
      end
      t_wall = tag.call('WR-Booth-Walls',   [120, 128, 140])
      t_door = tag.call('WR-Booth-Door',    [238,  98,  22])
      t_vent = tag.call('WR-Booth-Vent',    [64, 102, 124])
      t_seal = tag.call('WR-Booth-Seals',   [90,  90,  96])
      t_corn = tag.call('WR-Booth-Corners', [70,  70,  76])

      booth = cfg['dry'] ? nil : model.entities.add_group
      booth.name = "#{key} (components)" if booth

      placed = 0
      warn = []
      # Same idiom as the room-proud warning below: a figure this booth has not
      # been measured for is used, and is NAMED so it cannot pass as measured.
      if spec[:eiw] && shell != 'outer' && !vent_drop_measured
        warn << "#{key}: no IEP_VENT_LIFT_DROP figure for this booth, so its inner "                  "vent walls sit flush with the rest of the inner shell. That is the "                  "pre-v1.6.33 behaviour, NOT a measurement. Measured booths: "                  "#{IEP_VENT_LIFT_DROP.map { |k, v| "#{k} #{v}" }.join(', ')}"
      end
      if spec[:eiw] && shell != 'outer' && !lift_measured
        warn << "#{key}: IEP wall lift #{lift} is IEP_WALL_LIFT_DEFAULT - this booth "  \
                "has never been measured. Measured booths: "  \
                "#{IEP_WALL_LIFT.map { |k, v| "#{k} #{v}" }.join(', ')}"
      end
      rows.each do |r|
        p = r[:part]
        # Per PART, not per booth. An inner wall is 1.5 shorter than an outer
        # one and its top sits IEP_WALL_LIFT higher; one booth-wide nominal put
        # every IEP wall 1.5 too low, which looks almost right.
        # The vent family hangs IEP_VENT_LIFT_DROP below the rest of the inner
        # shell. Subtracted from the lift rather than from the nominal so an
        # outer part is untouched - part_top_z applies the lift only to inner
        # parts, and an outer vent must not move.
        p_lift = lift
        p_lift -= vent_drop if inner?(p) && iep_vent_part?(r[:name])
        nominal = part_top_z(p, cfg['hx'], p_lift)
        rev = REVERSED.include?(r[:name])
        proud = p[:k] == 'seal' ? SEAL_PROUD : 0.0
        # A door's bulk is its swung leaf and belongs on the ROOM side, the
        # opposite of a vent housing. Which parts are doors is read from the
        # COMPONENT THAT WAS ASSIGNED, never from p[:sk].
        #
        # p[:sk] is the layout's static slot kind, fixed when the data was
        # generated. It says where the door sits on the CATALOGUE arrangement.
        # A customer moving the door in the booth builder does not change it, so
        # on the 96120 the door landed in E1 — a slot the layout calls SOLID —
        # and took the vent rule: bulk out, leaf pointing away from the room. It
        # was the only part in the whole booth facing opposite to its neighbours.
        # The standalone path never showed this because ASSIGN only ever puts a
        # door in a DRFRM slot.
        is_door = !(r[:name].to_s =~ /Door/i).nil?
        tr, slot_len, thickness, part_h, facing = place(r[:cls], p[:poly], centre,
                                                        rev, nominal, r[:slab], proud,
                                                        p[:k] == 'panel',
                                                        !is_door)
        drop = part_h - nominal

        if p[:k] == 'corner'
          xs = p[:poly].map { |q| q[0].to_f }
          ys = p[:poly].map { |q| q[1].to_f }
          pivot = Geom::Point3d.new((xs.min + xs.max) / 2.0, (ys.min + ys.max) / 2.0, 0)
          # Aim the L's centre of mass at the BOOTH'S MIDDLE.
          #
          # Two earlier versions aimed it at a vertex of the corner polygon —
          # first the one furthest from the middle, then the one nearest. Those
          # made no difference, and it took a screenshot to see why: every vertex
          # of that polygon lies on the same diagonal from the polygon's own
          # centre, so "nearest" and "furthest" point the SAME way and pick the
          # same orientation. Aiming at the booth's middle is the direction that
          # is genuinely opposite, and it is the 180 the corners needed.
          target = [centre[0], centre[1]]
          if inner?(p)
            # THE INNER CORNER IS PLACED DIRECTLY, WITH NO HEURISTIC.
            #
            # corner_yaw aims the L's mass at the booth middle, then the IEP
            # quarter turn went on top. On Benton's probed 4872 E that left
            # each corner 0.25 outboard on one axis - the slab search finds a
            # 4.875 leg inside the 5.375 part and place() centred THAT, so the
            # part sat a quarter inch off its own footprint before any turn.
            #
            # ENH CornerSeamSeal is authored AS the SW corner: its box is
            # 1.7500..7.1250 on both axes, which is exactly the SW polygon in
            # booth coordinates, so SW is the identity and the others are
            # quarter turns about the polygon's own centre. The box is square,
            # so a turn about its centre keeps it on its footprint. Yaws match
            # the ones the hand assembly left in place: NW 270, NE 180.
            bb = r[:cls][:bb]
            dz = nominal - bb.max.z.to_f
            tr = Geom::Transformation.translation(
              Geom::Vector3d.new(xs.min - bb.min.x.to_f, ys.min - bb.min.y.to_f, dz))
            # The layout names the corner in the id: 'SW corner seal i'.
            yaw = { 'SW' => 0.0, 'SE' => 90.0, 'NE' => 180.0, 'NW' => 270.0 }[p[:id].to_s[0, 2]] || 0.0
            tr = Geom::Transformation.rotation(pivot, VZ, yaw.degrees) * tr if yaw != 0.0
          else
            yaw = corner_yaw(r[:defn], tr, pivot, target)
            tr = Geom::Transformation.rotation(pivot, VZ, yaw) * tr
          end
        end

        # The inner door turns the same way, for its own reason (above).
        if inner?(p) && is_door && IEP_DOOR_YAW != 0.0
          dxs = p[:poly].map { |q| q[0].to_f }
          dys = p[:poly].map { |q| q[1].to_f }
          dpiv = Geom::Point3d.new((dxs.min + dxs.max) / 2.0,
                                   (dys.min + dys.max) / 2.0, 0)
          tr = Geom::Transformation.rotation(dpiv, VZ, IEP_DOOR_YAW.degrees) * tr
          # ...then 1/2 in toward the room, on the axis across its wall.
          din = case p[:id].to_s[0, 1]
                when 'N' then Geom::Vector3d.new(0, -IEP_DOOR_IN, 0)
                when 'S' then Geom::Vector3d.new(0,  IEP_DOOR_IN, 0)
                when 'E' then Geom::Vector3d.new(-IEP_DOOR_IN, 0, 0)
                else          Geom::Vector3d.new( IEP_DOOR_IN, 0, 0)
                end
          tr = Geom::Transformation.translation(din) * tr if IEP_DOOR_IN != 0.0
        end

        # The IEP mid-wall seal goes in end for end against the Standard one.
        if p[:k] == 'seal' && inner?(p) && IEP_SEAL_YAW != 0.0
          sxs = p[:poly].map { |q| q[0].to_f }
          sys = p[:poly].map { |q| q[1].to_f }
          spiv = Geom::Point3d.new((sxs.min + sxs.max) / 2.0,
                                   (sys.min + sys.max) / 2.0, 0)
          tr = Geom::Transformation.rotation(spiv, VZ, IEP_SEAL_YAW.degrees) * tr
        end

        # The IEP vent wall may go in end for end - see iep_vent_yaw(), which
        # DERIVES the turn from the part's measured axes. Read the name
        # off the COMPONENT THAT WAS ASSIGNED, never p[:sk] - the same reason
        # is_door is: a customer can move a vent into a slot the layout calls
        # SOLID, and the slot kind would not know.
        is_vent = iep_vent_part?(r[:name])
        if inner?(p) && p[:k] == 'panel' && is_vent
          vyaw = iep_vent_yaw(r[:cls])
          axis = r[:cls].nil? ? '?' : %w[X Y Z][r[:cls][:wi]]
          puts format('  %-6s %-22s width runs %s -> vent yaw %g',
                      p[:id], r[:name], axis, vyaw)
          if vyaw != 0.0
            vxs = p[:poly].map { |q| q[0].to_f }
            vys = p[:poly].map { |q| q[1].to_f }
            vpiv = Geom::Point3d.new((vxs.min + vxs.max) / 2.0,
                                     (vys.min + vys.max) / 2.0, 0)
            tr = Geom::Transformation.rotation(vpiv, VZ, vyaw.degrees) * tr
          end
        end

        # Across the wall, for an inner panel with no slab - AFTER the yaw
        # blocks above, because a half turn about the polygon centre swaps
        # which box face is the room face.
        if inner?(p) && p[:k] == 'panel' && r[:slab].nil?
          bb = r[:cls][:bb]
          wx = []
          wy = []
          8.times do |i|
            q = bb.corner(i).transform(tr)
            wx << q.x.to_f
            wy << q.y.to_f
          end
          pxs = p[:poly].map { |q| q[0].to_f }
          pys = p[:poly].map { |q| q[1].to_f }
          wall = p[:id].to_s[0, 1]
          proud = iep_room_proud(r[:name])
          unless iep_room_proud_measured?(r[:name])
            warn << "#{p[:id]} #{r[:name]}: room-proud #{proud} is the 41.5's figure, not measured for this width"
          end
          shift = case wall
                  when 'N' then (pys.min - proud) - wy.min
                  when 'S' then (pys.max + proud) - wy.max
                  when 'E' then (pxs.min - proud) - wx.min
                  else          (pxs.max + proud) - wx.max
                  end
          if shift.abs > 0.0001
            vec = %w[N S].include?(wall) ? Geom::Vector3d.new(0, shift, 0)
                                         : Geom::Vector3d.new(shift, 0, 0)
            tr = Geom::Transformation.translation(vec) * tr
          end

          # ...and along it, if the box's overshoot is all at one end.
          over = r[:cls][:w] - slot_len
          if iep_trim_end(r[:name]) == :lo && over > 0.02
            wdir = [tr.xaxis, tr.yaxis, tr.zaxis][r[:cls][:wi]]
            v = Geom::Vector3d.new(wdir.x * -over / 2.0, wdir.y * -over / 2.0, 0)
            tr = Geom::Transformation.translation(v) * tr
          end
        end

        # The exact difference, not a pass mark. A part 0.01 under its slot is
        # "ok" by any tolerance and still shows as daylight at a corner, so the
        # number is what gets printed.
        # Fit compares the PANEL against its slot. The part box is no measure —
        # an EFS silencer widens the part far beyond the slot on purpose.
        pw = r[:slab] ? (r[:slab][:w1] - r[:slab][:w0]) : r[:cls][:w]
        fit = if p[:k] == 'panel'
                d = pw - slot_len
                d.abs < 0.0005 ? 'exact' : format('%+.4f', d)
              else
                'n/a'
              end
        if p[:k] == 'panel' && (pw - slot_len).abs > 0.02
          warn << "#{p[:id]} #{r[:name]}: #{fit} in against its slot"
        end

        puts format('  %-16s %-22s %8.3f %8.3f  %-11s %-9s %-9s %s',
                    p[:id], r[:name], slot_len, pw, fit,
                    r[:slab] ? format('%.4f', r[:slab][:t1] - r[:slab][:t0]) : 'NOT FOUND',
                    facing, drop > 0.01 ? format('hangs %.3f', drop) : '')
        if r[:slab] && r[:cls][:t] > 3.0
          s2 = r[:slab]
          puts format('  %-16s   votes: bulk +%.1f / -%.1f   floor +%.1f / -%.1f   panel w %.3f..%.3f of part %.3f',
                      '', s2[:va], s2[:vb], s2[:fp], s2[:fm], s2[:w0], s2[:w1], r[:cls][:w])
        end
        next if cfg['dry']

        inst = booth.entities.add_instance(r[:defn], tr)
        inst.name = "#{p[:id]}  #{r[:name]}"
        # The tag follows the COMPONENT NAME, not the slot's :sk.
        #
        # :sk is the kind the layout generator expected in that slot. The moment
        # a booth puts a vent somewhere the data calls SOLID — which the E/W
        # swap above does — a slot-kind tag lands the vent on WR-Booth-Walls and
        # a plain panel on WR-Booth-Vent, so hiding the vent tag hides the wrong
        # part. Adding :sk as a fallback does not help: it would re-tag the very
        # slots the swap emptied.
        #
        # The name is always informative, assigned or not: guess_component
        # builds "<w>VNT" and "Right<w>Door" from the kind, and the _HX suffix
        # does not disturb either match.
        inst.layer = if p[:k] == 'corner' then t_corn
                     elsif p[:k] == 'seal' then t_seal
                     elsif r[:name] =~ /Door/i then t_door
                     elsif r[:name] =~ /VNT/i then t_vent
                     else t_wall
                     end
        placed += 1
      end

      # ---- floor and ceiling ------------------------------------------------
      #
      # Kept in wr-deck.rb rather than inlined here: the rules behind it are
      # measured, documented in reference/floor-ceiling-geometry.md, and have
      # their own four constants. Folding them into this file would bury them.
      #
      # UNCONDITIONAL SINCE 2026-08-17. There was a "Floor and ceiling: Yes/No"
      # row in the dialog and a cfg['deck'] boolean behind it; both are gone at
      # Benton's request. A booth without its floor, ceiling and seam seals is
      # not a state anyone was asking for, and the toggle was one more row to
      # answer on every single build. The tradeoff is real and accepted: there
      # is now no way to skip the deck. Restoring it is one dialog row in each
      # of the two tools plus this guard.
      #
      # Still skipped on a dry run — a dry run places nothing, deck included.
      deck_note = nil
      # The standard deck is placed even on an inner-only build, because the
      # IEP deck sits against it and needs its bounds - and then erased again,
      # so what is left is still only the inner shell.
      if !cfg['dry'] && booth
        t_deck = tag.call('WR-Booth-Deck', [120, 120, 128])
        wall_h = cfg['hx'] ? 91.0 : 81.0
        deck_added = {}
        %w[FL CL].each do |kind|
          before = booth.entities.length
          n, dwarn, note = WR_Deck.build(model, booth, spec, cfg['dir'], kind, wall_h)
          added = booth.entities.to_a[before..-1].to_a
          added.each { |e| (e.layer = t_deck) rescue nil }
          deck_added[kind] = added
          deck_note = "#{deck_note}#{deck_note ? '; ' : ''}#{kind} #{n}#{note ? " (#{note})" : ''}"
          placed += n
          (dwarn || []).each { |w| puts "  DECK #{kind}: #{w}" }
        end

        # Seam seals run with the deck and carry the same WR-Booth-Deck tag: a
        # seal is part of the deck, and a deck without its seam seals is not a
        # state anyone has asked for. They were never given their own control,
        # and now neither has one — the whole deck is unconditional.
        #
        # BOTH DECKS GET THEM AS OF 2026-08-26. The ceiling five were placed
        # from the start; the floor five (STDSS FL5/FL6/FL7/FL8, STDSS 8.5FL)
        # existed in the library all along and had never been placed. Benton:
        # "We also need to start pulling in the floor seam seal."
        #
        # THE FLOOR SEAL'S HEIGHT IS NOT FIT TESTED and WR_Deck warns by name on
        # every build until WR_Deck::SEAL_FL_DATUM_LIFT is set from a real one.
        # The ceiling's -1.75 was NOT reused — see the constant's comment.
        seal_added = []
        %w[CL FL].each do |skind|
          before = booth.entities.length
          sn, swarn, snote = WR_Deck.seals(model, booth, spec, cfg['dir'], wall_h, skind)
          added = booth.entities.to_a[before..-1].to_a
          added.each { |e| (e.layer = t_deck) rescue nil }
          seal_added.concat(added)
          deck_note = "#{deck_note}; #{skind} seals #{sn}#{snote ? " (#{snote})" : ''}"
          placed += sn
          (swarn || []).each { |w| puts "  DECK SEAL #{skind}: #{w}" }
        end

        # Where the standard deck landed, per kind, read off the placed parts.
        host = { 'FL' => union_bounds(deck_added['FL']),
                 'CL' => union_bounds(deck_added['CL']) }

        if shell == 'inner'
          gone = deck_added.values.flatten + seal_added
          booth.entities.erase_entities(gone) unless gone.empty?
          placed -= gone.length
          deck_note = "standard deck measured and removed (inner-only build)"
        end
        puts "  deck     #{deck_note}"

        # THE IEP DECK, against the standard one.
        if spec[:eiw] && shell != 'outer'
          before = booth.entities.length
          n, dnotes, dwarns = iep_deck(model, booth, key, spec, cfg['dir'], cache, host)
          booth.entities.to_a[before..-1].to_a.each { |e| (e.layer = t_deck) rescue nil }
          placed += n
          dnotes.each { |x| puts "  IEP deck #{x}" }
          dwarns.each { |x| puts "  IEP DECK: #{x}" }
          puts '  IEP deck NOT PLACED - see above' if n.zero?
        end
      end

      model.commit_operation unless cfg['dry']
      model.active_view.zoom_extents unless cfg['dry']

      thick = rows.count { |r| r[:cls][:t] > THIN }
      puts ''
      puts '  ' + '-' * 60
      if cfg['dry']
        puts "  DRY RUN — nothing built. #{rows.length} parts would be placed."
        # A dry run whose whole result is console text is invisible if the
        # console happens to be closed, so say it in a dialog too.
        UI.messagebox("DRY RUN — nothing built.\n\n#{rows.length} parts resolved" \
                      "#{warn.empty? ? ' and every panel matches its slot.' : ", #{warn.length} item(s) flagged."}" \
                      "\n\nThe full table is in the Ruby Console:\n" \
                      'Extensions > Developer > Ruby Console.')
      else
        puts "  placed #{placed} component instances."
      end
      puts "  #{thick} part(s) carry bulk beyond their wall panel (a leaf, a housing,"
      puts '  a trim) and were oriented so that bulk faces OUT of the booth — measured'
      puts "  from each part's own geometry, marked ·bulk in the FACING column. Parts"
      puts '  authored either way round therefore come out the same. If one of THOSE'
      puts '  faces the wrong way, the part itself points its bulk into the booth.'
      unless warn.empty?
        puts ''
        puts "  *** #{warn.length} item(s) flagged - a part that does not measure its"
        puts '      slot, or a figure used that was not measured for this booth:'
        warn.each { |w| puts "      #{w}" }
      end
      puts '  ' + '-' * 60
      puts ''
    rescue Exception => e
      model.abort_operation unless cfg['dry']
      raise e
    end
    nil
  end
end

begin
  # $wr_no_autorun lets booth-from-link.rb load this file for its build_booth
  # method without popping the dialog.
  WR_BuildBoothComponents.run unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Build from components failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
