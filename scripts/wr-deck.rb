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
  # EVERY CONSTANT HERE IS RE-ASSIGNED ON EVERY LOAD, DELIBERATELY.
  #
  # These were written `X = 1 unless defined?(X)` to silence Ruby's "already
  # initialized constant" warning on reload. That silenced the warning and it
  # also meant THE VALUE NEVER CHANGED AGAIN for the rest of the session: a
  # constant is defined after the first load, so the guard skips the assignment
  # on every load after it.
  #
  # The cost was four rounds of "nothing changed". Turn constants were edited,
  # committed, reloaded, and had no effect whatsoever, because only a SketchUp
  # restart could have applied them. Worse, the reports that came back were
  # genuinely contradictory — they were describing a build made with whatever
  # values happened to be in memory, not the ones in the file.
  #
  # remove_const first gets both halves: the value updates on reload AND there is
  # no warning. Anything meant to be TUNED must be in this list.
  # The two dead orientation constants stay in this list on purpose: an older
  # copy of them may still be sitting in a running session's memory, and
  # removing them here clears it rather than leaving a stale value that nothing
  # reads but everything remembers.
  %w[INSET DECK_TOP_Z WALL_H TOL NAME ENH_NAME ORIGIN Z_AXIS X_AXIS
     BIG_GAP SMALL_GAP GAP_TOL
     SEAL_NAME SEAL_FL_NAME SEAL_DATUM_LIFT SEAL_FL_DATUM_LIFT
     SEAL_LEN_TOL SEAL_LEN_INSET
     SIDE_R_SMALL_WALL_AT_LOW_END LOW_END_PANEL_IS_TURNED].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  # ------------------------------------------------------------- the dials --
  #
  # Each named, each with the check that settles it written next to it. If a
  # booth comes out wrong it is one of these, not the algorithm.

  # How far in from the exterior the deck stops, per side.
  INSET = 1.0

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
  DECK_TOP_Z = 0.0

  # Wall height the ceiling sits on top of. The builder passes its own, so this
  # is only the fallback.
  WALL_H = 81.0

  # The two orientation constants that used to live here are GONE, and their
  # absence is the point.
  #
  # LOW_END_PANEL_IS_TURNED and SIDE_R_SMALL_WALL_AT_LOW_END were each flipped
  # four times across an evening, and every flip fixed one panel and broke
  # another, because neither was a fact about the world — they were both
  # stand-ins for a measurement nobody had taken.
  #
  # The measurement exists: hinge gaps of 24.125 and 21.125 in name the wall
  # that drops into each slot, so the panel states its own orientation. See
  # big_wall_fraction and layout_big_on_low? — both sides derived, nothing to
  # tune, and correct whether or not the layout is fixed.

  TOL = 0.35   # a tiling this far off the footprint is wrong

  # ------------------------------------------------------- reading the part --
  #
  # THE PANEL SAYS WHICH WAY ROUND IT GOES. No constant, no table.
  #
  # Hinges sit either side of each wall along the panel's LONG edge, and the gap
  # between a pair names the wall that drops into it:
  #
  #     2' 1/8   (24.125)  -> the 46 in wall   (40 in on the 60 series)
  #     1' 9 1/8 (21.125)  -> the 22 in wall   (16 in on the 60 series)
  #
  # Measured on STD7248FL SIDE L and STD7224FL SIDE R — identical patterns, both
  # with the 24.125 gap centred at 33% along and the 21.125 at 67%. So the large
  # wall belongs on the panel's LOW half.
  #
  # Only the four booths with a split wall run have two different walls on one
  # side and therefore an orientation to get wrong: 6060, 6084, 7272, 7296.
  # Everything else is symmetric and this returns nil, meaning "no preference".
  BIG_GAP   = 24.125
  SMALL_GAP = 21.125
  GAP_TOL   = 1.0     # the two are 3 in apart, so this cannot match both

  # Fraction along the panel's long axis at which the BIG wall's slot sits.
  # nil when the panel has no such pair — most of them.
  def self.big_wall_fraction(defn, rim_z)
    runs = hinge_runs(defn, rim_z)
    return nil if runs.length < 2
    bb = defn.bounds
    long_y = (bb.max.y - bb.min.y) >= (bb.max.x - bb.min.x)
    lo  = (long_y ? bb.min.y : bb.min.x).to_f
    len = ((long_y ? bb.max.y - bb.min.y : bb.max.x - bb.min.x)).to_f
    return nil if len <= 0
    runs.each_cons(2) do |a, b|
      gap = b[0] - a[1]
      next unless (gap - BIG_GAP).abs < GAP_TOL
      return (((a[1] + b[0]) / 2.0) - lo) / len
    end
    nil
  end

  # Hinges are the geometry standing proud of the RIM. Measuring from the deck
  # instead sweeps in the rim itself, which runs the full length of the panel
  # and merges every hinge into one span — that mistake cost an evening.
  def self.hinge_runs(defn, rim_z)
    bb = defn.bounds
    long_y = (bb.max.y - bb.min.y) >= (bb.max.x - bb.min.x)
    spans = []
    walk(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        pts = f.vertices.map { |v| v.position.transform(tr) }
        next if pts.all? { |p| p.z.to_f <= rim_z + 0.02 }
        vals = pts.map { |p| (long_y ? p.y : p.x).to_f }
        spans << [vals.min, vals.max]
      rescue StandardError
        next
      end
    end
    return [] if spans.empty?
    spans.sort!
    runs = [spans.first.dup]
    spans.each do |a, b|
      if a <= runs.last[1] + 0.05
        runs.last[1] = b if b > runs.last[1]
      else
        runs << [a, b]
      end
    end
    runs.reject { |a, b| (b - a) < 0.25 }
  rescue StandardError
    []
  end

  # WHERE THE BRACKET LINE SITS ALONG THE PANEL'S SHORT AXIS.
  #
  # A fraction: 0.0 hard against the low edge, 1.0 against the high edge. The
  # short axis is the tiling direction, so this is the number that says which way
  # a SIDE panel has to be turned for its brackets to face out of the booth.
  #
  # Area-weighted over everything standing proud of the rim, which is the same
  # geometry hinge_runs uses — but measured across the panel rather than along
  # it, because along-the-panel answers "where do the walls land" and this
  # answers "which end do they land at".
  #
  # Returns nil when the geometry is symmetric across that axis, meaning the part
  # gives no cue. Every CTR panel reads 0.500, and the 6042 SIDE L/R pair reads
  # 0.430 for both — the probe shows those two are identical to four decimals, so
  # no measurement could separate them and pretending otherwise would be a
  # fiction. nil is the honest answer and the caller falls back.
  SYMMETRIC = 0.08
  def self.bracket_edge(defn)
    rz = rim_z(defn)
    return nil if rz.nil?
    bb = defn.bounds
    short_is_y = (bb.max.y - bb.min.y).to_f < (bb.max.x - bb.min.x).to_f
    lo  = (short_is_y ? bb.min.y : bb.min.x).to_f
    len = (short_is_y ? bb.max.y - bb.min.y : bb.max.x - bb.min.x).to_f
    return nil if len <= 0
    wsum = 0.0
    asum = 0.0
    walk(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        pts = f.vertices.map { |v| v.position.transform(tr) }
        next if pts.all? { |p| p.z.to_f <= rz + 0.02 }
        a = f.area.to_f
        next if a <= 0
        vals = pts.map { |p| (short_is_y ? p.y : p.x).to_f }
        wsum += a * ((((vals.min + vals.max) / 2.0) - lo) / len)
        asum += a
      rescue StandardError
        next
      end
    end
    return nil if asum <= 0
    e = wsum / asum
    (e - 0.5).abs < SYMMETRIC ? nil : e
  rescue StandardError
    nil
  end

  # The FL part matching this one. Orientation is read off the floor for both
  # decks — see the invariant quoted at the turn. Returns the part itself when it
  # is already a floor, or when no twin exists.
  def self.fl_twin(cat, part)
    return part if part[:kind] == 'FL'
    cat.find { |c| c[:kind] == 'FL' &&
                   (c[:cross] - part[:cross]).abs < TOL &&
                   (c[:along] - part[:along]).abs < TOL &&
                   c[:role] == part[:role] && c[:hand] == part[:hand] } || part
  end

  # The rim: the highest flat level holding any real area.
  def self.rim_z(defn)
    tally = flat_levels(defn)
    return nil if tally.empty?
    peak = tally.values.max.to_f
    tally.select { |_z, a| a >= peak * 0.05 }.keys.max
  end

  # Where the layout puts the BIG wall on the cross axis: low half or high half.
  #
  # Compared against the panel's own answer, and a disagreement is what the half
  # turn is for. Deriving BOTH sides means this stays right if the layout is
  # corrected later — which it needs to be, since on all four affected booths
  # the layout currently puts the big wall on the HIGH half and every panel
  # expects it LOW.
  # THE DECK BELONGS TO THE OUTER SHELL, so it must only ever see outer parts.
  #
  # Both of the questions below - which end the big wall run sits at, and where
  # the short wall's midpoint is - are answered by walking spec[:parts]. On an
  # Enhanced booth that list carries the IEP inner shell as well, twelve more
  # panels at different lengths and different positions, and they change both
  # answers. That is what flipped the floor on the first real 4872 E: nothing in
  # wr-deck changed, the list it reads got longer.
  #
  # :sh is 'out' on every part of a Standard layout, so this filter is a no-op
  # there and the Standard deck is untouched.
  def self.outer_parts(spec)
    (spec[:parts] || []).reject { |p| p[:sh].to_s == 'in' }
  end

  def self.layout_big_on_low?(spec, along_is_x)
    span = along_is_x ? spec[:h].to_f : spec[:w].to_f
    best = nil
    outer_parts(spec).each do |p|
      next unless p[:k] == 'panel'
      xs = p[:poly].map { |q| q[0].to_f }
      ys = p[:poly].map { |q| q[1].to_f }
      dx = xs.max - xs.min
      dy = ys.max - ys.min
      # A wall on the cross axis runs the cross way.
      cross_run = along_is_x ? dy : dx
      other     = along_is_x ? dx : dy
      next unless cross_run > other
      mid = along_is_x ? (ys.min + ys.max) / 2.0 : (xs.min + xs.max) / 2.0
      best = [cross_run, mid] if best.nil? || cross_run > best[0]
    end
    return nil if best.nil? || span <= 0
    best[1] < span / 2.0
  rescue StandardError
    nil
  end

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

  # THE ENHANCED DECK IS THE SAME CATALOGUE WITH A DIFFERENT PREFIX.
  #
  # The IEP inner shell has its own floor mat and ceiling tray, and they tile
  # exactly the way the Standard deck does. Verified by listing
  # P:\Sketchup\NewMasterComponentList\ on 2026-08-26 and extracting every code
  # matching each pattern: 42 STD codes, 42 ENH codes, and the two sets are
  # IDENTICAL — every arrangement the Standard deck can build has an exact ENH
  # twin, including 'ENH 6042CL SIDE L' / 'ENH 6018CL SIDE R', which is how the
  # MDL 6060 tiles. So the tiling question the IEP deck used to refuse is not a
  # new question; it is this one, already solved and fit-tested.
  #
  # TWO DIFFERENCES FROM `NAME`, AND ONLY TWO: the prefix, and the space after
  # it ('ENH 6042CL SIDE L', not 'ENH6042CL SIDE L'). Everything after the
  # digits is byte-for-byte the same pattern.
  #
  # THE ANCHORED DIGITS ARE LOAD-BEARING AND MUST STAY. They are what keeps the
  # seam seals out of the panel pool — see the note on seal_catalogue. 'STDSS
  # CL8' fails because SS is not two digits, and the ENH pattern is anchored the
  # same way, so 'ENH MidWallSeamSeal' and 'ENH CornerSeamSeal' fail too. It is
  # also what keeps the ENH WALL PANELS out: those are named 'ENH 41.5VNT',
  # 'ENH 17.5PanelSolid', 'ENH 26.5Panel1648WDO' — digits, then a DECIMAL POINT,
  # which \d{2,3}\d{2} cannot cross. A pattern loosened to \d+ would sweep every
  # one of them into the deck pool. Do not loosen it.
  #
  # 'ENH 127LPFL' is excluded, exactly as 'STD127LPFL' is — LP is not two
  # digits. Both families lose the same two parts, so the sets stay in step.
  ENH_NAME = /\AENH\s+(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\z/i.freeze

  # `family` is 'STD' or 'ENH'. It defaults to STD so every existing caller —
  # build, seals — reads the Standard library unchanged.
  def self.catalogue(dir, family = 'STD')
    enh = family.to_s.upcase == 'ENH'
    re   = enh ? ENH_NAME : NAME
    glob = enh ? 'ENH *.skp' : 'STD*.skp'
    out = []
    Dir.glob(File.join(dir, glob)).each do |path|
      base = File.basename(path, '.skp')
      m = re.match(base.strip)
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
  #
  # THIS RETURNS THE SET OF WIDTHS, NOT THEIR ORDER. Greedy leaves the remainder
  # last, which is only right when the short wall happens to be at the high end.
  # order_cuts puts it where the layout says it belongs.
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

  # ============================================================================
  # WHERE THE ODD TILE GOES — IT CROSSES THE SHORT WALL, NOT THE END
  #
  # tile() is greedy: it takes as many full-width panels as fit and leaves the
  # remainder LAST. On an MDL 96120 S that gives 48 + 48 + 24 with the 24 at the
  # high end, so the deck ends up with one SIDE panel, one CTR, and a narrow
  # strip standing on the end wall. Benton's screenshot of exactly that is what
  # started this. The booth wants **two 9648 SIDE panels with the 9624 CTR
  # between them** — 48 + 24 + 48.
  #
  # The reason is in the wall layout, not in the deck catalogue. Every one of
  # these booths has ONE short wall run in its long walls, and the narrow deck
  # panel bridges it:
  #
  #     96120   walls 46 | 22 | 46      short wall at 50..72
  #             deck   48 | 24 | 48     odd tile spans 49..73   ✔ covers it
  #     96168   walls 46 | 46 | 22 | 46 short wall at 98..120
  #             deck   48 | 48 | 24 | 48   odd tile spans 97..121  ✔
  #
  # So the odd tile's position is DERIVED from the layout rather than chosen: put
  # it at whichever index centres it on the short wall. That is one rule, and it
  # reproduces both decks already confirmed correct — the MDL 7272 S (48 + 24)
  # and the MDL 6060 S (42 + 18) both have their short wall at the high end, so
  # the odd tile stays exactly where greedy tiling already put it. Nothing about
  # those two moves.
  #
  # A deck whose tiles are all one width has no odd tile and returns unchanged.
  # ============================================================================

  # Midpoint of the short wall run, along the tiling axis, in booth coordinates.
  # nil when the long walls are all one length — then there is nothing to align
  # to and nothing to reorder.
  def self.short_wall_mid(spec, along_is_x)
    runs = []
    outer_parts(spec).each do |p|
      next unless p[:k] == 'panel'
      xs = p[:poly].map { |q| q[0].to_f }
      ys = p[:poly].map { |q| q[1].to_f }
      dx = xs.max - xs.min
      dy = ys.max - ys.min
      along = along_is_x ? dx : dy
      cross = along_is_x ? dy : dx
      # Only the walls that RUN ALONG the tiling axis are the ones the deck
      # tiles across. The walls at right angles to it are a different question.
      next unless along > cross
      mid = along_is_x ? (xs.min + xs.max) / 2.0 : (ys.min + ys.max) / 2.0
      runs << [along, mid]
    end
    return nil if runs.empty?
    shortest = runs.map { |r| r[0] }.min
    return nil if (runs.map { |r| r[0] }.max - shortest) < TOL
    # N and S carry the short wall at the same station, so this is normally two
    # identical values. Taking the median rather than the first keeps it honest
    # if a booth ever disagrees with itself.
    mids = runs.select { |r| (r[0] - shortest).abs < TOL }.map { |r| r[1] }.sort
    mids[mids.length / 2]
  end

  def self.order_cuts(cuts, spec, along_is_x)
    return cuts if cuts.uniq.length < 2
    big = cuts.max
    odd = cuts.find { |c| (c - big).abs >= TOL }
    return cuts if odd.nil?
    target = short_wall_mid(spec, along_is_x)
    return cuts if target.nil?
    target -= INSET                      # booth coordinates -> deck coordinates
    n = cuts.length - 1                  # full-width tiles
    best = (0..n).min_by { |i| ((i * big + odd / 2.0) - target).abs }
    Array.new(n, big).insert(best, odd)
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

    cuts = order_cuts(cuts, spec, along_is_x)

    # Ends get SIDE, middle gets CTR, falling back to whatever exists.
    tiles = []
    pos = 0.0
    cuts.each_with_index do |width, i|
      end_of_run = (i.zero? || i == cuts.length - 1)
      want = end_of_run ? 'SIDE' : 'CTR'
      part, substituted = pick(pool, width, want, i.zero?)
      return [nil, format('no %s part %g in wide', kind, width)] if part.nil?
      tiles << { :part => part, :along => width, :at => pos,
                 :at_low_end => i.zero?, :substituted => substituted,
                 :along_is_x => along_is_x, :cross => cross_len,
                 # The far perimeter, and whether this tile is the one that has
                 # to reach it. A one-tile deck is BOTH ends, so it is excluded:
                 # it is already flush at the low end and there is no second
                 # tile to take up the slack. See the note at the seating step.
                 :run => along_len,
                 :at_high_end => (cuts.length > 1 && i == cuts.length - 1) }
      pos += width
    end
    [tiles, format('%d tile(s), %s', tiles.length,
                   cuts.map { |c| format('%g', c) }.join(' + '))]
  end

  # Prefer the requested role; fall back rather than fail, because plenty of
  # sizes exist in only one role and a booth should still build.
  #
  # Returns [part, substituted?].
  #
  # THE HAND IS CHOSEN BY WHICH END THE TILE SITS AT: L at the low end, R at the
  # high end.
  #
  # This used to be dead — it took `handed.first` and ignored the end entirely,
  # on the stated grounds that the 72 series ships exactly one hand per size so
  # there was never a choice. That is true of an MDL 7272 S, which tiles 48 + 24
  # and therefore draws STD7248 SIDE L at the low end and STD7224 SIDE R at the
  # high end whatever this method does. It is why the 7272 looks right.
  #
  # It is NOT true in general, and the counter-example is the MDL 7296 S: it
  # tiles 48 + 48, so BOTH ends ask for a 7248 and both got SIDE L. Benton saw
  # exactly that. The MDL 6084 S is the same shape of bug — it tiles 42 + 42, and
  # STD6042 ships both hands, so it was silently taking SIDE L twice.
  #
  # L-low / R-high is read off the two confirmed booths, not chosen: the 7272's
  # SIDE L is at its low end and its SIDE R at its high end, and the 6060 does
  # the same with STD6042 SIDE L low and STD6018 SIDE R high. Where only one hand
  # exists this changes nothing, so neither of those booths moves.
  #
  # ORIENTATION IS STILL DECIDED BY POSITION, NOT BY HAND. The half turn on the
  # high-end panel stays exactly as it is — that is the state confirmed on the
  # 7272 and it is not what this method is for. Tangling "which file" together
  # with "which way round" is the mistake that cost an evening; picking the file
  # by end and turning by end are two independent, both-positional rules.
  #
  # Returns [part, substituted?]. `substituted` now means what it says: this end
  # wanted a hand the folder does not have and the other one was used instead.
  # It is reported, because a deck built from two left-hand panels should not be
  # able to look like a clean build in the console.
  def self.pick(pool, width, want, at_low_end)
    same = pool.select { |c| (c[:along] - width).abs < TOL }
    return [nil, false] if same.empty?
    byrole = same.select { |c| c[:role] == want }
    byrole = same if byrole.empty?
    handed = byrole.select { |c| !c[:hand].empty? }
    return [byrole.first, false] if handed.empty?
    wanted = at_low_end ? 'L' : 'R'
    hit = handed.find { |c| c[:hand] == wanted }
    return [hit, false] if hit
    [handed.first, true]
  end

  # ----------------------------------------------------------- measurement --

  # The z at which this part meets a wall, in the part's own coordinates.
  #
  # FLOOR: the deck top, the highest face holding most of the panel's area.
  # CEILING: the slab face nearest the third minor level — see fact 4. Both are
  # measured, so a part re-exported the other way up still places correctly.
  # Returns [contact_z, upside_down?].
  #
  # THE HEIGHT AND THE ORIENTATION ARE TWO SEPARATE QUESTIONS, and the first
  # version only answered the first. It put every ceiling at the right height
  # and left half of them face-up, which is exactly what came back: "all
  # ceilings are upside down on MDL 96168 S".
  #
  # 96168's ceilings are all convention B, and convention B IS convention A
  # modelled the other way up — established in
  # reference/floor-ceiling-geometry.md by mirroring A's levels onto B's to four
  # decimals. So a rule that only picks a z can never fix them.
  #
  # THE TELL IS THE MINOR LEVEL. It is the geometry on the ROOM side of the
  # slab — trim, light housings, the recess. Installed correctly:
  #
  #   FLOOR   room side is UP,   so the minor level sits ABOVE the deck.
  #   CEILING room side is DOWN, so the minor level sits BELOW the slab.
  #
  # Anything that measures the other way round is modelled upside down and gets
  # turned over. That is one rule for both kinds and it needs no list of which
  # parts are which.
  # The in-plane extent of the DECK ITSELF, at the contact level.
  #
  # SEATING BY THE BOUNDING BOX IS WRONG AND IT COST A ROUND. STD7224FL SIDE R
  # is a 24 in panel whose bounding box measures 37.938 — something projects
  # 13.938 in past the deck. Seat by the box and the panel lands 1' 1-15/16"
  # out of position, which is the number that came back off the screen.
  #
  # This is the same lesson build-booth-components.rb already learned about wall
  # parts: find the PANEL inside the part and place by that, never by the box,
  # because an EFS silencer or a door leaf or — here — a bracket run will widen
  # the box without moving the panel.
  def self.deck_extent(defn, cz)
    box = Geom::BoundingBox.new
    walk(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        pts = f.vertices.map { |v| v.position.transform(tr) }
        next unless pts.all? { |p| (p.z.to_f - cz).abs < 0.02 }
        pts.each { |p| box.add(p) }
      rescue StandardError
        next
      end
    end
    box.valid? ? box : nil
  rescue StandardError
    nil
  end

  def self.contact_z(defn, kind)
    tally, exact = flat_levels_with_exact(defn)
    return [nil, false] if tally.empty?
    # Every return below goes through this so the contact is the true face,
    # not its 1/64 bucket.
    ex = lambda { |z| exact[z] || z }
    peak = tally.values.max.to_f
    levels = tally.select { |_z, a| a >= peak * 0.05 }.keys.sort
    return [nil, false] if levels.empty?

    # THE SLAB IS THE FACE PAIR 1.000 IN APART, SEARCHED ACROSS EVERY LEVEL
    # CARRYING REAL AREA — not only the ones above half the peak.
    #
    # Restricting the search to the >=50% levels is what put the ceilings three
    # quarters of an inch high. A convention-B ceiling measures 1.7500 (90-94%),
    # 1.0000 (29-45%) and 0.0000 (100%), and its slab is 1.0000/0.0000 — but the
    # 1.0000 face carries under half the peak area, so it was filed as a MINOR
    # level and never offered to the pair search. The fallback then took
    # [first, last] = 0.0000/1.7500, contact came out at 1.7500 instead of
    # 1.0000, and every convention-B ceiling sat 0.75 in high. That is what
    # Benton saw as "nearly an inch too high", and
    # reference/floor-ceiling-geometry.md predicted this exact failure when it
    # marked the ceiling rule "derived, not confirmed — it will be obvious on
    # the first build, because the ceiling will sit a hair over an inch out".
    #
    # Ties are broken by area, so a genuine slab beats a coincidence. On a floor
    # CTR panel the 1/32 in underside lip makes 0.0312/1.0000 a near-miss
    # candidate at 0.9688; the real 0.0000/1.0000 pair carries far more area and
    # wins.
    cands = levels.combination(2).select { |a, b| ((b - a) - 1.0).abs < 0.05 }
    pair = cands.max_by { |a, b| tally[a].to_f + tally[b].to_f }
    pair ||= [levels.first, levels.last]

    # THE ROOM-SIDE TELL MUST LIE OUTSIDE THE SLAB, NOT INSIDE IT.
    #
    # Anything between the two slab faces is internal to the slab and says
    # nothing about which way up the part is. The 1/32 in lip on the underside of
    # the floor CTR panels sits at 0.0312, inside the 0.0000..1.0000 slab, and
    # reference/floor-ceiling-geometry.md calls it out as "not structural" — but
    # it was the only minor level those parts have, so it was read as the tell,
    # came out BELOW the deck, and every floor CTR panel was turned upside down.
    # That is the second half of what Benton reported.
    minor = levels.reject { |z| z >= pair.first - 0.02 && z <= pair.last + 0.02 }

    if minor.empty?
      # Nothing to read the orientation from. Assume as-modelled and say so by
      # taking the face the wall would meet if it were the right way up.
      return [ex.call(kind == 'FL' ? pair.last : pair.first), false]
    end

    m = minor.max_by { |z| tally[z] }          # the most substantial minor face
    above = m > (pair[0] + pair[1]) / 2.0

    if kind == 'FL'
      # Deck faces up when the minor geometry is above it.
      [ex.call(above ? pair.last : pair.first), !above]
    else
      # Slab's room side faces down when the minor geometry is below it.
      [ex.call(above ? pair.last : pair.first), above]
    end
  end

  # Area per horizontal level, keyed on z ROUNDED TO 1/64 so that faces of one
  # plane land in one bucket. The rounding is for grouping only - see
  # exact_level for why the placement must not use these keys.
  def self.flat_levels(defn)
    tally, = flat_levels_with_exact(defn)
    tally
  end

  # THE ROUNDED KEY IS NOT THE FACE. A face at 2.1016 is filed under 2.1094,
  # and a ceiling placed at the key instead of the face sits 1/128 low. Benton,
  # 2026-08-25, off a corrected full build: "the standard ceiling is just
  # SLIGHTLY too low, like maybe 1/128". So the bucket keeps the area-weighted
  # mean of the true z of every face in it, and contact_z hands back THAT.
  def self.flat_levels_with_exact(defn)
    up = Geom::Vector3d.new(0, 0, 1)
    tally = Hash.new(0.0)
    zsum  = Hash.new(0.0)
    walk(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        n = f.normal.transform(tr)
        n.normalize!
        next if n.dot(up).abs < 0.999
        zt = f.vertices.first.position.transform(tr).z.to_f
        z = (zt * 64).round / 64.0
        a = f.area.to_f
        tally[z] += a
        zsum[z]  += a * zt
      rescue StandardError
        next
      end
    end
    exact = {}
    tally.each { |z, a| exact[z] = a > 0 ? zsum[z] / a : z }
    [tally, exact]
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
      cz, flip = contact_z(defn, kind)
      if cz.nil?
        warn << "#{t[:part][:file]}: no flat faces to measure"
        next
      end

      # Orientation off the FL twin, so floor and ceiling take the same rotation.
      # On a CL build the twin is already loaded — build-booth-components runs FL
      # first — so this resolves to the existing definition rather than importing
      # anything new.
      # ====================================================================
      # A CEILING SPEAKS FOR ITSELF WHEN IT CAN, AND IS MIRRORED WHEN IT CANNOT.
      # ====================================================================
      #
      # Benton, 2026-08-26, off a built MDL 84126: "the 84126 E standard ceiling
      # components side pieces need to be rotated 180. The hinges are on the
      # inside right now, they should be on the outside perimeter."
      #
      # He is the first person ever to look at one. No Standard CEILING deck's
      # plan rotation has ever been confirmed, by eye or by probe - the
      # bracket_edge rule below was validated by SIMULATION over FLOOR parts,
      # and probe-levels.rb has always printed nothing at all for ceilings.
      # reference/floor-ceiling-geometry.md's "floor and ceiling hinges are
      # coplanar in plan" is an ASSERTION carried on the words "Also Benton"
      # from 2026-08-14, with no measurement behind it.
      #
      # THE STANDARD CEILINGS COME IN TWO AUTHORING CONVENTIONS, and the split is
      # measured, not named (_face-levels.tsv, 2026-08-26; the arithmetic is in
      # .forge/fixer/verify-ceiling-cue.py, whose sole witness is that TSV):
      #
      #   B - rim at 1.7500, hardware ABOVE it, contact_z says flip.  6 parts.
      #       Authored the same way up as a FLOOR and turned over by the X-axis
      #       180 below. An X-180 mirrors Y and leaves the SHORT axis alone, so
      #       the plan position survives - and it is measured to:
      #           STD9648CL SIDE  own edge 0.7366
      #           STD9648FL SIDE  twin     0.7366   <- identical to 4 dp
      #       That is the ONLY Standard ceiling part carrying a cue of its own,
      #       and for it the coplanar invariant HOLDS. It must not move.
      #
      #   A - rim at 3.1094, NOTHING above it, hardware hanging below, no flip.
      #       17 parts, STD8442CL SIDE among them. Authored already inverted -
      #       and inverted about the LONG axis, which DOES mirror the short axis.
      #       So its bracket line sits at the opposite end of the tiling axis
      #       from its floor twin's, and applying the twin's fraction unmirrored
      #       turns it exactly the wrong way. That is the defect Benton reports.
      #
      # So: use the part's OWN cue when it has one (convention B - provably no
      # change, its own reading and its twin's are the same number), and mirror
      # the twin's when it does not (convention A). Floors always have a cue of
      # their own and are untouched by this, to the thousandth.
      #
      # Moves the ceiling end tiles of the 60, 72, 84 and 102 series. Leaves
      # every 96-series ceiling alone - the one series with a measured cue - and
      # leaves every floor alone. Full list in
      # .forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md.
      #
      # WHAT FALSIFIES THIS: a convention-A ceiling that still reads hinges
      # inboard after the change. The mirror generalises ONE observed part
      # across a MEASURED class; if the class is not uniformly authored, it will
      # show up as a booth this fix turns the wrong way. Say which booth.
      own  = bracket_edge(defn)
      twin = fl_twin(cat, t[:part])
      t[:edge] = if own
                   own
                 elsif twin[:file] == t[:part][:file]
                   nil
                 else
                   td = (model.definitions.load(twin[:path]) rescue nil)
                   e  = td ? bracket_edge(td) : nil
                   (e && kind == 'CL') ? 1.0 - e : e
                 end

      # Say so when an end could not get the hand it wanted. Silence here is how
      # an MDL 7296 S came out with SIDE L at both ends and still read as a
      # clean build in the console.
      if t[:substituted]
        warn << format('%s used at the %s end — no SIDE %s of that size in the ' \
                       'folder, so the %s-hand part was placed instead.',
                       t[:part][:file], t[:at_low_end] ? 'low' : 'high',
                       t[:at_low_end] ? 'L' : 'R',
                       t[:part][:hand] == 'L' ? 'left' : 'right')
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
      # height above it.
      target_z = DECK_TOP_Z
      target_z += wall_h unless kind == 'FL'

      # ORIENTATION FIRST, THEN READ THE CONTACT PLANE BACK OUT OF IT.
      #
      # Only the quarter turn remains, but the order still matters: the contact
      # z was measured in the part's own coordinates, and any rotation moves that
      # plane. Build the transform, push the contact point through it, then work
      # out the lift from where it actually ended up.
      tr = Geom::Transformation.new
      # THE PANEL'S BRACKET LINE MUST FACE OUT, AND THE PANEL SAYS WHERE IT IS.
      #
      # The old rule was positional — turn the high-end tile, leave the low one —
      # and it was right for the 72 series and wrong for the 96 series, which is
      # what made the MDL 96120 S come out with both side panels' hinges facing
      # the centre while the MDL 7272 S was confirmed correct.
      #
      # The probe over all 237 parts says why. The bracket line does NOT sit at a
      # consistent end of the part's short axis, reported as a fraction along it:
      #
      #     STD7248FL SIDE L   0.261      STD9648FL SIDE   0.737
      #     STD7224FL SIDE R   0.218      STD9648CL SIDE   0.737
      #     STD10242FL SIDE    0.240      STD6018FL SIDE R 0.216
      #     STD8442FL SIDE     0.266      every CTR        0.500
      #
      # The 72, 102 and 84 series carry it at the LOW edge; the 96 series at the
      # HIGH edge. One positional rule cannot serve both, so the turn is measured:
      # turn whenever the bracket line would otherwise end up inboard.
      #
      # This reproduces the confirmed 7272 exactly — at 0.261 the low tile stays
      # unturned and the high tile still turns — so the booth Benton signed off on
      # does not move. It is the 96 series that flips, which is the whole point.
      #
      # ORIENTATION IS READ OFF THE FLOOR PART, FOR BOTH DECKS.
      # reference/floor-ceiling-geometry.md records the invariant: floor and
      # ceiling hinges are coplanar in plan, so the pair take the same rotation
      # and are never decided independently. It is also the only thing that
      # works — a convention-A ceiling has nothing above its rim to measure, so
      # it yields no cue at all, while its floor twin always does.
      #
      # A symmetric part (CTR panels, and the 6042 SIDE pair, which the probe
      # shows are identical to four decimals) yields no cue and keeps the old
      # positional rule. Nothing there can be got wrong, because there is no
      # asymmetry to point the wrong way.
      edge = t[:edge]
      half = if edge.nil?
               !t[:at_low_end]
             elsif t[:at_low_end]
               edge > 0.5
             else
               edge < 0.5
             end
      tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, 180.degrees) * tr if flip
      tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees) * tr if half
      tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * tr if turn

      # Where the contact plane ended up, after all of that.
      now_cz = Geom::Point3d.new(0, 0, cz).transform(tr).z.to_f
      tr = Geom::Transformation.translation(
        Geom::Vector3d.new(0, 0, target_z - now_cz)) * tr

      # THEN seat it in plan, from the TRANSFORMED corners rather than bb.min.
      #
      # bb.min transformed is not the minimum of the transformed box: a half
      # turn sends the minimum corner to the maximum, and a quarter turn swaps
      # the axes. Using it would put every turned panel a full panel-width off.
      # All eight corners, take the minimum — cheap, and right under any
      # transformation.
      seat = deck_extent(defn, cz) || bb
      got = Geom::BoundingBox.new
      8.times { |k| got.add(seat.corner(k).transform(tr)) }
      dx_seat = x - got.min.x.to_f
      dy_seat = y - got.min.y.to_f

      # ====================================================================
      # THE LAST TILE SEATS AGAINST THE FAR PERIMETER, NOT ITS NOMINAL STATION.
      # ====================================================================
      #
      # Benton, 2026-08-26, off a built MDL 84126: "One of the 8442FL Sides
      # needs to move outwards 1/32. Only one, so kinda weird." The asymmetry
      # is the whole diagnosis, and it is not weird at all.
      #
      # catalogue() reads :along off the NAME DIGITS (see the regex above), so
      # every tile station is NOMINAL - 0, 42, 84. But the seating above lands
      # each tile by its MEASURED low corner. A part that measures under its
      # name therefore loses that difference at whichever edge it is NOT seated
      # against, and since every tile is laid low-edge-first, the loss lands at
      # the HIGH end of the run - once, on the last tile only:
      #
      #   STD8442FL SIDE  41.9688 vs 42 nominal   -> ends 1/32 short of the wall
      #   STD8442FL CTR   41.9375 vs 42 nominal   -> an interior joint, hidden
      #   STD8442CL SIDE  42.0000 exactly         -> the CEILING is already flush
      #
      # That last line is why he reported this on the FLOOR and not the ceiling:
      # all 21 Standard CL parts measure their nominal name, so no ceiling deck
      # moves by one thousandth here. Of the 25 Standard layouts, 17 floors move
      # (1/32 or 1/16) and 8 do not; every one of the 23 ceilings is unchanged.
      # Verified part by part in .forge/fixer/verify-deck-pitch.py, whose
      # witnesses are the folder listing, _component-probe.tsv and
      # wr-booth-data.rb - never a snapshot of this file.
      #
      # This is the same rule the Enhanced tray already follows: seat the tile
      # on the edge that meets the wall and let the slack fall at the interior
      # joint, which is a butt joint nobody sees. Doing it from `got.max` rather
      # than by adding a fudge means it is right whatever deck_extent measures -
      # the outer edge lands on the perimeter by construction.
      #
      # The interior slack is NOT closed by this and is not claimed to be: an
      # MDL 84126 floor still carries a 3/32 gap at the CTR/high-SIDE joint.
      # Benton reported the perimeter, so the perimeter is what moves.
      if t[:at_high_end]
        far = INSET + t[:run].to_f
        if t[:along_is_x]
          dx_seat = far - got.max.x.to_f
        else
          dy_seat = far - got.max.y.to_f
        end
      end

      tr = Geom::Transformation.translation(
        Geom::Vector3d.new(dx_seat, dy_seat, 0)) * tr

      inst = nil
      begin
        inst = parent.entities.add_instance(defn, tr)
        # The part's own name, and nothing else.
        #
        # This carried " (turned)" and " (flipped)" while the orientation was
        # being worked out, so a wrong panel was visible in the Outliner without
        # measuring. That is diagnostic scaffolding, and it does not belong in a
        # model that gets exported and read by other people — an instance called
        # "STD7224FL SIDE R (turned)" invites the question "turned by whom, and
        # is that a problem". The console line below still reports it.
        inst.name = t[:part][:file] if inst
        placed += 1
      rescue StandardError => e
        warn << "#{t[:part][:file]}: place failed, #{e.class}: #{e.message}"
      end

      # Report from the PLACED INSTANCE, not from `got` — `got` was measured
      # before the final seating translation, so its x and y are one step stale.
      # A debug line that is subtly wrong is worse than none, because it gets
      # believed.
      landed = (inst && inst.valid? ? inst.bounds : nil)
      if landed
        puts format('    %-26s%-9s%-9s contact %7.4f  ->  %7.2f %7.2f %7.2f  ' \
                    'to %7.2f %7.2f %7.2f   %s',
                    t[:part][:file], flip ? ' flipped' : '', half ? ' turned' : '',
                    cz, landed.min.x.to_f, landed.min.y.to_f, landed.min.z.to_f,
                    landed.max.x.to_f, landed.max.y.to_f, landed.max.z.to_f,
                    t[:edge].nil? ? 'edge n/a' : format('edge %.3f', t[:edge]))
      end
    end

    [placed, warn, note]
  end

  # --------------------------------------------------------- seam seals --
  #
  # A seam seal drops into the joint between two deck panels and registers into
  # a slot cut in each of them. `build` leaves those joints bare.
  #
  # THERE ARE TWO FAMILIES AND THEY ARE NOT THE SAME PART. The library carries
  # STDSS CL5/CL6/CL7/CL8 and STDSS 8.5CL for the ceiling, and an exact mirror
  # STDSS FL5/FL6/FL7/FL8 and STDSS 8.5FL for the floor. Only the ceiling five
  # were ever placed; the floor five went in on 2026-08-26.
  #
  # THEY ARE A STANDARD-DECK FEATURE. The only 'ENH' seals in the folder are
  # 'ENH MidWallSeamSeal' and 'ENH CornerSeamSeal', which are WALL seals - there
  # is no ENH deck seam seal of either kind. Observed off the real listing on
  # 2026-08-26. So the inner deck's joints get nothing, and that is not an
  # omission here; if the IEP tray and mat want seals it is a parts question.
  # This is a SEPARATE PASS on purpose: the FL/CL path was confirmed correct on
  # 2026-08-17 and re-running `plan` here costs one folder glob to leave `build`
  # byte-identical. `plan` is pure, so the joints computed here are the joints
  # the panels were actually seated at.
  #
  # WHAT IS MEASURED (probe-seam-seal.rb, run by Benton on a built MDL 7272 S):
  #
  #   Seals are all 6.500 across the joint and — since Benton re-cut all four CL
  #   seals on 2026-08-17 — 1.750 tall, and their length is exactly
  #   feet x 12 - 2: CL5 58, CL6 70, CL7 82, CL8 94, 8.5CL 100.
  #
  #   Levels, from the datum (the largest flat face) upward:
  #
  #     CL5 / CL6 / CL7    datum  0.000   mid 1.000   top 1.750
  #     CL8 / 8.5CL        datum -0.750   mid 0.250   top 1.000
  #
  #   Gap signature +1.000 / +0.750 on every one of them, so CL8 and 8.5CL are
  #   CL5/6/7 TRANSLATED DOWN 0.750, not flipped. NOTHING IN THIS PATH MAY FLIP A
  #   SEAL, and no contact_z-style up/down detection belongs here — that rule is
  #   for the panels. The 0.750 top section is what drops into the panel slot.
  #
  #   Registration is symmetric and unhanded. STDSS CL8's ribs sit at part x
  #   0.6875..0.9375 and 5.5625..5.8125 on a 6.500 part, i.e. +/-2.4375 from its
  #   own centreline. The slot in STD7248CL SIDE L is centred 2.4378 from the
  #   joint edge and in STD7224CL SIDE R 2.4368 from its own — two panels,
  #   independently, agreeing with the seal to three decimals. So: centre the
  #   seal on the joint station and the ribs land in the slots. There is no
  #   handing and no front/back.
  SEAL_NAME = /\ASTDSS\s*(?:CL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*CL)\z/i.freeze

  # THE FLOOR FAMILY, AND IT IS A SECOND PATTERN RATHER THAN A LOOSENED FIRST
  # ONE. Writing `(CL|FL)` into SEAL_NAME would work and it would also mean one
  # regex standing between the seals and the panel pool; the comment above and
  # the one on `NAME` both say in capitals that keeping those pools disjoint has
  # already cost a round. Two named patterns cost one line and cannot drift into
  # each other.
  #
  # Same two spellings for the same reason: the digit changes sides at 8.5
  # ('STDSS FL8' but 'STDSS 8.5FL'), exactly as it does on the ceiling.
  SEAL_FL_NAME = /\ASTDSS\s*(?:FL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*FL)\z/i.freeze

  # HOW LONG A SEAL OF EACH KIND IS, AS AN INSET OFF THE DECK'S CROSS SPAN.
  #
  # The two families do NOT follow one rule and this is the number that says so.
  # Measured off P:\Sketchup\NewMasterComponentList\_face-levels.tsv, which
  # carries the real bounding box of every part in the folder:
  #
  #   STDSS CL5 58, CL6 70, CL7 82, CL8 94, 8.5CL 100   -> cross - 2
  #   STDSS FL6 72, FL7 84, FL8 96                      -> cross exactly
  #
  # So a floor seal runs the FULL width of the deck and a ceiling seal stops an
  # inch short at each end. Two inches is not a rounding difference, and one
  # shared rule would have called every floor seal wrong by exactly that.
  #
  # STDSS FL5 AND STDSS 8.5FL ARE NOT IN THAT PROBE - it was written on
  # 2026-08-14 and does not carry them - so the FL figure is MEASURED on three
  # of the five parts and ASSUMED for the other two. The length tripwire in
  # `seals` is what catches it if either turns out to be a 2 in part.
  SEAL_LEN_INSET = { 'CL' => 2.0, 'FL' => 0.0 }.freeze

  # THE RULE: THE SEAL'S TOP FACE LANDS ON THE PANELS' CONTACT PLANE.
  #
  # This constant is that rule expressed as the one number the placement uses, so
  # if a seal ever sits at the wrong HEIGHT it is the only constant to change.
  # Nothing else compensates for it and nothing that does should ever be added.
  #
  # Inches to lift the seal's DATUM FACE — its largest-area flat level — above the
  # ceiling panels' contact plane, which is DECK_TOP_Z + wall_h (81.000 on a
  # standard booth). The datum sits 1.750 BELOW the seal's top face on every
  # ceiling seal in the library, so -1.75 is "top flush with the contact plane".
  #
  # MEASURED, BY FIT TEST, NOT DERIVED. Benton built an MDL 7272 S with this pass
  # on 2026-08-17, moved the placed STDSS CL6 by hand until it seated, and it
  # needed to come DOWN 1 3/4. The geometry says that is exact rather than an
  # eyeball figure:
  #
  #   datum 0.000 -> top 1.750 on CL5/6/7, datum -0.750 -> top 1.000 on CL8 and
  #   8.5CL. Datum-to-top is 1.750 on BOTH families, because CL8's datum and its
  #   top are each 0.750 lower. So ONE value serves all five and the 0.750 family
  #   shift needs no special case — proved in .forge/builder/seal_placement_proof.py.
  #
  #   At -1.75 the datum lands at booth z 79.250 and the top at exactly 81.000,
  #   and the seal's top section (part z 1.000 -> 1.750, 0.750 tall) drops exactly
  #   into the panel slot, which runs booth z 80.249 -> 81.000 and is 0.750 deep.
  #
  # THE PARTS CHANGED ON 2026-08-17 AND THIS NUMBER IS TIED TO THAT. The seals
  # used to be 2.000 tall with an extra 0.250 step at z 1.250; Benton re-cut all
  # four CL seals to 1.750 overall with that step removed, so the seal now suits
  # the slot instead of the code compensating for a part that did not fit. A
  # library still holding the old 2.000-tall seals would want -2.00 here, and
  # would be the thing to check first if a seal ever lands 1/4 in proud.
  SEAL_DATUM_LIFT = -1.75

  # ==========================================================================
  # THE FLOOR SEAL'S VERTICAL DATUM IS NOT MEASURED. THIS IS THAT ADMISSION.
  # ==========================================================================
  #
  # nil means "nobody has fit-tested this", and while it is nil the build DERIVES
  # a datum, PLACES the seals anyway, and WARNS BY NAME every time. Set it to a
  # number after a fit test and the warning goes away - that is the whole
  # protocol, and it is deliberately the same shape as SEAL_DATUM_LIFT above so
  # the two read alike once both are real.
  #
  # WHAT IT MEANS WHEN SET: inches to lift the floor seal's DATUM FACE - its
  # largest-area flat level - above the FLOOR deck's contact plane, which is
  # DECK_TOP_Z (0.000). Exactly the ceiling constant's definition with the
  # ceiling's contact plane swapped for the floor's.
  #
  # WHAT IT DERIVES WHILE NIL: the ceiling rule's own sentence, applied to the
  # floor - "the seal's TOP face lands on the panels' contact plane". Computed
  # per part from its own geometry (bounds.max.z - datum) rather than written
  # out as a number, so a re-cut part moves with it instead of silently
  # inheriting a figure measured on the old one. On the 2026-08-14 probe that
  # comes to -1.6906 for STDSS FL6 / FL7 / FL8 (datum -1.0000, top +0.6906).
  #
  # WHY THE CEILING'S -1.75 IS NOT REUSED, AND MUST NOT BE. That number is a FIT
  # TEST: Benton moved a placed STDSS CL6 by hand on 2026-08-17 until it seated,
  # and it is tied to the re-cut that made the ceiling seals 1.750 tall the same
  # week. The floor seals are a different profile entirely - 7.1897 across the
  # joint against the ceiling's 6.500, 1.6906 tall against 1.750, and their
  # largest face is at the BOTTOM (-1.0000) where the ceiling's is at the datum
  # 0.0000. Nothing about the ceiling's number transfers.
  #
  # THE THREE CANDIDATES, so the fit test is a one-line edit rather than a
  # re-derivation. Floor deck top (the walking surface) is booth z 0.000 and a
  # standard floor panel runs booth z -1.000 to +2.108 around it:
  #
  #   top flush with the deck top   SEAL_FL_DATUM_LIFT = -1.6906  (the default)
  #     -> seal spans -1.6906 .. 0.0000, i.e. 0.69 below the panel underside
  #   datum flush with the deck top SEAL_FL_DATUM_LIFT =  0.0000
  #     -> seal spans  0.0000 .. 1.6906, entirely above the walking surface
  #   bottom flush with the panel underside      = -1.0000
  #     -> seal spans -1.0000 .. 0.6906, 0.69 proud of the walking surface
  #
  # None of the three is obviously right and this file cannot open the part to
  # find out, which is precisely why it is nil and warns instead of choosing
  # quietly. The first is the default only because it is the ceiling rule's own
  # words, not because it has been seen.
  # MEASURED 2026-08-26. Benton, off a built MDL 102144 E whose floor seals were
  # placed at the derived -1.6875: "all of the floor seam seals need to go up
  # 9/16"." So -1.6875 + 0.5625 = -1.1250, and it is a measurement now, not one
  # of the three guesses above.
  #
  # None of the three candidates was right, which is the useful part. The seal
  # spans booth z -1.1250 .. 0.5625: it starts 0.125 below the floor panel's
  # underside (-1.000) and stands 0.5625 proud of the walking surface (0.000).
  # "Top flush with the deck top" - the ceiling rule's own sentence, and the
  # default this shipped with - was wrong by exactly the 9/16 Benton moved it.
  # The ceiling's -1.75 does not transfer and never did; the two seals are
  # different profiles, 6.500 across against 7.1897.
  # SECOND FIT TEST, 2026-08-27, and the constant moved again. Benton, off a
  # built MDL 102144 E carrying the -1.1250 above: "each floor seam seal needs
  # to go up 15/128"." Up is toward the room, so the datum lift RISES:
  # -1.1250 + 0.1171875 = -1.0078125, i.e. -129/128.
  #
  # 15/128 IS NOT A HAND MEASUREMENT AND IS NOT MEANT TO LOOK LIKE ONE. It is
  # the kind of figure SketchUp reports when a placed instance is moved onto a
  # snap and the displacement is read back, so it is a real distance off a real
  # build rather than a fraction anyone chose. Do NOT tidy it to 1/8 (0.125):
  # that is 1/128 of an inch away, and the precision is the point.
  #
  # THE SEAL NOW SPANS booth z -1.0078 .. 0.6828. Its underside sits 0.0078
  # below the floor panel underside (-1.000) - very nearly flush with it - and
  # it stands 0.6828 proud of the walking surface (0.000).
  #
  # WORTH KNOWING IF A THIRD CORRECTION EVER LANDS: that is within 1/128 of the
  # THIRD candidate listed above, "bottom flush with the panel underside"
  # (-1.0000) - the one none of the three rounds of reasoning picked, and the
  # one two successive fit tests have now walked onto from -1.6906. The answer
  # looks like it wants to be -1.0000 exactly. That is an OBSERVATION AND NOT A
  # LICENCE TO ROUND: the constant stays at what was measured until Benton says
  # otherwise, because every time this file has reasoned its way to a number
  # instead of being told one, it has been wrong.
  SEAL_FL_DATUM_LIFT = -1.0078125

  # How far the measured seal length may differ from cross - 2 before it is
  # called out. The name-to-cross mapping and the measured length are two
  # independent checks on the same claim, and finding them in disagreement means
  # the feet x 12 - 2 rule met a part it does not cover.
  SEAL_LEN_TOL = 0.05

  # Every seam seal of one kind in the folder. `kind` is 'CL' or 'FL'.
  #
  # Globbed as STDSS*, which is disjoint from the panel catalogue's STD* + a
  # regex demanding STD followed by DIGITS (`NAME`, above). That disjointness is
  # the whole reason seals need their own path, and it must not be "fixed" by
  # loosening NAME - that would drop seals into the panel pool and let one get
  # tiled into a deck. Adding the floor family does not widen the glob by one
  # character: 'STDSS FL6' was already swept up and already thrown away by
  # SEAL_NAME. All that changes is which of the two patterns judges it.
  #
  # Both spellings are matched (CL8 and 8.5CL, FL8 and 8.5FL) because the digit
  # changes sides at 8.5 and the naming gives no reason for it, so trusting
  # whoever names the next one to pick a side is not a plan.
  #
  # `kind` DEFAULTS TO 'CL' so the ceiling call site is unchanged.
  def self.seal_catalogue(dir, kind = 'CL')
    re = kind.to_s.upcase == 'FL' ? SEAL_FL_NAME : SEAL_NAME
    out = []
    Dir.glob(File.join(dir, 'STDSS*.skp')).each do |path|
      base = File.basename(path, '.skp')
      m = re.match(base.strip)
      next if m.nil?
      ft = (m[1] || m[2]).to_f
      out << { :file => base, :path => path, :feet => ft, :cross => ft * 12.0 }
    end
    out
  rescue StandardError => e
    puts "  seal catalogue failed: #{e.class}: #{e.message}"
    []
  end

  # The seal for a deck of this cross dimension, by the name's feet x 12 mapping.
  # nil when the library has none — a normal answer for a single-tile cross,
  # which never gets here, and an error for a real joint, which is reported.
  #
  # No per-model table, and no name-based exception: the crosses are 42, 48, 60,
  # 72, 84, 96, 102, and the library carries CL5/6/7/8 and 8.5CL - and, since
  # 2026-08-26, FL5/6/7/8 and 8.5FL - which is exactly the crosses that tile
  # into more than one panel. The two families map identically, so this method
  # does not need to know which one it was handed.
  def self.pick_seal(seals, cross)
    seals.find { |s| (s[:cross] - cross.to_f).abs < TOL }
  end

  # Where the joints fall along the tiling axis, in DECK coordinates (0 at the
  # deck's low edge). One per interior joint: an MDL 7272 S tiles 48 + 24 and has
  # one at 48; an MDL 96168 S tiles 48 + 48 + 24 + 48 and has three, at 48, 96
  # and 120.
  #
  # Taken from the cut list, not from the placed panels. `build` seats each
  # panel's measured deck_extent at INSET + the running sum, so these ARE the
  # stations the deck edges landed on; re-measuring the instances would be a
  # second source of truth free to disagree with the first.
  def self.joint_stations(tiles)
    return [] if tiles.nil? || tiles.length < 2
    pos = 0.0
    tiles[0..-2].map { |t| pos += t[:along].to_f; pos }
  end

  # Places the seam seals of one deck. `kind` is 'CL' (the ceiling, the original
  # and only caller until 2026-08-26) or 'FL' (the floor). Returns
  # [placed, [warnings], note] - the same shape as `build`, so the caller treats
  # them alike.
  #
  # THE TWO KINDS SHARE EVERYTHING EXCEPT THREE THINGS, and they are all named
  # here rather than spread through the body:
  #
  #   which catalogue   SEAL_NAME vs SEAL_FL_NAME
  #   how long a seal   SEAL_LEN_INSET - cross - 2 on the ceiling, cross on the
  #                     floor. MEASURED, and they really do differ.
  #   where it sits     the ceiling's is a FIT TEST (SEAL_DATUM_LIFT, -1.75);
  #                     the floor's is NOT MEASURED (SEAL_FL_DATUM_LIFT, nil)
  #                     and every floor seal placed while it is nil is warned
  #                     about by name.
  #
  # The stations, the quarter turn, the centring on the joint and the plan-seat
  # discipline are one implementation for both, because the joints are the same
  # joints: `plan` is pure and resolves the SAME cut list for FL and CL on all
  # 25 layouts (asserted in .forge/builder/replay-iep-deck.py).
  def self.seals(model, parent, spec, dir, wall_h = WALL_H, kind = 'CL')
    kind = kind.to_s.upcase
    cat = catalogue(dir)
    return [0, [], "no #{kind} parts"] if cat.empty?

    tiles, = plan(spec, cat, kind)
    # The deck pass already reported why there is no plan. A second copy of the
    # same complaint is noise.
    return [0, [], "no #{kind} plan"] if tiles.nil?

    stations = joint_stations(tiles)
    # A one-tile deck has no joint and therefore no seal. That is a correct
    # build, so it gets a note and NOT a warning.
    return [0, [], 'single tile — no joint'] if stations.empty?

    cross      = tiles.first[:cross].to_f
    along_is_x = tiles.first[:along_is_x]

    seal = pick_seal(seal_catalogue(dir, kind), cross)
    if seal.nil?
      return [0, [format('no %s seam seal for a %g in cross — %d joint(s) ' \
                         'left bare. Nothing was substituted: a seal of the ' \
                         'wrong length would not reach its slots.',
                         kind == 'FL' ? 'floor' : 'ceiling',
                         cross, stations.length)], nil]
    end

    defn = begin
             model.definitions.load(seal[:path])
           rescue StandardError => e
             return [0, ["#{seal[:file]}: #{e.class}: #{e.message}"], nil]
           end

    tally = flat_levels(defn)
    if tally.empty?
      return [0, ["#{seal[:file]}: no flat faces to measure"], nil]
    end
    # The datum: the largest-area flat level. Measured, never the origin — the
    # CL5/6/7 family puts it at 0.0000 and the CL8 family at -0.7500, and the
    # part is the same way up in both. The floor family's largest face is at its
    # BOTTOM (-1.0000 on the 2026-08-14 probe of FL6/7/8), which is one more
    # reason the ceiling's lift cannot be borrowed.
    datum = tally.max_by { |_z, a| a }[0].to_f

    bb   = defn.bounds
    dx   = (bb.max.x - bb.min.x).to_f
    dy   = (bb.max.y - bb.min.y).to_f
    len  = [dx, dy].max
    warn = []
    # The finding-1 tripwire: the NAME said this seal fits and the GEOMETRY is
    # asked whether it agrees. Placed anyway — the name mapping is right on five
    # parts and a warned placement is more useful than a bare joint — but never
    # silently. The expected length is per kind: see SEAL_LEN_INSET.
    inset = (SEAL_LEN_INSET[kind] || 0.0).to_f
    if (len - (cross - inset)).abs > SEAL_LEN_TOL
      warn << format('%s measures %.4f but a %g in %s cross wants %g — the ' \
                     'length rule met a part it does not describe. ' \
                     'Placed anyway; check the joint.',
                     seal[:file], len, cross, kind, cross - inset)
    end

    if kind == 'FL'
      # THE FLOOR SEAL'S HEIGHT IS THE ONE UNMEASURED NUMBER IN THIS FILE.
      # While SEAL_FL_DATUM_LIFT is nil, derive the ceiling rule's own sentence
      # — top face flush with the deck's contact plane — from THIS part's
      # geometry, place it, and say so by name on every single build.
      lift = SEAL_FL_DATUM_LIFT
      if lift.nil?
        lift = datum - bb.max.z.to_f      # negative: the datum sits below the top
        warn << format('%s: its vertical datum is UNMEASURED. Placed with its ' \
                       'TOP face flush to the floor deck at z %.4f (datum ' \
                       'lift %.4f, derived from the part itself, NOT fit ' \
                       'tested). Check it against the real joint and set ' \
                       'WR_Deck::SEAL_FL_DATUM_LIFT. The ceiling seal%s -1.75 ' \
                       'is a different profile and does NOT transfer.',
                       seal[:file], DECK_TOP_Z, lift, "'s")
      end
      target_z = DECK_TOP_Z + lift
    else
      target_z = DECK_TOP_Z + wall_h + SEAL_DATUM_LIFT
    end

    placed = 0
    stations.each do |station|
      # Same quarter turn as the panels and NOTHING ELSE. The seal's own X runs
      # across the joint and its Y along it, the identical convention the panels
      # use, so it takes `turn` and no flip and no half turn.
      tr = Geom::Transformation.new
      tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * tr unless along_is_x

      # Read the datum plane back out of the transform rather than assuming the
      # rotation left it alone — same discipline as the panel path.
      now = Geom::Point3d.new(0, 0, datum).transform(tr).z.to_f
      tr = Geom::Transformation.translation(
        Geom::Vector3d.new(0, 0, target_z - now)) * tr

      # Seat in plan from ALL EIGHT transformed corners, not bb.min: a quarter
      # turn swaps the axes and bb.min transformed is not the transformed
      # minimum.
      got = Geom::BoundingBox.new
      8.times { |k| got.add(bb.corner(k).transform(tr)) }

      # Centre across the joint ON THE JOINT STATION — that is what puts the ribs
      # in the slots — and centre along the joint on the deck's cross span.
      want_a = INSET + station
      want_c = INSET + cross / 2.0
      wx, wy = along_is_x ? [want_a, want_c] : [want_c, want_a]
      cx = (got.min.x.to_f + got.max.x.to_f) / 2.0
      cy = (got.min.y.to_f + got.max.y.to_f) / 2.0
      tr = Geom::Transformation.translation(
        Geom::Vector3d.new(wx - cx, wy - cy, 0)) * tr

      inst = nil
      begin
        inst = parent.entities.add_instance(defn, tr)
        # The part's own name and nothing else — the panel path learned that
        # diagnostic suffixes end up in exported models.
        inst.name = seal[:file] if inst
        placed += 1
      rescue StandardError => e
        warn << "#{seal[:file]}: place failed at station #{station}, #{e.class}: #{e.message}"
        next
      end

      landed = (inst && inst.valid? ? inst.bounds : nil)
      next unless landed
      puts format('    %-26s joint %7.2f  datum %7.4f  ->  %7.2f %7.2f %7.2f  ' \
                  'to %7.2f %7.2f %7.2f',
                  seal[:file], want_a, datum,
                  landed.min.x.to_f, landed.min.y.to_f, landed.min.z.to_f,
                  landed.max.x.to_f, landed.max.y.to_f, landed.max.z.to_f)
    end

    [placed, warn, format('%s x%d', seal[:file], placed)]
  end
  ORIGIN = Geom::Point3d.new(0, 0, 0)
  Z_AXIS = Geom::Vector3d.new(0, 0, 1)
  X_AXIS = Geom::Vector3d.new(1, 0, 0)
end
