# Phase B edit job: apply one wall of layout-v8.json (slots from b-plan.json). Set $b8_wall first.
# One undoable operation per wall; any exception or failed self-check aborts it. Never groups, never saves.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/b-lib.rb'
WALL8 = $b8_wall
raise "set $b8_wall to S/E/W/N (got #{WALL8.inspect})" unless %w[S E W N].include?(WALL8)
m = B8.model!
b = B8.booth(m)
plan = JSON.parse(File.read(B8::DIR + '/b-plan.json'))
slots = plan['jobs'][WALL8]
fixed = plan['fixed']
all = B8.pieces(b)
bypid = all.map { |e| [e.persistent_id, e] }.to_h
foam_src = bypid[3325139] or raise 'reference Foam instance (S0i) not found'
raise 'Foam definition mismatch' unless foam_src.definition.name == 'Foam'
slots.each { |s| raise "slot #{s['id']}: pid #{s['pid']} not in the booth" unless s['pid'] == 'new' || bypid[s['pid']] }
hidden_before = b.entities.select(&:hidden?).map(&:persistent_id).sort
raise 'a foam/Audimute piece is already hidden' if all.any?(&:hidden?)

log = []
m.start_operation("Walsh AP v8: #{WALL8} wall", true)
begin
  # 1. seats by ray with every foam/Audimute piece hidden (a flush piece's back is coplanar with the
  #    wall face, so stepping through pieces would also step past the face). Unhidden again below.
  all.each { |e| e.hidden = true }
  seats = {}
  slots.each do |s|
    r = B8.seat(m, b, s['wall'], s['s0'], s['s1'], s['z0'], s['z1'], [])
    raise "#{s['id']}: seat #{r[:seat].round(4)} is #{r[:proud_off].round(3)} off the nominal face" unless r[:proud_off].between?(-0.03, 0.15)
    raise "#{s['id']}: #{r[:misses]} rays missed" if r[:misses] > 0
    seats[s['id']] = r
  end
  placed = {}
  slots.each do |s|
    w = s['wall']; f = B8::FR[w]
    inst = s['pid'] == 'new' ? nil : bypid[s['pid']]
    defn = inst ? inst.definition : foam_src.definition
    raise "#{s['id']}: definition #{defn.name} is not #{s['part']}" unless defn.name == s['part']
    xa, ya, za = B8.axes(s['part'], s['orient'], w)
    rot = Geom::Transformation.axes(ORIGIN, xa, ya, za)
    lo, hi = B8.body_local(defn)
    pts = [lo[0], hi[0]].product([lo[1], hi[1]], [lo[2], hi[2]]).map { |a, c, d| Geom::Point3d.new(a, c, d).transform(rot) }
    bp, _ = B8.back_and_front(defn)
    v = [0.0, 0.0, 0.0]
    v[f[:s]] = s['s0'] - pts.map { |p| B8.coord(p, f[:s]) }.min
    v[2] = s['z0'] - pts.map { |p| p.z.to_f }.min
    v[f[:d]] = seats[s['id']][:seat] - B8.coord(bp.transform(rot), f[:d])
    t = Geom::Transformation.translation(Geom::Vector3d.new(*v)) * rot
    old = inst ? inst.name : nil
    if inst
      inst.transformation = t
    else
      inst = b.entities.add_instance(defn, t)
      inst.layer = foam_src.layer
      inst.hidden = true
    end
    inst.name = s['name']
    inst.set_attribute('wr_walsh', 'wall', w) if s['part'] =~ /\AAudimute/
    inst.set_attribute('wr_walsh', 'v8_slot', s['id'])
    placed[s['id']] = inst
    log << [s['id'], inst.persistent_id, old, s['name']]
  end

  # 2. self-check before committing (seat re-check still with every piece hidden)
  fails = []
  report = {}
  recheck = {}
  placed.each do |sid, inst|
    s = slots.find { |x| x['id'] == sid }; mm = B8.measure(inst, s['wall'])
    recheck[sid] = B8.seat(m, b, s['wall'], mm[:s0], mm[:s1], mm[:z0], mm[:z1], [])
  end
  B8.pieces(b).each { |e| e.hidden = false }
  placed.each do |sid, inst|
    s = slots.find { |x| x['id'] == sid }; w = s['wall']
    mm = B8.measure(inst, w)
    dpos = [mm[:s0] - s['s0'], mm[:s1] - s['s1'], mm[:z0] - s['z0'], mm[:z1] - s['z1']].map(&:abs).max
    dseat = (mm[:back] - seats[sid][:seat]).abs
    front_ok = mm[:front].dot(B8.nvec(w)) > 0.9999
    re = recheck[sid]
    air = (mm[:back] - re[:seat]) * B8::FR[w][:n]          # + = floating in front of the most proud face
    fails << "#{sid} position off by #{dpos.round(4)}" if dpos > 0.02
    fails << "#{sid} back #{dseat.round(4)} off its seat" if dseat > 0.005
    fails << "#{sid} fabric/front does not face the room" unless front_ok
    fails << "#{sid} seat re-check #{air.round(4)}" if air.abs > 0.02
    fails << "#{sid} layer #{inst.layer.name}" unless inst.layer.name == (s['part'] == 'Foam' ? 'WR-Booth-Foam' : 'WR-Booth-Acoustic')
    report[sid] = { 'pid' => inst.persistent_id, 'name' => inst.name, 'dpos' => dpos.round(4), 'seat' => seats[sid][:seat].round(4),
                    'proud_off' => seats[sid][:proud_off].round(4), 'rays' => seats[sid][:rays], 'recheck_air' => air.round(4),
                    'face_lo_hi' => [seats[sid][:lo].round(4), seats[sid][:hi].round(4)], 'hit_parts' => seats[sid][:hit_parts] }
  end
  touched = slots.map { |s| s['wall'] }.uniq
  gaps = {}
  touched.each do |w|
    on = B8.pieces(b).select { |e| B8.wall_of(e) == w }
    rects = on.map { |e| mm = B8.measure(e, w); [e, [mm[:s0], mm[:s1], mm[:z0], mm[:z1]]] }
    pp = 1e9; pf = 1e9
    rects.combination(2).each { |(a, ra), (c, rc)| g = B8.gap2(ra, rc); pp = [pp, g].min; fails << "#{w}: #{a.name} / #{c.name} gap #{g.round(4)}" if g < B8::G - 1e-4 }
    rects.each do |e, r|
      fixed[w].each { |k| g = B8.gap2(r, k[2, 4]); pf = [pf, g].min; fails << "#{w}: #{e.name} to #{k[1]} gap #{g.round(4)}" if g < B8::G - 1e-4 }
    end
    gaps[w] = { 'pieces' => on.length, 'min_piece' => pp.round(4), 'min_fixed' => pf.round(4) }
  end
  fails << 'hidden state changed' unless b.entities.select(&:hidden?).map(&:persistent_id).sort == hidden_before
  raise "self-check failed: #{fails.join('; ')}" unless fails.empty?
  if $b8_dry then m.abort_operation else m.commit_operation end
rescue Exception => e
  m.abort_operation
  raise e
end
$b8_result = JSON.generate({ 'wall' => WALL8, 'committed' => !$b8_dry, 'moves' => log, 'slots' => report, 'gaps' => gaps, 'modified' => m.modified? })
