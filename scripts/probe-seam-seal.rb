# @title Probe Ceiling Seam Seal Fit...
# @shelf dev
#
# THE CROSS-SECTION of a ceiling seam seal and of the ceiling panel edge it
# registers into, printed side by side on the same Z scale.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-seam-seal.rb"
#
# WHY THIS EXISTS, AND WHY THE TWO EXISTING PROBES ARE NOT ENOUGH
#
# probe-components.rb reports a bounding box. probe-levels.rb reports the
# heights of HORIZONTAL faces. A slot is neither: it is a notch cut into the
# panel, bounded by VERTICAL faces, running along the joint. Both existing
# probes are blind to it by construction — a panel with a slot down its edge has
# exactly the same bounding box and exactly the same horizontal-face levels as
# one without.
#
# So this measures the thing neither of them can: the PROFILE. For an extruded
# part, every edge whose two endpoints share the same coordinate along the long
# axis lies in a cross-section plane, and the set of them IS the profile. No
# intersection, no boolean, nothing written to the model.
#
# WHAT IS ALREADY KNOWN, so that this is not re-measuring settled ground.
# From _face-levels.tsv in the parts folder, measured 2026-08-14 (observed):
#
#   STDSS CL5      6.500 x  58.000 x 2.000    levels 2.0000 1.2500 1.0000  0.0000
#   STDSS CL6      6.500 x  70.000 x 2.000    levels 2.0000 1.2500 1.0000  0.0000
#   STDSS CL7      6.500 x  82.000 x 2.000    levels 2.0000 1.2500 1.0000  0.0000
#   STDSS CL8      6.500 x  94.000 x 2.000    levels 1.2500 0.5000 0.2500 -0.7500
#   STDSS 8.5CL    6.500 x 100.000 x 2.000    levels 1.2500 0.5000 0.2500 -0.7500
#
# Two things fall straight out of that and this probe re-checks both rather than
# taking them on trust:
#
#   1. THE DIGIT IS A LENGTH IN FEET AND THE PART IS 2 IN SHORT OF IT.
#      5 -> 58, 6 -> 70, 7 -> 82, 8 -> 94, 8.5 -> 100. Five for five, exact.
#      12 * feet is the booth's CROSS dimension, so the rule is
#      seal length = cross - 2, and the seal that a booth takes is the one whose
#      feet * 12 equals its cross. That is what makes the selection general
#      instead of a per-model table.
#
#   2. CL8 AND 8.5CL ARE NOT UPSIDE DOWN, ONLY SHIFTED. Read the gaps from the
#      largest-area level upward and all five agree exactly: +1.000, +0.250,
#      +0.750. The ceiling PANELS split into two conventions that are genuine
#      mirror images of each other, and it would be easy to assume the seals do
#      the same. They do not. Anything that flips a seal is wrong.
#
# WHAT IS NOT KNOWN, AND IS THE WHOLE REASON TO RUN THIS
#
#   - Which way up the seal is, physically. The 6-in-wide face and the 2-in-wide
#     face are at opposite ends of a 2 in height and nothing measured so far says
#     which one faces the room.
#   - Where the slot is in the ceiling panel: how far in from the joint edge, how
#     deep, how wide.
#   - Therefore the ONE remaining number: which Z in the seal's own coordinates
#     lands on which Z in the panel's own coordinates.
#   - Whether the seal is symmetric across the joint, which decides whether it
#     can simply be centred on the joint station.
#
# READ ONLY. It loads definitions into the open model and purges afterwards, so
# a scratch file is the safe place — a purge cannot remove a definition your
# model already uses. It never adds, moves or deletes anything.
#
# It `load`s wr-deck.rb and calls WR_Deck.contact_z, WR_Deck.deck_extent and
# WR_Deck.flat_levels DELIBERATELY, rather than reimplementing them. The numbers
# reported here are then the same numbers the builder will actually place with.
# A probe that re-derives the builder's rules can drift away from them silently,
# and then the measurement describes a booth nobody is building.

require 'sketchup.rb'

