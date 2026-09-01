# wr-overlays.rb — foam, duct covers and the option parts, for the component
# booth builder.
#
# NOT A COMMAND. A library, `load`ed by build-booth-components.rb, and in
# wr_tools' SKIP so it never appears in the panel.
#
# Every placement number here is PORTAL-SOURCED — read out of the booth builder
# portal's own renderers by the researcher and recorded, with provenance, in
# .forge/researcher/portal-part-placement.md. Nothing in this file was derived
# from a screenshot or a guess; where a figure could not be sourced, the part is
# refused BY NAME rather than approximated. Read that report before changing a
# number here.
#
# VOCABULARY, because it has already caused one mistranslation: the wall Benton
# calls the "bench wall" is the portal's VNT (VENT) wall — the word "bench"
# exists nowhere in the portal source. The duct covers attach to VENT walls.
# "IEP wall" is the Enhanced inner-shell panel, whose room face stands 2.25 in
# roomward of the standard wall's interior face (1.25 air gap + 1.00 panel).
#
# WHAT THIS PLACES
#
#   FOAM        one 24 x 48 x 2 sheet per 40/46 in SOLID / VNT / CBL / NV
#               panel — never a door, never a window, never a narrow companion
#               panel (the 43 included). Centred both ways on its panel, on the
#               interior face; on an Enhanced booth it MOVES to the IEP inner
#               wall's room face — one sheet per wall, never both shells.
#               Always ships: it is not a payload option (payload `f` is only
#               its colour).
#   DUCT COVERS a hi/lo pair per 40/46 in VENT wall, each centred on its
#               measured duct port. NOT on an HX booth — the 10 in
#               height-extension panels do not ship with the hinge duct covers
#               (a product fact, Benton, quoted in the portal source). Same
#               2.25 in IEP move on Enhanced.
#   DESK        payload dk/dl/ds/dox. Small 30x14 (may mount outside a
#               window), large 42x17 (interior only), surface at 32.5.
#   MJP         payload jp/ms. "Multi jack panel" — a pass-through with a box
#               on BOTH faces of one window/cable wall, plate centre 27.25.
#   EFP         payload ep (or the ad ADA bundle). The elevated-floor slab,
#               centred in plan on the carpet floor. The Standard booth's
#               perimeter strips have NO component and NO art — reported
#               missing, never faked.
#   ROOF UNIT   payload rv (+ vs for the VSS twin). RM<model>.skp — the whole
#               roof assembly, both boxes and every duct, as ONE part — seated
#               on the booth's roof. Centred on the booth's NOMINAL footprint,
#               except the four 84-in-wide models which go flush RIGHT (+x).
#               The rule, whose side +x is, and what is still refused (HX) all
#               live in scripts/wr-roof-vent.rb's header; this file only
#               applies it.
#   CASTER      payload cs. The wheeled tray the whole booth sits down into:
#   PLATE       one CP plate per floor-deck tile — the plate set tiles
#               one-for-one with the floor deck (observed, WhisperRoomQuote
#               scripts/gen-iso-placeholders.js CP block: the cp tiles are
#               built from the floor tiling plan) and each plate is authored
#               with its lap out to the FULL published exterior (SIDE plates
#               measure along+1 x cross+2, CTR along x cross+2, single-piece
#               +2 both ways — verified against _face-levels.tsv for all 17
#               two-axis CP parts). Plate bottoms seat on the ground plane
#               (world z 0) and the WHOLE BOOTH is lifted CP_BOOTH_LIFT in
#               one group transform — see the caster constants below for the
#               datum figures and who they came from. A model whose CP file
#               is missing (the 4260 / 4284 / 4896 today — the portal's own
#               manifest is missing the same sizes) refuses BY NAME and the
#               booth is NOT lifted. The vent-wall _CP art swap is separate
#               and already handled by booth-from-link.rb.
#
# WHAT IT DOES NOT PLACE, ON PURPOSE
#
#   STEP (payload sp). Pairs with the caster plate, which now builds — but
#   the step's own placement is still not portal-sourced end to end. What IS
#   known: 12 in deep in front of the door (layout-render's step block,
#   TD_ART.step art measures 44.03 x 12.08), StepFront.skp exists. What is
#   NOT sourced: its lateral anchor (centred on the door leaf or the frame?)
#   and which face of the part is the tread. Refused by name until someone
#   rules on those two, so a guessed step cannot ship inside a correct booth.

require 'sketchup.rb'

