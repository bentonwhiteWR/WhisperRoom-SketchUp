# @title Pre-render checklist...
# @cat V-Ray renders
# @rank 4
#
# READ-ONLY until you press something. Five checks that catch the mistakes
# that come from switching draft <-> render by hand and from memory: a
# dimension string left on, a floor still wearing drafting white, a camera
# nudged off its saved scene, geometry left outside the room, and a camera
# that has ended up looking at the ceiling instead of the booth. Every
# failing row carries a Fix button that clears it — the window is the next
# step, not a report you then go act on somewhere else.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-preflight.rb"
#
# WHAT IS DELIBERATELY NOT HERE: a "lighting rig present" row. Rig placement
# was deferred on purpose and nothing in this repo maintains one, so a row
# claiming to verify it would be claiming to verify something that does not
# exist yet.
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp, so nothing here has executed — only parsed with rbparse.py, which
# checks syntax, not behaviour. The camera/scene-drift comparison and the
# ceiling raytest in particular are REPORTED from the documented SketchUp Ruby
# API, not observed working: both are wrapped so a wrong assumption about a
# method's signature shows up as a "could not evaluate" row instead of a
# crash or, worse, a false PASS.

require 'sketchup.rb'
require 'json'

$wr_no_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-mode.rb')
  load File.join(File.dirname(__FILE__), 'wr-materials-swap.rb')
  load File.join(File.dirname(__FILE__), 'proposal-scenes.rb')
ensure
  $wr_no_autorun = $wr_no_autorun_was
end

