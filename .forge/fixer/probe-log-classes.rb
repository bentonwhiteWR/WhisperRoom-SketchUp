# LIVE PROBE 2 -- what does finish actually SEND to the panel's log?
#
# Probe 1 proved no modal fires. This proves the summary is not lost with it:
# it records every (text, class) pair finish hands to self.log while still
# calling the real log, so the panel is driven for real AND the traffic is
# visible. Run twice: once on a batch with a failure, once on a clean batch,
# so the headline's colour can be compared.

$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
$wr_no_autorun = nil

P = WR_ProposalPackage
m = Sketchup.active_model
d = P.instance_variable_get(:@dlg)
raise 'no panel dialog -- open the proposal panel first' if d.nil?
raise 'panel dialog is not visible' unless d.visible?

$wr_sent = []
$wr_script_errors = []
class << P
  alias_method :wr_probe_orig_log, :log
  def log(dlg, text, cls)
    $wr_sent << [cls.to_s, text.to_s]
    begin
      wr_probe_orig_log(dlg, text, cls)
    rescue Exception => e
      $wr_script_errors << "#{e.class}: #{e.message}"
    end
  end
end

def wr_probe_run(p, m, d, results, plan)
  cfg = { 'dir' => 'C:/nonexistent-probe-dir', 'width' => 1600, 'height' => 1200 }
  p.instance_variable_set(:@headless, d.nil? || (cfg && cfg['force']) ? true : false)
  { :@shade_saved => nil, :@vray_saved => nil, :@saved_mode => 'draft',
    :@mode_now => 'draft', :@mode_note => nil, :@prev_page => nil,
    :@prev_cam => nil, :@prev_2d => nil, :@manifest_plan => nil,
    :@last_prompt => nil, :@timer => nil, :@finishing => false,
    :@running => true, :@cancel => false, :@close_after => false,
    :@unmapped => [], :@quality_problems => [], :@srgb_problems => [],
    :@cfg => cfg, :@plan_files => plan, :@results => results
  }.each { |k, v| p.instance_variable_set(k, v) }
  $wr_sent = []
  p.finish(m, d, 'done')
  $wr_sent.dup
end

failing = wr_probe_run(P, m, d,
  [{ :file => 'hero.png', :status => 'ok',      :detail => 'rendered' },
   { :file => 'dims.png', :status => 'failed',  :detail => 'V-Ray timed out' },
   { :file => 'plan.png', :status => 'skipped', :detail => 'exists' }],
  %w[hero.png dims.png plan.png])

clean = wr_probe_run(P, m, d,
  [{ :file => 'hero.png', :status => 'ok', :detail => 'rendered' },
   { :file => 'dims.png', :status => 'ok', :detail => 'rendered' }],
  %w[hero.png dims.png])

class << P
  alias_method :log, :wr_probe_orig_log
end

{ 'failed_headline'  => failing.first,
  'failed_all'       => failing,
  'clean_headline'   => clean.first,
  'clean_classes'    => clean.map { |c, _t| c }.uniq,
  'execute_script_errors' => $wr_script_errors,
  'log_still_original'    => P.method(:log).owner.to_s }
