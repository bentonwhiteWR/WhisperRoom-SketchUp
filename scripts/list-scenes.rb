# @title List Scenes...
# @cat Scenes and images
# @rank 2
#
# Every scene with its NUMBER, in a window you can search, sort and tick — so
# "scenes 1-40" can be typed into the exporters knowing what it covers. Two
# hundred scenes named "(Left46Door)" are impossible to count by eye, and
# guessing the range is how half a run comes out wrong.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/list-scenes.rb"
#
# ABOUT THE ORDER, because it is the thing to get right here.
#
# The number is the scene's position in `model.pages`, counting from 1. That is
# the SAME index every exporter uses to resolve a Scenes field, so a number read
# here always selects the same scene there. The list is never re-sorted on the
# way out of Ruby: it is emitted in pages order and the window opens in pages
# order. Sorting by scene name or component in the window is a VIEW — the number
# column travels with each row and does not change.
#
# SEARCHING. Type words and every one of them has to appear somewhere in the
# scene name or the component name, in any order and anywhere inside a word:
# "wdo panel" and "panel wdo" both land on ENH 26.5Panel1648WDO_HX. Typing a
# range instead -- "1-40" or "3,7,12" -- filters to those SCENE NUMBERS, so an
# existing range can be checked before it is used. A bare number is both at
# once: these components are full of digits, so "1648" shows scene 1648 AND
# everything whose name contains 1648, rather than silently throwing the text
# search away.
#
# It is a snapshot, not an identifier. Drag a scene tab to a new position and
# every number after it shifts. Re-run after reordering.
#
# TICK ROWS AND IT BUILDS THE RANGE FOR YOU. Selecting scenes 1,2,3,5,9,10 gives
# "1-3,5,9-10", ready to paste into the exporters' Scenes field. That is the
# whole point of the window and the reason it beat a text file: the text file
# made you count.
#
# For each scene it also resolves WHICH COMPONENT that scene is looking at, by
# the same camera-target rule angled-component-art.rb uses, so the list answers
# "which numbers do I need" rather than only "what are they called".
#
# READ ONLY, with one deliberate exception: clicking a row's arrow ACTIVATES
# that scene, which moves the camera exactly as clicking its tab would. Nothing
# is written to the model.

require 'sketchup.rb'
require 'json'

