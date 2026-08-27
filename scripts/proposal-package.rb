# @title Proposal package...
# @cat V-Ray renders
# @rank 0
#
# One button for a proposal's whole image set. Lists every scene in the model,
# lets each one be marked Skip / Image / Render, picks an output folder, and
# writes `<Scene Name>.png` (plain SketchUp export) or `<Scene Name> render.png`
# (V-Ray) into that folder — leaving the model exactly as it was.
#
# Spec and clickable mockup: .forge/scoper/vray-proposal-package-spec.md and
# vray-proposal-mockup.html. The design decisions live there; the short form:
#
#   - Marks are stored ON EACH SCENE (attribute dict on the Sketchup::Page), so
#     they survive a save, a reopen, and a scene-tab reorder. Unmarked = Skip.
#   - The FILE column shows the EXACT name each row will write — sanitised,
#     " render" suffixed, collision-numbered — before anything is written. The
#     names are computed in Ruby, by the same method the export uses, and
#     pushed to the window; the column can never disagree with the disk.
#   - TWO PASSES, ONE MODE SWAP EACH WAY. Image rows export in DRAFT mode
#     (drafting materials — a plain export of render materials is neither one
#     thing nor the other), then render rows in RENDER mode. Model state is
#     changed only through WR_Mode, and the FINISH block — reached on success,
#     on failure and on cancel alike — restores mode, scene and camera. There
#     is no code path out of the batch that skips it.
#   - PLAIN IMAGES GET THE wr-shading.rb CONTRACT BY DEFAULT (DisplayShadows
#     off, Light 80 / Dark 45, ground/horizon/fog/watermark/AO off). V-Ray
#     lights cannot brighten a plain export; this contract is what makes one
#     read well. One checkbox turns it off; it is pushed after the draft swap
#     and popped before anything else changes mode, so it never leaks into a
#     mode snapshot.
#   - THE V-RAY LANE IS GATED, NOT ASSUMED. Nothing about the V-Ray Ruby API
#     has ever been run from this repo (reference/vray-ruby-api.md is
#     transcribed from docs; probe-vray.rb has never been run). When render
#     rows are planned and VRay::Context.active is nil, this tool REFUSES BY
#     NAME and offers to export the image rows only — never a half-run.
#
# The batch is a state machine stepped by UI.start_timer, not a blocking loop:
# SketchUp runs Ruby on the UI thread, and a long `each` would freeze the
# window so progress never paints and Cancel can never be clicked.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb"
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp, so nothing here has executed — only parsed with rbparse.py (real
# syntax check) and, for the filename/collision logic, executed against
# fixtures through SketchUp's own CRuby DLL. The machinery it drives —
# wr-mode.rb, wr-materials-swap.rb — carries the same banner: this tool is the
# first live exercise of all of it.

require 'sketchup.rb'
require 'json'
require 'fileutils'

$wr_no_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-preflight.rb')   # pulls in wr-mode.rb,
  load File.join(File.dirname(__FILE__), 'export-scenes.rb')  # wr-materials-swap.rb,
  load File.join(File.dirname(__FILE__), 'wr-folder.rb')      # wr-shading.rb
ensure
  $wr_no_autorun = $wr_no_autorun_was
end

module WR_ProposalPackage
  %w[DICT PREF FORBIDDEN FOLDER_KEY SLOT_LABEL].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  DICT       = 'WR_ProposalPackage'.freeze
  PREF       = 'WR_ProposalPackage'.freeze
  FOLDER_KEY = 'package'.freeze

  # Only what Windows genuinely refuses — export-scenes.rb's rule, verbatim.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # Human label for each drafting material, for the slot rows. The slots and
  # their draft names come from WR_MaterialsSwap — the one owner of that table.
  SLOT_LABEL = { WR_MaterialsSwap::DRAFT_FLOOR => 'Floor',
                 WR_MaterialsSwap::DRAFT_WALL  => 'Walls',
                 WR_MaterialsSwap::DRAFT_DOOR  => 'Door' }.freeze

  # -------------------------------------------------------------- marking --

  # 'render' / 'image' / 'skip'. Stored on the page itself so a mark survives
  # save, reopen and tab reorder (precedent: wr-pack-export.rb's vray flag).
  # Key absent means skip — the default and the safe one.
  def self.mode_of(page)
    m = page.get_attribute(DICT, 'mode', nil).to_s
    %w[render image].include?(m) ? m : 'skip'
  rescue StandardError
    'skip'
  end

  def self.set_mode(page, mode)
    if %w[render image].include?(mode)
      page.set_attribute(DICT, 'mode', mode)
    else
      d = page.attribute_dictionary(DICT, false)
      d.delete_key('mode') if d
    end
  end

  # ---------------------------------------------------------------- naming --

  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')      # Windows silently drops a trailing dot or space
  end

  # First caller gets the base name; later callers get "base (2)", "base (3)".
  # The FINAL name is what goes into `used`, so a scene literally named
  # "X (2)" cannot silently collide with a numbered one either.
  def self.uniquify(base, used)
    final = base
    k = 1
    while used.key?(final)
      k += 1
      final = "#{base} (#{k})"
    end
    used[final] = true
    final
  end

  # rows: [{'n'=>Integer, 'scene'=>String, 'mode'=>'skip'|'image'|'render'}]
  # in pages order. Returns { n => 'file.png' } for every non-skip row.
  # ONE collision map across BOTH lanes, and the " render" suffix goes on
  # AFTER sanitising (the suffix contains no forbidden characters) — so
  # "05-plan" marked render and a scene named "05-plan render" marked image
  # feed the same map and the second one gets "(2)", visibly, in the FILE
  # column before anything is written.
  def self.plan_names(rows)
    used = {}
    out  = {}
    rows.each do |r|
      next if r['mode'] == 'skip'
      base = sanitize(r['scene'])
      base = "scene-#{r['n']}" if base.empty?
      base += ' render' if r['mode'] == 'render'
      out[r['n']] = "#{uniquify(base, used)}.png"
    end
    out
  end

  # ----------------------------------------------------------------- state --

  # each_with_index over model.pages and nothing re-sorts it — the number IS
  # the position in the scene tabs, same as every exporter (list-scenes rule).
  def self.gather(model)
    model.pages.to_a.each_with_index.map do |page, i|
      { 'n' => i + 1, 'scene' => page.name.to_s, 'mode' => mode_of(page) }
    end
  end

  def self.slot_rows(model)
    WR_MaterialsSwap::SLOT_FOR.map do |draft, slot|
      { 'slot' => slot, 'draft' => draft,
        'label' => SLOT_LABEL[draft] || draft,
        'fill'  => WR_MaterialsSwap.fill(model, slot) }
    end
  end

  def self.state(model)
    rows  = gather(model)
    files = plan_names(rows)
    rows.each { |r| r['file'] = files[r['n']].to_s }
    { 'rows'      => rows,
      'slots'     => slot_rows(model),
      'materials' => (model.materials.map(&:name).sort rescue []) }
  end

  def self.push_state(model, dlg)
    dlg.execute_script("applyState(#{state(model).to_json})")
  rescue StandardError => e
    puts "  could not refresh the window: #{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------ v-ray gate --

  # REPORTED API (reference/vray-ruby-api.md, transcribed from Chaos's docs;
  # probe-vray.rb has never been run). Every VRay:: call in this file sits
  # behind this gate and inside its own rescue.
  def self.vray_context
    return nil unless defined?(VRay)
    VRay::Context.active
  rescue Exception
    nil
  end

  # -------------------------------------------------------------- the run --

  # cfg: {'dir', 'width', 'over' ('Ask'|'Overwrite'|'Skip existing'), 'shade'}
  def self.start_run(model, dlg, cfg)
    return if @running

    dir = cfg['dir'].to_s.strip.delete('"').tr('\\', '/').sub(%r{/+\z}, '')
    if dir.empty?
      UI.messagebox('Choose an output folder first.')
      return
    end

    rows  = gather(model)
    files = plan_names(rows)
    live  = rows.reject { |r| r['mode'] == 'skip' }
    if live.empty?
      UI.messagebox('No scenes are marked Image or Render — nothing to export.')
      return
    end

    # V-Ray gate BEFORE anything runs: never a half-run that dies mid-pass.
    if live.any? { |r| r['mode'] == 'render' } && vray_context.nil?
      images = live.select { |r| r['mode'] == 'image' }
      msg = "V-Ray is not available in this session (no active context).\n\n" \
            "Render one frame by hand in V-Ray, then run this again"
      if images.empty?
        UI.messagebox("#{msg}.\n\nNo scenes are marked Image, so there is nothing " \
                      'else to export.')
        return
      end
      ans = UI.messagebox("#{msg} — or export the image rows only.\n\n" \
                          "Yes = export the #{images.size} image row(s) only.\n" \
                          'No = cancel.', MB_YESNO)
      return unless ans == IDYES
      live = images
    end

    # Preflight — failing rows shown, Continue/Cancel is the operator's call.
    pf = begin
      WR_Preflight.check(model)
    rescue StandardError => e
      puts "  preflight itself failed: #{e.class}: #{e.message}"
      nil
    end
    failing = (pf || []).select { |r| r['status'] == 'fail' }
    unless failing.empty?
      lines = failing.map { |r| "  - #{r['label']}: #{r['detail']}" }.join("\n")
      go = UI.messagebox("Preflight found #{failing.size} issue(s):\n\n#{lines}\n\n" \
                         'Continue the export anyway?', MB_YESNO)
      return unless go == IDYES
    end

    begin
      FileUtils.mkdir_p(dir)
    rescue StandardError => e
      UI.messagebox("Cannot create the output folder:\n#{dir}\n\n#{e.class}: #{e.message}")
      return
    end

    # Resolve the on-disk collision policy UP FRONT, so the batch itself never
    # has to ask anything (a messagebox inside a timer tick re-enters timers).
    @results = []
    pages = model.pages.to_a
    plan = live.map do |r|
      { :page => pages[r['n'] - 1], :n => r['n'], :lane => r['mode'],
        :file => files[r['n']], :base => File.basename(files[r['n']], '.png'),
        :path => File.join(dir, files[r['n']]) }
    end
    existing = plan.select { |p| File.exist?(p[:path]) }
    unless existing.empty?
      case cfg['over']
      when 'Overwrite'
        # keep them all
      when 'Skip existing'
        existing.each do |p|
          @results << { :file => p[:file], :lane => p[:lane],
                        :status => 'skipped', :detail => 'already existed (policy: skip existing)' }
        end
        plan -= existing
      else # Ask
        names = existing.map { |p| p[:file] }.join("\n  ")
        ans = UI.messagebox("These files already exist in\n#{dir}:\n\n  #{names}\n\n" \
                            'Overwrite them? Yes overwrites, No skips just those and ' \
                            'keeps going.', MB_YESNOCANCEL)
        return if ans == IDCANCEL
        if ans != IDYES
          existing.each do |p|
            @results << { :file => p[:file], :lane => p[:lane],
                          :status => 'skipped', :detail => 'already existed, overwrite declined' }
          end
          plan -= existing
        end
      end
    end
    if plan.empty?
      UI.messagebox('Every planned file already exists and was skipped — nothing to do.')
      @results = []
      return
    end

    # Settings that should survive a restart — per machine, not per model
    # (a folder path is machine-specific). Quotes are stripped above; the
    # wr-folder storage rules apply.
    begin
      Sketchup.write_default(PREF, 'width', cfg['width'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'over',  cfg['over'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'shade', cfg['shade'] ? 'Yes' : 'No')
    rescue Exception
      nil
    end
    WR_Folder.remember(FOLDER_KEY, dir)

    image_rows  = plan.select { |p| p[:lane] == 'image' }
    render_rows = plan.select { |p| p[:lane] == 'render' }

    # ---- build the unit list. One timer tick does at most one unit.
    units = []
    unless image_rows.empty?
      units << [:mode, 'draft']
      units << [:shade_push] if cfg['shade']
      image_rows.each { |p| units << [:image, p] }
      units << [:shade_pop] if cfg['shade']
    end
    unless render_rows.empty?
      units << [:mode, 'render']
      render_rows.each { |p| units << [:render, p] }
    end

    @running     = true
    @cancel      = false
    @close_after = false
    @units       = units
    @ui          = 0
    @done        = 0
    @total       = units.size
    @awaiting    = nil
    @rend        = nil
    @shade_saved = nil
    @cfg         = { 'dir' => dir, 'width' => cfg['width'].to_s }
    @saved_mode  = WR_Mode.current(model)
    @mode_now    = @saved_mode
    @prev_page   = model.pages.selected_page
    @prev_cam    = (model.active_view.camera.clone rescue nil)

    puts ''
    puts "PROPOSAL PACKAGE — #{image_rows.size} image, #{render_rows.size} render -> #{dir}"
    dlg.execute_script('runStarted()')
    log(dlg, "#{image_rows.size} image + #{render_rows.size} render row(s) -> #{dir}", 'dim')

    stop_stale_timer
    @timer = UI.start_timer(0.1, true) { step(model, dlg) }
  end

  def self.stop_stale_timer
    UI.stop_timer(@timer) if @timer
  rescue StandardError
    nil
  ensure
    @timer = nil
  end

  # ------------------------------------------------------------- the step --

  def self.step(model, dlg)
    return if @in_step
    @in_step = true

    if @cancel
      if @awaiting
        begin
          @rend.stop if @rend            # reported API — best effort
        rescue Exception
          nil
        end
        @results << { :file => @awaiting[:file], :lane => 'render',
                      :status => 'cancelled', :detail => 'render stopped mid-flight' }
        @awaiting = nil
      end
      finish(model, dlg, 'cancelled')
      return
    end

    # A render in flight: poll it, at most one poll per tick.
    if @awaiting
      busy = begin
        @rend.respond_to?(:in_process?) ? @rend.in_process? : false
      rescue Exception
        false                            # unreadable — treat as finished, try to save
      end
      if busy
        progress(dlg, "Rendering #{@awaiting[:file]}…")
      else
        save_frame(dlg, @awaiting)
        @awaiting = nil
        @done += 1
        progress(dlg, nil)
      end
      return
    end

    unit = @units[@ui]
    if unit.nil?
      finish(model, dlg, 'done')
      return
    end
    @ui += 1

    case unit[0]
    when :mode       then unit_mode(model, dlg, unit[1])
    when :shade_push then unit_shade_push(model, dlg)
    when :shade_pop  then unit_shade_pop(model, dlg)
    when :image      then unit_image(model, dlg, unit[1])
    when :render     then unit_render(model, dlg, unit[1])
    end
    @done += 1 unless @awaiting          # a started render counts when it lands
    progress(dlg, nil)
  rescue Exception => e
    # No path out of the batch skips FINISH — an unexpected raise lands here.
    puts "  *** batch step raised: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).map { |l| "      #{l}" }.join("\n") if e.backtrace
    log(dlg, "batch step raised: #{e.class}: #{e.message}", 'bad')
    finish(model, dlg, "stopped by an error (#{e.class})")
  ensure
    @in_step = false
  end

  # --------------------------------------------------------------- units --

  # The ONLY way this tool changes model state. A raise here stops the batch
  # (the model is safe: each WR_MaterialsSwap sweep is one atomic operation,
  # aborted on a raise) — routed to FINISH by step's rescue.
  def self.unit_mode(model, dlg, target)
    res = WR_Mode.to_mode(model, target)
    @mode_now = target
    log(dlg, "MODE -> #{target.upcase}", 'dim')
    mat = res[:materials] || {}
    (mat[:applied] || mat[:reverted] || {}).each do |slot, n|
      log(dlg, "  #{slot}: #{n} surface(s)", 'dim')
    end
    # Unmapped surfaces named BEFORE the first render — "floor still white"
    # is said here, not discovered in the image.
    problems = mat[:unmapped] || mat[:left] || []
    problems.each { |s| log(dlg, "unmapped  #{s}", 'bad') }
    @unmapped = problems if target == 'render'
    model.active_view.refresh
  end

  # The wr-shading contract, image lane only, one checkbox. Pushed AFTER the
  # draft swap and popped before anything else changes mode, so the contract
  # never gets recorded into a WR_Mode snapshot.
  def self.unit_shade_push(model, dlg)
    @shade_saved = WR_Shading.push(model, WR_Shading::KEEP, WR_Shading::DEF_DARK)
    log(dlg, "shading contract on (Light #{WR_Shading::DEF_LIGHT} / Dark #{WR_Shading::DEF_DARK}, shadows off)", 'dim')
  rescue StandardError => e
    @shade_saved = nil
    log(dlg, "shading contract could not be applied: #{e.class}: #{e.message} — images export as the model sits", 'bad')
  end

  def self.unit_shade_pop(model, dlg)
    WR_Shading.pop(model, @shade_saved) if @shade_saved
    @shade_saved = nil
    log(dlg, 'shading contract restored', 'dim')
  end

  def self.unit_image(model, dlg, p)
    plan = [{ :page => p[:page], :n => p[:n], :base => p[:base] }]
    cfg  = { 'dir' => @cfg['dir'], 'width' => @cfg['width'], 'bg' => 'Opaque', 'over' => 'Yes' }
    x = WR_ExportScenes.export_pages(model, plan, cfg)
    if x[:written] > 0
      @results << { :file => p[:file], :lane => 'image', :status => 'ok',
                    :detail => "image, #{x[:width]}x#{x[:height]}" }
      log(dlg, "ok      #{p[:file]}  (image, #{x[:width]}x#{x[:height]})", 'ok')
    else
      @results << { :file => p[:file], :lane => 'image', :status => 'failed',
                    :detail => 'view.write_image returned false' }
      log(dlg, "FAILED  #{p[:file]}  (view.write_image returned false)", 'bad')
    end
  rescue StandardError => e
    @results << { :file => p[:file], :lane => 'image', :status => 'failed',
                  :detail => "#{e.class}: #{e.message}" }
    log(dlg, "FAILED  #{p[:file]}  (#{e.class}: #{e.message})", 'bad')
  end

  # Everything V-Ray in here is REPORTED API, individually rescued: a wrong
  # assumption about a signature becomes a named per-row failure, never a
  # crash out of the batch.
  def self.unit_render(model, dlg, p)
    ctx = vray_context
    if ctx.nil?
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'V-Ray context went away mid-run' }
      log(dlg, "FAILED  #{p[:file]}  (V-Ray context went away mid-run)", 'bad')
      return
    end
    rend = begin
      ctx.renderer
    rescue Exception => e
      nil
    end
    if rend.nil?
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'the active V-Ray context has no renderer' }
      log(dlg, "FAILED  #{p[:file]}  (the active V-Ray context has no renderer)", 'bad')
      return
    end

    model.pages.selected_page = p[:page]
    model.active_view.refresh
    progress(dlg, "Rendering #{p[:file]}…")

    @rend = rend
    begin
      rend.start
    rescue Exception => e
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => "renderer.start raised #{e.class}: #{e.message}" }
      log(dlg, "FAILED  #{p[:file]}  (renderer.start raised #{e.class}: #{e.message})", 'bad')
      return
    end

    if rend.respond_to?(:in_process?)
      @awaiting = p                      # async (or already done) — poll next tick
    else
      # No way to poll — fall back to the documented blocking wait. Progress
      # is per-scene here and mid-render cancel cannot land until it returns.
      begin
        rend.wait if rend.respond_to?(:wait)
      rescue Exception
        nil
      end
      save_frame(dlg, p)
    end
  end

  def self.save_frame(dlg, p)
    begin
      @rend.save_vfb_image(p[:path])
    rescue Exception => e
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => "save_vfb_image raised #{e.class}: #{e.message}" }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image raised #{e.class}: #{e.message})", 'bad')
      return
    end
    if File.exist?(p[:path])
      @results << { :file => p[:file], :lane => 'render', :status => 'ok',
                    :detail => 'V-Ray, Asset Editor size' }
      log(dlg, "ok      #{p[:file]}  (V-Ray, Asset Editor size)", 'ok')
    else
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'save_vfb_image returned but wrote no file' }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image returned but wrote no file)", 'bad')
    end
  end

  # -------------------------------------------------------------- finish --

  # THE single exit. Runs on completion, on cancel and on any raise — restores
  # mode, scene and camera, and fails LOUDLY with a recovery instruction if
  # the restore itself fails. A leaked mutation is the worst failure this
  # tool can have, so nothing here is allowed to fail quietly.
  def self.finish(model, dlg, why)
    stop_stale_timer
    restore_errs = []

    begin
      if @shade_saved
        WR_Shading.pop(model, @shade_saved)
        @shade_saved = nil
      end
    rescue Exception => e
      restore_errs << "shading pop: #{e.class}: #{e.message}"
    end

    if %w[draft render].include?(@saved_mode) && @mode_now != @saved_mode
      begin
        WR_Mode.to_mode(model, @saved_mode)
        @mode_now = @saved_mode
      rescue Exception => e
        restore_errs << "mode restore: #{e.class}: #{e.message}"
      end
    end

    begin
      model.pages.selected_page = @prev_page if @prev_page
    rescue Exception => e
      restore_errs << "scene restore: #{e.class}: #{e.message}"
    end
    begin
      model.active_view.camera = @prev_cam if @prev_cam
    rescue Exception => e
      restore_errs << "camera restore: #{e.class}: #{e.message}"
    end

    unless restore_errs.empty?
      puts "  *** could not restore the model's original state:"
      restore_errs.each { |s| puts "        #{s}" }
      UI.messagebox("*** COULD NOT RESTORE THE MODEL'S ORIGINAL STATE ***\n\n" +
                    restore_errs.join("\n") +
                    "\n\nThe model is likely in #{@mode_now.to_s.upcase} mode " \
                    "(it started in #{@saved_mode.to_s.upcase}).\n" \
                    "Press 'Toggle Draft / Render mode' to put it back — WR_Mode " \
                    'stores the true state in the model, so the toggle reads it ' \
                    'even after a crash.')
    end

    lines = summary_lines(why, restore_errs)
    puts ''
    lines.each { |l| puts l }
    puts ''
    restore_errs.each { |s| log(dlg, "RESTORE FAILED: #{s}", 'bad') }
    log(dlg, lines.first.to_s, restore_errs.empty? ? 'dim' : 'bad')
    (@unmapped || []).each { |s| log(dlg, "unmapped  #{s}", 'bad') }

    fails = @results.count { |r| r[:status] == 'failed' }
    msg = if why == 'cancelled'
            'Cancelled — model restored. Partial results are real files.'
          elsif fails > 0
            "Done — #{fails} failure(s) named in the log. Nothing silent."
          else
            'Done. Model restored.'
          end
    msg = 'FINISHED WITH RESTORE ERRORS — see the message and console.' unless restore_errs.empty?
    begin
      dlg.execute_script("runFinished(#{msg.to_json})")
    rescue StandardError
      nil
    end
    UI.messagebox(lines.join("\n"))

    @running  = false
    @unmapped = nil
    @results  = @results || []
    if @close_after
      @close_after = false
      begin
        dlg.close
      rescue StandardError
        nil
      end
    end
  end

  def self.summary_lines(why, restore_errs)
    ok    = @results.count { |r| r[:status] == 'ok' }
    skip  = @results.count { |r| %w[skipped cancelled].include?(r[:status]) }
    fails = @results.count { |r| r[:status] == 'failed' }
    lines = ["PROPOSAL PACKAGE — #{ok} exported, #{skip} skipped, #{fails} FAILED" \
             "#{why == 'done' ? '' : "  (#{why})"}"]
    lines << "  #{@cfg['dir']}"
    @results.each do |r|
      tag = { 'ok' => 'ok', 'failed' => 'FAILED', 'skipped' => 'skip',
              'cancelled' => 'cancel' }[r[:status]] || r[:status]
      lines << format('  %-7s %-40s (%s)', tag, r[:file], r[:detail])
    end
    (@unmapped || []).each { |s| lines << "  unmapped: #{s}" }
    restore_errs.each { |s| lines << "  *** RESTORE FAILED: #{s}" }
    lines
  end

  # ------------------------------------------------------------ dialog io --

  def self.log(dlg, text, cls)
    dlg.execute_script("logLine(#{text.to_json}, #{cls.to_json})")
  rescue StandardError
    nil
  end

  def self.progress(dlg, msg)
    pct = @total.zero? ? 0 : (100.0 * @done / @total).round
    m = msg || "#{@done} of #{@total} step(s) done…"
    dlg.execute_script("setProgress(#{pct}, #{m.to_json})")
  rescue StandardError
    nil
  end

  # ------------------------------------------------------------------ run --

  def self.run
    model = Sketchup.active_model
    if model.nil? || model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\nAdd scenes first " \
                    '(View > Animation > Add Scene), or run ' \
                    "'Set up the five proposal plates'.")
      return
    end

    # Never stomp a live batch — killing its timer would skip FINISH and leave
    # the model mutated. The live run's own window has the Cancel button.
    if @running
      UI.messagebox('A proposal-package export is already running. ' \
                    'Cancel it from its own window first.')
      return
    end
    stop_stale_timer
    @results = []

    title = model.title.to_s.empty? ? '(unsaved model)' : model.title
    dir   = WR_Folder.read_list(FOLDER_KEY).first.to_s
    # read_default EVALS the stored string; a bad one raises SyntaxError, which
    # descends from ScriptError, not StandardError (wr-folder.rb's storage
    # rules) — so these rescue Exception, not a plain rescue.
    width = begin
      Sketchup.read_default(PREF, 'width', '2400').to_s
    rescue Exception
      '2400'
    end
    over = begin
      Sketchup.read_default(PREF, 'over', 'Ask').to_s
    rescue Exception
      'Ask'
    end
    shade = begin
      Sketchup.read_default(PREF, 'shade', 'Yes').to_s
    rescue Exception
      'Yes'
    end != 'No'
    width = '2400' if width.strip.empty?
    over  = 'Ask' unless ['Ask', 'Overwrite', 'Skip existing'].include?(over)

    d = UI::HtmlDialog.new(
      :dialog_title    => "Proposal package — #{title}",
      :preferences_key => 'com.whisperroom.proposalpackage',
      :scrollable      => true,
      :resizable       => true,
      :width           => 700,
      :height          => 760,
      :min_width       => 520,
      :min_height      => 480,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(title, state(model), dir, width, over, shade))

    d.add_action_callback('mark') do |_c, payload|
      begin
        data = JSON.parse(payload)
        page = model.pages.to_a[data['n'].to_i - 1]
        set_mode(page, data['mode'].to_s) if page
      rescue StandardError => e
        puts "  mark failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('bulk') do |_c, payload|
      begin
        data  = JSON.parse(payload)
        pages = model.pages.to_a
        (data['ns'] || []).each do |n|
          page = pages[n.to_i - 1]
          set_mode(page, data['mode'].to_s) if page
        end
      rescue StandardError => e
        puts "  bulk mark failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('setfill') do |_c, payload|
      begin
        data = JSON.parse(payload)
        name = data['name'].to_s
        name = '' if name == '(unset)'
        WR_MaterialsSwap.set_fill(model, data['slot'].to_s, name)
      rescue StandardError => e
        puts "  slot fill failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('activate') do |_c, n|
      begin
        pg = model.pages.to_a[n.to_i - 1]
        model.pages.selected_page = pg if pg
      rescue StandardError => e
        puts "  could not activate scene #{n}: #{e.class}: #{e.message}"
      end
    end

    d.add_action_callback('browse') do |_c, cur|
      begin
        start = cur.to_s.strip.delete('"')
        start = WR_Folder.read_list(FOLDER_KEY).first.to_s unless File.directory?(start)
        opts = { :title => 'Where should the package go?' }
        opts[:directory] = start if !start.empty? && File.directory?(start)
        chosen = UI.select_directory(opts)
        unless chosen.nil? || chosen.to_s.empty?
          p = chosen.to_s.tr('\\', '/')
          WR_Folder.remember(FOLDER_KEY, p)
          d.execute_script("setDir(#{p.to_json})")
        end
      rescue StandardError => e
        puts "  browse failed: #{e.class}: #{e.message}"
      end
    end

    d.add_action_callback('export') do |_c, payload|
      begin
        cfg = JSON.parse(payload)
        start_run(model, d, cfg)
      rescue StandardError => e
        UI.messagebox("Export failed to start:\n\n#{e.class}: #{e.message}")
        puts "FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(5)
      end
    end

    d.add_action_callback('cancelrun') { |_c| @cancel = true if @running }

    d.add_action_callback('close') do |_c|
      if @running
        @cancel = true        # Close during a run behaves as Cancel first;
        @close_after = true   # FINISH closes the window after the restore.
      else
        d.close
      end
    end

    d.show
    nil
  rescue StandardError => e
    UI.messagebox("Proposal package failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  # ----------------------------------------------------------------- html --

  def self.html(title, st, dir, width, over, shade)
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Proposal package</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --ok:#2e7d46; --bad:#b0402c; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  ::-webkit-scrollbar { width:9px; height:9px; }
  ::-webkit-scrollbar-thumb { background:#c9d0d5; border-radius:5px; }

  .top { flex:0 0 auto; padding:10px 12px 6px; display:flex; gap:10px; align-items:baseline; }
  .top .t { font-weight:650; }
  .top .c { color:var(--muted); font-size:12px; margin-left:auto; }
  .cmd { flex:0 0 auto; margin:0 12px 8px; }
  .cmd input { width:100%; padding:8px 10px; font:inherit; color:var(--ink);
    background:var(--surface); border:1px solid var(--line); border-radius:8px; outline:none; }
  .cmd input:focus { border-color:var(--accent); }

  .bulk { flex:0 0 auto; margin:0 12px 8px; padding:8px 11px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; display:flex; gap:8px; align-items:center; }
  .bulk .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .btn { font:inherit; font-size:12px; padding:5px 11px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer;
         white-space:nowrap; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; font-weight:650; }
  .btn.p:disabled { background:#f0b48e; border-color:#f0b48e; cursor:default; }
  .btn:disabled { color:var(--faint); cursor:default; border-color:var(--line); }

  .wrap { flex:1 1 auto; overflow:auto; margin:0 12px 10px; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; min-height:140px; }
  table { width:100%; border-collapse:collapse; }
  th { position:sticky; top:0; background:var(--surface); text-align:left;
       font-size:10.5px; font-weight:650; letter-spacing:.09em; color:var(--faint);
       padding:8px 9px; border-bottom:1px solid var(--line); white-space:nowrap; z-index:2; }
  td { padding:5px 9px; border-top:1px solid var(--line); vertical-align:middle; }
  tr:hover td { background:#f8f4f1; }
  td.n { font-variant-numeric:tabular-nums; color:var(--muted); width:1%; white-space:nowrap; }
  td.file { color:var(--muted); font-size:11.5px; white-space:nowrap; overflow:hidden;
            text-overflow:ellipsis; max-width:210px; }
  td.file b { color:var(--accent); font-weight:600; }
  td.go { width:1%; }
  .go button { border:0; background:transparent; color:var(--faint); cursor:pointer;
               font-size:13px; padding:0 4px; }
  .go button:hover { color:var(--accent); }
  mark { background:#ffe3a8; color:inherit; border-radius:2px; }

  .seg { display:inline-flex; border:1px solid var(--line); border-radius:6px; overflow:hidden; }
  .seg button { font:inherit; font-size:11px; padding:3px 9px; border:0; background:var(--surface);
                color:var(--muted); cursor:pointer; border-left:1px solid var(--line); }
  .seg button:first-child { border-left:0; }
  .seg button.on-skip   { background:#eef1f2; color:var(--muted); font-weight:650; }
  .seg button.on-image  { background:#e8f0fa; color:#2b5e8f; font-weight:650; }
  .seg button.on-render { background:var(--soft); color:var(--accent); font-weight:650; }

  .sect { flex:0 0 auto; margin:0 12px 8px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; }
  .sect > .hd { padding:8px 11px; display:flex; gap:8px; align-items:center; cursor:pointer;
                user-select:none; }
  .sect .hd .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .sect .hd .sum { color:var(--muted); font-size:11.5px; margin-left:auto; }
  .sect .hd .tri { color:var(--faint); font-size:10px; }
  .sect .bodyy { padding:2px 11px 10px; display:none; }
  .sect.open .bodyy { display:block; }
  .matrow { display:flex; gap:8px; align-items:center; padding:4px 0; }
  .matrow .from { width:230px; flex:0 0 auto; color:var(--muted); font-size:12px; }
  .matrow .from b { color:var(--ink); font-weight:600; }
  .matrow select { flex:1 1 auto; font:inherit; font-size:12px; padding:4px 6px;
                   border:1px solid var(--line); border-radius:6px; background:#fff;
                   color:var(--ink); min-width:0; }
  .matnote { color:var(--muted); font-size:11px; padding-top:6px;
             border-top:1px dashed var(--line); margin-top:6px; }

  .out { flex:0 0 auto; margin:0 12px 8px; padding:9px 11px; background:var(--surface);
         border:1px solid var(--line); border-radius:8px; display:grid;
         grid-template-columns:auto 1fr auto; gap:7px 8px; align-items:center; }
  .out .lbl { font-size:10.5px; font-weight:650; letter-spacing:.08em; color:var(--faint); }
  .out input, .out select { font:inherit; font-size:12px; padding:5px 8px;
               border:1px solid var(--line); border-radius:6px; background:#fff;
               color:var(--ink); min-width:0; }
  .out input:focus { border-color:var(--accent); outline:none; }
  .out .half { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  .out .half .lbl { width:auto; }
  .out .half input[type=text] { width:72px; }
  .out .shadelbl { font-size:11.5px; color:var(--muted); }

  .runlog { flex:0 0 auto; margin:0 12px 8px; background:#20262a; color:#cdd6da;
            border-radius:8px; font:11px/1.6 Consolas,monospace; padding:8px 11px;
            max-height:130px; overflow:auto; display:none; }
  .runlog .ok { color:#8fd0a0; } .runlog .bad { color:#f0a08c; } .runlog .dim { color:#8b979e; }
  .bar { flex:0 0 auto; padding:0 12px 12px; display:flex; gap:8px; align-items:center; }
  .prog { flex:1 1 auto; color:var(--muted); font-size:11.5px; }
  .prog .pbar { height:4px; background:#e6e9eb; border-radius:2px; margin-top:4px; overflow:hidden; }
  .prog .pbar i { display:block; height:100%; width:0%; background:var(--accent); transition:width .2s; }
  .foot { flex:0 0 auto; padding:0 12px 10px; color:var(--muted); font-size:11px; }
</style></head><body>

<div class="top">
  <span class="t">#{escHtml(title)}</span>
  <span class="c" id="count"></span>
</div>

<div class="cmd">
  <input id="q" placeholder="Search scenes — several words, any order — or a range like 1-5"
         autocomplete="off" spellcheck="false">
</div>

<div class="bulk">
  <span class="lbl">SHOWN &rarr;</span>
  <button class="btn" data-bulk="render">Render</button>
  <button class="btn" data-bulk="image">Image</button>
  <button class="btn" data-bulk="skip">Skip</button>
  <span class="lbl" style="margin-left:auto" id="picksum"></span>
</div>

<div class="wrap"><table>
  <thead><tr>
    <th>#</th><th>SCENE</th><th>MODE</th><th>FILE IT WILL WRITE</th><th></th>
  </tr></thead>
  <tbody id="body"></tbody>
</table></div>

<div class="sect" id="mats">
  <div class="hd" id="matshd">
    <span class="tri">&#9654;</span>
    <span class="lbl">MATERIALS FOR THE V-RAY PASS</span>
    <span class="sum" id="matsum"></span>
  </div>
  <div class="bodyy" id="matbody"></div>
</div>

<div class="out">
  <span class="lbl">FOLDER</span>
  <input type="text" id="dir" value="#{escAttr(dir)}" style="width:100%">
  <button class="btn" id="browse">Browse&hellip;</button>

  <span class="lbl">IMAGES</span>
  <div class="half">
    <span class="lbl">WIDTH</span><input type="text" id="width" value="#{escAttr(width)}">
    <span class="lbl">PX — height follows the viewport aspect. V-Ray renders use the size in the V-Ray Asset Editor.</span>
  </div>
  <span></span>

  <span class="lbl">EXISTS?</span>
  <select id="over" style="max-width:200px">
    <option#{over == 'Ask' ? ' selected' : ''}>Ask</option>
    <option#{over == 'Overwrite' ? ' selected' : ''}>Overwrite</option>
    <option#{over == 'Skip existing' ? ' selected' : ''}>Skip existing</option>
  </select>
  <span></span>

  <span class="lbl">SHADING</span>
  <label class="shadelbl"><input type="checkbox" id="shade"#{shade ? ' checked' : ''}>
    Even shading for plain images (shadows off, Light #{WR_Shading::DEF_LIGHT} / Dark #{WR_Shading::DEF_DARK} — the component-art contract). V-Ray scenes are never touched by this.</label>
  <span></span>
</div>

<div class="runlog" id="log"></div>

<div class="bar">
  <div class="prog"><span id="pmsg">Ready.</span><div class="pbar"><i id="pfill"></i></div></div>
  <button class="btn" id="cancel" style="display:none">Cancel</button>
  <button class="btn" id="closeb">Close</button>
  <button class="btn p" id="export">Export package</button>
</div>

<div class="foot"># is the scene's position in the tabs — same number the exporters use.
  The arrow jumps to that scene. Filenames are the scene names verbatim; only characters
  Windows forbids become &ldquo;-&rdquo;, and a V-Ray scene gets &ldquo; render&rdquo; added.
  Size the SketchUp window to the aspect you want before exporting.</div>

<script>
(function () {
  "use strict";
  var ST = #{st.to_json};
  var running = false;

  function g(id){ return document.getElementById(id); }
  var $q=g("q"), $b=g("body"), $count=g("count"), $pick=g("picksum"),
      $log=g("log"), $pmsg=g("pmsg"), $pfill=g("pfill");

  function esc(s){ return String(s==null?"":s).replace(/&/g,"&amp;")
    .replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")
    .replace(/'/g,"&#39;"); }   // scene names go into title='...' attributes

  // ---- search: list-scenes semantics, over scene names only ----
  function terms(q){ return q.toLowerCase().split(/\\s+/).filter(function(t){return t.length>0;}); }
  function parseNums(q){
    if (!/^[\\d\\s,\\-]+$/.test(q)) return null;
    var want={}, only=/[,\\-]/.test(q);
    q.split(",").forEach(function(tok){
      tok=tok.trim(); if(!tok) return;
      var m=tok.match(/^(\\d+)\\s*-\\s*(\\d+)$/);
      if (m){ var a=+m[1],b=+m[2]; if(a>b){var t=a;a=b;b=t;} for(var k=a;k<=b;k++) want[k]=1; }
      else if (/^\\d+$/.test(tok)) want[+tok]=1;
    });
    return Object.keys(want).length ? {want:want, only:only} : null;
  }
  function hl(t, ts){
    var s=String(t==null?"":t);
    if(!ts || !ts.length) return esc(s);
    var lo=s.toLowerCase(), spans=[];
    ts.forEach(function(term){
      if(!term) return; var i=lo.indexOf(term);
      while(i>=0){ spans.push([i,i+term.length]); i=lo.indexOf(term,i+term.length); }
    });
    if(!spans.length) return esc(s);
    spans.sort(function(a,b){return a[0]-b[0]||a[1]-b[1];});
    var out="", at=0;
    spans.forEach(function(sp){
      if(sp[1]<=at) return; var a=sp[0]>at?sp[0]:at;
      out+=esc(s.slice(at,a))+"<mark>"+esc(s.slice(a,sp[1]))+"</mark>"; at=sp[1];
    });
    return out+esc(s.slice(at));
  }

  // ---- table ----
  var view = ST.rows.slice();
  function segBtn(r,m,label){
    return "<button data-n='"+r.n+"' data-mode='"+m+"' class='"+(r.mode===m?("on-"+m):"")+"'>"+label+"</button>";
  }
  function draw(){
    var q=$q.value.trim(), nums=parseNums(q), ts=terms(q);
    view = ST.rows.filter(function(r){
      if(!q) return true;
      if(nums && nums.only) return !!nums.want[r.n];
      if(nums && nums.want[r.n]) return true;
      var s=r.scene.toLowerCase();
      return ts.length>0 && ts.every(function(t){ return s.indexOf(t)>=0; });
    });
    var hi=(nums&&nums.only)?[]:ts;
    $b.innerHTML = view.map(function(r){
      var fh = r.file ? esc(r.file).replace(/ render(?=( \\(\\d+\\))?\\.png$)/," <b>render</b>") : "&mdash;";
      return "<tr data-n='"+r.n+"'>"+
        "<td class='n'>"+r.n+"</td>"+
        "<td>"+hl(r.scene,hi)+"</td>"+
        "<td><span class='seg'>"+
          segBtn(r,"skip","Skip")+segBtn(r,"image","Image")+segBtn(r,"render","Render")+
        "</span></td>"+
        "<td class='file' title='"+esc(r.file)+"'>"+fh+"</td>"+
        "<td class='go'><button data-go='"+r.n+"' title='Go to this scene'>&#8594;</button></td></tr>";
    }).join("");
    Array.prototype.forEach.call($b.querySelectorAll("[data-mode]"), function(el){
      el.addEventListener("click", function(){
        if(running) return;
        if(window.sketchup && sketchup.mark)
          sketchup.mark(JSON.stringify({ n:+el.getAttribute("data-n"),
                                         mode:el.getAttribute("data-mode") }));
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-go]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(window.sketchup && sketchup.activate) sketchup.activate(el.getAttribute("data-go"));
      });
    });
    var nr=ST.rows.filter(function(r){return r.mode==="render";}).length,
        ni=ST.rows.filter(function(r){return r.mode==="image";}).length;
    $count.textContent = (view.length===ST.rows.length ? ST.rows.length+" scenes"
                          : view.length+" of "+ST.rows.length)
                         + " · "+nr+" render · "+ni+" image";
    $pick.textContent = nr+" RENDER · "+ni+" IMAGE · "+(ST.rows.length-nr-ni)+" SKIP";
    var filled = ST.slots.filter(function(s){ return s.fill; }).length;
    g("matsum").textContent = nr ? (filled+" of "+ST.slots.length+" slots filled — applies to "
                                    +nr+" render scene(s)")
                                 : "no render scenes marked";
    g("export").disabled = running || (nr+ni)===0;
  }

  function drawMats(){
    g("matbody").innerHTML = ST.slots.map(function(s){
      var opts = ["(unset)"].concat(ST.materials).map(function(m){
        var cur = s.fill ? s.fill : "(unset)";
        return "<option"+(m===cur?" selected":"")+">"+esc(m)+"</option>";
      }).join("");
      return "<div class='matrow'><span class='from'>"+esc(s.label)+" <b>"+esc(s.draft)+
             "</b> &rarr; "+esc(s.slot)+"</span>"+
             "<select data-slot='"+esc(s.slot)+"'>"+opts+"</select></div>";
    }).join("") +
    "<div class='matnote'>Applied only while the V-Ray scenes render, and reverted before this " +
    "window says done — the model goes back to drafting materials. A slot left (unset) leaves " +
    "those surfaces drafting and is <b>reported by name</b>, never silently wrong. Same slots as " +
    "the Draft / Render toggle — set them in either place. If SketchUp ever dies mid-render, " +
    "the Toggle Draft/Render button puts the model back.</div>";
    Array.prototype.forEach.call(g("matbody").querySelectorAll("select"), function(sel){
      sel.addEventListener("change", function(){
        if(window.sketchup && sketchup.setfill)
          sketchup.setfill(JSON.stringify({ slot:sel.getAttribute("data-slot"), name:sel.value }));
      });
    });
  }

  // Ruby pushes fresh rows + filenames after every mark / bulk / fill change,
  // so the FILE column always shows what the export will actually write.
  window.applyState = function (st) { ST = st; drawMats(); draw(); };
  window.setDir = function (d) { g("dir").value = d; };

  // ---- run feedback, driven from Ruby ----
  window.logLine = function (text, cls) {
    $log.style.display="block";
    $log.innerHTML += "<span class='"+(cls||"dim")+"'>"+esc(text)+"</span><br>";
    $log.scrollTop = 1e6;
  };
  window.setProgress = function (pct, msg) {
    $pfill.style.width = pct+"%"; $pmsg.textContent = msg;
  };
  window.runStarted = function () {
    running = true; $log.innerHTML=""; $log.style.display="block";
    g("cancel").style.display=""; $pfill.style.width="0%"; draw();
  };
  window.runFinished = function (msg) {
    running = false; g("cancel").style.display="none"; $pmsg.textContent = msg; draw();
  };

  // ---- wiring ----
  Array.prototype.forEach.call(document.querySelectorAll("[data-bulk]"), function(el){
    el.addEventListener("click", function(){
      if(running) return;
      var ns = view.map(function(r){ return r.n; });
      if(window.sketchup && sketchup.bulk)
        sketchup.bulk(JSON.stringify({ ns:ns, mode:el.getAttribute("data-bulk") }));
    });
  });
  $q.addEventListener("input", draw);
  g("matshd").addEventListener("click", function(){
    var s=g("mats"); s.classList.toggle("open");
    s.querySelector(".tri").innerHTML = s.classList.contains("open")?"&#9660;":"&#9654;";
  });
  g("browse").addEventListener("click", function(){
    if(window.sketchup && sketchup.browse) sketchup.browse(g("dir").value);
  });
  g("cancel").addEventListener("click", function(){
    if(window.sketchup && sketchup.cancelrun) sketchup.cancelrun();
    $pmsg.textContent = "Cancelling — finishing the current step, then restoring the model…";
  });
  g("closeb").addEventListener("click", function(){
    if(window.sketchup && sketchup.close) sketchup.close();
  });
  g("export").addEventListener("click", function(){
    if(running) return;
    if(window.sketchup && sketchup.export)
      sketchup.export(JSON.stringify({
        dir:   g("dir").value,
        width: g("width").value,
        over:  g("over").value,
        shade: g("shade").checked
      }));
  });

  drawMats();
  draw();
}());
</script></body></html>
    HTML
  end

  def self.escAttr(s)
    s.to_s.gsub('&', '&amp;').gsub('"', '&quot;').gsub('<', '&lt;')
  end

  def self.escHtml(s)
    s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end

begin
  WR_ProposalPackage.run unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n") if e.backtrace
  UI.messagebox("Proposal package failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
