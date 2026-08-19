# @title Probe V-Ray API...
# @shelf dev
# @cat Tidy up the model
#
# probe-vray.rb — find out what the V-Ray Ruby API actually offers in THIS
# SketchUp, in this session, on this licence.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-vray.rb"
#
# READ-ONLY. It renders nothing, changes nothing, and saves nothing. Every call
# it makes is a query, each one individually rescued, so a method that does not
# exist in this build reports as missing instead of stopping the probe.
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS
#
# V-Ray ships a full YARD-documented Ruby API — see reference/vray-ruby-api.md
# and the docs at
#   C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\
#
# But the implementation is compiled into vray.so, the docs describe signatures
# rather than behaviour, and nothing in this repo has ever called it. Writing a
# batch-render tool against a documented-but-unverified API is how you end up
# debugging someone else's binary. So: ask the live object what it can do, and
# design against the answer.
#
# THE QUESTION THIS EXISTS TO ANSWER FIRST is whether VRay::Context.active is
# non-nil in a normal session, or only after V-Ray has been activated by
# rendering once. Everything about a batch script depends on that.
#
module WR_ProbeVRay

  def self.line(c = '-')
    puts(c * 74)
  end

  def self.try(label)
    v = yield
    puts format('  %-34s %s', label, v.inspect[0, 110])
  rescue Exception => e
    puts format('  %-34s !! %s: %s', label, e.class, e.message.to_s[0, 70])
  end

  def self.methods_of(obj, label)
    m = (obj.methods - Object.instance_methods).sort
    puts "  #{label} — #{m.length} method(s)"
    m.each_slice(4) { |row| puts '      ' + row.map(&:to_s).join(', ') }
  rescue Exception => e
    puts "  #{label} — could not list: #{e.class}"
  end

  def self.run
    puts ''
    line('=')
    puts 'V-RAY RUBY API PROBE — read-only'
    line('=')

    unless defined?(VRay)
      puts '  VRay is NOT DEFINED in this session.'
      puts '  Either V-Ray is not installed, or its extension has not loaded yet.'
      puts '  Check Extensions > Extension Manager, then re-run.'
      line('=')
      puts ''
      return
    end

    puts "  VRay module         defined"
    try('VRay.constants') { VRay.constants.sort.first(24) }

    # THE ONE THAT DECIDES THE DESIGN. If this is nil until someone has
    # rendered once by hand, a batch script cannot start cold and has to say so
    # rather than failing halfway through a client's pack.
    line
    puts 'THE QUESTION: is there an active context, cold?'
    ctx = nil
    try('VRay::Context.active') { ctx = (VRay::Context.active rescue nil); ctx.class }
    if ctx.nil?
      puts ''
      puts '  *** NO ACTIVE CONTEXT. This is the important result.'
      puts '  *** Render one frame by hand, then run this probe again. If the'
      puts '  *** context appears only after that, a batch tool must either'
      puts '  *** trigger activation itself or refuse to start and say why.'
      line('=')
      puts ''
      return
    end

    line
    puts 'CONTEXT'
    try('context.model')    { ctx.model.class }
    try('model.title')      { ctx.model.title }
    try('context.scene')    { ctx.scene.class }
    try('context.renderer') { ctx.renderer.class }

    scene = (ctx.scene rescue nil)
    rend  = (ctx.renderer rescue nil)

    if rend
      line
      puts 'RENDERER — the state a batch tool would read before starting'
      try('render_mode')        { rend.render_mode }
      try('state')              { rend.state }
      try('in_process?')        { rend.in_process? }
      try('vfb_visible?')       { rend.vfb_visible? }
      try('sequence_ended?')    { rend.sequence_ended? }
      try('thread_count')       { rend.thread_count }
      try('dr_enabled?')        { rend.dr_enabled? }
      try('get_compute_devices'){ rend.get_compute_devices }
      try('vfb_settings')       { rend.vfb_settings }
      # Which of the methods the docs list are REALLY here. respond_to? is the
      # honest check — the docs describe a build, not this build.
      want = %i[start stop wait export image save_vfb_image denoise
                set_denoiser_options show_vfb hide_vfb apply_settings_vfb
                subscribe unsubscribe load dump]
      have = want.select { |m| rend.respond_to?(m) rescue false }
      puts ''
      puts "  present: #{have.join(', ')}"
      miss = want - have
      puts "  MISSING: #{miss.join(', ')}" unless miss.empty?
      methods_of(rend, 'renderer, everything')
    end

    if scene
      line
      puts 'SCENE'
      try('scene.id') { scene.id }
      n = 0
      begin
        scene.each { |_p| n += 1 }
        puts format('  %-34s %d', 'plugins in the scene', n)
      rescue Exception => e
        puts "  could not walk the scene: #{e.class}: #{e.message}"
      end
      begin
        names = []
        scene.each { |p| names << (p.name rescue nil) }
        names.compact!
        puts '  first few plugin names:'
        names.first(10).each { |x| puts "      #{x}" }
      rescue Exception
        nil
      end
      methods_of(scene, 'scene, everything')
    end

    line('=')
    puts 'Nothing was rendered, changed or saved. See reference/vray-ruby-api.md'
    puts 'for the open questions this is meant to narrow.'
    line('=')
    puts ''
  rescue Exception => e
    puts "PROBE FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
  end
end

WR_ProbeVRay.run unless $wr_no_autorun
