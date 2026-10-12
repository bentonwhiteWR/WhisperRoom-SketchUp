# wr-accessories.rb — the quote accessories a booth-builder link can carry:
# studio lights (sl), HEPA filters (hp) and bass traps (bt). Which part, how
# many, and the plan for where each goes.
#
# SINCE 1.83.0 IT ALSO HOLDS THE IEP CEILING BEAM TABLE (iep_beam_plan). The
# beam is not a quote accessory — it is in the booth's own bill of materials —
# but it is the same kind of thing for this file: a part, a count copied from
# the quote repo's data, and a rule, with the placing done in wr-overlays.rb
# (place_iep_beams).
#
# NOT A COMMAND. A library, `load`ed by booth-from-link.rb (to print the plan
# before the build) and build-booth-components.rb (for wr-overlays, which does
# the placing), and in wr_tools' SKIP so it never appears in the panel.
# NOTHING HERE TOUCHES THE SKETCHUP API, so scripts/rbtest-accessories.py loads
# the whole file outside SketchUp. Keep it that way: the SketchUp half lives in
# wr-overlays.rb (place_studio_lights / place_hepa / place_bass_traps).
#
# The Audimute acoustic package (ac) is NOT here: it is laid out on the booth's
# interior walls by the whisperroom-acoustic-package skill (skills/), not by the
# importer. booth-from-link refuses ac by name and points at that skill.
#
# THE TABLES ARE EMBEDDED, NOT READ. The plugin runs on machines that have no
# WhisperRoomQuote checkout (Gabe's), so the figures are copied here with the
# file they came from. If the source changes, re-copy; do not edit a figure
# here on its own.
#
# MDL 127 LP (the diamond booth) is EXCLUDED from every accessory for now
# (Benton, Sep 2026). It is refused by name, never silently skipped.

