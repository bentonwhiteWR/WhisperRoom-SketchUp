# @title Dimension WhisperRoom...
# @cat Room tools
# @ability Dimensioned booth
# @ability-blurb Select a booth: it works out which model, dimensions it and labels it. Switch off to remove.
# @setting height  choice  Auto|Standard|Enhanced  Panel height
# @setting vents   text    auto         Vented faces: auto, none, or e.g. "N E"
# @setting gap     number  24           Standoff (in)
# @on  WR_DimensionBooth.ability_on(opts)
# @off WR_DimensionBooth.ability_off(opts)
#
# Select a WhisperRoom. It works out WHICH model it is, dimensions it to the
# catalogue figures, and labels the drawing with the model name.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dimension-booth.rb"
#
# THERE IS NO BOOTH DROPDOWN, AND THAT IS THE POINT. A dropdown is a second
# place for the answer to live, and the two drift apart the moment a booth is
# rebuilt as a different model — you would get a 96144's numbers on a 96120 and
# nothing on screen would say so. The model in front of you is the only source.
#
# WHY NOT JUST MEASURE THE BOOTH — dimension-selection.rb already does that
#
# Because the answer would be wrong, and wrong in a way that looks right. A
# built booth's bounding box also contains the door leaf modelled standing open,
# a VSS silencer stack, a condensate pan hanging below the floor and any ADA
# ramp. A 96120 measures 10' 8 7/16" x 9' 11 1/2" that way against a catalogue
# 10' 7 1/2" x 8' 7 1/2" — that is not a rounding difference, and it would go in
# front of a customer.
#
# So the model IDENTIFIES the booth and wr-booth-data.rb supplies the size.
#
# ============================================================================
# THE THREE NUMBERS
#
# 1. FOOTPRINT is the exterior in wr-booth-data.rb — :w across X, :h across Y.
#    An MDL 7296 S is 98 x 74, which is 8'2" x 6'2".
#
# 2. A VENTED FACE ADDS 5.5 IN TO THE DIMENSION ON ITS OWN AXIS. Benton, and it
#    checks out twice over:
#
#      7296  vents on N only     ->  8'2" x 6'7 1/2"
#      96120 vents on N and E    -> 10'7 1/2" x 8'7 1/2"
#
#    The second is read straight off Benton's own dimensioned render, drawn
#    before this script existed. Two independent confirmations of one rule.
#
#    Note it is PER FACE, not per vent. The 7296 carries two vent sets and both
#    sit on N, so N projects once and the booth gains 5.5 in, not 11.
#
# 3. HEIGHT is the panel height, not anything measured:
#
#      Standard   6'11"        83.0000 in
#      Enhanced   7'-0 5/16"   84.3125 in
#
#    The standard figure is also what the built model comes to, which is a free
#    check rather than a coincidence: floor underside at -1.0, wall 0 to 81,
#    ceiling top at 82.0, and 82.0 - (-1.0) = 83.0.
#
# THE 5.5 IS THE NO-EFS FIGURE. A wall with exterior fan silencers projects
# further and that distance has NOT been measured, so it is a dial here rather
# than a constant — see VENT_PROUD. An EFS booth is reported, not guessed at.
# ============================================================================
#
# Dimensions and the label go in MODEL SPACE on their own tag, WR-Dims-Booth, so
# switching the ability off removes exactly what it drew. Never anything
# hand-drawn, and never dimension-selection.rb's — separate tags on purpose,
# because the two answer different questions and you may want both.

require 'sketchup.rb'

