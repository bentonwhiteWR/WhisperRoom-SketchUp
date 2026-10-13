# Phase B verify (no net change): measure every foam/Audimute piece and the live fixed items.
# Seat rays need the pieces hidden (a flush back is coplanar with the wall face), so the hide/unhide runs
# inside an operation that is ABORTED at the end: the model is left exactly as it was.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/b-lib.rb'
m = B8.model!
b = B8.booth(m)
mod_before = m.modified?
hidden_before = b.entities.select(&:hidden?).map(&:persistent_id).sort
top_hidden_before = m.entities.select(&:hidden?).map(&:persistent_id).sort
pcs = B8.pieces(b)
raise 'a foam/Audimute piece is hidden' if pcs.any?(&:hidden?)
out = { 'pieces' => [], 'fixed' => [] }
m.start_operation('Walsh AP v8 verify (aborted, no change)', true)
begin
  pcs.each { |e| e.hidden = true }
  pcs.each do |e|
    w = B8.wall_of(e)
    h = { 'pid' => e.persistent_id, 'name' => e.name, 'def' => e.definition.name, 'layer' => e.layer.name, 'wall' => w,
          'slot' => e.get_attribute('wr_walsh', 'v8_slot'), 'wr_wall' => e.get_attribute('wr_walsh', 'wall') }
    if w && w != '?'
      mm = B8.measure(e, w)
      r = B8.seat(m, b, w, mm[:s0], mm[:s1], mm[:z0], mm[:z1], [])
      h.merge!('rect' => [mm[:s0], mm[:s1], mm[:z0], mm[:z1]].map { |v| v.round(4) }, 'back' => mm[:back].round(4),
               'front_dot' => mm[:front].dot(B8.nvec(w)).round(5), 'seat' => r[:seat].round(4), 'rays' => r[:rays], 'misses' => r[:misses],
               'air' => ((mm[:back] - r[:seat]) * B8::FR[w][:n]).round(4), 'face_lo_hi' => [r[:lo].round(4), r[:hi].round(4)],
               'box3d' => (lambda { lo, hi = B8.body_local(e.definition)
                   pts = [lo[0], hi[0]].product([lo[1], hi[1]], [lo[2], hi[2]]).map { |a, c, d| Geom::Point3d.new(a, c, d).transform(e.transformation) }
                   [pts.map { |p| p.x.to_f }.min, pts.map { |p| p.x.to_f }.max, pts.map { |p| p.y.to_f }.min, pts.map { |p| p.y.to_f }.max,
                    pts.map { |p| p.z.to_f }.min, pts.map { |p| p.z.to_f }.max].map { |v| v.round(4) } }).call)
    end
    out['pieces'] << h
  end
  pcs.each { |e| e.hidden = false }
ensure
  m.abort_operation
end
b.entities.each do |e|
  next unless e.respond_to?(:definition)
  dn = e.definition.name
  next unless dn =~ /Bass Trap|Duct Cover|IEP BEAM|STDSS CL8/
  bb = e.bounds
  out['fixed'] << { 'name' => e.name.empty? ? dn : e.name, 'def' => dn,
                    'box3d' => [bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z].map { |v| v.to_f.round(4) } }
end
out['counts'] = pcs.map { |e| e.definition.name }.tally
out['traps'] = b.entities.count { |e| e.respond_to?(:definition) && e.definition.name == 'Bass Trap' }
out['hidden_unchanged'] = b.entities.select(&:hidden?).map(&:persistent_id).sort == hidden_before &&
                          m.entities.select(&:hidden?).map(&:persistent_id).sort == top_hidden_before
out['hidden_booth'] = hidden_before.length
out['modified_before'] = mod_before
out['modified_after'] = m.modified?
out['scene'] = m.pages.selected_page && m.pages.selected_page.name
out['path'] = m.path
$b8_result = JSON.generate(out)
