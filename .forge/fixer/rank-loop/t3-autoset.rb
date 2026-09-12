# STEP 1 — AUTO-SET, headless. Replicates the 'autosetapply' action callback
# in proposal-package.rb (line 4737) because there is NO other entry point.
$wr_no_autorun = true
R = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'.freeze
load File.join(R, 'proposal-package.rb') unless defined?(WR_ProposalPackage)
load File.join(R, 'wr-autoset.rb') unless defined?(WR_AutoSet)
$wr_no_autorun = nil
m = Sketchup.active_model
t0 = Time.now
booth, note = WR_AutoSet.resolve_booth(m, '')
raise "no booth: #{note}" if booth.nil?
puts "BOOTH: #{booth.name.inspect}  note=#{note.inspect}"
puts "CHOICES: #{WR_AutoSet.booth_choices(m).inspect}"
opts = { 'mode' => 'create', 'renders' => WR_AutoSet::DEFAULT_RENDERS,
         'interior' => false, 'reaim' => false }
ok, msg, lines = WR_AutoSet.apply(m, booth, opts)
puts "APPLY ok=#{ok} msg=#{msg}"
(lines || []).each { |l| puts "  #{l}" }
{ 'ok' => ok, 'msg' => msg, 'secs' => (Time.now - t0).round(2),
  'pages' => m.pages.map { |p| p.name },
  'modes' => m.pages.map { |p| [p.name, WR_ProposalPackage.mode_of(p)] } }
