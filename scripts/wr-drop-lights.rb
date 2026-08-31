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
# UNITS — LUMENS, AGAINST A CONSIDERED INTERIOR EXPOSURE
#
# SUPERSEDED at 1.9.9, and the correction is the foundation of this rewrite.
# Up to 1.9.8 this file said the units enum was unproven and stayed on
# V-Ray's default scalar, with an area correction it called "the weakest
# link in this file". Both are gone:
#
#   units = 1   Luminous Power (Lumens). intensity is TOTAL OUTPUT and is
#               SIZE-INDEPENDENT, so the area term has nothing to correct
#               and REF_INTENSITY / REF_AREA / REF_LUMENS / AREA_NORMALIZED
#               are all deleted — four constants going away together.
#
# What made lumens usable is the exposure. V-Ray's factory physical camera
# is f/8 @ 1/300 @ ISO 100 = EV 14.23, which is a FULL-SUN EXTERIOR
# exposure (observed). A 40 fc interior wants EV 8.8-9.1 by photometry
# (L = rho*E/pi, EV = log2(L*8), derived), and the one arm of the 148-frame
# sun-off sweep where the fixtures alone served both cameras was EV 9.5
# (observed). Three lines converge, so this tool writes ONE interior
# exposure — f/8 @ 1/300 @ ISO 3200 = EV 9.23, exactly five stops of pure
# ISO gain — ONCE, and then leaves the camera alone forever. See
# stamp_exposure! for the five guards on that write.
#
# The payoff is that every number in LIGHT_LAYERS is now a real product
# number: 2,000 lm 18" flush mount, 1,200 lm drum pendant, 600 lm sconce,
# 2,800 lm track head, 1,600 lm wall washer, 800 lm booth light, 400 lm
# graze strip. Benton can hold each against a product page.
#
# ===========================================================================
# ===========================================================================
# WHAT A PRESS DOES — ONE OPERATION, ONE Ctrl+Z
#
#   1. Reads the selection: groups and component instances only — it never
#      guesses which things in a model are rooms, and it NEVER lights a
#      light: its own dropped lights, any V-Ray light, and anything tagged
#      "WR Lights" are refused as subjects by name.
#   2. Pops the settings dialog — TWO dropdowns, Brightness and Warmth.
#      The exposure question is gone: exposure is written ONCE as a
#      documented default (see stamp_exposure!), never asked per press.
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
#   6. Draws the visible fixtures (F1/F2/F3) as its OWN groups around the
#      emitters, borrows a ceiling for the room if it has none, tags all of
#      it "WR Lights", stamps that tag into every saved scene, and prints,
#      per layer, the size, units, lumens, Kelvin and RGB actually written
#      — plus every write that did not stick.
#
# Lights go in the CURRENT drawing context, never inside the client's room
# group, so coordinates agree with the selections' own bounding boxes.
#
# ===========================================================================
# RUN LIVE 2026-08-30 — AND IT WAS BROKEN IN TWO SILENT WAYS
#
# 1.8.0 wrote everything below without a SketchUp on the machine. It was
# first run for real on 2026-08-30, SketchUp 2026 / V-Ray 7, through
# scripts/sketchup-bridge.py, on a scratch 16' x 12' build-room room. Two
# defects were found, both of which made a clean-looking press produce a
# rig that could not do its job, and both are fixed here (1.9.1):
#
#   1. EVERY PER-LIGHT WRITE WAS DISCARDED. plugin[key] = value outside a
#      VRay::Scene#change transaction does not persist; V-Ray re-syncs the
#      plugin from the JSON in the light DEFINITION's VRayPlugins
#      dictionary and the write is gone. All eight lights of the first
#      live press read back V-Ray's factory defaults minutes later —
#      intensity 30, invisible FALSE, i.e. visible white slabs at the
#      wrong brightness. The read-back this file already had reported a
#      clean press, because it read the same in-memory object right after
#      the write. See write_params / read_param.
#   2. THE SECOND PRESS KILLED THE RIG. Removing the replaced lights'
#      definitions schedules a deferred V-Ray purge by plugin name, and
#      the new lights inherit those freed names. 8 instances, 0 light
#      plugins. See erase_lights / reap_lights.
#
# What is CONFIRMED live now: 4 lights in a 16x12 room (not 6); every
# parameter persists into later sessions; Dim/Normal/Bright read back
# 128/256/512 on the downlights; a second and third press leave the count
# at 8 with 8 live plugins; the light widget's direction arrow runs to
# (0, 0, -7.41), so the fixture faces DOWN and FACE_FLIP stays 0.0.
#
# SUPERSEDED at 1.9.9: the rig HAS now been rendered — six 1600x900 frames,
# .forge/builder/rig-build-results.json. REF_INTENSITY and AREA_NORMALIZED
# no longer exist to be judged; the exposure is settled at EV 9.23.
#
# python scripts/rbparse.py proves this file parses (the same CRuby 3.2
# SketchUp ships) and python scripts/rbtest-lights.py RUNS the whole pure
# section — grid, polygon tests, L-shape, keep-outs, tiny-room centroid,
# wall wash, lumens, the Kelvin curve, the scalar-intensity formula, the
# read-back comparator and the grid-count fix — outside SketchUp, lifted
# verbatim from this file. Every VRay:: call is individually rescued so a
# wrong assumption becomes a NAMED failure on the console, never a crash
# and never a silent no-op.

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

  # --- THE SEVEN-ROLE LAYER TABLE -----------------------------------------
  # Spec: .forge/scoper/layered-light-rig.md §6. The rig runs in LUMENS
  # (units = 1), so :lumens is what is WRITTEN, not a design figure something
  # else is measured against, and every visible number is a real product
  # number a client could hold against a product page (reported, spec §7.4).
  #
  #   :n         instances of this role a full rig places
  #   :emitter   :rect (create_rectangle_light) or :sphere (create_sphere_light)
  #   :u / :v    rectangle size in inches; for a sphere :u is the DIAMETER
  #   :emitters  emitters per fixture (the sconce cylinder throws up AND down)
  #   :lumens    per INSTANCE at Brightness = Normal, before the enclosure trim
  #   :kelvin    per LAYER — six temperatures across the rig, 2700 K to 5000 K
  #   :budget    :room (trimmed when the room is open) or :booth (never trimmed)
  #   :visible   invisible = 0 — the emitter is SEEN. Five layers are.
  #   :fixture   the procedural fixture group drawn around it, or nil
  #   :disc      rectangle lights only: write is_disc = 1 (observed present)
  #   :tilt      degrees off vertical, aimed booth-relative
  #   :dir       Directionality, or nil to leave the parameter alone
  LIGHT_LAYERS = {
    :ceiling => { :label => 'Ceiling ambient', :n => 2, :emitter => :rect,
                  :u => 17.5, :v => 17.5, :emitters => 1, :lumens => 2000.0,
                  :kelvin => 3500, :budget => :room, :visible => true,
                  :fixture => :f1, :disc => true, :tilt => nil, :dir => nil },
    :key     => { :label => 'Key / booth face', :n => 1, :emitter => :rect,
                  :u => 24.0, :v => 24.0, :emitters => 1, :lumens => 2800.0,
                  :kelvin => 3200, :budget => :room, :visible => false,
                  :fixture => nil, :disc => false, :tilt => 35.0, :dir => 0.5 },
    :pendant => { :label => 'Pendant', :n => 1, :emitter => :sphere,
                  :u => 3.0, :v => 3.0, :emitters => 1, :lumens => 1200.0,
                  :kelvin => 2700, :budget => :room, :visible => true,
                  :fixture => :f2, :disc => false, :tilt => nil, :dir => nil },
    :sconce  => { :label => 'Sconce graze', :n => 2, :emitter => :sphere,
                  :u => 2.0, :v => 2.0, :emitters => 2, :lumens => 300.0,
                  :kelvin => 3000, :budget => :room, :visible => true,
                  :fixture => :f3, :disc => false, :tilt => nil, :dir => nil },
    :rim     => { :label => 'Rim / kicker', :n => 1, :emitter => :rect,
                  :u => 12.0, :v => 36.0, :emitters => 1, :lumens => 1600.0,
                  :kelvin => 5000, :budget => :room, :visible => false,
                  :fixture => nil, :disc => false, :tilt => 60.0, :dir => nil },
    :booth   => { :label => 'Booth interior', :n => 1, :emitter => :rect,
                  :u => 12.0, :v => 24.0, :emitters => 1, :lumens => 800.0,
                  :kelvin => 4000, :budget => :booth, :visible => false,
                  :fixture => nil, :disc => false, :tilt => nil, :dir => nil },
    :foam    => { :label => 'Foam graze', :n => 1, :emitter => :rect,
                  :u => 4.0, :v => 36.0, :emitters => 1, :lumens => 400.0,
                  :kelvin => 3500, :budget => :booth, :visible => false,
                  :fixture => nil, :disc => false, :tilt => nil, :dir => nil }
  }.freeze

  # Roles that only exist when a booth stands in the room.
  BOOTH_ROLES = [:key, :rim, :booth, :foam].freeze

  # --- UNITS, and the four constants that went away -----------------------
  # UNITS_SCALAR / REF_INTENSITY / REF_AREA / REF_LUMENS / AREA_NORMALIZED
  # are DELETED at 1.9.9. In Luminous Power mode intensity is total output
  # and size-independent, so the area term — the weakest link in this file
  # since 1.8.0 — has nothing left to correct.
  UNITS_LUMENS    = 1.0    # `units` = 1 = Luminous Power (Lumens).
  FACE_FLIP       = 0.0    # degrees about X applied to every light. 0 =
                           #   the created light already faces DOWN.

  # --- the exposure stamp (spec §4) ---------------------------------------
  # ONE interior exposure, written ONCE, ISO ONLY, and only from the factory
  # ISO. f/8 @ 1/300 @ ISO 3200 = EV 9.23. Five stops off V-Ray's factory
  # full-sun-exterior default, and 0.13 stops from the photometric target for
  # a 40 fc interior at rho = 0.50 (derived, spec §4).
  EXPO_ISO         = 3200.0
  EXPO_FACTORY_ISO = 100.0
  EXPO_EV          = 9.23
  EXPO_F           = 8.0     # NEVER written — read back and asserted unmoved
  EXPO_SHUTTER     = 300.0   # NEVER written — read back and asserted unmoved

  # THE NEVER-WRITE LIST, with the reason at the site. Everything outside the
  # single ISO stamp above is Benton's. A tool that quietly retunes a render
  # setting is indistinguishable from a bug in the render.
  NEVER_WRITE = ['/SettingsOutput',       # image size, safe frames — his
                 '/SunLight',             # sun is his dressing decision
                 '/SettingsEnvironment',  # sky, GI and background multipliers
                 '/SettingsImageSampler', # quality — "Medium" is his choice
                 '/CameraPhysical except ISO'].freeze

  # --- the reference room the lumen table is quoted for (spec §6) ----------
  # "Lumens are for a capped room, sun off, EV 9.23, Brightness = Normal, in
  # the 192 sq ft reference room; THEY SCALE WITH FLOOR AREA via the budget."
  # Without this a 20'x16' room gets a 16'x12' room's light and meters 0.74
  # stops under (observed: mean luminance 0.093 on the first live frame).
  REF_ROOM_SQFT  = 192.0
  REF_BOOTH_SQFT = 24.0
  AREA_SCALE_MIN = 0.5    # a tiny room still wants a usable fixture
  AREA_SCALE_MAX = 3.0    # and a hall does not get a stadium's worth

  # --- enclosure trims (spec §6; derived from the sun-off sweep) -----------
  TRIM_OPEN4 = 0.35      # no ceiling, 4 walls  (-1.5 stops, observed cost)
  TRIM_OPEN3 = 0.25      # no ceiling, 3 walls  (-2 stops)

  # --- fixture geometry (spec §7.2; dimensions reported, §7.4) ------------
  SEG            = 16    # segments per circle. The spec asks for 24; at 24
                         #   the five fixtures cost ~590 faces and the 600
                         #   budget has no headroom, so this ships at 16 and
                         #   says so. One constant.
  FIXTURE_FACES_MAX = 600
  F1_DRUM_R      = 9.0   # 18" flush drum
  F1_DRUM_H      = 3.5
  F1_SHELL       = 0.125
  F1_EMIT_UP     = 0.25  # emitter sits this far inside the open bottom
  F2_SHADE_BOT_R = 8.0   # 16" bottom
  F2_SHADE_TOP_R = 5.0   # 10" top
  F2_SHADE_H     = 10.0
  F2_CANOPY_R    = 2.5
  F2_CANOPY_H    = 0.75
  F2_CORD_R      = 0.25
  F2_BULB_UP     = 4.0   # sphere centre above the shade bottom
  PENDANT_AFF    = 78.0  # shade bottom above finished floor (generalised)
  F3_CYL_R       = 2.5   # 5" cylinder
  F3_CYL_H       = 12.0
  F3_PLATE_D     = 0.5
  F3_PROJECT     = 3.0   # cylinder axis this far off the wall face
  F3_EMIT_OUT    = 0.5   # spheres this far outside each open end
  SCONCE_AFF     = 66.0  # mounting height (reported, 60-72" band)
  SCONCE_STANDOFF = 3.0

  # --- the rim and the foam graze ----------------------------------------
  RIM_OUT       = 30.0   # in from the booth centre, opposite the key
  RIM_TILT      = 60.0   # degrees, across the booth's back top edge
  FOAM_OFFSET   = 4.0    # in inside the booth's foam wall — grazing is about
                         #   ANGLE, and 4" across 2" of pyramid relief is what
                         #   makes the foam self-shadow instead of flatten
  CEIL_NAME     = 'WR Lights Ceiling'.freeze

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
    ax, ay = poly[wall_i]
    bx, by = poly[(wall_i + 1) % n]
    len = Math.sqrt((bx - ax)**2 + (by - ay)**2)
    return [] if len < 1e-6
    count = grid_count(len, WASH_SPACING * WASH_STANDOFF)
    count = 2 if count < 2
    count = 4 if count > 4
    wall_points(poly, wall_i, WASH_STANDOFF, count, keepouts)
  end

  # THE BUDGET ARITHMETIC, kept and no longer used to set anything. At 1.9.9
  # the per-layer lumen figures come from LIGHT_LAYERS (real product numbers)
  # scaled by area_scale, not from a share of this. These two remain because
  # they ARE the design doc's budget and the layer table is checked against
  # them: 320 sq ft x 40 fc / 0.6 = 21,333 lm against the rig's 18,000, the
  # deliberate 16% under-spend explained in the spec (three of the five room
  # sources throw sideways and upward, so the room meters lower and looks
  # better). rbtest-lights.py exercises both.
  #
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

  # Enclosure trim for the ROOM budget only (spec §6). Booth-side roles never
  # trim — the sky was never getting into the booth (observed: capping costs
  # the room view ~1.5 stops and the booth interior 4%).
  def self.enclosure_trim(capped, walls)
    return 1.0 if capped
    walls >= 4 ? TRIM_OPEN4 : TRIM_OPEN3
  end

  # The lumen table is quoted for a 192 sq ft room; a real room is not that
  # room. Clamped both ways so the scaling can never run away.
  def self.area_scale(area_sqin, ref_sqft)
    return 1.0 if area_sqin.nil? || area_sqin <= 0.0 || ref_sqft <= 0.0
    k = (area_sqin / 144.0) / (ref_sqft * 1.0)
    return AREA_SCALE_MIN if k < AREA_SCALE_MIN
    return AREA_SCALE_MAX if k > AREA_SCALE_MAX
    k
  end

  # What ONE instance of a layer actually gets written, in lumens. This is the
  # whole of the intensity calculation now: no area term, no reference light,
  # no scalar anchor. In Luminous Power mode intensity IS the output.
  # THE RIG RENDERS ~10x DIMMER THAN ITS OWN LUMEN TABLE SAYS.
  #
  # Measured by eye, Benton, 2026-08-31, on a real press: the pendant landed
  # in V-Ray at 750 lm and "7500 looked more acceptable"; the sconce landed at
  # 187.5 and 1870.5 "looked much better". Both are exactly x10, and both are
  # the SPHERE roles, which is where he happened to look.
  #
  # WHY THIS IS A SEPARATE CONSTANT AND NOT A BIGGER TABLE. LIGHT_LAYERS'
  # :lumens are real product numbers -- the file's own contract is that every
  # visible figure is one a client could hold against a product page. Ten-xing
  # the table would quietly break that and leave nobody able to tell a
  # calibration fudge from a spec. So the table stays honest and the
  # discrepancy lives here, in one number, named, with the evidence for it.
  #
  # It is a CALIBRATION, not a design figure: it says the units this rig
  # writes do not land where a lumen should in this scene. If the real cause
  # is ever found -- V-Ray's unit interpretation, or the physical camera's
  # exposure, which proposal-package.rb already documents as the dominant
  # lever -- this is the number that goes back to 1.0.
  #
  # NOT ALL SEVEN ROLES WERE EYEBALLED. Two spheres were. The five rectangle
  # roles are carried along on the same factor because Benton's report was
  # "everything was quite too dim to begin with", and because lumens is total
  # flux -- emitter size changes the softness of a shadow, not how much light
  # leaves it. If the rects come out hot, this is the knob.
  LUMEN_GAIN = 10.0

  def self.layer_lumens(base_lm, mult, trim)
    (base_lm * 1.0) * (mult * 1.0) * (trim * 1.0) * LUMEN_GAIN
  end

  # Global Kelvin offset from the Warmth answer. Warm = the table as written;
  # Neutral = every layer +500 K. It SHIFTS the palette; it never flattens it.
  def self.layer_kelvin(base_k, offset)
    (base_k + offset)
  end

  # n points evenly around a circle. Every drum, cone and cylinder shell in
  # §7 is built from two of these, so it is the one piece of fixture geometry
  # maths worth running outside SketchUp.
  def self.ring_points(cx, cy, r, n)
    return [] if n < 3 || r <= 0.0
    (0...n).map do |i|
      a = 2.0 * Math::PI * i / n
      [cx + r * Math.cos(a), cy + r * Math.sin(a)]
    end
  end

  # Faces a two-ring shell of n segments costs: outer, inner, and the two rims.
  def self.shell_faces(n)
    4 * n
  end

  # Total faces the fixtures on one room will add, so the budget assertion is
  # arithmetic and not a guess. F1 and F3 are annular tubes (4n side/rim faces
  # + 1 cap); F2 is a cone shell plus two small solids of (n + 2) each.
  def self.fixture_faces(n_f1, n_f2, n_f3, seg)
    n_f1 * (shell_faces(seg) + 1) +
      n_f2 * (shell_faces(seg) + 2 * (seg + 2)) +
      n_f3 * (shell_faces(seg) + (seg + 2))
  end

  # Generalised wall row: `count` points at `standoff` into the room off wall
  # `wall_i`, centred on the run, culled by the floor polygon and the
  # keep-outs. wash_points is this at the wash standoff with its 2-4 clamp;
  # the sconce pair is this at 3" with count 2.
  def self.wall_points(poly, wall_i, standoff, count, keepouts)
    n = poly.size
    ccw = poly_signed_area(poly) > 0
    ax, ay = poly[wall_i]
    bx, by = poly[(wall_i + 1) % n]
    dx = bx - ax
    dy = by - ay
    len = Math.sqrt(dx * dx + dy * dy)
    return [] if len < 1e-6 || count < 1
    ux = dx / len
    uy = dy / len
    nx0 = ccw ? -uy : uy
    ny0 = ccw ? ux : -ux
    axis_points(len, count).map do |t|
      [ax + ux * t + nx0 * standoff, ay + uy * t + ny0 * standoff]
    end.select do |p|
      point_in_poly?(p[0], p[1], poly) && !in_keepout?(p[0], p[1], keepouts)
    end
  end

  # The sconce pair: two fixtures 3" off the wall, at wash spacing.
  def self.sconce_points(poly, wall_i, keepouts)
    wall_points(poly, wall_i, SCONCE_STANDOFF, 2, keepouts)
  end

  # The inward unit normal of wall run i — the direction a sconce faces and
  # the direction its backplate is pushed.
  def self.wall_normal(poly, wall_i)
    n = poly.size
    ccw = poly_signed_area(poly) > 0
    ax, ay = poly[wall_i]
    bx, by = poly[(wall_i + 1) % n]
    dx = bx - ax
    dy = by - ay
    len = Math.sqrt(dx * dx + dy * dy)
    return nil if len < 1e-6
    ux = dx / len
    uy = dy / len
    ccw ? [-uy, ux] : [uy, -ux]
  end

  # The polygon corner furthest from (bx, by), pulled `inset` toward the
  # floor centroid so the pendant hangs in the room and not inside a wall.
  def self.far_corner(poly, bx, by, inset)
    return nil if poly.size < 3
    c = poly_centroid(poly)
    best = poly.max_by { |p| (p[0] - bx)**2 + (p[1] - by)**2 }
    dx = c[0] - best[0]
    dy = c[1] - best[1]
    d = Math.sqrt(dx * dx + dy * dy)
    return [c[0], c[1]] if d < 1e-6
    t = [inset / d, 1.0].min
    [best[0] + dx * t, best[1] + dy * t]
  end

  # The two grid points furthest from the booth — the ceiling ambient pair.
  # With no booth, the two furthest from each other, so the pair spreads.
  def self.ceiling_pair(pts, bx, by)
    return pts if pts.size <= 2
    if bx.nil? || by.nil?
      best = nil
      best_d = -1.0
      pts.each_with_index do |a, i|
        pts.each_with_index do |b, j|
          next if j <= i
          d = (a[0] - b[0])**2 + (a[1] - b[1])**2
          if d > best_d
            best_d = d
            best = [a, b]
          end
        end
      end
      return best
    end
    pts.sort_by { |p| -((p[0] - bx)**2 + (p[1] - by)**2) }.first(2)
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


  # Make ONE V-Ray sphere light of radius r. Same contract as create_light:
  # returns [ComponentDefinition, Plugin] or RAISES with its arguments in the
  # message. A sphere reads round from every angle and is physically exactly
  # "a bulb in a shade", which is why every emitter inside a shade is one
  # (spec §7.1) — and it needs no unproven parameter.
  def self.create_sphere(ctx, r)
    o = begin
          VRay::Command.create_sphere_light(:context => ctx, :radius => r.to_f)
        rescue StandardError, ScriptError => e
          raise "VRay::Command.create_sphere_light(radius: #{r}) raised " \
                "#{e.class}: #{e.message}"
        end
    raise "create_sphere_light(radius: #{r}) returned nil" if o.nil?
    d = (o.entity rescue nil)
    p = (o.plugin rescue nil)
    unless d.is_a?(Sketchup::ComponentDefinition)
      raise "create_sphere_light gave .entity of class #{d.class}, not a " \
            'Sketchup::ComponentDefinition — the API changed shape.'
    end
    raise 'create_sphere_light gave a nil .plugin' if p.nil?
    [d, p]
  end

  # ======================================================================
  # THE FIXTURES — drawn here, in Ruby, from primitives (spec §7)
  #
  # THE BINDING RULE, and it is not optional: fixture geometry NEVER goes
  # inside a V-Ray light definition. That definition is V-Ray's, it holds
  # zero faces, and removing it schedules a deferred purge by plugin name
  # that killed the whole rig once already (observed, 1.9.1 — see THE
  # SECOND-PRESS KILL above). So each fixture is its OWN group in the same
  # drawing context, the light instance is placed separately at the right
  # offset inside it, and BOTH carry the WR_DropLights dictionary so the
  # existing recursive world-space sweep removes both. No new sweep logic.
  #
  # NO MATERIAL IS EVER CREATED. lookdev-matrix.rb:446 did
  # `materials[X] || materials.add(X)` and its removal path never took the
  # material back — 37 materials where the model had 36 (observed). This
  # reuses an existing material by name if one is there and otherwise
  # leaves the default.
  #
  # KNOWN LIMITATION, stated rather than hidden: F2's shade renders OPAQUE.
  # A real fabric drum shade is a translucent diffuser and light escapes
  # through the shade wall; making ours glow needs a translucent V-Ray
  # material, and writing a newly created material plugin HANGS SketchUp
  # (observed, four force-kills). So the pendant reads as a shade with
  # light escaping top and bottom, not as a glowing lantern. F1 and F3 are
  # unaffected: F1's diffuser IS its visible emitter, and a real up/down
  # cylinder is opaque metal anyway.
  # ======================================================================

  # A solid disc: circle, face, extrude by h along +z (h may be negative).
  def self.disc_solid(ents, cx, cy, z, r, h, seg)
    c = ents.add_circle(Geom::Point3d.new(cx, cy, z),
                        Geom::Vector3d.new(0, 0, 1), r, seg)
    f = ents.add_face(c)
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    f
  end

  # An open-ended TUBE with a real wall thickness: outer circle, inner circle,
  # erase the inner disc, extrude the annulus. A shade must read as a shade
  # and not as a box — a single unshaded plane renders dark from inside and
  # gives the whole thing away (spec §7.3).
  def self.tube(ents, cx, cy, z, r_out, r_in, h, seg)
    before = ents.grep(Sketchup::Face)
    o = ents.add_circle(Geom::Point3d.new(cx, cy, z),
                        Geom::Vector3d.new(0, 0, 1), r_out, seg)
    f = ents.add_face(o)
    return nil if f.nil?
    # OBSERVED, 30 Aug 2026: adding the inner circle SPLITS the face that is
    # already there, so `add_face` on the inner loop returns NIL — the face
    # exists but was not created by that call. Erasing "the face add_face
    # returned" therefore erased nothing, left a solid disc, and the group
    # went away under the next call. Find the two coplanar faces by AREA
    # instead: the annulus is the small one, the inner disc the large one.
    ents.add_circle(Geom::Point3d.new(cx, cy, z),
                    Geom::Vector3d.new(0, 0, 1), r_in, seg)
    fresh = (ents.grep(Sketchup::Face) - before).select(&:valid?)
    return nil if fresh.empty?
    ring = fresh.min_by { |x| x.area }
    disc = fresh.max_by { |x| x.area }
    disc.erase! if disc && ring && !disc.equal?(ring)
    return nil unless ring && ring.valid?
    ring.reverse! if ring.normal.z < 0
    ring.pushpull(h)
    ring
  end

  # A truncated-cone SHELL — the pendant shade. Built as an explicit polygon
  # mesh because a lofted cone has no pushpull: outer wall, inner wall offset
  # by t, and a rim quad at each end so no edge is a one-sided surface.
  def self.cone_shell(ents, cx, cy, z_bot, r_bot, r_top, h, t, seg)
    ob = ring_points(cx, cy, r_bot, seg)
    ot = ring_points(cx, cy, r_top, seg)
    ib = ring_points(cx, cy, r_bot - t, seg)
    it = ring_points(cx, cy, r_top - t, seg)
    zt = z_bot + h
    mesh = Geom::PolygonMesh.new
    p3 = lambda { |xy, z| Geom::Point3d.new(xy[0], xy[1], z) }
    seg.times do |i|
      j = (i + 1) % seg
      mesh.add_polygon(p3.call(ob[i], z_bot), p3.call(ob[j], z_bot),
                       p3.call(ot[j], zt),    p3.call(ot[i], zt))
      mesh.add_polygon(p3.call(it[i], zt),    p3.call(it[j], zt),
                       p3.call(ib[j], z_bot), p3.call(ib[i], z_bot))
      mesh.add_polygon(p3.call(ot[i], zt),    p3.call(ot[j], zt),
                       p3.call(it[j], zt),    p3.call(it[i], zt))
      mesh.add_polygon(p3.call(ib[i], z_bot), p3.call(ib[j], z_bot),
                       p3.call(ob[j], z_bot), p3.call(ob[i], z_bot))
    end
    ents.add_faces_from_mesh(mesh, 12)
    mesh
  end

  # Reuse a model material by NAME if one is there; never create one.
  def self.borrow_material(model, names)
    names.each do |n|
      m = (model.materials[n] rescue nil)
      return m if m
    end
    nil
  end

  # F1 — flush ceiling drum, 18" across, 3.5" deep, OPEN BOTTOM. The emitter
  # disc IS the diffuser, which is how a real flush mount is built, and it is
  # why role 1 is both the general layer and the room's obvious light source.
  # Returns [group, emitter_z].
  def self.build_f1(ents, model, cx, cy, z_ceil, mat)
    g = ents.add_group
    g.name = 'WR Fixture F1 flush drum'
    z_bot = z_ceil - F1_DRUM_H
    tube(g.entities, cx, cy, z_bot, F1_DRUM_R, F1_DRUM_R - F1_SHELL,
         F1_DRUM_H, SEG)
    # NO TOP CAP. The drum is FLUSH against the ceiling, so a cap disc would
    # be coplanar with the tube's own top ring — add_face on coincident edges
    # returns nil or raises "Could not create Face" (observed) — and it would
    # never be seen anyway: the ceiling closes the drum.
    g.material = mat if mat
    [g, z_bot + F1_EMIT_UP]
  end

  # F2 — cord-hung pendant. Canopy at the ceiling, 1/4-IPS-scale cord, and a
  # truncated-cone shade whose bottom sits at PENDANT_AFF. Drawn from the
  # PH5 / Nelson Bubble / Akari proportions (reported, spec §7.4).
  # Returns [group, emitter_z].
  def self.build_f2(ents, model, cx, cy, z_ceil, z_floor, mat)
    g = ents.add_group
    g.name = 'WR Fixture F2 pendant'
    z_shade_bot = z_floor + PENDANT_AFF
    z_shade_top = z_shade_bot + F2_SHADE_H
    disc_solid(g.entities, cx, cy, z_ceil - F2_CANOPY_H, F2_CANOPY_R,
               F2_CANOPY_H, SEG)
    cord_h = z_ceil - F2_CANOPY_H - z_shade_top
    disc_solid(g.entities, cx, cy, z_shade_top, F2_CORD_R, cord_h, SEG) if cord_h > 0.1
    cone_shell(g.entities, cx, cy, z_shade_bot, F2_SHADE_BOT_R,
               F2_SHADE_TOP_R, F2_SHADE_H, F1_SHELL, SEG)
    g.material = mat if mat
    [g, z_shade_bot + F2_BULB_UP]
  end

  # F3 — open-ended up/down cylinder sconce. The body is opaque; light escapes
  # only through the open top and bottom, which is the double scallop the
  # graze layer wants, and it is a visible fixture and the graze source in one
  # object. Returns [group, [ex, ey, z_up_emitter, z_down_emitter]].
  def self.build_f3(ents, model, wx, wy, nx, ny, z_mid, mat)
    g = ents.add_group
    g.name = 'WR Fixture F3 sconce'
    nv = Geom::Vector3d.new(nx, ny, 0)
    c = g.entities.add_circle(Geom::Point3d.new(wx, wy, z_mid), nv, F3_CYL_R, SEG)
    f = g.entities.add_face(c)
    if f
      d = f.normal.dot(nv) > 0 ? F3_PLATE_D : -F3_PLATE_D
      f.pushpull(d)
    end
    bx = wx + nx * F3_PROJECT
    by = wy + ny * F3_PROJECT
    z_bot = z_mid - F3_CYL_H / 2.0
    tube(g.entities, bx, by, z_bot, F3_CYL_R, F3_CYL_R - F1_SHELL, F3_CYL_H, SEG)
    g.material = mat if mat
    [g, [bx, by, z_bot + F3_CYL_H + F3_EMIT_OUT, z_bot - F3_EMIT_OUT]]
  end

  # ======================================================================
  # THE ON-DEMAND CEILING (spec §8) — and its removal, which is the
  # riskiest thing in this tool.
  #
  # LIFETIME = THE RIG'S LIFETIME, not the press's. A ceiling removed at the
  # end of the press does not exist when the render runs, which defeats its
  # purpose and leaves five visible fixtures hanging in open air. It is
  # created with the rig and removed by the same thing that removes the rig:
  # the next press's stale sweep, or WR_DropLights.remove_rig!.
  #
  # OWNERSHIP IS BY DICTIONARY, never by name and never by tag alone — a name
  # match will happily miss a renamed group or match a user's own.
  # ======================================================================

  # Does this room already have a ceiling THE TOOL DOES NOT OWN? A horizontal
  # face at or above the wall top, spanning the floor centroid.
  def self.existing_ceiling(room, poly, z_top)
    c = poly_centroid(poly)
    found = nil
    scan = nil
    scan = lambda do |ents, tr, depth|
      next if depth > 3 || found
      ents.each do |e|
        break if found
        if e.is_a?(Sketchup::Face)
          nrm = e.normal.transform(tr)
          next if nrm.z.abs < 0.99
          pts = e.outer_loop.vertices.map { |v| v.position.transform(tr) }
          zs = pts.map(&:z)
          next if zs.max < z_top - 2.0
          xy = pts.map { |p| [p.x, p.y] }
          found = e if point_in_poly?(c[0], c[1], xy)
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.get_attribute(DICT, 'kind') == 'ceiling'
          kids = child_entities(e)
          scan.call(kids, tr * e.transformation, depth + 1) if kids.respond_to?(:each)
        end
      end
    end
    scan.call(child_entities(room), room.transformation, 0)
    found
  rescue StandardError
    nil
  end

  # Build the ceiling: the floor polygon, faced at the wall top, lit side
  # DOWN. No new geometry logic and L-shaped rooms work for free.
  def self.add_ceiling(ents, poly, z_top, layer, uuid, mat)
    g = ents.add_group
    g.name = CEIL_NAME
    f = g.entities.add_face(poly.map { |p| Geom::Point3d.new(p[0], p[1], z_top) })
    if f.nil?
      g.erase! if g.valid?
      return nil
    end
    f.reverse! if f.normal.z > 0     # the lit face points DOWN into the room
    g.material = mat if mat
    g.layer = layer
    g.set_attribute(DICT, 'kind', 'ceiling')
    g.set_attribute(DICT, 'uuid', uuid)
    g.set_attribute(DICT, 'role', 'ceiling')  # so the existing sweep owns it
    g
  end

  # An INDEPENDENT probe of the model — the numbers criterion 9 compares.
  # Deliberately reads the model afresh and never a captured value: two
  # separate restores have already lied in this project by trusting their own
  # capture (37 materials where the model had 36; a sky_multiplier written,
  # read back, and changed nothing).
  def self.model_probe(model)
    { :definitions => model.definitions.count,
      :materials   => model.materials.count,
      :tags        => model.layers.map { |l| l.name.to_s }.sort,
      :top_level   => model.entities.length,
      :ceilings    => find_ceilings(model).size }
  end

  # Every entity anywhere carrying WR_DropLights/kind => 'ceiling'.
  def self.find_ceilings(model, ents = nil, out = nil, depth = 0)
    out ||= []
    ents ||= model.entities
    return out if depth > SWEEP_MAX_DEPTH
    ents.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      if e.get_attribute(DICT, 'kind') == 'ceiling'
        out << e
        next
      end
      kids = child_entities(e)
      find_ceilings(model, kids, out, depth + 1) if kids.respond_to?(:each)
    end
    out
  rescue StandardError
    out
  end

  # Remove the tool-owned ceilings and PROVE it by re-reading the model from
  # scratch. Refuses BY NAME and prints no success line if any check fails.
  # Returns [ok?, lines].
  # Erase every tool-owned ceiling. Returns how many groups went.
  def self.erase_ceilings!(model)
    gs = find_ceilings(model)
    return 0 if gs.empty?
    model.start_operation('Remove WR Lights ceiling', true)
    n = 0
    gs.each do |g|
      next unless g.valid?
      begin
        g.erase!
        n += 1
      rescue StandardError
        nil
      end
    end
    model.commit_operation
    n
  end

  # THE RE-READ, and it is the whole point: not the capture, the model again,
  # from the top. Refuses BY NAME and prints no success line if anything is
  # off. Returns [ok?, lines].
  def self.verify_restore!(model, before, n = nil)
    lines = []
    after = model_probe(model)
    fails = []
    if after[:ceilings] > 0
      fails << format('%d entit%s still carries WR_DropLights/kind => ceiling',
                      after[:ceilings], after[:ceilings] == 1 ? 'y' : 'ies')
    end
    if after[:materials] != before[:materials]
      fails << format('materials.count is %d, was %d before the press — ' \
                      'this is the check that catches the 37th material',
                      after[:materials], before[:materials])
    end
    if after[:definitions] != before[:definitions]
      fails << format('definitions.count is %d, was %d before the press',
                      after[:definitions], before[:definitions])
    end
    if after[:tags] != before[:tags]
      fails << format('the tag list changed: %s',
                      ((after[:tags] - before[:tags]) +
                       (before[:tags] - after[:tags])).join(', '))
    end
    if after[:top_level] != before[:top_level]
      fails << format('the model holds %d top-level entities, was %d before '                       'the press', after[:top_level], before[:top_level])
    end
    if fails.empty?
      lines << format('  restore verified by an INDEPENDENT re-read — '                       'definitions %d, materials %d, %d tags, %d top-level '                       'entities, and nothing anywhere carries the ceiling '                       'stamp.%s', after[:definitions], after[:materials],
                      after[:tags].size, after[:top_level],
                      n.nil? ? '' : format(' %d ceiling group%s erased.',
                                           n, n == 1 ? '' : 's'))
      return [true, lines]
    end
    lines << '  REFUSED — the restore DID NOT verify:'
    fails.each { |f| lines << "    #{f}" }
    lines << '    Delete the group named ' + CEIL_NAME.inspect +
             ' by hand and check the Materials browser.'
    [false, lines]
  end

  # Erase the ceilings and verify in one call — the shape the negative test
  # exercises, and the one a caller with nothing else to remove wants.
  def self.remove_ceilings_verified!(model, before)
    n = erase_ceilings!(model)
    return [true, ['  no tool-owned ceiling in this model — nothing to remove.']] if n.zero?
    verify_restore!(model, before, n)
  end

  # The explicit Remove Lights action: sweep every light, fixture and ceiling
  # this tool owns, anywhere in the model, and verify the ceiling went.
  def self.remove_rig!(model, before = nil)
    before ||= model_probe(model)
    found = []
    collect_lights(model.entities, IDENT, found, 0, [])
    ceilings = find_ceilings(model).size
    model.start_operation('Remove Interior Lights', true)
    pend = []
    n = 0
    found.each do |e, _|
      next unless e.respond_to?(:valid?) && e.valid?
      next if e.get_attribute(DICT, 'kind') == 'ceiling'
      pname = e.get_attribute(DICT, 'plugin').to_s
      defn = e.respond_to?(:definition) ? e.definition : nil
      begin
        e.erase!
        n += 1
      rescue StandardError
        next
      end
      pend << [pname, defn] unless pname.empty?
    end
    model.commit_operation
    ctx, = vray_context
    sc = vray_scene(ctx)
    gone, left = reap_lights(model, sc, pend)
    # THE CEILING GOES FIRST, then the tag, then the verification —
    # in that order, because the ceiling group is itself ON the tag and
    # a tag with something standing on it is never removed (observed:
    # the first run of this refused itself with "1 entity is still on
    # the tag", which was its own ceiling).
    erased_ceilings = erase_ceilings!(model)
    # THE TAG COMES BACK OFF, when this tool is the one that put it on and
    # nothing is left standing on it. Both conditions matter: a tag the model
    # already had is Benton's, and a tag with something on it would take that
    # something's visibility with it.
    tag_removed = false
    tag_note = nil
    if model.get_attribute(DICT, 'tag_created')
      ly = model.layers[TAG]
      if ly.nil?
        tag_removed = true
      else
        users = 0
        count_users = nil
        count_users = lambda do |ents, d|
          next if d > SWEEP_MAX_DEPTH
          ents.each do |e|
            users += 1 if e.respond_to?(:layer) && e.layer && e.layer.name == TAG
            kids = child_entities(e) if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            count_users.call(kids, d + 1) if kids.respond_to?(:each)
          end
        end
        count_users.call(model.entities, 0)
        if users.zero?
          begin
            model.layers.remove(ly, false)
            tag_removed = model.layers[TAG].nil?
            model.set_attribute(DICT, 'tag_created', nil) if tag_removed
          rescue StandardError => e
            tag_note = "removing the #{TAG.inspect} tag raised #{e.class}: #{e.message}"
          end
        else
          tag_note = "#{users} entit#{users == 1 ? 'y is' : 'ies are'} still on "                      "the #{TAG.inspect} tag, so it stays"
        end
      end
    end
    ok, lines = verify_restore!(model, before)
    { 'erased' => n, 'ceilings' => ceilings, 'plugins_deleted' => gone,
      'plugins_left' => left, 'ceiling_verified' => ok, 'lines' => lines,
      'ceiling_groups_erased' => erased_ceilings,
      'tag_removed' => tag_removed, 'tag_note' => tag_note }
  end

  # ======================================================================
  # THE EXPOSURE STAMP (spec §4) — narrow, loud, once.
  #
  # Five guards, and every one of them is here because the alternative is a
  # tool that quietly retunes Benton's camera:
  #   1. ISO ONLY. Never f_number, never shutter, never anything in
  #      /SettingsOutput, /SunLight or /SettingsEnvironment (NEVER_WRITE).
  #   2. ONCE. The stamp is recorded in the model's own dictionary; a second
  #      press writes nothing and says so.
  #   3. ONLY FROM FACTORY ISO 100. Anything else means Benton set it:
  #      report the value and leave it alone.
  #   4. LOUD, WITH ITS UNDO, by name.
  #   5. READ BACK after the transaction, and refused by name if it did not
  #      stick — and f_number and shutter are read back too, to PROVE they
  #      did not move.
  # ======================================================================
  def self.stamp_exposure!(model, scene)
    r = { :wrote => false, :reason => nil }
    cp = (scene && (scene['/CameraPhysical'] rescue nil))
    if cp.nil?
      r[:reason] = 'no /CameraPhysical plugin in the V-Ray scene — exposure left alone'
      return r
    end
    r[:f_before]   = (cp[:f_number] rescue nil)
    r[:iso_before] = (cp[:ISO] rescue nil)
    r[:sh_before]  = (cp[:shutter_speed] rescue nil)
    prev = model.get_attribute(DICT, 'exposure_stamped')
    if prev
      r[:reason] = "already stamped (#{prev}) — a second press writes nothing"
      return r
    end
    unless param_agrees?(EXPO_FACTORY_ISO, r[:iso_before])
      r[:reason] = format('ISO reads %s, not the factory %.0f — you have set ' \
                          'this yourself, so it is left exactly as it is',
                          r[:iso_before].inspect, EXPO_FACTORY_ISO)
      return r
    end
    errs = write_params(scene, cp, [[:ISO, EXPO_ISO]])
    stuck, got, err = read_param(cp, :ISO, EXPO_ISO, errs[:ISO] || errs[:__scene])
    r[:iso_after] = got
    r[:f_after]   = (cp[:f_number] rescue nil)
    r[:sh_after]  = (cp[:shutter_speed] rescue nil)
    r[:moved_f]  = !param_agrees?(r[:f_before], r[:f_after])
    r[:moved_sh] = !param_agrees?(r[:sh_before], r[:sh_after])
    if stuck
      r[:wrote] = true
      model.set_attribute(DICT, 'exposure_stamped',
                          format('ISO %.0f, %s', EXPO_ISO,
                                 Time.now.strftime('%Y-%m-%d %H:%M:%S')))
    else
      r[:reason] = "the ISO write DID NOT STICK#{err ? " (#{err})" : ''}"
    end
    r
  end

  def self.print_exposure_report(r)
    puts ''
    puts '  EXPOSURE — the ONE V-Ray setting this tool writes, and it writes'
    puts '  it once. ISO only: f-number and shutter never move.'
    if r[:wrote]
      puts format('    /CameraPhysical ISO  %s  ->  %.0f', r[:iso_before].inspect, EXPO_ISO)
      puts format('    f/%s @ 1/%s @ ISO %.0f = EV %.2f — an interior exposure.',
                  r[:f_after].to_s, r[:sh_after].to_s, EXPO_ISO, EXPO_EV)
      puts '    TO UNDO: Asset Editor > Settings > Camera > ISO, back to 100.'
      puts format('    f-number read back %s (was %s) and shutter %s (was %s) — %s',
                  r[:f_after].inspect, r[:f_before].inspect,
                  r[:sh_after].inspect, r[:sh_before].inspect,
                  (r[:moved_f] || r[:moved_sh]) ?
                    '** ONE OF THEM MOVED — that is a BUG **' :
                    'both unmoved, as promised')
    else
      puts "    nothing written — #{r[:reason]}"
      puts format('    camera reads f/%s @ 1/%s @ ISO %s',
                  r[:f_before].inspect, r[:sh_before].inspect, r[:iso_before].inspect)
    end
    puts format('    NEVER WRITTEN: %s', NEVER_WRITE.join(', '))
  end

  # ======================================================================
  # THE TAG GATE (spec §9 step 2b, auditor finding C1)
  #
  # `WR Lights` read FALSE on the live model three times on 30 Aug, and a
  # saved scene re-applies its OWN stored copy of tag visibility on
  # activation (observed, proposal-scenes.rb:221,223 — scenes are captured
  # with use_hidden_layers = true). So forcing the tag visible for the
  # session is necessary and NOT sufficient: every page has to be stamped
  # too, or activating a scene hides the whole rig again and V-Ray exports
  # none of it. This is the mechanism behind "same model, some frames lit,
  # some black", and no rig design survives it.
  # ======================================================================
  def self.stamp_tag_into_pages(model, layer)
    done = 0
    failed = []
    model.pages.each do |pg|
      begin
        pg.set_visibility(layer, true)
        done += 1
      rescue StandardError => e
        failed << "#{pg.name}: #{e.class}"
      end
    end
    [done, failed]
  end

  # The render-time gate. The same pattern as lookdev-matrix.rb's
  # assert_lights_visible!, which has already caught one null experiment: it
  # RAISES rather than warning, because a frame rendered with this tag hidden
  # is a wasted frame and is indistinguishable from a correctly rendered
  # failure.
  def self.assert_lights_visible!(model, expect = nil)
    ly = model.layers[TAG]
    raise "REFUSED: this model has no tag named #{TAG.inspect}" if ly.nil?
    unless ly.visible?
      raise "REFUSED: the tag #{TAG.inspect} is HIDDEN. A light on a hidden " \
            'tag is excluded from the V-Ray export, so the frame would ' \
            'contain no artificial light at all.'
    end
    on = model.entities.grep(Sketchup::ComponentInstance)
              .select { |e| e.layer && e.layer.name == TAG && e.visible? }
    if expect && on.length < expect
      raise "REFUSED: tag #{TAG.inspect} is visible but only #{on.length} " \
            "light instances are visible (expected #{expect})."
    end
    on.length
  end

  # ---- THE TRANSACTION, and why it is not optional ----------------------  #
  # LIVE FINDING, SketchUp 2026 / V-Ray 7, 2026-08-30 (observed through the
  # bridge, A/B'd twice):
  #
  #   plugin[:intensity] = 256.0        # reads back 256.0 immediately
  #   ... next bridge job, seconds later ...
  #   scene[name][:intensity]           # => 30.0. The write is GONE.
  #
  # A bare `plugin[key] = value` lands only on the in-memory plugin. The
  # authoritative copy is the JSON blob V-Ray keeps in the light component
  # DEFINITION's `VRayPlugins` attribute dictionary (observed: the
  # definition of every light this tool placed on 30 Aug held V-Ray's
  # factory defaults, `"intensity":"30"`, `"invisible":"0"`). V-Ray
  # re-syncs the scene plugin from that blob on its own schedule, and an
  # un-transacted write is silently discarded.
  #
  # The read-back this file already had could not catch it: it read the
  # same in-memory object microseconds after the write, so it agreed every
  # single time. Eight lights placed, zero "DID NOT STICK" lines, and not
  # one of the eight was actually configured. A read-back that cannot fail
  # is not a check.
  #
  # `VRay::Scene#change { }` (documented, VRay/Scene.html: "Wraps all
  # changes inside the block in a transaction") is the fix. Writing inside
  # it pushes the parameters into the definition's `VRayPlugins` JSON
  # (observed: `"intensity":"555"`, `"invisible":"1"`) and the value
  # survives every later job. The same code without the block, same order
  # of operations, same commit_operation: reset to default. That is the
  # whole difference.
  #
  # So the two halves are now SEPARATE, and the read-back happens AFTER
  # the transaction closes, where it can genuinely fail:
  #   write_params  — every write, inside one scene.change
  #   read_param    — every read, after it

  # Write every [key, value] inside ONE scene transaction. Returns a hash
  # of key => error-string for the writes that raised; an empty hash means
  # every write was accepted (which is NOT yet proof it stuck — read back).
  # Never raises.
  def self.write_params(scene, plugin, wants)
    errs = {}
    body = lambda do
      wants.each do |key, value|
        begin
          plugin[key] = value
        rescue StandardError => e
          errs[key] = "write raised #{e.class}: #{e.message}"
        end
      end
    end
    if scene.nil?
      errs[:__scene] = 'no V-Ray scene — these writes were made outside a '                        'transaction and V-Ray will discard them'
      body.call
      return errs
    end
    begin
      scene.change('WR Drop Interior Lights') { body.call }
    rescue StandardError => e
      errs[:__scene] = "scene.change raised #{e.class}: #{e.message} — "                        'these writes were not transacted'
      body.call
    end
    errs
  end

  # Read ONE plugin parameter back and compare. Returns
  # [stuck?, value_read, error_or_nil]. Never raises. Call this only AFTER
  # write_params has closed its transaction.
  def self.read_param(plugin, key, value, write_err)
    got = begin
            plugin[key]
          rescue StandardError => e
            return [false, nil, "read-back raised #{e.class}: #{e.message}"]
          end
    [param_agrees?(value, got) && write_err.nil?, got, write_err]
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
  #
  # THE UNITS CHANGE, 1.9.9: `units` is 1 — Luminous Power (Lumens) — and
  # `intensity` is the layer's lumen figure, unmodified. There is no area
  # correction any more because in lumens mode intensity IS the total output
  # and does not depend on emitter size.
  def self.configure_light(scene, plugin, role, lumens, kelvin)
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
    # invisible FIRST, and it is now PER LAYER rather than a constant: five
    # of the seven roles are visible fixtures, which is the whole point of
    # the redesign. An invisible emitter inside a visible shade would be a
    # fixture that does not glow.
    wants << [:invisible, !spec[:visible]]
    wants << [:units, UNITS_LUMENS]
    wants << [:intensity, lumens.to_f]
    wants << [:color, color] unless color.nil?
    wants << [:directional, spec[:dir]] unless spec[:dir].nil?
    # is_disc is READ from the plugin's own default dump on this build
    # (observed, 30 Aug 2026: rectangle lights carry is_disc = 0), so it is
    # not a guessed key — but it is still written, read back, and refused by
    # name if it will not take.
    wants << [:is_disc, 1] if spec[:disc] && spec[:emitter] == :rect
    # ONE transaction for the whole light, then read every value back
    # OUTSIDE it. See write_params: an un-transacted write is discarded by
    # V-Ray and a read-back taken inside the transaction always agrees.
    werrs = write_params(scene, plugin, wants)
    writes = []
    bad = []
    if werrs[:__scene]
      writes << [:__scene, 'transacted', 'NOT transacted', false, werrs[:__scene]]
      bad << :__scene
    end
    wants.each do |key, value|
      stuck, got, err = read_param(plugin, key, value, werrs[key])
      writes << [key, value, got, stuck, err]
      bad << key unless stuck
    end
    # Sizes were set by the create call — read them back rather than
    # re-writing, so a mismatch is a fact about the API, not ours.
    keys = spec[:emitter] == :sphere ? [:radius] : [:u_size, :v_size]
    sizes = keys.map do |k|
      begin
        plugin[k]
      rescue StandardError
        nil
      end
    end
    { :writes => writes, :bad => bad, :rgb => rgb, :sizes => sizes,
      :color_err => color_err, :lumens => lumens.to_f, :kelvin => kelvin }
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

  # ---- THE SECOND-PRESS KILL, and why the reap is deferred --------------
  #
  # LIVE FINDING, SketchUp 2026 / V-Ray 7, 2026-08-30 (observed through
  # the bridge; four variants run, three of them clean).
  #
  # 1.8.0 swept in one pass: erase the instance, remove its component
  # definition, delete its V-Ray plugin - all BEFORE the new rig was
  # placed. Press once and the rig is fine. Press TWICE and the eight new
  # lights are still in the model, still tagged, still reporting a clean
  # read-back on the console - and the V-Ray scene holds ZERO light
  # plugins. A second press produced a rig that CANNOT emit, silently
  # (observed: 8 instances in the model, and the only light plugin left in
  # the whole scene was /SunLight).
  #
  # The mechanism: removing the component definition schedules a DEFERRED
  # purge in V-Ray, keyed on the plugin name recorded in that definition's
  # VRayInfo dictionary. SketchUp then hands the freed definition names
  # ("Rectangle Light", "#1", ...) straight back to the lights created
  # moments later in the same press, and their plugins take the freed
  # plugin names too. When the purge finally runs - after the job returns
  # - it deletes those names, and it is the NEW lights it kills.
  #
  # Renaming the stale plugin and definition to a graveyard name first
  # does NOT help (tried live; the purge follows the definition's recorded
  # main_plugin, not the current name). What helps is never letting the
  # new lights inherit a freed name. Three variants were run live and all
  # three survived: skip definitions.remove; skip scene.delete; or place
  # first and reap last. The third is the one taken here - it is the only
  # one that still leaves the Asset Editor clean.
  #
  # So the sweep is now TWO steps with all of the placement between them:
  #   erase_lights  - erase the instances only, and hand back the list
  #   reap_lights   - remove the now-unused definitions and delete the
  #                   plugins, AFTER every new light exists
  #
  # Erase the replaced lights' INSTANCES. Returns [erased, pending], where
  # pending is [[plugin_name, definition], ...] for reap_lights to finish
  # once the new rig is in place. Nothing V-Ray-side happens here.
  def self.erase_lights(lights)
    erased = 0
    pending = []
    lights.each do |e, _|
      # A light reached through two instance paths of one shared
      # definition appears twice in the list; the second visit is already
      # deleted and reading an attribute off it would raise.
      next unless e.respond_to?(:valid?) && e.valid?
      pname = e.get_attribute(DICT, 'plugin').to_s
      kind = e.get_attribute(DICT, 'kind').to_s
      defn = e.respond_to?(:definition) ? e.definition : nil
      begin
        e.erase!
        erased += 1
      rescue StandardError
        next
      end
      # A FIXTURE GROUP AND THE BORROWED CEILING never owned a V-Ray plugin,
      # so they are not "left behind" when none is deleted for them — counting
      # them as left behind made a clean sweep report 6 orphans it had not
      # created (observed, 1.9.9 first live press).
      next if kind == 'fixture' || kind == 'ceiling'
      pending << [pname, defn]
    end
    [erased, pending]
  end

  # Finish the sweep: drop the now-unused definitions and delete the V-Ray
  # plugins. MUST run after every new light has been created, or V-Ray's
  # deferred purge takes the new rig with it (see above).
  # Returns [plugins_deleted, plugins_left].
  def self.reap_lights(model, scene, pending)
    gone = 0
    left = 0
    pending.each do |pname, defn|
      if defn && defn.respond_to?(:valid?) && defn.valid? &&
         defn.respond_to?(:instances) && defn.instances.empty?
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
    [gone, left]
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
    t = model.layers[TAG]
    if t.nil?
      t = model.layers.add(TAG)
      # RECORD THAT WE MADE IT. "Leaves Benton's drawing exactly as it found
      # it" includes the tag list: the first live removal refused itself by
      # name because `WR Lights` was still there afterwards (observed,
      # 1.9.9). remove_rig! takes the tag back, but ONLY the one this tool
      # created and only while nothing is left on it.
      model.set_attribute(DICT, 'tag_created', true)
    end
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

  # TWO DROPDOWNS, and no more. Brightness is a global multiplier; Warmth is
  # a global KELVIN OFFSET — Warm = the layer table as written (2700-5000 K),
  # Neutral = every layer +500 K. It SHIFTS the palette; it never flattens
  # it, which is the difference between a warmth control and the old
  # one-colour-on-everything rig this replaces.
  #
  # The exposure question is GONE. Exposure is written once, as a documented
  # default, not asked per press — see stamp_exposure!.
  # ADD CEILING? -- the room's own enclosure is a judgement, not a fact this
  # tool can read. A room drawn as four walls with an open top is a drawing
  # convention, not a statement that the real room has no ceiling, so the tool
  # used to cap it unconditionally: the rig needs a surface to mount to and a
  # room to bounce in, and an uncapped room renders as a lightbox.
  #
  # But capping is not always wanted, so it is a choice now. 'Yes' stays the
  # default because it is what every press before this did. 'No' takes the
  # enclosure trims that already exist (enclosure_trim), so the lumens follow
  # the choice rather than pretending the room is still capped.
  #
  # An existing ceiling this tool does not own is BORROWED either way and this
  # answer does not touch it -- 'No' means "do not add one", never "delete the
  # one that is there."
  def self.ask
    @last ||= ['Normal', 'Warm', 'Yes']
    res = UI.inputbox(
      ['Brightness', 'Warmth', 'Add ceiling'],
      @last,
      ['Normal|Dim|Bright', 'Warm|Neutral', 'Yes|No'],
      'Drop Interior Lights')
    return nil unless res
    @last = res
    { :mult    => BRIGHT[res[0]] || 1.0,
      :bright  => res[0],
      :warmth  => res[1],
      :koffset => res[1] == 'Neutral' ? 500 : 0,
      :ceiling => res[2].to_s != 'No',
      :density => :soft }
  end

  # ==== WHAT WAS ACTUALLY WRITTEN INTO V-RAY ===============================
  # `layers` is { role => report-hash } for the FIRST light of each layer,
  # plus :count. One block per layer, not per light.
  def self.print_light_report(layers, opts, extra)
    puts ''
    puts '  WHAT WAS WRITTEN INTO EACH V-RAY LIGHT — one plugin per light, so'
    puts '  these are per-light values, in LUMENS (units = 1):'
    layers.each do |role, r|
      spec = LIGHT_LAYERS[role]
      rgb = r[:rgb]
      size = spec[:emitter] == :sphere ?
        format('sphere d%.1f"', spec[:u]) :
        format('%.1f" x %.1f"%s', spec[:u], spec[:v], spec[:disc] ? ' disc' : '')
      puts format('    %-16s x%-2d %-18s %6.0f lm  %4dK  %s',
                  spec[:label], r[:count], size, r[:lumens], r[:kelvin],
                  spec[:visible] ? 'VISIBLE' : 'invisible')
      puts format('                     colour rgb %.3f %.3f %.3f, fixture %s, plugin size %s',
                  rgb[0], rgb[1], rgb[2],
                  spec[:fixture] ? spec[:fixture].to_s.upcase : 'none',
                  r[:sizes].map(&:to_s).join(' x '))
      puts "                     NOTE: #{r[:color_err]}" if r[:color_err]
      next if r[:bad].nil? || r[:bad].empty?
      puts "    ** #{spec[:label]}: these writes DID NOT STICK — " \
           "#{r[:bad].map(&:to_s).join(', ')}."
      r[:writes].each do |key, want, got, stuck, err|
        next if stuck
        puts format('       %s: wanted %s, plugin holds %s%s', key.to_s,
                    want.inspect, got.inspect, err ? " (#{err})" : '')
      end
    end
    puts ''
    ks = layers.values.map { |r| r[:kelvin] }.uniq.sort
    puts format('  %d distinct colour temperatures across the rig: %s',
                ks.size, ks.map { |k| "#{k}K" }.join(', '))
    puts format('  %d of the %d layers are VISIBLE fixtures.',
                layers.keys.count { |r| LIGHT_LAYERS[r][:visible] }, layers.size)
    puts format('  room budget spent %.0f lm; booth budget spent %.0f lm.',
                extra[:room_lm], extra[:booth_lm])
    puts format('  enclosure: %s, %d walls -> room trim x%.2f (booth roles never trim)',
                extra[:capped] ? 'CAPPED' : 'OPEN', extra[:walls], extra[:trim])
    puts format('  fixture geometry added %d faces (budget %d, %d segments/circle)',
                extra[:faces], FIXTURE_FACES_MAX, SEG)
    if extra[:faces] > FIXTURE_FACES_MAX
      puts '    ** OVER THE FACE BUDGET — lower SEG or drop a fixture type.'
    end
    puts format('  materials.count %d before the press, %d after — %s',
                extra[:mat_before], extra[:mat_after],
                extra[:mat_before] == extra[:mat_after] ?
                  'unchanged, as it must be' :
                  '** CHANGED. This tool must create no material. **')
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

    # THE PROBE, taken BEFORE anything is placed and NEVER from this
    # tool's own capture. It is what the ceiling removal is checked against
    # (spec §8 / criterion 9), and it is the check that would have caught
    # "restored clean (69 keys put back)" while a 37th material stayed
    # behind.
    probe_before = model_probe(model)
    puts ''
    puts format('  probe BEFORE the press: %d definitions, %d materials, ' \
                '%d tags, %d top-level entities',
                probe_before[:definitions], probe_before[:materials],
                probe_before[:tags].size, probe_before[:top_level])

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
      # Instances now; definitions and V-Ray plugins only AFTER placement
      # (reap_lights, at the bottom of this method). See erase_lights.
      erased, reap_pending = erase_lights(stale)

      puts ''
      puts format('Drop Interior Lights 1.9.9 — brightness %s (x%.2f), ' \
                  'warmth %s (%+d K), units 1 (LUMENS), seven roles',
                  opts[:bright], opts[:mult], opts[:warmth], opts[:koffset])
      unless stale.empty?
        puts format('  replacing %d previously dropped light%s - their ' \
                    'V-Ray plugins are deleted AFTER the new rig is ' \
                    'placed, because a deferred V-Ray purge kills the new ' \
                    'lights otherwise', erased, erased == 1 ? '' : 's')
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
      placed = 0
      layers_rep = {}
      fixture_faces = 0
      ceilings_added = 0
      room_lm = 0.0
      booth_lm = 0.0
      press_uuid = format('%d-%06d', Time.now.to_i, rand(1_000_000))
      mat_before = model.materials.count
      capped_any = false
      walls_any = 0
      trim_any = 1.0

      # THE ONE SANCTIONED V-RAY WRITE. Everything else in NEVER_WRITE is
      # Benton's and is not touched.
      expo = stamp_exposure!(model, scene)
      print_exposure_report(expo)

      # THE TAG GATE. Forcing the tag visible for the session is necessary
      # and NOT sufficient — a saved scene re-applies its own stored copy on
      # activation, which is the mechanism behind "same model, some frames
      # lit, some black". So every page is stamped too.
      pages_ok, pages_bad = stamp_tag_into_pages(model, layer)
      puts format('  tag "%s": visible, and stamped VISIBLE into %d of %d ' \
                  'saved scene%s%s', TAG, pages_ok, model.pages.count,
                  model.pages.count == 1 ? '' : 's',
                  pages_bad.empty? ? '' : " (FAILED on: #{pages_bad.join(', ')})")

      # No material is ever created — borrow one by name or leave the
      # default. See the comment above build_f1.
      fx_mat = borrow_material(model, ['Aluminum', 'WR Wall', 'Wall',
                                       'WR Panel', 'Metal'])

      stamp_own = lambda do |g, kind|
        g.layer = layer
        g.set_attribute(DICT, 'seed', "Fixture #{kind.to_s.upcase}")
        g.set_attribute(DICT, 'role', "fixture_#{kind}")
        g.set_attribute(DICT, 'kind', 'fixture')
        g.set_attribute(DICT, 'uuid', press_uuid)
        n = 0
        begin
          n = g.entities.grep(Sketchup::Face).length
        rescue StandardError
          n = 0
        end
        fixture_faces += n
        g
      end

      # ONE V-Ray light per call — each light gets its own plugin, so its own
      # brightness, colour and visibility. Creating a light is a V-Ray-scene
      # change and V-Ray's scene is NOT on SketchUp's undo stack.
      place = lambda do |role, pt, lumens, extra_tr = nil|
        spec = LIGHT_LAYERS[role]
        if spec[:emitter] == :sphere
          d, plug = create_sphere(ctx, spec[:u] / 2.0)
        else
          d, plug = create_light(ctx, spec[:u], spec[:v])
        end
        kelv = layer_kelvin(spec[:kelvin], opts[:koffset])
        rpt = configure_light(scene, plug, role, lumens, kelv)
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
        inst.set_attribute(DICT, 'uuid', press_uuid)
        inst.set_attribute(DICT, 'plugin', plugin_name(plug))
        placed += 1
        if spec[:budget] == :room
          room_lm += lumens
        else
          booth_lm += lumens
        end
        prev = layers_rep[role]
        if prev.nil?
          layers_rep[role] = rpt.merge(:count => 1)
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
        # light only.
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
          pt = [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0,
                bb.max.z - BOOTH_DROP]
          lm = layer_lumens(LIGHT_LAYERS[:booth][:lumens], opts[:mult], 1.0)
          place.call(:booth, pt, lm)
          puts "  #{name}: selected booth — 1 interior light at #{fmt(pt)}, #{lm.round} lm"
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

        veto = subject_veto(h, area)
        if veto
          puts "  REFUSED #{name} — #{veto}"
          next
        end

        fallbacks = []
        if info[:fallback]
          fallbacks << 'no WR-Floor child: bounding-box rectangle used as the floor'
          puts "  #{name}: NO WR-Floor child found — using the BOUNDING-BOX rectangle."
        end
        if info[:no_walls]
          fallbacks << 'no Walls child: ceiling taken from the group top'
          puts "  #{name}: no Walls child — ceiling taken from the group top."
        end

        z_m = info[:z_top] - DROP
        z0 = info[:z0]

        obst, room_sibs = obstructions(model, s, poly, z_m, subjects)
        room_sibs.each do |e|
          puts "  #{name}: sibling \"#{display_name(e)}\" overlaps this " \
               "room's footprint but is itself a ROOM — never a keep-out."
        end
        keepouts = obst.map { |o| o[:rect] }
        booths = obst.select { |o| booth?(o[:ent]) }
        obst.each do |o|
          next if booth?(o[:ent])
          bb = o[:bb]
          next unless booth_like?(bb.max.x - bb.min.x, bb.max.y - bb.min.y,
                                  bb.max.z - bb.min.z)
          booths << o
          puts format('  %s: "%s" carries no WR-Booth-* tag but is ' \
                      'booth-sized (%.0f" x %.0f" x %.0f") — treated as a booth.',
                      name, display_name(o[:ent]),
                      bb.max.x - bb.min.x, bb.max.y - bb.min.y,
                      bb.max.z - bb.min.z)
        end

        # ---- THE ON-DEMAND CEILING (spec §8) --------------------------------
        # It is created with the rig and it leaves with the rig. Ownership is
        # by DICTIONARY plus a per-press UUID, never by name.
        had_ceiling = !existing_ceiling(s, poly, info[:z_top]).nil?
        capped = had_ceiling
        if had_ceiling
          puts "  #{name}: this room already has a ceiling this tool does not " \
               'own — borrowing it. Nothing added, nothing to remove.'
        elsif !opts[:ceiling]
          # Said out loud WITH the consequence: the lumens below are about to
          # be trimmed for an open room, and that is not visible in the picture.
          puts "  #{name}: \"Add ceiling\" was No — the room is left open. The " \
               'open-room trims apply, so the rig is dimmer than a capped room ' \
               'by design; the fixtures still mount at the wall top.'
        else
          cg = add_ceiling(ents, poly, info[:z_top], layer, press_uuid,
                           borrow_material(model, ['WR Wall', 'Wall']))
          if cg
            capped = true
            ceilings_added += 1
            puts format('  %s: added a tool-owned ceiling "%s" at %.0f" — the ' \
                        'rig needs a surface to mount to and a room to bounce ' \
                        'in. IT LEAVES WHEN THE LIGHTS DO (next press, or ' \
                        'WR_DropLights.remove_rig!), and the removal is ' \
                        'verified by an independent re-read.',
                        name, CEIL_NAME, info[:z_top])
          else
            puts "  #{name}: could not face the floor polygon at the wall top " \
                 '— no ceiling added, and the open-room trims apply.'
          end
        end
        walls_n = poly.size
        trim = enclosure_trim(capped, walls_n)
        room_trim = trim
        capped_any = capped
        walls_any = walls_n
        trim_any = trim
        room_k = area_scale(area, REF_ROOM_SQFT)
        booth_k = 1.0
        lm_of = lambda do |role|
          sp = LIGHT_LAYERS[role]
          k = sp[:budget] == :room ? room_k * room_trim : booth_k
          layer_lumens(sp[:lumens], opts[:mult], k)
        end

        # ---- ROLE 1 — ceiling ambient, and the room's visible light source --
        grid = grid_points(poly, h, opts[:density], keepouts)
        if grid[:pts].empty?
          puts "  REFUSED #{name} — no valid point found inside its floor."
          next
        end
        verdict = fallback_verdict(fallbacks)
        if verdict
          puts "  REFUSED #{name} — #{verdict}"
          next
        end

        bcx = nil
        bcy = nil
        unless booths.empty?
          bb = booths.first[:bb]
          bcx = (bb.min.x + bb.max.x) / 2.0
          bcy = (bb.min.y + bb.max.y) / 2.0
        end
        pair = ceiling_pair(grid[:pts], bcx, bcy)
        pair.each do |p|
          fg, ez = build_f1(ents, model, p[0], p[1], info[:z_top], fx_mat)
          stamp_own.call(fg, :f1)
          place.call(:ceiling, [p[0], p[1], ez], lm_of.call(:ceiling))
        end
        puts format('  %s: floor %.0f sq ft against the %.0f sq ft reference '                     'room -> room roles x%.2f, and the enclosure trim is x%.2f',
                    name, area / 144.0, REF_ROOM_SQFT, room_k, room_trim)
        puts format('  %s: ceiling ambient — %d x F1 flush drum (18"), %.0f lm ' \
                    'each at %dK, at %s', name, pair.size,
                    lm_of.call(:ceiling), layer_kelvin(3500, opts[:koffset]),
                    pair.map { |p| format('(%.0f, %.0f)', p[0], p[1]) }.join(' '))

        # ---- ROLE 3 — the pendant, the warm human-scale cue -----------------
        cen = poly_centroid(poly)
        pc = far_corner(poly, bcx || cen[0], bcy || cen[1], 36.0)
        if pc && point_in_poly?(pc[0], pc[1], poly) &&
           !in_keepout?(pc[0], pc[1], keepouts)
          fg, ez = build_f2(ents, model, pc[0], pc[1], info[:z_top], z0, fx_mat)
          stamp_own.call(fg, :f2)
          place.call(:pendant, [pc[0], pc[1], ez], lm_of.call(:pendant))
          puts format('  %s: pendant — F2 cord-hung drum (16"), shade bottom ' \
                      '%.0f" AFF at (%.0f, %.0f), %.0f lm at %dK',
                      name, PENDANT_AFF, pc[0], pc[1], lm_of.call(:pendant),
                      layer_kelvin(2700, opts[:koffset]))
        else
          puts "  #{name}: no clear corner for the pendant — layer skipped here."
        end

        # ---- the washed wall: opposite the largest door, else the longest ---
        door = info[:doors].max_by { |d| d[:w] }
        wall_i = nil
        if door
          puts "  #{name}: door#{info[:doors].size == 1 ? '' : 's'} found via #{info[:door_mech]}."
          wall_i = opposite_edge(poly, nearest_edge(poly, door[:cx], door[:cy]))
        end
        if wall_i.nil?
          puts "  #{name}: door search came up empty — #{info[:door_diag]}." if info[:door_diag]
          n = poly.size
          wall_i = (0...n).max_by do |i|
            a = poly[i]
            b = poly[(i + 1) % n]
            (b[0] - a[0])**2 + (b[1] - a[1])**2
          end
        end

        # ---- ROLE 4 — the sconce pair: visible fixture AND the graze layer --
        nrm = wall_normal(poly, wall_i)
        sps = nrm ? sconce_points(poly, wall_i, keepouts) : []
        if sps.empty?
          puts "  #{name}: no sconce position survived on wall run #{wall_i + 1} — layer skipped."
        else
          sps.each do |p|
            wx = p[0] - nrm[0] * SCONCE_STANDOFF
            wy = p[1] - nrm[1] * SCONCE_STANDOFF
            fg, e = build_f3(ents, model, wx, wy, nrm[0], nrm[1],
                             z0 + SCONCE_AFF, fx_mat)
            stamp_own.call(fg, :f3)
            place.call(:sconce, [e[0], e[1], e[2]], lm_of.call(:sconce))
            place.call(:sconce, [e[0], e[1], e[3]], lm_of.call(:sconce))
          end
          puts format('  %s: sconces — %d x F3 up/down cylinder (5") at %.0f" ' \
                      'AFF on wall run %d, TWO spheres each (%.0f lm up, ' \
                      '%.0f lm down) at %dK. Two emitters per fixture is what ' \
                      'throws the double scallop; the spec\'s "9 instances" ' \
                      'counts one per fixture and undercounts by two.',
                      name, sps.size, SCONCE_AFF, wall_i + 1,
                      lm_of.call(:sconce), lm_of.call(:sconce),
                      layer_kelvin(3000, opts[:koffset]))
        end

        # ---- ROLES 2, 5, 6, 7 — the booth-conditional layers ----------------
        if booths.empty?
          puts "  #{name}: no booth in this room — the key, rim, booth " \
               'interior and foam graze have nothing to aim at.'
        end
        booths.each do |o|
          bname = display_name(o[:ent])
          bb = o[:bb]
          cx = (bb.min.x + bb.max.x) / 2.0
          cy = (bb.min.y + bb.max.y) / 2.0
          # The booth roles scale with the BOOTH's footprint against the
          # 24 sq ft reference, for the same reason the room roles scale.
          booth_k = area_scale((bb.max.x - bb.min.x) * (bb.max.y - bb.min.y),
                               REF_BOOTH_SQFT)

          # ROLE 6 — the booth is a sealed box: 0.0173 mean, 95.4% near-black
          # with the room lights on and nothing inside (observed). Without
          # this the hero product is a hole in every frame.
          bpt = [cx, cy, bb.max.z - BOOTH_DROP]
          place.call(:booth, bpt, lm_of.call(:booth))
          puts format('  %s: booth "%s" interior — %.0f lm at %dK, %s',
                      name, bname, lm_of.call(:booth),
                      layer_kelvin(4000, opts[:koffset]), fmt(bpt))

          dc = booth_door_center(o)
          if dc.nil?
            puts "  #{name}: booth \"#{bname}\" has no WR-Booth-Door tagged " \
                 'panel — key, rim and foam graze all skipped (they are all ' \
                 'aimed booth-relative and there is nothing to aim from).'
            next
          end
          dlen = Math.sqrt((dc[0] - cx)**2 + (dc[1] - cy)**2)
          ax = accent_axis(cx - dc[0], cy - dc[1])
          if ax.nil? || dlen < 1e-6
            puts "  #{name}: booth \"#{bname}\" door direction is degenerate — " \
                 'key, rim and foam graze skipped.'
            next
          end
          ux = (dc[0] - cx) / dlen
          uy = (dc[1] - cy) / dlen

          # ROLE 2 — the key, 42" out from the door face, tilted 35 degrees
          # onto it. This is what gives the booth a defined FRONT instead of
          # a lit TOP.
          kpt = [dc[0] + ux * ACCENT_OUT, dc[1] + uy * ACCENT_OUT, z_m]
          if point_in_poly?(kpt[0], kpt[1], poly)
            rot = Geom::Transformation.rotation(
              Geom::Point3d.new(0, 0, 0),
              Geom::Vector3d.new(ax[0], ax[1], 0), ACCENT_TILT.degrees)
            place.call(:key, kpt, lm_of.call(:key), rot)
            puts format('  %s: key — %.0f lm at %dK, %s, tilted %d deg onto ' \
                        'the door face', name, lm_of.call(:key),
                        layer_kelvin(3200, opts[:koffset]), fmt(kpt),
                        ACCENT_TILT.to_i)
          else
            puts "  #{name}: the key position lands outside the floor — skipped."
          end

          # ROLE 5 — the rim, OPPOSITE the key across the booth, cool against
          # the warm key. Without it the booth's silhouette dissolves into the
          # wall behind it and the frame goes flat.
          rx = cx - ux * (dlen + RIM_OUT)
          ry = cy - uy * (dlen + RIM_OUT)
          rax = accent_axis(cx - rx, cy - ry)
          if rax && point_in_poly?(rx, ry, poly)
            rrot = Geom::Transformation.rotation(
              Geom::Point3d.new(0, 0, 0),
              Geom::Vector3d.new(rax[0], rax[1], 0), RIM_TILT.degrees)
            place.call(:rim, [rx, ry, z_m], lm_of.call(:rim), rrot)
            puts format('  %s: rim — %.0f lm at %dK, %s, tilted %d deg across ' \
                        'the booth\'s back top edge', name, lm_of.call(:rim),
                        layer_kelvin(5000, opts[:koffset]),
                        fmt([rx, ry, z_m]), RIM_TILT.to_i)
          else
            puts "  #{name}: the rim position lands outside the floor — skipped."
          end

          # ROLE 7 — the foam graze. The foam is a real pyramid field and its
          # material is a flat-diffuse shim with no reflection layer and no
          # texture (observed), so GEOMETRY IS THE ONLY CHANNEL THIS SURFACE
          # HAS. Lit flat from above it vanishes; raked from 4" away across 2"
          # of relief it self-shadows and reads. Grazing is the mechanism, not
          # a nicety.
          # `dlen` — centre to door face — and NOT half the bounding box: an
          # open door leaf swings outside the booth and inflates that box, and
          # a graze light placed from it lands OUTSIDE the back wall instead of
          # 4" inside it (observed on MDL 7272 E, whose leaf adds 15" of depth).
          fx = cx - ux * (dlen - FOAM_OFFSET)
          fy = cy - uy * (dlen - FOAM_OFFSET)
          zrot = Geom::Transformation.rotation(
            Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1),
            Math.atan2(uy, ux))
          place.call(:foam, [fx, fy, bb.max.z - BOOTH_DROP],
                     lm_of.call(:foam), zrot)
          puts format('  %s: foam graze — %.0f lm at %dK, %.0f" inside the ' \
                      'back wall at the tray plane, long axis along the wall',
                      name, lm_of.call(:foam),
                      layer_kelvin(3500, opts[:koffset]), FOAM_OFFSET)
        end
      end

      raise 'Nothing was placed — see the per-room lines above.' if placed.zero?

      # THE REAP - last, and it has to be last. See erase_lights.
      plugs_gone, plugs_left = reap_lights(model, scene, reap_pending)
      unless reap_pending.empty?
        puts format('  swept the replaced rig: %d V-Ray plugin%s deleted, ' \
                    '%d left behind', plugs_gone, plugs_gone == 1 ? '' : 's',
                    plugs_left)
        if plugs_left > 0
          puts '    A left-behind plugin is a light asset with no light — ' \
               'harmless in the render, but it clutters the Asset Editor. ' \
               'Lights dropped before 1.8.0 shared a seed asset and never ' \
               'owned a plugin to delete.'
        end
      end
      model.commit_operation

      probe_after = model_probe(model)
      print_light_report(layers_rep, opts,
                         { :room_lm => room_lm, :booth_lm => booth_lm,
                           :capped => capped_any, :walls => walls_any,
                           :trim => trim_any, :faces => fixture_faces,
                           :mat_before => mat_before,
                           :mat_after => probe_after[:materials] })
      puts ''
      bad = layers_rep.values.map { |r| r[:bad] }.flatten.uniq
      if bad.empty?
        puts '  WILL IT EMIT: every light was made by V-Ray itself and owns ' \
             'its own plugin, every parameter written read back the value it ' \
             'was given, and the tag that carries them is visible and stamped ' \
             'into every saved scene.'
      else
        puts '  WILL IT EMIT: the lights are real V-Ray lights, but ' \
             "#{bad.map(&:to_s).join(', ')} did not read back — check those " \
             'in the Asset Editor before rendering (details above).'
      end
      vis = layers_rep.keys.select { |r| LIGHT_LAYERS[r][:visible] }
      puts format('  %d light instance%s across %d role%s, %d of them VISIBLE ' \
                  'fixtures, in %d container%s.', placed,
                  placed == 1 ? '' : 's', layers_rep.size,
                  layers_rep.size == 1 ? '' : 's',
                  vis.inject(0) { |a, r| a + layers_rep[r][:count] },
                  subjects.size, subjects.size == 1 ? '' : 's')
      if ceilings_added > 0
        puts format('  %d tool-owned ceiling%s stands in the model. Its ' \
                    'lifetime is THE RIG\'S lifetime: the next press sweeps ' \
                    'it, or run WR_DropLights.remove_rig!(Sketchup.active_model) ' \
                    'to take the whole rig away with a verified removal.',
                    ceilings_added, ceilings_added == 1 ? '' : 's')
      end
      puts '  Ctrl+Z removes the lights, the fixtures and the ceiling in one ' \
           'step (their V-Ray plugins may linger in the Asset Editor — a ' \
           're-press deletes the ones it replaces).'
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
