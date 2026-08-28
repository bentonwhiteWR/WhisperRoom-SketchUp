# @title Drop Interior Lights
# @cat V-Ray renders
# @rank 3
#
# wr-drop-lights.rb — a layered showroom lighting rig for each selected room.
#
#   Select the room groups (or a booth), press the button, answer one small
#   pop-up (Density / Brightness / Warmth / Layers / exposure), get:
#
#     A. an AMBIENT DOWNLIGHT GRID over the real WR-Floor polygon — spacing =
#        ceiling height (Soft) or height/2 (Showroom grid), centred so the
#        wall gap is half a spacing, culled where a booth or the floor edge
#        is in the way. L-shaped rooms need no special case: the polygon
#        inside/edge-distance tests ARE the L handling.
#     B. a WALL-WASH row on the wall opposite the largest door, 24" off the
#        wall — vertical light is what the camera sees, and washed walls are
#        why showrooms photograph as designed.
#     C. when a booth stands in the room: one INTERIOR light under its tray
#        ceiling, and one ACCENT light tilted 35 degrees at its door face —
#        the merchandise layer.
#
#   Design source: .forge/researcher/interior-lighting-design.md — every
#   spacing, standoff, footcandle and Kelvin number below traces there.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb"
#
# ===========================================================================
# EVERY LIGHT IS MADE BY THE V-RAY LIGHT API — THE SEEDS ARE GONE
#
# SUPERSEDED, and the correction matters: every version of this file up to
# 1.7.9 said "the documented V-Ray Ruby API has NO light class" and placed
# copies of hand-authored seed .skp files. That statement was true of the
# older doc set and is FALSE of the V-Ray installed here. The docs generated
# 29 Apr 2026, under the V-Ray for SketchUp extension's documentation folder,
# document VRay::Command.create_rectangle_light / _sphere_ / _spot_ /
# _omni_ / _ies_ / _mesh_ / _dome_light (observed — read out of
# VRay/Command.html). The seed architecture is retired for two reasons,
# both observed live by Benton in SketchUp 2026 on 2026-08-28:
#
#   * SEED-COPIED LIGHTS DO NOT EMIT. Outlines appear, the V-Ray settings
#     look right, the render is unlit — even copying from a light that
#     works. That is the bug that triggered this rebuild.
#   * AN API-CREATED LIGHT DOES EMIT. Room lit, soft shadow under the
#     fixture, floor gradient, in the V-Ray frame buffer.
#
# And the architectural win: create_rectangle_light returns a light with
# its OWN V-Ray plugin, so brightness and colour are set PER LIGHT, in
# code. Under the seed architecture every copy shared ONE V-Ray asset —
# which is why the dialog's Brightness/Warmth answers wrote nothing and
# why one Asset Editor slider silently retuned every light in the model.
#
# The three seed files under scripts/vray-seeds/ are now DEAD CODE on
# disk. Nothing in this repo loads them. They are left in place rather
# than deleted so that a machine mid-upgrade cannot break; delete them
# once every install is past 1.8.0.
#
# ===========================================================================
# THE API, AS OBSERVED — nothing here is guessed
#
#   o = VRay::Command.create_rectangle_light(context: VRay::Context.active,
#                                            width: 24.0, height: 48.0)
#   o.entity  => Sketchup::ComponentDefinition   (NOT placed — we place it)
#   o.plugin  => VRay::Scene::Plugin             (this light's OWN params)
#
# width / height are INCHES and land on the plugin as u_size / v_size
# (observed: 24.0 / 48.0 gave u_size 24, v_size 48). The call places no
# instance — model.entities.add_instance(o.entity, tr) still does that.
#
# Plugin parameters are read and written with p[:key] / p[:key] = value
# (documented, VRay/Scene/Plugin.html; there is no parameters/params/to_h).
# A colour is written as VRay::Color.new(r, g, b) — that exact form is the
# doc page's own example. What this tool writes per light:
#
#   invisible   true    REQUIRED. Benton's test render drew the emitter as
#                       a visible white slab on the ceiling (observed). A
#                       visible emitter in a client render is unacceptable.
#   intensity   scalar  see the UNITS section below
#   units       0       V-Ray's default. See below — this is deliberate.
#   color       VRay::Color from the Warmth answer via kelvin_rgb.
#   u/v_size    set by the create call; read back and reported.
#   directional 0.5     accent layer only.
#
# EVERY write is followed by a READ-BACK and compared (param_agrees?). A
# write that does not stick is named on the console, never assumed.
#
# There is NO temperature or colour-mode parameter on this light (observed
# in the full default dump), so Warmth is a Kelvin -> RGB conversion this
# file performs itself — kelvin_rgb, sourced in its own comment.
#
# ===========================================================================
# UNITS — WHY THIS TOOL STAYS ON THE SCALAR AND SAYS SO
#
# The rectangle light's `units` parameter defaults to 0. The enum is
# commonly documented elsewhere as 0=default/scalar, 1=lumens, 2=lm/m2/sr,
# 3=watts, 4=W/m2/sr — REPORTED, and NOT confirmed on this build: the
# installed doc set documents no units enum at all (grepped 2026-08-28;
# VRay/Command.html is the only light page and it carries none).
#
# Shipping a guessed enum would silently make every light the wrong
# brightness, so units STAYS 0 and intensity is tuned as a scalar. The
# console prints the units value and the intensity actually set for every
# layer, so a wrong guess is visible immediately instead of silent.
#
# The scalar is anchored to the one observed-good data point: V-Ray's own
# default rectangle light, 24" x 48" at intensity 30, is the light Benton
# rendered and found correctly lit. So:
#
#   intensity = REF_INTENSITY * (target_lm / REF_LUMENS) * (REF_AREA / area)
#
# The first factor carries the design doc's own lumen arithmetic
# (area x 40 fc / CU, split over the grid). The second is the size
# correction: the design doc itself records that "the default scalar-units
# intensity DOES depend on size" (§1.4, reported from Chaos' Rectangle
# Light page), so a 12x12 fixture needs 8x the scalar of the 24x48
# reference to emit the same power. THAT SECOND FACTOR IS THE WEAKEST
# LINK IN THIS FILE — if the first render is uniformly ~8x too bright or
# too dim, set AREA_NORMALIZED to 0.0 (one constant) and re-press.
#
# ===========================================================================
# WHAT A PRESS DOES — ONE OPERATION, ONE Ctrl+Z
#
#   1. Reads the selection: groups and component instances only — it never
#      guesses which things in a model are rooms, and it NEVER lights a
#      light: its own dropped lights, any V-Ray light, and anything tagged
#      "WR Lights" are refused as subjects by name.
#   2. Pops the settings dialog (UI.inputbox, four dropdowns + one yes/no).
#   3. Checks the V-Ray light API is really there — VRay, VRay::Command,
#      create_rectangle_light, VRay::Color, VRay::Context.active — and
#      refuses BY NAME, before anything is placed, if any piece is missing.
#   4. Removes any lights IT previously dropped inside the selected rooms,
#      RECURSIVELY (nested groups included, in world coordinates) and
#      deletes each one's V-Ray scene plugin. A second press replaces; it
#      never doubles. The old sweep walked model.active_entities only and
#      was not recursive, so a press made inside an open group left the old
#      lights and stacked new ones on top.
#   5. Per selected room: sanity-checks it, reads the WR-Floor polygon
#      (bounding-box fallback, LOUD, when there is none), the wall top and
#      the doors; finds obstructions; places the layers; prints every
#      number it used. More than ONE fallback for a single subject refuses
#      that subject by name.
#   6. Tags everything "WR Lights" and prints, per layer, the size, units,
#      intensity, Kelvin and RGB actually written — plus every write that
#      did not stick.
#
# Lights go in the CURRENT drawing context, never inside the client's room
# group, so coordinates agree with the selections' own bounding boxes.
#
# ===========================================================================
# THIS SCRIPT HAS NOT BEEN RUN IN SKETCHUP
#
# No SketchUp and no V-Ray on the machine that wrote it. python
# scripts/rbparse.py proves it parses (the same CRuby 3.2 SketchUp ships) and
# python scripts/rbtest-lights.py RUNS the whole pure section — grid,
# polygon tests, L-shape, keep-outs, tiny-room centroid, wall wash, lumens,
# the Kelvin curve, the scalar-intensity formula, the read-back comparator
# and the grid-count fix — outside SketchUp, lifted verbatim from this
# file. No instance has been placed and no render seen. Every VRay:: call
# is individually rescued so a wrong assumption becomes a NAMED failure on
# the console, never a crash and never a silent no-op.

require 'sketchup.rb'

