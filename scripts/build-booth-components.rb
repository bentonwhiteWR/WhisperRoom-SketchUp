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
  # 0.0 is now the assumption: the inner wall's underside is flush with the
  # outer wall's and the whole 1.5 falls at the top. That is still a guess, but
  # it is a guess you can check by eye - the two wall bottoms either line up or
  # they do not - which 0.3125 was not.
  IEP_WALL_LIFT = 0.0

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
  IEP_ROOM_PROUD = { :vent => 0.125, :panel => 0.0625 }.freeze

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
    name.to_s =~ /VNT|NV/i ? :sym : :lo
  end

  def self.iep_room_proud(name)
    name.to_s =~ /VNT|NV/i ? IEP_ROOM_PROUD[:vent] : IEP_ROOM_PROUD[:panel]
  end
  IEP_DOOR_YAW   = 180.0   # the inner door - see below

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
  # IEP_WALL_LIFT for an inner one, which puts its underside on the lip.
  def self.part_top_z(part, hx)
    part_height(part, hx) + (inner?(part) ? IEP_WALL_LIFT : 0.0)
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
      pw_of = lambda do |r|
        next (r[:slab][:w1] - r[:slab][:w0]) if r[:slab]
        slot = ext.call(r[:part][:poly])
        want = slot[1] - slot[0]
        (r[:cls][:w] - want).abs <= SLAB_NOISE ? want : r[:cls][:w]
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
      puts "  inner walls #{cfg['hx'] ? ENH_WALL_H_HX : ENH_WALL_H}\" tall, underside lifted #{IEP_WALL_LIFT}\" - THE LIFT IS UNMEASURED, see IEP_WALL_LIFT"
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
      rows.each do |r|
        p = r[:part]
        # Per PART, not per booth. An inner wall is 1.5 shorter than an outer
        # one and its top sits IEP_WALL_LIFT higher; one booth-wide nominal put
        # every IEP wall 1.5 too low, which looks almost right.
        nominal = part_top_z(p, cfg['hx'])
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
        end

        # The IEP mid-wall seal goes in end for end against the Standard one.
        if p[:k] == 'seal' && inner?(p) && IEP_SEAL_YAW != 0.0
          sxs = p[:poly].map { |q| q[0].to_f }
          sys = p[:poly].map { |q| q[1].to_f }
          spiv = Geom::Point3d.new((sxs.min + sxs.max) / 2.0,
                                   (sys.min + sys.max) / 2.0, 0)
          tr = Geom::Transformation.rotation(spiv, VZ, IEP_SEAL_YAW.degrees) * tr
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
      if !cfg['dry'] && booth && shell != 'inner'
        t_deck = tag.call('WR-Booth-Deck', [120, 120, 128])
        wall_h = cfg['hx'] ? 91.0 : 81.0
        %w[FL CL].each do |kind|
          before = booth.entities.length
          n, dwarn, note = WR_Deck.build(model, booth, spec, cfg['dir'], kind, wall_h)
          booth.entities.to_a[before..-1].to_a.each { |e| (e.layer = t_deck) rescue nil }
          deck_note = "#{deck_note}#{deck_note ? '; ' : ''}#{kind} #{n}#{note ? " (#{note})" : ''}"
          placed += n
          (dwarn || []).each { |w| puts "  DECK #{kind}: #{w}" }
        end

        # Ceiling seam seals run with the deck and carry the same WR-Booth-Deck
        # tag: a seal is part of the deck, and a deck without its seam seals is
        # not a state anyone has asked for. They were never given their own
        # control, and now neither has one — the whole deck is unconditional.
        before = booth.entities.length
        sn, swarn, snote = WR_Deck.seals(model, booth, spec, cfg['dir'], wall_h)
        booth.entities.to_a[before..-1].to_a.each { |e| (e.layer = t_deck) rescue nil }
        deck_note = "#{deck_note}; seals #{sn}#{snote ? " (#{snote})" : ''}"
        placed += sn
        (swarn || []).each { |w| puts "  DECK SEAL: #{w}" }

        puts "  deck     #{deck_note}"
        if spec[:eiw]
          # SAID OUT LOUD RATHER THAN LEFT MISSING. The deck placed above is
          # the STANDARD floor and ceiling. The IEP inner floor and ceiling
          # (ENH <size>FL / ENH <size>CL, which do exist in the library) are
          # NOT placed - their z datum has not been measured, and guessing
          # it would put a floor through a wall. A render of an Enhanced
          # booth interior is missing its inner deck until that is done.
          puts "  deck     IEP INNER FLOOR AND CEILING NOT PLACED - outer deck only"
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
                      "#{warn.empty? ? ' and every panel matches its slot.' : ", #{warn.length} do NOT match their slot."}" \
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
        puts "  *** #{warn.length} part(s) do not measure their slot:"
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
