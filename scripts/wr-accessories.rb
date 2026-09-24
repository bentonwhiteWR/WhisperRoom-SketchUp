# wr-accessories.rb — the quote accessories a booth-builder link can carry:
# studio lights (sl), HEPA filters (hp) and bass traps (bt). Which part, how
# many, and the plan for where each goes.
#
# NOT A COMMAND. A library, `load`ed by booth-from-link.rb (to print the plan
# before the build) and build-booth-components.rb (for wr-overlays, which does
# the placing), and in wr_tools' SKIP so it never appears in the panel.
# NOTHING HERE TOUCHES THE SKETCHUP API, so scripts/rbtest-accessories.py loads
# the whole file outside SketchUp. Keep it that way: the SketchUp half lives in
# wr-overlays.rb (place_studio_lights / place_hepa / place_bass_traps).
#
# The Audimute acoustic package (ac) is NOT here yet: whether the importer
# stages the kit beside the booth or lays it out on the walls is Benton's
# decision, pending (24 Sep 2026). booth-from-link refuses ac by name until then.
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

  # Plan layout of the fixtures under the ceiling. ASSUMED, not sourced — no
  # drawing or rule was found for where studio lights hang, so this is the
  # simplest even rule: centres spaced evenly along the ceiling's LONG axis at
  # (i + 0.5) / n, centred on the short axis, each fixture laid ACROSS the
  # booth when it clears the ceiling edge by SL_EDGE_CLEAR on both sides, and
  # along it otherwise (a 52 in fixture cannot lie across a 48 in booth).
  SL_EDGE_CLEAR = 6.0
  SL_GAP        = 2.0

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

  # Studio-light plan layout. box = [x0, y0, x1, y1], the ceiling's plan
  # extent in booth coordinates; len = the fixture's measured length.
  # Returns { :orient => :x|:y (the axis the fixture's LENGTH runs on),
  # :centres => [[x, y], ...], :how } or { :error }.
  def self.sl_layout(count, len, box)
    x0, y0, x1, y1 = box.map { |v| v * 1.0 }
    wx = x1 - x0
    wy = y1 - y0
    long = wx >= wy ? :x : :y
    lng  = long == :x ? wx : wy
    crs  = long == :x ? wy : wx
    if count < 1
      return { :error => "a studio-light count of #{count} is not a count" }
    end
    step = lng / count
    centres = (0...count).map do |i|
      a = (long == :x ? x0 : y0) + (i + 0.5) * step
      c = long == :x ? (y0 + y1) / 2.0 : (x0 + x1) / 2.0
      long == :x ? [a, c] : [c, a]
    end
    if len <= crs - 2 * SL_EDGE_CLEAR
      return { :orient => (long == :x ? :y : :x), :centres => centres,
               :how => 'across the booth, spaced evenly along its length' }
    end
    if count * len + (count - 1) * SL_GAP + 2 * SL_EDGE_CLEAR <= lng
      return { :orient => long, :centres => centres,
               :how => 'end to end along the booth (too long to lie across it)' }
    end
    { :error => "#{count} x #{len.round(1)} in of fixture fits neither across " \
                "(#{crs.round(1)} in) nor along (#{lng.round(1)} in) this ceiling" }
  end
end
