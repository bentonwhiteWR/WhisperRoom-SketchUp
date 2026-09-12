load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/t3/t3-lib.rb'
c = DCYC.cfg
dir = File.join(c['out'], c['sub'])
raise 'a batch is already running' if WR_ProposalPackage.instance_variable_get(:@running)
$T3_T0 = Time.now
WR_ProposalPackage.start_run(DCYC.model, nil,
  { 'dir' => dir, 'sub' => false, 'force' => true, 'over' => 'Overwrite', 'width' => 800 })
{ 'dir' => dir, 'running' => WR_ProposalPackage.instance_variable_get(:@running),
  'pages' => DCYC.model.pages.length }
