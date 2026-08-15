# @title Dimension WhisperRoom...
# @cat Room tools
# @ability Dimensioned booth
# @ability-blurb Catalogue length, width and height for a booth, vents included. Switch off to remove them.
# @setting booth   text    MDL 7296 S   Which model
# @setting height  choice  Standard|Enhanced  Panel height
# @setting vents   text    auto         Vented faces: auto, none, or e.g. "N E"
# @setting gap     number  24           Standoff (in)
# @on  WR_DimensionBooth.ability_on(opts)
# @off WR_DimensionBooth.ability_off(opts)
#
# The three figures that go on a WhisperRoom drawing, taken from the CATALOGUE
# rather than measured off the model.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dimension-booth.rb"
#
# WHY NOT JUST MEASURE THE MODEL — dimension-selection.rb already does that
#
# Because the answer would be wrong, and wrong in a way that looks right. A
# built booth's bounding box also contains the door leaf modelled standing open,
# a VSS silencer stack, a condensate pan hanging below the floor, and an ADA
# ramp reaching five feet out of the frame. None of those are the booth's size.
# A 7296 would come back over ten feet long and the number would go in front of
# a customer.
#
# So this works the other way round: the model NAMES the booth, and the size
# comes from wr-booth-data.rb plus one rule about ventilation. Nothing is
# measured, so nothing stray can get in.
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
#    The second is read straight off Benton's own dimensioned render, which was
#    drawn before this script existed. Two independent confirmations of one
#    rule, so it is not a guess.
#
#    Note it is PER FACE, not per vent. The 7296 carries two vent sets and both
#    sit on N, so N projects once and the booth gains 5.5 in, not 11. A booth
#    vented on opposite faces would gain it at each end.
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
# than a constant — see VENT_PROUD. Do not assume 5.5 covers an EFS booth.
# ============================================================================
#
# Dimensions go in MODEL SPACE on their own tag, WR-Dims-Booth, so switching the
# ability off removes exactly what it drew. Never anything hand-drawn, and never
# the ones dimension-selection.rb made — the two tools have separate tags on
# purpose, because they answer different questions and you may want both.

require 'sketchup.rb'

