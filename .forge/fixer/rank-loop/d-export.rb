# Render the one live plate. See d-lib.rb.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'
dir = DCYC.export!
{ 'dir' => dir, 'selected' => DCYC.model.pages.selected_page.name,
  'running' => WR_ProposalPackage.instance_variable_get(:@running) }