module WR_DimensionBooth
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')
  TAG  = 'WR-Dims-Booth'.freeze
  DICT = 'WR_DimBooth'.freeze
  PREF = 'WR_DimensionBooth'.freeze

  # How far a vented face stands proud of the wall, in inches, WITHOUT exterior
  # fan silencers. Benton's figure, confirmed against the 96120 render.
  #
  # A dial rather than a constant because the EFS distance is unmeasured. Do not
  # reuse this number for an EFS booth, and do not reach for the 10 in EFS figure
  # in CLAUDE.md — that is a CLEARANCE to leave around the booth, not the booth's
  # own projection.
  VENT_PROUD = 5.5

  HEIGHTS = { 'Standard' => 83.0, 'Enhanced' => 84.3125 }.freeze

  # Underside of the floor deck in the builder's coordinates, which is where a
  # booth actually meets the host floor. wr-deck.rb places the deck TOP at
  # DECK_TOP_Z = 0.0 and the slab is 1 in, so the underside is -1.0. If
  # DECK_TOP_Z is ever raised to 1.0 — the physically honest alternative noted in
  # that file — this becomes 0.0 in the same commit, or the height dimension will
  # float an inch off the floor.
  BASE_Z = -1.0

  # Dimension Selection's tag. Not ours to erase — it is a different tool
  # answering a different question — but its numbers are a bounding box, so a
  # booth carrying both sets shows two different footprints at once with nothing
  # on screen to say which is which. Counted and called out.
  OTHER_TAG = 'WR-Dims-Selection'.freeze

  DEFAULTS = { 'height' => 'Auto', 'vents' => 'auto', 'gap' => '24' }.freeze

  def self.read_pref(k)
    v = Sketchup.read_default(PREF, k, DEFAULTS[k].to_s).to_s
    v.empty? ? DEFAULTS[k].to_s : v
  rescue Exception
    DEFAULTS[k].to_s
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  # ------------------------------------------------------------------- data --

  def self.booths
    return {} unless File.exist?(DATA)
    load DATA
    WR_BOOTH_DATA::BOOTHS
  rescue Exception => e
    puts "  could not read #{DATA}: #{e.class}: #{e.message}"
    {}
  end

  # =========================================================== identification =
  #
  # WHICH BOOTH IS THIS. Two routes, tried in order, and the console always says
  # which one answered — a size taken off a guess and a size taken off the group
  # name must never look the same in the report.
  #
  #   1. THE GROUP NAME. build-booth-components.rb names its group
  #      "MDL 96120 S (components)", so the key is sitting right there. Exact,
  #      and it is the normal case.
  #
  #   2. THE DECK PART NAMES. Failing that, the floor panels give it away.
  #      wr-deck.rb names each one after its file — STD<cross><along>FL — so
  #      9648 + 9624 + 9648 is 96 across by 120 along, and the exterior is that
  #      plus the 1 in inset per side that the deck runs under.
  #
  #      Every model has a distinct exterior EXCEPT MDL 10284 S and MDL 84102 S,
  #      which are the same 86 x 104 rectangle turned 90 degrees. So the tiling
  #      DIRECTION is measured from where the deck panels actually sit, and if
  #      that cannot separate them both candidates are reported rather than one
  #      being picked.
  #
  # No route means no answer. It says so and stops, because the alternative is
  # putting a plausible model name on a drawing.

  DECK_RE = /\ASTD(\d{2,3})(\d{2})\s*(FL|CL)/i.freeze

  # A Group carries its entities directly; a ComponentInstance keeps them on its
  # definition. Both turn up as a booth.
  def self.inner(inst)
    return inst.entities if inst.is_a?(Sketchup::Group)
    return inst.definition.entities if inst.respond_to?(:definition) && inst.definition
    nil
  rescue StandardError
    nil
  end

  def self.named_children(ents)
    out = []
    return out if ents.nil?
    ents.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      n = (e.name.to_s rescue '')
      out << [n, e] unless n.empty?
    end
    out
  rescue StandardError
    out
  end

  def self.by_name(inst, specs)
    nm = (inst.name.to_s rescue '')
    return nil if nm.empty?
    hit = specs.keys.find { |k| nm.include?(k) }
    return nil if hit.nil?
    [hit, format('the group name, "%s"', nm)]
  end

  def self.by_deck(kids, specs)
    fl = []
    kids.each do |n, e|
      m = DECK_RE.match(n.strip)
      next if m.nil? || m[3].upcase != 'FL'
      b = e.bounds
      next unless b.valid?
      fl << [m[1].to_f, m[2].to_f,
             (b.min.x.to_f + b.max.x.to_f) / 2.0,
             (b.min.y.to_f + b.max.y.to_f) / 2.0]
    end
    return nil if fl.empty?

    cross = fl.map { |f| f[0] }.max
    along = fl.map { |f| f[1] }.inject(0.0) { |a, v| a + v }
    xs = fl.map { |f| f[2] }
    ys = fl.map { |f| f[3] }
    spread_x = xs.max - xs.min
    spread_y = ys.max - ys.min

    # One tile has no spread and therefore no measured direction. Try both ways
    # round and take whichever matches; those models are all unique, so there is
    # nothing to be ambiguous about.
    orders = if (spread_x - spread_y).abs < 1.0
               [[along + 2.0, cross + 2.0], [cross + 2.0, along + 2.0]]
             elsif spread_x > spread_y
               [[along + 2.0, cross + 2.0]]
             else
               [[cross + 2.0, along + 2.0]]
             end

    hits = []
    orders.each do |ex, ey|
      specs.each do |k, s|
        next unless (s[:w].to_f - ex).abs < 0.5 && (s[:h].to_f - ey).abs < 0.5
        hits << k unless hits.include?(k)
      end
    end
    return nil if hits.empty?
    if hits.length > 1
      return [nil, format('the deck reads %g x %g, which fits %s equally — ' \
                          'name the group and run again', cross, along, hits.join(' and '))]
    end
    [hits.first, format('the deck parts: %g across, %g along (%d panel(s))',
                        cross, along, fl.length)]
  end

  def self.identify(inst, specs)
    hit = by_name(inst, specs)
    return hit unless hit.nil?
    by_deck(named_children(inner(inst)), specs)
  end

  # ----------------------------------------------------------------- vents --
  #
  # Read off the PLACED PARTS, not the layout data, because the layout says what
  # kind of slot a wall has and the placed part says what actually went in it.
  # A booth whose vent was moved for a customer is dimensioned as it is, not as
  # the generator would have made it.
  #
  # "46NV" is a blank, not a vent — VNT and Vent both match here, NV does not.
  def self.vents_from_model(kids)
    faces = []
    efs = false
    hx = false
    kids.each do |n, _e|
      hx = true if n =~ /_HX\b/i
      m = /\A([NSEW])\d+\s/.match(n)
      next if m.nil?
      next unless n =~ /v(?:e)?nt/i
      efs = true if n =~ /EFS/i
      faces << m[1] unless faces.include?(m[1])
    end
    [faces.sort, efs, hx]
  end

  # Fallback when the parts are not named per slot: the layout's own VNT slots.
  def self.vents_from_data(spec)
    out = []
    (spec[:parts] || []).each do |p|
      next unless p[:k] == 'panel' && p[:sk] == 'VNT'
      w = p[:id].to_s[0, 1]
      out << w if %w[N S E W].include?(w) && !out.include?(w)
    end
    out.sort
  end

  # ---------------------------------------------------------------- extent --

  def self.extent(spec, faces, proud)
    w = spec[:w].to_f
    h = spec[:h].to_f
    { :x0 => (faces.include?('W') ? -proud : 0.0),
      :x1 => w + (faces.include?('E') ? proud : 0.0),
      :y0 => (faces.include?('S') ? -proud : 0.0),
      :y1 => h + (faces.include?('N') ? proud : 0.0) }
  end

  # ---------------------------------------------------------------- drawing --

  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(238, 98, 22)) rescue nil   # brand orange
    t
  end

  def self.dim(ents, a, b, offset, layer)
    d = ents.add_dimension_linear(a, b, offset)
    d.layer = layer if d
    d
  rescue StandardError => e
    puts "  dimension failed: #{e.class}: #{e.message}"
    nil
  end

  # Placed the way Benton's own render places them: both footprint dimensions on
  # the ground plane running out from the near corner, and the height standing
  # off the left. Consistent placement beats clever placement — you learn where
  # to look, and two booths side by side read the same way.
  def self.draw(model, ext, height, gap, origin, label = nil)
    lay = tag(model)
    ents = model.entities
    g = gap.to_f.abs
    ox = origin.x.to_f
    oy = origin.y.to_f
    oz = origin.z.to_f
    pt = lambda { |x, y, z| Geom::Point3d.new(ox + x, oy + y, oz + z) }

    made = []
    # THE DRAWING SAYS WHICH BOOTH IT IS. Three numbers with no model name on
    # them is how a 96120's dimensions end up quoted for a 96144 — and it is the
    # difference between a drawing and a screenshot.
    unless label.nil? || label.empty?
      t = (ents.add_text(label, pt.call(ext[:x0], ext[:y0], BASE_Z + height + g * 0.5)) rescue nil)
      if t
        (t.layer = lay) rescue nil
        made << t
      end
    end
    # ACROSS X, on the near edge, pushed toward the viewer.
    made << dim(ents, pt.call(ext[:x0], ext[:y0], BASE_Z),
                pt.call(ext[:x1], ext[:y0], BASE_Z),
                Geom::Vector3d.new(0, -g, 0), lay)
    # ACROSS Y, on the right edge, pushed out in +X.
    made << dim(ents, pt.call(ext[:x1], ext[:y0], BASE_Z),
                pt.call(ext[:x1], ext[:y1], BASE_Z),
                Geom::Vector3d.new(g, 0, 0), lay)
    # HEIGHT, up the near-left corner, pushed out in -X so it clears both.
    made << dim(ents, pt.call(ext[:x0], ext[:y0], BASE_Z),
                pt.call(ext[:x0], ext[:y0], BASE_Z + height),
                Geom::Vector3d.new(-g, 0, 0), lay)

    made.compact!
    made.each { |d| d.set_attribute(DICT, 'own', true) rescue nil }
    made
  end

  # Only ever erases what this script drew: on this tag AND carrying the
  # attribute. Either test alone would eventually eat something hand-drawn.
  def self.clear(model)
    doomed = model.entities.to_a.select do |e|
      next false unless e.valid?
      # Text as well as Dimension — the model label is part of what this drew,
      # and switching off has to take the whole drawing or the next booth
      # inherits the last one's name.
      next false unless e.is_a?(Sketchup::Dimension) || e.is_a?(Sketchup::Text)
      (e.layer && e.layer.name == TAG) || e.get_attribute(DICT, 'own', false)
    end
    n = doomed.length
    model.entities.erase_entities(doomed) unless doomed.empty?
    n
  rescue StandardError => e
    puts "  clear failed: #{e.class}: #{e.message}"
    0
  end

  def self.other_dims(model)
    model.entities.to_a.count do |e|
      e.valid? && e.is_a?(Sketchup::Dimension) &&
        e.layer && e.layer.name == OTHER_TAG
    end
  rescue StandardError
    0
  end

  def self.arch(inches)
    Sketchup.format_length(inches.to_f).to_s
  rescue StandardError
    format('%.4f in', inches.to_f)
  end

  # ------------------------------------------------------------------ input --

  def self.ask
    res = UI.inputbox(['Panel height', 'Vented faces', 'Standoff (in)'],
                      [read_pref('height'), read_pref('vents'), read_pref('gap')],
                      ['Auto|Standard|Enhanced', '', ''],
                      'Dimension WhisperRoom')
    return nil unless res
    { 'height' => res[0], 'vents' => res[1], 'gap' => res[2] }
  end

  def self.faces_from(setting, model_faces, data_faces)
    s = setting.to_s.strip
    return (model_faces.empty? ? data_faces : model_faces) if s.empty? || s.downcase == 'auto'
    return [] if s.downcase == 'none'
    s.upcase.scan(/[NSEW]/).uniq.sort
  end

  # ---------------------------------------------------------------- ability --

  def self.settings(opts)
    height = (opts['height'] || opts[:height] || read_pref('height')).to_s
    vents  = (opts['vents']  || opts[:vents]  || read_pref('vents')).to_s
    gap    = (opts['gap']    || opts[:gap]    || read_pref('gap')).to_f
    gap = 24.0 if gap <= 0 || gap > 240
    write_pref('height', height)
    write_pref('vents', vents)
    write_pref('gap', gap.round.to_s)
    [height, vents, gap]
  end

  def self.ability_on(opts = {})
    model = Sketchup.active_model
    return false if model.nil?

    inst = model.selection.to_a.find do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
    if inst.nil?
      UI.messagebox("Select the WhisperRoom first.\n\n" \
                    'It works out which model it is from the group name, or ' \
                    'failing that from the floor panels inside it.')
      return false
    end

    specs = booths
    if specs.empty?
      UI.messagebox("Booth data not found:\n#{DATA}\n\nRun:  python gen-booth.py --all")
      return false
    end

    key, how = identify(inst, specs)
    if key.nil?
      msg = how || 'nothing in it names a model and it has no recognisable floor panels'
      UI.messagebox("Could not tell which WhisperRoom this is.\n\n#{msg}\n\n" \
                    "Nothing was drawn. Rename the group to include the model — " \
                    "\"MDL 96120 S\" — and run it again.")
      puts ''
      puts "DIMENSION WHISPERROOM — could not identify the selection: #{msg}"
      puts ''
      return false
    end
    spec = specs[key]

    height_key, vents, gap = settings(opts)
    kids = named_children(inner(inst))
    model_faces, efs, hx = vents_from_model(kids)
    data_faces = vents_from_data(spec)
    faces = faces_from(vents, model_faces, data_faces)

    # Enhanced booths carry an E on the key; everything in the data today is S.
    auto_h = key.to_s =~ /\sE\z/ ? 'Enhanced' : 'Standard'
    height_key = auto_h if height_key.to_s.downcase == 'auto'
    h = HEIGHTS[height_key] || HEIGHTS['Standard']

    ext = extent(spec, faces, VENT_PROUD)
    origin = (inst.transformation.origin rescue Geom::Point3d.new(0, 0, 0))

    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    dx = ext[:x1] - ext[:x0]
    dy = ext[:y1] - ext[:y0]
    label = format("%s\n%s x %s x %s%s", key, arch(dx), arch(dy), arch(h),
                   faces.empty? ? '' : format("\nvent %s, +%s each",
                                              faces.join(' '), arch(VENT_PROUD)))

    model.start_operation('Dimension WhisperRoom', true)
    begin
      clear(model)                        # never stack two sets on one booth
      made = draw(model, ext, h, gap, origin, label)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Dimension WhisperRoom failed:\n\n#{e.class}: #{e.message}")
      return false
    end
    dims = made.count { |e| e.is_a?(Sketchup::Dimension) }

    puts ''
    puts "DIMENSION WHISPERROOM — #{key}   #{spec[:label]}"
    puts "  identified by #{how}"
    puts format('  exterior      %s x %s   (catalogue, wr-booth-data.rb)',
                arch(spec[:w]), arch(spec[:h]))
    if faces.empty?
      puts '  ventilation   none counted'
    else
      src = if !vents.to_s.strip.empty? && vents.to_s.strip.downcase != 'auto'
              'you asked for these'
            elsif !model_faces.empty?
              'read off the placed parts'
            else
              'read off the layout data'
            end
      puts format('  ventilation   %s  +%s each  (%s)', faces.join(' '), arch(VENT_PROUD), src)
      if !model_faces.empty? && !data_faces.empty? && model_faces != data_faces
        puts format('                the layout data says %s — the parts win, ' \
                    'they are what is built', data_faces.join(' '))
      end
    end
    puts format('  DIMENSIONED   %s across X   x   %s across Y', arch(dx), arch(dy))
    puts format('  HEIGHT        %s   (%s)', arch(h), height_key)
    puts format('  drawn at      %.1f, %.1f  from "%s"',
                origin.x.to_f, origin.y.to_f, (inst.name.to_s rescue ''))
    puts "  #{dims} dimension(s) and a model label on #{TAG}"

    if efs
      puts ''
      puts '  *** EFS PARTS IN THIS BOOTH. The 5 1/2 in projection is the NO-EFS'
      puts '      figure. An exterior fan silencer stands further out and that'
      puts '      distance has never been measured, so the footprint above is'
      puts '      UNDERSTATED. Do not quote it. Measure one and tell me the number.'
    end
    if hx
      puts ''
      puts '  *** HX PARTS IN THIS BOOTH — 91 in panels. The two heights here are'
      puts format('      Standard and Enhanced; %s was used. There is no agreed', height_key)
      puts '      drawing height for an HX build, so check it before quoting.'
    end
    n = other_dims(model)
    if n > 0
      puts ''
      puts format('  *** %d dimension(s) from Dimension Selection are also in this', n)
      puts format('      model, on %s. Those are a BOUNDING BOX — on a built booth', OTHER_TAG)
      puts '      that box holds the open door leaf, a vent housing and any ramp, so'
      puts '      it reads bigger than the booth and disagrees with these. Switch'
      puts '      that ability off before anyone reads the drawing.'
    end
    puts ''
    puts '  These are CATALOGUE figures plus the vent rule. Nothing was measured'
    puts '  off the model except which booth it is.'
    puts ''
    dims == 3
  end

  def self.ability_off(_opts = {})
    model = Sketchup.active_model
    return false if model.nil?
    model.start_operation('Remove booth dimensions', true)
    n = clear(model)
    model.commit_operation
    puts "  removed #{n} dimension(s) and label(s) from #{TAG}"
    true
  end

  # From the list, ask first; from the toggle, ability_on runs with the stored
  # settings. The button and the switch therefore mean the same thing, they just
  # differ on whether you get to change the standoff first.
  def self.run
    cfg = ask
    if cfg.nil?
      puts '  cancelled at the dialog — nothing was drawn.'
      return
    end
    ability_on(cfg)
  end
end

begin
  WR_DimensionBooth.run unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Dimension WhisperRoom failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