module WR_Accessories
  # Re-loadable: constants are re-assigned on every load.
  constants.each { |c| remove_const(c) rescue nil }

  # ------------------------------------------------------------ studio light --
  #
  # SOURCE: WhisperRoomQuote lib/pl-data/feature-rules.json `sl_by_model`,
  # derived there from 52 real packing lists (copied 24 Sep 2026; the file's
  # last commit is 89a27d09, 5 Aug 2026). Each row there is
  #   "MDL 7272 E": { "add": { "T08": 1 }, "remove": { "T01": 2 } }
  # T01 is the standard LIGHT, T07 the 29" STUDIO LIGHT (pack 'SL 29'), T08 the
  # 52" STUDIO LIGHT (pack 'SL 52') — lib/pl-data/components-master.json. The S
  # and E rows are identical for every model (checked when copied), so this is
  # keyed on the model digits alone.
  #
  #   digits => [part file, how many studio lights, how many T01 they replace]
  SL_BY_MODEL = {
    '4230'   => ['SL29', 1, 1], '4242'   => ['SL29', 1, 1],
    '4260'   => ['SL29', 1, 1], '4284'   => ['SL52', 1, 2],
    '4848'   => ['SL29', 1, 1], '4872'   => ['SL29', 1, 1],
    '4896'   => ['SL52', 1, 2], '6060'   => ['SL29', 1, 2],
    '6084'   => ['SL29', 2, 2], '7272'   => ['SL52', 1, 2],
    '7296'   => ['SL29', 2, 2], '8484'   => ['SL52', 2, 3],
    '9696'   => ['SL52', 2, 3], '10284'  => ['SL52', 2, 3],
    '84102'  => ['SL52', 2, 3], '84126'  => ['SL52', 3, 4],
    '96120'  => ['SL52', 2, 3], '96144'  => ['SL52', 3, 4],
    '96168'  => ['SL52', 3, 4], '96192'  => ['SL52', 4, 4],
    '102102' => ['SL52', 2, 3], '102126' => ['SL52', 3, 4],
    '102144' => ['SL52', 3, 4], '102168' => ['SL52', 4, 4],
    '102186' => ['SL52', 4, 4]
  }.freeze

  # Nominal fixture lengths, from the part names ('1 - 52" STUDIO LIGHT').
  # Used only to report; placement measures the loaded .skp.
  SL_NOMINAL = { 'SL29' => 29.0, 'SL52' => 52.0 }.freeze

  # Plan layout of the fixtures under the ceiling: LONGWISE ON A CEILING TILE
  # (Benton, 12 Oct 2026: "They should be rotated 90 so they are longwise on
  # the ceiling component. Not crossing from ceiling piece to ceiling piece").
  # Each fixture's length runs along its tile's long side — which on every
  # multi-tile deck is the seam direction, parallel to the ceiling seam seals
  # (tile widths 18-48 against crosses 60-102) — and it sits inside one tile,
  # never across a seam. The widest tiles take a fixture first, one each; a
  # count beyond the tiles that fit doubles up, spaced evenly across the tile.
  # Which tiles, and where across the tile, is still ASSUMED (no drawing).
  # SL_EDGE_CLEAR is the room a fixture must leave at each end of its tile.
  SL_EDGE_CLEAR = 6.0

  # KEEP-OUTS UNDER THE CEILING (1.84.0). Anything that hangs below a ceiling
  # tile's underside inside the usable tile rectangle is a keep-out for the
  # fixture flush on that underside: on a roof-mounted (rv = 1) booth that is
  # the roof unit's hanger rods, which come down THROUGH the ceiling (People's
  # Space RM96120VSS > Component#69 > Component#68, about 2 in round, to booth
  # z 77.15 against a ceiling face at 80.25, at x ~23 and x ~96, y ~49 —
  # .forge/builder/HANDOFF-peoplesspace-accessories.md, observed 6 Oct 2026).
  # 1.83.0's tile centres on a 96120 are x 25 and x 97: both on a rod.
  # wr-overlays measures the keep-outs off the placed geometry; this only
  # moves fixtures off them. SL_KEEP_CLEAR is the gap left to a keep-out:
  # ASSUMED (no drawing gives one), the same 1/2 in the acoustic package keeps.
  SL_KEEP_CLEAR = 0.5

  # ---------------------------------------------------------------- HEPA --
  #
  # ONE PER VENT SET, on the INTAKE duct box — the box the fan hose does NOT
  # connect to — butted to its open end, filter side up (Benton, Sep 2026).
  #
  # THE ONLY PROVEN GEOMETRY IS THE ROOF UNIT'S. It was placed and accepted
  # live on People's Space's RM96120VSS (.forge/builder/peoplesspace-ap/,
  # place-hepa.rb then hepaout.rb, 23 Sep 2026): the intakes there are the
  # 'VSS duct box' instances sitting DIRECTLY inside the RM part, and every
  # fan hose runs fan -> EFS, never to them (hose.rb, observed). All 44 RM
  # parts carry exactly one such box per vent set (.forge/builder/roof-vent/
  # rm-measure.json, observed: kids 'VSS duct box' + one other, ents = 2 x sets).
  #
  # In that box's OWN coordinates:
  #   HEPA_OPEN_END  centre of the open end (the box runs along its local +z
  #                  from the closed end to this one)
  #   HEPA_BOX_FLOOR the box's local x at its underside, which lands at the
  #                  world bottom of the box
  # and the HEPA part measures 7.87 x 6.5 x 10.7 with its filter on local +x,
  # so local x -> world up, local z -> out of the open end, local y across.
  #
  # A WALL-VENTED booth is REFUSED BY NAME. Its duct boxes live inside the
  # vent-wall parts (40VNT / 46VNT_VSS / ...), whose insides have never been
  # measured, and which box is the intake there is not known. Guessing would
  # put a filter on the wrong box and it would look right in a render.
  HEPA_BOX_NAME  = /\AVSS duct box(#\d+)?\z/
  HEPA_OPEN_END  = [3.92, 3.87, 49.5].freeze
  HEPA_BOX_FLOOR = 0.67

  # ------------------------------------------------------------ bass traps --
  #
  # EACH 'BASS TRAPS' QUOTE LINE IS ONE 2-PACK (Benton, Sep 2026). The link
  # carries bt as an ON/OFF FLAG ONLY (booth-builder.html designPayload:
  # `bt: state.bassTraps ? 1 : 0`) — never a quantity. The pack count comes
  # from the quote builder's package presets, WhisperRoomQuote
  # quote-builder.html PRESET_QTY_OVERRIDES (copied 24 Sep 2026), keyed on the
  # link's package name `pk`; every other case is one pack. A rep who changes
  # the line quantity on the quote by hand is NOT visible in the link.
  BT_PER_PACK = 2
  BT_PACKS_BY_PACKAGE = {
    'Practice Basic'   => 3,
    'Practice Deluxe'  => 3,
    'Recording Studio' => 3,
    'Drum Booth'       => 4,
    'Drum Studio'      => 4
  }.freeze

  # Default placement: STANDING in the UPPER interior corners (Benton). The
  # back corners (the N wall, the portal's "Back") fill first, then the front
  # ones. A fifth trap and on starts a second tier directly under the first
  # — ASSUMED, no rule was given for more than four.
  BT_CORNERS = {
    'NW' => %w[N W], 'NE' => %w[N E], 'SW' => %w[S W], 'SE' => %w[S E]
  }.freeze

  # ------------------------------------------------------------- IEP beams --
  #
  # ONE IEP BEAM CENTRED DIRECTLY BELOW EACH CEILING SEAM SEAL (Benton, 12 Oct
  # 2026). Fitted on Enhanced booths, and on 84-series-and-bigger booths with
  # roof-mounted ventilation — and in the importer "roof-mounted" is rv = 1
  # and NOTHING else (booth-from-link.rb's header says why CBL packs are not
  # evidence of it).
  #
  # Unlike the other accessories this is NOT a quote line. The beam is part of
  # the booth's own bill of materials, so the importer places it whenever the
  # booth carries one — no link flag turns it on or off.
  #
  # THE THREE PARTS, AND THE FILE EACH ONE IS. The PART FILE is chosen BY NAME
  # (Benton, 12 Oct 2026: "You pulled the IEP Beam 7 for this one. It should
  # have been IEP Beam 8."). The BOM descriptions name the size in feet —
  # U02 "IEP BEAM 7'", U101 "IEP BEAM 8'", U01 "IEP BEAM 8.5'" — and the share's
  # files carry the same names, so code -> description -> file is the mapping.
  #
  # THE TRUE LENGTHS ARE BENTON'S, NOT THE BOM'S. Benton, 12 Oct 2026
  # (reported, superseding every figure before it): IEP BEAM 7 = 76 in,
  # IEP BEAM 8 = 88 in, IEP BEAM 8.5 = 94 in. So the quote repo's L figures
  # (70 / 82 / 88, components-master.json) are wrong too; whether they are
  # fixed there is his call, and this repo never writes to WhisperRoomQuote.
  # :length below is Benton's figure and is what the importer's length guard
  # checks a loaded part against; :bom_l is the quote repo's, kept only so
  # the drift check can say the two differ. History: the share's files
  # measured 82 / 94 / 100, then 80 / 92 / 98, before he re-saved them at
  # 13:46 that day measuring exactly 76 / 88 / 94 (observed). The NAME picks
  # the part; the length only guards it (wr-overlays place_iep_beams).
  #
  #   series => code, pack name (the BOM's), part file, Benton's length,
  #             BOM L, source
  #
  # '84' -> U02: Benton put beams on Enhanced 84s (12 Oct 2026, see
  # IEP_BEAMS_84). U02 is in the master but NO model in base-bom.json carries
  # it; the 7 ft beam is the one that fits under the 84-series seal (STDSS
  # CL7, 82 long), as 8 ft fits the 96 and 8.5 ft the 102.
  IEP_BEAM_SERIES = {
    '96'  => { :code => 'U101', :pack => 'IEP BEAM 8 (82")',   :file => 'IEP BEAM 8',
               :length => 88.0, :bom_l => 82.0, :src => 'components-master.json U101' },
    '102' => { :code => 'U01',  :pack => 'IEP BEAM 8.5 (88")', :file => 'IEP BEAM 8.5',
               :length => 94.0, :bom_l => 88.0, :src => 'components-master.json U01' },
    '84'  => { :code => 'U02',  :pack => 'IEP BEAM 7 (70")',   :file => 'IEP BEAM 7',
               :length => 76.0, :bom_l => 70.0,
               :src  => 'components-master.json U02 — the 84 series by Benton, ' \
                        '12 Oct 2026; no BOM row carries U02' }
  }.freeze

  # HOW MANY. SOURCE: WhisperRoomQuote lib/pl-data/base-bom.json, the U-code
  # quantity on each model's E row (observed 12 Oct 2026; the ENV row is
  # identical on every one). No other model in base-bom.json carries a U-code.
  #
  # On every one of these rows the beam count EQUALS the model's STDSS FLCL8
  # (D101) or STDSS FLCL8.5 (D12) count — one floor + one ceiling seal per
  # pack — so "one beam per ceiling seam seal" is the BOM's own arithmetic as
  # well as Benton's rule. build-time code cross-checks it against the seals
  # the importer ACTUALLY placed and refuses to guess when they disagree.
  #
  # ROOF-MOUNTED STANDARD BOOTHS take the SAME count. lib/packing-list.js's RM
  # rule (observed 12 Oct 2026): "Standard (S) booths omit the IEP beam that E
  # booths carry; under Roof Mount the ceiling bears the roof-mount load, so add
  # it back: one U101 per D101 (96-series) / one U01 per D12 (102-series).
  # Count matches the E variant's beam count. E/SNV/ENV are unaffected."
  IEP_BEAMS_BY_MODEL = {
    '9696'   => 1, '96120'  => 2, '96144'  => 2, '96168'  => 3, '96192'  => 3,
    '10284'  => 1, '102102' => 2, '102126' => 2, '102144' => 3, '102168' => 3,
    '102186' => 4
  }.freeze

  # THE 84 SERIES. Benton, 12 Oct 2026 (reported): "Enhanced 84 series should
  # get IEP beams. There are no beams for 72 series or smaller." So an
  # Enhanced 84 gets IEP BEAM 7 whether or not it is roof-mounted, and so does
  # a roof-mounted Standard 84 (his RM rule, 84-series and bigger). That
  # OVERRIDES the BOM, which is silent: no 84 model in base-bom.json carries a
  # U-code and the RM rule in packing-list.js adds none for D11.
  #
  # The COUNT is still the BOM's arithmetic, not a guess: the model's STDSS
  # FLCL7 (D11) quantity in base-bom.json — one floor + one ceiling seal per
  # pack — which is "one beam per ceiling seam seal" exactly as on the 96 and
  # 102 series, and is cross-checked at build time against the seals placed.
  IEP_BEAMS_84 = { '8484' => 1, '84102' => 2, '84126' => 2 }.freeze

  # 72-SERIES AND SMALLER GET NO BEAMS, Enhanced or roof-mounted (Benton, 12
  # Oct 2026, above). iep_series returns nil for them and iep_beam_plan says
  # so by name; this is the rule, not a gap in the table.

  # A ceiling seal is the deck's cross less this (WR_Deck::SEAL_LEN_INSET['CL'],
  # copied — this file must load without wr-deck.rb). So the seal a series'
  # beam hangs under measures (series - 2): 94 / 100 / 82. Used to check the
  # seal the importer placed is the series the beam was chosen for.
  IEP_SEAL_INSET = 2.0

  # ---------------------------------------------------------------- logic --

  def self.excluded(model)
    model.to_s =~ /\AMDL\s*127\s*LP\b/i ? true : false
  end

  def self.digits(model)
    model.to_s[/\AMDL\s+(\d+)/i, 1].to_s
  end

  # { :part, :count, :remove } for a model, or { :error } naming why not.
  def self.sl_plan(model)
    if excluded(model)
      return { :error => "#{model} is excluded from accessories (MDL 127 LP, Benton)" }
    end
    row = SL_BY_MODEL[digits(model)]
    if row.nil?
      return { :error => "#{model} is not in the studio-light table (sl_by_model, " \
                         'feature-rules.json) — no count to place' }
    end
    { :part => row[0], :count => row[1], :remove => row[2] }
  end

  # { :packs, :traps, :source } for a link's bt flag and package name.
  def self.bass_trap_plan(package)
    pk = package.to_s
    packs = BT_PACKS_BY_PACKAGE[pk]
    if packs
      src = "package \"#{pk}\" (quote-builder PRESET_QTY_OVERRIDES)"
    else
      packs = 1
      src = pk.empty? ? 'no package on the link, so one pack' :
                        "package \"#{pk}\" has no override, so one pack"
    end
    { :packs => packs, :traps => packs * BT_PER_PACK, :source => src }
  end

  # The corner fill order: the wall opposite the door first. back_wall is a
  # wall letter; anything else falls back to N, the portal's Back.
  def self.corner_order(back_wall)
    b = %w[N S].include?(back_wall.to_s) ? back_wall.to_s : nil
    if b.nil? && %w[E W].include?(back_wall.to_s)
      e = back_wall.to_s
      o = e == 'E' ? 'W' : 'E'
      return ["N#{e}", "S#{e}", "N#{o}", "S#{o}"]
    end
    b ||= 'N'
    f = b == 'N' ? 'S' : 'N'
    ["#{b}W", "#{b}E", "#{f}W", "#{f}E"]
  end

  # n traps -> [[corner, tier], ...], tier 0 against the ceiling.
  def self.trap_slots(n, order)
    (0...n).map { |i| [order[i % order.length], i / order.length] }
  end

  # Studio-light plan layout over the ceiling TILES. rects = one
  # [x0, y0, x1, y1] per standard ceiling tile, in booth coordinates, already
  # cut back to the room and clear of the seam seals (wr-overlays does that);
  # len = the fixture's measured length.
  # Returns { :lights => [{ :centre => [x, y], :orient => :x|:y (the axis the
  # fixture's LENGTH runs on), :tile => index into rects }], :how }
  # or { :error }.
  def self.sl_tile_layout(count, len, rects)
    if count < 1
      return { :error => "a studio-light count of #{count} is not a count" }
    end
    return { :error => 'no ceiling tiles to hang studio lights from' } if rects.nil? || rects.empty?
    info = rects.each_with_index.map do |r, i|
      x0, y0, x1, y1 = r.map { |v| v * 1.0 }
      wx = x1 - x0
      wy = y1 - y0
      { :i => i, :box => [x0, y0, x1, y1], :long => wx >= wy ? :x : :y,
        :lng => [wx, wy].max, :crs => [wx, wy].min }
    end
    fit = info.select { |t| len <= t[:lng] - 2 * SL_EDGE_CLEAR }
              .sort_by { |t| [-t[:crs].round(3), t[:i]] }
    if fit.empty?
      longest = info.map { |t| t[:lng] }.max.round(1)
      return { :error => "a #{len.round(1)} in fixture fits longwise on none of the " \
                         "#{rects.length} ceiling tile(s) (longest #{longest} in, less " \
                         "#{SL_EDGE_CLEAR} in at each end)" }
    end
    per = Hash.new(0)
    count.times { |j| per[fit[j % fit.length][:i]] += 1 }
    lights = []
    info.each do |t|
      k = per[t[:i]]
      next if k.zero?
      x0, y0, x1, y1 = t[:box]
      k.times do |j|
        c = if t[:long] == :x
              [(x0 + x1) / 2.0, y0 + (j + 0.5) * (y1 - y0) / k]
            else
              [x0 + (j + 0.5) * (x1 - x0) / k, (y0 + y1) / 2.0]
            end
        lights << { :centre => c, :orient => t[:long], :tile => t[:i] }
      end
    end
    { :lights => lights,
      :how => 'longwise on its ceiling tile, inside one tile, widest tiles first' }
  end

  # Move each fixture of a sl_tile_layout off the keep-outs (1.84.0) — the
  # roof-unit rods, or anything else wr-overlays measured hanging below the
  # ceiling inside a tile rectangle. Never across a seam: a fixture only moves
  # INSIDE its own tile, so 1.83.0's rule (longwise, one tile) still holds.
  #
  #   lights    sl_tile_layout's :lights (not modified; copies come back)
  #   len, wid  the fixture's measured length and width
  #   rects     the same tile rectangles the layout was made on
  #   keepouts  [[x0, y0, x1, y1], ...] plan boxes, booth coordinates
  #
  # A fixture already clear stays exactly where the layout put it. One that
  # is not tries every position that just clears an obstacle — slid ACROSS
  # its tile, or ALONG it (still SL_EDGE_CLEAR from each tile end) — and
  # takes the smallest move that stays inside the tile and clears every
  # keep-out and every fixture already settled. Fixtures settle in layout
  # order. Each light comes back with :moved (the plan distance, 0.0 when
  # it did not move) and :blocked (true when no clear position exists in
  # its tile — it is then left where the layout put it, for the caller to
  # report by name; nothing is ever placed on a rod silently).
  def self.sl_clear_keepouts(lights, len, wid, rects, keepouts)
    c = SL_KEEP_CLEAR
    obs = (keepouts || []).map { |k| k.map { |v| v * 1.0 } }
    hits = lambda do |fp, list|
      list.any? do |o|
        fp[0] < o[2] + c - 1e-6 && fp[2] > o[0] - c + 1e-6 &&
          fp[1] < o[3] + c - 1e-6 && fp[3] > o[1] - c + 1e-6
      end
    end
    settled = []
    out = []
    lights.each do |lt|
      r = rects[lt[:tile]].map { |v| v * 1.0 }
      along_x = lt[:orient] == :x
      hx = (along_x ? len : wid) / 2.0
      hy = (along_x ? wid : len) / 2.0
      fp_at = lambda { |x, y| [x - hx, y - hy, x + hx, y + hy] }
      cx, cy = lt[:centre].map { |v| v * 1.0 }
      others = obs + settled
      best = nil
      if hits.call(fp_at.call(cx, cy), others)
        # The x and y bounds a centre may take, per axis: across the tile it
        # may go edge to edge; along it, SL_EDGE_CLEAR from each end.
        ex = along_x ? SL_EDGE_CLEAR : 0.0
        ey = along_x ? 0.0 : SL_EDGE_CLEAR
        lo_x = r[0] + ex + hx
        hi_x = r[2] - ex - hx
        lo_y = r[1] + ey + hy
        hi_y = r[3] - ey - hy
        xs = [cx]
        ys = [cy]
        others.each do |o|
          xs << o[0] - c - hx << o[2] + c + hx
          ys << o[1] - c - hy << o[3] + c + hy
        end
        cands = []
        xs.each { |x| ys.each { |y| cands << [x, y] } }
        cands.each do |x, y|
          next if x < lo_x - 1e-6 || x > hi_x + 1e-6 || y < lo_y - 1e-6 || y > hi_y + 1e-6
          next if hits.call(fp_at.call(x, y), others)
          d = Math.sqrt((x - cx)**2 + (y - cy)**2)
          best = [d, x, y] if best.nil? || d < best[0] - 1e-9
        end
      end
      if best.nil? && hits.call(fp_at.call(cx, cy), others)
        out << lt.merge(:moved => 0.0, :blocked => true)
        settled << fp_at.call(cx, cy)
      elsif best
        out << lt.merge(:centre => [best[1], best[2]], :moved => best[0], :blocked => false)
        settled << fp_at.call(best[1], best[2])
      else
        out << lt.merge(:moved => 0.0, :blocked => false)
        settled << fp_at.call(cx, cy)
      end
    end
    out
  end

  # The beam series of a model's digits: '84', '96', '102', or nil for a booth
  # smaller than the 84 series. The leading digits are the CEILING CROSS in the
  # BOM's naming (MDL 10284 is a 102 cross, STD10242CL SIDE x 2; MDL 84102 an
  # 84 cross) — so this reads the front of the number, never the back.
  def self.iep_series(d)
    s = d.to_s
    return '102' if s.start_with?('102')
    return '96'  if s.start_with?('96')
    return '84'  if s.start_with?('84')
    nil
  end

  # What IEP beams this booth gets. model is the layout key ('MDL 96120 E'),
  # enh true on an Enhanced booth, rv true when the link says roof-mounted.
  #
  # Returns { :count, :code, :pack, :file, :length, :seal_len, :series, :why,
  #           :source, :derived } when beams belong,
  #      or { :none => reason, :note => true|false } when they do not.
  # :note true means the rule and the BOM DISAGREE and the reason is worth a
  # line of its own in the console (Benton's rule says yes, the BOM says
  # nothing); false is the ordinary "this booth has no beams".
  def self.iep_beam_plan(model, enh, rv)
    if excluded(model)
      return { :none => "#{model} is excluded (MDL 127 LP, Benton) — no IEP beams",
               :note => false }
    end
    d = digits(model)
    series = iep_series(d)
    if series.nil?
      # THE RULE, not a gap: 72-series and smaller carry no beam, Enhanced or
      # roof-mounted (Benton, 12 Oct 2026).
      return { :none => '72-series and smaller carry no IEP beams, Enhanced or ' +
                        'roof-mounted (Benton, 12 Oct 2026)', :note => false }
    end
    unless enh || rv
      return { :none => 'a Standard booth without roof-mounted ventilation (rv = 0)',
               :note => false }
    end
    part = IEP_BEAM_SERIES[series]
    base = { :code => part[:code], :pack => part[:pack], :file => part[:file],
             :length => part[:length],
             :seal_len => series.to_f - IEP_SEAL_INSET, :series => series }
    if series == '84'
      n = IEP_BEAMS_84[d]
      if n.nil?
        return { :none => "#{model} is not in the 84-series beam table — no count to place",
                 :note => true }
      end
      why = if enh && rv then 'Enhanced 84 series (and roof-mounted)'
            elsif enh    then 'Enhanced 84 series'
            else              'roof-mounted (rv = 1) 84 series'
            end
      return base.merge(:count => n, :derived => true, :why => why,
                        :source => "Benton, 12 Oct 2026 (the BOM carries no 84-series " +
                                   "beam). Count = #{model}'s STDSS FLCL7 (D11) quantity " +
                                   "in base-bom.json, one per ceiling seam seal")
    end
    n = IEP_BEAMS_BY_MODEL[d]
    if n.nil?
      return { :none => "#{model} is not in the IEP beam table (base-bom.json) — " \
                        'no count to place', :note => true }
    end
    why = if enh && rv then 'Enhanced, and roof-mounted (rv = 1)'
          elsif enh    then 'Enhanced'
          else              'roof-mounted (rv = 1) Standard booth'
          end
    src = if enh
            "base-bom.json #{model} E row: #{part[:code]} x#{n}"
          else
            "packing-list.js RM rule: one #{part[:code]} per ceiling seal pack, = " \
            "the E row's #{part[:code]} x#{n} in base-bom.json"
          end
    base.merge(:count => n, :derived => false, :why => why, :source => src)
  end
end
