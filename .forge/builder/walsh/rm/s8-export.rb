# Walsh v3 step 8: export the AUTO-SET IMAGE plates through the proposal package (headless start_run).
# No V-Ray this pass (Benton: speed): the render-marked 'r' plates are set to Skip for the run and put back
# by s8b-restore.rb. Folder is new; refuses if it already holds PNGs.
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
OUT = 'Z:/Sketchup/Proposals/Walsh Construction Tech Lab MDL 96168 S - Corner RM'
Dir.mkdir(OUT) unless File.directory?(OUT)
raise "#{OUT} already has PNGs" unless Dir.glob(File.join(OUT, '*.png')).empty?
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
held = []
m.pages.each do |p|
  next unless WR_ProposalPackage.mode_of(p) == 'render'
  held << p.name
  WR_ProposalPackage.set_mode(p, 'skip')
end
m.set_attribute('WalshRM', 'render_held', held)
live = m.pages.select { |p| WR_ProposalPackage.mode_of(p) != 'skip' }.map(&:name)
puts "held render plates (now skip): #{held.inspect}"
puts "image plates: #{live.inspect}"
WR_ProposalPackage.start_run(m, nil, { 'dir' => OUT, 'sub' => false, 'force' => true, 'over' => 'Overwrite', 'width' => 1920, 'client' => 'Walsh Construction' })
{ 'running' => WR_ProposalPackage.instance_variable_get(:@running), 'out' => OUT }
