# @title Export the client pack...
# @cat V-Ray renders
# @rank 5
#
# The one-button export. A ROUTER, not a renderer: it walks the five proposal
# plates in order and sends each one down the lane it is marked for.
#
#   01-exterior  02-dimensioned  03-side  04-ventilation  05-plan
#
# VIEWPORT LANE — LIVE. Every plate defaults here. It puts the model in the
# right mode for that plate (02-dimensioned needs DRAFT — drafting materials,
# dimensions on; the other four need RENDER), reuses export-scenes.rb's own
# export_pages() to get the PNG, then flattens it onto white and trims dead
# margins with wr-flatten-trim.py, because a SketchUp export is a transparent
# PNG and a transparent PNG must never reach a proposal pack
# (reference/proposal-playbook.md section 5). The hero (01-exterior) is
# flattened but NOT trimmed — its background is part of the picture, same
# rule as the playbook's manual step.
#
# V-RAY LANE — STUB ONLY, BEHIND A FINISHED INTERFACE. A scene is marked for
# V-Ray with a flag stored ON THE SCENE ITSELF (an attribute dictionary on the
# Sketchup::Page), so the marking survives a save and a hand-off the same way
# the plate names do. Unmarked is the default and the safe one. A marked scene
# is reported and SKIPPED, never exported through the viewport lane by
# mistake. This stub calls NOTHING under the VRay:: namespace — nobody has run
# scripts/probe-vray.rb yet, so nothing about V-Ray's Ruby API (whether
# VRay::Context.active works cold, whether start blocks, what save_vfb_image
# takes) is confirmed. That probe is the blocker for turning this lane on.
#
# THE PER-SCENE MODE SWITCH IS THE CORE OF THIS SCRIPT, NOT A NICETY. A run
# that flips the whole model to render once and then exports all five would
# ship 02-dimensioned with no dimensions on it. Each plate gets its own
# WR_Mode.to_draft / WR_Mode.to_render call, immediately before its own
# export, and the model's original mode is restored once every plate is done.
#
# PREFLIGHT RUNS FIRST. wr-preflight.rb's checks are read and, if anything is
# failing, shown before export starts — Continue / Cancel is the operator's
# call, this script does not decide it.
#
# NEVER OVERWRITES WITHOUT ASKING. If any of the five target files already
# exist in the destination folder, this asks before touching them — same
# house rule export-scenes.rb already follows for a manual run.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-pack-export.rb"
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp, so nothing here has executed — only parsed with rbparse.py, which
# checks syntax, not behaviour.

require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'tmpdir'

$wr_no_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-preflight.rb')     # also loads wr-mode.rb,
  load File.join(File.dirname(__FILE__), 'export-scenes.rb')    # wr-materials-swap.rb and
  load File.join(File.dirname(__FILE__), 'proposal-scenes.rb')  # proposal-scenes.rb itself
ensure
  $wr_no_autorun = $wr_no_autorun_was
end

