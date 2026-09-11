# Cycle helpers for the blocker-2 experiments. Loaded by every job.
$wr_no_autorun = true
CYC_R = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'
load File.join(CYC_R, 'proposal-package.rb') unless defined?(WR_ProposalPackage)
load File.join(CYC_R, 'wr-autoset.rb') unless defined?(WR_AutoSet)
load File.join(CYC_R, 'wr-drop-lights.rb') unless defined?(WR_DropLights)
$wr_no_autorun = nil
module CYC
  OUT = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc'
  def self.model; Sketchup.active_model; end
  def self.room; model.entities.grep(Sketchup::Group).find { |g| g.name == 'Room' }; end
  def self.booth; model.entities.grep(Sketchup::Group).find { |g| g.name =~ /MDL/ }; end
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
  def self.census
    m = model
    { 'pages' => m.pages.map { |p| [p.name, WR_ProposalPackage.mode_of(p)] },
      'top' => m.entities.map { |e| e.respond_to?(:name) ? e.name : e.class.name },
      'vray_lights' => vray_lights, 'rig_entities' => rig_entities,
      'defs' => m.definitions.length, 'mats' => m.materials.length,
      'layers' => m.layers.map(&:name), 'wr_lights_visible' => (m.layers['WR Lights'] ? m.layers['WR Lights'].visible? : nil),
      'mode' => m.get_attribute('WR_Mode', 'mode'), 'running' => WR_ProposalPackage.instance_variable_get(:@running) }
  end
  def self.drop(st = nil)
    st ||= WR_DropLights.default_settings
    WR_DropLights.run(st, [room, booth])
  end
  def self.export(sub)
    dir = File.join(OUT, sub)
    WR_ProposalPackage.start_run(model, nil, { 'dir' => dir, 'sub' => false, 'force' => true, 'over' => 'Overwrite', 'width' => 800 })
    dir
  end
end
