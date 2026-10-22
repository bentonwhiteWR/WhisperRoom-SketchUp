# Test render of the two render rows only (960 wide) into scratch. Other rows set to skip for the
# test; their marks are stored on the model first and restored by t1-restore.rb.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
require 'json'
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
out = ARGV_OUT rescue nil
out = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad/test1'
require 'fileutils'; FileUtils.mkdir_p(out)
Dir.children(out).each { |f| File.delete(File.join(out, f)) }
marks = m.pages.map { |p| [p.name, WR_ProposalPackage.mode_of(p)] }.to_h
m.set_attribute('walsh_pkg2', 'marks', marks.to_json) unless m.get_attribute('walsh_pkg2', 'marks')
keep = (TEST_KEEP rescue ['01-angled r', '02-front r'])
m.pages.each { |p| WR_ProposalPackage.set_mode(p, keep.any? { |k| p.name.end_with?(k) } ? 'render' : 'skip') }
WalshRM.save(m)
m.pages.each { |p| puts "  #{p.name} -> #{WR_ProposalPackage.mode_of(p)}" }
WR_ProposalPackage.start_run(m, nil, { 'dir' => out, 'sub' => false, 'force' => true, 'over' => 'Overwrite',
                                      'width' => 960, 'shade' => true, 'client' => 'Walsh test' })
puts "running=#{WR_ProposalPackage.instance_variable_get(:@running).inspect}"
true