module WR_ListScenes
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  # Same rule as the exporters: a scene's camera target names its subject, and
  # the nearest top-level instance to that target is what the scene is about.
  def self.subject_for(model, page)
    cam = (page.camera rescue nil)
    return nil if cam.nil?
    t = cam.target
    best = nil
    bestd = nil
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      bb = e.bounds
      next unless bb.valid?
      d = bb.contains?(t) ? 0.0 : t.distance(bb.center).to_f
      if bestd.nil? || d < bestd
        bestd = d
        best = e
      end
    end
    best
  end

  def self.component_name(e)
    return '(unresolved)' if e.nil?
    if e.is_a?(Sketchup::ComponentInstance)
      n = (e.definition.name.to_s.strip rescue '')
      return n unless n.empty? || n =~ AUTONAME
    end
    n = (e.name.to_s.strip rescue '')
    return n unless n.empty? || n =~ AUTONAME
    '(unnamed)'
  end

  def self.size_of(e)
    return '' if e.nil?
    bb = e.bounds
    return '' unless bb.valid?
    format('%.1f x %.1f x %.1f', bb.width.to_f, bb.height.to_f, bb.depth.to_f)
  end

  # each_with_index over model.pages, and nothing sorts it afterwards. The index
  # IS the number, so the two cannot disagree.
  def self.gather(model)
    model.pages.to_a.each_with_index.map do |page, i|
      subj = subject_for(model, page)
      { 'n' => i + 1, 'scene' => page.name.to_s,
        'comp' => component_name(subj), 'size' => size_of(subj) }
    end
  end

  def self.text_lines(model, rows)
    wn = [rows.map { |r| r['scene'].length }.max || 5, 5].max
    wc = [rows.map { |r| r['comp'].length }.max  || 9, 9].max
    out = ['']
    out << "SCENES IN #{model.title.to_s.empty? ? '(unsaved model)' : model.title}"
    out << "  #{rows.length} scenes, in scene-tab order."
    out << ''
    out << format("  %-4s %-#{wn}s  %-#{wc}s  %s", '#', 'SCENE', 'COMPONENT IT LOOKS AT', 'SIZE in (w x h x d)')
    out << '  ' + '-' * (4 + wn + wc + 26)
    rows.each do |r|
      out << format("  %-4d %-#{wn}s  %-#{wc}s  %s", r['n'], r['scene'], r['comp'], r['size'])
    end
    out << '  ' + '-' * (4 + wn + wc + 26)
    out << "  #{rows.length} scenes, #{rows.count { |r| r['comp'] == '(unresolved)' }} " \
           'of which resolve to no component.'
    out << ''
    out
  end

  # ------------------------------------------------------------------ window --

  def self.run
    model = Sketchup.active_model
    if model.nil? || model.pages.count.zero?
      UI.messagebox('This model has no scenes.')
      return
    end

    Sketchup.status_text = 'List Scenes: resolving what each scene looks at...'
    rows = gather(model)
    Sketchup.status_text = ''

    # The console copy stays. It costs nothing, it survives the window being
    # closed, and it is what gets pasted into a message when something is wrong.
    text_lines(model, rows).each { |l| puts l }

    title = model.title.to_s.empty? ? '(unsaved model)' : model.title

    d = UI::HtmlDialog.new(
      :dialog_title    => "Scenes — #{title}",
      :preferences_key => 'com.whisperroom.listscenes',
      :scrollable      => true,
      :resizable       => true,
      :width           => 620,
      :height          => 640,
      :min_width       => 420,
      :min_height      => 300,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    # set_html rather than set_file: no second file to install, nothing to get
    # out of step with the .rb, and the script stays runnable straight from the
    # scripts folder like every other one here.
    d.set_html(html(title, rows))

    d.add_action_callback('activate') do |_c, n|
      begin
        pg = model.pages.to_a[n.to_i - 1]
        model.pages.selected_page = pg if pg
      rescue Exception => e
        puts "could not activate scene #{n}: #{e.class}: #{e.message}"
      end
    end

    d.add_action_callback('savetext') do |_c|
      dir = (UI.select_directory(:title => 'Where should the scene list go?') rescue nil)
      unless dir.nil? || dir.to_s.empty?
        path = File.join(dir.to_s.tr('\\', '/'), '_scene-list.txt')
        begin
          File.open(path, 'w') { |f| text_lines(model, rows).each { |l| f.puts l } }
          puts "  saved #{path}"
          UI.messagebox("Saved:\n#{path}")
        rescue StandardError => e
          puts "  could not save: #{e.class}: #{e.message}"
          UI.messagebox("Could not save:\n#{e.class}: #{e.message}")
        end
      end
    end

    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  end

  def self.html(title, rows)
    data = rows.to_json
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Scenes</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  ::-webkit-scrollbar { width:9px; height:9px; }
  ::-webkit-scrollbar-thumb { background:#c9d0d5; border-radius:5px; }

  .top { padding:10px 12px 6px; display:flex; gap:8px; align-items:center; }
  .top .t { font-weight:650; margin-right:auto; }
  .top .c { color:var(--muted); font-size:12px; }
  .cmd { margin:0 12px 8px; }
  .cmd input { width:100%; padding:8px 10px; font:inherit; color:var(--ink);
    background:var(--surface); border:1px solid var(--line); border-radius:8px; outline:none; }
  .cmd input:focus { border-color:var(--accent); }

  /* The range strip is the reason this window exists, so it sits above the
     list and stays put while the list scrolls. */
  .pick { margin:0 12px 8px; padding:9px 11px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; display:flex;
          gap:8px; align-items:center; }
  .pick.on { border-color:var(--accent); background:var(--soft); }
  .pick .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .pick input { flex:1 1 auto; font:inherit; font-weight:600; padding:5px 8px;
    border:1px solid var(--line); border-radius:6px; background:#fff; color:var(--ink); }
  .btn { font:inherit; font-size:12px; padding:5px 11px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer;
         white-space:nowrap; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; }

  .wrap { flex:1 1 auto; overflow:auto; margin:0 12px 12px; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; }
  table { width:100%; border-collapse:collapse; }
  th { position:sticky; top:0; background:var(--surface); text-align:left;
       font-size:10.5px; font-weight:650; letter-spacing:.09em; color:var(--faint);
       padding:8px 9px; border-bottom:1px solid var(--line); cursor:pointer;
       white-space:nowrap; z-index:2; }
  th:hover { color:var(--accent); }
  th .ar { color:var(--accent); }
  td { padding:6px 9px; border-top:1px solid var(--line); vertical-align:top; }
  tr:hover td { background:#f8f4f1; }
  tr.sel td { background:var(--soft); }
  td.n { font-variant-numeric:tabular-nums; color:var(--muted); width:1%; white-space:nowrap; }
  td.sz { color:var(--faint); font-size:11.5px; white-space:nowrap; }
  td.go { width:1%; }
  .go button { border:0; background:transparent; color:var(--faint); cursor:pointer;
               font-size:13px; padding:0 4px; }
  .go button:hover { color:var(--accent); }
  .un { color:#b0402c; }
  mark { background:#ffe3a8; color:inherit; border-radius:2px; }
  .foot { padding:0 12px 10px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">#{title}</span>
  <span class="c" id="count"></span>
  <button class="btn" id="save">Save as text</button>
</div>

<div class="cmd">
  <input id="q" placeholder="Search scene or component — several words, any order — or a range like 1-40" autofocus
         autocomplete="off" spellcheck="false">
</div>

<div class="pick" id="pick">
  <span class="lbl">RANGE</span>
  <input id="spec" readonly value="tick rows to build a range">
  <button class="btn" id="all">All shown</button>
  <button class="btn" id="none">Clear</button>
  <button class="btn p" id="copy">Copy</button>
</div>

<div class="wrap"><table>
  <thead><tr>
    <th data-k="n">#<span class="ar"></span></th>
    <th data-k="scene">SCENE<span class="ar"></span></th>
    <th data-k="comp">COMPONENT IT LOOKS AT<span class="ar"></span></th>
    <th data-k="size">SIZE<span class="ar"></span></th>
    <th></th>
  </tr></thead>
  <tbody id="body"></tbody>
</table></div>

<div class="foot">
  # is the scene's position in the tabs, left to right — the same number the
  exporters use. Sorting changes the view, never the number. The arrow jumps to
  that scene.
</div>

<script>
(function () {
  "use strict";
  var ROWS = #{data};
  var sel = {}, sortK = "n", sortA = true, view = ROWS.slice();

  var $q = document.getElementById("q"), $b = document.getElementById("body"),
      $spec = document.getElementById("spec"), $pick = document.getElementById("pick"),
      $count = document.getElementById("count");

  function esc(s) {
    return String(s == null ? "" : s).replace(/&/g, "&amp;")
      .replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  // Marks EVERY occurrence of EVERY search term. Spans are collected on the raw
  // text and each piece is escaped as it is emitted — escaping first and then
  // slicing would cut an entity like &amp; in half.
  function hl(t, ts) {
    var s = String(t == null ? "" : t);
    if (!ts || !ts.length) return esc(s);
    var lo = s.toLowerCase(), spans = [];
    ts.forEach(function (term) {
      if (!term) return;
      var i = lo.indexOf(term);
      while (i >= 0) { spans.push([i, i + term.length]); i = lo.indexOf(term, i + term.length); }
    });
    if (!spans.length) return esc(s);
    spans.sort(function (a, b) { return a[0] - b[0] || a[1] - b[1]; });
    var out = "", at = 0;
    spans.forEach(function (sp) {
      if (sp[1] <= at) return;                       // wholly inside one already marked
      var a = sp[0] > at ? sp[0] : at;               // overlap: start where the last one ended
      out += esc(s.slice(at, a)) + "<mark>" + esc(s.slice(a, sp[1])) + "</mark>";
      at = sp[1];
    });
    return out + esc(s.slice(at));
  }

  // Every whitespace-separated term must appear somewhere in scene + component,
  // in any order: "wdo panel" and "panel wdo" both find ENH 26.5Panel1648WDO_HX.
  function terms(q) {
    return q.toLowerCase().split(/\\s+/).filter(function (t) { return t.length > 0; });
  }
  function textHit(r, ts) {
    var s = (r.scene + " " + r.comp).toLowerCase();
    for (var i = 0; i < ts.length; i++) { if (s.indexOf(ts[i]) < 0) return false; }
    return ts.length > 0;
  }

  // "1-3,5,9-10" out of [1,2,3,5,9,10]. Consecutive runs collapse, which is what
  // makes the result short enough to actually paste.
  function toSpec(ns) {
    ns = ns.slice().sort(function (a, b) { return a - b; });
    var out = [], i = 0;
    while (i < ns.length) {
      var a = ns[i], b = a;
      while (i + 1 < ns.length && ns[i + 1] === b + 1) { b = ns[++i]; }
      out.push(a === b ? String(a) : a + "-" + b);
      i++;
    }
    return out.join(",");
  }

  // A search box that also takes "1-40" or "3,7,12": typing numbers filters to
  // those scenes, so an existing range can be checked before it is used.
  //
  // But component names here are heavily numeric — ENH 10242FL SIDE, 4896,
  // ENH 26.5Panel1648WDO_HX — so a BARE number is ambiguous. Reading "1648" as
  // "scene 1648" and dropping the text search is what made mid-name search look
  // broken. So `.only` is true, meaning scene numbers alone, ONLY when the query
  // is unambiguously a list or a range (it carries a comma or a hyphen). A bare
  // number stays a text search too, and draw() takes the union.
  function parseNums(q) {
    if (!/^[\\d\\s,\\-]+$/.test(q)) return null;
    var want = {}, only = /[,\\-]/.test(q);
    q.split(",").forEach(function (tok) {
      tok = tok.trim(); if (!tok) return;
      var m = tok.match(/^(\\d+)\\s*-\\s*(\\d+)$/);
      if (m) { var a = +m[1], b = +m[2]; if (a > b) { var t = a; a = b; b = t; }
               for (var k = a; k <= b; k++) want[k] = 1; }
      else if (/^\\d+$/.test(tok)) want[+tok] = 1;
    });
    return Object.keys(want).length ? { want: want, only: only } : null;
  }

  function draw() {
    var q = $q.value.trim(), nums = parseNums(q), ts = terms(q);
    view = ROWS.filter(function (r) {
      if (!q) return true;
      if (nums && nums.only) return !!nums.want[r.n];   // "1-40" / "3,7,12"
      if (nums && nums.want[r.n]) return true;          // bare "12" keeps scene 12
      return textHit(r, ts);
    });
    view.sort(function (a, b) {
      var x = a[sortK], y = b[sortK];
      if (sortK !== "n") { x = String(x).toLowerCase(); y = String(y).toLowerCase(); }
      if (x < y) return sortA ? -1 : 1;
      if (x > y) return sortA ? 1 : -1;
      return a.n - b.n;
    });

    var hi = (nums && nums.only) ? [] : ts;
    $b.innerHTML = view.map(function (r) {
      return '<tr class="' + (sel[r.n] ? "sel" : "") + '" data-n="' + r.n + '">' +
        '<td class="n">' + r.n + "</td>" +
        "<td>" + hl(r.scene, hi) + "</td>" +
        '<td class="' + (r.comp === "(unresolved)" ? "un" : "") + '">' + hl(r.comp, hi) + "</td>" +
        '<td class="sz">' + esc(r.size) + "</td>" +
        '<td class="go"><button data-go="' + r.n + '" title="Go to this scene">&#8594;</button></td>' +
        "</tr>";
    }).join("");

    Array.prototype.forEach.call($b.querySelectorAll("tr"), function (tr) {
      tr.addEventListener("click", function () {
        var n = +tr.dataset.n;
        if (sel[n]) { delete sel[n]; } else { sel[n] = 1; }
        draw();
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-go]"), function (el) {
      el.addEventListener("click", function (e) {
        e.stopPropagation();
        if (window.sketchup && sketchup.activate) sketchup.activate(el.dataset.go);
      });
    });

    Array.prototype.forEach.call(document.querySelectorAll("th[data-k]"), function (th) {
      th.querySelector(".ar").textContent =
        th.dataset.k === sortK ? (sortA ? "  \\u25b2" : "  \\u25bc") : "";
    });

    var picked = Object.keys(sel).map(Number);
    $spec.value = picked.length ? toSpec(picked) : "tick rows to build a range";
    $pick.className = picked.length ? "pick on" : "pick";
    $count.textContent = view.length === ROWS.length
      ? ROWS.length + " scenes" + (picked.length ? "  ·  " + picked.length + " ticked" : "")
      : view.length + " of " + ROWS.length + (picked.length ? "  ·  " + picked.length + " ticked" : "");
  }

  Array.prototype.forEach.call(document.querySelectorAll("th[data-k]"), function (th) {
    th.addEventListener("click", function () {
      if (sortK === th.dataset.k) { sortA = !sortA; } else { sortK = th.dataset.k; sortA = true; }
      draw();
    });
  });
  $q.addEventListener("input", draw);
  document.getElementById("all").addEventListener("click", function () {
    view.forEach(function (r) { sel[r.n] = 1; }); draw();
  });
  document.getElementById("none").addEventListener("click", function () { sel = {}; draw(); });
  document.getElementById("copy").addEventListener("click", function () {
    $spec.removeAttribute("readonly");
    $spec.select(); $spec.setSelectionRange(0, 9999);
    try { document.execCommand("copy"); } catch (e) { /* select-and-Ctrl+C still works */ }
    $spec.setAttribute("readonly", "readonly");
  });
  document.getElementById("save").addEventListener("click", function () {
    if (window.sketchup && sketchup.savetext) sketchup.savetext();
  });

  draw();
}());
</script></body></html>
    HTML
  end
end

begin
  WR_ListScenes.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("List Scenes failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
