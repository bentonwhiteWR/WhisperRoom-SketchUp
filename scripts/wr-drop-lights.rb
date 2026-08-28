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
#        ceiling, and (if the optional Accent seed exists) one accent light
#        tilted 35 degrees at its door face — the merchandise layer.
#
#   Design source: .forge/researcher/interior-lighting-design.md — every
#   spacing, standoff, footcandle and Kelvin number below traces there.
#   Superseded: the single-troffer-per-bbox behaviour this file used to have.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb"
#
# ===========================================================================
# WHY SEED COMPONENTS AND NOT THE V-RAY API
#
# The documented V-Ray Ruby API has NO light class — see
# reference/vray-ruby-api.md — and anything injected into the render scene
# that is not in the SketchUp model is wiped on every re-export. But a V-Ray
# light IS a SketchUp component instance carrying the extension's attributes:
# save one as a .skp once and placing copies is definitions.load +
# add_instance. Copies share ONE light asset, so one Asset Editor slider
# tunes every copy at once — which is exactly why this rig uses one seed PER
# LAYER: three seeds = three independent brightness sliders for free.
#
# ===========================================================================
# THE SEEDS — AUTHORED ONCE BY HAND, OR MINTED FROM ONE HAND-MADE LIGHT
#
# All in scripts/vray-seeds/, each drawn AT THE COMPONENT ORIGIN, emitting
# face DOWN (-Z), Units = Luminous Power (lm), Color Mode = Temperature at
# 3000K, Invisible = ON:
#
#   WR Light Downlight.skp   12" x 12"   3,000 lm   ambient grid
#   WR Light Wallwash.skp     6" x 24"   1,500 lm   feature wall (long side
#                                                   along the wall)
#   WR Light Booth.skp       12" x 24"   1,000 lm   booth interior
#   WR Light Accent.skp      12" x 12"   6,000 lm   booth face accent —
#                            OPTIONAL, Directionality ~0.5; until it exists
#                            the accent layer is skipped with a console note.
#
# Nobody has to author all of them by hand. Draw ONE V-Ray rectangle
# light (V-Ray toolbar > Lights > Rectangle Light, at the origin, facing
# down) and press the button: when seeds are missing and such a light is
# found, the tool offers (Yes/No, default No — it writes files to disk) to
# MINT the missing .skp seeds as copies of it, then carries on placing in
# the same press. A copy is made with add_instance + make_unique — a real
# duplicate of the hand-made definition — because a V-Ray light CANNOT be
# synthesized from Ruby (no light API, reference/vray-ruby-api.md) and a
# file that merely LOOKS like a light emits nothing, silently, in a render
# an hour later. A copy that lost the source's V-Ray dictionaries is
# refused, never saved. Sizes and intensities are NOT set on the copies —
# where V-Ray stores them is unproven — so minting prints the exact Asset
# Editor values to set per seed, plus a full attribute-dictionary dump of
# the source light to paste back to Claude (that dump is the evidence that
# will let a later version set the values in code).
#
# The accent seed is never minted: it needs Directionality ~0.5 set by
# hand, and a plain copy would silently be a wrong light. It stays
# optional, authored by hand when wanted.
#
# A layer whose seed is missing (and not minted) is refused BY NAME; the
# other layers still place. If the older "WR Interior Light.skp" (24x48
# troffer) exists it is accepted for the Downlight role with a console note.
# NOTE install-plugin.py bundles only .rb files — the seeds ride in with a
# repo checkout (git pull). Minted seeds land in the first
# scripts/vray-seeds/ this machine has (created if needed) — commit them.
#
# ===========================================================================
# BRIGHTNESS / WARMTH / EXPOSURE ARE PRINTED, NOT WRITTEN — THE SEAM
#
# Whether Ruby can write a V-Ray light's intensity/temperature (and the
# camera's exposure) without the write being wiped on the next export is
# undetermined until Benton runs the probe in
# .forge/researcher/interior-lighting-design.md §3.3. Until that probe says
# yes, this tool NEVER calls scene.change on a light or camera plugin — a
# wrong write into V-Ray settings persists in the model. Instead the pop-up's
# Brightness / Warmth / exposure choices become a printed Asset Editor
# recipe: the exact lumen number per seed, the Kelvin, the EV. The single
# method print_asset_advice (marked V-RAY WRITE SEAM below) is where a real
# write goes later — swap its body, keep its inputs, nothing else moves.
#
# V-Ray's default exposure (EV 14.2) is full-sun exterior; a correctly-lit
# 40 fc interior at that EV renders 30-60x too dark. No lumen value fixes a
# wrong exposure — hence the "Set interior exposure" advice line (EV 8).
#
# ===========================================================================
# WHAT A PRESS DOES — ONE OPERATION, ONE Ctrl+Z
#
#   1. Reads the selection: groups and component instances only — it never
#      guesses which things in a model are rooms. Lights it dropped earlier
#      are never treated as rooms (never lights its own lights).
#   2. Pops the settings dialog (UI.inputbox, four dropdowns + one yes/no).
#   3. If seed .skp files are missing: offers (default No) to mint them
#      from a hand-made V-Ray light in the model — see the seeds section
#      above — then carries on in the same press.
#   4. Removes any lights IT previously dropped inside the selected rooms
#      (found by their WR_DropLights attribute) — a re-press re-places.
#   5. Per selected room: reads the WR-Floor polygon (bounding-box fallback,
#      LOUD, when there is none — booths and legacy rooms are legitimate),
#      the wall top, the doors; finds obstructions (a booth under the light
#      plane); places the layers; prints every number it used.
#   6. Tags everything "WR Lights"; prints the per-seed lumen targets so the
#      Asset Editor sliders can be nudged to the computed values.
#
# Lights go in the CURRENT drawing context, never inside the client's room
# group, so coordinates agree with the selections' own bounding boxes.
#
# ===========================================================================
# THIS SCRIPT HAS NOT BEEN RUN IN SKETCHUP
#
# No SketchUp and no V-Ray on the machine that wrote it. python
# scripts/rbparse.py proves it parses (the same CRuby 3.2 SketchUp ships) and
# python scripts/rbtest-lights.py RUNS the whole pure placement section —
# grid, polygon tests, L-shape, keep-outs, tiny-room centroid, wall wash,
# lumens — outside SketchUp, lifted verbatim from this file. No instance has
# been placed and no render seen. Everything below fails loudly to the
# console and a messagebox rather than doing nothing.

