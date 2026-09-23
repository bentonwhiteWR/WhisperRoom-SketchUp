# LIVE TEST of proposal-package 1.76.0 (16:9, forced size), headless, 2 scenes only, SCRATCH folder.
# gather is wrapped IN MEMORY for this run only (no scene marks are changed): every row except the two
# test scenes reads 'skip'.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
KEEP = ['MDL 96144 E (components) 02-front r', 'MDL 96144 E (components) 02-front']
class << WR_ProposalPackage
  alias_method :gather_orig_cms, :gather unless method_defined?(:gather_orig_cms)
  def gather(model)
    gather_orig_cms(model).map { |r| KEEP.include?(r['scene'].to_s) ? r : r.merge('mode' => 'skip') }
  end
end
m = Sketchup.active_model
rows = WR_ProposalPackage.gather(m).reject { |r| r['mode'] == 'skip' }.map { |r| [r['scene'], r['mode']] }
cfg = { 'dir' => 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/5422d5e4-a09b-4ff0-bdd5-a1a5ee8cb3e0/scratchpad/pkg-test-169', 'width' => '800', 'over' => 'Overwrite', 'transp' => true, 'force' => true,
        'sub' => false, 'client' => 'TEST 16x9' }
WR_ProposalPackage.start_run(m, nil, cfg)
{ 'rows' => rows, 'running' => WR_ProposalPackage.instance_variable_get(:@running) }
