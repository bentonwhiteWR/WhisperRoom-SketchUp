# LIVE PROBE -- does the end-of-batch summary box fire on the INTERACTIVE path?
#
# Reported condition: Benton's panel is open (a real, visible HtmlDialog) and
# the caller passed no 'force'. That is exactly what is set up below; nothing
# about the box decision is simulated. What IS simulated is the WORK that
# produced @results -- this probe does not render, it hands finish a finished
# batch and watches what finish does with it.
#
# ORACLE: the bridge patches UI.messagebox to raise ModalBlocked. finish
# rescues that and prints "(the summary box could not be shown: ...)". So:
#   BEFORE the fix -> that string appears, and box_attempted is true.
#   AFTER  the fix -> neither appears.
# Designed to fail: if the box is gone and this still reports it, the probe
# is wrong, not the code.

$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
$wr_no_autorun = nil

P = WR_ProposalPackage
m = Sketchup.active_model
d = P.instance_variable_get(:@dlg)
raise 'no panel dialog -- open the proposal panel first' if d.nil?
raise 'panel dialog is not visible' unless d.visible?

# THE LATCH, set the way start_run sets it for a panel-driven run:
#   @headless = dlg.nil? || (cfg && cfg['force']) ? true : false
cfg = { 'dir' => 'C:/nonexistent-probe-dir', 'width' => 1600, 'height' => 1200 }
P.instance_variable_set(:@headless, d.nil? || (cfg && cfg['force']) ? true : false)

# Every restore made a no-op, so restore_errs stays empty and the SEPARATE
# restore-failure box (out of scope) cannot fire and muddy the oracle.
{ :@shade_saved => nil, :@vray_saved => nil, :@saved_mode => 'draft',
  :@mode_now => 'draft', :@mode_note => nil, :@prev_page => nil,
  :@prev_cam => nil, :@prev_2d => nil, :@manifest_plan => nil,
  :@last_prompt => nil, :@timer => nil, :@finishing => false,
  :@running => true, :@cancel => false, :@close_after => false,
  :@unmapped => [], :@quality_problems => [], :@srgb_problems => [],
  :@cfg => cfg,
  :@plan_files => %w[hero.png dims.png plan.png],
  :@results => [{ :file => 'hero.png', :status => 'ok',      :detail => 'rendered' },
                { :file => 'dims.png', :status => 'failed',  :detail => 'V-Ray timed out' },
                { :file => 'plan.png', :status => 'skipped', :detail => 'exists' }]
}.each { |k, v| P.instance_variable_set(k, v) }

# READ THE PANEL BACK. The log lines go out through dlg.execute_script,
# which is fire-and-forget; a callback answering it can only run once the
# message loop pumps, which is after this job returns. So the answer is
# parked in a global and a SECOND bridge job collects it.
$wr_probe_log = nil
d.add_action_callback('wrprobelog') { |_c, payload| $wr_probe_log = payload }

before = $stdout.respond_to?(:text) ? $stdout.text.to_s.length : 0
P.finish(m, d, 'done')
tail = $stdout.respond_to?(:text) ? $stdout.text.to_s[before..-1].to_s : ''

d.execute_script("sketchup.wrprobelog(document.getElementById('log').innerHTML)")

{ 'headless?'        => P.headless?,
  'box_attempted'    => tail.include?('the summary box could not be shown'),
  'modal_blocked'    => tail.include?('ModalBlocked'),
  'restore_box_hit'  => tail.include?('the restore-failure box could not be shown'),
  'running_latch'    => P.instance_variable_get(:@running),
  'oracle'           => (tail.include?('the summary box could not be shown') ?
                         'MODAL FIRED on the interactive path' :
                         'no modal on the interactive path') }
