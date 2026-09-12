# RUN h — THE FLOOR VARIABLE (ruling R8). One floor per cycle, lighting frozen.
#
# WHY THIS FILE EXISTS. Run g changed the render floor by hand from a bridge
# one-liner and the only record of it is prose in the scores file. R8 makes the
# floor the variable of a whole run, so the swap becomes a harness step with the
# same discipline as the drop: it reads its argument from the SAME config file
# the rig reads, it REPORTS what it changed, and it refuses rather than guesses.
#
# CONFIG — two new keys in `rank-loop-d.json`, read here and nowhere else:
#
#   "floor":      "Oak Honey Semigloss 300cm"   the material NAME to end up on
#   "floor_skm":  "Wood/Wood_Floor_12_1K"       optional: load it from SketchUp's
#                                               own Materials library if the model
#                                               does not have it yet
#   "floor_size": 36.0                          optional: texture size in INCHES,
#                                               square. A floor texture at the
#                                               wrong scale is a different floor.
#
# WHAT IT REFUSES TO DO. It does not paint a surface that is not the room's
# floor, it does not invent a material, and it does not proceed if the floor is
# not currently on the fill the model says it is on — that would mean the model
# is in draft mode, or somebody painted it by hand, and either way the "one
# variable per cycle" claim would be false.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-materials-swap.rb'
$wr_no_autorun = nil

module HFLOOR
  SLOT = 'WR-Floor-Render'.freeze
  LIB  = 'C:/ProgramData/SketchUp/SketchUp 2026/SketchUp/Materials'.freeze

  def self.room_floor(model)
    room = model.entities.grep(Sketchup::Group).find { |g| g.name == 'Room' }
    raise 'no Room group' if room.nil?
    f = room.entities.grep(Sketchup::Group).find { |g| g.name == 'Floor' }
    raise 'no Room > Floor group' if f.nil?
    f
  end

  def self.ensure_material(model, name, skm)
    m = model.materials[name]
    return [m, 'already in model'] if m
    raise "material #{name.inspect} is not in the model and no floor_skm was given" if skm.to_s.empty?
    path = File.join(LIB, skm.to_s.sub(/\.skm\z/, '') + '.skm')
    raise "no such .skm: #{path}" unless File.exist?(path)
    loaded = model.materials.load(path)
    raise "load returned nil for #{path}" if loaded.nil?
    # model.materials.load names it after the file; rename to the asked-for name
    # so the fill, the dictionary and the scores row all say one thing.
    loaded.name = name unless loaded.name == name
    [loaded, "loaded from #{path}"]
  end

  def self.apply!
    c = DCYC.cfg
    model = DCYC.model
    want = c['floor'].to_s
    raise 'config has no "floor"' if want.empty?

    was_fill = WR_MaterialsSwap.fill(model, SLOT)
    floor = room_floor(model)
    cur = (floor.material && floor.material.name).to_s
    unless cur == was_fill
      raise "Room > Floor is on #{cur.inspect} but the model's #{SLOT} fill is " \
            "#{was_fill.inspect}. The model is not in render mode, or the floor " \
            'was painted by hand. Not swapping.'
    end
    return { 'changed' => false, 'floor' => want, 'note' => 'already on it' } if cur == want

    mat, how = ensure_material(model, want, c['floor_skm'])
    if c['floor_size'] && mat.texture
      s = c['floor_size'].to_f
      model.start_operation('WR h-floor: texture size', true)
      mat.texture.size = s
      model.commit_operation
    end

    model.start_operation('WR h-floor: swap render floor', true)
    begin
      floor.material = mat
      WR_MaterialsSwap.set_fill(model, SLOT, want)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      raise e
    end

    back = room_floor(model)
    now = (back.material && back.material.name).to_s
    raise "swap did not take: floor is on #{now.inspect}" unless now == want
    raise 'fill did not stick' unless WR_MaterialsSwap.fill(model, SLOT) == want

    col = mat.color
    tex = mat.texture
    puts format('FLOOR: %s -> %s (%s)', was_fill, want, how)
    puts format('  colour rgb(%d,%d,%d)  R/B %.3f  texture %s  size %s x %s in',
                col.red, col.green, col.blue,
                col.blue.zero? ? 0.0 : col.red.to_f / col.blue,
                tex ? File.basename(tex.filename.to_s) : 'NONE',
                tex ? tex.width.to_f.round(2) : '-',
                tex ? tex.height.to_f.round(2) : '-')
    { 'changed' => true, 'was' => was_fill, 'floor' => want, 'how' => how,
      'rgb' => [col.red, col.green, col.blue],
      'tex' => tex ? File.basename(tex.filename.to_s) : nil,
      'tex_in' => tex ? tex.width.to_f.round(2) : nil }
  end
end

HFLOOR.apply!