require 'sketchup.rb'

module WR_DropLights
  DICT = 'WR_DropLights'.freeze
  TAG  = 'WR Lights'.freeze

  # --- placement constants (interior-lighting-design.md; "assumed" ones are
  # --- single constants by design) --------------------------------------------
  DROP          = 6.0    # in below the ceiling plane / booth tray (assumed)
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

  BRIGHT = { 'Dim' => 0.5, 'Normal' => 1.0, 'Bright' => 2.0 }.freeze

  # One seed per layer — shared asset = one Asset Editor slider per layer.
  SEEDS = {
    :downlight => ['WR Light Downlight', '12" x 12", 3,000 lm'],
    :wallwash  => ['WR Light Wallwash',  '6" x 24" (long side along the wall), 1,500 lm'],
    :booth     => ['WR Light Booth',     '12" x 24", 1,000 lm'],
    :accent    => ['WR Light Accent',    '12" x 12", 6,000 lm, Directionality ~0.5']
  }.freeze
  LEGACY_DOWNLIGHT = 'WR Interior Light'.freeze  # accepted for :downlight

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

  # The ambient grid. Returns { :pts, :s, :fallback }. If every candidate is
  # culled (tiny room, wall-to-wall keep-out) the single-centroid clause
  # answers with one point and :fallback => true.
  def self.grid_points(poly, h, density, keepouts)
    xs = poly.map { |p| p[0] }
    ys = poly.map { |p| p[1] }
    minx = xs.min
    miny = ys.min
    lx = xs.max - minx
    ly = ys.max - miny
    s = grid_spacing(h, density)
    nx = [1, (lx / s).ceil].max
    ny = [1, (ly / s).ceil].max
    t = edge_threshold(s, lx / (2.0 * nx), ly / (2.0 * ny))
    cand = []
    axis_points(lx, nx).each do |x|
      axis_points(ly, ny).each { |y| cand << [minx + x, miny + y] }
    end
    keep = cand.select do |p|
      point_in_poly?(p[0], p[1], poly) &&
        edge_dist(p[0], p[1], poly) >= t - 1e-6 &&
        !in_keepout?(p[0], p[1], keepouts)
    end
    return { :pts => keep, :s => s, :fallback => false } unless keep.empty?
    c = poly_centroid(poly)
    c = nil unless c && point_in_poly?(c[0], c[1], poly)
    if c.nil?
      c = cand.select { |p| point_in_poly?(p[0], p[1], poly) }
              .max_by { |p| edge_dist(p[0], p[1], poly) }
    end
    { :pts => c ? [c] : [], :s => s, :fallback => true }
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
    count = (len / (WASH_SPACING * WASH_STANDOFF)).ceil
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

  # ======================================================================
  # END OF THE PURE SECTION — SketchUp API from here down.
  # ======================================================================

  def self.seed_candidates(name)
    home = ENV['USERPROFILE'].to_s
    [
      File.join(__dir__.to_s, 'vray-seeds', "#{name}.skp"),
      File.join(home, 'Documents/Claude/Sketchup/scripts/vray-seeds', "#{name}.skp"),
      File.join(home, 'Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/vray-seeds', "#{name}.skp"),
      File.join(home, 'OneDrive/Documents/Claude/Sketchup/scripts/vray-seeds', "#{name}.skp"),
      File.join(home, 'OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/vray-seeds', "#{name}.skp")
    ].map { |p| p.tr('\\', '/') }.uniq
  end

  def self.seed_path(name)
    seed_candidates(name).find { |p| File.exist?(p) }
  end

  def self.seed_refusal(role)
    name, spec = SEEDS[role]
    "scripts/vray-seeds/#{name}.skp is missing — the #{role} layer is " \
    "refused until it exists.\nAuthor it once on the render machine: V-Ray " \
    "toolbar > Rectangle Light, #{spec}, facing DOWN, drawn at the " \
    "component origin, Units = Luminous Power (lm), Color Mode = " \
    "Temperature 3000K, Invisible = ON, then right-click > Save As into " \
    "scripts/vray-seeds/ as \"#{name}.skp\".\n" \
    'OR draw ONE rectangle light anywhere in the model and press this ' \
    'button again — the tool will offer to mint every missing seed from it.'
  end


  # nil-free seed paths for the requested layers, the roles refused because
  # their file is missing, and the legacy-downlight console note.
  def self.resolve_seeds(opts)
    paths = {}
    refusals = []
    legacy_note = nil
    paths[:downlight] = seed_path(SEEDS[:downlight][0])
    if paths[:downlight].nil?
      legacy = seed_path(LEGACY_DOWNLIGHT)
      if legacy
        paths[:downlight] = legacy
        legacy_note = "using legacy #{LEGACY_DOWNLIGHT}.skp as the Downlight " \
                      'seed — re-save it as WR Light Downlight.skp (12" x 12", ' \
                      '3,000 lm) when convenient.'
      else
        refusals << :downlight
      end
    end
    if opts[:wash]
      paths[:wallwash] = seed_path(SEEDS[:wallwash][0])
      refusals << :wallwash if paths[:wallwash].nil?
    end
    if opts[:booth]
      paths[:booth] = seed_path(SEEDS[:booth][0])
      refusals << :booth if paths[:booth].nil?
      paths[:accent] = seed_path(SEEDS[:accent][0]) # optional — nil = skip
    end
    paths.delete_if { |_, v| v.nil? }
    [paths, refusals, legacy_note]
  end

  # ========================================================================
  # SEED MINTING — the missing .skp seeds, copied from ONE hand-made light
  #
  # A V-Ray light cannot be conjured from Ruby (no light class — see
  # reference/vray-ruby-api.md), and a file assembled from guessed
  # attributes is worse than none: it looks right and emits nothing, an
  # hour later, in a render. So minting only ever COPIES a light V-Ray
  # itself made, and verifies the copy kept the source's dictionaries
  # before saving it.
  # ========================================================================

  # Roles whose seed may be minted. Accent is excluded on purpose: it
  # needs Directionality ~0.5 set by hand; a plain copy would be a wrong
  # light wearing the right name.
  MINTABLE = [:downlight, :wallwash, :booth].freeze

  def self.own_dict_names(ent)
    ad = ent.respond_to?(:attribute_dictionaries) ? ent.attribute_dictionaries : nil
    ad ? ad.map { |d| d.name.to_s } : []
  end

  # Does this look like a V-Ray light? Judged by names only: its definition
  # name plus its attribute-dictionary names (instance and definition) must
  # mention both "vray" and "light". Deliberately strict — minting from a
  # non-light would produce seeds that fail silently in a render.
  def self.vray_light?(ent)
    return false unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
    words = own_dict_names(ent)
    if ent.respond_to?(:definition) && ent.definition
      words += own_dict_names(ent.definition)
      words << ent.definition.name.to_s
    end
    text = words.join(' ')
    !!(text =~ /v-?ray/i && text =~ /light/i)
  end

  # The one light the seeds get copied from: a selected V-Ray light wins,
  # else the model's top level — but only when every candidate is the same
  # light (same definition). Different definitions are a genuine choice
  # this tool refuses to make; it lists them and asks for a selection.
  def self.find_source_light(model)
    sel = model.selection.to_a.select { |e| vray_light?(e) }
    return sel.first if sel.size == 1
    if sel.size > 1
      puts '  Several V-Ray lights are SELECTED — select exactly one (with the rooms) and press again:'
      sel.each { |e| puts "    #{display_name(e)}" }
      return nil
    end
    all = model.entities.to_a.select { |e| vray_light?(e) }
    if all.empty?
      puts '  No V-Ray light found to copy from (searched the selection and the model top level).'
      return nil
    end
    defs = all.map { |e| e.respond_to?(:definition) ? e.definition : nil }.uniq
    if defs.size == 1
      note = all.size == 1 ? 'the only V-Ray light in the model' :
             "all #{all.size} V-Ray lights found are copies of it"
      puts "  Using \"#{display_name(all.first)}\" as the seed source — #{note}."
      return all.first
    end
    puts '  Several DIFFERENT V-Ray lights found — this tool will not guess between them:'
    all.each { |e| puts "    #{display_name(e)}" }
    puts '  Add the one to copy to the selection and press again.'
    nil
  end

  # Where minted seeds land: the first scripts/vray-seeds/ that exists,
  # else the first one whose scripts/ parent exists (created on the spot).
  def self.mint_dir
    dirs = seed_candidates('probe').map { |p| File.dirname(p) }.uniq
    hit = dirs.find { |d| File.directory?(d) }
    return hit if hit
    creatable = dirs.find { |d| File.directory?(File.dirname(d)) }
    return nil if creatable.nil?
    Dir.mkdir(creatable)
    creatable
  end

  def self.dump_dicts(ent, label)
    ad = ent.respond_to?(:attribute_dictionaries) ? ent.attribute_dictionaries : nil
    dicts = ad ? ad.to_a : []
    if dicts.empty?
      puts "  #{label}: no attribute dictionaries"
      return
    end
    puts "  #{label}:"
    dicts.each do |d|
      puts "    dictionary \"#{d.name}\":"
      d.each_pair do |k, v|
        s = v.inspect
        s = "#{s[0, 160]}..." if s.length > 160
        puts "      #{k} = (#{v.class}) #{s}"
      end
      nested = d.attribute_dictionaries
      (nested ? nested.to_a : []).each do |nd|
        puts "      nested dictionary \"#{nd.name}\":"
        nd.each_pair do |k, v|
          s = v.inspect
          s = "#{s[0, 160]}..." if s.length > 160
          puts "        #{k} = (#{v.class}) #{s}"
        end
      end
    end
  end

  # The evidence printout. We do NOT currently know where a V-Ray light
  # stores its size, intensity, colour temperature or invisible flag —
  # this dump of a light V-Ray itself made is how we find out. Printed
  # whenever minting runs.
  def self.dump_light(src)
    d = src.respond_to?(:definition) ? src.definition : nil
    bb = d ? d.bounds : src.bounds
    puts ''
    puts '=== V-RAY LIGHT DUMP — copy this whole block back to Claude ========'
    puts "  class: #{src.class}"
    puts "  definition: #{d ? "\"#{d.name}\"" : '(none)'}"
    puts format('  drawn size (definition bounds): %.2f" x %.2f" x %.2f"',
                bb.width, bb.height, bb.depth)
    o = src.transformation.origin
    puts format('  placed at: (%.2f", %.2f", %.2f")', o.x, o.y, o.z)
    dump_dicts(src, 'instance dictionaries')
    if d
      dump_dicts(d, 'definition dictionaries')
      ents = d.entities.to_a
      kinds = Hash.new(0)
      ents.each { |e| kinds[e.class.to_s.sub('Sketchup::', '')] += 1 }
      puts "  definition contains #{ents.size} entities: " +
           kinds.map { |k, n| "#{n} #{k}" }.join(', ')
      ents.first(12).each_with_index do |e, i|
        dump_dicts(e, "entity[#{i}] (#{e.class.to_s.sub('Sketchup::', '')})")
      end
    end
    puts '=== END DUMP ======================================================='
    puts '  ^ Paste that whole block back to Claude — it is the evidence for'
    puts '    where V-Ray keeps size / intensity / temperature / invisible.'
  end

  # save_copy (SketchUp 2022+) writes the file without re-binding the
  # definition to the path; older SketchUp falls back to save_as.
  def self.save_skp(defn, path)
    ok = defn.respond_to?(:save_copy) ? defn.save_copy(path) : defn.save_as(path)
    raise "SketchUp refused to save #{path}" unless ok
    raise "save reported success but #{path} does not exist" unless File.exist?(path)
  end

  # Mint the given roles' seed files as copies of src. Returns the minted
  # [role, path] pairs. The temp copies are made inside an operation that
  # is ABORTED at the end: the files persist, the model is left untouched.
  def self.mint_seeds(model, src, roles, dir)
    src_def = src.definition
    minted = []
    model.start_operation('Mint V-Ray light seeds', true)
    begin
      roles.each do |role|
        name = SEEDS[role][0]
        path = File.join(dir, "#{name}.skp").tr('\\', '/')
        if File.exist?(path)
          a = UI.messagebox("#{name}.skp already exists:\n#{path}\n\n" \
                            "Overwrite it with a copy of \"#{display_name(src)}\"?",
                            MB_YESNOCANCEL)
          if a == IDCANCEL
            puts '  minting CANCELLED — no further seeds written.'
            break
          end
          if a == IDNO
            puts "  kept the existing #{name}.skp — not overwritten."
            next
          end
        end
        if src_def.name == name
          # The source is itself a placed copy of this very seed (a model
          # made on another machine) — save its definition straight out.
          save_skp(src_def, path)
        else
          temp = model.entities.add_instance(src_def, Geom::Transformation.new)
          temp.make_unique
          d = temp.definition
          raise "make_unique did not copy the light for #{name}" if d == src_def
          lost = own_dict_names(src_def) - own_dict_names(d)
          unless lost.empty?
            raise "the copy for #{name} LOST V-Ray dictionaries #{lost.inspect} — " \
                  'a dead seed will not be saved. Author this one by hand ' \
                  'instead (right-click the light > Save As).'
          end
          begin
            d.name = name
          rescue StandardError => e
            puts "  note: could not rename the copy to \"#{name}\" " \
                 "(#{e.message}) — saved anyway; the file name is what counts."
          end
          save_skp(d, path)
        end
        minted << [role, path]
        puts "  minted #{name}.skp -> #{path}"
      end
    ensure
      model.abort_operation # the temp copies leave the model; the files stay
    end
    minted
  end

  # Minted copies inherit the SOURCE light's size / intensity / colour —
  # where V-Ray stores those is unproven, so this tool does not touch them
  # and prints the hand-off instead.
  def self.print_mint_recipe(minted)
    puts ''
    puts "  MINTED SEEDS CARRY THE SOURCE LIGHT'S SETTINGS. Set each one in"
    puts '  the V-Ray Asset Editor (Lights tab):'
    minted.each { |role, _| puts format('    %-22s -> %s', "\"#{SEEDS[role][0]}\"", SEEDS[role][1]) }
    puts '    every one            -> Units: Luminous Power (lm), Color Mode:'
    puts '                            Temperature 3000K, Invisible: ON'
    puts '  That edits the copies in THIS model. To bake the values into the'
    puts '  seed files for every future model, re-save each tuned light over'
    puts '  its .skp (right-click > Save As) — or keep tuning per model.'
  end

  # The on-the-spot fix for missing seeds. Never a surprise: it writes
  # files to disk, so it asks first and the prompt defaults to No. Returns
  # the source light used when anything was minted, else nil.
  def self.offer_minting(model, refusals)
    roles = refusals & MINTABLE
    return nil if roles.empty?
    # With a source light in hand, offer every missing core seed, not just
    # the refused layers' — one Yes instead of three separate runs.
    MINTABLE.each do |r|
      roles << r if !roles.include?(r) && seed_path(SEEDS[r][0]).nil?
    end
    puts ''
    puts "Missing seed file#{roles.size == 1 ? '' : 's'}: " +
         roles.map { |r| "#{SEEDS[r][0]}.skp" }.join(', ')
    src = find_source_light(model)
    return nil if src.nil?
    dir = mint_dir
    if dir.nil?
      puts '  MINTING IMPOSSIBLE — no scripts/ folder to create vray-seeds/ in. Looked at:'
      seed_candidates(SEEDS[roles.first][0]).each { |p| puts "    #{File.dirname(p)}" }
      return nil
    end
    puts "  They can be minted as copies of \"#{display_name(src)}\" into:"
    puts "    #{dir}"
    ans = UI.inputbox(
      ["Write #{roles.size} seed file#{roles.size == 1 ? '' : 's'} copied from \"#{display_name(src)}\"?"],
      ['No'], ['Yes|No'], 'Missing V-Ray light seeds — mint them?')
    unless ans && ans[0] == 'Yes'
      puts '  Minting declined — the by-name refusals below stand.'
      return nil
    end
    dump_light(src)
    minted = mint_seeds(model, src, roles, dir)
    if minted.empty?
      puts '  Nothing was minted.'
      return nil
    end
    print_mint_recipe(minted)
    src
  end

  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(255, 199, 44)) rescue nil # troffer yellow
    t
  end

  # The rooms/booths to light: groups and component instances from the
  # selection, minus any light this tool itself dropped (selecting the whole
  # model and pressing again must not light the lights).
  def self.containers(model)
    model.selection.to_a
         .select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
         .reject { |e| e.get_attribute(DICT, 'seed') }
  end

  # Previously-dropped lights (any version of this tool) whose origin sits
  # inside any of the given bounding boxes — the ones a re-press replaces.
  def self.stale_lights(ents, boxes)
    ents.grep(Sketchup::ComponentInstance).select do |i|
      next false unless i.get_attribute(DICT, 'seed')
      o = i.transformation.origin
      boxes.any? { |bb| bb.contains?(o) }
    end
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
  #   :fallback (true = bbox rectangle, said loudly by the caller),
  #   :degenerate (true = refuse this room by name).
  def self.room_info(inst)
    tr = inst.transformation
    kids = child_entities(inst).to_a
    floor_g = kids.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        (layer_name(e) == 'WR-Floor' || display_name(e) == 'Floor')
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
        (layer_name(e) == 'WR-Room' || display_name(e) == 'Walls')
    end
    z_top = walls_g ? world_bounds(walls_g, tr).max.z : inst.bounds.max.z

    doors = []
    doors_g = kids.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
        (layer_name(e) == 'WR-Doors' || display_name(e) == 'Doors')
    end
    if doors_g
      dtr = tr * doors_g.transformation
      child_entities(doors_g).to_a.each do |d|
        next unless d.is_a?(Sketchup::Group) || d.is_a?(Sketchup::ComponentInstance)
        next unless display_name(d).start_with?('Opening')
        wb = world_bounds(d, dtr)
        w = [wb.max.x - wb.min.x, wb.max.y - wb.min.y].max
        doors << { :cx => (wb.min.x + wb.max.x) / 2.0,
                   :cy => (wb.min.y + wb.max.y) / 2.0, :w => w }
      end
    end

    { :poly => poly, :z0 => z0, :z_top => z_top, :doors => doors,
      :fallback => false, :degenerate => false,
      :no_walls => walls_g.nil? }
  end

  # ---- obstructions -------------------------------------------------------

  ROOM_CHILD_TAGS = %w[WR-Floor WR-Room WR-Room-Upper WR-Doors
                       WR-Doors-Leaf WR-Notes].freeze
  ROOM_CHILD_NAMES = %w[Floor Walls Doors].freeze

  # Everything that could stand under the light plane of `room`: top-level
  # groups/components plus the room's own non-structural children (a booth
  # dragged inside the group). Returns [{:rect(inflated), :ent, :tr, :bb}].
  def self.obstructions(model, room, poly, z_m, subjects)
    xs = poly.map { |p| p[0] }
    ys = poly.map { |p| p[1] }
    minx = xs.min
    miny = ys.min
    maxx = xs.max
    maxy = ys.max

    cands = []
    model.entities.to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      # Other selected rooms are not obstructions of this one, but a
      # selected BOOTH still obstructs (and is lit by) the room around it.
      next if e == room || (subjects.include?(e) && !booth?(e))
      next if e.get_attribute(DICT, 'seed')
      cands << [e, IDENT]
    end
    child_entities(room).to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if ROOM_CHILD_TAGS.include?(layer_name(e))
      next if ROOM_CHILD_NAMES.include?(display_name(e))
      cands << [e, room.transformation]
    end

    out = []
    cands.each do |e, base|
      bb = base.identity? ? e.bounds : world_bounds(e, base)
      next unless bb.valid?
      next if bb.max.z <= z_m - HEADROOM                      # too short to matter
      next if bb.min.x > maxx || bb.max.x < minx ||           # clear of the floor
              bb.min.y > maxy || bb.max.y < miny
      out << { :ent => e, :tr => base,
               :bb => bb,
               :rect => [bb.min.x - KEEPOUT_PAD, bb.min.y - KEEPOUT_PAD,
                         bb.max.x + KEEPOUT_PAD, bb.max.y + KEEPOUT_PAD] }
    end
    out
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

  # ==== V-RAY WRITE SEAM ===================================================
  # Brightness / Warmth / exposure land HERE and today they are PRINTED as
  # an Asset Editor recipe, never written: whether a scene.change write on a
  # light or camera plugin sticks (or is wiped on the next export) is
  # undetermined until the probe in interior-lighting-design.md §3.3 runs,
  # and a wrong write into V-Ray settings persists in the model. When the
  # probe proves the write path, replace THIS METHOD BODY with the writes
  # and keep the printout as confirmation — its inputs already carry every
  # target value. Nothing outside this method changes.
  def self.print_asset_advice(targets, opts)
    puts ''
    puts '  ASSET EDITOR TARGETS (this tool does not write V-Ray settings;'
    puts '  nudge the sliders to these values):'
    targets.each do |t|
      puts format('    %-22s -> %s lm   (Units: Luminous Power)',
                  "\"#{t[:seed]}\"", t[:lumens].to_s)
    end
    puts format('    every light asset    -> Color Mode: Temperature, %d K', opts[:kelvin])
    if opts[:exposure]
      puts '    Settings > Camera    -> Exposure Value 8 (or enable Auto'
      puts '    Exposure). The default EV 14.2 is full-sun exterior and'
      puts '    renders ANY sane interior rig 30-60x too dark.'
    end
  end
  # ==== END V-RAY WRITE SEAM ==============================================

  def self.fmt(pt)
    format('(%.1f", %.1f", %.1f")', pt[0], pt[1], pt[2])
  end

  # ---- run ----------------------------------------------------------------

  def self.run
    model = Sketchup.active_model
    raise 'No model open.' unless model

    subjects = containers(model)
    if subjects.empty?
      msg = if model.selection.empty?
              'Nothing is selected.'
            else
              'The selection has no group or component in it — only loose ' \
              'geometry or previously dropped lights.'
            end
      UI.messagebox("#{msg}\n\nSelect the room or booth groups to light, " \
                    'then press Drop Interior Lights again. This tool never ' \
                    'guesses which things are rooms.')
      return
    end

    opts = ask
    return unless opts # cancelled

    # Resolve the seeds the requested layers need. A missing seed refuses
    # ITS layer by name — but first the on-the-spot fix: when a hand-made
    # V-Ray light is in the model, offer to mint the missing seed files as
    # copies of it and carry on in the same press.
    paths, refusals, legacy_note = resolve_seeds(opts)
    unless refusals.empty?
      seed_src = offer_minting(model, refusals)
      if seed_src
        if subjects.delete(seed_src)
          puts "  \"#{display_name(seed_src)}\" was selected as the seed " \
               'source — not treated as a room.'
          if subjects.empty?
            puts 'Only the source light was selected — select the rooms ' \
                 'to light and press again.'
            return
          end
        end
        paths, refusals, legacy_note = resolve_seeds(opts)
      end
    end

    unless refusals.empty?
      txt = refusals.map { |r| seed_refusal(r) }.join("\n\n")
      puts ''
      refusals.each { |r| puts "REFUSED (#{r}): #{seed_refusal(r)}" }
      UI.messagebox("#{txt}\n\nLooked in:\n#{seed_candidates(SEEDS[refusals.first][0]).join("\n")}")
      if paths[:downlight].nil?
        puts 'Nothing to place — the ambient Downlight seed is required.'
        return
      end
    end

    model.start_operation('Drop Interior Lights', true)
    begin
      defs = {}
      paths.each do |role, path|
        d = begin
              model.definitions.load(path)
            rescue StandardError => e
              raise "SketchUp could not load the seed component:\n#{path}\n#{e.message}"
            end
        raise "SketchUp could not load the seed component:\n#{path}" if d.nil?
        defs[role] = d
      end

      ents  = model.active_entities
      layer = tag(model)
      boxes = subjects.map(&:bounds).select(&:valid?)
      stale = stale_lights(ents, boxes)
      ents.erase_entities(stale) unless stale.empty?

      puts ''
      puts "Drop Interior Lights — density #{opts[:density]}, brightness " \
           "#{opts[:bright]} (x#{opts[:mult]}), #{opts[:kelvin]}K, " \
           "wash #{opts[:wash] ? 'on' : 'off'}, booth #{opts[:booth] ? 'on' : 'off'}"
      puts "  replaced #{stale.size} previously dropped light#{stale.size == 1 ? '' : 's'}" unless stale.empty?
      puts "  NOTE: #{legacy_note}" if legacy_note

      placed = 0
      down_targets = []   # per-room per-fixture lumen targets, for the advice
      booth_targets = []
      any_wash = false
      any_accent = false

      place = lambda do |role, pt, extra_tr = nil|
        t = Geom::Transformation.translation(Geom::Point3d.new(*pt))
        t = t * extra_tr if extra_tr
        inst = ents.add_instance(defs[role], t)
        raise "add_instance failed (#{role})" if inst.nil?
        inst.layer = layer
        inst.set_attribute(DICT, 'seed', SEEDS[role][0])
        inst.set_attribute(DICT, 'role', role.to_s)
        placed += 1
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
          if defs[:booth]
            bb = s.bounds
            pt = [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0,
                  bb.max.z - DROP]
            place.call(:booth, pt)
            lm = booth_lumens((bb.max.x - bb.min.x) * (bb.max.y - bb.min.y), opts[:mult])
            booth_targets << lm
            puts "  #{name}: selected booth — 1 interior light at #{fmt(pt)}, " \
                 "target #{lm} lm"
          else
            puts "  #{name}: selected booth but the Booth layer is off or its " \
                 'seed is missing — nothing placed here.'
          end
          next
        end

        info = room_info(s)
        if info[:degenerate]
          puts "  REFUSED #{name} — its WR-Floor group has no usable face " \
               '(zero-area floor). Fix the floor or explode/rebuild the room.'
          next
        end
        if info[:fallback]
          puts "  #{name}: NO WR-Floor child found — using the BOUNDING-BOX " \
               'rectangle as the floor. Right for rectangular things; an ' \
               'L-shaped room needs its build-room floor group.'
        end
        puts "  #{name}: no Walls child — ceiling taken from the group top." if info[:no_walls]

        poly = info[:poly]
        h = info[:z_top] - info[:z0]
        if h <= DROP
          puts "  REFUSED #{name} — height #{h.round(1)}\" is not a room."
          next
        end
        z_m = info[:z_top] - DROP

        obst = obstructions(model, s, poly, z_m, subjects)
        keepouts = obst.map { |o| o[:rect] }
        booths = obst.select { |o| booth?(o[:ent]) }
        area = poly_area(poly)

        # A — ambient grid
        grid = grid_points(poly, h, opts[:density], keepouts)
        if grid[:fallback]
          puts "  #{name}: grid fully culled (tiny room or wall-to-wall " \
               "keep-out) — single light at the floor centroid."
        end
        if grid[:pts].empty?
          puts "  REFUSED #{name} — no valid point found inside its floor."
          next
        end
        grid[:pts].each { |p| place.call(:downlight, [p[0], p[1], z_m]) }
        lm = downlight_lumens(area, grid[:pts].size, opts[:mult])
        down_targets << lm
        puts format('  %s: ambient %d light%s, spacing %.0f", ceiling %.0f", ' \
                    'target %d lm per fixture', name, grid[:pts].size,
                    grid[:pts].size == 1 ? '' : 's', grid[:s], h, lm)
        obst.each do |o|
          puts "    keep-out: #{display_name(o[:ent])}" \
               "#{booth?(o[:ent]) ? ' (booth)' : ''}"
        end

        # B — wall wash, opposite the largest door
        if opts[:wash] && defs[:wallwash]
          door = info[:doors].max_by { |d| d[:w] }
          wall_i = nil
          if door
            wall_i = opposite_edge(poly, nearest_edge(poly, door[:cx], door[:cy]))
            puts "  #{name}: wall wash could not find a wall opposite the door — skipped." if wall_i.nil?
          else
            # No doors readable (bbox fallback or door-less room): wash the
            # longest wall and say so.
            n = poly.size
            wall_i = (0...n).max_by do |i|
              a = poly[i]
              b = poly[(i + 1) % n]
              (b[0] - a[0])**2 + (b[1] - a[1])**2
            end
            puts "  #{name}: no door found — washing the LONGEST wall instead " \
                 'of the one opposite a door.'
          end
          if wall_i
            wps = wash_points(poly, wall_i, keepouts)
            if wps.empty?
              puts "  #{name}: every wall-wash position was culled — layer skipped here."
            else
              wps.each { |p| place.call(:wallwash, [p[0], p[1], z_m]) }
              any_wash = true
              puts format('  %s: wall wash %d light%s at 24" standoff on wall ' \
                          'run %d: %s', name, wps.size, wps.size == 1 ? '' : 's',
                          wall_i + 1, wps.map { |p| format('(%.0f, %.0f)', p[0], p[1]) }.join(' '))
            end
          end
        end

        # C — the booth is the merchandise
        if opts[:booth]
          if booths.empty?
            puts "  #{name}: no booth found in this room (looked for WR-Booth-* " \
                 'tags) — booth layers have nothing to do.'
          end
          booths.each do |o|
            bname = display_name(o[:ent])
            bb = o[:bb]
            if defs[:booth]
              pt = [(bb.min.x + bb.max.x) / 2.0, (bb.min.y + bb.max.y) / 2.0,
                    bb.max.z - DROP]
              place.call(:booth, pt)
              lm = booth_lumens((bb.max.x - bb.min.x) * (bb.max.y - bb.min.y), opts[:mult])
              booth_targets << lm
              puts "  #{name}: booth \"#{bname}\" interior light at #{fmt(pt)}, " \
                   "target #{lm} lm"
            end
            if defs[:accent]
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
                    place.call(:accent, apt, rot)
                    any_accent = true
                    puts "  #{name}: booth \"#{bname}\" accent at #{fmt(apt)}, " \
                         "tilted #{ACCENT_TILT.to_i} deg onto the door face"
                  else
                    puts "  #{name}: accent position for \"#{bname}\" lands " \
                         'outside the floor — skipped.'
                  end
                end
              end
            elsif opts[:booth] && !booths.empty?
              puts "  accent layer skipped — optional scripts/vray-seeds/" \
                   "#{SEEDS[:accent][0]}.skp not authored (#{SEEDS[:accent][1]})."
            end
          end
        end
      end

      raise 'Nothing was placed — see the per-room lines above.' if placed.zero?
      model.commit_operation

      targets = []
      unless down_targets.empty?
        targets << { :seed => SEEDS[:downlight][0],
                     :lumens => (down_targets.inject(:+) / down_targets.size.to_f).round }
      end
      targets << { :seed => SEEDS[:wallwash][0],
                   :lumens => targets.first ? (targets.first[:lumens] / 2.0).round : 1500 } if any_wash
      unless booth_targets.empty?
        targets << { :seed => SEEDS[:booth][0],
                     :lumens => (booth_targets.inject(:+) / booth_targets.size.to_f).round }
      end
      targets << { :seed => SEEDS[:accent][0],
                   :lumens => targets.first ? targets.first[:lumens] * 2 : 6000 } if any_accent
      print_asset_advice(targets, opts)
      puts ''
      puts "  #{placed} light#{placed == 1 ? '' : 's'} in #{subjects.size} " \
           "container#{subjects.size == 1 ? '' : 's'}. Ctrl+Z removes them " \
           'all; a re-press replaces them. Move tool and eraser fine-tune.'
    rescue StandardError => e
      model.abort_operation
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
