# Walsh corner: step 8 (21 Oct, Benton): reorder the MDL 96168 E sections inside the PLATFORM booth.
#   Before, corner-wall end (x 0) -> open end (x 170): SIDE 48 | CTR 48 | CTR 24 | SIDE 48 (door N3)
#   After:                                             SIDE 48 | CTR 24 | CTR 48 (door N3) | SIDE 48
# Benton: "the 2' section ... is still a center section, but it would be the closest section other than the
# 'side' section" and "the door needs to be shifted one section in". No part is added or removed: the
# 49" door frame keeps its 19" companion beside it (46+22 -> 49+19), so the BOM is unchanged.
#   front (N): N0 46 window | N2 19 | N3 door 49 | N1 46 window   (was N0 | N1 | N2 | N3)
#   back  (S): S0 vent      | S2 22 | S1 vent    | S3 vent        (was S0 | S1 | S2 | S3)
# Platform + ramp (Component#17) follow the door (-48), ramp still toward the open end.
# Interior AP/foam: moved only where the new door or duct covers would land on them; three pieces that have
# no free spot are HIDDEN (never deleted) and tagged with an attribute. Needs an AP re-layout pass.
# $walsh_dry = true prints the plan without changing anything.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
pb = m.find_entity_by_persistent_id(3404973) or raise 'PLATFORM booth (pid 3404973) not found'
raise 'already reordered' if pb.get_attribute('WalshCorner', 'sections') == 'S48|C24|C48door|S48'
d = pb.respond_to?(:definition) ? pb.definition : pb.entities.parent
dry = defined?($walsh_dry) && $walsh_dry
puts "booth #{pb.typename} #{pb.name}; definition instances=#{d.instances.size}; dry=#{!!dry}"
bbx = lambda do |c|
  cd = c.respond_to?(:definition) ? c.definition : c.entities.parent
  b = Geom::BoundingBox.new
  (0..7).each { |i| b.add(cd.bounds.corner(i).transform(c.transformation)) }
  b
end
kids = d.entities.select { |c| c.is_a?(Sketchup::ComponentInstance) || c.is_a?(Sketchup::Group) }
loose = d.entities.reject { |c| c.is_a?(Sketchup::ComponentInstance) || c.is_a?(Sketchup::Group) }
puts "children #{kids.size}, loose entities #{loose.size}: " + loose.group_by(&:typename).map { |k, v| "#{k}=#{v.size}" }.join(', ')
BY_NAME = { 'N1' => 72, 'N1i' => 72, 'N2' => -48, 'N2i' => -48, 'N3' => -48, 'N3i' => -48,
            'N-seal1' => 24, 'N-seal1i' => 24, 'N-seal2' => -48, 'N-seal2i' => -48,
            'S1' => 24, 'S1i' => 24, 'S2' => -48, 'S2i' => -48, 'S-seal1' => -24, 'S-seal1i' => -24 }.freeze
FULL = { 'Studio Light SL52 (2 of 3)' => 24, 'Duct Cover lo  S1i' => 24, 'Duct Cover hi  S1i' => 24,
         'IEP BEAM 8 seam 2' => -24, 'Foam  N1i' => 45 }.freeze
HIDE = ['Audimute2x4 front', 'Audimute2x4 back', 'Foam  S1i'].freeze
plan = []
kids.each do |c|
  b = bbx.(c)
  cx = (b.min.x + b.max.x) / 2.0
  tok = c.name.split(' ').first.to_s
  dn = c.respond_to?(:definition) ? c.definition.name : ''
  dx = nil
  act = :move
  if BY_NAME.key?(tok) then dx = BY_NAME[tok]
  elsif FULL.key?(c.name) then dx = FULL[c.name]
  elsif HIDE.include?(c.name) then act = :hide
  elsif dn == 'Component#17' then dx = -48
  elsif c.layer.name == 'WR-Booth-Deck'
    if dn =~ /STDSS/ then dx = -24 if (cx - 97.0).abs < 2.0
    elsif cx > 50 && cx < 96 then dx = 24
    elsif cx > 98 && cx < 120 then dx = -48
    end
  end
  next unless dx || act == :hide
  plan << [c, act, dx, b]
end
plan.each { |c, a, dx, b| puts format('  %-5s %+4s  %-30s|%-26s x %7.2f..%7.2f -> %7.2f..%7.2f', a, dx.to_s, c.name[0, 30], (c.respond_to?(:definition) ? c.definition.name : '')[0, 26], b.min.x, b.max.x, b.min.x + (dx || 0), b.max.x + (dx || 0)) }
names = plan.map { |c, _, _, _| c.name.split(' ').first }
miss = BY_NAME.keys - names
miss += FULL.keys.reject { |n| plan.any? { |c, _, _, _| c.name == n } }
miss += HIDE.reject { |n| plan.any? { |c, _, _, _| c.name == n } }
miss << 'Component#17' unless plan.any? { |c, _, _, _| c.respond_to?(:definition) && c.definition.name == 'Component#17' }
deck = plan.count { |c, _, _, _| c.layer.name == 'WR-Booth-Deck' }
puts "deck pieces moved #{deck} (expect 4 x CTR48 + 4 x CTR24 + 2 STDSS = 10); missing: #{miss.inspect}"
raise "plan incomplete: #{miss.inspect}" unless miss.empty?
raise "deck count #{deck} != 10" unless deck == 10
raise "duplicate hide matches" unless plan.count { |_, a, _, _| a == :hide } == HIDE.size
# EFS duct extents, for the S1 / S3 overlap check
%w[S1 S3].each do |n|
  c = kids.find { |k| k.name.split(' ').first == n }
  c.definition.entities.each do |e|
    next unless e.respond_to?(:transformation)
    b = Geom::BoundingBox.new
    cd = e.respond_to?(:definition) ? e.definition : e.entities.parent
    (0..7).each { |i| b.add(cd.bounds.corner(i).transform(c.transformation * e.transformation)) }
    puts format('    %s/%-24s x %7.2f..%7.2f y %6.2f..%6.2f z %6.2f..%6.2f', n, (e.name.empty? ? cd.name : e.name)[0, 24], b.min.x, b.max.x, b.min.y, b.max.y, b.min.z, b.max.z)
  end
end
if dry
  puts 'DRY RUN: nothing changed'
else
  m.start_operation('Walsh corner: reorder 96168 sections', true)
  begin
    plan.each do |c, a, dx, _|
      if a == :hide
        c.hidden = true
        c.set_attribute('WalshCorner', 'hidden_by', 's8-sections 21 Oct: no free spot after section reorder; AP re-layout needed')
      else
        c.transform!(Geom::Transformation.translation(Geom::Vector3d.new(dx, 0, 0)))
      end
    end
    pb.set_attribute('WalshCorner', 'sections', 'S48|C24|C48door|S48')
    m.commit_operation
  rescue Exception => e
    m.abort_operation
    puts "FAILED: #{e.class}: #{e.message}"
    raise
  end
  WalshCorner.save(m)
  %w[N0 N2 N3 N1 N3i S0 S2 S1 S3].each do |n|
    c = kids.find { |k| k.name.split(' ').first == n }
    b = bbx.(c)
    puts format('  now %-4s x %7.2f..%7.2f', n, b.min.x, b.max.x)
  end
  puts "saved #{m.path}"
end
nil
