# Tampa Prep -- EXTERIOR fill rig for the booth (24 Sep 2026). Built from the house tool's own V-Ray
# primitives (WR_DropLights.create_sphere / write_params / read_param / kelvin_rgb / reap_lights), the way
# .forge/builder/cms/lights.rb does. Every light: V-Ray SPHERE, camera-INVISIBLE, affectReflections OFF
# (no discs in the booth glass), top-level instance on its own tag WR_TampaExt::TAG so a scene can hide the
# whole rig by tag (never by object hidden flags -- those are global).
#
#   WR_TampaExt.place!(rows)   rows = [[name, x, y, z, radius, lumens_written, kelvin], ...]  (place only)
#   WR_TampaExt.set!(name, lumens_written, kelvin = nil)     retune in place, no re-create
#   WR_TampaExt.audit           read every rig light's plugin back (run in a LATER job than place!)
#   WR_TampaExt.remove!(names = nil)   erase + reap (never in the same job as a place!)
module WR_TampaExt
  DICT = 'wr_tampa_ext'.freeze
  TAG  = 'WR Exterior Lights'.freeze
  def self.model; Sketchup.active_model; end
  def self.ctx; VRay::Context.active; end

  def self.mine
    model.entities.select { |e| e.valid? && e.respond_to?(:definition) && e.get_attribute(DICT, 'plugin') }
  end

  def self.plug(inst)
    ctx.scene[inst.get_attribute(DICT, 'plugin').to_s]
  end

  def self.wants(lm, kelvin)
    [[:invisible, true], [:affectReflections, false], [:units, WR_DropLights::UNITS_LUMENS],
     [:intensity, lm.to_f], [:color, VRay::Color.new(*WR_DropLights.kelvin_rgb(kelvin))]]
  end

  def self.place!(rows)
    raise 'no V-Ray sphere API' unless VRay::Command.respond_to?(:create_sphere_light)
    tag = model.layers[TAG] || model.layers.add(TAG)
    out = []
    model.start_operation('Tampa: exterior lights', true)
    rows.each do |nm, x, y, z, r, lm, k|
      raise "#{nm} already placed" if mine.any? { |e| e.get_attribute(DICT, 'name') == nm }
      d, pl = WR_DropLights.create_sphere(ctx, r)
      w = wants(lm, k)
      errs = WR_DropLights.write_params(ctx.scene, pl, w)
      bad = w.reject { |kk, v| WR_DropLights.read_param(pl, kk, v, errs[kk])[0] }.map(&:first)
      i = model.entities.add_instance(d, Geom::Transformation.translation([x, y, z]))
      i.layer = tag
      i.name = "WR ext #{nm}"
      { 'name' => nm, 'plugin' => WR_DropLights.plugin_name(pl), 'lm' => lm, 'kelvin' => k, 'r' => r }.each { |kk, v| i.set_attribute(DICT, kk, v) }
      out << { 'name' => nm, 'plugin' => WR_DropLights.plugin_name(pl), 'bad' => bad }
    end
    model.commit_operation
    out
  end

  def self.set!(nm, lm, kelvin = nil)
    i = mine.find { |e| e.get_attribute(DICT, 'name') == nm } or raise "no rig light #{nm}"
    k = kelvin || i.get_attribute(DICT, 'kelvin')
    w = wants(lm, k)
    errs = WR_DropLights.write_params(ctx.scene, plug(i), w)
    i.set_attribute(DICT, 'lm', lm); i.set_attribute(DICT, 'kelvin', k)
    w.reject { |kk, v| WR_DropLights.read_param(plug(i), kk, v, errs[kk])[0] }.map(&:first)
  end

  def self.audit
    mine.map do |i|
      p = plug(i)
      { 'name' => i.get_attribute(DICT, 'name'), 'plugin' => i.get_attribute(DICT, 'plugin'), 'present' => !p.nil?,
        'at' => i.transformation.origin.to_a.map { |v| v.to_f.round(1) }, 'tag' => i.layer.name, 'hidden' => i.hidden?,
        'invisible' => (p && p[:invisible]), 'affectReflections' => (p && p[:affectReflections]),
        'intensity' => (p && p[:intensity]), 'units' => (p && p[:units]), 'radius' => (p && p[:radius]),
        'color' => (p && p[:color] && [p[:color].r, p[:color].g, p[:color].b].map { |x| x.round(3) }) }
    end
  end

  def self.remove!(names = nil)
    ls = mine.select { |e| names.nil? || names.include?(e.get_attribute(DICT, 'name')) }
    pend = ls.map { |e| [e.get_attribute(DICT, 'plugin').to_s, e.definition] }
    model.start_operation('Tampa: remove exterior lights', true)
    model.entities.erase_entities(ls) unless ls.empty?
    model.commit_operation
    gone, left = WR_DropLights.reap_lights(model, ctx.scene, pend)
    { 'erased' => ls.size, 'plugins_deleted' => gone, 'plugins_left' => left }
  end
end
