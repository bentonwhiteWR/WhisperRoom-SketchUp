# THE d-SERIES RANK LOOP (11 Sep 2026) — the office rig's cycle harness.
#
# Committed, unlike the c-series harness, which lived in a session scratch
# directory and went with it. Every d-row in
# `Z:\Sketchup\Proposals\test2\.rank\booth-render.scores.md` was produced by
# these three entry points and can be re-run from them.
#
#   d-drop.rb    remove_rig! (VERIFIED) -> drop -> audit_scene
#   d-export.rb  render the one live plate
#   d-audit.rb   re-audit after the render, to prove the frame is the rig
#
# THE LOOP RULE, inherited from
# `.forge/fixer/ROOTCAUSE-key-light-and-2x-2026-09-11.md` and not negotiable:
# reset is `remove_rig!` with plugins_left == 0 and rig_entities == 0, NEVER
# `Sketchup.undo` (V-Ray's scene.change closes the SketchUp operation
# underneath the rig, so an undo leaves the rig standing and the tool's own
# "Ctrl+Z removes the lights" line is untrue). `audit_scene` must return ok
# before the render AND agree after it. A frame whose audit is not ok is void
# and is not scored.
#
# CONFIG. A JSON file at CFG below, written by the operator between cycles, so
# the Ruby is fixed and only the settings move:
#   { "out": "<dir for the export>", "sub": "d00",
#     "rig": "office"|"classic", "mult": 1.0, "koffset": 0,
#     "layers": { "panel": {"on":true,"scale":1.0,"kdelta":0}, ... } }
$wr_no_autorun = true
D_ROOT = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'.freeze
D_CFG  = 'C:/Users/bento/AppData/Local/WhisperRoom/rank-loop-d.json'.freeze
load File.join(D_ROOT, 'proposal-package.rb') unless defined?(WR_ProposalPackage)
load File.join(D_ROOT, 'wr-autoset.rb') unless defined?(WR_AutoSet)
# ALWAYS re-loaded, never guarded on defined?: the whole point of a cycle is
# that the rig code may have changed since the last one, and a guarded load
# silently renders the PREVIOUS version of the rule.
load File.join(D_ROOT, 'wr-drop-lights.rb')
$wr_no_autorun = nil

module DCYC
  def self.cfg
    JSON.parse(File.read(D_CFG))
  end

  def self.model
    Sketchup.active_model
  end

  def self.room
    model.entities.grep(Sketchup::Group).find { |g| g.name == 'Room' }
  end

  def self.booth
    model.entities.grep(Sketchup::Group).find { |g| g.name =~ /MDL/ }
  end

  def self.vray_lights
    sc = VRay::Context.active.scene
    out = []
    sc.each do |pl|
      t = pl.type.to_s
      next unless t =~ /\ALight/ || t == 'SunLight'
      out << [pl.name.to_s, t, (pl[:intensity] rescue nil), (pl[:enabled] rescue nil)]
    end
    out.sort_by { |r| r[0] }
  end

  def self.rig_entities
    n = 0
    walk = nil
    walk = lambda do |ents, d|
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        n += 1 if e.get_attribute(WR_DropLights::DICT, 'role')
        walk.call(e.definition.entities, d + 1) if d < 4
      end
    end
    walk.call(model.entities, 0)
    n
  end

  # THE RESET, and the verification that makes it a reset rather than a hope.
  # A press that leaves ONE rig entity or ONE rig plugin behind stacks the
  # next rig on top of it, and the frame is then two rigs deep with nothing
  # in the model saying so.
  def self.reset!
    r = WR_DropLights.remove_rig!(model)
    puts format('REMOVE: erased=%s plugins_deleted=%s plugins_left=%s ' \
                'ceiling_verified=%s ceilings=%s walls=%s',
                r['erased'], r['plugins_deleted'], r['plugins_left'],
                r['ceiling_verified'], r['ceiling_groups_erased'],
                r['wall_groups_erased'])
    left = r['plugins_left'].to_i
    ents = rig_entities
    vl = vray_lights
    puts format('AFTER REMOVE: v-ray lights=%d (%s), rig_entities=%d',
                vl.length, vl.map { |x| x[0] }.join(', '), ents)
    raise "RESET FAILED: #{left} rig plugins left behind" unless left.zero?
    raise "RESET FAILED: #{ents} rig entities still in the model" unless ents.zero?
    # Two is the booth's own /Standard Light plus the sun. Anything else is
    # a light this harness does not know about and the cycle is not clean.
    raise "RESET FAILED: #{vl.length} lights in the V-Ray scene, expected 2 " \
          "(the booth's own light and the sun): #{vl.inspect}" unless vl.length == 2
    true
  end

  # The settings hash for this cycle: the tool's own defaults with the config
  # file's overrides on top. Written out in full so the console transcript
  # records exactly what was pressed.
  def self.settings
    c = cfg
    st = WR_DropLights.default_settings
    st['rig'] = c['rig'] if c['rig']
    st['mult'] = c['mult'].to_f if c['mult']
    st['koffset'] = c['koffset'].to_i if c['koffset']
    st['ceiling'] = c['ceiling'] unless c['ceiling'].nil?
    st['walls'] = c['walls'] if c['walls']
    (c['layers'] || {}).each do |role, o|
      st['layers'][role] ||= { 'on' => true, 'scale' => 1.0, 'kdelta' => 0 }
      o.each { |k, v| st['layers'][role][k] = v }
    end
    st
  end

  def self.drop!
    st = settings
    puts "SETTINGS: #{st.to_json}"
    WR_DropLights.run(st, [room, booth])
  end

  def self.audit!(when_s)
    a = WR_DropLights.audit_scene(model)
    puts format('AUDIT (%s): ok=%s rig=%s model=%s ghosts=%s dead=%s off=%s ' \
                'wrong=%s missing=%s', when_s, a['ok'], a['rig'], a['model'],
                a['ghosts'].inspect, a['dead'].inspect, a['off'].inspect,
                a['wrong'].inspect, a['missing'].inspect)
    a['lines'].each { |l| puts "   #{l}" }
    a
  end

  def self.export!
    c = cfg
    dir = File.join(c['out'], c['sub'])
    raise 'a batch is already running' if
      WR_ProposalPackage.instance_variable_get(:@running)
    WR_ProposalPackage.start_run(model, nil,
                                 { 'dir' => dir, 'sub' => false, 'force' => true,
                                   'over' => 'Overwrite', 'width' => 800 })
    dir
  end
end
