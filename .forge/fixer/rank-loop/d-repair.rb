# REPAIR a rig whose V-Ray scene has drifted off what the rig wrote, then
# re-audit. Run ONLY after d-drop.rb reports a failed audit.
#
# WHY THIS EXISTS (observed, 11 Sep 2026, and it is a real V-Ray behaviour,
# not a tool bug). `configure_light` writes every parameter inside one
# `VRay::Scene#change` transaction and reads each one back AFTER the
# transaction closes; on the drop those read-backs all agree. Seconds later,
# in a separate bridge job, `audit_scene` finds one or more lights sitting at
# V-Ray's factory 30 lm. V-Ray re-syncs its scene plugins from the JSON blob
# in each light component DEFINITION's `VRayPlugins` dictionary on its own
# schedule, and that re-sync is what puts them back.
#
# `ROOTCAUSE-key-light-and-2x-2026-09-11.md` finding 6 recorded this as
# intermittent - "one press in three" - on an 18-light rig. On the 56-light
# office rig it is not intermittent: five consecutive drops each left between
# one and four sphere lights at 30. Re-dropping is not a fix; it is a
# lottery.
#
# THIS DOES NOT MASK THE FAULT AND MUST NOT. It re-writes only what the rig
# itself already stamped on the instance, names every light it touched, and
# then hands back to `audit_scene`, which is still the only thing that can
# clear a frame to be rendered. If the repair does not take, the audit still
# fails and the cycle is still void.
#
# IT REWRITES THE WHOLE LIGHT, NOT JUST THE INTENSITY, and that is the
# lesson of rank cycle d05. The first version of this file restored
# `intensity` alone. The re-sync does not revert one parameter -- it puts the
# plugin back to FACTORY, so `invisible` had gone to 0 as well, and the frame
# came back with a bare white BALL floating in the middle of it where a fill
# sphere should have been unseen. `audit_scene` cleared that frame, because
# at the time it only checked intensity and enabled. Both halves are now
# fixed: the audit compares visibility against what the rig wrote (1.67.1),
# and this pass restores every parameter the role specifies.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'

m = DCYC.model
why = WR_DropLights.vray_api_missing
ctx = nil
ctx, why = WR_DropLights.vray_context unless why
raise "no V-Ray: #{why}" if why
sc = WR_DropLights.vray_scene(ctx)
raise 'no V-Ray scene' if sc.nil?

# plugin name -> the lumens the rig stamped on the instance that owns it
want = {}
vis = {}
role = {}
walk = nil
walk = lambda do |ents, depth|
  next if depth > WR_DropLights::SWEEP_MAX_DEPTH
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    p = e.get_attribute(WR_DropLights::DICT, 'plugin').to_s
    lm = e.get_attribute(WR_DropLights::DICT, 'lumens')
    unless p.empty? || lm.nil?
      want[p] = lm
      vis[p] = e.get_attribute(WR_DropLights::DICT, 'invisible')
      role[p] = e.get_attribute(WR_DropLights::DICT, 'role')
    end
    kids = WR_DropLights.child_entities(e)
    walk.call(kids, depth + 1) if kids.respond_to?(:each)
  end
end
walk.call(m.entities, 0)

drifted = []
sc.each do |pl|
  t = (pl.type.to_s rescue '')
  next unless t =~ /\ALight/
  n = pl.name.to_s
  w = want[n]
  next if w.nil?
  got = (pl[:intensity] rescue nil)
  gotv = (pl[:invisible] rescue nil)
  truth = lambda { |v| v == true || v == 1 || v == 1.0 || v.to_s == 'true' || v.to_s == '1' }
  wantv = vis[n]
  bad_i = !(got && ((got * 1.0) - (w * 1.0)).abs <= 0.5)
  bad_v = !wantv.nil? && !gotv.nil? && truth.call(wantv) != truth.call(gotv)
  next unless bad_i || bad_v
  drifted << [pl, n, got, w, gotv, wantv]
end

puts format('DRIFTED: %d of %d rig lights are not holding what the rig wrote',
            drifted.size, want.size)
fixed = 0
truth2 = lambda { |v| v == true || v == 1 || v == 1.0 || v.to_s == 'true' || v.to_s == '1' }
drifted.each do |pl, n, got, w, gotv, wantv|
  spec = WR_DropLights::LIGHT_LAYERS[(role[n] || '').to_sym]
  wants = [[:units, WR_DropLights::UNITS_LUMENS], [:intensity, w * 1.0]]
  wants << [:invisible, truth2.call(wantv)] unless wantv.nil?
  if spec
    kelv = WR_DropLights.layer_kelvin(spec[:kelvin], 0)
    rgbv = WR_DropLights.kelvin_rgb(kelv)
    c = (VRay::Color.new(rgbv[0], rgbv[1], rgbv[2]) rescue nil)
    wants << [:color, c] unless c.nil?
    wants << [:directional, spec[:dir]] unless spec[:dir].nil?
    wants << [:is_disc, 1] if spec[:disc] && spec[:emitter] == :rect
  end
  errs = WR_DropLights.write_params(sc, pl, wants)
  now = (pl[:intensity] rescue nil)
  nowv = (pl[:invisible] rescue nil)
  ok = now && ((now * 1.0) - (w * 1.0)).abs <= 0.5 &&
       (wantv.nil? || nowv.nil? || truth2.call(nowv) == truth2.call(wantv))
  fixed += 1 if ok
  puts format('  %-22s intensity %s -> %s (wanted %.0f), invisible %s -> %s '               '(wanted %s), role %s%s', n, got.inspect, now.inspect, w * 1.0,
              gotv.inspect, nowv.inspect, wantv.inspect, role[n].inspect,
              ok ? '' : "  ** DID NOT TAKE #{errs.inspect}")
end
puts format('REPAIRED %d of %d', fixed, drifted.size)

a = DCYC.audit!('post-repair')
{ 'drifted' => drifted.size, 'fixed' => fixed, 'ok' => a['ok'],
  'rig' => a['rig'], 'dead' => a['dead'], 'wrong' => a['wrong'] }
