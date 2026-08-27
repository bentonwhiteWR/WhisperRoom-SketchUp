# @title UTHSC Audiology rooms 1-4...
# @tab client
# @cat Draw the room
#
# uthsc-audiology-rooms.rb — the four rooms University of Tennessee Health
# Science Center marked 1 / 2 / 3 / 4 on their suite plan.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/uthsc-audiology-rooms.rb"
#
# Ctrl+Z before re-running. Everything is imperial; units are set to
# Architectural on build.
#
# Client : University of Tennessee Health Science Center,
#          Dept. of Audiology & Speech Pathology (Saravanan Elangovan, Ph.D.)
# Source : "UTFloorLayout.png" — a dimensioned suite plan at the UT Conference
#          Center, marked up in red with room areas and a handwritten 1/2/3/4.
#
# NO BOOTH IS DRAWN AND NO MODEL IS NAMED. Sales quotes the model; this script
# draws the rooms it goes in. Nothing here should be read as a recommendation.
#
# ---------------------------------------------------------------------------
# WHERE THE NUMBERS CAME FROM, AND HOW GOOD THEY ARE
#
# The source is a 941 x 510 px raster, which is LOW resolution: one pixel is
# about 1.5 in of building. So there are two grades of number in this file and
# they are not interchangeable.
#
#   OBSERVED — read as text off the plan's own dimension strings. Each string
#     below was cropped and upscaled 8-16x with LANCZOS before it was trusted,
#     then cross-checked against the pixel geometry of the red room outline and
#     against the plan's printed square-footage. These are as good as the plan.
#
#   DERIVED — not printed anywhere; computed from OBSERVED numbers by closing a
#     chain, or scaled off pixels. Good to about +/- 3 in. Every one is called
#     out at its constant and printed again on build.
#
#   ASSUMED — house defaults. Ceiling, door leaf, door height, wall thickness.
#
# CHECKS THAT PASSED, so the take-off can be trusted as far as it goes:
#
#   Every room's printed area closes on its own dimension strings:
#     Room 3   19'-3 1/2" x 12'-11"        = 249.2 sf   vs printed 249.3   sf
#     Room 4   19'-4 3/4" x 12'-11 1/4"    = 250.9 sf   vs printed 249.44  sf  (0.6% over)
#     Room 1   19'-11 1/4" x 22'-4 1/4"    = 445.7 sf   vs printed 444.92  sf  (0.17% over)
#     Room 2   L-shape, see below          = 334.9 sf   vs printed 333.45  sf  (0.44% over)
#
#   The left-hand depth chain closes on the printed overall:
#     Room 3 12'-11" + the unnumbered 170.87 sf room 14'-1" + Room 2's WEST
#     wall 15'-8 1/4"  =  512.25 in of interior.
#     Printed overall on that side is 44'-1/4" = 528.25 in.
#     Residual 16.00 in over the two intervening partitions = 8.0 in each,
#     against 8.9 in and 7.4 in measured off the pixels. It closes.
#
#     NOTE FOR THE FILE: that overall reads 44'-1/4", NOT 44'-1 1/4". The
#     string was cropped and upscaled 16x to settle it — there is no whole-inch
#     digit before the 1/4.
#
#   The bottom chain closes the same way:
#     Room 2 18'-10 1/4" + Room 1 19'-11 1/4" = 465.50 in interior against the
#     printed 39'-7 3/4" = 475.75 in overall, leaving 10.25 in of partition.
#
# ROOM 2 IS L-SHAPED. This is the one thing on the plan that will catch you out,
# because its printed area does not close on a bounding box:
#     main body 18'-10 1/4" wide x 15'-8 1/4" deep, then the room continues UP
#     on the RIGHT-HAND (east) side only, as a 5'-10 1/2" wide entrance leg.
#     Leg depth  = 22'-4 1/4" (east wall) - 15'-8 1/4" (west wall) = 6'-8" EXACTLY.
#     Notch      = (18'-10 1/4" - 5'-10 1/2") x 6'-8" = 12'-11 3/4" x 6'-8".
#     A whole 6'-8" falling out of two independently printed dimensions is good
#     evidence the set is read right. A rectangle here misses the printed area
#     by 11%; the L misses it by 0.44%, in line with every other room.
#     Room 2's east wall and Room 1's west wall are both 22'-4 1/4" deep and
#     they are adjacent — that shared depth is the cross-check on the relative
#     placement of the two rooms, and it holds.
#
# WHAT IS NOT MEASURED — printed again at the end of every build
#   CEILING    8'-0" house default. THE PLAN GIVES NO CEILING HEIGHT ANYWHERE.
#              This is the number that disqualifies a booth fastest and the one
#              clients forget. It is top of the site-visit list.
#   DOOR_LEAF  3'-0". The only door width the plan actually calls out is a 3'-0"
#              mid-plan, nowhere near these four rooms.
#   DOOR_H     6'-8". There are no elevations on the sheet.
#   WALL_T     4" (Benton, Aug 2026). Cosmetic — walls are mitred OUTWARD from
#              the interior polygon, so this never moves an interior dimension.
#   Door positions and opening widths — scaled off pixels, +/- 3 in. See DOORS_*.
#   The two partitions inside the left-hand depth chain, 8" each by difference.
#
# WHAT COULD NOT BE READ AT ALL — say this out loud to the client
#   Only ONE door per room is legible in the source. The underlying black
#   linework is drawn far lighter than the red markup, and on most wall runs it
#   does not survive the raster at all. So this model shows the doors that could
#   be read; it is NOT evidence that there are no others. In particular no
#   opening could be confirmed or ruled out in the wall Room 1 and Room 2 share.
#
module WR_UTHSC

  # ─── parameters ────────────────────────────────────────────────────────
  CEILING   = 96.0     # ASSUMED. 8'-0" house default — the plan gives no ceiling height.
  DOOR_H    = 80.0     # ASSUMED. 6'-8" standard leaf, no elevations on the sheet.
  DOOR_LEAF = 36.0     # ASSUMED. 3'-0" leaf inside the measured framed opening.
  WALL_T    = 4.0      # ASSUMED, cosmetic. Mitred OUTWARD from the interior face.

  BUILD_1   = true
  BUILD_2   = true
  BUILD_3   = true
  BUILD_4   = true
  DRAW_DOORS = true
  DRAW_DIMS  = true
  DIM_DOORS  = true    # corner -> near jamb, then the opening. How a booth gets placed.
  DIM_SUITE  = true    # the two printed overalls, drawn outside the room chains

  # ─── materials ─────────────────────────────────────────────────────────
  # Names match SketchUp's built-in "Colors-Named" collection, so these load the
  # real .skm when it can be found; otherwise an identically-named colour.
  MAT_FLOOR = "0128_White"            # white floor so dimensions read against it
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_DOOR  = "0043_SaddleBrown"
  MAT_RGB   = {
    "0128_White"          => [255, 255, 255],
    "0099_LightSteelBlue" => [176, 196, 222],
    "0043_SaddleBrown"    => [139,  69,  19]
  }.freeze

  # ═══════════════════════════════════════════════════════════════════════
  # THE TAKE-OFF, in inches, all four rooms in ONE coordinate system so the
  # suite reads as a suite.
  #
  #   origin = the interior SOUTH-WEST corner of the left-hand block, which is
  #            also Room 2's south-west interior corner
  #   +X = east (right on the plan)   +Y = north (up on the plan)
  #
  # The plan does support placing all four relative to each other: the left
  # block has printed overalls on both the bottom (39'-7 3/4") and the left
  # side (44'-1/4"), and every partition below is what those overalls have left
  # over once the printed room dimensions are taken out. Nothing is eyeballed.
  # ═══════════════════════════════════════════════════════════════════════

  # ── printed dimension strings, OBSERVED ────────────────────────────────
  R1_W = 239.25   # 19'-11 1/4"   OBSERVED
  R1_D = 268.25   # 22'-4 1/4"    OBSERVED
  R2_W = 226.25   # 18'-10 1/4"   OBSERVED  (total width, bottom run)
  R2_DE = 268.25  # 22'-4 1/4"    OBSERVED  (EAST wall — the long one, up to the door)
  R2_DW = 188.25  # 15'-8 1/4"    OBSERVED  (WEST wall — the short one)
  R2_LEG = 70.50  #  5'-10 1/2"   OBSERVED  (entrance-leg width)
  R3_W = 231.50   # 19'-3 1/2"    OBSERVED
  R3_D = 155.00   # 12'-11"       OBSERVED
  R4_W = 232.75   # 19'-4 3/4"    OBSERVED
  R4_D = 155.25   # 12'-11 1/4"   OBSERVED
  #   R3_D and R4_D differ by 1/4 in. Both are printed; the raster cannot
  #   resolve a quarter inch, so both are drawn as printed and the two south
  #   faces land 1/4 in apart. That jog is the plan's, not mine.

  BLOCK_W = 475.75  # 39'-7 3/4"  OBSERVED — left block, interior west face to interior east face
  BLOCK_D = 528.25  # 44'-1/4"    OBSERVED — left block, interior south face to interior north face
  CTX_D   = 169.00  # 14'-1"      OBSERVED — the unnumbered 170.87 sf room between 3 and 2
  #   (that room is not drawn; it is only here because Room 3's position
  #    depends on its depth)

  # ── DERIVED by closing a printed chain ─────────────────────────────────
  R2_LEG_D = R2_DE - R2_DW              # 80.00 = 6'-8" exactly. DERIVED, and a clean one.
  R2_NOTCH = R2_W  - R2_LEG             # 155.75 = 12'-11 3/4". DERIVED.
  P_H1     = BLOCK_W - R2_W  - R1_W     # 10.25" partition, Room 2 | Room 1.   DERIVED
  P_H2     = BLOCK_W - R3_W  - R4_W     # 11.50" partition, Room 3 | Room 4.   DERIVED
  P_V      = (BLOCK_D - R2_DW - CTX_D - R3_D) / 2.0
  #   8.00" each for the two partitions in the left-hand depth chain. DERIVED by
  #   difference and split evenly; the pixels read 8.9" and 7.4", i.e. the split
  #   is inside the read tolerance either way.

  # ── the four interior polygons, wound COUNTER-CLOCKWISE ────────────────
  # Room 2 — the L. Six runs. Vertex 4 is the reflex corner of the notch.
  R2_X0 = 0.0
  R2_Y0 = 0.0
  ROOM_2 = [
    [ R2_X0,                 R2_Y0                 ],  # 0  SW
    [ R2_X0 + R2_W,          R2_Y0                 ],  # 1  SE   south run 18'-10 1/4"
    [ R2_X0 + R2_W,          R2_Y0 + R2_DE         ],  # 2  NE   east run 22'-4 1/4"
    [ R2_X0 + R2_NOTCH,      R2_Y0 + R2_DE         ],  # 3       leg north run 5'-10 1/2"
    [ R2_X0 + R2_NOTCH,      R2_Y0 + R2_DW         ],  # 4       leg west run 6'-8" (reflex)
    [ R2_X0,                 R2_Y0 + R2_DW         ]   # 5  NW   main north run 12'-11 3/4"
  ].freeze
  # width chain closes : 155.75 + 70.50 = 226.25 = R2_W
  # depth chain closes : 188.25 + 80.00 = 268.25 = R2_DE

  # Room 1 — east of Room 2, same south face, same 22'-4 1/4" depth.
  R1_X0 = R2_W + P_H1          # 236.50
  R1_Y0 = 0.0
  ROOM_1 = [
    [ R1_X0,          R1_Y0          ],  # 0  SW
    [ R1_X0 + R1_W,   R1_Y0          ],  # 1  SE
    [ R1_X0 + R1_W,   R1_Y0 + R1_D   ],  # 2  NE
    [ R1_X0,          R1_Y0 + R1_D   ]   # 3  NW
  ].freeze
  # R1_X0 + R1_W = 475.75 = BLOCK_W. The bottom chain closes on the printed overall.

  # Room 3 — top-left. Its north face IS the block's north face.
  R3_X0 = 0.0
  R3_Y0 = BLOCK_D - R3_D       # 373.25
  ROOM_3 = [
    [ R3_X0,          R3_Y0          ],  # 0  SW
    [ R3_X0 + R3_W,   R3_Y0          ],  # 1  SE
    [ R3_X0 + R3_W,   R3_Y0 + R3_D   ],  # 2  NE
    [ R3_X0,          R3_Y0 + R3_D   ]   # 3  NW
  ].freeze
  # Depth chain up the left side: 188.25 + 8.00 + 169.00 + 8.00 + 155.00 = 528.25 = BLOCK_D.

  # Room 4 — top-right. Shares Room 3's north face; east face is the block's.
  R4_X0 = R3_W + P_H2          # 243.00
  R4_Y0 = BLOCK_D - R4_D       # 373.00
  ROOM_4 = [
    [ R4_X0,          R4_Y0          ],  # 0  SW
    [ R4_X0 + R4_W,   R4_Y0          ],  # 1  SE
    [ R4_X0 + R4_W,   R4_Y0 + R4_D   ],  # 2  NE
    [ R4_X0,          R4_Y0 + R4_D   ]   # 3  NW
  ].freeze
  # R4_X0 + R4_W = 475.75 = BLOCK_W. The top chain closes on the same overall.

  # ── doors ──────────────────────────────────────────────────────────────
  # :edge  polygon edge index (edge i runs point i -> i+1)
  # :at    distance ALONG that edge, from its FIRST point to the near jamb
  # :w     the framed opening cut in the wall
  # :leaf  the leaf drawn in it (DOOR_LEAF, assumed)
  # :hinge :start or :end of the opening, in the edge's own direction
  # :swing :in draws the leaf into the room, :out draws it away
  #
  # EVERY NUMBER IN THESE FOUR TABLES IS DERIVED, NOT PRINTED. The plan carries
  # no dimension to any of these doors. Positions and opening widths were scaled
  # off the wall gaps in the raster, so they are good to about +/- 3 in and each
  # one wants a tape on site before anything is ordered.
  #
  # What IS solid is the pattern, and it is the same in all four rooms: one door
  # near the EAST end of the wall, hinged on its EAST jamb, swinging INTO the
  # room, in a framed opening scaling 37-42 in — consistent with a 3'-0" leaf in
  # its frame. Four independent reads agreeing is why the hinge sides are stated
  # rather than hedged.

  DOORS_1 = [
    # north wall, edge 2, which runs NE -> NW, so :at is measured from the NE corner
    { :edge => 2, :at => 16.75, :w => 38.5, :leaf => DOOR_LEAF, :hinge => :start, :swing => :in }
  ].freeze
  #   NE corner -> near jamb 16 3/4", opening 38 1/2", then 184" back to the NW corner.
  #   16.75 + 38.5 + 184.0 = 239.25 = R1_W. Closes.

  DOORS_2 = [
    # leg north wall, edge 2, which runs NE -> west, so :at is from the leg's NE corner
    { :edge => 2, :at => 13.25, :w => 37.0, :leaf => DOOR_LEAF, :hinge => :start, :swing => :in }
  ].freeze
  #   Leg NE corner -> near jamb 13 1/4", opening 37", then 20 1/4" to the leg's NW corner.
  #   13.25 + 37.0 + 20.25 = 70.50 = R2_LEG. Closes.

  DOORS_3 = [
    # south wall, edge 0, which runs SW -> SE, so :at is from the SW corner
    { :edge => 0, :at => 179.5, :w => 41.5, :leaf => DOOR_LEAF, :hinge => :end, :swing => :in }
  ].freeze
  #   SW corner -> near jamb 179 1/2", opening 41 1/2", then 10 1/2" to the SE corner.
  #   179.5 + 41.5 + 10.5 = 231.50 = R3_W. Closes.

  DOORS_4 = [
    # south wall, edge 0, SW -> SE
    { :edge => 0, :at => 177.0, :w => 40.0, :leaf => DOOR_LEAF, :hinge => :end, :swing => :in }
  ].freeze
  #   SW corner -> near jamb 177", opening 40", then 15 3/4" to the SE corner.
  #   177.0 + 40.0 + 15.75 = 232.75 = R4_W. Closes.

  # ═══════════════════════════════════════════════════════════════════════
  # geometry helpers — same shapes as csusb-rooms.rb, which is the working
  # example for this deliverable
  # ═══════════════════════════════════════════════════════════════════════
  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, color = nil)
    layer = model.layers[name] || model.layers.add(name)
    layer.color = color if color
    layer
  end

  # Signed area. Which side is "outside" is never hard-coded — a polygon wound
  # the other way would otherwise build its walls INWARD and quietly eat the
  # wall thickness off every interior dimension.
  def self.ccw?(poly)
    s = 0.0
    n = poly.length
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      s += (ax * by) - (bx * ay)
    end
    s > 0.0
  end

  def self.edge_dirs(poly)
    ccw = ccw?(poly)
    n = poly.length
    dirs = []
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      dx = bx - ax
      dy = by - ay
      len = Math.sqrt((dx * dx) + (dy * dy))
      len = 1.0 if len < 1.0e-9
      ux = dx / len
      uy = dy / len
      dirs << { :u => [ux, uy], :n => (ccw ? [uy, -ux] : [-uy, ux]), :len => len }
    end
    dirs
  end

  # Mitred outer polygon: each vertex is where the two offset wall faces meet.
  # This squares the corners instead of letting wall solids cross into an X, and
  # it handles Room 2's reflex corner as well as the convex ones.
  def self.mitre(poly, dirs, t)
    n = poly.length
    out = []
    n.times do |i|
      pv = dirs[(i - 1) % n][:n]
      nv = dirs[i][:n]
      c  = (pv[0] * nv[0]) + (pv[1] * nv[1])
      if (1.0 + c).abs < 0.1
        out << [poly[i][0] + (nv[0] * t), poly[i][1] + (nv[1] * t)]
      else
        k = t / (1.0 + c)
        out << [poly[i][0] + (k * (pv[0] + nv[0])), poly[i][1] + (k * (pv[1] + nv[1]))]
      end
    end
    out
  end

  # Fetch a Colors-Named material, loading the real .skm when it can be found
  # and falling back to an identically-named colour when it can't.
  def self.material(model, name)
    m = model.materials[name]
    return m if m
    begin
      base = Sketchup.find_support_file("Materials")
      if base
        path = File.join(base, "Colors-Named", "#{name}.skm")
        return model.materials.load(path) if File.exist?(path)
      end
    rescue StandardError
      # fall through to the colour below
    end
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(MAT_RGB[name] || [200, 200, 200]))
    m
  end

  def self.slab(parent, poly, name, layer)
    grp = parent.add_group
    f = grp.entities.add_face(poly.map { |p| pt(p[0], p[1], 0.0) })
    f.reverse! if f && f.normal.z < 0     # front face up, so it takes paint cleanly
    grp.name  = name
    grp.layer = layer
    grp
  end

  def self.quad(parent, corners, z, h, name)
    return if h <= 0.01
    g = parent.entities.add_group
    f = g.entities.add_face(corners.map { |p| pt(p[0], p[1], z) })
    return if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    g.name = name
    g
  end

  # Walls mitred outward from the interior polygon, split around each opening,
  # header over each opening.
  def self.build_walls(parent, poly, height, layer, name, doors)
    dirs  = edge_dirs(poly)
    outer = mitre(poly, dirs, WALL_T)
    walls = parent.add_group
    walls.name  = name
    walls.layer = layer
    n = poly.length

    n.times do |i|
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      len    = dirs[i][:len]
      next if len < 0.01

      inner = lambda { |d| [ax + (ux * d), ay + (uy * d)] }
      # outer point at distance d: the mitred corner at the ends, a plain offset between
      outp = lambda do |d|
        return outer[i]           if d <= 0.001
        return outer[(i + 1) % n] if d >= len - 0.001
        ip = inner.call(d)
        [ip[0] + (nx * WALL_T), ip[1] + (ny * WALL_T)]
      end

      ops = doors.select { |dr| dr[:edge] == i }
                 .map    { |dr| [dr[:at], [dr[:at] + dr[:w], len].min] }
                 .sort_by { |o| o[0] }

      marks = [0.0]
      ops.each { |o| marks << o[0] << o[1] }
      marks << len

      k = 0
      while k < marks.length - 1
        s = marks[k]
        e = marks[k + 1]
        if (e - s) > 0.05
          quad(walls, [inner.call(s), inner.call(e), outp.call(e), outp.call(s)], 0.0, height, "wall")
        end
        k += 2
      end

      ops.each do |o|
        quad(walls,
             [inner.call(o[0]), inner.call(o[1]), outp.call(o[1]), outp.call(o[0])],
             DOOR_H, height - DOOR_H, "header")
      end
    end
    walls
  end

  # Leaf drawn open 90 degrees on the hinge side that was read off the plan's
  # own leaf and arc, plus the floor swing arc. The leaf is DOOR_LEAF wide and
  # the opening is :w — they are not the same number here, because the opening
  # is what scales off the drawing and the leaf is a house assumption.
  def self.build_doors(parent, poly, doors, layer, name)
    dirs = edge_dirs(poly)
    grp  = parent.add_group
    grp.name  = name
    grp.layer = layer

    doors.each do |d|
      i = d[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      leaf_w = d[:leaf] || d[:w]

      if d[:hinge] == :start
        hx = ax + (ux * d[:at])
        hy = ay + (uy * d[:at])
        cx = ux
        cy = uy
      else
        hx = ax + (ux * (d[:at] + d[:w]))
        hy = ay + (uy * (d[:at] + d[:w]))
        cx = -ux
        cy = -uy
      end
      sx = (d[:swing] == :out) ? nx : -nx
      sy = (d[:swing] == :out) ? ny : -ny

      t = 1.75
      leaf = [
        [hx,                                hy                               ],
        [hx + (sx * leaf_w),                hy + (sy * leaf_w)               ],
        [hx + (sx * leaf_w) + (cx * t),     hy + (sy * leaf_w) + (cy * t)    ],
        [hx + (cx * t),                     hy + (cy * t)                    ]
      ]
      quad(grp, leaf, 0.0, DOOR_H, "door leaf #{leaf_w.round}\" ASSUMED, swings #{d[:swing]}")

      cross = (cx * sy) - (cy * sx)
      grp.entities.add_arc(pt(hx, hy, 0.25),
                           Geom::Vector3d.new(cx, cy, 0),
                           Geom::Vector3d.new(0, 0, cross > 0 ? 1 : -1),
                           leaf_w, 0.degrees, 90.degrees, 16)
    end
    grp
  end

  def self.dim(ents, a, b, off)
    return unless DRAW_DIMS
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  # Door dimensions: wall corner -> near jamb, then the opening width. This is
  # what you need to place a booth against a wall, so it is not optional.
  def self.dim_doors(ents, poly, doors)
    return unless DIM_DOORS
    dirs = edge_dirs(poly)
    doors.each do |d|
      i = d[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      off1 = Geom::Vector3d.new(nx * (WALL_T + 18.0), ny * (WALL_T + 18.0), 0)
      off2 = Geom::Vector3d.new(nx * (WALL_T + 36.0), ny * (WALL_T + 36.0), 0)
      corner = pt(ax, ay)
      near   = pt(ax + (ux * d[:at]),           ay + (uy * d[:at]))
      far    = pt(ax + (ux * (d[:at] + d[:w])), ay + (uy * (d[:at] + d[:w])))
      dim(ents, corner, near, off1)   # corner -> near jamb
      dim(ents, near,   far,  off2)   # the opening itself
    end
  end

  # All four sides of a rectangular room, plus a note.
  def self.dim_rect(ents, poly)
    sw = poly[0]
    se = poly[1]
    ne = poly[2]
    nw = poly[3]
    dim(ents, pt(sw[0], sw[1]), pt(se[0], se[1]), Geom::Vector3d.new(0, -(WALL_T + 22.0), 0))
    dim(ents, pt(nw[0], nw[1]), pt(ne[0], ne[1]), Geom::Vector3d.new(0,  (WALL_T + 22.0), 0))
    dim(ents, pt(sw[0], sw[1]), pt(nw[0], nw[1]), Geom::Vector3d.new(-(WALL_T + 22.0), 0, 0))
    dim(ents, pt(se[0], se[1]), pt(ne[0], ne[1]), Geom::Vector3d.new( (WALL_T + 22.0), 0, 0))
  end

  def self.note(ents, text, x, y, layer)
    t = ents.add_text(text, pt(x, y, 1.0))
    t.layer = layer if t
    t
  end

  def self.set_imperial(model)
    o = model.options["UnitsOptions"]
    o["LengthFormat"] = Length::Architectural
    o["LengthUnit"]   = Length::Inches
  rescue StandardError => e
    puts "  (couldn't set units automatically: #{e.message} — set Model Info > Units to Architectural)"
  end

  # One room: floor, walls, doors. Dimensions are done by the caller because
  # Room 2's are not a rectangle's.
  def self.build_room(parent, poly, doors, label, t_floor, t_room, t_door,
                      m_floor, m_wall, m_door)
    g = parent.add_group
    g.name = label

    f = slab(g.entities, poly, "floor", t_floor)
    f.material = m_floor if f

    w = build_walls(g.entities, poly, CEILING, t_room, "walls", doors)
    w.material = m_wall if w

    if DRAW_DOORS
      d = build_doors(g.entities, poly, doors, t_door, "doors")
      d.material = m_door if d
    end
    g
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    set_imperial(model)
    model.start_operation("UTHSC Audiology rooms 1-4", true)

    t_room  = tag(model, "WR-Room",  Sketchup::Color.new(120, 128, 140))
    t_floor = tag(model, "WR-Floor", Sketchup::Color.new(200, 200, 200))
    t_door  = tag(model, "WR-Doors", Sketchup::Color.new( 64, 102, 124))
    t_note  = tag(model, "WR-Notes", Sketchup::Color.new( 30,  30,  30))

    m_floor = material(model, MAT_FLOOR)
    m_wall  = material(model, MAT_WALL)
    m_door  = material(model, MAT_DOOR)

    suite = model.entities.add_group
    suite.name = "UTHSC AUDIOLOGY - SUITE ROOMS 1-4 (true relative positions)"
    ents = suite.entities

    ceiling_note = "Ceiling drawn 8'-0\" — HOUSE DEFAULT, NOT MEASURED."

    # ── ROOM 1 ────────────────────────────────────────────────────────────
    if BUILD_1
      g = build_room(ents, ROOM_1, DOORS_1, "ROOM 1 - 19'-11 1/4\" x 22'-4 1/4\" (444.92 sf)",
                     t_floor, t_room, t_door, m_floor, m_wall, m_door)
      dim_rect(g.entities, ROOM_1)
      dim_doors(g.entities, ROOM_1, DOORS_1)
      note(g.entities,
           "ROOM 1  19'-11 1/4\" x 22'-4 1/4\"  (plan: 444.92 sf)\n" \
           "Both dimensions read off the plan.\n" \
           "Door position + 38 1/2\" opening are DERIVED (scaled, +/-3\").\n" \
           "#{ceiling_note}",
           R1_X0 + 20.0, R1_Y0 + 100.0, t_note)
    end

    # ── ROOM 2 — the L. Every one of the six runs gets its own dimension. ──
    if BUILD_2
      g = build_room(ents, ROOM_2, DOORS_2, "ROOM 2 - L-SHAPED, 18'-10 1/4\" x 22'-4 1/4\" overall (333.45 sf)",
                     t_floor, t_room, t_door, m_floor, m_wall, m_door)
      e = g.entities

      # south — overall 18'-10 1/4", with the width chain projected onto it
      dim(e, pt(R2_X0, R2_Y0), pt(R2_X0 + R2_W, R2_Y0), Geom::Vector3d.new(0, -(WALL_T + 44.0), 0))
      dim(e, pt(R2_X0, R2_Y0), pt(R2_X0 + R2_NOTCH, R2_Y0), Geom::Vector3d.new(0, -(WALL_T + 22.0), 0))
      dim(e, pt(R2_X0 + R2_NOTCH, R2_Y0), pt(R2_X0 + R2_W, R2_Y0), Geom::Vector3d.new(0, -(WALL_T + 22.0), 0))
      #   width chain CLOSES: 155.75 + 70.50 = 226.25. The break at 155.75 is
      #   projected down from the notch, which is where it is actually read.

      # east — overall 22'-4 1/4", with the depth chain projected onto it
      dim(e, pt(R2_X0 + R2_W, R2_Y0), pt(R2_X0 + R2_W, R2_Y0 + R2_DE), Geom::Vector3d.new(WALL_T + 44.0, 0, 0))
      dim(e, pt(R2_X0 + R2_W, R2_Y0), pt(R2_X0 + R2_W, R2_Y0 + R2_DW), Geom::Vector3d.new(WALL_T + 22.0, 0, 0))
      dim(e, pt(R2_X0 + R2_W, R2_Y0 + R2_DW), pt(R2_X0 + R2_W, R2_Y0 + R2_DE), Geom::Vector3d.new(WALL_T + 22.0, 0, 0))
      #   depth chain CLOSES: 188.25 + 80.00 = 268.25. The 188.25 break is
      #   projected across from the west wall, which is where it is read.

      # west — 15'-8 1/4", the short wall
      dim(e, pt(R2_X0, R2_Y0), pt(R2_X0, R2_Y0 + R2_DW), Geom::Vector3d.new(-(WALL_T + 22.0), 0, 0))

      # main-body north — 12'-11 3/4" (the notch run)
      dim(e, pt(R2_X0, R2_Y0 + R2_DW), pt(R2_X0 + R2_NOTCH, R2_Y0 + R2_DW), Geom::Vector3d.new(0, WALL_T + 22.0, 0))

      # leg west — 6'-8"
      dim(e, pt(R2_X0 + R2_NOTCH, R2_Y0 + R2_DW), pt(R2_X0 + R2_NOTCH, R2_Y0 + R2_DE), Geom::Vector3d.new(-(WALL_T + 22.0), 0, 0))

      # leg north — 5'-10 1/2"
      dim(e, pt(R2_X0 + R2_NOTCH, R2_Y0 + R2_DE), pt(R2_X0 + R2_W, R2_Y0 + R2_DE), Geom::Vector3d.new(0, WALL_T + 22.0, 0))

      dim_doors(e, ROOM_2, DOORS_2)

      note(e,
           "ROOM 2  L-SHAPED  (plan: 333.45 sf; the L computes 334.94 sf, 0.44% over)\n" \
           "Main body 18'-10 1/4\" x 15'-8 1/4\", entrance leg 5'-10 1/2\" wide on the EAST.\n" \
           "Leg depth 6'-8\" is DERIVED: 22'-4 1/4\" east wall - 15'-8 1/4\" west wall.\n" \
           "Notch 12'-11 3/4\" x 6'-8\" is DERIVED the same way.\n" \
           "Width chain closes 12'-11 3/4\" + 5'-10 1/2\" = 18'-10 1/4\".\n" \
           "Depth chain closes 15'-8 1/4\" + 6'-8\" = 22'-4 1/4\".\n" \
           "Door position + 37\" opening are DERIVED (scaled, +/-3\").\n" \
           "#{ceiling_note}",
           R2_X0 + 20.0, R2_Y0 + 60.0, t_note)
    end

    # ── ROOM 3 ────────────────────────────────────────────────────────────
    if BUILD_3
      g = build_room(ents, ROOM_3, DOORS_3, "ROOM 3 - 19'-3 1/2\" x 12'-11\" (249.3 sf)",
                     t_floor, t_room, t_door, m_floor, m_wall, m_door)
      dim_rect(g.entities, ROOM_3)
      dim_doors(g.entities, ROOM_3, DOORS_3)
      note(g.entities,
           "ROOM 3  19'-3 1/2\" x 12'-11\"  (plan: 249.3 sf)\n" \
           "Both dimensions read off the plan.\n" \
           "Door position + 41 1/2\" opening are DERIVED (scaled, +/-3\").\n" \
           "#{ceiling_note}",
           R3_X0 + 20.0, R3_Y0 + 60.0, t_note)
    end

    # ── ROOM 4 ────────────────────────────────────────────────────────────
    if BUILD_4
      g = build_room(ents, ROOM_4, DOORS_4, "ROOM 4 - 19'-4 3/4\" x 12'-11 1/4\" (249.44 sf)",
                     t_floor, t_room, t_door, m_floor, m_wall, m_door)
      dim_rect(g.entities, ROOM_4)
      dim_doors(g.entities, ROOM_4, DOORS_4)
      note(g.entities,
           "ROOM 4  19'-4 3/4\" x 12'-11 1/4\"  (plan: 249.44 sf; the box computes 250.9, 0.6% over)\n" \
           "Both dimensions read off the plan.\n" \
           "Door position + 40\" opening are DERIVED (scaled, +/-3\").\n" \
           "#{ceiling_note}",
           R4_X0 + 20.0, R4_Y0 + 60.0, t_note)
    end

    # ── the two printed suite overalls, outside every room chain ──────────
    # These are the numbers the room positions were closed against, so they are
    # on the drawing rather than only in a comment.
    if DIM_SUITE && DRAW_DIMS
      dim(ents, pt(0.0, 0.0), pt(BLOCK_W, 0.0), Geom::Vector3d.new(0, -(WALL_T + 90.0), 0))   # 39'-7 3/4"
      dim(ents, pt(0.0, 0.0), pt(0.0, BLOCK_D), Geom::Vector3d.new(-(WALL_T + 90.0), 0, 0))   # 44'-1/4"

      # left-hand depth chain, inside that overall. The two 8" segments are the
      # DERIVED partitions; everything else in the chain is printed.
      y0 = R2_DW
      y1 = y0 + P_V
      y2 = y1 + CTX_D
      y3 = y2 + P_V
      dim(ents, pt(0.0, 0.0), pt(0.0, y0), Geom::Vector3d.new(-(WALL_T + 62.0), 0, 0))  # 15'-8 1/4"  observed
      dim(ents, pt(0.0, y0),  pt(0.0, y1), Geom::Vector3d.new(-(WALL_T + 62.0), 0, 0))  # 8"  DERIVED partition
      dim(ents, pt(0.0, y1),  pt(0.0, y2), Geom::Vector3d.new(-(WALL_T + 62.0), 0, 0))  # 14'-1"      observed
      dim(ents, pt(0.0, y2),  pt(0.0, y3), Geom::Vector3d.new(-(WALL_T + 62.0), 0, 0))  # 8"  DERIVED partition
      dim(ents, pt(0.0, y3),  pt(0.0, BLOCK_D), Geom::Vector3d.new(-(WALL_T + 62.0), 0, 0))  # 12'-11" observed
      #   Chain closes on the overall: 188.25 + 8 + 169 + 8 + 155 = 528.25 = 44'-1/4".
      #   The middle 14'-1" run is the unnumbered 170.87 sf room, which is NOT
      #   drawn — it is in the chain only because Room 3's position depends on it.

      note(ents,
           "UTHSC Dept. of Audiology & Speech Pathology — rooms marked 1, 2, 3, 4.\n" \
           "Drawn to the plan's own interior dimension strings. NO BOOTH IS SHOWN:\n" \
           "the model comes off the sales quote, not off this drawing.\n" \
           "\n" \
           "The 14'-1\" gap in the left-hand chain is an unnumbered 170.87 sf room,\n" \
           "not drawn. The two 8\" runs beside it are DERIVED partitions.\n" \
           "\n" \
           "CEILINGS ARE NOT MEASURED. All four are drawn at the 8'-0\" house\n" \
           "default because the plan states no ceiling height anywhere. Ceiling\n" \
           "height disqualifies a booth faster than floor area does — get a tape\n" \
           "on all four before anything is quoted as fitting.",
           -150.0, BLOCK_D + 130.0, t_note)
    end

    model.commit_operation
    model.active_view.zoom_extents

    puts ""
    puts "UTHSC Audiology — rooms 1, 2, 3, 4 built in true relative position."
    puts "Architectural units. Everything on WR-* tags. NO BOOTH DRAWN."
    puts ""
    puts "  ROOM 1  19'-11 1/4\" x 22'-4 1/4\"   plan 444.92 sf   (computes 445.7)"
    puts "  ROOM 2  L-SHAPED: main 18'-10 1/4\" x 15'-8 1/4\", east leg 5'-10 1/2\" x 6'-8\""
    puts "          overall 18'-10 1/4\" x 22'-4 1/4\"   plan 333.45 sf   (computes 334.94)"
    puts "  ROOM 3  19'-3 1/2\" x 12'-11\"       plan 249.3 sf    (computes 249.2)"
    puts "  ROOM 4  19'-4 3/4\" x 12'-11 1/4\"   plan 249.44 sf   (computes 250.9)"
    puts ""
    puts "  Walls #{WALL_T}\" thick, mitred at every corner including Room 2's inside"
    puts "  corner, extruded OUTWARD from the interior face."
    puts "  Openings cut to #{DOOR_H}\" with a header over; leaves drawn open 90 degrees."
    puts ""
    puts "  ── NOT MEASURED. Do not let any of this become a commitment. ──"
    puts "  CEILINGS   all four drawn at #{CEILING.round}\" (8'-0\" house default)."
    puts "             THE PLAN STATES NO CEILING HEIGHT. Measure all four on site."
    puts "  DOOR_H     #{DOOR_H.round}\" (6'-8\" standard). No elevations on the sheet."
    puts "  DOOR_LEAF  #{DOOR_LEAF.round}\" (3'-0\" assumed inside each measured opening)."
    puts "  DOORS      every door position and opening width is DERIVED — scaled off"
    puts "             the raster, +/- 3\". The plan dimensions none of them."
    puts "             Only ONE door per room is legible in the source. That is not"
    puts "             evidence there are no others; the underlying linework is too"
    puts "             light to read on most wall runs. No opening could be confirmed"
    puts "             or ruled out in the wall Rooms 1 and 2 share."
    puts "  PARTITIONS 10 1/4\" (R2|R1), 11 1/2\" (R3|R4), 8\" x2 in the left depth"
    puts "             chain — all DERIVED by closing a printed overall."
    puts "  R2 LEG     6'-8\" leg depth and 12'-11 3/4\" notch are DERIVED by"
    puts "             subtracting the two printed wall lengths. They land on a"
    puts "             whole 6'-8\", and the area then closes to 0.44%."
    puts "  WALL_T     #{WALL_T.round}\" cosmetic — built outward, never moves an interior dim."
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end
end

WR_UTHSC.build
