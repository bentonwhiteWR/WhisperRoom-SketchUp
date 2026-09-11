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
# THIS DOES NOT MASK THE FAULT AND MUST NOT. It re-writes ONLY the intensity
# the rig itself already stamped on the instance (`lumens`), names every
# light it touched, and then hands back to `audit_scene`, which is still the
# only thing that can clear a frame to be rendered. If the repair does not
# take, the audit still fails and the cycle is still void.
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
walk = nil
walk = lambda do |ents, depth|
  next if depth > WR_DropLights::SWEEP_MAX_DEPTH
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    p = e.get_attribute(WR_DropLights::DICT, 'plugin').to_s
    lm = e.get_attribute(WR_DropLights::DICT, 'lumens')
    want[p] = lm unless p.empty? || lm.nil?
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
  next if got && ((got * 1.0) - (w * 1.0)).abs <= 0.5
  drifted << [pl, n, got, w]
end

puts format('DRIFTED: %d of %d rig lights are not holding what the rig wrote',
            drifted.size, want.size)
fixed = 0
drifted.each do |pl, n, got, w|
  errs = WR_DropLights.write_params(sc, pl, [[:units, WR_DropLights::UNITS_LUMENS],
                                             [:intensity, w * 1.0]])
  now = (pl[:intensity] rescue nil)
  ok = now && ((now * 1.0) - (w * 1.0)).abs <= 0.5
  fixed += 1 if ok
  puts format('  %-22s %s -> %s (wanted %.0f)%s', n, got.inspect, now.inspect,
              w * 1.0, ok ? '' : "  ** DID NOT TAKE #{errs.inspect}")
end
puts format('REPAIRED %d of %d', fixed, drifted.size)

a = DCYC.audit!('post-repair')
{ 'drifted' => drifted.size, 'fixed' => fixed, 'ok' => a['ok'],
  'rig' => a['rig'], 'dead' => a['dead'], 'wrong' => a['wrong'] }
