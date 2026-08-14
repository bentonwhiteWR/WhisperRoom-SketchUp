# wr-deck.rb — floors and ceilings for the component booth builder.
#
# NOT A COMMAND. A library, `load`ed by build-booth-components.rb, and in
# wr_tools' SKIP so it never appears in the panel.
#
# All measurements behind this live in reference/floor-ceiling-geometry.md.
# Read that before changing a number here; every one of them was measured with
# probe-levels.rb rather than taken from a catalogue.
#
# ---------------------------------------------------------------------------
# THE FIVE FACTS THIS IS BUILT ON
#
# 1. FOOTPRINT = (exterior_w - 2) x (exterior_h - 2), centred on the booth.
#    Checked against MDL 96168 S: exterior 170 x 98, panels sum 167.81 x 96.00.
#    The floor runs UNDER the walls, so it is not the interior.
#
# 2. NAME ENCODES <cross><along>, and definition axes follow it:
#    definition X = along the tiling run, Y = across it, Z = up.
#    STD9648FL is 96 across x 48 along, box 47.969 x 96.000. True for all of
#    them, so placement is a translation with no rotation when the booth tiles
#    along its own X.
#
# 3. FLOOR DECK TOP is at z = 1.0000 in the part's own coordinates, and that is
#    the plane the walls AND the door frame sit on. Confirmed by Benton.
#
# 4. CEILING CONTACT is the slab face nearest the third, minor level. The slab
#    is the face pair exactly 1.000 in apart. Some ceilings are modelled the
#    other way up, which is why this is a rule and not a number.
#
# 5. SIDE PANELS GO AT THE ENDS, CTR fills the middle. SIDE L and SIDE R are
#    mirror images and CANNOT be told apart by measurement — see the constant
#    below.
#
# NOTHING HERE IS HARD-CODED PER MODEL. The catalogue is read from the folder,
# so a part added or renamed is picked up without editing this file.

require 'sketchup.rb'