module WR_Preflight
  # -------------------------------------------------------------- checks --

  # 1. Any WhisperRoom dimension tag still visible.
  def self.check_dims(model)
    on = WR_Mode::DIM_TAGS.select { |n| l = model.layers[n]; l && l.visible? }
    if on.empty?
      { 'status' => 'pass', 'detail' => 'All dimension tags are off.' }
    else
      { 'status' => 'fail', 'detail' => "Visible: #{on.join(', ')}" }
    end
  end

  # 2. Floor still on the drafting material.
  def self.check_floor(model)
    hits = WR_ProposalScenes.tagged(model, 'WR-Floor')
    drafting = hits.select { |e| (e.material.name rescue nil) == WR_MaterialsSwap::DRAFT_FLOOR }
    if hits.empty?
      { 'status' => 'skip', 'detail' => 'No WR-Floor tagged geometry in this model.' }
    elsif drafting.empty?
      { 'status' => 'pass', 'detail' => 'Floor is not on the drafting material.' }
    else
      { 'status' => 'fail',
        'detail' => "#{drafting.size} of #{hits.size} WR-Floor surface(s) still on " \
                    "#{WR_MaterialsSwap::DRAFT_FLOOR}." }
    end
  end

  # 3. Camera on a saved scene, not a nudged viewport.
  def self.check_scene(model)
    page = model.pages.selected_page
    return { 'status' => 'fail', 'detail' => 'No scene is selected.' } if page.nil?
    pc = (page.camera rescue nil)
    return { 'status' => 'skip', 'detail' => "Scene #{page.name.inspect} has no stored camera." } if pc.nil?
    vc = model.active_view.camera
    begin
      eye_d    = pc.eye.distance(vc.eye)
      target_d = pc.target.distance(vc.target)
      up_ang   = (pc.up.angle_between(vc.up) rescue 0.0) * 180.0 / Math::PI
      matched = eye_d <= 0.75 && target_d <= 0.75 && up_ang <= 0.5
      if matched
        { 'status' => 'pass', 'detail' => "Matches scene #{page.name.inspect}." }
      else
        { 'status' => 'fail',
          'detail' => format('Scene %s, but the view has drifted (eye %.1f in, target %.1f in, up %.1f deg).',
                             page.name.inspect, eye_d, target_d, up_ang) }
      end
    rescue StandardError => e
      { 'status' => 'skip', 'detail' => "Could not compare camera to scene: #{e.class}: #{e.message}" }
    end
  end

  # 4. Stray geometry outside the walls.
  def self.stray_bounds(model)
    room = WR_ProposalScenes.tagged(model, 'WR-Room') + WR_ProposalScenes.tagged(model, 'WR-Floor')
    bb = Geom::BoundingBox.new
    room.each { |e| bb.add(e.bounds) }
    bb
  end

  def self.stray_hits(model)
    bb = stray_bounds(model)
    return [] unless bb.valid?
    margin = 24.0 # inches — generous, this only needs to catch geometry left well outside
    lo = bb.min.offset(Geom::Vector3d.new(-margin, -margin, -margin))
    hi = bb.max.offset(Geom::Vector3d.new(margin, margin, margin))
    out = []
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Face)
      eb = (e.bounds rescue nil)
      next unless eb && eb.valid?
      inside = eb.min.x >= lo.x && eb.min.y >= lo.y && eb.max.x <= hi.x && eb.max.y <= hi.y
      out << e unless inside
    end
    out
  end

  def self.check_stray(model)
    bb = stray_bounds(model)
    return { 'status' => 'skip', 'detail' => 'No WR-Room / WR-Floor geometry to measure against yet.' } unless bb.valid?
    hits = stray_hits(model)
    if hits.empty?
      { 'status' => 'pass', 'detail' => 'Nothing sits outside the room by more than 24 in.' }
    else
      { 'status' => 'fail', 'detail' => "#{hits.size} item(s) sit outside the room. Select clears " \
                                        'them into the selection so you can move, tag or delete by hand.' }
    end
  end

  # 5. Ceiling geometry between the camera and the booth. Heuristic: cast a
  # ray from the eye toward the booth's bounding-box centre and see whether
  # anything NOT tagged WR-Booth-* is hit first. This cannot tell "ceiling"
  # from "some other obstruction" by name — it can only tell "something is in
  # the way that is not the booth itself" — so the detail line says exactly
  # that rather than overclaiming what was found.
  BOOTH_PREFIX = 'WR-Booth'.freeze

  def self.booth_bounds(model)
    out = []
    walk_prefix(model.entities, out, [], 0)
    bb = Geom::BoundingBox.new
    out.each { |e| bb.add(e.bounds) }
    bb
  end

  def self.walk_prefix(ents, out, chain, depth)
    return if depth > 6
    ents.each do |e|
      out << e if e.respond_to?(:layer) && e.layer && e.layer.name.to_s.start_with?(BOOTH_PREFIX)
      case e
      when Sketchup::Group then walk_prefix(e.entities, out, chain + [e], depth + 1)
      when Sketchup::ComponentInstance then walk_prefix(e.definition.entities, out, chain + [e], depth + 1)
      end
    end
  end

  def self.check_ceiling(model)
    bb = booth_bounds(model)
    return { 'status' => 'skip', 'detail' => 'No WR-Booth-* tagged geometry in this model yet.' } unless bb.valid?
    view = model.active_view
    eye = view.camera.eye
    target = bb.center
    vec = target - eye
    return { 'status' => 'skip', 'detail' => 'Camera is sitting on the booth centre.' } if vec.length < 1.0
    begin
      hit = model.raytest(eye, vec)
      return { 'status' => 'pass', 'detail' => 'Line of sight to the booth is clear (nothing hit).' } if hit.nil?
      point, path = hit
      on_booth = path.any? { |e| e.respond_to?(:layer) && e.layer && e.layer.name.to_s.start_with?(BOOTH_PREFIX) }
      dist_to_hit = eye.distance(point)
      dist_to_target = eye.distance(target)
      if on_booth || dist_to_hit >= dist_to_target - 1.0
        { 'status' => 'pass', 'detail' => 'The booth is the first thing this camera sees.' }
      else
        blocker = (path.last.respond_to?(:layer) && path.last.layer ? path.last.layer.name : path.last.class.to_s)
        { 'status' => 'fail',
          'detail' => "Something else (tagged #{blocker.inspect}) sits between the camera and the " \
                      'booth — heuristic only, this cannot confirm it is a ceiling by name.' }
      end
    rescue StandardError => e
      { 'status' => 'skip', 'detail' => "raytest could not run: #{e.class}: #{e.message} — " \
                                        'this SketchUp build may not support the call this way.' }
    end
  end

  # --------------------------------------------------------------------- run --

  ROWS = [
    { 'id' => 'dims',    'label' => 'Dimension tags off',        'fixable' => true },
    { 'id' => 'floor',   'label' => 'Floor off drafting white',  'fixable' => true },
    { 'id' => 'scene',   'label' => 'Camera on a saved scene',   'fixable' => true },
    { 'id' => 'stray',   'label' => 'No geometry outside walls', 'fixable' => false },
    { 'id' => 'ceiling', 'label' => 'Clear line of sight to the booth', 'fixable' => false }
  ].freeze

  def self.check(model)
    results = { 'dims' => check_dims(model), 'floor' => check_floor(model),
                'scene' => check_scene(model), 'stray' => check_stray(model),
                'ceiling' => check_ceiling(model) }
    ROWS.map do |r|
      c = results[r['id']]
      r.merge('status' => c['status'], 'detail' => c['detail'])
    end
  end

  def self.fix(model, id)
    case id
    when 'dims', 'floor'
      WR_Mode.to_render(model)
      nil
    when 'scene'
      page = model.pages.selected_page
      if page && (page.camera rescue nil)
        model.active_view.camera = page.camera
        model.active_view.refresh
      end
      nil
    else
      nil
    end
  rescue StandardError => e
    "#{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------------ window --

  def self.run
    model = Sketchup.active_model
    rows = check(model)
    rows.each { |r| puts format('  %-32s %-5s %s', r['label'], r['status'].upcase, r['detail']) }

    d = UI::HtmlDialog.new(
      :dialog_title    => 'Pre-render checklist',
      :preferences_key => 'com.whisperroom.preflight',
      :scrollable      => true,
      :resizable       => true,
      :width           => 620,
      :height          => 520,
      :min_width       => 440,
      :min_height       => 360,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(rows))

    d.add_action_callback('fix') do |_c, id|
      begin
        err = fix(model, id)
        UI.messagebox("Could not fix #{id}:\n\n#{err}") if err
      rescue StandardError => e
        UI.messagebox("Fix failed:\n\n#{e.class}: #{e.message}")
      end
      d.execute_script("render(#{check(model).to_json})")
    end

    d.add_action_callback('select_stray') do |_c|
      hits = stray_hits(model)
      sel = model.selection
      sel.clear
      hits.each { |e| sel.add(e) }
      begin
        model.active_view.zoom(sel) unless hits.empty?
      rescue StandardError
        nil
      end
      UI.messagebox(hits.empty? ? 'Nothing to select.' : "Selected #{hits.size} item(s).")
    end

    d.add_action_callback('ceiling_help') do |_c|
      UI.messagebox("Camera framing is a judgement call this checklist will not make for you.\n\n" \
                    "Nudge the camera (or re-aim and re-save the scene) so the booth is the first " \
                    "thing in view, then press Refresh.")
    end

    d.add_action_callback('refresh') { |_c| d.execute_script("render(#{check(model).to_json})") }
    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  rescue StandardError => e
    UI.messagebox("Preflight failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.html(rows)
    data = rows.to_json
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Preflight</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --pass:#2e7d46; --fail:#b0402c; --skip:#9aa4ab; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  .top { padding:12px 14px 8px; display:flex; gap:8px; align-items:center; }
  .top .t { font-weight:650; margin-right:auto; }
  .btn { font:inherit; font-size:12px; padding:6px 12px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; }
  .wrap { flex:1 1 auto; overflow:auto; margin:0 14px 14px; }
  .row { background:var(--surface); border:1px solid var(--line); border-radius:9px;
         padding:10px 12px; margin-bottom:8px; display:flex; gap:10px; align-items:flex-start; }
  .row.fail { border-color:#e3b3a4; }
  .dot { width:10px; height:10px; border-radius:50%; margin-top:4px; flex:0 0 auto; }
  .dot.pass { background:var(--pass); }
  .dot.fail { background:var(--fail); }
  .dot.skip { background:var(--skip); }
  .body { flex:1 1 auto; min-width:0; }
  .lbl { font-weight:650; }
  .det { color:var(--muted); font-size:12px; margin-top:2px; }
  .st { font-size:10.5px; font-weight:700; letter-spacing:.08em; color:var(--faint); margin-top:2px; }
  .st.fail { color:var(--fail); } .st.pass { color:var(--pass); }
  .fixbtn { flex:0 0 auto; }
  .foot { padding:0 14px 12px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">Pre-render checklist</span>
  <button class="btn" id="refresh">Refresh</button>
  <button class="btn" id="close">Close</button>
</div>
<div class="wrap" id="wrap"></div>
<div class="foot">Read-only until you press Fix or Select. This does not export or render anything.</div>

<script>
(function () {
  "use strict";
  function esc(s) { return String(s == null ? "" : s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

  window.render = function (rows) {
    var w = document.getElementById("wrap");
    w.innerHTML = rows.map(function (r) {
      var canFix = r.fixable && r.status === "fail";
      var canSelect = r.id === "stray" && r.status === "fail";
      var canHelp = r.id === "ceiling" && r.status === "fail";
      var btn = "";
      if (canFix) btn = '<button class="btn p fixbtn" data-fix="' + r.id + '">Fix</button>';
      else if (canSelect) btn = '<button class="btn fixbtn" data-select="1">Select</button>';
      else if (canHelp) btn = '<button class="btn fixbtn" data-help="1">How to fix</button>';
      return '<div class="row ' + (r.status === "fail" ? "fail" : "") + '">' +
        '<div class="dot ' + r.status + '"></div>' +
        '<div class="body"><div class="lbl">' + esc(r.label) + '</div>' +
          '<div class="det">' + esc(r.detail) + '</div>' +
          '<div class="st ' + r.status + '">' + r.status.toUpperCase() + '</div></div>' +
        btn + '</div>';
    }).join("");
    Array.prototype.forEach.call(w.querySelectorAll("[data-fix]"), function (b) {
      b.addEventListener("click", function () { sketchup.fix(b.getAttribute("data-fix")); });
    });
    Array.prototype.forEach.call(w.querySelectorAll("[data-select]"), function (b) {
      b.addEventListener("click", function () { sketchup.select_stray(); });
    });
    Array.prototype.forEach.call(w.querySelectorAll("[data-help]"), function (b) {
      b.addEventListener("click", function () { sketchup.ceiling_help(); });
    });
  };

  document.getElementById("refresh").addEventListener("click", function () { sketchup.refresh(); });
  document.getElementById("close").addEventListener("click", function () { sketchup.close(); });

  render(#{data});
})();
</script>
</body></html>
    HTML
  end
end

WR_Preflight.run unless $wr_no_autorun