module WR_DimensionBooth
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')
  TAG  = 'WR-Dims-Booth'.freeze
  DICT = 'WR_DimBooth'.freeze
  PREF = 'WR_DimensionBooth'.freeze

  # How far a vented face stands proud of the wall, in inches, WITHOUT exterior
  # fan silencers. Benton's figure, confirmed against the 96120 render.
  #
  # A dial rather than a constant because the EFS distance is unmeasured. If an
  # EFS booth ever needs dimensioning, measure it and pass it in — do not reuse
  # this number, and do not reach for the 10 in EFS figure in CLAUDE.md, which is
  # a CLEARANCE to leave around the booth and not the booth's own projection.
  VENT_PROUD = 5.5

  # Panel heights. Both are the figures WhisperRoom puts on a drawing.
  HEIGHTS = { 'Standard' => 83.0, 'Enhanced' => 84.3125 }.freeze

  # Underside of the floor deck in the builder's coordinates, which is where a
  # booth actually meets the host floor. wr-deck.rb places the deck TOP at
  # DECK_TOP_Z = 0.0 and the slab is 1 in, so the underside is -1.0. If
  # DECK_TOP_Z is ever raised to 1.0 — the physically honest alternative noted
  # in that file — this becomes 0.0 in the same commit, or the height dimension
  # will float an inch off the floor.
  BASE_Z = -1.0

  DEFAULTS = { 'booth' => 'MDL 7296 S', 'height' => 'Standard',
               'vents' => 'auto', 'gap' => '24' }.freeze

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

  def self.spec_for(key)
    return nil unless File.exist?(DATA)
    load DATA
    WR_BOOTH_DATA::BOOTHS[key]
  rescue Exception => e
    puts "  could not read #{DATA}: #{e.class}: #{e.message}"
    nil
  end

  def self.booth_keys
    return [] unless File.exist?(DATA)
    load DATA
    WR_BOOTH_DATA::BOOTHS.keys.sort_by { |k| [(k[/\d+/] || '0').to_i, k] }
  rescue Exception
    []
  end

  # Which faces carry a vent, read off the layout rather than asked for. A slot's
  # id begins with its wall letter, so N0 being a VNT makes N a vented face.
  def self.vented_faces(spec)
    out = []
    (spec[:parts] || []).each do |p|
      next unless p[:k] == 'panel' && p[:sk] == 'VNT'
      w = p[:id].to_s[0, 1]
      out << w if %w[N S E W].include?(w) && !out.include?(w)
    end
    out.sort
  end

  # ----------------------------------------------------------------- extent --

  # The rectangle to dimension, in the builder's own coordinates: the booth runs
  # 0..w by 0..h and each vented face pushes its own side out by VENT_PROUD.
  def self.extent(spec, faces, proud)
    w = spec[:w].to_f
    h = spec[:h].to_f
    { :x0 => (faces.include?('W') ? -proud : 0.0),
      :x1 => w + (faces.include?('E') ? proud : 0.0),
      :y0 => (faces.include?('S') ? -proud : 0.0),
      :y1 => h + (faces.include?('N') ? proud : 0.0) }
  end

  # Where the booth sits. A selected group or component is taken as the booth and
  # its transformation origin is the datum, so a booth that has been moved gets
  # its dimensions in the right place. With nothing selected the model origin is
  # used, which is where build-booth-components.rb puts one.
  def self.datum(model)
    hit = model.selection.to_a.find do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
    return [Geom::Point3d.new(0, 0, 0), nil] if hit.nil?
    [hit.transformation.origin, hit.name.to_s]
  rescue StandardError
    [Geom::Point3d.new(0, 0, 0), nil]
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
  def self.draw(model, ext, height, gap, origin)
    lay = tag(model)
    ents = model.entities
    g = gap.to_f.abs
    ox = origin.x.to_f
    oy = origin.y.to_f
    oz = origin.z.to_f
    pt = lambda { |x, y, z| Geom::Point3d.new(ox + x, oy + y, oz + z) }

    made = []
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
      next false unless e.is_a?(Sketchup::Dimension)
      (e.layer && e.layer.name == TAG) || e.get_attribute(DICT, 'own', false)
    end
    n = doomed.length
    model.entities.erase_entities(doomed) unless doomed.empty?
    n
  rescue StandardError => e
    puts "  clear failed: #{e.class}: #{e.message}"
    0
  end

  def self.arch(inches)
    Sketchup.format_length(inches.to_f).to_s
  rescue StandardError
    format('%.4f in', inches.to_f)
  end

  # ------------------------------------------------------------------ input --

  def self.ask
    keys = booth_keys
    if keys.empty?
      UI.messagebox("Booth data not found:\n#{DATA}\n\nRun:  python gen-booth.py --all")
      return nil
    end
    last = read_pref('booth')
    last = keys.first unless keys.include?(last)

    res = UI.inputbox(['Booth', 'Height', 'Vented faces', 'Standoff (in)'],
                      [last, read_pref('height'), read_pref('vents'), read_pref('gap')],
                      [keys.join('|'), HEIGHTS.keys.join('|'), '', ''],
                      'Dimension WhisperRoom')
    return nil unless res
    { 'booth' => res[0], 'height' => res[1], 'vents' => res[2], 'gap' => res[3] }
  end

  # 'auto' reads the vents off the layout, 'none' suppresses them, anything else
  # is taken as an explicit face list — "N E", "n,e" and "NE" all work, because a
  # tool that rejects a comma is a tool nobody uses twice.
  def self.faces_from(setting, spec)
    s = setting.to_s.strip
    return vented_faces(spec) if s.empty? || s.downcase == 'auto'
    return [] if s.downcase == 'none'
    s.upcase.scan(/[NSEW]/).uniq.sort
  end

  # ---------------------------------------------------------------- ability --

  def self.settings(opts)
    booth  = (opts['booth']  || opts[:booth]  || read_pref('booth')).to_s
    height = (opts['height'] || opts[:height] || read_pref('height')).to_s
    vents  = (opts['vents']  || opts[:vents]  || read_pref('vents')).to_s
    gap    = (opts['gap']    || opts[:gap]    || read_pref('gap')).to_f
    gap = 24.0 if gap <= 0 || gap > 240
    write_pref('booth', booth)
    write_pref('height', height)
    write_pref('vents', vents)
    write_pref('gap', gap.round.to_s)
    [booth, height, vents, gap]
  end

  def self.ability_on(opts = {})
    model = Sketchup.active_model
    return false if model.nil?
    booth, height_key, vents, gap = settings(opts)

    spec = spec_for(booth)
    if spec.nil?
      UI.messagebox("#{booth} is not in the booth data.")
      return false
    end
    h = HEIGHTS[height_key] || HEIGHTS['Standard']
    faces = faces_from(vents, spec)
    detected = vented_faces(spec)
    ext = extent(spec, faces, VENT_PROUD)
    origin, sel_name = datum(model)

    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    model.start_operation('Dimension WhisperRoom', true)
    begin
      clear(model)                        # never stack two sets on one booth
      made = draw(model, ext, h, gap, origin)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Dimension WhisperRoom failed:\n\n#{e.class}: #{e.message}")
      return false
    end

    dx = ext[:x1] - ext[:x0]
    dy = ext[:y1] - ext[:y0]
    puts ''
    puts "DIMENSION WHISPERROOM — #{booth}   #{spec[:label]}"
    puts format('  exterior      %s x %s   (catalogue, wr-booth-data.rb)',
                arch(spec[:w]), arch(spec[:h]))
    if faces.empty?
      puts '  ventilation   none counted'
    else
      puts format('  ventilation   %s +%s each%s', faces.join(' '), arch(VENT_PROUD),
                  faces == detected ? ' (read off the layout)' : " (you asked for these; the layout says #{detected.join(' ')})")
    end
    puts format('  DIMENSIONED   %s across X   x   %s across Y', arch(dx), arch(dy))
    puts format('  HEIGHT        %s   (%s panels)', arch(h), height_key)
    puts format('  drawn at      %.1f, %.1f%s', origin.x.to_f, origin.y.to_f,
                sel_name.nil? ? ' (model origin — nothing selected)' : " (from \"#{sel_name}\")")
    puts "  #{made.length} dimension(s) on #{TAG}"
    puts ''
    puts '  These are CATALOGUE figures plus the vent rule — nothing was measured'
    puts '  off the model, deliberately, because a built booth\'s bounding box also'
    puts '  holds an open door leaf, a silencer stack and any ramp.'
    puts format('  The %s vent projection is the NO-EFS figure. An EFS wall stands', arch(VENT_PROUD))
    puts '  further out and that distance has never been measured — do not quote'
    puts '  one of these on an EFS booth without checking.'
    puts ''
    made.length == 3
  end

  def self.ability_off(_opts = {})
    model = Sketchup.active_model
    return false if model.nil?
    model.start_operation('Remove booth dimensions', true)
    n = clear(model)
    model.commit_operation
    puts "  removed #{n} dimension(s) from #{TAG}"
    true
  end

  # From the list, ask first; from the toggle, ability_on runs with the stored
  # settings. The button and the switch therefore mean the same thing, they just
  # differ on whether you get to change the model first.
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
