# Community Music School -- the light rig, built from the house tool's own V-Ray primitives
# (WR_DropLights.create_light / create_sphere / write_params / kelvin_rgb), NOT a new mechanism.
#
#   $wr_no_autorun = true
#   load '.../cms/room.rb'; load '.../cms/lights.rb'
#   WR_CMS_Lights.place!    # places the new rig, THEN removes the previous one (never by rollback)
#   VERIFY IN A LATER JOB: WR_CMS_Lights.audit (a purge by plugin name runs after the job ends)
#   WR_CMS_Lights.remove!   # erase instances, then reap definitions + V-Ray plugins (tool's reap)
#   WR_CMS_Lights.audit     # every light: plugin present, invisible/intensity as written
#
# WHY NOT A PLAIN WR_DropLights PRESS (tried 22 Sep, observed):
#   * the office rig's panel grid draws NEW ceiling fixtures; Benton: the visible fixtures stay the
#     room's own surface fluorescents, nothing new. A layer switched "off" still places at 0 lm.
#   * its fill scatter placed 0 of 14 spheres here ("nowhere legal" for every row), so the
#     scatter is placed explicitly below, to the same rules (4-5 ft off the booth, irregular
#     angles and heights, every sphere its own output, >= 40 in (FILL_EDGE) off every wall).
#
# LAYERS (every figure = product lumens x 320, the tool's LUMEN_GAIN x CAMERA_GAIN at the factory
# camera EV 14.23 -- see wr-drop-lights.rb UNITS; nothing here writes the camera):
#   1. ROOM FIXTURES -- the four 4-ft fluorescents already in the model (features.rb). Per fixture,
#      the tool's panel lesson (PANEL_VISIBLE_SHARE): a VISIBLE emitter the size of the lens face,
#      just below it, at 8% (so the lens reads as a lamp, not paper white), plus an INVISIBLE one
#      0.5 in below it doing the lighting at 92%. 4,000 lm product per 4-ft fixture, 4000 K.
#   2. DAYLIGHT -- per window, an invisible rectangle in the reveal just inside the glass facing
#      INTO the room (overcast sky, 6500 K), and an invisible one between glass and backdrop facing
#      OUT at the backdrop, so the photo view reads daylit. The backdrops (CMS Backdrop w1/w2) are
#      plain materials 6 in outside Wall A and block the V-Ray sun/sky; that is why this is
#      emitters and not the sun.
#   3. FILL -- 8 invisible spheres, d10 in, in front of the booth's door face (the only side with
#      room: the booth is 18 in off the other three walls).
# EXPOSURE IS UNVERIFIED: no render has been run on this rig (renders held for Benton's go-ahead).
module WR_CMS_Lights
  DICT = 'wr_cms_lights'.freeze
  TAG  = 'WR Lights'.freeze
  GAIN = 320.0

  # [name, x, y, z, product lm, share]  -- fill spheres, world inches. Booth door face at Y 154.7,
  # booth X 18.3-164.3. Standoffs 43-65 in; walls >= 43 in away.
  FILL = [
    ['fill 1', 44.0, 101.0, 82.0, 1240.0],
    ['fill 2', 63.0, 112.0, 26.0, 760.0],
    ['fill 3', 88.0, 96.0, 71.0, 1480.0],
    ['fill 4', 104.0, 108.0, 20.0, 600.0],
    ['fill 5', 121.0, 99.0, 58.0, 1320.0],
    ['fill 6', 139.0, 110.0, 88.0, 1040.0],
    ['fill 7', 74.0, 90.0, 44.0, 960.0],
    ['fill 8', 131.0, 92.0, 33.0, 800.0]
  ].freeze
  FILL_D = 10.0
  FILL_K = 5000   # hero tuning i2 (was 3500): the tool's kelvin_rgb reads warm; the photos are neutral
  FIX_LM = 4000.0
  FIX_K  = 5000   # hero tuning i2 (was 4000)
  VIS_SHARE = 0.08
  DAY_IN_LM  = 9000.0
  DAY_OUT_LM = 3000.0   # Benton, 22 Sep: halved (was 6000) so the window backdrop detail reads, not blown
  DAY_K = 6500
  WALLC_LM = 3000.0   # hero tuning i4

  def self.model; Sketchup.active_model; end
  def self.ctx; VRay::Context.active; end

  # Lights stand at TOP LEVEL, as the tool's fill spheres do: a nested emitter lighting the render is
  # something wr-drop-lights itself says only a render can prove.
  def self.mine
    [nil, model.entities.select { |e| e.valid? && e.respond_to?(:definition) && e.get_attribute(DICT, 'plugin') }]
  end

  def self.remove!
    g, lights = mine
    pend = lights.map { |e| [e.get_attribute(DICT, 'plugin').to_s, e.definition] }
    model.start_operation('CMS: remove lights', true)
    model.entities.erase_entities(lights) unless lights.empty?
    model.commit_operation
    gone, left = WR_DropLights.reap_lights(model, ctx.scene, pend)
    { 'erased' => lights.size, 'plugins_deleted' => gone, 'plugins_left' => left }
  end

  def self.write!(plug, invisible, lm, kelvin)
    rgb = WR_DropLights.kelvin_rgb(kelvin)
    # EVERY rig light is camera-invisible AND out of reflections (Benton, 22 Sep: "these lights need to be
    # transparent" -- the lens rectangles showed on the ceiling and invisible lights showed as discs in the
    # window glass). The `invisible` argument is kept for the stamp, but the write is always true.
    wants = [[:invisible, true], [:affectReflections, false], [:units, WR_DropLights::UNITS_LUMENS],
             [:intensity, lm * GAIN], [:color, VRay::Color.new(*rgb)]]
    errs = WR_DropLights.write_params(ctx.scene, plug, wants)
    bad = wants.reject { |k, v| WR_DropLights.read_param(plug, k, v, errs[k])[0] }.map(&:first)
    bad
  end

  def self.add(ents, kind, name, tr, invisible, lm, kelvin, size)
    d, plug = kind == :sphere ? WR_DropLights.create_sphere(ctx, size[0] / 2.0) :
                                WR_DropLights.create_light(ctx, size[0], size[1])
    bad = write!(plug, invisible, lm, kelvin)
    i = ents.add_instance(d, tr)
    i.layer = model.layers[TAG] || model.layers.add(TAG)
    pn = WR_DropLights.plugin_name(plug)
    { 'name' => name, 'plugin' => pn, 'invisible' => invisible, 'lm_product' => lm.round,
      'written' => (lm * GAIN).round, 'kelvin' => kelvin, 'bad' => bad }.tap do |r|
      r.each { |k, v| i.set_attribute(DICT, k, v.is_a?(Array) ? v.join(',') : v) }
    end
  end

  def self.place!
    raise 'no V-Ray light API' unless defined?(VRay::Command) && VRay::Command.respond_to?(:create_rectangle_light)
    # PLACE FIRST, REAP LAST (wr-drop-lights "THE SECOND-PRESS KILL", observed here too on 22 Sep:
    # removing the old lights first freed their plugin names, the new lights inherited them, and V-Ray's
    # deferred purge by name then killed all 20 new plugins -- after an in-job audit had passed).
    _, old = mine
    old_pend = old.map { |x| [x.get_attribute(DICT, 'plugin').to_s, x.definition] }
    rep = {}
    l, w, h, = WR_CMS.dims
    tag = model.layers[TAG] || model.layers.add(TAG)
    tag.visible = true
    rows = []
    model.start_operation('CMS: lights', true)
    e = model.entities
    z0 = h - 4.4
    # 1. room fixtures -- lens-face sized emitters (features.rb ceiling_fixtures! geometry)
    fx = []
    [[38.5, 87.0], [87.0, 135.5]].each { |a, b| fx << ['run 1 wraparound', a + 0.6, b - 0.6, 68.8, 78.2, z0] }
    [[41.5, 90.0], [90.0, 138.5]].each { |a, b| fx << ['run 2 louvered', a + 0.6, b - 0.6, 202.6, 211.9, h - 1.25] }
    fx.each_with_index do |(nm, xa, xb, ya, yb, zb), i|
      c = [(xa + xb) / 2.0, (ya + yb) / 2.0]
      sz = [xb - xa - 0.2, yb - ya - 0.2]   # create_rectangle_light width -> local X, height -> local Y
      # (was a VISIBLE lens emitter; Benton 22 Sep: the fixture's own geometry is the visible fixture,
      # so this emitter is now camera-invisible like every other rig light -- same output, same place)
      rows << add(e, :rect, "#{nm} #{i} lens (visible)", Geom::Transformation.translation([c[0], c[1], zb - 0.05]),
                  true, FIX_LM * VIS_SHARE, FIX_K, sz)
      rows << add(e, :rect, "#{nm} #{i} emitter", Geom::Transformation.translation([c[0], c[1], zb - 0.55]),
                  true, FIX_LM * (1.0 - VIS_SHARE), FIX_K, sz)
    end
    # 2. daylight per window (features.rb WIN / REVEAL; glass plane at X = W + REVEAL + 1)
    WR_CMS::WIN.each do |wi|
      yc = (wi[:y0] + wi[:y1]) / 2.0
      zc = (wi[:sill] + wi[:head]) / 2.0
      wy = wi[:y1] - wi[:y0] - 4.0
      hz = wi[:head] - wi[:sill] - 4.0
      # default emitter faces -Z; +90 deg about Y turns it to face -X (into the room). Local X
      # (the width argument) then runs vertical, local Y along the wall.
      into = Geom::Transformation.translation([w + WR_CMS::REVEAL - 1.5, yc, zc]) *   # clear of the sash lock (W+14.8)
             Geom::Transformation.rotation(ORIGIN, Y_AXIS, 90.degrees)
      rows << add(e, :rect, "daylight #{wi[:key]} (into room)", into, true, DAY_IN_LM, DAY_K, [hz, wy])
      out = Geom::Transformation.translation([w + WR_CMS::REVEAL + 3.0, yc, zc]) *
            Geom::Transformation.rotation(ORIGIN, Y_AXIS, -90.degrees)
      rows << add(e, :rect, "daylight #{wi[:key]} (on backdrop)", out, true, DAY_OUT_LM, DAY_K, [hz, wy])
    end
    # 4. WALL C BOUNCE STAND-IN (hero tuning i4). AUTO-SET hides Wall C for every camera that stands
    # behind it; with the wall gone the booth's west end loses the room light the wall would bounce onto it
    # (and the sun, which cannot reach this room, is off). An invisible panel INSIDE the wall's own
    # thickness (X -2, the wall is X -4..0) facing +X: sealed in the solid when the wall is shown, the
    # wall's bounce when it is hidden. Behind the booth zone only, Y 130-265, Z 8-112.
    wc = Geom::Transformation.translation([-2.0, 197.5, 60.0]) * Geom::Transformation.rotation(ORIGIN, Y_AXIS, -90.degrees)
    rows << add(e, :rect, 'wall C bounce stand-in', wc, true, WALLC_LM, FIX_K, [104.0, 135.0])
    # 3. fill spheres
    FILL.each do |nm, x, y, z, lm|
      rows << add(e, :sphere, nm, Geom::Transformation.translation([x, y, z]), true, lm, FILL_K, [FILL_D])
    end
    model.commit_operation
    unless old.empty?
      model.start_operation('CMS: remove replaced lights', true)
      model.entities.erase_entities(old.select(&:valid?))
      model.commit_operation
    end
    gone, left = WR_DropLights.reap_lights(model, ctx.scene, old_pend)
    rep['replaced'] = { 'erased' => old.size, 'plugins_deleted' => gone, 'plugins_left' => left }
    WR_DropLights.stamp_tag_into_pages(model, tag) rescue nil
    rep.merge('placed' => rows.size, 'bad' => rows.reject { |r| r['bad'].empty? }, 'rows' => rows.map { |r| r.values_at('name', 'invisible', 'lm_product', 'written') })
  end

  def self.audit
    _, lights = mine
    sc = ctx.scene
    lights.map do |i|
      pn = i.get_attribute(DICT, 'plugin').to_s
      p = (sc[pn] rescue nil)
      [i.get_attribute(DICT, 'name'), pn, !p.nil?, p && (p[:invisible] rescue nil), p && (p[:intensity] rescue nil).to_f.round,
       i.get_attribute(DICT, 'written'), i.transformation.origin.to_a.map { |v| v.to_f.round(1) }]
    end
  end
end
