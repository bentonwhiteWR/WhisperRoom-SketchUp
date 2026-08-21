# @title Prefix Every Scene...
# @cat Tidy up the model
#
# prefix-scenes.rb — put a prefix on the FRONT of every scene name in the
# model. Built for "ENH", which is what it is defaulted to, but the prefix is
# a field so the same button does "STD ", "REV B " or anything else.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/prefix-scenes.rb"
#
# ===========================================================================
# THIS ONE CHANGES THE MODEL, so it behaves the way find-replace-names.rb
# does, for the same reasons:
#
#   * NOTHING HAPPENS UNTIL YOU PRESS APPLY. The window opens on a preview
#     of every scene and what it would become. Type in the prefix box and the
#     preview re-reads itself.
#   * The whole rename is ONE undo step. Ctrl+Z puts every name back.
#   * It REFUSES to run if the result would collide. SketchUp silently
#     appends " (2)" when two scenes end up sharing a name, which is exactly
#     the mess these tidy-up scripts exist to clean, so a rename that would
#     make one is reported and the run is abandoned rather than half-applied.
#
# ===========================================================================
# RUNNING IT TWICE MUST NOT GIVE YOU "ENH ENH"
#
# A scene whose name already starts with the prefix is SKIPPED, and the window
# says so on its own row rather than silently leaving it out of the list. That
# is the difference between a button you can press twice without thinking and
# one you have to remember the state of.
#
# The check is case-sensitive on purpose. "ENH " and "enh " are different
# prefixes, and a tool that quietly treated them as the same would be making a
# naming decision that is not its to make.
#
# ===========================================================================
# THE PREVIEW IS COMPUTED IN RUBY, NOT IN JAVASCRIPT
#
# The window could compute its own preview from the name list in one line of
# JS. It does not, because then there would be two implementations of "what
# does this prefix do" and they would eventually disagree — the panel already
# learned this the hard way with toolbar slot faces. Every keystroke asks Ruby,
# and Ruby answers with the same method that Apply uses.

require 'sketchup.rb'
require 'json'