module WR_Overlays
  # Re-loadable like wr-deck.rb: constants are re-assigned on every load.
  constants.each { |c| remove_const(c) rescue nil }

  # ---------------------------------------------------------------- numbers --
  #
  # Foam sheet, nominal. Used only for CENTRING math (x = (panelW - 24)/2 by
  # placing the measured part's centre on the panel centre) — the part itself
  # is placed off its own measured bounding box, so the fraction-of-an-inch
  # disagreement between the delivered art measurements (22.97 x 47.88 vs
  # 24.12 x 48.06) never enters placement.
  FOAM_W = 24.0
  FOAM_H = 48.0
  FOAM_T = 2.0

  # Duct port centres, wall-local inches, measured off the delivered vent-wall
  # interior renders (portal assets/iso-render.js OV_DUCT_POS, re-measured four
  # times there). x is from the panel's LEFT EDGE AS SEEN FROM INSIDE the
  # booth; z is the port centre height off the booth floor, ABSOLUTE — an HX
  # booth keeps the ports at the same heights (moot here: HX ships no covers).
  DUCT_PORTS = {
    40 => { :hi => [13.9,  71.1],  :lo => [27.7, 9.1]  },
    46 => { :hi => [16.15, 71.45], :lo => [29.9, 9.45] }
  }.freeze

  # Cover body, from the portal's iso manifest: 11.94 wide, hi 14.76 / lo
  # 13.78 tall, 3.14 deep. Used only to identify the part's axes; placement is
  # off the measured geometry.
  DUCT_COVER_W = 11.94
  DUCT_COVER_H = 14.76
  DUCT_COVER_T = 3.14

  # The two covers sit 62.0 in apart vertically (port-centre table above).
  # The delivered 'Duct Cover.skp' is the cover-SET export, and the portal
  # measured that set's internal separation at 66 in — 4 in wrong. So the .skp
  # is SPLIT and each cover is anchored on its own port centre; if it cannot be
  # split (raw geometry rather than two nested containers), the set goes in
  # anchored on the HIGH port and the low cover's error is stated in inches.
  DUCT_PAIR_SPLIT_MIN = 40.0   # a bounding box longer than this holds the pair

  # Enhanced: overlays move roomward onto the IEP inner wall. The 2.25 itself
  # is never hard-coded into a translation — the inner slot polygon's room edge
  # IS the standard interior face minus 2.25 (generated data, checked), so the
  # move falls out of using the inner twin's slot. What IS added is the inner
  # wall's measured room-proud stand-off (build-booth-components'
  # IEP_ROOM_PROUD), so the sheet sits on the wall's PHYSICAL face rather than
  # its nominal band.

  # Desk. Work surface at 32.5 (30 + Benton's 2.5 QA lift, portal
  # MJP/desk height block). The carpeted back strip stands 4.84 above the
  # surface (portal DESK_STRIP_PROUD_IN, measured) — the part is placed by its
  # TOP at 32.5 + 4.84 on the reading that the strip is the part's highest
  # geometry. If a built desk sits visibly high, the .skp does not carry the
  # strip: change DESK_TOP_IS_STRIP to false and the top goes to 32.5.
  DESK_SURFACE_Z    = 32.5
  DESK_STRIP_PROUD  = 4.84
  DESK_TOP_IS_STRIP = true
  DESK_SMALL = { :file => 'DeskSmall', :w => 30.0, :d => 14.0 }.freeze
  DESK_LARGE = { :file => 'DeskLarge', :w => 42.0, :d => 17.0 }.freeze

  # MJP: BOTH BOXES TAKE A HALF TURN IN THE PLANE OF THE WALL.
  #
  # Benton, 1 Sep 2026, off a booth pulled in from a booth link: "MJP needs to
  # be flipped 180". As authored, MJP.skp lands upside down on the wall.
  #
  # This is a spin about the wall NORMAL, not a room flip — the plate stays
  # flat on its face and only its own orientation changes. It is applied to
  # the interior AND the exterior box, because they are the same .skp and a
  # part authored upside down is upside down on both faces. The exterior box's
  # existing 180-in-plan (room_flip, "the ports need to face the camera") is a
  # separate move and is unchanged; the two compose.
  #
  # IF ONLY ONE FACE COMES OUT RIGHT, this is not one constant but two, and
  # the call sites below take the flag separately.
  MJP_SPIN180 = true

  # MJP. Plate CENTRE at 27.25 off the floor (32.5 desk surface minus 5.25,
  # Benton QA 2026-06-27). The jack box is 3.64 tall with cable tails hanging
  # BELOW it, so the box TOP is the stable datum: geometry top goes at
  # 27.25 + 3.64/2. ASSUMED: the plate spans the box's full height. If the
  # plate lands visibly off, measure the part and set MJP_TOP_Z directly.
  MJP_BOX_H = 3.64
  MJP_TOP_Z = 27.25 + MJP_BOX_H / 2.0
  MJP_W = 8.39
  MJP_T = 3.01

  # EFP. The sizes the portal sells (lib/booth-price-map.js:269). EFP4896.skp
  # exists in the library but 4896 is not sold standalone — not listed here.
  EFP_SIZES = %w[4872 7272 7296 9696 96120 96144 96168 96192].freeze
  # ~2.83-2.89 measured across sizes; used only to sanity-check which axis is
  # the slab's thickness.
  EFP_T_MIN = 2.5
  EFP_T_MAX = 3.3

  # Which authored face points into the room. A slab's bounding box cannot say
  # which face is the sculpted / hinged / jacked one, so each part family gets
  # ONE flag: +1 means the definition's +thickness axis points INTO the room,
  # -1 means away. If a family builds consistently inside-out, flip its one
  # constant — do not add per-booth exceptions.
  #
  # :duct is -1 as of 2026-08-28. Benton, off freshly built booths: "ALL duct
  # covers need to be flipped 180 degrees." Unconditional - not one model, not
  # one wall, not one width - which is the signature of ONE family constant
  # being the wrong sign, exactly the case this flag was written for. The
  # 'Duct Cover.skp' export's +thickness axis points AWAY from the room, so
  # pinning it to the room normal turned every cover back-to-front.
  #
  # WHAT THIS MOVES, and what it does not: face_sign only reverses the wall
  # normal handed to `rotation`, so the cover yaws 180 degrees IN PLACE. The
  # seating in `wall_transform` is computed from `room`, which is untouched, so
  # the cover's back still lands ON the wall face and its body still stands into
  # the room; the port centre it is anchored on (`run_c`, `z_c`) does not move
  # by a thousandth. Nothing else reads FACE_ROOM[:duct].
  #
  # FALSIFIED BY: a duct cover that now reads backwards the other way, or one
  # that has moved off its port. Say which booth and which wall.
  FACE_ROOM = { :foam => 1, :duct => -1, :desk => 1, :mjp => 1 }.freeze

  # ------------------------------------------------------ caster plate (cs) --
  #
  # THE THREE DATUM FIGURES CAME FROM BENTON DIRECTLY (2026-08-27) AND
  # SUPERSEDE THE PORTAL. The portal's height rule lifts the booth "exactly
  # 5 in" (assets/layout-render.js:3553) and the catalogue says "nearly 5 in"
  # — that is the MARKETING number, what customers are told. Benton uses 4.75
  # when he dimensions drawings, and 4.75 is what this builds. One line each
  # to change if he refines them.
  #
  # CP_BOOTH_LIFT   the booth floor slab's UNDERSIDE ends up this far above
  #                 the ground plane (world z 0, where the plate bottom sits).
  # CP_TRAY_DEPTH   the plate is a TRAY and the whole WhisperRoom sits down
  #                 into it — the rim wraps the bottom of the floor slab by
  #                 this much. The researcher measured 0.739 off the portal
  #                 art; Benton says 3/4, and the delivered plate geometry
  #                 agrees with Benton EXACTLY: every CP part carries a face
  #                 0.7500 below its rim (_face-levels.tsv, all 17 two-axis
  #                 plates, checked 2026-08-27). 0.75 is authored intent AND
  #                 measurement; the 0.739 was pixels.
  # CP_PLATE_HEIGHT derived, 4.75 + 0.75: what a plate SHOULD measure from
  #                 its bottom to its rim. THE DELIVERED PARTS DISAGREE: they
  #                 measure 5.36 to 5.53 bottom-to-rim (rim minus lowest
  #                 geometry, per part, same TSV) — most run about an eighth
  #                 SHORT of 5.50. Neither number is averaged or silently
  #                 picked: the plate bottom seats on the ground and the
  #                 BOOTH holds Benton's 4.75 datum, so a short plate leaves
  #                 its shortfall as a gap hidden inside the tray (tray floor
  #                 a hair below the booth floor) instead of moving the booth.
  #                 Each plate that measures off 5.50 is warned BY NAME.
  CP_BOOTH_LIFT   = 4.75
  CP_TRAY_DEPTH   = 0.75
  CP_PLATE_HEIGHT = 5.50

  # ------------------------------------------------------------- pure logic --
  #
  # Everything from here to the SketchUp section is pure data-in data-out and
  # is exercised OUTSIDE SketchUp by scripts/rbtest-overlays.py on every
  # change. Keep it that way: no Sketchup::, no UI::, no Geom:: above the
  # marked line.

  # The portal's wall kinds, read off the ASSIGNED COMPONENT NAME — never the
  # layout's :sk, for the same reason build-booth-components reads names: a
  # customer moving ventilation changes the assigned component, not the slot
  # kind. Order matters: '46Panel3236WDO' contains 'Panel' and must read as a
  # window; NV is matched at the name's end so 'VNT' can never shadow it.
  def self.kind_of(name)
    n = name.to_s
    return :door   if n =~ /Door/i
    return :window if n =~ /WDO/i
    return :cbl    if n =~ /CBL/i
    return :vnt    if n =~ /VNT/i
    return :nv     if n =~ /NV(_HX)?\z/i
    :solid
  end

  # Benton's foam rule, verified and sharpened by the portal (three renderers
  # agree): 40/46 in SOLID / VNT / CBL / NV panels only. Doors and windows get
  # none; every narrow companion (7/16/19/22/28/31/43) fails the width test.
  # The width is the STANDARD host panel's module width even on Enhanced.
  def self.wears_foam?(name, width)
    return false unless [40, 46].include?(width)
    ![:door, :window].include?(kind_of(name))
  end

  # The duct-cover rule: every 40/46 VENT wall, silencer variants included
  # (the -VSS/-EFS hardware is all on the exterior side; the interior ports are
  # the same) — and NO covers at all on an HX booth. They do not ship.
  def self.wears_duct_covers?(name, width, hx)
    !hx && [40, 46].include?(width) && kind_of(name) == :vnt
  end

  # A slot polygon reduced to wall-local terms: which axis the run is on, the
  # run extents, and where the ROOM side is. `centre` is the booth's plan
  # centre; the face returned is the band edge nearer it — the interior face
  # for an outer slot, the room face for an IEP inner slot.
  #   :run   :x or :y          :r0/:r1  run extents
  #   :naxis the normal axis   :face    room-side band edge
  #   :room  +1/-1             which way along :naxis the room lies
  def self.slot_frame(poly, centre)
    xs = poly.map { |p| p[0].to_f }
    ys = poly.map { |p| p[1].to_f }
    if (xs.max - xs.min) >= (ys.max - ys.min)
      run = :x
      r0 = xs.min
      r1 = xs.max
      n0 = ys.min
      n1 = ys.max
      c  = centre[1].to_f
    else
      run = :y
      r0 = ys.min
      r1 = ys.max
      n0 = xs.min
      n1 = xs.max
      c  = centre[0].to_f
    end
    room = ((n0 + n1) / 2.0) < c ? 1.0 : -1.0
    { :run => run, :r0 => r0, :r1 => r1,
      :naxis => (run == :x ? :y : :x),
      :face => (room > 0 ? n1 : n0), :room => room }
  end

  # The duct x is measured from the panel's LEFT EDGE AS SEEN FROM INSIDE the
  # booth (portal assets/layout-render.js:3369-3374, which mirrors to wIn - x
  # when drawing from outside). Standing inside facing a wall, left is
  # z-cross-facing: N -> west (low run end), S -> east (high), E -> north
  # (high), W -> south (low). So on N and W the x runs up from r0; on S and E
  # it runs down from r1.
  def self.port_run_pos(wall, r0, r1, x)
    %w[N W].include?(wall.to_s) ? r0 + x : r1 - x
  end

  def self.wall_of(id)
    id.to_s[0, 1]
  end

  OPPOSITE_WALL = { 'N' => 'S', 'S' => 'N', 'E' => 'W', 'W' => 'E' }.freeze

  # panels: [{ :id, :name, :poly, :inner }] — every placed panel row, both
  # shells. Only OUTER panels drive qualification (the portal's rules are
  # stated on the standard walls); the inner twin '<id>i', when it exists,
  # supplies the face the overlay actually mounts on. A host with no inner
  # twin keeps its overlay on the standard face (the portal's own exception
  # for filler walls that grew no inner family).
  def self.host_frame(panels, outer, centre)
    twin = panels.find { |q| q[:id] == "#{outer[:id]}i" }
    f = slot_frame((twin || outer)[:poly], centre)
    f.merge(:host_id => (twin || outer)[:id],
            :host_name => (twin || outer)[:name],
            :moved => !twin.nil?)
  end

  # One foam sheet per qualifying panel. Horizontal centre = the HOST PANEL's
  # run centre (portal: (panelWidth - 24)/2, i.e. centred); vertical centre =
  # ph/2 (portal: z = (ph - 48)/2 with ph 81 standard / 91 HX — foam DOES ship
  # on an HX booth). Face from the inner twin on Enhanced.
  def self.foam_targets(panels, centre, ph)
    out = []
    panels.reject { |p| p[:inner] }.each do |p|
      fr0 = slot_frame(p[:poly], centre)
      width = (fr0[:r1] - fr0[:r0]).round
      next unless wears_foam?(p[:name], width)
      hf = host_frame(panels, p, centre)
      out << { :id => p[:id], :outer_name => p[:name], :width => width,
               :wall => wall_of(p[:id]),
               :run => hf[:run], :naxis => hf[:naxis],
               :run_c => (fr0[:r0] + fr0[:r1]) / 2.0,
               :face => hf[:face], :room => hf[:room],
               :z_c => ph / 2.0,
               :host_id => hf[:host_id], :host_name => hf[:host_name],
               :moved => hf[:moved] }
    end
    out
  end

  # The hi/lo cover pair per qualifying vent wall, each centred on its port.
  # x is converted through port_run_pos on the OUTER slot's extents — the port
  # table is stated on the 40/46 standard panel. Empty on an HX booth.
  def self.duct_targets(panels, centre, hx)
    out = []
    panels.reject { |p| p[:inner] }.each do |p|
      fr0 = slot_frame(p[:poly], centre)
      width = (fr0[:r1] - fr0[:r0]).round
      next unless wears_duct_covers?(p[:name], width, hx)
      hf = host_frame(panels, p, centre)
      wall = wall_of(p[:id])
      DUCT_PORTS[width].each do |pos, (x, z)|
        out << { :id => p[:id], :outer_name => p[:name], :width => width,
                 :wall => wall, :pos => pos,
                 :run => hf[:run], :naxis => hf[:naxis],
                 :run_c => port_run_pos(wall, fr0[:r0], fr0[:r1], x),
                 :face => hf[:face], :room => hf[:room],
                 :z_c => z,
                 :host_id => hf[:host_id], :host_name => hf[:host_name],
                 :moved => hf[:moved] }
      end
    end
    out
  end

  # ---- desk / MJP host selection (portal deskPlacement / mjpPlacement) ----

  # deskAccepts: SOLID / VNT / CBL (an NV plug wall classifies SOLID in the
  # portal) of width >= 40 mounts INSIDE; a window of width >= 40 mounts
  # OUTSIDE (small desk only); a door wall never.
  def self.desk_accepts_inside?(name, width)
    width >= 40 && [:solid, :vnt, :cbl, :nv].include?(kind_of(name))
  end

  def self.desk_accepts_outside?(name, width, large)
    !large && width >= 40 && kind_of(name) == :window
  end

  # Returns [panel, :inside/:outside, why] or [nil, nil, why]. `chosen` is the
  # customer's slot id from payload ds ('' when absent); auto order is the
  # portal's: 1) a >=40 inside wall, preferring the wall opposite the door,
  # then SOLID over VNT, then wider; 2) a >=40 window, outside (small only);
  # 3) the widest inside-accepting wall as a last resort.
  def self.desk_host(panels, chosen, large, outside)
    outer = panels.reject { |p| p[:inner] }
    with_w = outer.map do |p|
      xs = p[:poly].map { |q| q[0].to_f }
      ys = p[:poly].map { |q| q[1].to_f }
      [p, [xs.max - xs.min, ys.max - ys.min].max.round]
    end
    door = outer.find { |p| kind_of(p[:name]) == :door }
    opp  = door ? OPPOSITE_WALL[wall_of(door[:id])] : nil

    unless chosen.to_s.empty?
      hit = with_w.find { |p, _| p[:id] == chosen.to_s }
      if hit
        p, w = hit
        if outside && desk_accepts_outside?(p[:name], w, large)
          return [p, :outside, "customer's slot #{chosen}"]
        elsif desk_accepts_inside?(p[:name], w)
          return [p, :inside, "customer's slot #{chosen}"]
        end
      end
      # fall through to auto, and say so
    end

    inside = with_w.select { |p, w| desk_accepts_inside?(p[:name], w) }
    unless inside.empty?
      best = inside.min_by do |p, w|
        [opp && wall_of(p[:id]) == opp ? 0 : 1,
         { :solid => 0, :nv => 0, :vnt => 1, :cbl => 2 }[kind_of(p[:name])] || 3,
         -w]
      end
      why = chosen.to_s.empty? ? 'auto' : "auto — slot #{chosen} does not accept a desk"
      return [best[0], :inside, why]
    end
    windows = with_w.select { |p, w| desk_accepts_outside?(p[:name], w, large) }
    unless windows.empty?
      return [windows.max_by { |_, w| w }[0], :outside, 'auto — no inside wall, window mount']
    end
    [nil, nil, 'no wall accepts a desk']
  end

  # mjpPlacement: the chosen slot if it is still a window or cable wall; else
  # the widest window/cable wall; else the widest desk-accepting wall so the
  # plate still shows. Returns [panel, why] or [nil, why].
  def self.mjp_host(panels, chosen)
    outer = panels.reject { |p| p[:inner] }
    with_w = outer.map do |p|
      xs = p[:poly].map { |q| q[0].to_f }
      ys = p[:poly].map { |q| q[1].to_f }
      [p, [xs.max - xs.min, ys.max - ys.min].max.round]
    end
    unless chosen.to_s.empty?
      hit = with_w.find { |p, _| p[:id] == chosen.to_s }
      if hit && [:window, :cbl].include?(kind_of(hit[0][:name]))
        return [hit[0], "customer's slot #{chosen}"]
      end
    end
    wdo = with_w.select { |p, _| [:window, :cbl].include?(kind_of(p[:name])) }
    return [wdo.max_by { |_, w| w }[0], 'widest window/cable wall'] unless wdo.empty?
    any = with_w.select { |p, w| desk_accepts_inside?(p[:name], w) }
    return [any.max_by { |_, w| w }[0], 'no window/cable wall — widest solid'] unless any.empty?
    [nil, 'no wall can carry the MJP']
  end

  # Which axis assignment best matches the part's expected (width, height,
  # thickness). Tries all six permutations of the measured extents against the
  # expectation and keeps the closest — the components are not authored to one
  # convention (measured across the wall library) and these parts are new
  # territory, so nothing is assumed about which authored axis is up.
  # e: [ex, ey, ez]. Returns { :wi, :hi, :ti, :err }.
  #
  # want_h MAY BE NIL, and for any part whose height is not measured it MUST
  # be. A guessed height is not a free hint: it is scored exactly like the two
  # real numbers, so it can outvote them and win a permutation that stands the
  # part on edge. That is what put the desk vertically on the wall — the
  # invented 20" height beat the measured 14" depth into the vertical slot.
  # With nil, only the measured axes are scored and the leftover axis IS the
  # vertical one, which is the fact we actually know about a wall-mounted part.
  def self.axes_for(e, want_w, want_h, want_t)
    best = nil
    [0, 1, 2].permutation.each do |wi, hi, ti|
      err = (e[wi] - want_w).abs + (e[ti] - want_t).abs
      err += (e[hi] - want_h).abs unless want_h.nil?
      best = { :wi => wi, :hi => hi, :ti => ti, :err => err } if best.nil? || err < best[:err]
    end
    best
  end

  # How far the whole booth group moves up. THE ONLY PLACE THE LIFT IS
  # COMPUTED — the SketchUp side applies exactly this, once, to the booth
  # group's transformation, so there is one function to test and one call
  # site to read. A booth without casters gets 0.0, ALWAYS: that is the
  # no-regression contract rbtest-overlays.py pins, because a lift leaking
  # into the default path silently moves every drawing Benton has.
  #
  # fl_bottom is the placed floor deck's measured bottom in booth-local
  # coordinates (DECK_TOP_Z - 1.0 nominally, so about -1.0): the lift is
  # whatever puts that underside at CP_BOOTH_LIFT above world z 0.
  def self.booth_lift(casters, fl_bottom)
    return 0.0 unless casters
    CP_BOOTH_LIFT - fl_bottom.to_f
  end

  # The CP file names to try for one floor-deck tile, best first.
  #
  # cross/along are the FLOOR part's name digits (WR_Deck catalogue fields —
  # the plate set mirrors the floor set name for name, 17 two-axis plates
  # against 17 floor arrangements, 4260/4284/4896 missing on both sides of
  # the portal). Role is POSITIONAL — ends are SIDE, middles CTR — exactly
  # the deck plan's own want; the CP set is unhanded so the L/R letter never
  # appears. The alternate role and the bare name follow as fallbacks,
  # mirroring WR_Deck.pick's byrole fallback; a fallback hit is WARNED by
  # name at the call site, and no hit at all refuses the whole plate set.
  def self.cp_candidates(cross, along, count, index)
    d = format('%g%g', cross.to_f, along.to_f)
    return ["CP#{d}"] if count < 2
    role  = (index.zero? || index == count - 1) ? 'SIDE' : 'CTR'
    other = role == 'SIDE' ? 'CTR' : 'SIDE'
    ["CP#{d} #{role}", "CP#{d} #{other}", "CP#{d}"]
  end

  # ========================================================================
  # SketchUp side — nothing below here is reachable from the offline tests.
  # ========================================================================

  # The inner wall's PHYSICAL room face stands a measured 1/16-1/8 proud of
  # its nominal band (build-booth-components' IEP_ROOM_PROUD, per family).
  # An overlay mounted on an inner host moves roomward by that stand-off so
  # it sits on the wall, not buried a sixteenth into it.
  def self.host_proud(host_name, moved)
    return 0.0 unless moved
    WR_BuildBoothComponents.iep_room_proud(host_name)
  rescue StandardError
    0.0
  end

  # Bounding box of the definition's GEOMETRY ONLY — faces, walked through
  # nested containers. A plain defn.bounds is inflated by any dimension
  # annotation fused into the export, which the portal found on the MJP art;
  # measuring faces sidesteps that without needing to find and hide the layer.
  def self.geom_extents(defn)
    boxes = []
    WR_BuildBoothComponents.collect_faces(defn.entities, Geom::Transformation.new, boxes)
    return nil if boxes.empty?
    lo = [boxes.map { |b| b[0][0] }.min, boxes.map { |b| b[1][0] }.min,
          boxes.map { |b| b[2][0] }.min]
    hi = [boxes.map { |b| b[0][1] }.max, boxes.map { |b| b[1][1] }.max,
          boxes.map { |b| b[2][1] }.max]
    { :lo => lo, :hi => hi, :e => [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]] }
  end

  # Place a wall-mounted overlay. t is a target hash from foam_targets /
  # duct_targets (plus :z_top for parts anchored by their top instead of their
  # centre). The rotation reuses build-booth-components' measured-axes
  # rotation: height axis to world up, thickness axis to the wall normal, the
  # width direction derived right-handed. face_sign is the part family's
  # FACE_ROOM constant; outward-mounted parts (the exterior desk, the outer
  # MJP box) pass room_flip = true.
  # spin180 turns the part a half turn ABOUT THE WALL NORMAL — in the plane of
  # the wall, so it stays flat on its face and only its own up/down and
  # left/right swap. That is a different move from room_flip, which sends the
  # part to the other FACE of the wall.
  #
  # It is composed into `rot` BEFORE the span arithmetic below, deliberately:
  # every offset is then measured off the part as it will finally sit, so a
  # spun part is centred and seated by exactly the same code as an unspun one
  # and cannot drift off its slot. Applying it afterwards would move the part.
  def self.wall_transform(gx, ax, t, face_sign, room_flip = false, spin180 = false)
    room = t[:room] * (room_flip ? -1.0 : 1.0)
    o = room * face_sign
    nrm = t[:naxis] == :x ? Geom::Vector3d.new(o, 0, 0) : Geom::Vector3d.new(0, o, 0)
    cls = { :hi => ax[:hi], :ti => ax[:ti], :wi => ax[:wi] }
    rot = WR_BuildBoothComponents.rotation(cls, nrm)
    if spin180
      rot = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                          nrm, 180.degrees) * rot
    end

    xs = []
    ys = []
    zs = []
    [gx[:lo], gx[:hi]].each do |px|
      [gx[:lo], gx[:hi]].each do |py|
        [gx[:lo], gx[:hi]].each do |pz|
          q = Geom::Point3d.new(px[0], py[1], pz[2]).transform(rot)
          xs << q.x.to_f
          ys << q.y.to_f
          zs << q.z.to_f
        end
      end
    end
    run_span = t[:run] == :x ? [xs.min, xs.max] : [ys.min, ys.max]
    nrm_span = t[:naxis] == :x ? [xs.min, xs.max] : [ys.min, ys.max]

    d_run = t[:run_c] - (run_span[0] + run_span[1]) / 2.0
    # The back of the part goes ON the face and the body stands proud into the
    # room (or out of the booth when room_flip): with room = +1 the part
    # occupies [face, face + depth], so its LOW edge sits on the face.
    d_nrm = room > 0 ? t[:face] - nrm_span[0] : t[:face] - nrm_span[1]
    d_z = t[:z_top] ? t[:z_top] - zs.max : t[:z_c] - (zs.min + zs.max) / 2.0

    dx = t[:run] == :x ? d_run : d_nrm
    dy = t[:run] == :x ? d_nrm : d_run
    Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, d_z)) * rot
  end

  def self.add(booth, defn, tr, name, layer)
    inst = booth.entities.add_instance(defn, tr)
    inst.name = name
    inst.layer = layer if layer
    b = inst.bounds
    format('%7.2f %7.2f %7.2f to %7.2f %7.2f %7.2f',
           b.min.x.to_f, b.min.y.to_f, b.min.z.to_f,
           b.max.x.to_f, b.max.y.to_f, b.max.z.to_f)
  end

  # Split 'Duct Cover.skp' into its two covers, once per build.
  #
  # The library file is the cover-SET export — both covers in one part, and
  # the portal measured that set's internal spacing 4 in wrong against the
  # real ports (66 vs 62.0). So: find the set's long axis; if it is long
  # enough to be the pair, cluster the top-level entities into a low and a
  # high group about the box middle and wrap each group in its own new
  # definition. Every entity keeps its own transform, so the covers are
  # untouched — only the 66 in of authored spacing between them is discarded.
  #
  # Returns { :hi => defn, :lo => defn } on a split, { :single => defn } when
  # the file turns out to hold one cover, or { :set => defn, :span => n } when
  # the file holds the pair but cannot be split (raw geometry at top level) —
  # the caller then anchors the set on the HIGH port and states the low
  # cover's error.
  def self.cover_pieces(model, defn)
    gx = geom_extents(defn)
    return { :single => defn } if gx.nil?
    v = (0..2).max_by { |i| gx[:e][i] }
    return { :single => defn } if gx[:e][v] < DUCT_PAIR_SPLIT_MIN

    mid = (gx[:lo][v] + gx[:hi][v]) / 2.0
    los = []
    his = []
    defn.entities.each do |e|
      next unless e.respond_to?(:bounds)
      next if e.is_a?(Sketchup::Text) || e.is_a?(Sketchup::Dimension)
      b = e.bounds
      c = (WR_BuildBoothComponents.coord(b.min, v) +
           WR_BuildBoothComponents.coord(b.max, v)) / 2.0
      (c < mid ? los : his) << e
    end
    splittable = !los.empty? && !his.empty? &&
                 (los + his).all? do |e|
                   e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
                 end
    unless splittable
      return { :set => defn, :span => gx[:e][v] }
    end

    wrap = lambda do |list, label|
      d = model.definitions.add("WR Duct Cover (#{label})")
      list.each do |e|
        d.entities.add_instance(e.definition, e.transformation)
      end
      d
    end
    { :hi => wrap.call(his, 'hi'), :lo => wrap.call(los, 'lo') }
  end

  # ---- the entry point -----------------------------------------------------
  #
  # Called by build-booth-components.build_booth after the walls and both
  # decks. rows are its resolved rows (post-rebalance polygons); returns
  # [placed_count, warnings]. On a dry run everything is computed and printed
  # and nothing is placed. Any exception is the CALLER's to catch — the walls
  # are already committed work and a foam bug must not take them down.
  #
  # deck is build_booth's host-bounds hash ({'FL' => BoundingBox, ...}) so
  # the caster plate can read where the placed floor's underside really is;
  # nil on a dry run and from any older caller, and only the caster branch
  # reads it.
  def self.place_all(model, booth, key, spec, cfg, rows, cache, deck = nil)
    dry = cfg['dry'] ? true : false
    hx  = cfg['hx'] ? true : false
    ov  = cfg['overlay'] || {}
    dir = cfg['dir']
    centre = [spec[:w] / 2.0, spec[:h] / 2.0]
    ph = hx ? 91.0 : 81.0
    enh = !spec[:eiw].nil?
    warns = []
    placed = 0

    panels = rows.select { |r| r[:part][:k] == 'panel' }.map do |r|
      { :id => r[:part][:id], :name => r[:name], :poly => r[:part][:poly],
        :inner => r[:part][:sh].to_s == 'in' }
    end

    tag = lambda do |nm, rgb|
      next nil if dry
      l = model.layers[nm] || model.layers.add(nm)
      (l.color = Sketchup::Color.new(*rgb)) rescue nil
      l
    end
    t_foam = tag.call('WR-Booth-Foam',    [140, 140, 145])
    t_opt  = tag.call('WR-Booth-Options', [180, 120,  60])

    getdef = lambda do |name|
      WR_BuildBoothComponents.load_def(model, dir, name, cache)
    end

    puts ''
    puts '  ---- overlays: foam, duct covers, options ' + '-' * 34
    if enh
      puts '  ENHANCED: foam and duct covers mount on the IEP inner walls (a MOVE,'
      puts '  never a copy), 2.25 in roomward of the standard interior face via the'
      puts '  inner slot band, plus the measured IEP_ROOM_PROUD stand-off.'
    end

    # ---------------------------------------------------------------- foam --
    #
    # Always ships — one sheet per qualifying panel; not a payload option.
    ft = foam_targets(panels, centre, ph)
    if ft.empty?
      puts '  FOAM: no qualifying 40/46 in SOLID/VNT/CBL/NV panels on this booth.'
    else
      fd = getdef.call('Foam')
      if fd.nil?
        warns << "Foam.skp not found in #{dir} — NO foam was placed (#{ft.length} sheets wanted)"
      else
        gx = geom_extents(fd)
        if gx.nil?
          warns << 'Foam.skp holds no measurable faces — NO foam was placed'
        else
          ax = axes_for(gx[:e], FOAM_W, FOAM_H, FOAM_T)
          puts format('  FOAM  measures %.2f x %.2f x %.2f (w x h x t, matched err %.2f)' \
                      ' — one sheet per panel, centred, %s face',
                      gx[:e][ax[:wi]], gx[:e][ax[:hi]], gx[:e][ax[:ti]], ax[:err],
                      enh ? 'IEP room' : 'interior')
          warns << format('Foam.skp measures %.2f in on its matched height axis — not the ' \
                          'nominal 48. Placement centres the measured box; check one sheet.',
                          gx[:e][ax[:hi]]) if (gx[:e][ax[:hi]] - FOAM_H).abs > 2.0
          ft.each do |t|
            t2 = t.merge(:face => t[:face] + t[:room] * host_proud(t[:host_name], t[:moved]))
            if dry
              puts format('    %-6s -> %-8s run centre %7.2f  face %7.2f  z centre %5.1f%s',
                          t[:id], t[:host_id], t[:run_c], t2[:face], t[:z_c],
                          t[:moved] ? '  (IEP)' : '')
              next
            end
            tr = wall_transform(gx, ax, t2, FACE_ROOM[:foam])
            at = add(booth, fd, tr, "Foam  #{t[:host_id]}", t_foam)
            placed += 1
            puts format('    %-6s -> %-8s %s%s', t[:id], t[:host_id], at,
                        t[:moved] ? '  (IEP)' : '')
          end
        end
      end
    end
    color = ov['foam_color'].to_s
    unless color.empty? || color.casecmp('Gray').zero?
      puts "  FOAM colour '#{color}' from the link is REPORT-ONLY: Foam.skp has no" \
           ' colour variants (the portal re-tints one geometry). Not applied.'
    end

    # --------------------------------------------------------- duct covers --
    #
    # Always ship on vent walls — except on an HX booth, where they do not
    # ship at all (product fact; foam is unaffected).
    dt = duct_targets(panels, centre, hx)
    if hx
      puts '  DUCT COVERS: none — the 10 in height-extension panels do not ship'
      puts '  with the hinge duct covers (product fact, Benton via the portal source).'
    elsif dt.empty?
      puts '  DUCT COVERS: no qualifying 40/46 in vent walls on this booth.'
    else
      dd = getdef.call('Duct Cover')
      if dd.nil?
        warns << "Duct Cover.skp not found in #{dir} — NO duct covers were placed " \
                 "(#{dt.length} wanted)"
      else
        pieces = dry ? nil : cover_pieces(model, dd)
        if !dry && pieces[:set]
          warns << format('Duct Cover.skp is the two-cover SET (%.1f in long) and could ' \
                          'not be split — raw geometry at top level. Each pair was placed ' \
                          'as the set, anchored on its HIGH port; the LOW cover is off by ' \
                          'the set spacing minus 62.0 in. Split the .skp into two ' \
                          'components to fix this properly.', pieces[:span])
        end
        puts "  DUCT COVERS  hi/lo pair per vent wall, each centred on its measured port#{dry ? ' (dry)' : ''}"
        # Group the targets back into hi/lo pairs per wall for the set fallback.
        dt.group_by { |t| t[:id] }.each do |_slot, pair|
          pair.each do |t|
            t2 = t.merge(:face => t[:face] + t[:room] * host_proud(t[:host_name], t[:moved]))
            if dry
              puts format('    %-6s %-3s -> %-8s run centre %7.2f  face %7.2f  z %6.2f%s',
                          t[:id], t[:pos], t[:host_id], t[:run_c], t2[:face], t[:z_c],
                          t[:moved] ? '  (IEP)' : '')
              next
            end
            if pieces[:set]
              # Whole set once per wall, anchored on the HIGH port; skip the
              # low target so the set is not placed twice.
              next unless t[:pos] == :hi
              gx = geom_extents(pieces[:set])
              ax = axes_for(gx[:e], DUCT_COVER_W, pieces[:span], DUCT_COVER_T)
              # Anchor: the set's TOP cover centre on the high port. The top
              # cover is ~14.76 tall at the set's top end, so its centre sits
              # half a cover below the set top.
              t3 = t2.merge(:z_c => nil, :z_top => t[:z_c] + DUCT_COVER_H / 2.0)
              tr = wall_transform(gx, ax, t3, FACE_ROOM[:duct])
              at = add(booth, pieces[:set], tr, "Duct Cover set  #{t[:host_id]}", t_opt)
              placed += 1
              puts format('    %-6s SET -> %-8s %s   (LOW COVER IS OFF — see warning)',
                          t[:id], t[:host_id], at)
            else
              d1 = pieces[t[:pos]] || pieces[:single]
              gx = geom_extents(d1)
              ax = axes_for(gx[:e], DUCT_COVER_W, DUCT_COVER_H, DUCT_COVER_T)
              tr = wall_transform(gx, ax, t2, FACE_ROOM[:duct])
              at = add(booth, d1, tr, "Duct Cover #{t[:pos]}  #{t[:host_id]}", t_opt)
              placed += 1
              puts format('    %-6s %-3s -> %-8s %s%s', t[:id], t[:pos], t[:host_id], at,
                          t[:moved] ? '  (IEP)' : '')
            end
          end
        end
        # The portal's layering rule (Benton): foam sits IN FRONT of the duct
        # covers where they overlap. In 3D both stand off the same wall face,
        # so on a vent wall the 2 in sheet and the 3.14 in covers interpenetrate
        # — exactly the simplification the portal's flat views also make. Say
        # it so nobody reads the overlap as a placement bug.
        puts '    (foam overlaps the covers on a vent wall — the portal layers them' \
             ' flat; the interpenetration is the known simplification)'
      end
    end

    # ----------------------------------------------------------------- desk --
    if ov['desk']
      large = ov['desk_large'] ? true : false
      dk = large ? DESK_LARGE : DESK_SMALL
      host, mode, why = desk_host(panels, ov['desk_slot'], large, ov['desk_outside'])
      if host.nil?
        warns << "DESK requested but #{why} — NOT placed"
      elsif large && ov['desk_outside']
        warns << 'DESK: the large desk is interior-only (portal rule); dox=1 ignored, ' \
                 'mounted inside'
        mode = :inside
      end
      unless host.nil?
        dd = getdef.call(dk[:file])
        if dd.nil?
          warns << "#{dk[:file]}.skp not found in #{dir} — desk NOT placed"
        else
          fr0 = slot_frame(host[:poly], centre)
          hf = mode == :inside ? host_frame(panels, host, centre) : slot_frame(host[:poly], centre)
          gx = geom_extents(dd)
          # Height is NOT guessed. The desk's two measured numbers — width
          # along the wall and depth out from it — pick the axes; whatever is
          # left over is vertical. Passing an invented height here is what
          # stood the work surface up on edge against the wall.
          #
          # DeskSmall.skp MEASURES 30.00 x 12.18 x 14.75 (Benton's build log,
          # 1 Sep 2026) — so the part IS authored lying down; it was only ever
          # placed wrong. The old guessed 20" height scored |14.75-20| = 5.25
          # against |12.18-20| = 7.82 and so chose the 14.75 DEPTH as the
          # vertical axis, leaving 12.18 as the depth. Dropping the guess
          # scores only the real numbers and the part lands 30 wide, 14.75
          # deep, 12.18 tall. Benton, on the rebuild: "desk looks good now".
          ax = axes_for(gx[:e], dk[:w], nil, dk[:d])
          z_top = DESK_SURFACE_Z + (DESK_TOP_IS_STRIP ? DESK_STRIP_PROUD : 0.0)
          t = { :run => fr0[:run], :naxis => fr0[:naxis],
                :run_c => (fr0[:r0] + fr0[:r1]) / 2.0,
                :room => fr0[:room], :z_c => nil, :z_top => z_top }
          if mode == :inside
            t[:face] = hf[:face] + hf[:room] * host_proud(hf[:host_name], hf[:moved])
            t[:room] = hf[:room]
          else
            # Outside a window: back flush to the OUTER wall face, extending
            # 14 in outward (claims 14 in of exterior clearance on that side).
            xs = host[:poly].map { |q| q[0].to_f }
            ys = host[:poly].map { |q| q[1].to_f }
            t[:face] = if fr0[:naxis] == :x
                         fr0[:room] > 0 ? xs.min : xs.max
                       else
                         fr0[:room] > 0 ? ys.min : ys.max
                       end
          end
          puts format('  DESK  %s (%s) on %s — %s; measures %.2f x %.2f x %.2f, ' \
                      'surface %.1f (top anchored at %.2f%s)',
                      large ? 'large 42x17' : 'small 30x14', mode, host[:id], why,
                      gx[:e][ax[:wi]], gx[:e][ax[:hi]], gx[:e][ax[:ti]],
                      DESK_SURFACE_Z, z_top,
                      DESK_TOP_IS_STRIP ? ', strip assumed tallest' : '')
          if dry
            puts format('    would place at run centre %.2f, face %.2f', t[:run_c], t[:face])
          else
            tr = wall_transform(gx, ax, t, FACE_ROOM[:desk], mode == :outside)
            at = add(booth, dd, tr, "Desk #{large ? 'large' : 'small'}  #{host[:id]}", t_opt)
            placed += 1
            puts "    #{at}"
          end
          if enh && mode == :inside
            puts '    (Enhanced: mounted on the IEP room face — the portal is split on'
            puts '     this and Benton has not ruled; see the researcher handoff, open q 1)'
          end
        end
      end
    end

    # ------------------------------------------------------------------ MJP --
    if ov['mjp']
      host, why = mjp_host(panels, ov['mjp_slot'])
      if host.nil?
        warns << "MJP requested but #{why} — NOT placed"
      else
        md = getdef.call('MJP')
        if md.nil?
          warns << "MJP.skp not found in #{dir} — MJP NOT placed"
        else
          gx = geom_extents(md)
          ax = axes_for(gx[:e], MJP_W, 8.0, MJP_T)
          fr0 = slot_frame(host[:poly], centre)
          hf = host_frame(panels, host, centre)
          run_c = (fr0[:r0] + fr0[:r1]) / 2.0
          puts format('  MJP ("Multi jack panel") on %s — %s; measures %.2f x %.2f x %.2f, ' \
                      'plate centre %.2f (box top anchored at %.2f — tails hang below)',
                      host[:id], why, gx[:e][ax[:wi]], gx[:e][ax[:hi]], gx[:e][ax[:ti]],
                      27.25, MJP_TOP_Z)
          # A pass-through: the interior box on the room face (IEP face on
          # Enhanced), and the exterior box — the same part turned 180 in plan,
          # Benton's own description — on the standard OUTER face. On Enhanced
          # the passage crosses both shells; the portal never models that and
          # neither does this.
          inner_t = { :run => hf[:run], :naxis => hf[:naxis], :run_c => run_c,
                      :face => hf[:face] + hf[:room] * host_proud(hf[:host_name], hf[:moved]),
                      :room => hf[:room], :z_c => nil, :z_top => MJP_TOP_Z }
          xs = host[:poly].map { |q| q[0].to_f }
          ys = host[:poly].map { |q| q[1].to_f }
          outer_face = if fr0[:naxis] == :x
                         fr0[:room] > 0 ? xs.min : xs.max
                       else
                         fr0[:room] > 0 ? ys.min : ys.max
                       end
          outer_t = { :run => fr0[:run], :naxis => fr0[:naxis], :run_c => run_c,
                      :face => outer_face, :room => fr0[:room],
                      :z_c => nil, :z_top => MJP_TOP_Z }
          if dry
            puts format('    would place both boxes at run centre %.2f — interior face ' \
                        '%.2f, exterior face %.2f', run_c, inner_t[:face], outer_face)
          else
            tri = wall_transform(gx, ax, inner_t, FACE_ROOM[:mjp], false, MJP_SPIN180)
            placed += 1
            puts '    interior  ' + add(booth, md, tri, "MJP interior  #{hf[:host_id]}", t_opt)
            tro = wall_transform(gx, ax, outer_t, FACE_ROOM[:mjp], true, MJP_SPIN180)
            placed += 1
            puts '    exterior  ' + add(booth, md, tro, "MJP exterior  #{host[:id]}", t_opt)
          end
        end
      end
    end

    # ------------------------------------------------------------------ EFP --
    if ov['efp']
      digits = key[/MDL\s+(\d+)/, 1].to_s
      src = ov['efp_from_ada'] ? 'ADA bundle (ad)' : 'elevated floor (ep)'
      # THE 96192 REFUSAL IS GONE, 2026-08-30. It used to sit HERE, ahead of
      # the EFP_SIZES test, so it fired unconditionally. Its reason was true
      # when it was written: EFP96192.skp did not exist, and EFP96196.skp
      # matched no catalogue size - almost certainly the same file misnamed.
      # Benton renamed it. EFP96192.skp is now on the share (426,135 bytes,
      # observed 30 Aug 2026) and 96192 was already in EFP_SIZES, so this
      # branch had become a refusal of a part that builds.
      #
      # NOTHING REPLACES IT, deliberately. A missing .skp is already refused
      # by name three lines down by `ed.nil?`, which prints the filename and
      # the directory - so a future rename, or the share being offline,
      # still fails loudly rather than placing nothing quietly. That general
      # guard is what this special case was standing in for.
      if !EFP_SIZES.include?(digits)
        warns << "EFP requested (#{src}) but the portal sells no EFP for a #{digits} " \
                 "(sold sizes: #{EFP_SIZES.join(', ')}) — NOT placed"
      else
        ed = getdef.call("EFP#{digits}")
        if ed.nil?
          warns << "EFP#{digits}.skp not found in #{dir} — elevated floor NOT placed"
        else
          n2 = place_efp(model, booth, ed, spec, digits, dry, t_opt, warns)
          placed += n2
          if enh
            puts '    (Enhanced: centred = pressed to the IEP walls to within a quarter' \
                 ' inch — the art is cut for the Enhanced room)'
          else
            warns << 'EFP on a STANDARD booth leaves ~2-2.4 in of carpet showing per ' \
                     'side. The PERIMETER STRIPS that fill it are a real product part ' \
                     'with NO component and NO art — Benton must author them. Not faked.'
          end
        end
      end
    end

    # ------------------------------------------ roof-mounted ventilation --
    #
    # BEFORE the caster plate, so the booth lift (which is applied once to the
    # group's own transformation) carries the roof unit up with everything
    # else. Placed only when wr-roof-vent has NO blockers left — an HX booth
    # or a model with no part is refused there, by name, and nothing is drawn.
    if ov['roof_vent']
      placed += place_roof_unit(model, booth, key, spec, cfg, cache, t_opt, warns)
    end

    # --------------------------------------- caster plate + the booth lift --
    if ov['casters_plate']
      placed += place_casters(model, booth, key, spec, cfg, cache,
                              deck && deck['FL'], warns)
    end

    # -------------------------------------------- named refusals, not silent --
    if ov['step']
      warns << 'STEP (sp) not built: the caster plate it pairs with now builds, ' \
               'but the step itself still lacks a ruling on its lateral anchor ' \
               'and tread face — the portal gives only "12 in deep in front of ' \
               'the door" (art 44.03 x 12.08). StepFront.skp exists; see the ' \
               'wr-overlays.rb header before building it.'
    end

    puts '  ---- overlays end ' + '-' * 58
    [placed, warns]
  end

  # ---- the roof unit of a roof-mounted (rv = 1) booth ---------------------
  #
  # RM<model>.skp is the complete roof assembly — both boxes, every duct — and
  # needs seating, not assembling (Benton, 31 Aug 2026). So this is a pure
  # translation: the part is authored the right way up and with its width on x
  # and its depth on y, matching the booth (observed on all 44 files by
  # .forge/builder/roof-vent/measure-rm.py).
  #
  # PLAN comes from WR_RoofVent.seat, which is the only place the rule lives.
  #
  # Z IS MEASURED, NOT ASSUMED, and that is the whole of the HX handling.
  # Benton, 31 Aug 2026: "These RM components just sit on the ceiling. Albeit,
  # 10 in higher since the roof is 10 in higher." So the unit sits on whatever
  # the booth's roof actually came out at — the highest thing in the booth
  # group, in booth-local coordinates — and a Standard, an Enhanced and a
  # height-extended booth all seat correctly with no per-case constant and no
  # `+ 10 if hx` branch. The 10 is already in the geometry: an HX booth is
  # built from 91 in panels instead of 81 (build-booth-components). The panel
  # top is printed alongside the measured roof so the two can be compared.
  def self.place_roof_unit(model, booth, key, spec, cfg, cache, layer, warns)
    dry = cfg['dry'] ? true : false
    ov  = cfg['overlay'] || {}
    vss = ov['roof_vss'] ? true : false
    efs = ov['roof_efs'] ? true : false

    puts ''
    puts '  ---- roof-mounted ventilation: the roof unit ' + '-' * 31

    blockers = WR_RoofVent.roof_unit_blockers(key, spec[:eiw] ? 'E' : 'S',
                                              cfg['hx'] ? true : false, efs, vss)
    unless blockers.empty?
      blockers.each do |b|
        puts "    ROOF UNIT NOT PLACED — #{b}"
        warns << "roof unit NOT placed: #{b}"
      end
      return 0
    end

    name = WR_RoofVent.part_name(key, vss)
    defn = WR_BuildBoothComponents.load_def(model, cfg['dir'], name, cache)
    if defn.nil?
      warns << "#{name}.skp not found in #{cfg['dir']} — roof unit NOT placed"
      puts "    ROOF UNIT NOT PLACED — #{name}.skp is not in #{cfg['dir']}"
      return 0
    end
    gx = geom_extents(defn)
    if gx.nil?
      warns << "#{name}.skp holds no measurable faces — roof unit NOT placed"
      puts "    ROOF UNIT NOT PLACED — #{name}.skp holds no measurable faces"
      return 0
    end

    # Cross-check the live part against the table wr-roof-vent reports its
    # ceiling figure from. A silent disagreement here would mean the ceiling
    # requirement printed on the drawing is not the part standing in it.
    row = WR_RoofVent::MEASURED[WR_RoofVent.digits(key)]
    want = row && row[vss ? :vss : :flat]
    if want && (0..2).any? { |i| (gx[:e][i] - want[i]).abs > 0.01 }
      warns << format('%s.skp measures %.3f x %.3f x %.4f live, where MEASURED ' \
                      'in wr-roof-vent.rb says %.3f x %.3f x %.4f. The part was ' \
                      're-exported or the table is stale — re-run measure-rm.py. ' \
                      'Seated off the LIVE measurement.',
                      name, gx[:e][0], gx[:e][1], gx[:e][2], *want)
    end

    seat = WR_RoofVent.seat(key, spec[:w], spec[:h], gx[:e][0], gx[:e][1])
    if seat[:error]
      warns << "roof unit NOT placed: #{seat[:error]}"
      puts "    ROOF UNIT NOT PLACED — #{seat[:error]}"
      return 0
    end

    # The roof, measured. Children of a group report bounds in the group's own
    # coordinates, which is exactly the frame seat[:x] / seat[:y] are in.
    roof_z = nil
    booth.entities.each do |e|
      z = (e.bounds.max.z.to_f rescue nil)
      roof_z = z if z && (roof_z.nil? || z > roof_z)
    end
    if roof_z.nil?
      warns << 'the booth group is empty, so there is no measured roof to ' \
               'seat the roof unit on — NOT placed'
      puts '    ROOF UNIT NOT PLACED — nothing in the booth group to measure a roof from'
      return 0
    end
    nominal_roof = WR_Deck::DECK_TOP_Z + (cfg['hx'] ? 91.0 : 81.0)
    puts format('    roof measured at booth-local z %.4f (panel tops are at ' \
                '%.2f; the ceiling slab sits above them)', roof_z, nominal_roof)

    puts format('    %-12s %.3f x %.3f x %.4f in', name, *gx[:e])
    puts format('    %s: %.1f x %.1f nominal footprint, left %.3f / right ' \
                '%.3f, front %.3f / back %.3f',
                seat[:rule], spec[:w] - 2.0 * WR_RoofVent::NOMINAL_INSET,
                spec[:h] - 2.0 * WR_RoofVent::NOMINAL_INSET,
                seat[:left], seat[:right], seat[:front], seat[:back])
    WR_RoofVent.seating_note(key, vss, efs).each { |l| puts "    #{l}" }
    return 0 if dry

    tr = Geom::Transformation.translation(
      Geom::Vector3d.new(seat[:x] - gx[:lo][0],
                         seat[:y] - gx[:lo][1],
                         roof_z  - gx[:lo][2]))
    at = add(booth, defn, tr, "#{name} roof unit", layer)
    puts "    #{at}"
    1
  end

  # Lay the EFP slab flat, centred in plan, bottom on the carpet floor.
  #
  # z: WR_Deck::DECK_TOP_Z — the plane the walls stand on IS the floor deck's
  # top in booth coordinates (wr-deck.rb fact 3), so the slab's bottom goes
  # there. Plan: centred on the booth centre, the portal's own (admitted
  # authored-not-measured) rule; the part's slab-thickness axis is found by
  # measurement and stood vertical, and the footprint takes the quarter turn
  # that better matches the interior aspect.
  def self.place_efp(model, booth, defn, spec, digits, dry, layer, warns)
    gx = geom_extents(defn)
    if gx.nil?
      warns << "EFP#{digits}.skp holds no measurable faces — NOT placed"
      return 0
    end
    v = (0..2).min_by { |i| gx[:e][i] }
    if gx[:e][v] < EFP_T_MIN || gx[:e][v] > EFP_T_MAX
      warns << format('EFP%s: thinnest axis measures %.2f in where the slab family runs ' \
                      '2.83-2.89 — placed anyway on that axis, CHECK IT', digits, gx[:e][v])
    end

    # Stand the thin axis up: rotate about whichever horizontal axis brings it
    # to Z (nothing to do when it already is Z).
    rot = case v
          when 0 then Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                                    Geom::Vector3d.new(0, 1, 0), 90.degrees)
          when 1 then Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                                    Geom::Vector3d.new(1, 0, 0), 90.degrees)
          else Geom::Transformation.new
          end
    span = lambda do |tr|
      xs = []
      ys = []
      zs = []
      [gx[:lo], gx[:hi]].each do |px|
        [gx[:lo], gx[:hi]].each do |py|
          [gx[:lo], gx[:hi]].each do |pz|
            q = Geom::Point3d.new(px[0], py[1], pz[2]).transform(tr)
            xs << q.x.to_f
            ys << q.y.to_f
            zs << q.z.to_f
          end
        end
      end
      [[xs.min, xs.max], [ys.min, ys.max], [zs.min, zs.max]]
    end
    sp = span.call(rot)
    # Quarter-turn if the footprint fits the interior better the other way.
    iw = (spec[:eiw] || spec[:iw]).to_f
    ih = (spec[:eih] || spec[:ih]).to_f
    as_is  = ((sp[0][1] - sp[0][0]) - iw).abs + ((sp[1][1] - sp[1][0]) - ih).abs
    turned = ((sp[1][1] - sp[1][0]) - iw).abs + ((sp[0][1] - sp[0][0]) - ih).abs
    if turned < as_is - 0.001
      rot = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                          Geom::Vector3d.new(0, 0, 1), 90.degrees) * rot
      sp = span.call(rot)
    end

    cx = spec[:w] / 2.0
    cy = spec[:h] / 2.0
    z0 = WR_Deck::DECK_TOP_Z
    tr = Geom::Transformation.translation(
      Geom::Vector3d.new(cx - (sp[0][0] + sp[0][1]) / 2.0,
                         cy - (sp[1][0] + sp[1][1]) / 2.0,
                         z0 - sp[2][0])) * rot
    puts format('  EFP%s  slab %.2f x %.2f x %.2f, centred in plan, bottom at z %.2f',
                digits, sp[0][1] - sp[0][0], sp[1][1] - sp[1][0],
                sp[2][1] - sp[2][0], z0)
    return 0 if dry
    at = add(booth, defn, tr, "EFP#{digits} elevated floor", layer)
    puts "    #{at}"
    1
  end

  # ---- the caster plate, and the one place the booth is lifted -------------
  #
  # One CP plate per floor-deck tile — the SAME plan the floor was laid from
  # (WR_Deck.plan on the same catalogue), so the plate set tiles one-for-one
  # with the deck by construction, which is the portal's own rule (gen-iso-
  # placeholders.js CP block builds the cp tiles from the floor sections).
  # Each plate is authored with its lap to the published exterior already in
  # the geometry (SIDE along+1 x cross+2, CTR +0/+2, single +2/+2 — measured,
  # _face-levels.tsv), so a tile is seated exactly the way the IEP ceiling
  # tray is: outer along edge to the outer end, cross centred, and the lap
  # falls outward on its own.
  #
  # VERTICAL: plate bottoms on the ground plane (world z 0) and the WHOLE
  # BOOTH GROUP lifted by booth_lift(...) in ONE transform, applied here and
  # nowhere else — walls, decks, door, overlays all ride it, so no per-part
  # z can drift. Everything printed before the lift line is in pre-lift
  # booth-local coordinates (which stay the group's local frame afterwards).
  #
  # fl_bounds: the placed standard floor's union bounds, or nil on a dry run.
  # Returns the number of plates placed; refusals return 0, warn BY NAME, and
  # leave the booth UNLIFTED — a lifted booth over a missing plate is a
  # floating booth.
  def self.place_casters(model, booth, key, spec, cfg, cache, fl_bounds, warns)
    dir = cfg['dir']
    dry = cfg['dry'] ? true : false

    cat = WR_Deck.catalogue(dir)
    tiles, note = WR_Deck.plan(spec, cat, 'FL')
    if tiles.nil?
      warns << 'CASTER PLATE REFUSED BY NAME: the plate set tiles one-for-one ' \
               "with the floor deck and the floor cannot be planned — #{note}. " \
               'No plate was placed and the booth was NOT lifted.'
      return 0
    end
    if !dry && fl_bounds.nil?
      warns << 'CASTER PLATE REFUSED BY NAME: no standard floor deck was placed, ' \
               'so there is nothing to seat the booth into the tray by. No plate ' \
               'was placed and the booth was NOT lifted.'
      return 0
    end

    # Resolve EVERY plate before touching the model: a half-lifted booth over
    # half a plate set is worse than a named refusal.
    plates = []
    gone = []
    subs = []
    tiles.each_with_index do |t, i|
      cands = cp_candidates(t[:part][:cross], t[:part][:along], tiles.length, i)
      defn = nil
      used = nil
      cands.each do |n|
        defn = WR_BuildBoothComponents.load_def(model, dir, n, cache)
        if defn
          used = n
          break
        end
      end
      if defn.nil?
        gone << "#{cands.first}.skp"
      else
        subs << "#{cands.first} -> #{used}" if used != cands.first
        plates << [t, used, defn]
      end
    end
    unless gone.empty?
      warns << "CASTER PLATE REFUSED BY NAME: #{gone.uniq.join(', ')} not in " \
               "#{dir} (the portal's manifest is missing the same sizes on the " \
               '4260/4284/4896). No plate was placed and the booth was NOT lifted.'
      return 0
    end
    subs.each do |s|
      warns << "caster plate role fallback: #{s} — the positional role does not " \
               'exist at that size, the other one went in. Check the joint.'
    end

    # The measured floor underside; nominal on a dry run, and said so.
    fl_bottom = fl_bounds ? fl_bounds.min.z.to_f : WR_Deck::DECK_TOP_Z - 1.0
    lift = booth_lift(true, fl_bottom)
    z_bot = fl_bottom - CP_BOOTH_LIFT
    puts format('  CASTER PLATE  %s — plate bottoms at ground (booth-local %.4f), ' \
                'floor underside %.4f%s',
                note, z_bot, fl_bottom, fl_bounds ? '' : ' (NOMINAL — dry run)')
    puts format('    datum from Benton, 2026-08-27: net lift %.2f, tray %.2f, ' \
                'plate %.2f (= lift + tray). The portal\'s 5 in is marketing.',
                CP_BOOTH_LIFT, CP_TRAY_DEPTH, CP_PLATE_HEIGHT)

    t_cast = nil
    unless dry
      t_cast = model.layers['WR-Booth-Casters'] || model.layers.add('WR-Booth-Casters')
      (t_cast.color = Sketchup::Color.new(60, 60, 66)) rescue nil
    end

    placed = 0
    plates.each_with_index do |(t, name, defn), i|
      rx, ry, rw, rh = WR_BuildBoothComponents.tile_rect(t)
      # Same seating the IEP ceiling tray uses, for the same authored lap:
      # outer along edge on the outer end, cross centred (the +2 splits 1/1).
      seat_along = if tiles.length < 2 then :centre
                   elsif t[:at_low_end] then :max
                   elsif i == tiles.length - 1 then :min
                   else :centre
                   end
      seat_x, seat_y = t[:along_is_x] ? [seat_along, :centre] : [:centre, seat_along]
      # The plates are unhanded, so the turn is the deck's POSITIONAL fallback
      # (low end as authored, everything else end for end). The portal notes
      # the mating (lipless, pocketed) edge must land at the joint; no probe
      # can confirm which authored end that is from here, so the turn is
      # printed per plate and Benton's eye is the instrument, as it was for
      # every other orientation in this builder.
      half = tiles.length > 1 && !t[:at_low_end]

      bb = defn.bounds
      h = (bb.max.z - bb.min.z).to_f
      if (h - CP_PLATE_HEIGHT).abs > 0.05
        warns << format('%s measures %.4f bottom-to-rim where Benton\'s stack ' \
                        'says %.2f (%.2f lift + %.2f tray). The plate bottom ' \
                        'stays on the ground and the BOOTH holds the %.2f ' \
                        'datum, so the difference (%.4f) is a gap hidden ' \
                        'inside the tray, not a datum change.',
                        name, h, CP_PLATE_HEIGHT, CP_BOOTH_LIFT, CP_TRAY_DEPTH,
                        CP_BOOTH_LIFT, CP_PLATE_HEIGHT - h)
      end
      # The tray depth, off the part's own flat faces: a face CP_TRAY_DEPTH
      # below the rim is the tray floor. Every delivered plate carries it at
      # 0.7500 exactly (checked offline, all 17); this re-checks the live part
      # so a re-export cannot silently change the stack.
      tally = begin
                WR_Deck.flat_levels(defn)
              rescue StandardError
                {}
              end
      unless tally.empty?
        top = tally.keys.max
        tray = tally.keys.find { |z| ((top - z) - CP_TRAY_DEPTH).abs <= 0.02 }
        if tray.nil?
          warns << format('%s carries NO face %.2f below its rim — its authored ' \
                          'tray depth is not the %.2f Benton gave. CHECK IT.',
                          name, CP_TRAY_DEPTH, CP_TRAY_DEPTH)
        end
      end

      if dry
        puts format('    %-14s at %6.2f  rect %.2f,%.2f %.2fx%.2f  seat %s%s  h %.3f',
                    name, t[:at].to_f, rx, ry, rw, rh, seat_along.to_s,
                    half ? '  turned' : '', h)
        next
      end
      tr, tnote = WR_BuildBoothComponents.flat_placement(defn, rx, ry, rw, rh,
                                                         false, half, :bottom,
                                                         z_bot, seat_x, seat_y)
      if tr.nil?
        warns << "#{name}: #{tnote} — this plate was NOT placed. The booth was " \
                 'still lifted (the rest of the set is in); the gap is visible.'
        next
      end
      at = add(booth, defn, tr, "#{name}  caster plate", t_cast)
      placed += 1
      puts format('    %-14s %s%s', name, at, half ? '   (turned)' : '')
    end

    if dry
      puts format('    would lift the whole booth %.4f (booth_lift) — nothing moved on a dry run', lift)
      return 0
    end

    # THE LIFT, applied exactly once, to the group. Instances added to the
    # group above are in booth-local coordinates and ride along; every bounds
    # printed before this line is pre-lift.
    booth.transformation = Geom::Transformation.translation(
      Geom::Vector3d.new(0, 0, lift)) * booth.transformation
    puts format('    BOOTH LIFTED %.4f — floor underside now %.2f above the ' \
                'ground plane (Benton\'s figure; every bounds printed above ' \
                'is pre-lift, booth-local).', lift, CP_BOOTH_LIFT)
    placed
  end
end