# Reload guard. A console re-`load` of this file used to print ~20
# "already initialized constant" warnings: the module body re-assigns every
# frozen constant on each load. An Object-level remove_const of the whole
# module was tried first and a live session STILL printed the full warning
# set (mechanism never reproduced outside SketchUp), so this now copies the
# pattern that demonstrably reloads clean in this repo (wr-mode.rb,
# wr-overlays.rb, wr-deck.rb): the module removes its OWN constants from
# inside its own body before the body reassigns them. constants(false)
# rather than a hand-kept list, so a constant added later is covered on the
# day it is added.
module WR_DropLights
  constants(false).each { |c| remove_const(c) }

  DICT = 'WR_DropLights'.freeze
  TAG  = 'WR Lights'.freeze
  WR_MODE_DICT = 'WR_Mode'.freeze # wr-mode.rb's dictionary — read only here

  # --- placement constants (interior-lighting-design.md; "assumed" ones are
  # --- single constants by design) --------------------------------------------
  DROP          = 0.0    # in below the wall-top plane for ROOM lights —
                         #   FLUSH, from Benton's own render (2026-08-27):
                         #   at the old 6" drop the fixture plane drew a
                         #   visible horizontal "light line" along the
                         #   walls; his verdict was "at the edge of the
                         #   ceiling for sure". build-room rooms are
                         #   OPEN-TOP, so flush cannot bury a light. A
                         #   model with a REAL ceiling slab WOULD bury a
                         #   flush light inside it — no cheap, testable way
                         #   to detect a slab is known, so this stays flush
                         #   and the console says so at placement.
  BOOTH_DROP    = 6.0    # in below the booth's OUTER top for its interior
                         #   light — a booth IS closed-top, so flush would
                         #   put the light inside the roof tray; 6" clears
                         #   it (assumed tray thickness — the pre-flush
                         #   figure, which Benton has seen emit).
  EDGE_MIN      = 18.0   # in — absolute floor on distance to any wall
  EDGE_CAP      = 36.0   # in — cap on the edge keep-away (the 2-3' band)
  KEEPOUT_PAD   = 12.0   # in — obstruction footprint inflation (assumed)
  HEADROOM      = 18.0   # in — an obstruction is anything rising above
                         #      mount plane minus this (catches a 7' booth
                         #      under an 8' ceiling)
  TARGET_FC     = 40.0   # footcandles on the floor — mid retail band
  BOOTH_FC      = 30.0   # footcandles inside the booth
  CU            = 0.6    # coefficient of utilization (assumed)
  WASH_STANDOFF = 24.0   # in off the washed wall (low end of sourced 2-3')
  WASH_SPACING  = 1.5    # spacing = this x standoff (sourced 1.2-1.5 band)
  ACCENT_OUT    = 42.0   # in from the booth door face to the accent light
  ACCENT_TILT   = 35.0   # degrees from vertical, toward the booth face

  # --- subject sanity — from the light-as-room incident -------------------
  # The first live press selected a 24"-tall V-Ray rectangle light; the
  # bbox-floor fallback happily called it a room and lit it. A room has a
  # floor you stand ON and headroom you stand IN, so a subject must clear
  # both bars or be refused by name:
  #   MIN_ROOM_H    72" (6'-0") — below every walk-in ceiling (house default
  #     is 8', the lowest habitable basements ~6'6") and above every
  #     fixture, desk, or panel stack this tool must never mistake for a
  #     room. Booths are NOT judged by this — they take the booth branch.
  #   MIN_ROOM_AREA 1296 sq in (9 sqft, 3'x3') — smaller than any room a
  #     person and a booth panel both fit in; a light's footprint (24"x48"
  #     = 8 sqft) stays under it.
  MIN_ROOM_H    = 72.0   # in — minimum plausible room height
  MIN_ROOM_AREA = 1296.0 # sq in — minimum plausible floor area (9 sqft)

  # --- untagged-booth recognition (secondary to the WR-Booth-* tags) ------
  # Benton's live booth carries no WR-Booth-* tags (imported, or built by a
  # path that does not tag), so the tag test alone left the booth-interior
  # and accent layers silently idle in a room with a visible booth. A
  # booth-SIZED box standing in the room is treated as a booth, judged by
  # the catalog's real envelope (reference/booth-models.md, exterior dims):
  # plan sides run 2'-8" (4230) to 15'-8" (102186); heights draw ~83" Std /
  # ~85" Enhanced, up to +5" on a caster plate. The bands take a little
  # margin each way; a room (96"+ walls), a desk, or a light cannot fall
  # inside them. Every size-matched booth is NAMED on the console.
  BOOTH_SIDE_MIN = 30.0  # in — smallest catalog plan side is 32"
  BOOTH_SIDE_MAX = 190.0 # in — largest catalog plan side is 188"
  BOOTH_H_MIN    = 78.0  # in — Std draws ~83"; margin below
  BOOTH_H_MAX    = 94.0  # in — Enh ~85" + 5" casters; an 8' room is out

  BRIGHT = { 'Dim' => 0.5, 'Normal' => 1.0, 'Bright' => 2.0 }.freeze

  # --- the four light layers ----------------------------------------------
  # :u / :v are the fixture's width x height in INCHES — they go straight
  # into create_rectangle_light(width:, height:) and land on the plugin as
  # u_size / v_size (observed). :lm is the layer's nominal design lumen
  # figure from interior-lighting-design.md — it is what the computed
  # per-fixture target is measured AGAINST, never a value written anywhere.
  # :dir is the accent layer's Directionality; nil means leave the
  # parameter alone.
  LIGHT_LAYERS = {
    :downlight => { :label => 'Downlight',      :u => 12.0, :v => 12.0,
                    :lm => 3000.0, :dir => nil },
    :wallwash  => { :label => 'Wall wash',      :u => 6.0,  :v => 24.0,
                    :lm => 1500.0, :dir => nil },
    :booth     => { :label => 'Booth interior', :u => 12.0, :v => 24.0,
                    :lm => 1000.0, :dir => nil },
    :accent    => { :label => 'Booth accent',   :u => 12.0, :v => 12.0,
                    :lm => 6000.0, :dir => 0.5 }
  }.freeze

  # --- the scalar-intensity anchor (see the UNITS section in the header) --
  # ONE observed data point: V-Ray's own default rectangle light, 24" x 48"
  # at intensity 30, is the light Benton rendered on 2026-08-28 and found
  # correctly lit. Everything else scales off it.
  UNITS_SCALAR    = 0.0    # the `units` value written — V-Ray's default.
                           #   The units enum is NOT in the installed docs,
                           #   so this tool refuses to guess one.
  REF_INTENSITY   = 30.0   # observed: that light's intensity
  REF_AREA        = 1152.0 # sq in — observed: that light's 24" x 48"
  REF_LUMENS      = 3000.0 # the Downlight layer's nominal design figure —
                           #   the lumen number REF_INTENSITY stands for
  AREA_NORMALIZED = 1.0    # 1.0 = correct intensity for fixture area (the
                           #   design doc records that scalar-units
                           #   intensity DOES depend on size); 0.0 = off.
                           #   THE WEAKEST ASSUMPTION IN THIS FILE — if the
                           #   first render is uniformly ~8x off, flip this.
  FACE_FLIP       = 0.0    # degrees about X applied to every light. 0 =
                           #   the created light already faces DOWN, which
                           #   is what Benton's lit test render implies but
                           #   was never measured. If the first render
                           #   lights the ceiling instead of the floor, set
                           #   this to 180.0 — that is the whole fix.
  BOX_TOL         = 0.0625 # in — 1/16". Bounding-box containment slack for
                           #   the stale sweep: room lights mount FLUSH
                           #   (DROP = 0), so their origin lies exactly on
                           #   the room bbox's top face and an exclusive
                           #   contains? would miss every one of them and
                           #   double the grid on a re-press.
  GRID_SNAP       = 0.0625 # in — 1/16", the finest quantity these drawings
                           #   carry. See grid_count: this is what stops an
                           #   extra row being squeezed in.

  # ========================================================================
  # PURE PLACEMENT LOGIC — no SketchUp API in this section. Polygons are
  # plain [[x, y], ...] arrays, keep-outs are [minx, miny, maxx, maxy]
  # rectangles ALREADY inflated. rbtest-lights.py lifts these methods
  # verbatim and runs them in CRuby outside SketchUp — keep them pure.
  # ========================================================================

  # Grid spacing from the Spacing Criterion rule: Soft is S = H (SC 1.0,
  # few large soft sources — Benton's "five or six"), Showroom is S = H/2
  # (SC 0.5, the full recessed-can rhythm).
  def self.grid_spacing(h, density)
    density == :showroom ? h / 2.0 : h * 1.0
  end

  # Centred positions along one axis: x_i = L(2i+1)/(2n). Leaves a half
  # spacing at each end when L = nS — the sourced half-spacing-at-walls rule.
  def self.axis_points(len, n)
    (0...n).map { |i| len * (2 * i + 1) / (2.0 * n) }
  end

  # HOW MANY fixtures fit on an axis of length `len` at target spacing `s`.
  #
  # THE OVERLAPPING-ROW BUG (Benton, observed 2026-08-28: "one side would
  # always get overlapping lights, like an extra row they squeezed in on
  # top"). The rule from interior-lighting-design.md §1.2 is
  # n = max(1, ceil(L / S)) and it is right — but L here is not a typed
  # number. It comes from face vertices pushed through a
  # Geom::Transformation, so a room whose side is an exact multiple of the
  # spacing arrives as 192.0000000001, not 192.0. ceil() then answers 3
  # where 2 was meant, and that axis gets a whole extra row at 2/3 of the
  # intended spacing while the other axis is untouched — an extra row
  # squeezed in on ONE side, exactly as reported. It is not
  # deterministic-by-axis either: the sign of the rounding error decides,
  # which is why it looked like the tool "did something different every
  # time".
  #
  # The fix is arithmetic, not a guessed axis: after ceil, if the last row
  # is within GRID_SNAP (1/16" — the finest quantity these drawings carry)
  # of exactly closing the run, that row was float noise and is dropped.
  # A room genuinely longer than n*S by more than 1/16" still gets its
  # extra row: the sourced ceil rule is preserved, only its float hazard
  # is removed.
  # (Coercion is written `x * 1.0`, never `x.to_f`, throughout the pure
  # section: rbtest-lights.py runs these methods in the minimal CRuby VM
  # rbparse boots, and that VM does not define Float#to_f. A method that
  # cannot be exercised offline is a method with no test.)
  def self.grid_count(len, s)
    sp = s * 1.0
    return 1 if sp <= 0.0
    n = (len / sp).ceil
    n -= 1 if n > 1 && (len - (n - 1) * sp) <= GRID_SNAP
    n < 1 ? 1 : n
  end

  # Even-odd ray cast. Plays the role Geom.point_in_polygon_2D plays inside
  # SketchUp, implemented purely so rbtest-lights.py can run it.
  def self.point_in_poly?(px, py, poly)
    inside = false
    j = poly.size - 1
    poly.each_index do |i|
      xi, yi = poly[i]
      xj, yj = poly[j]
      if (yi > py) != (yj > py)
        x_at = xi + (py - yi) * (xj - xi) / (yj - yi)
        inside = !inside if px < x_at
      end
      j = i
    end
    inside
  end

  def self.seg_dist(px, py, ax, ay, bx, by)
    dx = bx - ax
    dy = by - ay
    len2 = dx * dx + dy * dy
    t = len2 < 1e-12 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    ex = ax + t * dx - px
    ey = ay + t * dy - py
    Math.sqrt(ex * ex + ey * ey)
  end

  def self.edge_dist(px, py, poly)
    n = poly.size
    d = nil
    n.times do |i|
      a = poly[i]
      b = poly[(i + 1) % n]
      s = seg_dist(px, py, a[0], a[1], b[0], b[1])
      d = s if d.nil? || s < d
    end
    d
  end

  def self.poly_signed_area(poly)
    a = 0.0
    n = poly.size
    n.times do |i|
      j = (i + 1) % n
      a += poly[i][0] * poly[j][1] - poly[j][0] * poly[i][1]
    end
    a / 2.0
  end

  def self.poly_area(poly)
    poly_signed_area(poly).abs
  end

  # Area centroid — NOT the bbox centre; an L's bbox centre can be outside
  # the floor. Returns nil on a degenerate polygon.
  def self.poly_centroid(poly)
    a = 0.0
    cx = 0.0
    cy = 0.0
    n = poly.size
    n.times do |i|
      x0, y0 = poly[i]
      x1, y1 = poly[(i + 1) % n]
      cr = x0 * y1 - x1 * y0
      a += cr
      cx += (x0 + x1) * cr
      cy += (y0 + y1) * cr
    end
    return nil if a.abs < 1e-9
    a *= 0.5
    [cx / (6.0 * a), cy / (6.0 * a)]
  end

  def self.in_keepout?(px, py, keepouts)
    keepouts.any? do |k|
      px >= k[0] && px <= k[2] && py >= k[1] && py <= k[3]
    end
  end

  # Edge keep-away threshold. The spec band is min(S/2, 36") with an 18"
  # floor, additionally capped at the grid's own natural half-gap (gx, gy =
  # L/(2n) per axis): without that cap the band culls the centred grid's own
  # regular rows whenever L is not a multiple of S — the researcher's own
  # 12x15 Showroom worked example (edge gaps 22.5") would place zero lights
  # on the long axis. The cap keeps the band binding only against edges the
  # grid did not plan for: an L-notch, a diagonal.
  def self.edge_threshold(s, gx, gy)
    t = [s / 2.0, EDGE_CAP, gx, gy].min
    t < EDGE_MIN ? EDGE_MIN : t
  end

  # The ambient grid. Returns { :pts, :s, :fallback, :diag }. If every
  # candidate is culled (tiny room, wall-to-wall keep-out) the
  # single-centroid clause answers with one point and :fallback => true.
  #
  # :diag is the cull ACCOUNTING — how many candidates were generated and
  # how many each test rejected. The live full-cull incident printed only
  # "grid fully culled" with no breakdown, and finding the offending
  # keep-out took a second round trip; the caller now prints these numbers
  # whenever the grid comes back empty. Each rejected point is charged to
  # the FIRST test it fails, in the order polygon -> edge -> keep-out.
  def self.grid_points(poly, h, density, keepouts)
    xs = poly.map { |p| p[0] }
    ys = poly.map { |p| p[1] }
    minx = xs.min
    miny = ys.min
    lx = xs.max - minx
    ly = ys.max - miny
    s = grid_spacing(h, density)
    nx = grid_count(lx, s)
    ny = grid_count(ly, s)
    t = edge_threshold(s, lx / (2.0 * nx), ly / (2.0 * ny))
    cand = []
    axis_points(lx, nx).each do |x|
      axis_points(ly, ny).each { |y| cand << [minx + x, miny + y] }
    end
    n_out = 0
    n_edge = 0
    n_keep = 0
    keep = cand.select do |p|
      if !point_in_poly?(p[0], p[1], poly)
        n_out += 1
        false
      elsif edge_dist(p[0], p[1], poly) < t - 1e-6
        n_edge += 1
        false
      elsif in_keepout?(p[0], p[1], keepouts)
        n_keep += 1
        false
      else
        true
      end
    end
    diag = { :cand => cand.size, :out => n_out, :edge => n_edge,
             :keep => n_keep, :thr => t }
    return { :pts => keep, :s => s, :fallback => false, :diag => diag } unless keep.empty?
    c = poly_centroid(poly)
    c = nil unless c && point_in_poly?(c[0], c[1], poly)
    if c.nil?
      c = cand.select { |p| point_in_poly?(p[0], p[1], poly) }
              .max_by { |p| edge_dist(p[0], p[1], poly) }
    end
    { :pts => c ? [c] : [], :s => s, :fallback => true, :diag => diag }
  end

  def self.nearest_edge(poly, px, py)
    n = poly.size
    best = 0
    best_d = nil
    n.times do |i|
      a = poly[i]
      b = poly[(i + 1) % n]
      d = seg_dist(px, py, a[0], a[1], b[0], b[1])
      if best_d.nil? || d < best_d
        best_d = d
        best = i
      end
    end
    best
  end

  # The wall a person entering through edge door_i sees first: the farthest
  # edge running antiparallel to the door wall, measured along the door
  # wall's inward normal. nil only on a degenerate polygon.
  def self.opposite_edge(poly, door_i)
    n = poly.size
    ccw = poly_signed_area(poly) > 0
    ax, ay = poly[door_i]
    bx, by = poly[(door_i + 1) % n]
    dx = bx - ax
    dy = by - ay
    li = Math.sqrt(dx * dx + dy * dy)
    return nil if li < 1e-6
    ux = dx / li
    uy = dy / li
    nx0 = ccw ? -uy : uy
    ny0 = ccw ? ux : -ux
    mx = (ax + bx) / 2.0
    my = (ay + by) / 2.0
    best = nil
    best_d = 0.0
    n.times do |j|
      next if j == door_i
      cx, cy = poly[j]
      ex, ey = poly[(j + 1) % n]
      ddx = ex - cx
      ddy = ey - cy
      lj = Math.sqrt(ddx * ddx + ddy * ddy)
      next if lj < 1e-6
      next if (ddx * ux + ddy * uy) / lj > -0.99
      d = ((cx + ex) / 2.0 - mx) * nx0 + ((cy + ey) / 2.0 - my) * ny0
      if d > best_d
        best_d = d
        best = j
      end
    end
    best
  end

  # Wall-wash row: 24" standoff into the room, 2-4 fixtures at 1.5x standoff
  # spacing, centred along the wall run, dropped where the floor polygon or
  # a keep-out disagrees.
  def self.wash_points(poly, wall_i, keepouts)
    n = poly.size
    ccw = poly_signed_area(poly) > 0
    ax, ay = poly[wall_i]
    bx, by = poly[(wall_i + 1) % n]
    dx = bx - ax
    dy = by - ay
    len = Math.sqrt(dx * dx + dy * dy)
    return [] if len < 1e-6
    ux = dx / len
    uy = dy / len
    nx0 = ccw ? -uy : uy
    ny0 = ccw ? ux : -ux
    count = grid_count(len, WASH_SPACING * WASH_STANDOFF)
    count = 2 if count < 2
    count = 4 if count > 4
    axis_points(len, count).map do |t|
      [ax + ux * t + nx0 * WASH_STANDOFF, ay + uy * t + ny0 * WASH_STANDOFF]
    end.select do |p|
      point_in_poly?(p[0], p[1], poly) && !in_keepout?(p[0], p[1], keepouts)
    end
  end

  # Per-fixture ambient lumens: floor area x 40 fc / CU, split over the grid.
  # 12x15 @ Soft (4 lights) = 3,000 lm each; @ Showroom (12) = 1,000 lm.
  def self.downlight_lumens(area_sqin, count, mult)
    return 0 if count < 1
    (area_sqin / 144.0 * TARGET_FC / CU / count * mult).round
  end

  # Booth interior: booth footprint x 30 fc / CU, one fixture.
  # A 24 sqft booth lands at 1,200 lm — the seed's 1,000 lm is in range.
  def self.booth_lumens(area_sqin, mult)
    (area_sqin / 144.0 * BOOTH_FC / CU * mult).round
  end

  # Rotation axis that tips a down-facing light toward the booth: for unit
  # XY direction d TOWARD the booth face, axis = cross(-Z, d) = [dy, -dx].
  # Rotating -Z about it by the tilt angle swings the beam onto the face.
  def self.accent_axis(dx, dy)
    len = Math.sqrt(dx * dx + dy * dy)
    return nil if len < 1e-9
    [dy / len, -dx / len]
  end

  # Subject sanity veto: nil when (h, area) is a plausible room, else the
  # refusal text. Runs BEFORE any layer math — see MIN_ROOM_H above.
  def self.subject_veto(h, area_sqin)
    if h < MIN_ROOM_H
      format('height %.0f" is below the %.0f" a walk-in room needs —' +
             ' this looks like a fixture or a part, not a room.', h, MIN_ROOM_H)
    elsif area_sqin < MIN_ROOM_AREA
      format('floor area %.1f sqft is below the %.0f sqft a room needs —' +
             ' this looks like a fixture or a part, not a room.',
             area_sqin / 144.0, MIN_ROOM_AREA / 144.0)
    end
  end

  # THE MULTI-FALLBACK RULE. Each fallback alone is a defensible
  # accommodation (a legacy room without WR-Floor, a door-less room). The
  # incident chained three of them — bbox floor, culled-grid centroid,
  # no-door longest wall — and turned a selected LIGHT into a confident
  # "1 light in 1 container" report. So: more than ONE fallback for a
  # single subject means the input is not what the tool thinks it is.
  # Returns nil (proceed) or the refusal text listing what fired.
  def self.fallback_verdict(fired)
    return nil if fired.size <= 1
    "#{fired.size} fallbacks fired for this one subject:\n" +
      fired.map { |f| "      - #{f}" }.join("\n") +
      "\n    One fallback is an accommodation; several in a row" +
      ' mean the selection is not the room this tool assumed.'
  end

  # Pure core of vray_light?: does this text (definition name + attribute
  # dictionary names) name a V-Ray light? Both words required — "Daylight"
  # alone must not match.
  def self.light_words?(text)
    !!(text =~ /v-?ray/i && text =~ /light/i)
  end

  # A room's own structure — floor, walls, doors — is never an obstruction.
  # Tags are authoritative; names catch untagged builds, CASE-INSENSITIVELY,
  # because the generators disagree: build-room.rb names the children
  # "Floor"/"Walls"/"Doors", uthsc-audiology-rooms.rb (the live UTHSC
  # rooms) names them "floor"/"walls"/"doors".
  ROOM_CHILD_TAGS = %w[WR-Floor WR-Room WR-Room-Upper WR-Doors
                       WR-Doors-Leaf WR-Notes].freeze
  ROOM_CHILD_NAMES = %w[Floor Walls Doors].freeze

  # Pure core of the obstruction child filter: is a child with this tag and
  # name part of the room's own structure?
  def self.room_structure_child?(tag_name, disp_name)
    return true if ROOM_CHILD_TAGS.include?(tag_name)
    ROOM_CHILD_NAMES.any? { |n| n.casecmp(disp_name).zero? }
  end

  # Pure core of the floor-child finder — the same predicate room_info uses
  # to read a room and obstructions() uses to recognize a sibling ROOM (a
  # thing with its own floor is a room, never a keep-out).
  def self.floor_child?(tag_name, disp_name)
    tag_name == 'WR-Floor' || disp_name =~ /\Afloor\z/i ? true : false
  end

  # Booth-by-size: both plan sides inside the catalog band and the height
  # inside the booth band (constants above). The secondary booth test for
  # untagged booths; every hit is named on the console by the caller.
  def self.booth_like?(w, l, h)
    lo = w < l ? w : l
    hi = w < l ? l : w
    lo >= BOOTH_SIDE_MIN && hi <= BOOTH_SIDE_MAX &&
      h >= BOOTH_H_MIN && h <= BOOTH_H_MAX
  end

  # --- V-Ray light parameter cores — pure --------------------------------

  # Kelvin -> linear RGB, each component 0..1.
  #
  # Tanner Helland's black-body approximation
  # (https://tannerhelland.com/2012/09/18/convert-temperature-rgb-algorithm-code.html),
  # the standard published curve-fit to Mitchell Charity's blackbody table;
  # valid 1000-40000 K, and its own author states the fit is within a few
  # percent over 1000-10000 K. Written out here because the V-Ray rectangle
  # light has NO temperature parameter (observed in its full default dump) —
  # colour is the only place a Kelvin answer can land.
  #
  # This is a REPORTED curve, not a measured one. It is exact at 6600 K
  # (white by construction), which is the test that pins it.
  def self.kelvin_rgb(kelvin)
    return [1.0, 1.0, 1.0] if kelvin * 1.0 <= 0.0
    t = kelvin / 100.0
    r = t <= 66.0 ? 255.0 : 329.698727446 * ((t - 60.0)**-0.1332047592)
    g = if t <= 66.0
          99.4708025861 * Math.log(t) - 161.1195681661
        else
          288.1221695283 * ((t - 60.0)**-0.0755148492)
        end
    b = if t >= 66.0
          255.0
        elsif t <= 19.0
          0.0
        else
          138.5177312231 * Math.log(t - 10.0) - 305.0447927307
        end
    [r, g, b].map do |c|
      if c <= 0.0 then 0.0
      elsif c >= 255.0 then 1.0
      else c / 255.0
      end
    end
  end

  # The scalar `intensity` to write for a fixture of u x v inches whose
  # design target is target_lm lumens. See the UNITS section in the header:
  # the units enum is unproven on this build, so units stays 0 and the
  # brightness is carried entirely by this number, anchored to the one
  # observed-good light (REF_*). Returns 0.0 on a degenerate fixture.
  def self.scalar_intensity(target_lm, u, v)
    a = u * v * 1.0
    lm = target_lm * 1.0
    return 0.0 if a <= 0.0 || lm <= 0.0
    i = REF_INTENSITY * (lm / REF_LUMENS)
    i * ((REF_AREA / a)**AREA_NORMALIZED)
  end

  # Did a plugin parameter write STICK? Compares what we asked for against
  # what the plugin read back. Nothing is assumed about how V-Ray stores a
  # value: an integer flag and a boolean are the same answer (the dump
  # prints invisible as 0/1, `each` yields it as false/true), floats are
  # compared with a relative tolerance, and anything with #to_a (a
  # VRay::Color) is compared component-wise. An unrecognised pair falls
  # back to ==, and a false answer is REPORTED, never silently accepted.
  def self.param_agrees?(want, got)
    return true if want == got
    w = want == true ? 1.0 : (want == false ? 0.0 : nil)
    g = got == true ? 1.0 : (got == false ? 0.0 : nil)
    w = want * 1.0 if w.nil? && want.is_a?(Numeric)
    g = got * 1.0 if g.nil? && got.is_a?(Numeric)
    if !w.nil? && !g.nil?
      scale = [w.abs, g.abs, 1.0].max
      return (w - g).abs <= 1e-4 * scale
    end
    if want.respond_to?(:to_a) && got.respond_to?(:to_a) &&
       !want.is_a?(String) && !got.is_a?(String)
      wa = want.to_a
      ga = got.to_a
      n = [wa.size, ga.size].min
      return false if n.zero?
      return (0...n).all? { |i| param_agrees?(wa[i], ga[i]) }
    end
    false
  end

  # Is point (px, py, pz) inside the box [minx, miny, minz, maxx, maxy,
  # maxz], with BOX_TOL of slack on every face? The slack is not
  # cosmetic: room lights mount FLUSH (DROP = 0), so their origin lies
  # exactly on the room's top face, and an exclusive containment test
  # would fail to find them on a re-press and double the grid.
  def self.in_box?(px, py, pz, box)
    px >= box[0] - BOX_TOL && px <= box[3] + BOX_TOL &&
      py >= box[1] - BOX_TOL && py <= box[4] + BOX_TOL &&
      pz >= box[2] - BOX_TOL && pz <= box[5] + BOX_TOL
  end

  # Pure door-detection cores, matched to what the room generators REALLY
  # write (read from the .rb files, not remembered):
  #
  #   build-room.rb:  a "Doors" group (untagged) holding "Opening N" groups
  #     tagged WR-Doors — the jamb-to-jamb marker auto-dimension.rb reads —
  #     plus "Door leaf N" / "Swing N" groups on WR-Doors-Leaf.
  #   uthsc-audiology-rooms.rb:  a "doors" group TAGGED WR-Doors holding
  #     'door leaf 36" ...' solids (untagged) and the swing arc as loose
  #     edges. NO Opening markers at all — which is exactly why the live
  #     UTHSC run printed "no door found" on a room with a visible door.
  #
  # So: the container is found by name or tag (but a thing named like a
  # marker is never the container); inside it an Opening marker is found by
  # tag-or-name; failing that a leaf solid is found by name, and the open
  # leaf's width stands in for the opening's.
  def self.doors_container?(tag_name, disp_name)
    return false if disp_name =~ /\Aopening/i
    disp_name =~ /\Adoors\z/i || tag_name == 'WR-Doors' ? true : false
  end

  # :opening (the real jamb-to-jamb marker), :leaf (the stand-in), or nil
  # (a swing arc, a header, anything else).
  def self.door_child_kind(tag_name, disp_name)
    return :opening if tag_name == 'WR-Doors' || disp_name =~ /\Aopening/i
    return :leaf if disp_name =~ /\Adoor leaf/i
    nil
  end

  # ======================================================================
  # END OF THE PURE SECTION — SketchUp API from here down.
  # ======================================================================

  # A V-Ray light is never a lighting subject — the pure core is
  # light_words?; these two read the entity that feeds it.
  def self.own_dict_names(ent)
    ad = ent.respond_to?(:attribute_dictionaries) ? ent.attribute_dictionaries : nil
    ad ? ad.map { |d| d.name.to_s } : []
  end

  # Does this look like a V-Ray light? Judged by names only: its definition
  # name plus its attribute-dictionary names (instance and definition) must
  # mention both "vray" and "light". Deliberately strict: this is what
  # keeps the tool from ever treating a light as a room to be lit.
  def self.vray_light?(ent)
    return false unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
    words = own_dict_names(ent)
    if ent.respond_to?(:definition) && ent.definition
      words += own_dict_names(ent.definition)
      words << ent.definition.name.to_s
    end
    light_words?(words.join(' '))
  end

  # The one light the seeds get copied from: a selected V-Ray light wins,
  # else the model's top level — but only when every candidate is the same
  # light (same definition). Different definitions are a genuine choice
  # this tool refuses to make; it lists them and asks for a selection.

  # ========================================================================
  # THE V-RAY LIGHT API — every call individually rescued
  #
  # The standing lesson (reference/vray-ruby-api.md) is that V-Ray calls
  # raise for reasons that have nothing to do with the call — a cold DR
  # renderer once raised "Incorrect DR version" from in_process?. So no
  # VRay:: call below is made bare: each one either returns a value or
  # turns into a NAMED failure. Nothing in this file may fail silently,
  # because the symptom of a silent failure here is a black render an hour
  # later.
  # ========================================================================

  # Every piece of the API this tool needs, checked BEFORE anything is
  # placed. Returns nil when all present, else the plain-words reason.
  def self.vray_api_missing
    return 'V-Ray is not loaded in this SketchUp (no VRay module)' unless defined?(VRay)
    return 'VRay::Command is not defined' unless defined?(VRay::Command)
    return 'VRay::Color is not defined' unless defined?(VRay::Color)
    return 'VRay::Context is not defined' unless defined?(VRay::Context)
    ok = begin
           VRay::Command.respond_to?(:create_rectangle_light)
         rescue StandardError => e
           return "asking VRay::Command for create_rectangle_light raised #{e.class}: #{e.message}"
         end
    unless ok
      return 'VRay::Command has no create_rectangle_light — this V-Ray ' \
             'predates the light API this tool is built on. Nothing was ' \
             'placed; there is no seed fallback any more.'
    end
    nil
  end

  # [context, nil] or [nil, plain-words reason].
  def self.vray_context
    ctx = begin
            VRay::Context.active
          rescue StandardError => e
            return [nil, "VRay::Context.active raised #{e.class}: #{e.message}"]
          end
    ctx.nil? ? [nil, 'VRay::Context.active is nil (V-Ray inactive)'] : [ctx, nil]
  end

  # The V-Ray scene, for deleting a replaced light's plugin. nil is fine —
  # the sweep just says the plugin was left behind.
  def self.vray_scene(ctx)
    return nil if ctx.nil?
    begin
      ctx.scene
    rescue StandardError
      nil
    end
  end

  # Make ONE V-Ray rectangle light. Returns [ComponentDefinition, Plugin].
  # RAISES with the arguments in the message on any failure — a light that
  # cannot be made must stop the press, not quietly reduce the rig.
  #
  # Observed signature (Benton, live, 2026-08-28):
  #   VRay::Command.create_rectangle_light(context:, width:, height:)
  #     -> OpenStruct with .entity (ComponentDefinition, NOT placed) and
  #        .plugin (this light's own VRay::Scene::Plugin)
  def self.create_light(ctx, w, h)
    o = begin
          VRay::Command.create_rectangle_light(:context => ctx,
                                               :width => w.to_f,
                                               :height => h.to_f)
        rescue StandardError, ScriptError => e
          raise "VRay::Command.create_rectangle_light(width: #{w}, " \
                "height: #{h}) raised #{e.class}: #{e.message}"
        end
    raise "create_rectangle_light(width: #{w}, height: #{h}) returned nil" if o.nil?
    d = begin
          o.entity
        rescue StandardError => e
          raise "the created light's .entity raised #{e.class}: #{e.message}"
        end
    p = begin
          o.plugin
        rescue StandardError => e
          raise "the created light's .plugin raised #{e.class}: #{e.message}"
        end
    unless d.is_a?(Sketchup::ComponentDefinition)
      raise "create_rectangle_light gave .entity of class #{d.class}, not a " \
            'Sketchup::ComponentDefinition — the API changed shape and this ' \
            'tool will not guess at it.'
    end
    raise 'create_rectangle_light gave a nil .plugin — nothing to configure' if p.nil?
    [d, p]
  end

  # Write ONE plugin parameter and READ IT BACK. Returns
  # [stuck?, value_read, error_or_nil]. Never raises.
  def self.set_param(plugin, key, value)
    begin
      plugin[key] = value
    rescue StandardError => e
      return [false, nil, "write raised #{e.class}: #{e.message}"]
    end
    got = begin
            plugin[key]
          rescue StandardError => e
            return [false, nil, "read-back raised #{e.class}: #{e.message}"]
          end
    [param_agrees?(value, got), got, nil]
  end

  def self.plugin_name(plugin)
    begin
      plugin.name.to_s
    rescue StandardError
      ''
    end
  end

  # Configure one freshly-created light for its layer. Returns a report
  # hash: :writes => [[key, want, got, stuck?, err]...], :bad => [key...].
  # NOTHING here raises — a parameter that will not take is reported by
  # name and the light still places, because a wrongly-tuned light that
  # emits is recoverable in the Asset Editor and a missing light is not.
  def self.configure_light(plugin, role, target_lm, kelvin)
    spec = LIGHT_LAYERS[role]
    rgb = kelvin_rgb(kelvin)
    color = nil
    color_err = nil
    begin
      color = VRay::Color.new(rgb[0], rgb[1], rgb[2])
    rescue StandardError => e
      color_err = "VRay::Color.new raised #{e.class}: #{e.message}" \
                  ' — this light stays V-Ray white; Warmth did not land.'
    end
    wants = []
    # invisible FIRST: it is the one that must not be missed. Benton's test
    # render drew the emitter as a white slab on the ceiling (observed).
    wants << [:invisible, true]
    wants << [:units, UNITS_SCALAR]
    wants << [:intensity, scalar_intensity(target_lm, spec[:u], spec[:v])]
    wants << [:color, color] unless color.nil?
    wants << [:directional, spec[:dir]] unless spec[:dir].nil?
    writes = []
    bad = []
    wants.each do |key, value|
      stuck, got, err = set_param(plugin, key, value)
      writes << [key, value, got, stuck, err]
      bad << key unless stuck
    end
    # u_size / v_size were set by the create call — read them back rather
    # than re-writing, so a mismatch is a fact about the API, not ours.
    sizes = [:u_size, :v_size].map do |k|
      begin
        plugin[k]
      rescue StandardError
        nil
      end
    end
    { :writes => writes, :bad => bad, :rgb => rgb, :sizes => sizes,
      :color_err => color_err }
  end

  # ---- the stale sweep — RECURSIVE, in world coordinates -----------------
  #
  # THE IDEMPOTENCY BUG (auditor, lighting-inconsistency-2026-08-28.md, C7):
  # the old sweep walked model.active_entities only, and not recursively.
  # A press made while a group was open for edit dropped its lights INSIDE
  # that group; the next press from the top level could not see them, left
  # them, and stacked a fresh grid on top — double brightness, invisible in
  # the viewport because the lights are Invisible = ON. This walks the whole
  # tree and compares WORLD origins, so where the press happened stops
  # mattering.
  #
  # Depth is capped so a pathological model cannot hang the press; hitting
  # the cap is reported, never swallowed.
  SWEEP_MAX_DEPTH = 12

  def self.collect_lights(ents, tr, out, depth = 0, over = [])
    if depth > SWEEP_MAX_DEPTH
      over << true
      return
    end
    ents.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      wt = begin
             tr * e.transformation
           rescue StandardError
             next
           end
      # 'seed' is the attribute EVERY version of this tool has written,
      # including the seed-based ones — so a re-press after the upgrade
      # still finds and replaces pre-1.8.0 lights instead of doubling them.
      if e.get_attribute(DICT, 'seed') || e.get_attribute(DICT, 'role')
        out << [e, wt.origin]
        next # never walk into a light
      end
      kids = child_entities(e)
      collect_lights(kids, wt, out, depth + 1, over) if kids.respond_to?(:each)
    end
  rescue StandardError
    nil
  end

  # Every light this tool has ever dropped whose WORLD origin lies inside
  # one of `boxes` ([minx,miny,minz,maxx,maxy,maxz] arrays). Returns
  # [[entity, world_origin]...] and whether the depth cap was hit.
  def self.stale_lights(model, boxes)
    found = []
    over = []
    collect_lights(model.entities, IDENT, found, 0, over)
    hits = found.select do |_, o|
      boxes.any? { |b| in_box?(o.x, o.y, o.z, b) }
    end
    [hits, !over.empty?]
  end

  # Box array from a Geom::BoundingBox — the form in_box? takes.
  def self.box_of(bb)
    [bb.min.x, bb.min.y, bb.min.z, bb.max.x, bb.max.y, bb.max.z]
  end

  # Erase replaced lights AND their V-Ray plugins. A light's plugin is
  # recorded on the instance at placement; deleting it keeps a re-press
  # from growing the Asset Editor's light list without bound.
  # Returns [erased, plugins_deleted, plugins_left].
  def self.erase_lights(model, scene, lights)
    erased = 0
    gone = 0
    left = 0
    lights.each do |e, _|
      # A light reached through two instance paths of one shared
      # definition appears twice in the list; the second visit is already
      # deleted and reading an attribute off it would raise.
      next unless e.respond_to?(:valid?) && e.valid?
      pname = e.get_attribute(DICT, 'plugin').to_s
      defn = e.respond_to?(:definition) ? e.definition : nil
      begin
        e.erase!
        erased += 1
      rescue StandardError
        next
      end
      if defn && defn.respond_to?(:instances) && defn.instances.empty?
        begin
          model.definitions.remove(defn)
        rescue StandardError
          nil
        end
      end
      if pname.empty?
        left += 1 # a pre-1.8.0 seed light: it never owned a plugin
      elsif scene.nil?
        left += 1
      else
        ok = begin
               scene.delete(pname)
             rescue StandardError
               false
             end
        ok ? gone += 1 : left += 1
      end
    end
    [erased, gone, left]
  end


  # The WR Lights tag. Placement NEVER hides it — in ANY mode. Visibility
  # belongs to the draft/render mode switch alone (wr-mode.rb's LIGHT_TAGS:
  # hidden in draft, visible in render); this method only makes sure the
  # tag EXISTS and is VISIBLE, so a just-dropped rig can never be silently
  # absent from a V-Ray pass.
  #
  # THE 1.7.3/1.7.4 REGRESSION, so it is never re-introduced: this method
  # used to hide the tag when the model was in draft mode, "so the
  # rectangles don't show in plain exports". The unlit-render failure of
  # 2026-08-27 correlated exactly with that change (commit 2f48a6e), and
  # V-Ray excludes hidden geometry from the render (reported, Chaos docs) —
  # but Benton's own evidence does NOT confirm the tag was hidden at
  # failure time ("tag wasn't hidden, but I did toggle it"), so hiding is a
  # plausible contributor, not a diagnosed cause. This fix removes the
  # CLASS of problem either way: the failure asymmetry decides the default.
  # A visible light rectangle in a draft export is a cosmetic problem seen
  # immediately; a hidden light tag in a V-Ray pass renders silently UNLIT,
  # the worse failure. Prefer the loud one. The mode dictionary is read
  # only to word the console line, never to hide anything.
  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(255, 199, 44)) rescue nil # troffer yellow
    mode = (model.get_attribute(WR_MODE_DICT, 'current') rescue nil)
    if t.visible? == false
      t.visible = true
      puts "  tag \"#{TAG}\" was hidden — SHOWN. A hidden light tag makes " +
           'a V-Ray pass render silently UNLIT (the 1.7.3 regression).'
    end
    if mode == 'draft'
      puts "  tag \"#{TAG}\" is VISIBLE and placement leaves it that way, " +
           'even though this model is in DRAFT mode — so the rectangles '
      puts '    WILL show in plain image exports until you press the ' +
           'Draft/Render toggle (draft hides them, render shows them).'
      puts '    A V-Ray render right now WILL be lit.'
    end
    t
  end

  # Why an entity is barred from being a lighting subject, or nil.
  # THE INCIDENT FIX: the old exclusion keyed on this tool's own DICT
  # attribute, so only lights IT had dropped were rejected — Benton's
  # hand-made V-Ray rectangle light carried no such attribute, stayed a
  # subject, and got lit as a "room". Classify by what the thing IS
  # (V-Ray dictionaries, the WR Lights tag), not by who placed it.
  def self.subject_exclusion(e)
    return :own  if e.get_attribute(DICT, 'seed')
    return :vray if vray_light?(e)
    return :tag  if layer_name(e) == TAG
    nil
  end

  # The rooms/booths to light, and the lights barred from being subjects:
  # [[subjects...], [[entity, reason]...]]. This tool NEVER lights a light.
  def self.split_selection(model)
    subjects = []
    excluded = []
    model.selection.to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      r = subject_exclusion(e)
      r ? excluded << [e, r] : subjects << e
    end
    [subjects, excluded]
  end

  def self.child_entities(ent)
    if ent.is_a?(Sketchup::Group)
      ent.entities
    elsif ent.respond_to?(:definition)
      ent.definition.entities
    else
      []
    end
  end

  def self.layer_name(ent)
    ent.respond_to?(:layer) && ent.layer ? ent.layer.name.to_s : ''
  end

  def self.display_name(ent)
    n = ent.respond_to?(:name) ? ent.name.to_s : ''
    n = ent.definition.name.to_s if n.empty? && ent.respond_to?(:definition)
    n.empty? ? '(unnamed)' : n
  end

  # A WhisperRoom booth is recognized by the WR-Booth-* tags that
  # build-booth-components.rb writes on the panel instances directly inside
  # the booth group (WR-Booth-Walls / -Door / -Vent / -Seals / -Corners /
  # -Deck). Keyed on the tag PREFIX so every family member matches.
  def self.booth?(ent)
    return true if layer_name(ent).start_with?('WR-Booth')
    child_entities(ent).to_a.any? { |e| layer_name(e).start_with?('WR-Booth') }
  end

  # A sibling that is itself a ROOM — it has its own floor child — is never
  # an obstruction: rooms do not stand under each other's lights, and an
  # L-shaped neighbour's BOUNDING BOX overlaps this room's floor even
  # though the rooms never touch (the live 2026-08-27 "keep-out: ROOM 2"
  # incident — an L's bbox covers its notch). A booth is never mistaken
  # for a room here, whatever its children are named.
  def self.room_group?(ent)
    return false if booth?(ent)
    child_entities(ent).to_a.any? do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        floor_child?(layer_name(e), display_name(e))
    end
  end

  # World-space bounding box of a child entity under transform tr.
  def self.world_bounds(ent, tr)
    bb = Geom::BoundingBox.new
    src = ent.bounds
    8.times { |i| bb.add(src.corner(i).transform(tr)) }
    bb
  end

  IDENT = Geom::Transformation.new

  # ---- room geometry ------------------------------------------------------

  # Reads one selected container into a plain-geometry hash:
  #   :poly [[x,y]..] world, :z0, :z_top, :doors [{:cx,:cy,:w}..],
  #   :door_mech (how the doors were recognized — printed by the caller),
  #   :door_diag (why NO door was found — printed on the no-door path),
  #   :fallback (true = bbox rectangle, said loudly by the caller),
  #   :degenerate (true = refuse this room by name).
  # Child names are matched case-insensitively throughout: build-room.rb
  # writes "Floor"/"Walls"/"Doors", uthsc-audiology-rooms.rb writes
  # "floor"/"walls"/"doors".
  def self.room_info(inst)
    tr = inst.transformation
    kids = child_entities(inst).to_a
    floor_g = kids.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        floor_child?(layer_name(e), display_name(e))
    end

    unless floor_g
      bb = inst.bounds
      poly = [[bb.min.x, bb.min.y], [bb.max.x, bb.min.y],
              [bb.max.x, bb.max.y], [bb.min.x, bb.max.y]]
      return { :poly => poly, :z0 => bb.min.z, :z_top => bb.max.z,
               :doors => [], :fallback => true, :degenerate => false }
    end

    ftr = tr * floor_g.transformation
    face = child_entities(floor_g).grep(Sketchup::Face).max_by(&:area)
    if face.nil? || face.area < 1.0
      return { :degenerate => true }
    end
    wpts = face.outer_loop.vertices.map { |v| v.position.transform(ftr) }
    poly = wpts.map { |p| [p.x, p.y] }
    z0 = wpts.map(&:z).min

    walls_g = kids.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        (layer_name(e) == 'WR-Room' || display_name(e) =~ /\Awalls\z/i)
    end
    z_top = walls_g ? world_bounds(walls_g, tr).max.z : inst.bounds.max.z

    # Doors, in the defined order the pure classifiers encode (see
    # doors_container? / door_child_kind): Opening markers inside the doors
    # container first, then door-leaf solids inside it, then Opening
    # markers sitting directly in the room group. Which mechanism matched
    # is returned in :door_mech and printed by the caller; when nothing
    # matched, :door_diag says exactly what was searched.
    doors = []
    door_mech = nil
    doors_g = kids.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        doors_container?(layer_name(e), display_name(e))
    end
    door_kids = []
    if doors_g
      door_kids = child_entities(doors_g).to_a.select do |d|
        d.is_a?(Sketchup::Group) || d.is_a?(Sketchup::ComponentInstance)
      end
    end
    picked = door_kids.select { |d| door_child_kind(layer_name(d), display_name(d)) == :opening }
    base_tr = doors_g ? tr * doors_g.transformation : tr
    if picked.any?
      door_mech = "#{picked.size} Opening marker#{picked.size == 1 ? '' : 's'} " \
                  "in \"#{display_name(doors_g)}\" (WR-Doors tag / Opening name)"
    else
      picked = door_kids.select { |d| door_child_kind(layer_name(d), display_name(d)) == :leaf }
      if picked.any?
        door_mech = "#{picked.size} door-leaf solid#{picked.size == 1 ? '' : 's'} " \
                    "in \"#{display_name(doors_g)}\" — no Opening markers; " \
                    "the open leaf's width stands in for the opening"
      else
        picked = kids.select do |d|
          (d.is_a?(Sketchup::Group) || d.is_a?(Sketchup::ComponentInstance)) &&
            !doors_container?(layer_name(d), display_name(d)) &&
            door_child_kind(layer_name(d), display_name(d)) == :opening
        end
        base_tr = tr
        if picked.any?
          door_mech = "#{picked.size} Opening marker#{picked.size == 1 ? '' : 's'} " \
                      'directly in the room group'
        end
      end
    end
    picked.each do |d|
      wb = world_bounds(d, base_tr)
      w = [wb.max.x - wb.min.x, wb.max.y - wb.min.y].max
      doors << { :cx => (wb.min.x + wb.max.x) / 2.0,
                 :cy => (wb.min.y + wb.max.y) / 2.0, :w => w }
    end
    door_diag =
      if doors.any?
        nil
      elsif doors_g
        "a doors container \"#{display_name(doors_g)}\" was found but none " \
        "of its #{door_kids.size} group children matched an Opening marker " \
        "(WR-Doors tag / name starting \"Opening\") or a leaf (name " \
        "starting \"door leaf\")"
      else
        "no doors container among the room's #{kids.size} children " \
        '(looked for the WR-Doors tag or a "Doors" name) and no Opening ' \
        'markers directly in the room group'
      end

    { :poly => poly, :z0 => z0, :z_top => z_top, :doors => doors,
      :door_mech => door_mech, :door_diag => door_diag,
      :fallback => false, :degenerate => false,
      :no_walls => walls_g.nil? }
  end

  # ---- obstructions -------------------------------------------------------

  # Everything that could stand under the light plane of `room`: the room's
  # SIBLINGS — the entities of the container the room itself sits in — plus
  # the room's own non-structural children (a booth dragged inside the
  # group). Returns [[{:rect(inflated), :ent, :tr, :bb}...], [skipped
  # sibling ROOMS — named by the caller, never keep-outs]].
  #
  # Siblings, NOT model.entities. The live UTHSC full-cull incident: the
  # selected room was nested inside a suite group, the old top-level scan
  # saw the SUITE ITSELF — a box spanning all four rooms wall-to-wall,
  # rising to the ceiling — and turned the room's own ancestor into one
  # keep-out that culled every grid point. A room's ancestors can never be
  # its obstructions, and a sibling list cannot contain an ancestor. The
  # siblings also share the coordinate frame the room's transformation (and
  # the placed lights, and the selection's bounds) live in, which
  # model.entities does not once the room is nested.
  def self.obstructions(model, room, poly, z_m, subjects)
    xs = poly.map { |p| p[0] }
    ys = poly.map { |p| p[1] }
    minx = xs.min
    miny = ys.min
    maxx = xs.max
    maxy = ys.max

    par = room.respond_to?(:parent) ? room.parent : nil
    sibs = par.respond_to?(:entities) ? par.entities : model.entities
    cands = []
    sibs.to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      # Other selected rooms are not obstructions of this one, but a
      # selected BOOTH still obstructs (and is lit by) the room around it.
      next if e == room || (subjects.include?(e) && !booth?(e))
      next if e.get_attribute(DICT, 'seed')
      next if vray_light?(e) || layer_name(e) == TAG # a light never keeps out
      cands << [e, IDENT]
    end
    child_entities(room).to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if room_structure_child?(layer_name(e), display_name(e))
      cands << [e, room.transformation]
    end

    out = []
    skipped_rooms = []
    cands.each do |e, base|
      bb = base.identity? ? e.bounds : world_bounds(e, base)
      next unless bb.valid?
      next if bb.max.z <= z_m - HEADROOM                      # too short to matter
      next if bb.min.x > maxx || bb.max.x < minx ||           # clear of the floor
              bb.min.y > maxy || bb.max.y < miny
      if room_group?(e)
        # A room is never furniture — see room_group?. It is collected,
        # not dropped, so the caller can NAME it on the console: a
        # genuinely-overlapping room must not vanish silently.
        skipped_rooms << e
        next
      end
      out << { :ent => e, :tr => base,
               :bb => bb,
               :rect => [bb.min.x - KEEPOUT_PAD, bb.min.y - KEEPOUT_PAD,
                         bb.max.x + KEEPOUT_PAD, bb.max.y + KEEPOUT_PAD] }
    end
    [out, skipped_rooms]
  end

  # Booth door face centre in world XY, from the WR-Booth-Door children.
  # nil when the booth has no tagged door (accent is then skipped, loudly).
  def self.booth_door_center(obst)
    btr = obst[:tr] * (obst[:ent].respond_to?(:transformation) ? obst[:ent].transformation : IDENT)
    bb = Geom::BoundingBox.new
    child_entities(obst[:ent]).to_a.each do |e|
      next unless layer_name(e) == 'WR-Booth-Door'
      wb = world_bounds(e, btr)
      bb.add(wb.min)
      bb.add(wb.max)
    end
    return nil unless bb.valid?
    [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0]
  end

  # ---- the dialog ---------------------------------------------------------

  def self.ask
    @last ||= ['Soft', 'Normal', '3000K warm', 'All', 'Yes']
    res = UI.inputbox(
      ['Density', 'Brightness', 'Warmth', 'Layers', 'Set interior exposure'],
      @last,
      ['Soft|Showroom grid',
       'Normal|Dim|Bright',
       '3000K warm|3500K neutral',
       'All|Ambient only|Ambient + wall wash|Ambient + booth',
       'Yes|No'],
      'Drop Interior Lights')
    return nil unless res
    @last = res
    {
      :density  => res[0] == 'Showroom grid' ? :showroom : :soft,
      :mult     => BRIGHT[res[1]] || 1.0,
      :bright   => res[1],
      :kelvin   => res[2].start_with?('3500') ? 3500 : 3000,
      :wash     => res[3] == 'All' || res[3] == 'Ambient + wall wash',
      :booth    => res[3] == 'All' || res[3] == 'Ambient + booth',
      :exposure => res[4] == 'Yes'
    }
  end

  # ==== WHAT WAS ACTUALLY WRITTEN INTO V-RAY ===============================
  # Brightness and Warmth are no longer advice: each light owns its plugin
  # and this tool writes them (see the header). What survives as advice is
  # EXPOSURE, which nothing here sets and nothing here can source — it is a
  # camera setting, a known open item, and it is 30-60x more important than
  # any lumen number.
  #
  # `layers` is { role => report-hash-from-configure_light } for the FIRST
  # light of each layer, plus :target and :count. One block per layer, not
  # per light: twelve identical blocks is not a report.
  def self.print_light_report(layers, opts)
    puts ''
    puts '  WHAT WAS WRITTEN INTO EACH V-RAY LIGHT (one plugin per light —'
    puts '  no shared asset any more, so these are per-light values):'
    layers.each do |role, r|
      spec = LIGHT_LAYERS[role]
      rgb = r[:rgb]
      puts format('    %-15s x%-3d  %.0f" x %.0f"  units %s  intensity %.1f',
                  spec[:label], r[:count], spec[:u], spec[:v],
                  UNITS_SCALAR.to_i.to_s, r[:intensity])
      puts format('                    target %d lm (design), colour %dK ' \
                  '= rgb %.3f %.3f %.3f, invisible ON',
                  r[:target].round, opts[:kelvin], rgb[0], rgb[1], rgb[2])
      if r[:sizes] && r[:sizes].compact.size == 2
        puts format('                    plugin read back u_size %s, v_size %s',
                    r[:sizes][0].to_s, r[:sizes][1].to_s)
      end
      puts "                    NOTE: #{r[:color_err]}" if r[:color_err]
      next if r[:bad].nil? || r[:bad].empty?
      puts "    ** #{spec[:label]}: these writes DID NOT STICK — " \
           "#{r[:bad].map(&:to_s).join(', ')}. Read them in the Asset " \
           'Editor before rendering; the light placed anyway.'
      r[:writes].each do |key, want, got, stuck, err|
        next if stuck
        puts format('       %s: wanted %s, plugin holds %s%s', key.to_s,
                    want.inspect, got.inspect, err ? " (#{err})" : '')
      end
    end
    puts ''
    puts format('  UNITS = %s. The units enum is NOT documented in the V-Ray',
                UNITS_SCALAR.to_i.to_s)
    puts '  docs installed on this machine, so this tool stays on V-Ray\'s'
    puts '  own default scalar rather than guessing "1 = lumens". Intensity'
    puts '  is anchored to the 24"x48" @ 30 light that rendered correctly on'
    puts '  2026-08-28. If EVERY light is uniformly too bright or too dim by'
    puts '  roughly the same factor, that anchor is the thing to move'
    puts '  (REF_INTENSITY), or the area correction (AREA_NORMALIZED = 0.0).'
    if opts[:exposure]
      puts ''
      puts '  EXPOSURE IS STILL YOURS — nothing here writes it. Asset Editor'
      puts '  > Settings > Camera > Exposure Value 8 (or Auto Exposure). The'
      puts '  default EV 14.2 is full-sun exterior and renders ANY sane'
      puts '  interior rig 30-60x too dark. No lumen number fixes that.'
    end
  end
  # ==== END REPORT =========================================================

  def self.fmt(pt)
    format('(%.1f", %.1f", %.1f")', pt[0], pt[1], pt[2])
  end

  # ---- run ----------------------------------------------------------------

  def self.run
    model = Sketchup.active_model
    raise 'No model open.' unless model

    subjects, excluded = split_selection(model)
    handmade = excluded.select { |_, r| r == :vray }.map { |p| p[0] }
    own_count = excluded.count { |_, r| r == :own }
    puts '' unless excluded.empty?
    if own_count > 0
      puts "  #{own_count} light#{own_count == 1 ? '' : 's'} this tool " \
           'previously dropped are in the selection — never subjects.'
    end
    excluded.each do |e, r|
      next if r == :own
      what = r == :vray ? 'a V-Ray light' : "tagged \"#{TAG}\""
      puts "  \"#{display_name(e)}\" is #{what} — excluded: this tool " \
           'never lights a light.'
    end

    if subjects.empty?
      if handmade.any?
        names = handmade.map { |e| "\"#{display_name(e)}\"" }.join(', ')
        puts ''
        puts "REFUSED — only a light is selected (#{names}); a light is " \
             'never a lighting subject. Select the ROOM group instead.'
        UI.messagebox("#{names} is a V-Ray light, not a room — this tool " \
                      "never lights a light.\n\nSelect the ROOM group (the " \
                      'build-room group with the WR-Floor child) and press ' \
                      'again.')
      elsif excluded.any?
        UI.messagebox('The selection holds only lights (previously dropped ' \
                      "or tagged \"#{TAG}\") — nothing to light.\n\nSelect " \
                      'the room or booth groups and press again.')
      else
        msg = if model.selection.empty?
                'Nothing is selected.'
              else
                'The selection has no group or component in it — only ' \
                'loose geometry.'
              end
        UI.messagebox("#{msg}\n\nSelect the room or booth groups to light, " \
                      'then press Drop Interior Lights again. This tool ' \
                      'never guesses which things are rooms.')
      end
      return
    end

    opts = ask
    return unless opts # cancelled

    # THE API CHECK — before a single entity moves. There is no seed
    # fallback any more: if the V-Ray light API is not here, nothing can
    # be placed, and saying so now beats half a rig and a black render.
    why = vray_api_missing
    ctx = nil
    unless why
      ctx, why = vray_context
    end
    if why
      puts ''
      puts "REFUSED — #{why}"
      puts '  This tool builds every light through VRay::Command.' \
           'create_rectangle_light. Open V-Ray (any V-Ray toolbar button ' \
           'wakes it), make sure the render engine has loaded, and press ' \
           'again. Nothing was placed and nothing was removed.'
      UI.messagebox("The V-Ray light API is not available:\n\n#{why}\n\n" \
                    'Nothing was placed. Open V-Ray and press again.')
      return
    end
    scene = vray_scene(ctx)

    # Which layers this press is allowed to build. Every layer is now
    # buildable — including ACCENT, which never existed as a seed .skp and
    # so had been skipped on every press since this tool shipped.
    enabled = { :downlight => true, :wallwash => opts[:wash],
                :booth => opts[:booth], :accent => opts[:booth] }

    model.start_operation('Drop Interior Lights', true)
    begin
      ents  = model.active_entities
      layer = tag(model)
      etr = begin
              model.edit_transform
            rescue StandardError
              IDENT
            end

      # THE STALE SWEEP — recursive, world-space, and it takes the V-Ray
      # plugin with it. See collect_lights: the old sweep was flat and
      # local, so a press inside an open group doubled the rig.
      boxes = subjects.map { |sub| world_bounds(sub, etr) }
                      .select(&:valid?).map { |bb| box_of(bb) }
      stale, deep = stale_lights(model, boxes)
      erased, plugs_gone, plugs_left = erase_lights(model, scene, stale)

      puts ''
      puts "Drop Interior Lights — density #{opts[:density]}, brightness " \
           "#{opts[:bright]} (x#{opts[:mult]}), #{opts[:kelvin]}K, " \
           "wash #{opts[:wash] ? 'on' : 'off'}, booth #{opts[:booth] ? 'on' : 'off'}"
      unless stale.empty?
        puts format('  replaced %d previously dropped light%s (V-Ray ' \
                    'plugins: %d deleted, %d left behind)', erased,
                    erased == 1 ? '' : 's', plugs_gone, plugs_left)
        if plugs_left > 0
          puts '    A left-behind plugin is a light asset with no light — ' \
               'harmless in the render, but it clutters the Asset Editor. ' \
               'Lights dropped before 1.8.0 shared a seed asset and never ' \
               'owned a plugin to delete.'
        end
      end
      if deep
        puts "  NOTE: the stale sweep stopped at #{SWEEP_MAX_DEPTH} levels " \
             'of nesting. Lights buried deeper than that were NOT removed ' \
             'and this press may have stacked on top of them.'
      end
      unless etr.identity?
        puts '  NOTE: you are inside an open group/component. The lights ' \
             'land in THAT context, not at model top level — press Esc to ' \
             'close the edit first if that is not what you want. The ' \
             'stale sweep works in world coordinates either way.'
      end
      puts '  room lights mount FLUSH with the wall top (Benton, 2026-08-27: ' \
           'a 6" drop drew a "light line" on the walls). A room with a real ' \
           'ceiling SLAB would bury a flush light — none of ours has one; ' \
           "booth interior lights sit #{BOOTH_DROP.to_i}\" below the booth top."

      placed = 0
      layers_rep = {}

      # ONE V-Ray light per call — that is the whole point of the rebuild.
      # Each light gets its own plugin, so its own brightness and colour.
      # Creating a light is a V-Ray-scene change and V-Ray's scene is NOT
      # on SketchUp's undo stack: if this press aborts, the SketchUp side
      # rolls back and the plugins it made may stay in the Asset Editor.
      place = lambda do |role, pt, target_lm, extra_tr = nil|
        spec = LIGHT_LAYERS[role]
        d, plug = create_light(ctx, spec[:u], spec[:v])
        rpt = configure_light(plug, role, target_lm, opts[:kelvin])
        t = Geom::Transformation.translation(Geom::Point3d.new(*pt))
        if FACE_FLIP != 0.0
          t = t * Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                                Geom::Vector3d.new(1, 0, 0),
                                                FACE_FLIP.degrees)
        end
        t = t * extra_tr if extra_tr
        inst = ents.add_instance(d, t)
        if inst.nil?
          raise "add_instance failed (#{role}) — the V-Ray light was " \
                'created but could not be placed in the model.'
        end
        inst.layer = layer
        inst.set_attribute(DICT, 'seed', spec[:label])
        inst.set_attribute(DICT, 'role', role.to_s)
        inst.set_attribute(DICT, 'plugin', plugin_name(plug))
        placed += 1
        prev = layers_rep[role]
        if prev.nil?
          layers_rep[role] = rpt.merge(
            :count => 1, :target => target_lm.to_f,
            :intensity => scalar_intensity(target_lm, spec[:u], spec[:v]))
        else
          prev[:count] += 1
          prev[:bad] = (prev[:bad] + rpt[:bad]).uniq
          rpt[:writes].each { |w| prev[:writes] << w unless w[3] }
        end
        inst
      end

      subjects.each do |s|
        name = display_name(s)
        unless s.bounds.valid?
          puts "  SKIPPED #{name} — empty bounding box"
          next
        end

        # A selected booth is merchandise, not a room: it gets the interior
        # light only (the old tool's booth behaviour, scoped to booths).
        if booth?(s)
          bb = s.bounds
          c = Geom::Point3d.new((bb.min.x + bb.max.x) / 2.0,
                                (bb.min.y + bb.max.y) / 2.0,
                                (bb.min.z + bb.max.z) / 2.0)
          host = subjects.find { |o| o != s && !booth?(o) && o.bounds.valid? && o.bounds.contains?(c) }
          if host
            puts "  #{name}: booth sits inside selected room " \
                 "\"#{display_name(host)}\" — handled with that room."
            next
          end
          if enabled[:booth]
            bb = s.bounds
            pt = [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0,
                  bb.max.z - BOOTH_DROP]
            lm = booth_lumens((bb.max.x - bb.min.x) * (bb.max.y - bb.min.y), opts[:mult])
            place.call(:booth, pt, lm)
            puts "  #{name}: selected booth — 1 interior light at #{fmt(pt)}, " \
                 "target #{lm} lm"
          else
            puts "  #{name}: selected booth but the Booth layer is switched " \
                 'off in the dialog — nothing placed here.'
          end
          next
        end

        info = room_info(s)
        if info[:degenerate]
          puts "  REFUSED #{name} — its WR-Floor group has no usable face " \
               '(zero-area floor). Fix the floor or explode/rebuild the room.'
          next
        end

        poly = info[:poly]
        h = info[:z_top] - info[:z0]
        area = poly_area(poly)

        # Subject sanity FIRST: a 24"-tall component or a shoebox footprint
        # is a fixture or a part, never a room (the light-as-room incident).
        veto = subject_veto(h, area)
        if veto
          puts "  REFUSED #{name} — #{veto}"
          puts '    Select the ROOM group instead (a build-room room — the ' \
               'group with the WR-Floor child).'
          next
        end

        # Every accommodation this subject needs is COLLECTED first; lights
        # are placed only after fallback_verdict allows it. One fallback is
        # helpful; more than one means the selection is not the room this
        # tool assumed — see fallback_verdict.
        fallbacks = []
        if info[:fallback]
          fallbacks << 'no WR-Floor child: bounding-box rectangle used as the floor'
          puts "  #{name}: NO WR-Floor child found — using the BOUNDING-BOX " \
               'rectangle as the floor. Right for rectangular things; an ' \
               'L-shaped room needs its build-room floor group.'
        end
        if info[:no_walls]
          fallbacks << 'no Walls child: ceiling taken from the group top'
          puts "  #{name}: no Walls child — ceiling taken from the group top."
        end

        z_m = info[:z_top] - DROP

        obst, room_sibs = obstructions(model, s, poly, z_m, subjects)
        # The 2026-08-27 "keep-out: ROOM 2" incident: a neighbouring
        # L-shaped room's bounding box overlapped this room's floor and
        # punched a hole in the grid. Rooms are never keep-outs — but a
        # skipped room is NAMED, so a genuinely-overlapping one cannot
        # vanish silently.
        room_sibs.each do |e|
          puts "  #{name}: sibling \"#{display_name(e)}\" overlaps this " \
               "room's footprint but is itself a ROOM (it has its own " \
               'floor child) — never a keep-out. An L-shaped ' \
               "neighbour's bounding box covers its notch; only " \
               'furniture and booths cut the grid.'
        end
        keepouts = obst.map { |o| o[:rect] }
        booths = obst.select { |o| booth?(o[:ent]) }
        # Untagged booths, recognized by size (the live booth that carried
        # no WR-Booth-* tags and left the booth layers silently idle).
        obst.each do |o|
          next if booth?(o[:ent])
          bb = o[:bb]
          next unless booth_like?(bb.max.x - bb.min.x, bb.max.y - bb.min.y,
                                  bb.max.z - bb.min.z)
          booths << o
          puts format('  %s: "%s" carries no WR-Booth-* tag but is ' \
                      'booth-sized (%.0f" x %.0f" x %.0f" — catalog ' \
                      'booths run 32-188" a side, ~83-85" tall) — ' \
                      'treated as a booth.', name, display_name(o[:ent]),
                      bb.max.x - bb.min.x, bb.max.y - bb.min.y,
                      bb.max.z - bb.min.z)
        end

        # A — ambient grid (computed now, placed only after the verdict)
        grid = grid_points(poly, h, opts[:density], keepouts)
        if grid[:fallback]
          fallbacks << 'grid fully culled: single light at the floor centroid'
          # The cull ACCOUNTING — the live UTHSC incident printed only
          # "fully culled" and finding the offending keep-out took another
          # round trip. Say what was generated, what each test rejected,
          # and name every keep-out with its inflated rectangle.
          d = grid[:diag]
          puts "  #{name}: grid fully culled — single light at the floor " \
               'centroid instead. The breakdown:'
          puts format('    %d candidate%s at %.0f" spacing: %d outside the ' \
                      'floor polygon, %d nearer than %.1f" to an edge, %d ' \
                      'inside a keep-out.', d[:cand],
                      d[:cand] == 1 ? '' : 's', grid[:s], d[:out],
                      d[:edge], d[:thr], d[:keep])
          if obst.empty?
            puts '    No keep-outs exist — the culling is the polygon/edge ' \
                 'tests alone (tiny room).'
          else
            obst.each do |o|
              r = o[:rect]
              puts format('    keep-out: "%s"%s — XY (%.0f, %.0f)-(%.0f, ' \
                          '%.0f) incl. %.0f" pad, top at %.0f"',
                          display_name(o[:ent]),
                          booth?(o[:ent]) ? ' (booth)' : '',
                          r[0], r[1], r[2], r[3], KEEPOUT_PAD, o[:bb].max.z)
            end
          end
        end
        if grid[:pts].empty?
          puts "  REFUSED #{name} — no valid point found inside its floor."
          next
        end

        # B — wall-wash wall choice (also decided before the verdict)
        wall_i = nil
        wps = []
        if opts[:wash] && enabled[:wallwash]
          door = info[:doors].max_by { |d| d[:w] }
          if door
            puts "  #{name}: door#{info[:doors].size == 1 ? '' : 's'} found " \
                 "via #{info[:door_mech]}."
            wall_i = opposite_edge(poly, nearest_edge(poly, door[:cx], door[:cy]))
            puts "  #{name}: wall wash could not find a wall opposite the door — skipped." if wall_i.nil?
          else
            # No doors readable (bbox fallback or door-less room): wash the
            # longest wall and say so — and say what the door search
            # actually looked at, so a detection miss is visible without
            # another live round trip.
            puts "  #{name}: door search came up empty — #{info[:door_diag]}." if info[:door_diag]
            n = poly.size
            wall_i = (0...n).max_by do |i|
              a = poly[i]
              b = poly[(i + 1) % n]
              (b[0] - a[0])**2 + (b[1] - a[1])**2
            end
            fallbacks << 'no door found: washing the longest wall'
            puts "  #{name}: no door found — washing the LONGEST wall instead " \
                 'of the one opposite a door.'
          end
          wps = wall_i ? wash_points(poly, wall_i, keepouts) : []
        end

        # THE MULTI-FALLBACK RULE — nothing has been placed for this
        # subject yet, so refusing here refuses it whole.
        verdict = fallback_verdict(fallbacks)
        if verdict
          puts "  REFUSED #{name} — #{verdict}"
          puts '    Select the ROOM group itself (a build-room room has a ' \
               'WR-Floor child). A legacy room with no WR-Floor can still ' \
               'be lit with Layers = "Ambient only" or "Ambient + booth" — ' \
               'that keeps it to the one bounding-box fallback.'
          next
        end

        lm = downlight_lumens(area, grid[:pts].size, opts[:mult])
        grid[:pts].each { |p| place.call(:downlight, [p[0], p[1], z_m], lm) }
        puts format('  %s: ambient %d light%s, spacing %.0f", ceiling %.0f", ' \
                    'target %d lm per fixture', name, grid[:pts].size,
                    grid[:pts].size == 1 ? '' : 's', grid[:s], h, lm)
        obst.each do |o|
          puts "    keep-out: #{display_name(o[:ent])}" \
               "#{booth?(o[:ent]) ? ' (booth)' : ''}"
        end

        if wall_i
          if wps.empty?
            puts "  #{name}: every wall-wash position was culled — layer skipped here."
          else
            wash_lm = LIGHT_LAYERS[:wallwash][:lm] * opts[:mult]
            wps.each { |p| place.call(:wallwash, [p[0], p[1], z_m], wash_lm) }
            puts format('  %s: wall wash %d light%s at 24" standoff on wall ' \
                        'run %d: %s', name, wps.size, wps.size == 1 ? '' : 's',
                        wall_i + 1, wps.map { |p| format('(%.0f, %.0f)', p[0], p[1]) }.join(' '))
          end
        end

        # C — the booth is the merchandise
        if opts[:booth]
          if booths.empty?
            puts "  #{name}: no booth found in this room (looked for " \
                 'WR-Booth-* tags, then for an untagged booth-sized box ' \
                 '32-188" a side, 78-94" tall) — booth layers have ' \
                 'nothing to do.'
          end
          booths.each do |o|
            bname = display_name(o[:ent])
            bb = o[:bb]
            if enabled[:booth]
              pt = [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0,
                    bb.max.z - BOOTH_DROP]
              lm = booth_lumens((bb.max.x - bb.min.x) * (bb.max.y - bb.min.y), opts[:mult])
              place.call(:booth, pt, lm)
              puts "  #{name}: booth \"#{bname}\" interior light at #{fmt(pt)}, " \
                   "target #{lm} lm"
            end
            if enabled[:accent]
              dc = booth_door_center(o)
              if dc.nil?
                puts "  #{name}: booth \"#{bname}\" has no WR-Booth-Door tagged " \
                     'panel — accent skipped.'
              else
                bcx = (bb.min.x + bb.max.x) / 2.0
                bcy = (bb.min.y + bb.max.y) / 2.0
                ax = accent_axis(bcx - dc[0], bcy - dc[1]) # toward the booth
                dlen = Math.sqrt((dc[0] - bcx)**2 + (dc[1] - bcy)**2)
                if ax.nil? || dlen < 1e-6
                  puts "  #{name}: booth \"#{bname}\" door direction is " \
                       'degenerate — accent skipped.'
                else
                  ux = (dc[0] - bcx) / dlen
                  uy = (dc[1] - bcy) / dlen
                  apt = [dc[0] + ux * ACCENT_OUT, dc[1] + uy * ACCENT_OUT, z_m]
                  if point_in_poly?(apt[0], apt[1], poly)
                    rot = Geom::Transformation.rotation(
                      Geom::Point3d.new(0, 0, 0),
                      Geom::Vector3d.new(ax[0], ax[1], 0),
                      ACCENT_TILT.degrees)
                    place.call(:accent, apt,
                               LIGHT_LAYERS[:accent][:lm] * opts[:mult], rot)
                    puts "  #{name}: booth \"#{bname}\" accent at #{fmt(apt)}, " \
                         "tilted #{ACCENT_TILT.to_i} deg onto the door face"
                  else
                    puts "  #{name}: accent position for \"#{bname}\" lands " \
                         'outside the floor — skipped.'
                  end
                end
              end
            end
          end
        end
      end

      raise 'Nothing was placed — see the per-room lines above.' if placed.zero?
      model.commit_operation

      print_light_report(layers_rep, opts)
      puts ''
      bad = layers_rep.values.map { |r| r[:bad] }.flatten.uniq
      if bad.empty?
        puts '  WILL IT EMIT: every light was made by V-Ray itself and owns ' \
             'its own plugin, and every parameter written read back the ' \
             'value it was given. There is no seed and no shared asset.'
      else
        puts "  WILL IT EMIT: the lights are real V-Ray lights, but " \
             "#{bad.map(&:to_s).join(', ')} did not read back — check those " \
             'in the Asset Editor before rendering (details above).'
      end
      puts "  #{placed} light#{placed == 1 ? '' : 's'} in #{subjects.size} " \
           "container#{subjects.size == 1 ? '' : 's'}. Ctrl+Z removes the " \
           'lights (their V-Ray plugins may linger in the Asset Editor — ' \
           'a re-press deletes the ones it replaces). Move tool and eraser ' \
           'fine-tune.'
    rescue StandardError => e
      model.abort_operation
      # SketchUp's undo stack owns the geometry; V-Ray's scene does not sit
      # on it. Any light plugins made before the failure are still in the
      # Asset Editor with no instance to go with them. Say so — an
      # unexplained pile of orphan light assets is how a tool loses trust.
      if placed && placed > 0
        puts "  NOTE: #{placed} V-Ray light plugin#{placed == 1 ? '' : 's'} " \
             'had already been created when this failed. The SketchUp side ' \
             'rolled back; those plugins may remain in the Asset Editor as ' \
             'lights with no instance. Delete them there if they bother you.'
      end
      raise e
    end
  end
end

begin
  WR_DropLights.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n") if e.backtrace
  UI.messagebox("Drop Interior Lights failed:\n\n#{e.message}\n\nSee the Ruby Console.")
end