module WR_Deck
  # ------------------------------------------------------------- the dials --
  #
  # Four numbers, each named, each with the check that settles it written next
  # to it. If a booth comes out wrong it is one of these, not the algorithm.

  # How far in from the exterior the deck stops, per side.
  INSET = 1.0 unless defined?(INSET)

  # Where the floor's deck top lands in BOOTH coordinates.
  #
  # Zero means the walls do not move: the deck top sits on the plane they
  # already stand on and the floor hangs below it, into the host floor. That is
  # the low-risk choice and it renders identically.
  #
  # The physically honest alternative is DECK_TOP_Z = 1.0 with every wall
  # raised to match, so the floor's underside sits on the host floor at zero
  # alongside the fan. Do that only with the wall placement changed in the same
  # commit, or the walls will float.
  DECK_TOP_Z = 0.0 unless defined?(DECK_TOP_Z)

  # Wall height the ceiling sits on top of. The builder passes its own, so this
  # is only the fallback.
  WALL_H = 81.0 unless defined?(WALL_H)

  # WHICH END OF ITS OWN RUN A "SIDE R" PANEL PUTS THE SMALL WALL AT.
  #
  # Not derivable. STD6042FL SIDE L and SIDE R measure identically on every
  # metric — box, face heights, areas, bracket extent — because they are mirror
  # images, and a mirror preserves all of those.
  #
  # So: build one booth and look. If the brackets miss the wall seams they miss
  # by the difference between the large and small wall, 24 in on a 40/16 run,
  # which is unmissable. Flip this and every model is right at once, because
  # they all resolve through it.
  SIDE_R_SMALL_WALL_AT_LOW_END = true unless defined?(SIDE_R_SMALL_WALL_AT_LOW_END)

  TOL = 0.35 unless defined?(TOL)   # a tiling this far off the footprint is wrong

  # ------------------------------------------------------------- catalogue --

  # Every floor and ceiling part in the folder, parsed from its filename.
  #
  #   STD9648FL SIDE   -> cross 96, along 48, kind FL, role SIDE
  #   STD6042CL SIDE R -> cross 60, along 42, kind CL, role SIDE, hand R
  #   STD8418 FL       -> the space moves; the digits do not
  #
  # Sizes come from the FILE NAME here only to group them. Actual placement
  # measures the definition, because the name is not the size — STD9648FL CTR
  # measures 47.938, not 48.
  NAME = /\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\z/i.freeze

  def self.catalogue(dir)
    out = []
    Dir.glob(File.join(dir, 'STD*.skp')).each do |path|
      base = File.basename(path, '.skp')
      m = NAME.match(base.strip)
      next if m.nil?
      out << { :file => base, :path => path,
               :cross => m[1].to_f, :along => m[2].to_f,
               :kind => m[3].upcase,
               :role => (m[4] || 'CTR').upcase,
               :hand => (m[5] || '').upcase }
    end
    out
  rescue StandardError => e
    puts "  deck catalogue failed: #{e.class}: #{e.message}"
    []
  end

  # ------------------------------------------------------------------ plan --

  # Tile `run` inches using the along-widths available at this cross size.
  #
  # Greedy largest-first, then the remainder must land exactly on another
  # available width. That is how the real booths are built — MDL 96168 is
  # 48+48+48+24 — and if it does not come out exact the answer is reported
  # rather than fudged, because a fudged floor is a floor with a gap in it.
  def self.tile(run, widths)
    widths = widths.sort.reverse
    big = widths.first
    return nil if big.nil? || big <= 0
    n = (run / big).floor
    n.downto(0) do |k|
      rest = run - k * big
      if rest.abs < TOL
        return Array.new(k, big)
      end
      hit = widths.find { |w| (w - rest).abs < TOL }
      return Array.new(k, big) + [hit] if hit
    end
    nil
  end

  # The full tile list for one deck, ends first.
  #
  # SIDE panels go at the two ends because that is where the walls are; CTR
  # fills the middle. A one-tile deck takes whatever single part exists.
  def self.plan(spec, cat, kind)
    w = spec[:w].to_f - 2 * INSET
    h = spec[:h].to_f - 2 * INSET
    return [nil, 'booth has no size'] if w <= 0 || h <= 0

    # WHICH WAY THE DECK TILES IS NOT ALWAYS ALONG THE LONGER SIDE.
    #
    # Tiling the long way is right for every multi-panel booth, but MDL 4230 S
    # is 42 x 30 and its only part is STD4230FL — 42 ACROSS, 30 along. Assuming
    # long-way-along made it unbuildable while the part sat right there. So try
    # the long way first and fall back to the short way, and let the catalogue
    # decide which orientation actually exists.
    orders = w >= h ? [[w, h, true], [h, w, false]] : [[h, w, false], [w, h, true]]

    pool = nil
    cuts = nil
    along_len = cross_len = nil
    along_is_x = true
    tried = []

    orders.each do |a_len, c_len, a_is_x|
      p = cat.select { |c| c[:kind] == kind && (c[:cross] - c_len).abs < TOL }
      if p.empty?
        tried << format('nothing %.0f across', c_len)
        next
      end
      widths = p.map { |c| c[:along] }.uniq
      t = tile(a_len, widths)
      if t.nil?
        tried << format('%.0f across cannot tile %.2f from %s', c_len, a_len,
                        widths.sort.reverse.map { |x| format('%g', x) }.join('/'))
        next
      end
      pool = p
      cuts = t
      along_len = a_len
      cross_len = c_len
      along_is_x = a_is_x
      break
    end

    if cuts.nil?
      return [nil, format('no %s tiling for %.0f x %.0f — %s',
                          kind, w, h, tried.join('; '))]
    end

    # Ends get SIDE, middle gets CTR, falling back to whatever exists.
    tiles = []
    pos = 0.0
    cuts.each_with_index do |width, i|
      end_of_run = (i.zero? || i == cuts.length - 1)
      want = end_of_run ? 'SIDE' : 'CTR'
      part, mirror = pick(pool, width, want, i.zero?)
      return [nil, format('no %s part %g in wide', kind, width)] if part.nil?
      tiles << { :part => part, :along => width, :at => pos, :mirror => mirror,
                 :along_is_x => along_is_x, :cross => cross_len }
      pos += width
    end
    [tiles, format('%d tile(s), %s', tiles.length,
                   cuts.map { |c| format('%g', c) }.join(' + '))]
  end

  # Prefer the requested role; fall back rather than fail, because plenty of
  # sizes exist in only one role and a booth should still build.
  #
  # Returns [part, mirror?].
  #
  # A HAND THAT DOES NOT EXIST AS A FILE IS MADE BY MIRRORING THE ONE THAT DOES.
  #
  # 7248 ships both SIDE L and SIDE R; 7224 ships only SIDE R. So on an
  # MDL 7272 S — which tiles 48 + 24 — the 48 gets a real handed part and the
  # 24 has nothing to reach for. It used to fall back to SIDE R unmirrored,
  # which put that panel's wall edge facing the CENTRE of the booth instead of
  # the wall. Reported, and exactly right.
  #
  # Mirroring is legitimate here rather than a bodge: L and R measured
  # identically on every metric precisely because they ARE reflections of each
  # other. Reflecting the R part reproduces the L part.
  def self.pick(pool, width, want, at_low_end)
    same = pool.select { |c| (c[:along] - width).abs < TOL }
    return [nil, false] if same.empty?
    byrole = same.select { |c| c[:role] == want }
    byrole = same if byrole.empty?

    handed = byrole.select { |c| !c[:hand].empty? }
    return [byrole.first, false] if handed.empty?

    want_r = at_low_end == SIDE_R_SMALL_WALL_AT_LOW_END
    hand   = want_r ? 'R' : 'L'
    hit    = handed.find { |c| c[:hand] == hand }
    return [hit, false] if hit

    # The hand we need is not in the folder. Take the other one and reflect it.
    [handed.first, true]
  end

  # ----------------------------------------------------------- measurement --

  # The z at which this part meets a wall, in the part's own coordinates.
  #
  # FLOOR: the deck top, the highest face holding most of the panel's area.
  # CEILING: the slab face nearest the third minor level — see fact 4. Both are
  # measured, so a part re-exported the other way up still places correctly.
  def self.contact_z(defn, kind)
    tally = flat_levels(defn)
    return nil if tally.empty?
    peak = tally.values.max.to_f
    big  = tally.select { |_z, a| a >= peak * 0.5 }.keys.sort
    minor = tally.reject { |z, _a| big.include?(z) }
                 .select { |_z, a| a >= peak * 0.05 }.keys.sort

    return big.last if kind == 'FL'          # deck top

    # Ceiling: the slab is the pair 1.000 apart; contact is whichever of that
    # pair sits nearer the minor level, which is always on the room side.
    pair = nil
    big.each_cons(2) { |a, b| pair = [a, b] if ((b - a) - 1.0).abs < 0.05 }
    pair ||= [big.first, big.last]
    return pair.first if minor.empty?
    m = minor.min_by { |z| [(z - pair[0]).abs, (z - pair[1]).abs].min }
    (m - pair[0]).abs <= (m - pair[1]).abs ? pair[0] : pair[1]
  end

  def self.flat_levels(defn)
    up = Geom::Vector3d.new(0, 0, 1)
    tally = Hash.new(0.0)
    walk(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        n = f.normal.transform(tr)
        n.normalize!
        next if n.dot(up).abs < 0.999
        z = (f.vertices.first.position.transform(tr).z.to_f * 64).round / 64.0
        tally[z] += f.area.to_f
      rescue StandardError
        next
      end
    end
    tally
  end

  def self.walk(ents, tr, depth = 0, &blk)
    return if depth > 8
    ents.each do |e|
      case e
      when Sketchup::Face              then blk.call(e, tr)
      when Sketchup::ComponentInstance then walk(e.definition.entities, tr * e.transformation, depth + 1, &blk)
      when Sketchup::Group             then walk(e.entities, tr * e.transformation, depth + 1, &blk)
      end
    end
  end

  # ----------------------------------------------------------------- build --

  # Places one deck. Returns [placed, [warnings]].
  #
  # Everything is positioned from the part's MEASURED bounding box and its
  # measured contact face, never from its origin — the parts do not agree on
  # where their origin is, which is the lesson the wall panels already taught.
  def self.build(model, parent, spec, dir, kind, wall_h = WALL_H)
    cat = catalogue(dir)
    return [0, ["no #{kind} parts in #{dir}"]] if cat.empty?

    tiles, note = plan(spec, cat, kind)
    return [0, [note]] if tiles.nil?

    warn = []
    placed = 0
    tiles.each do |t|
      defn = begin
               model.definitions.load(t[:part][:path])
             rescue StandardError => e
               warn << "#{t[:part][:file]}: #{e.class}: #{e.message}"
               next
             end
      cz = contact_z(defn, kind)
      if cz.nil?
        warn << "#{t[:part][:file]}: no flat faces to measure"
        next
      end
      bb = defn.bounds

      # Along and across, from the MEASURED box rather than the name.
      dx = (bb.max.x - bb.min.x).to_f
      dy = (bb.max.y - bb.min.y).to_f

      # Definition X runs along the tiling direction (fact 2). When the booth
      # tiles along its own Y instead, the part turns a quarter turn.
      turn = !t[:along_is_x]

      # Target position of the tile's low corner, in booth coordinates.
      ax = INSET + t[:at]
      cy = INSET
      x, y = turn ? [cy, ax] : [ax, cy]

      # A floor's contact face lands on the deck plane; a ceiling's lands a wall
      # height above it. Either way the part is shifted so its MEASURED contact
      # face hits the target, never its origin.
      target_z = DECK_TOP_Z
      target_z += wall_h unless kind == 'FL'
      z = target_z - cz

      # Orientation first, in the part's own space: mirror, then quarter turn.
      tr = Geom::Transformation.new
      tr = Geom::Transformation.scaling(ORIGIN, -1, 1, 1) * tr if t[:mirror]
      tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * tr if turn
      tr = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, z)) * tr

      # THEN seat it, from the TRANSFORMED corners rather than from bb.min.
      #
      # bb.min transformed is not the minimum of the transformed box: a mirror
      # sends the minimum corner to the maximum, and a quarter turn swaps the
      # axes. Using it would have put every mirrored panel a full panel-width
      # off. All eight corners, take the minimum — cheap, and correct under any
      # transformation.
      got = Geom::BoundingBox.new
      8.times { |k| got.add(bb.corner(k).transform(tr)) }
      tr = Geom::Transformation.translation(
        Geom::Vector3d.new(x - got.min.x.to_f, y - got.min.y.to_f, 0)) * tr

      begin
        inst = parent.entities.add_instance(defn, tr)
        inst.name = "#{t[:part][:file]}#{t[:mirror] ? ' (mirrored)' : ''}" if inst
        placed += 1
      rescue StandardError => e
        warn << "#{t[:part][:file]}: place failed, #{e.class}: #{e.message}"
      end
      warn << format('%s%s: box %.2f x %.2f, contact z %.4f, at %.2f',
                     t[:part][:file], t[:mirror] ? ' (mirrored)' : '',
                     dx, dy, cz, t[:at]) if $wr_deck_verbose
    end

    [placed, warn, note]
  end

  ORIGIN = Geom::Point3d.new(0, 0, 0) unless defined?(ORIGIN)
  Z_AXIS = Geom::Vector3d.new(0, 0, 1) unless defined?(Z_AXIS)
end
