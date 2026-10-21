# Walsh v3 step 10: re-export only 01-angled and 06-plan (others held to skip for the run; s10b restores).
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
OUT = 'Z:/Sketchup/Proposals/Walsh Construction Tech Lab MDL 96168 S - Corner RM'
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
want = ['01-angled', '06-plan'].map { |n| 'Booth - MDL 96168 S RM (21 Oct link) ' + n }
held = {}
m.pages.each do |p|
  md = WR_ProposalPackage.mode_of(p)
  next if want.include?(p.name) || md == 'skip'
  held[p.name] = md; WR_ProposalPackage.set_mode(p, 'skip')
end
m.set_attribute('WalshRM', 's10_held', held.to_a.flatten)
puts "held: #{held.inspect}"
WR_ProposalPackage.start_run(m, nil, { 'dir' => OUT, 'sub' => false, 'force' => true, 'over' => 'Overwrite', 'width' => 1920, 'client' => 'Walsh Construction' })
true