load File.join(File.dirname(__FILE__), 'wr-folder.rb')
load File.join(File.dirname(__FILE__), 'wr-deck.rb')

module WR_ProbeSeal
  # remove_const, NOT `unless defined?`. The guard silences the reload warning
  # and freezes the value for the session, so editing a number here and
  # re-running would quietly do nothing. That trap cost four rounds on
  # wr-deck.rb and it is documented at the top of that file.
  %w[PREF DEFAULT_DIR CELL WINDOW BIN FLAT_DOT SEAL_NAME].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  PREF        = 'WR_ProbeSeal'.freeze
  DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'.freeze

  # One character across and one row down, in inches. 1/16 reads the 1/4 in
  # features on these parts without running past a console line. Console
  # characters are taller than they are wide, so the picture comes out stretched
  # vertically — the numbers beside it, not the picture, are the measurement.
  CELL = 1.0 / 16.0

  # How far in from the joint edge of a ceiling panel to plot. The seal is
  # 6.5 in across, so 4 in either side of the joint covers it with room to spare.
  WINDOW = 4.0

  # Heights and profile coordinates are binned to this before grouping, so one
  # face split into two coplanar halves does not report as two things.
  BIN = 1.0 / 64.0

  FLAT_DOT = 0.999

  # STDSS CL5 / STDSS CL6 / STDSS CL7 / STDSS CL8 / STDSS 8.5CL.
  #
  # The digit moves from after CL to before it at 8.5 and the naming gives no
  # reason for it. Matching both spellings in one expression is cheaper than
  # trusting whoever names the next one to pick a side.
  SEAL_NAME = /\ASTDSS\s*(?:CL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*CL)\z/i.freeze

  def self.read_pref(k, fallback = '')
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

  def self.ask
    dir, list = WR_Folder.field('parts', DEFAULT_DIR)
    res = UI.inputbox(['Folder of .skp files',
                       'Seal parts — name contains',
                       'Ceiling panels to section — comma separated',
                       'Purge the definitions afterwards'],
                      [dir,
                       read_pref('seal', 'STDSS CL'),
                       read_pref('panels', 'STD7248CL SIDE L, STD7224CL SIDE R'),
                       'Yes'],
                      [list, '', '', 'Yes|No'],
                      'Probe Ceiling Seam Seal Fit')
    return nil unless res
    # create = false, because this folder is an INPUT. Silently creating an
    # empty one would turn a mistyped drive letter into "no parts found".
    d = WR_Folder.resolve(res[0], 'parts', 'Folder of component .skp files', false)
    return nil if d.nil?
    write_pref('seal', res[1])
    write_pref('panels', res[2])
    { 'dir' => d,
      'seal' => res[1].to_s.strip,
      'panels' => res[2].to_s.split(',').map { |s| s.strip }.reject { |s| s.empty? },
      'purge' => res[3].to_s }
  end

  # ------------------------------------------------------------- walking --

  def self.walk_faces(ents, tr, depth = 0, &blk)
    return if depth > 8
    ents.each do |e|
      case e
      when Sketchup::Face
        blk.call(e, tr)
      when Sketchup::ComponentInstance
        walk_faces(e.definition.entities, tr * e.transformation, depth + 1, &blk)
      when Sketchup::Group
        walk_faces(e.entities, tr * e.transformation, depth + 1, &blk)
      end
    end
  end

  def self.walk_edges(ents, tr, depth = 0, &blk)
    return if depth > 8
    ents.each do |e|
      case e
      when Sketchup::Edge
        blk.call(e, tr)
      when Sketchup::ComponentInstance
        walk_edges(e.definition.entities, tr * e.transformation, depth + 1, &blk)
      when Sketchup::Group
        walk_edges(e.entities, tr * e.transformation, depth + 1, &blk)
      end
    end
  end

  # ------------------------------------------------------------- profile --

  # THE CROSS-SECTION, taken without cutting anything.
  #
  # An extruded part's profile is the set of edges lying in a plane
  # perpendicular to the extrusion. Those are exactly the edges whose two
  # endpoints share a coordinate along the long axis. Collect them, bin them by
  # that coordinate, and each bin is one candidate section.
  #
  # Most bins are the real profile, repeated at every station where the part has
  # a rib or a face break. A few are local features — a bracket, a screw boss —
  # and those have their own edges and their own signature. So the profile that
  # appears at the MOST stations is the extrusion, and the count of distinct
  # signatures is the honest measure of how extruded the part really is. A part
  # reporting twenty different signatures is not an extrusion and this whole
  # method is the wrong tool for it, which is worth knowing rather than
  # averaging over.
  #
  # Returns [long_is_y, station, segments, distinct_signature_count,
  #          stations_sharing_that_signature].
  def self.profile(defn)
    bb = defn.bounds
    long_is_y = (bb.max.y - bb.min.y).to_f >= (bb.max.x - bb.min.x).to_f
    bins = {}
    walk_edges(defn.entities, Geom::Transformation.new) do |e, tr|
      begin
        a = e.start.position.transform(tr)
        b = e.end.position.transform(tr)
        la = (long_is_y ? a.y : a.x).to_f
        lb = (long_is_y ? b.y : b.x).to_f
        next if (la - lb).abs > 0.005
        st = ((la + lb) / 2.0 / BIN).round * BIN
        seg = [(long_is_y ? a.x : a.y).to_f, a.z.to_f,
               (long_is_y ? b.x : b.y).to_f, b.z.to_f]
        (bins[st] ||= []) << seg
      rescue StandardError
        next
      end
    end
    return [long_is_y, nil, [], 0, 0] if bins.empty?

    # Signature: the segment set rounded and sorted, so two stations carrying
    # the same shape compare equal whatever order their edges were walked in.
    sigs = {}
    bins.each do |st, segs|
      key = segs.map { |s| s.map { |v| ((v / BIN).round) }.sort }.sort.inspect
      (sigs[key] ||= []) << st
    end
    best = sigs.max_by { |_k, sts| sts.length }
    stations = best[1].sort
    st = stations[stations.length / 2]
    [long_is_y, st, bins[st], sigs.length, stations.length]
  rescue StandardError
    [true, nil, [], 0, 0]
  end

  # ---------------------------------------------------------------- plot --

  # ASCII of a segment set, windowed. Returns [rows, x0, z0], rows top-down.
  #
  # This draws the OUTLINE, not a filled section — it marks where the profile
  # edges run and says nothing about which side of them is material. That is a
  # real limit and it is why the segment table is printed underneath: the
  # picture is for reading the shape at a glance, the table is the measurement.
  def self.plot(segs, x0, x1, z0, z1)
    nx = ((x1 - x0) / CELL).ceil + 1
    nz = ((z1 - z0) / CELL).ceil + 1
    return [[], x0, z0] if nx <= 0 || nz <= 0 || nx > 300 || nz > 300
    grid = Array.new(nz) { ' ' * nx }
    segs.each do |ax, az, bx, bz|
      steps = [((bx - ax).abs / CELL).ceil, ((bz - az).abs / CELL).ceil, 1].max
      (0..steps).each do |i|
        t = i.to_f / steps
        cx = (((ax + (bx - ax) * t) - x0) / CELL).round
        cz = (((az + (bz - az) * t) - z0) / CELL).round
        next if cx < 0 || cx >= nx || cz < 0 || cz >= nz
        grid[cz][cx] = '#'
      end
    end
    [grid, x0, z0]
  end

  # Print a plot with a Z ruler down the left. `booth` maps part z to booth z,
  # or nil when there is nothing to map it to.
  def self.draw(grid, x0, z0, booth = nil)
    if grid.empty?
      puts '        (nothing to plot — the profile is empty or too large)'
      return
    end
    (grid.length - 1).downto(0) do |row|
      z = z0 + row * CELL
      # Label the quarter inches only; every row labelled is unreadable.
      mark = ((z / 0.25).round * 0.25 - z).abs < CELL / 2.0
      lbl = if mark && booth
              format('%8.4f %8.3f |', z, booth.call(z))
            elsif mark
              format('%8.4f          |', z)
            else
              '                  |'
            end
      puts "        #{lbl}#{grid[row]}"
    end
    ticks = ' ' * grid[0].length
    (0...grid[0].length).each do |c|
      x = x0 + c * CELL
      ticks[c] = '+' if ((x / 1.0).round - x).abs < CELL / 2.0
    end
    puts "        #{' ' * 18}|#{ticks}"
    puts format('        %18s x %.3f .. %.3f, one cell = 1/16 in, + = whole inch',
                '', x0, x0 + (grid[0].length - 1) * CELL)
  end

  def self.segment_table(segs, indent = '          ')
    segs.map { |ax, az, bx, bz| [ax, az, bx, bz] }
        .sort_by { |s| [s[1], s[0]] }
        .each do |ax, az, bx, bz|
      kind = if (az - bz).abs < 0.002 then 'horizontal'
             elsif (ax - bx).abs < 0.002 then 'VERTICAL  '
             else 'sloped    '
             end
      puts format('%s%s  x %8.4f .. %8.4f   z %8.4f .. %8.4f   len %6.4f',
                  indent, kind, ax, bx, az, bz,
                  Math.sqrt((bx - ax)**2 + (bz - az)**2))
    end
  end

  # ------------------------------------------------------------ the seal --

  def self.feet_from_name(base)
    m = SEAL_NAME.match(base.strip)
    return nil if m.nil?
    (m[1] || m[2]).to_f
  end

  def self.report_seal(model, path)
    base = File.basename(path, '.skp')
    defn = model.definitions.load(path)
    return nil if defn.nil?
    bb = defn.bounds
    dx = (bb.max.x - bb.min.x).to_f
    dy = (bb.max.y - bb.min.y).to_f
    dz = (bb.max.z - bb.min.z).to_f
    len = [dx, dy].max
    across = [dx, dy].min
    feet = feet_from_name(base)

    puts ''
    puts "  #{base}"
    puts format('      box %.4f x %.4f x %.4f in   origin at %.4f %.4f %.4f ' \
                'inside it', dx, dy, dz, -bb.min.x.to_f, -bb.min.y.to_f,
                -bb.min.z.to_f)
    if feet
      puts format('      name says %g ft = %.0f in;  measures %.4f;  ' \
                  'difference %+.4f  %s',
                  feet, feet * 12.0, len, len - feet * 12.0,
                  (len - (feet * 12.0 - 2.0)).abs < 0.02 ?
                    '<- exactly cross - 2, as predicted' :
                    '<- DOES NOT match cross - 2. The selection rule is wrong.')
    else
      puts '      name does not parse as STDSS <n>CL / STDSS CL<n>.'
    end

    tally = WR_Deck.flat_levels(defn)
    peak = tally.values.max.to_f
    datum = tally.max_by { |_z, a| a }[0]
    puts format('      flat levels (width = area / %.1f in of length):', len)
    tally.sort_by { |z, _a| -z }.each do |z, a|
      w = a / len
      puts format('        z %8.4f  %9.2f sq in  width %6.3f in  %s%s',
                  z, a, w,
                  (z - datum).abs < 0.0001 ? '<- LARGEST, the datum face  ' : '',
                  w < 0.35 ? '(narrow — likely a localized feature, not the profile)' : '')
    end
    # The gaps upward from the datum. All five seals must agree here; if one
    # does not, it is authored differently and the single placement rule below
    # would put it somewhere wrong.
    ups = tally.keys.select { |z| z > datum + 0.0001 }.sort
    sig = ([datum] + ups).each_cons(2).map { |a, b| format('%+.4f', b - a) }.join(' ')
    puts format('      gaps upward from the datum:  %s', sig)

    long_is_y, st, segs, nsig, nst = profile(defn)
    puts format('      long axis is %s;  section taken at %s = %.4f  ' \
                '(%d distinct profile(s) over %d station(s) sharing this one)',
                long_is_y ? 'Y' : 'X', long_is_y ? 'Y' : 'X', st || 0.0, nsig, nst)
    if segs.empty?
      puts '      NO PROFILE FOUND — no edges lie in a cross-section plane, so'
      puts '      this part is not a simple extrusion and the section below is'
      puts '      absent rather than empty. Report this; do not read past it.'
      return { :base => base, :sig => sig, :datum => datum, :len => len,
               :across => across, :feet => feet, :segs => [], :bb => bb }
    end

    xs = segs.flat_map { |s| [s[0], s[2]] }
    zs = segs.flat_map { |s| [s[1], s[3]] }
    puts ''
    puts '      CROSS-SECTION, looking along the joint. Left-right is ACROSS the'
    puts '      joint; up is up in the part\'s own coordinates.'
    grid, x0, z0 = plot(segs, xs.min, xs.max, zs.min, zs.max)
    draw(grid, x0, z0)
    puts ''
    puts '      segments:'
    segment_table(segs)

    # SYMMETRY ACROSS THE JOINT. If the profile mirrors about its own midpoint
    # the seal can simply be centred on the joint station and there is no
    # handing to get wrong. If it does not, which way round it goes becomes a
    # further question and the spec has to answer it.
    mid = (xs.min + xs.max) / 2.0
    orig = segs.map { |s| [((s[0] / BIN).round), ((s[1] / BIN).round),
                           ((s[2] / BIN).round), ((s[3] / BIN).round)].sort }.sort
    mirr = segs.map { |s| [(((2 * mid - s[0]) / BIN).round), ((s[1] / BIN).round),
                           (((2 * mid - s[2]) / BIN).round), ((s[3] / BIN).round)].sort }.sort
    puts ''
    puts format('      symmetric across the joint about x = %.4f?  %s', mid,
                orig == mirr ? 'YES — centring it on the joint is safe' :
                  'NO — the seal has a front and a back, and which way it faces ' \
                  'is a further question')

    { :base => base, :sig => sig, :datum => datum, :len => len,
      :across => across, :feet => feet, :segs => segs, :bb => bb,
      :symmetric => (orig == mirr) }
  rescue StandardError => e
    puts format('  %-28s FAILED %s: %s', File.basename(path), e.class, e.message)
    nil
  end

  # ----------------------------------------------------------- the panel --

  # Faces whose normal points along the tiling axis — the ones that face across
  # the joint. The walls of a slot are exactly these, so their stations and
  # areas locate the slot without any shape reasoning at all.
  def self.cross_faces(defn, along_is_x)
    ax = along_is_x ? Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(0, 1, 0)
    out = Hash.new(0.0)
    walk_faces(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        n = f.normal.transform(tr)
        n.normalize!
        next if n.dot(ax).abs < FLAT_DOT
        p = f.vertices.first.position.transform(tr)
        s = (((along_is_x ? p.x : p.y).to_f) / BIN).round * BIN
        out[[s, n.dot(ax) > 0 ? '+' : '-']] += f.area.to_f
      rescue StandardError
        next
      end
    end
    out
  end

  def self.report_panel(model, dir, name)
    path = File.join(dir, "#{name}.skp")
    unless File.exist?(path)
      hit = Dir.glob(File.join(dir, '*.skp'))
               .find { |f| File.basename(f, '.skp').downcase == name.downcase }
      path = hit
    end
    if path.nil? || !File.exist?(path)
      puts "  #{name} — NOT FOUND in the folder."
      return nil
    end
    defn = model.definitions.load(path)
    return nil if defn.nil?
    base = File.basename(path, '.skp')
    bb = defn.bounds

    # The builder's own rule, called rather than copied. cz is the face that
    # meets the wall top; flip says the part is modelled the other way up and
    # gets turned over before placing.
    cz, flip = WR_Deck.contact_z(defn, 'CL')
    if cz.nil?
      puts "  #{base} — no flat faces to measure, so no contact plane."
      return nil
    end

    # THE JOINT IS AT THE DECK EDGE, NOT THE BOX EDGE. STD7224FL SIDE R is a
    # 24 in panel whose box measures 37.938 because brackets project past the
    # deck; seating by the box put a panel 1 ft 1-15/16 in out of position and
    # that is why deck_extent exists. The same trap is waiting here: a seal
    # placed at the box edge would land over an inch off the seam.
    ext = WR_Deck.deck_extent(defn, cz) || bb

    long_is_y, st, segs, nsig, nst = profile(defn)
    # The long axis of a CL panel is its CROSS dimension, so the tiling axis —
    # the one the joint cuts across — is the other one.
    along_is_x = long_is_y

    puts ''
    puts "  #{base}"
    puts format('      box  %.4f x %.4f x %.4f   z %.4f .. %.4f',
                (bb.max.x - bb.min.x).to_f, (bb.max.y - bb.min.y).to_f,
                (bb.max.z - bb.min.z).to_f, bb.min.z.to_f, bb.max.z.to_f)
    puts format('      deck %.4f x %.4f  at the contact level, x %.4f .. %.4f, ' \
                'y %.4f .. %.4f',
                (ext.max.x - ext.min.x).to_f, (ext.max.y - ext.min.y).to_f,
                ext.min.x.to_f, ext.max.x.to_f, ext.min.y.to_f, ext.max.y.to_f)
    puts format('      box overhangs the deck by %.4f in on the tiling axis — ' \
                '%s',
                ((along_is_x ? (bb.max.x - bb.min.x) : (bb.max.y - bb.min.y)).to_f -
                 (along_is_x ? (ext.max.x - ext.min.x) : (ext.max.y - ext.min.y)).to_f),
                'the seal must be placed off the DECK edge, never the box edge.')
    puts format('      WR_Deck.contact_z = %.4f, flip = %s. The builder puts that ' \
                'face on the wall top.', cz, flip ? 'YES' : 'no')
    puts format('      tiling axis is %s;  long (cross) axis is %s',
                along_is_x ? 'X' : 'Y', long_is_y ? 'Y' : 'X')

    # Booth Z, given how the builder will place this part. Rotating 180 about X
    # sends z to -z and the translation then puts the contact face on the wall
    # top, so the mapping inverts when the part is flipped. Printed beside the
    # part's own Z so the seal's numbers can be read against a real height.
    wall_top = WR_Deck::DECK_TOP_Z + WR_Deck::WALL_H
    booth = lambda { |z| wall_top + (flip ? -(z - cz) : (z - cz)) }
    puts format('      so part z %.4f -> booth z %.3f, and part z %.4f -> ' \
                'booth z %.3f',
                bb.min.z.to_f, booth.call(bb.min.z.to_f),
                bb.max.z.to_f, booth.call(bb.max.z.to_f))

    puts ''
    puts '      FACES FACING ACROSS THE JOINT — the walls of any slot:'
    cf = cross_faces(defn, along_is_x)
    lo = (along_is_x ? ext.min.x : ext.min.y).to_f
    hi = (along_is_x ? ext.max.x : ext.max.y).to_f
    near = cf.select { |(s, _d), _a| (s - lo).abs <= WINDOW || (s - hi).abs <= WINDOW }
    if near.empty?
      puts '        none within the window of either deck edge.'
    else
      near.sort_by { |(s, _d), _a| s }.each do |(s, d), a|
        which = (s - lo).abs <= (s - hi).abs ? 'low' : 'high'
        puts format('        station %8.4f  facing %s  %8.2f sq in   ' \
                    '%.4f in from the %s deck edge',
                    s, d, a, (s - (which == 'low' ? lo : hi)).abs, which)
      end
    end

    if segs.empty?
      puts ''
      puts '      NO PROFILE FOUND — no edges lie in a cross-section plane.'
      puts '      Report this rather than reading a shape into its absence.'
      return nil
    end

    puts format('      section at %s = %.4f  (%d distinct profile(s), %d station(s) ' \
                'share this one)', long_is_y ? 'Y' : 'X', st || 0.0, nsig, nst)

    zs = segs.flat_map { |s| [s[1], s[3]] }
    [['LOW', lo], ['HIGH', hi]].each do |label, edge|
      win = segs.select do |s|
        [s[0], s[2]].any? { |x| (x - edge).abs <= WINDOW }
      end
      puts ''
      puts format('      %s DECK EDGE at %s = %.4f — the joint face. %.1f in shown.',
                  label, along_is_x ? 'X' : 'Y', edge, WINDOW)
      if win.empty?
        puts '        no profile edges within the window.'
        next
      end
      x0 = edge - WINDOW
      x1 = edge + WINDOW
      grid, gx0, gz0 = plot(win, x0, x1, zs.min, zs.max)
      draw(grid, gx0, gz0, booth)
      puts '        segments:'
      segment_table(win, '          ')
    end

    { :base => base, :cz => cz, :flip => flip, :lo => lo, :hi => hi,
      :booth => booth }
  rescue StandardError => e
    puts format('  %-28s FAILED %s: %s', name, e.class, e.message)
    nil
  end

  # -------------------------------------------------------------- report --

  # Wipe the Ruby Console so a run starts from a clean screen and there is no
  # question where it begins or what belonged to the run before it.
  #
  # GUARDED, AND DELIBERATELY SILENT WHEN IT CANNOT. SKETCHUP_CONSOLE is a
  # Sketchup::Console and #clear has been on it since SketchUp 2014
  # (ruby.sketchup.com/Sketchup/Console.html — checked, not remembered), but the
  # constant is not guaranteed to be defined in every context this file could be
  # loaded in, and $stdout can be redirected away from it. Clearing the screen is
  # a convenience; it must never be able to turn "the probe could not tidy up"
  # into "the probe raised and measured nothing".
  def self.clear_console
    return false unless defined?(SKETCHUP_CONSOLE)
    return false unless SKETCHUP_CONSOLE.respond_to?(:clear)
    SKETCHUP_CONSOLE.clear
    true
  rescue StandardError, NameError
    false
  end

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end
    cfg = ask
    return if cfg.nil?

    seals = Dir.glob(File.join(cfg['dir'], '*.skp')).sort.select do |p|
      cfg['seal'].empty? ||
        File.basename(p).downcase.include?(cfg['seal'].downcase)
    end

    if seals.empty? && cfg['panels'].empty?
      UI.messagebox("Nothing matches \"#{cfg['seal']}\" in\n#{cfg['dir']}")
      return
    end

    if model.entities.length > 0
      go = UI.messagebox("This model is not empty.\n\n#{seals.length + cfg['panels'].length} " \
                         "definitions are about to be loaded into it. Nothing is " \
                         "moved, added or deleted, but a purge cannot remove a " \
                         "definition your model already uses.\n\nCarry on anyway?",
                         MB_OKCANCEL)
      return if go != IDOK
    end

    # Cleared HERE rather than at the top of run: everything above this point is
    # dialogs and early returns, so clearing sooner would wipe the screen for a
    # run the user then cancelled. This is still before the first line of output,
    # which is what "start from a clean screen" actually asks for.
    clear_console

    puts ''
    puts '=' * 78
    puts 'PROBE CEILING SEAM SEAL FIT'
    puts "  #{cfg['dir']}"
    puts '=' * 78
    puts ''
    puts '  READ THE SEGMENT TABLES, NOT THE PICTURES. The pictures are an'
    puts '  outline at 1/16 in and are there to be recognised at a glance; every'
    puts '  number this probe is for is in the tables beside them.'

    puts ''
    puts '-' * 78
    puts "SEALS — #{seals.length}"
    puts '-' * 78
    srows = []
    seals.each_with_index do |p, i|
      Sketchup.status_text = "Seal #{i + 1}/#{seals.length}: #{File.basename(p)}"
      r = report_seal(model, p)
      srows << r if r
    end

    puts ''
    puts '-' * 78
    puts "CEILING PANELS — #{cfg['panels'].length}"
    puts '-' * 78
    prows = []
    cfg['panels'].each_with_index do |n, i|
      Sketchup.status_text = "Panel #{i + 1}/#{cfg['panels'].length}: #{n}"
      r = report_panel(model, cfg['dir'], n)
      prows << r if r
    end
    Sketchup.status_text = ''

    # ---- the cross-checks that decide whether the spec's rules hold ---------
    puts ''
    puts '=' * 78
    puts 'WHAT THIS SETTLES'
    puts '=' * 78
    puts ''

    if srows.length >= 2
      sigs = srows.map { |r| r[:sig] }.uniq
      puts format('  1. ALL SEALS THE SAME WAY UP?  %s',
                  sigs.length == 1 ?
                    "YES — one signature across all #{srows.length}: #{sigs.first}" :
                    "NO — #{sigs.length} different signatures. A single placement " \
                    'rule cannot serve them and the spec must say which is which.')
      sigs.each { |s| puts "       #{s}" } if sigs.length > 1
    end

    bad = srows.reject { |r| r[:feet].nil? }
                .reject { |r| (r[:len] - (r[:feet] * 12.0 - 2.0)).abs < 0.02 }
    puts format('  2. LENGTH = feet * 12 - 2 ?  %s',
                bad.empty? ?
                  "YES for all #{srows.count { |r| r[:feet] }} named seals. " \
                  'Selection can be driven by the booth cross dimension.' :
                  "NO for #{bad.length}: #{bad.map { |r| r[:base] }.join(', ')}. " \
                  'The selection rule is wrong and must not be written as stated.')

    widths = srows.map { |r| format('%.4f', r[:across]) }.uniq
    puts format('  3. ONE WIDTH ACROSS THE JOINT?  %s',
                widths.length == 1 ?
                  "YES — every seal is #{widths.first} in across." :
                  "NO — #{widths.join(', ')}. Clearance to anything beside the " \
                  'joint has to be checked per size.')

    asym = srows.reject { |r| r[:symmetric].nil? }.reject { |r| r[:symmetric] }
    puts format('  4. SYMMETRIC ACROSS THE JOINT?  %s',
                asym.empty? ?
                  'YES for every seal measured — centring on the joint station ' \
                  'is enough and there is no handing.' :
                  "NO for #{asym.map { |r| r[:base] }.join(', ')}. Which way the " \
                  'seal faces is a further question the spec must answer.')

    puts ''
    puts '  5. THE ONE NUMBER STILL MISSING, and only Benton can name it:'
    puts ''
    puts '     WHICH Z IN THE SEAL LANDS ON WHICH Z IN THE PANEL.'
    puts ''
    srows.each do |r|
      puts format('       %-14s datum (largest flat face) at part z %+.4f, ' \
                  'top of part at %+.4f',
                  r[:base], r[:datum], r[:bb].max.z.to_f)
    end
    prows.each do |r|
      puts format('       %-20s contact face part z %.4f -> booth z %.3f; ' \
                  'slab room side and any slot are read off the section above.',
                  r[:base], r[:cz], r[:booth].call(r[:cz]))
    end
    puts ''
    puts '     Answer it in this form and the spec is complete:'
    puts '       "the seal\'s datum face sits at booth z NN.NNN", or'
    puts '       "the seal\'s datum face sits flush with <named panel face>".'
    puts ''

    if cfg['purge'] == 'Yes'
      n = model.definitions.length
      begin
        model.definitions.purge_unused
        puts "  purged — definitions #{n} -> #{model.definitions.length}"
      rescue StandardError => e
        puts "  purge failed: #{e.class}: #{e.message}"
      end
    end

    puts ''
    puts "  #{srows.length} seal(s) and #{prows.length} panel(s) measured. " \
         'Nothing in the model was changed.'
    puts ''
    UI.messagebox("Seam-seal probe done.\n\n#{srows.length} seal(s), " \
                  "#{prows.length} ceiling panel(s).\n\nThe cross-sections and " \
                  "the tables are in the Ruby Console:\nExtensions > Developer > " \
                  "Ruby Console.\n\nThe one question left is printed at the " \
                  'bottom under "WHAT THIS SETTLES".')
  end
end

begin
  WR_ProbeSeal.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Probe Ceiling Seam Seal Fit failed:\n\n#{e.class}: " \
                "#{e.message}\n\nSee the Ruby Console.")
end
