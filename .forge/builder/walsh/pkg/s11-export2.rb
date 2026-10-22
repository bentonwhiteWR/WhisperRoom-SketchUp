# Walsh v3 package step 4: headless package export (3 V-Ray renders + 6 images) to a NEW folder.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'   # always reload: 1.84.5 open-group guard
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
m.active_path = nil if m.active_path && !m.active_path.empty?
raise "edit context still open" if m.active_path && !m.active_path.empty?
out = 'Z:/Sketchup/Proposals/Walsh Construction Tech Lab MDL 96168 S - Corner RM - Package 2'
raise "folder already has files: #{out}" if File.directory?(out) && !Dir.children(out).empty?
WalshRM.save(m)
m.pages.each { |p| puts "  #{p.name} -> #{WR_ProposalPackage.mode_of(p)}" }
WR_ProposalPackage.start_run(m, nil, { 'dir' => out, 'sub' => false, 'force' => true, 'over' => 'Overwrite',
                                      'width' => 1920, 'shade' => true, 'client' => 'Walsh Construction' })
puts "running=#{WR_ProposalPackage.instance_variable_get(:@running).inspect} units=#{(WR_ProposalPackage.instance_variable_get(:@units) || []).size}"
true
