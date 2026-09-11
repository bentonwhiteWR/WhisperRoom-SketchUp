load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
dir = CYC.export($cyc_sub)
{ 'dir' => dir, 'running' => WR_ProposalPackage.instance_variable_get(:@running), 'selected' => CYC.model.pages.selected_page.name }