module WR_PrefixScenes
  PREF    = 'WR_PrefixScenes'.freeze
  DEFAULT = 'ENH '.freeze

  # ------------------------------------------------------------------ prefs --

  def self.read_pref(key, fallback)
    v = Sketchup.read_default(PREF, key, fallback)
    v.nil? ? fallback : v.to_s
  rescue StandardError
    fallback
  end

  def self.write_pref(key, value)
    Sketchup.write_default(PREF, key, value.to_s)
  rescue StandardError
    nil
  end

  # ------------------------------------------------------------------ model --

  def self.pages(model)
    model.nil? ? [] : model.pages.to_a
  rescue StandardError
    []
  end

  # THE ONE RULE. Apply and the preview both come through here, so they cannot
  # drift apart. Returns the new name, or nil when the scene should be left
  # alone.
  def self.renamed(name, prefix)
    return nil if prefix.empty?
    return nil if name.start_with?(prefix)
    prefix + name
  end

  # Everything the window needs, for a given prefix. Rows carry their own
  # state so the JS never has to work out what a row means.
  def self.plan(model, prefix)
    all = pages(model)
    rows = []
    changes = []

    # Names that will still exist untouched after the run — a rename landing on
    # one of these is a collision.
    staying = {}
    all.each do |p|
      n = p.name.to_s
      staying[n.downcase] = n if renamed(n, prefix).nil?
    end

    seen = {}
    all.each do |p|
      old = p.name.to_s
      nn  = renamed(old, prefix)

      if nn.nil?
        rows << { 'old' => old, 'new' => old,
                  'state' => prefix.empty? ? 'wait' : 'skip',
                  'note'  => prefix.empty? ? 'enter a prefix' : 'already starts with it' }
        next
      end

      key = nn.downcase
      if staying.key?(key)
        rows << { 'old' => old, 'new' => nn, 'state' => 'clash',
                  'note' => "collides with #{staying[key]}" }
      elsif seen.key?(key)
        rows << { 'old' => old, 'new' => nn, 'state' => 'clash',
                  'note' => "collides with #{seen[key]}" }
      else
        seen[key] = old
        rows << { 'old' => old, 'new' => nn, 'state' => 'go', 'note' => '' }
        changes << [p, nn]
      end
    end

    { 'prefix'  => prefix,
      'rows'    => rows,
      'total'   => all.length,
      'go'      => changes.length,
      'skipped' => rows.count { |r| r['state'] == 'skip' },
      'clashes' => rows.count { |r| r['state'] == 'clash' } }
  end

  # --------------------------------------------------------------- applying --

  def self.apply(model, prefix)
    info = plan(model, prefix)
    return [0, ["#{info['clashes']} name collision(s) — nothing changed."]] if info['clashes'] > 0
    return [0, []] if info['go'].zero?

    # Recompute the targets here rather than carrying Page objects through the
    # JSON. A page could have been deleted in another window between the
    # preview and the press.
    todo = []
    pages(model).each do |p|
      nn = renamed(p.name.to_s, prefix)
      todo << [p, nn] unless nn.nil?
    end

    done   = 0
    failed = []
    # One operation, so the whole rename is a single Ctrl+Z. The `true`
    # suppresses the per-change UI refresh, which matters at a few hundred
    # scenes.
    model.start_operation('Prefix Every Scene', true)
    begin
      todo.each do |p, nn|
        begin
          p.name = nn
          done += 1
        rescue StandardError => e
          failed << "#{p.name}: #{e.class}: #{e.message}"
        end
      end
      model.commit_operation
    rescue Exception => e
      model.abort_operation
      raise e
    end

    [done, failed]
  end

  # ----------------------------------------------------------------- window --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end

    if pages(model).empty?
      UI.messagebox("This model has no scenes.\n\n" \
                    'Add one with View > Animation > Add Scene, then run this again.')
      return
    end

    prefix = read_pref('prefix', DEFAULT)
    info   = plan(model, prefix)

    puts ''
    puts '=' * 70
    puts "PREFIX EVERY SCENE — #{pages(model).length} scene(s) in this model"
    puts "  prefix #{prefix.inspect}   would rename #{info['go']}, " \
         "skip #{info['skipped']}, collide #{info['clashes']}"
    puts '  Nothing has changed — the window applies it.'
    puts '=' * 70

    d = UI::HtmlDialog.new(
      :dialog_title    => 'Prefix every scene',
      :preferences_key => 'com.whisperroom.prefixscenes',
      :scrollable      => true,
      :resizable       => true,
      :width           => 620,
      :height          => 560,
      :min_width       => 460,
      :min_height      => 380,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(info))

    # Every keystroke re-plans in Ruby. See the header — one rule, one place.
    d.add_action_callback('preview') do |_c, text|
      pfx = text.to_s
      write_pref('prefix', pfx)
      d.execute_script("render(#{plan(model, pfx).to_json})")
    end

    d.add_action_callback('apply') do |_c, text|
      pfx = text.to_s
      begin
        done, failed = apply(model, pfx)
        if done.zero?
          UI.messagebox(failed.empty? ? 'Nothing to rename.' : failed.join("\n"))
        else
          puts "  renamed #{done} scene(s) with #{pfx.inspect}"
          failed.each { |f| puts "  FAILED  #{f}" }
          puts '  Ctrl+Z undoes the whole run.'
          UI.messagebox("Renamed #{done} scene#{done == 1 ? '' : 's'}." \
                        "#{failed.empty? ? '' : "\n\n#{failed.length} failed — see the Ruby Console."}" \
                        "\n\nCtrl+Z undoes the whole run.")
        end
      rescue StandardError => e
        puts "FAILED: #{e.class}: #{e.message}"
        UI.messagebox("Rename failed:\n\n#{e.class}: #{e.message}")
      end
      d.execute_script("render(#{plan(model, pfx).to_json})")
    end

    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  end

  # ------------------------------------------------------------------- html --

  def self.html(info)
    data = info.to_json
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Prefix every scene</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --go:#2e7d46; --clash:#b0402c; --skip:#9aa4ab; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  .top { padding:12px 14px 4px; display:flex; gap:8px; align-items:center; }
  .top .t { font-weight:650; margin-right:auto; }
  .btn { font:inherit; font-size:12px; padding:6px 12px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; }
  .btn.p:disabled { background:var(--skip); border-color:var(--skip); cursor:default; }
  .bar { padding:4px 14px 10px; display:flex; gap:10px; align-items:center; }
  .bar label { font-size:12px; color:var(--muted); }
  input[type=text] {
    font:13px ui-monospace,Consolas,monospace; padding:6px 9px; width:150px;
    border:1px solid var(--line); border-radius:6px; background:var(--surface); color:var(--ink);
  }
  input[type=text]:focus { outline:2px solid var(--accent); outline-offset:-1px; }
  .tally { font-size:12px; color:var(--muted); margin-left:auto; }
  .tally b { color:var(--ink); }
  .tally .c { color:var(--clash); font-weight:650; }
  .wrap { flex:1 1 auto; overflow:auto; margin:0 14px 8px; }
  table { width:100%; border-collapse:collapse; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; overflow:hidden; }
  th { text-align:left; font-size:10.5px; letter-spacing:.08em; text-transform:uppercase;
       color:var(--faint); font-weight:700; padding:8px 10px; border-bottom:1px solid var(--line); }
  td { padding:7px 10px; border-bottom:1px solid var(--line); font-size:12.5px;
       font-family:ui-monospace,Consolas,monospace; vertical-align:top; }
  tr:last-child td { border-bottom:0; }
  td.st { font-family:"Segoe UI",system-ui,sans-serif; font-size:10.5px; font-weight:700;
          letter-spacing:.06em; white-space:nowrap; }
  tr.go   td.st { color:var(--go); }
  tr.skip td, tr.wait td { color:var(--skip); }
  tr.clash td { color:var(--clash); }
  tr.clash { background:#fdf1ee; }
  td.note { font-family:"Segoe UI",system-ui,sans-serif; font-size:11.5px; color:var(--muted); }
  .warn { margin:0 14px 8px; padding:9px 12px; border-radius:8px; font-size:12px;
          background:var(--soft); border:1px solid #f0c3a6; color:#8a3a22; }
  .foot { padding:0 14px 12px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">Prefix every scene</span>
  <button class="btn p" id="apply">Apply</button>
  <button class="btn" id="close">Close</button>
</div>

<div class="bar">
  <label for="pfx">Prefix</label>
  <input type="text" id="pfx" spellcheck="false" autocomplete="off">
  <span class="tally" id="tally"></span>
</div>

<div class="warn" id="warn" style="display:none"></div>
<div class="wrap"><table id="tbl"><thead><tr>
  <th style="width:38%">Scene now</th><th style="width:38%">Becomes</th>
  <th style="width:9%">&nbsp;</th><th style="width:15%">&nbsp;</th>
</tr></thead><tbody id="rows"></tbody></table></div>
<div class="foot">Nothing changes until you press Apply, and Apply is one undo step.
  A scene already starting with the prefix is left alone, so pressing this twice is safe.</div>

<script>
(function () {
  "use strict";
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  }
  // A trailing space in a prefix is the whole point and is invisible in a
  // table, so spaces are drawn as visible middots in the BECOMES column only.
  function vis(s) { return esc(s).replace(/ /g, '<span style="opacity:.34">\\u00b7</span>'); }

  var $pfx = document.getElementById("pfx");
  var $rows = document.getElementById("rows");
  var $tally = document.getElementById("tally");
  var $warn = document.getElementById("warn");
  var $apply = document.getElementById("apply");
  var timer = null;

  var LABEL = { go: "RENAME", skip: "SKIP", clash: "CLASH", wait: "" };

  window.render = function (info) {
    if (document.activeElement !== $pfx) $pfx.value = info.prefix;

    $rows.innerHTML = (info.rows || []).map(function (r) {
      return '<tr class="' + r.state + '"><td>' + esc(r.old) + "</td><td>" +
             (r.state === "go" || r.state === "clash" ? vis(r.new) : "&mdash;") +
             '</td><td class="st">' + LABEL[r.state] + "</td>" +
             '<td class="note">' + esc(r.note) + "</td></tr>";
    }).join("");

    var bits = ["<b>" + info.go + "</b> to rename"];
    if (info.skipped) bits.push(info.skipped + " already prefixed");
    if (info.clashes) bits.push('<span class="c">' + info.clashes + " would collide</span>");
    $tally.innerHTML = bits.join(" &middot; ") + " &middot; " + info.total + " scenes";

    if (info.clashes) {
      $warn.style.display = "";
      $warn.textContent = info.clashes + " scene name(s) would collide with a scene that is " +
        "not being renamed. SketchUp would quietly append \\" (2)\\" to fix that, so nothing " +
        "will be applied until the collision is gone.";
    } else {
      $warn.style.display = "none";
    }

    $apply.disabled = !(info.go > 0 && !info.clashes);
    $apply.textContent = info.go > 0 && !info.clashes
      ? "Apply to " + info.go + " scene" + (info.go === 1 ? "" : "s")
      : "Apply";
  };

  $pfx.addEventListener("input", function () {
    clearTimeout(timer);
    timer = setTimeout(function () { sketchup.preview($pfx.value); }, 120);
  });
  $apply.addEventListener("click", function () {
    if (!$apply.disabled) sketchup.apply($pfx.value);
  });
  document.getElementById("close").addEventListener("click", function () { sketchup.close(); });

  render(#{data});
}());
</script>
</body></html>
    HTML
  end
end

begin
  WR_PrefixScenes.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Prefix Every Scene failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