module WR_PackExport
  DICT_MARK = 'WR_PackExport'.freeze
  PREF      = 'WR_PackExport'.freeze

  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # -------------------------------------------------------------- marking --

  def self.marked?(page)
    page.get_attribute(DICT_MARK, 'vray', false) ? true : false
  rescue StandardError
    false
  end

  def self.set_marked(page, on)
    page.set_attribute(DICT_MARK, 'vray', on ? true : false)
  end

  # ---------------------------------------------------------------- plates --

  def self.plate_mode(name)
    name == '02-dimensioned' ? 'draft' : 'render'
  end

  # Read live off the model every time this is called — a page can be marked
  # or a scene renamed between one dialog paint and the next.
  def self.plates(model)
    WR_ProposalScenes::PLATES.map do |p|
      name = p[:name]
      page = model.pages[name]
      { 'name' => name, 'found' => !page.nil?,
        'mode' => plate_mode(name),
        'vray' => page ? marked?(page) : false }
    end
  end

  def self.sanitize(s)
    s.to_s.strip.gsub(FORBIDDEN, '-').sub(/[. ]+\z/, '')
  end

  # ----------------------------------------------------------------- export --

  # The real work. `client` names the ProposalFiles subfolder; `dir` is the
  # already-resolved destination path. Returns a report hash the dialog and
  # the console both render from — nothing here talks to the UI directly, so
  # export_all can be re-used from a future headless path without change.
  def self.export_all(model, client, dir)
    report = { 'client' => client, 'dir' => dir, 'rows' => [], 'aborted' => false }

    pf_rows = begin
      WR_Preflight.check(model)
    rescue StandardError => e
      report['preflight_error'] = "#{e.class}: #{e.message}"
      nil
    end
    report['preflight'] = pf_rows

    failing = (pf_rows || []).select { |r| r['status'] == 'fail' }
    unless failing.empty?
      lines = failing.map { |r| "  - #{r['label']}: #{r['detail']}" }.join("\n")
      go = UI.messagebox("Preflight found #{failing.size} issue(s):\n\n#{lines}\n\n" \
                         'Continue the export anyway?', MB_YESNO)
      unless go == IDYES
        report['aborted'] = true
        report['reason'] = 'stopped at preflight'
        return report
      end
    end

    plates = self.plates(model)
    missing = plates.reject { |p| p['found'] }
    unless missing.empty?
      puts "  MISSING SCENES (not exported): #{missing.map { |p| p['name'] }.join(', ')}"
      puts "  Run 'Set up the five proposal plates' first to create them."
    end
    found = plates.select { |p| p['found'] }
    if found.empty?
      report['aborted'] = true
      report['reason'] = 'no plate scenes found in this model'
      return report
    end

    FileUtils.mkdir_p(dir)

    existing = found.reject { |p| p['vray'] }.select { |p| File.exist?(File.join(dir, "#{p['name']}.png")) }
    overwrite = true
    unless existing.empty?
      names = existing.map { |p| p['name'] }.join(', ')
      ans = UI.messagebox("These files already exist in\n#{dir}:\n\n  #{names}\n\n" \
                          "Overwrite them? Yes overwrites, No skips just those and keeps going.",
                          MB_YESNOCANCEL)
      if ans == IDCANCEL
        report['aborted'] = true
        report['reason'] = 'stopped — files already existed'
        return report
      end
      overwrite = (ans == IDYES)
    end

    saved_mode = WR_Mode.current(model)
    prev_page   = model.pages.selected_page
    prev_camera = (model.active_view.camera.clone rescue nil)

    stage = File.join(Dir.tmpdir, "wr-pack-export-#{Time.now.to_i}")
    FileUtils.mkdir_p(stage)

    begin
      found.each do |p|
        page = model.pages[p['name']]
        row = { 'name' => p['name'], 'mode' => p['mode'] }

        if p['vray']
          row['lane'] = 'vray'
          row['status'] = 'skipped'
          row['detail'] = 'V-RAY LANE NOT IMPLEMENTED — probe-vray.rb has not been run; nothing ' \
                          'about the V-Ray Ruby API is confirmed. Marked scenes are skipped rather ' \
                          'than exported the wrong way.'
          report['rows'] << row
          next
        end
        row['lane'] = 'viewport'

        final_path = File.join(dir, "#{p['name']}.png")
        if File.exist?(final_path) && !overwrite
          row['status'] = 'skipped'
          row['detail'] = 'already existed, overwrite declined'
          report['rows'] << row
          next
        end

        model.pages.selected_page = page
        model.active_view.refresh
        mode_result = p['mode'] == 'draft' ? WR_Mode.to_draft(model) : WR_Mode.to_render(model)
        model.active_view.refresh

        raw_path = File.join(stage, "#{p['name']}.png")
        plan = [{ :page => page, :n => 0, :base => p['name'] }]
        cfg  = { 'dir' => stage, 'width' => '2400', 'bg' => 'Transparent', 'over' => 'Yes' }
        x = WR_ExportScenes.export_pages(model, plan, cfg)

        if x[:written].zero?
          row['status'] = 'failed'
          row['detail'] = 'view.write_image failed — see console'
          report['rows'] << row
          next
        end

        fixer = File.join(File.dirname(__FILE__), 'wr-flatten-trim.py')
        no_trim = p['name'] == '01-exterior' ? ' --no-trim' : ''
        cmd = "python \"#{fixer.tr('/', '\\')}\" \"#{raw_path.tr('/', '\\')}\" " \
              "\"#{final_path.tr('/', '\\')}\"#{no_trim}"
        puts "  #{cmd}"
        ok = system(cmd)

        if ok
          row['status'] = 'exported'
          mat = mode_result[:materials]
          unmapped = (mat && (mat[:unmapped] || mat[:left])) || []
          row['detail'] = final_path.to_s
          row['unmapped'] = unmapped
        else
          row['status'] = 'failed'
          row['detail'] = "flatten/trim step failed — raw export kept at #{raw_path}. " \
                          'Is python on PATH, and is Pillow installed?'
        end
        report['rows'] << row
      end
    ensure
      begin
        WR_Mode.to_mode(model, saved_mode) if %w[draft render].include?(saved_mode)
      rescue StandardError => e
        puts "  *** could not restore original mode (#{saved_mode.inspect}): #{e.class}: #{e.message}"
      end
      model.pages.selected_page = prev_page if prev_page
      (model.active_view.camera = prev_camera) rescue nil if prev_camera
      begin
        FileUtils.rm_rf(stage)
      rescue StandardError
        nil
      end
    end

    report
  end

  # ------------------------------------------------------------------ panel --

  def self.default_dir(client)
    root = (ENV['USERPROFILE'] || 'C:/Users/bento').tr('\\', '/')
    File.join(root, 'Desktop', 'ProposalFiles', sanitize(client))
  end

  def self.report_lines(report)
    lines = ['']
    if report['aborted']
      lines << "PACK EXPORT — stopped (#{report['reason']})"
      return lines
    end
    lines << "PACK EXPORT — #{report['client']}"
    lines << "  #{report['dir']}"
    report['rows'].each do |r|
      lines << format('  %-16s %-9s %-8s %s', r['name'], r['lane'], r['status'], r['detail'])
      (r['unmapped'] || []).each { |u| lines << "        unmapped: #{u}" }
    end
    lines << ''
    lines
  end

  def self.run
    model = Sketchup.active_model
    d = UI::HtmlDialog.new(
      :dialog_title    => 'Export client pack',
      :preferences_key => 'com.whisperroom.packexport',
      :scrollable      => true,
      :resizable       => true,
      :width           => 660,
      :height          => 560,
      :min_width       => 480,
      :min_height      => 420,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )

    client_default = Sketchup.read_default(PREF, 'client', '').to_s
    d.set_html(html(client_default, plates(model)))

    d.add_action_callback('mark') do |_c, payload|
      begin
        data = JSON.parse(payload)
        page = model.pages[data['name'].to_s]
        set_marked(page, data['on'] ? true : false) if page
      rescue StandardError => e
        puts "  mark failed: #{e.class}: #{e.message}"
      end
      d.execute_script("renderPlates(#{plates(model).to_json})")
    end

    d.add_action_callback('refresh') { |_c| d.execute_script("renderPlates(#{plates(model).to_json})") }

    d.add_action_callback('export') do |_c, payload|
      begin
        data = JSON.parse(payload)
        client = data['client'].to_s.strip
        if client.empty?
          UI.messagebox('Type the client name first.')
        else
          Sketchup.write_default(PREF, 'client', client)
          dir = data['dir'].to_s.strip
          dir = default_dir(client) if dir.empty?
          report = export_all(model, client, dir)
          lines = report_lines(report)
          lines.each { |l| puts l }
          UI.messagebox(lines.join("\n"))
          d.execute_script("renderPlates(#{plates(model).to_json})")
        end
      rescue StandardError => e
        UI.messagebox("Export failed:\n\n#{e.class}: #{e.message}")
        puts "FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(5)
      end
    end

    d.add_action_callback('default_dir') do |_c, client|
      d.execute_script("setDir(#{default_dir(client).to_json})")
    end

    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  rescue StandardError => e
    UI.messagebox("Export client pack failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.html(client_default, plates)
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Export client pack</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  .top { padding:12px 14px 8px; }
  .top .t { font-weight:650; }
  .field { margin:0 14px 8px; display:flex; gap:8px; align-items:center; }
  .field label { font-size:10.5px; font-weight:650; letter-spacing:.08em; color:var(--faint);
                 width:70px; flex:0 0 auto; }
  .field input { flex:1 1 auto; font:inherit; padding:6px 8px; border:1px solid var(--line);
                 border-radius:6px; background:var(--surface); color:var(--ink); }
  .field input:focus { border-color:var(--accent); outline:none; }
  .wrap { flex:1 1 auto; overflow:auto; margin:0 14px 10px; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; }
  table { width:100%; border-collapse:collapse; }
  th { position:sticky; top:0; background:var(--surface); text-align:left; font-size:10.5px;
       font-weight:650; letter-spacing:.08em; color:var(--faint); padding:7px 9px;
       border-bottom:1px solid var(--line); }
  td { padding:7px 9px; border-top:1px solid var(--line); vertical-align:middle; }
  td.miss { color:var(--faint); font-style:italic; }
  .lane { font-size:11px; padding:2px 7px; border-radius:10px; background:#eef1f2; color:var(--muted); }
  .lane.vray { background:var(--soft); color:var(--accent); font-weight:650; }
  .bar { padding:0 14px 14px; display:flex; gap:8px; align-items:center; }
  .btn { font:inherit; font-size:12.5px; padding:8px 16px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; font-weight:650; margin-left:auto; }
  .note { padding:0 14px 10px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top"><span class="t">Export client pack</span></div>

<div class="field">
  <label>CLIENT</label>
  <input id="client" placeholder="Client folder name" value="#{escAttr(client_default)}" autofocus>
</div>
<div class="field">
  <label>FOLDER</label>
  <input id="dir" placeholder="Desktop/ProposalFiles/&lt;Client&gt; — leave blank to use the default">
</div>

<div class="wrap"><table>
  <thead><tr><th>PLATE</th><th>MODE NEEDED</th><th>LANE</th></tr></thead>
  <tbody id="body"></tbody>
</table></div>

<div class="note">
  Viewport lane is live and is the default. Tick V-Ray only if you know that scene is meant to
  be routed there — the V-Ray lane is a stub and will be reported as skipped, not exported.
</div>

<div class="bar">
  <button class="btn" id="refresh">Refresh</button>
  <button class="btn" id="close">Close</button>
  <button class="btn p" id="export">Export pack</button>
</div>

<script>
(function () {
  "use strict";
  function esc(s) { return String(s == null ? "" : s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

  window.setDir = function (d) {
    var el = document.getElementById("dir");
    if (!el.value) el.value = d;
  };

  window.renderPlates = function (plates) {
    var b = document.getElementById("body");
    b.innerHTML = plates.map(function (p) {
      if (!p.found) {
        return "<tr><td class='miss'>" + esc(p.name) + " — not found</td><td class='miss'>" +
               esc(p.mode) + "</td><td class='miss'>run \\"Set up the five proposal plates\\" first</td></tr>";
      }
      return "<tr><td>" + esc(p.name) + "</td><td>" + esc(p.mode) + "</td><td>" +
        "<label><input type='checkbox' data-name='" + esc(p.name) + "' " + (p.vray ? "checked" : "") + "> " +
        "<span class='lane " + (p.vray ? "vray" : "") + "'>" + (p.vray ? "V-Ray (stub)" : "viewport") +
        "</span></label></td></tr>";
    }).join("");
    Array.prototype.forEach.call(b.querySelectorAll("input[type=checkbox]"), function (cb) {
      cb.addEventListener("change", function () {
        sketchup.mark(JSON.stringify({ name: cb.getAttribute("data-name"), on: cb.checked }));
      });
    });
  };

  document.getElementById("client").addEventListener("change", function () {
    sketchup.default_dir(this.value);
  });
  document.getElementById("refresh").addEventListener("click", function () { sketchup.refresh(); });
  document.getElementById("close").addEventListener("click", function () { sketchup.close(); });
  document.getElementById("export").addEventListener("click", function () {
    sketchup.export(JSON.stringify({
      client: document.getElementById("client").value,
      dir: document.getElementById("dir").value
    }));
  });

  renderPlates(#{plates.to_json});
  sketchup.default_dir(document.getElementById("client").value);
})();
</script>
</body></html>
    HTML
  end

  def self.escAttr(s)
    s.to_s.gsub('"', '&quot;')
  end
end

WR_PackExport.run unless $wr_no_autorun
