# @title Uniform callout font & colour...
# @cat Tidy up the model
#
# ONE font and ONE colour for every callout in the model — notes, dimensions
# and 3D labels — in a single click, instead of Entity Info on each one.
# Benton, 10 Sep 2026: "You can change all of the text or all of the
# dimensions font and color ... it could also be an all function. By default
# I would like to have everything the same font and the same color, whether
# that's text or dimensions. But being able to break that down in certain
# situations would also be helpful."
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-callout-style.rb"
#
# WHAT "A CALLOUT" IS IS NOT DECIDED HERE. wr-scene-annotations.rb owns that
# question — its kind_of (text / dim / 3d) and each_annotation (the walk, to
# its DEPTH, with a `label:` group as an item and never a container) are
# called directly. A second definition of "annotation" in the toolkit would
# be a defect: the per-scene picker and this sweep must always agree about
# which entities they mean.
#
# WHAT THE API CAN AND CANNOT DO, PER KIND. This is the shape of the tool,
# and it was read off ruby.sketchup.com and the SketchUp forum on 10 Sep
# 2026, not remembered:
#
#   text  Sketchup::Text#font= exists from SketchUp 2026.2 — a Hash of
#         :name / :size (points, 1..1000) / :bold / :italic; omitted keys
#         inherit. Colour is a MATERIAL (Drawingelement#material=), the same
#         thing Entity Info's swatch sets.
#   dim   Sketchup::Dimension has NO font method in any version — a request
#         open since 2015, still open in the 2026.2 docs, and there is no
#         "DimensionOptions" provider under model.options either. Colour IS
#         settable: material= on a dimension recolours it (forum, confirmed
#         working by the asker). So a dimension gets the colour and a
#         SKIP for the font, with the manual route named: Model Info >
#         Dimensions > Fonts, then Select all dimensions > Update.
#   3d    A 3D label is geometry from add_3d_text; its face is fixed at
#         creation and only a rebuild changes it. Colour is a material on
#         the group, which paints every default-material face in it (the
#         group-materials rule in reference/sketchup-drawing.md).
#
# NOTHING IS SKIPPED SILENTLY. Every callout the sweep could not restyle is
# counted under a reason and the reasons are printed in the dialog, so
# "30 dims got the colour but not the font" is a sentence on screen and
# never a surprise at the export.
#
# SCOPE. Whole model is the default (the "all function"). My selection and
# One set (a WR-Dims* / WR-Notes* tag, or Untagged) are there for the
# "certain situations". All three run through the same walk; the selection
# case descends into a selected group or component exactly the way the
# per-scene picker's Use-my-selection does.
#
# DEFAULTS. Last-used values win (per user, Sketchup.read_default). Before
# any are stored the house pair is Arial 12 regular and brand orange
# #ee6216: Arial is the face every add_3d_text in this repo asks for and the
# proposal brand card's "system grotesque (Arial/Helvetica)"; orange is what
# dimension-booth.rb and dimension-selection.rb already declare for their
# callout tags. A MATCH MAJORITY link fills in the font and colour most of
# the model's callouts already carry, for the job of pulling three odd ones
# into line with the other hundred.
#
# ONE UNDO. The whole sweep is one start_operation, so Ctrl+Z puts every
# callout back at once; an exception aborts the operation and leaves the
# model as it was.

require 'sketchup.rb'
require 'json'

# wr-scene-annotations.rb owns kind_of / each_annotation / tag_of, and loads
# proposal-scenes.rb (the tag family) itself. Loaded as a library only — a
# LOCAL holds the flag so a nested load cannot clobber it (the 2026-08-27
# dead-button bug, same guard as the annotations tool uses on its own load).
wr_cs_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-scene-annotations.rb')
ensure
  $wr_no_autorun = wr_cs_autorun_was
end

module WR_CalloutStyle
  PREF = 'WR_CalloutStyle'.freeze

  HOUSE_FONT = { :name => 'Arial', :size => 12, :bold => false, :italic => false }.freeze
  HOUSE_HEX  = '#ee6216'.freeze   # brand orange, CLAUDE.md

  # Materials this tool makes are named by their colour so that two sweeps
  # with two colours never fight over one material, and so a later sweep in
  # the same colour reuses the one it made rather than piling up copies.
  MAT_PREFIX = 'WR-Callout '.freeze

  KINDS = %w[text dim 3d].freeze
  KIND_LABEL = { 'text' => 'notes', 'dim' => 'dimensions', '3d' => '3D labels' }.freeze

  # The reasons a callout is skipped, worded once so the dialog and the
  # console cannot disagree.
  SKIP_DIM_FONT  = 'dimension font is not settable from Ruby (Model Info > Dimensions > Fonts, then Select all dimensions > Update)'.freeze
  SKIP_3D_FONT   = '3D label face is fixed geometry — rebuild the label to change it'.freeze
  SKIP_TEXT_FONT = 'this SketchUp cannot set text fonts (needs 2026.2 or later)'.freeze

  # ---------------------------------------------------------------- prefs --

  # read_default EVALS the stored string, so a font name with a quote in it
  # would come back as a SyntaxError — not a StandardError. Rescued wide, and
  # write_pref strips the quote, the same way find-replace-names.rb does.
  def self.read_pref(k, dflt)
    v = Sketchup.read_default(PREF, k, dflt)
    v.nil? ? dflt : v
  rescue Exception
    dflt
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.is_a?(String) ? v.delete('"') : v)
  rescue Exception
    nil
  end

  def self.defaults
    { 'name'   => read_pref('name', HOUSE_FONT[:name]).to_s,
      'size'   => read_pref('size', HOUSE_FONT[:size]).to_i,
      'bold'   => read_pref('bold', false) ? true : false,
      'italic' => read_pref('italic', false) ? true : false,
      'hex'    => read_pref('hex', HOUSE_HEX).to_s }
  end

  def self.remember(req)
    write_pref('name',   req[:font][:name])
    write_pref('size',   req[:font][:size])
    write_pref('bold',   req[:font][:bold])
    write_pref('italic', req[:font][:italic])
    write_pref('hex',    req[:hex])
  end

  # ------------------------------------------------------------- request --

  # A request from the dialog, checked. Returns [req, nil] or [nil, message].
  # PURE — no SketchUp calls — so rbtest-callout-style.py can run it. Shape
  # in:  { 'scope' => 'all' | 'sel' | 'tag:<name>', 'kinds' => [...],
  #        'font' => { 'on', 'name', 'size', 'bold', 'italic' },
  #        'color' => { 'on', 'hex' } }
  # Shape out: { :scope, :tag, :kinds, :font => {...} | nil, :hex | nil }.
  def self.normalise(r)
    r = {} unless r.is_a?(Hash)
    kinds = Array(r['kinds']).map(&:to_s).select { |k| KINDS.include?(k) }.uniq
    return [nil, 'Tick at least one of notes, dimensions or 3D labels.'] if kinds.empty?
    scope = r['scope'].to_s
    tag = nil
    if scope.start_with?('tag:')
      tag = scope.sub('tag:', '')
      return [nil, 'Pick a set.'] if tag.empty?
      scope = 'tag'
    elsif !%w[all sel].include?(scope)
      scope = 'all'
    end
    f = r['font'].is_a?(Hash) ? r['font'] : {}
    c = r['color'].is_a?(Hash) ? r['color'] : {}
    font = nil
    if f['on']
      name = f['name'].to_s.strip
      return [nil, 'Type a font name.'] if name.empty?
      size = f['size'].to_s.strip
      return [nil, 'Size must be a whole number of points, 1 to 1000.'] unless size =~ /\A\d+\z/
      size = size.to_i
      return [nil, 'Size must be a whole number of points, 1 to 1000.'] unless size >= 1 && size <= 1000
      font = { :name => name, :size => size,
               :bold => (f['bold'] ? true : false), :italic => (f['italic'] ? true : false) }
    end
    hex = nil
    if c['on']
      h = c['hex'].to_s.strip.downcase
      h = '#' + h unless h.start_with?('#')
      return [nil, 'Colour must be a six-digit hex like #ee6216.'] unless h =~ /\A#[0-9a-f]{6}\z/
      hex = h
    end
    return [nil, 'Tick Change font or Change colour — there is nothing to apply.'] if font.nil? && hex.nil?
    [{ :scope => scope, :tag => tag, :kinds => kinds, :font => font, :hex => hex }, nil]
  end

  def self.hex_to_rgb(hex)
    h = hex.to_s.sub('#', '')
    [h[0, 2], h[2, 2], h[4, 2]].map { |p| p.to_i(16) }
  end

  def self.rgb_to_hex(rgb)
    '#' + rgb.first(3).map { |v| format('%02x', v.to_i.clamp(0, 255)) }.join
  end

  # ----------------------------------------------------------------- walk --

  def self.kids_of(e)
    if e.is_a?(Sketchup::Group)
      e.entities
    elsif e.is_a?(Sketchup::ComponentInstance)
      e.definition.entities
    end
  rescue StandardError
    nil
  end

  # Every callout in the selection: a selected callout itself, or the
  # callouts inside a selected group / component (the per-scene picker's
  # own rule, so the two tools mean the same thing by "my selection").
  def self.selected_annotations(model)
    hits = []
    model.selection.to_a.each do |e|
      k = WR_SceneAnnotations.kind_of(e)
      if k
        hits << [e, k]
        next
      end
      kids = kids_of(e)
      WR_SceneAnnotations.each_annotation(kids, 1) { |c, ck| hits << [c, ck] } if kids
    end
    hits.uniq { |e, _k| e.entityID }
  end

  def self.all_annotations(model)
    hits = []
    WR_SceneAnnotations.each_annotation(model.entities) { |e, k| hits << [e, k] }
    hits
  end

  # The entities one request touches, after scope and kind.
  def self.targets(model, req)
    items = req[:scope] == 'sel' ? selected_annotations(model) : all_annotations(model)
    items = items.select { |e, _k| WR_SceneAnnotations.tag_of(e) == req[:tag] } if req[:scope] == 'tag'
    items.select { |_e, k| req[:kinds].include?(k) }
  end

  def self.count_kinds(items)
    c = { 'text' => 0, 'dim' => 0, '3d' => 0 }
    items.each { |_e, k| c[k] += 1 }
    c
  end

  # -------------------------------------------------------------- majority --

  def self.can_font?
    Sketchup::Text.method_defined?(:font=)
  rescue StandardError
    false
  end

  # What most callouts already are. Font from the text entities (the only
  # kind that reports one); colour from any kind carrying a material.
  def self.majority(items)
    fonts = Hash.new(0)
    hexes = Hash.new(0)
    items.each do |e, k|
      if k == 'text' && e.respond_to?(:font)
        f = (e.font rescue nil)
        if f.is_a?(Hash)
          key = [f[:name].to_s, f[:size].to_i, f[:bold] ? true : false, f[:italic] ? true : false]
          fonts[key] += 1
        end
      end
      m = (e.material rescue nil)
      if m && m.respond_to?(:color) && m.color
        hexes[rgb_to_hex(m.color.to_a)] += 1
      end
    end
    out = {}
    unless fonts.empty?
      k, n = fonts.max_by { |_kk, nn| nn }
      out['font'] = { 'name' => k[0], 'size' => k[1], 'bold' => k[2], 'italic' => k[3], 'n' => n }
    end
    unless hexes.empty?
      h, n = hexes.max_by { |_hh, nn| nn }
      out['hex'] = h
      out['hex_n'] = n
    end
    out
  end

  # ---------------------------------------------------------------- state --

  def self.state_hash(model)
    all = all_annotations(model)
    sel = selected_annotations(model)
    tags = Hash.new { |h, k| h[k] = { 'text' => 0, 'dim' => 0, '3d' => 0 } }
    all.each { |e, k| tags[WR_SceneAnnotations.tag_of(e)][k] += 1 }
    family = WR_ProposalScenes.annot_tags(model)
    # Untagged first (where hand-placed text lands), then the WR family in
    # catalogue order, then anything else by name — every tag that carries a
    # callout, so a set is never missing from the list because it is "wrong".
    order = tags.keys.sort_by do |n|
      [n == 'Untagged' ? 0 : (family.include?(n) ? 1 : 2), family.index(n) || 0, n]
    end
    { 'version'  => Sketchup.version.to_s,
      'can_font' => can_font?,
      'all'      => count_kinds(all),
      'sel'      => count_kinds(sel),
      'tags'     => order.map { |n| { 'name' => n, 'counts' => tags[n] } },
      'defaults' => defaults,
      'house'    => { 'name' => HOUSE_FONT[:name], 'size' => HOUSE_FONT[:size],
                      'bold' => HOUSE_FONT[:bold], 'italic' => HOUSE_FONT[:italic],
                      'hex' => HOUSE_HEX },
      'majority' => majority(all) }
  end

  # ---------------------------------------------------------------- apply --

  def self.material_for(model, hex)
    name = MAT_PREFIX + hex
    m = model.materials[name]
    m ||= model.materials.add(name)
    m.color = Sketchup::Color.new(*hex_to_rgb(hex))
    m
  end

  # Counters in, the sentences the dialog and the console print out. PURE.
  # counts: { :font => n, :color => n, :skips => { reason => n },
  #           :errors => [str], :total => n, :kinds => { 'text' => n, ... } }
  def self.summary_lines(c)
    lines = []
    kinds = KINDS.map { |k| n = c[:kinds][k].to_i; n > 0 ? "#{n} #{KIND_LABEL[k]}" : nil }.compact
    lines << "Touched #{c[:total]} callout(s)#{kinds.empty? ? '' : ' — ' + kinds.join(', ')}."
    lines << "Font set on #{c[:font]}." if c.key?(:font) && c[:font]
    lines << "Colour set on #{c[:color]}." if c.key?(:color) && c[:color]
    (c[:skips] || {}).each { |reason, n| lines << "Skipped #{n}: #{reason}." }
    (c[:errors] || []).first(5).each { |e| lines << "FAILED #{e}" }
    more = (c[:errors] || []).size - 5
    lines << "...and #{more} more failure(s) — see the Ruby Console." if more > 0
    lines << 'Ctrl+Z undoes the whole sweep.' if c[:total].to_i > 0
    lines
  end

  def self.apply(model, raw)
    req, err = normalise(raw)
    return [false, [err]] if err
    items = targets(model, req)
    if items.empty?
      where = case req[:scope]
              when 'sel' then 'your selection'
              when 'tag' then "the set #{req[:tag]}"
              else 'this model'
              end
      return [false, ["Nothing to restyle — no #{req[:kinds].map { |k| KIND_LABEL[k] }.join(' / ')} in #{where}."]]
    end

    c = { :total => items.size, :kinds => count_kinds(items), :skips => Hash.new(0), :errors => [] }
    c[:font]  = 0 if req[:font]
    c[:color] = 0 if req[:hex]
    fontable = can_font?

    model.start_operation('Uniform callout style', true)
    begin
      mat = req[:hex] ? material_for(model, req[:hex]) : nil
      items.each do |e, k|
        if req[:font]
          if k == 'text' && fontable && e.respond_to?(:font=)
            begin
              e.font = req[:font]
              c[:font] += 1
            rescue StandardError => ex
              c[:errors] << "font on #{WR_SceneAnnotations.text_of(e, k).inspect}: #{ex.class}: #{ex.message}"
            end
          else
            c[:skips][k == 'dim' ? SKIP_DIM_FONT : (k == '3d' ? SKIP_3D_FONT : SKIP_TEXT_FONT)] += 1
          end
        end
        next unless mat
        begin
          e.material = mat
          c[:color] += 1
        rescue StandardError => ex
          c[:errors] << "colour on #{WR_SceneAnnotations.text_of(e, k).inspect}: #{ex.class}: #{ex.message}"
        end
      end
      model.commit_operation
    rescue Exception => ex
      model.abort_operation
      raise ex
    end

    remember(req)
    lines = summary_lines(c)
    puts "WR_CalloutStyle: #{lines.join(' ')}"
    c[:errors].each { |e| puts "  FAILED #{e}" }
    [c[:errors].empty?, lines]
  end

  # --------------------------------------------------------------- dialog --

  def self.html
    <<~'HTML'
      <!DOCTYPE html><html><head><meta charset="utf-8"><style>
        body { font: 13px "Segoe UI", sans-serif; margin: 0; background: #22262b;
               color: #dde3ea; }
        #bar { padding: 10px 12px 4px; color: #9aa5b1; font-size: 11.5px; }
        #bar b { color: #dde3ea; }
        .sec { padding: 6px 12px; }
        .h { font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
             color: #9aa5b1; margin: 8px 0 4px; display: flex; gap: 10px; align-items: baseline; }
        .h a { margin-left: auto; text-transform: none; letter-spacing: 0; color: #9aa5b1;
               cursor: pointer; text-decoration: underline dotted; font-size: 11px; }
        .h a:hover { color: #e8a06a; }
        .row { display: flex; align-items: center; gap: 8px; padding: 3px 2px; font-size: 12px;
               flex-wrap: wrap; }
        .row label { display: flex; align-items: center; gap: 6px; cursor: pointer; }
        .row .cnt { color: #8a94a0; font-size: 11px; }
        .row .note { color: #e8a06a; font-size: 10.5px; flex: 1 1 100%; padding-left: 24px; }
        input[type=text], input[type=number], select {
          font: inherit; font-size: 12px; padding: 4px 7px; border: 1px solid #48505a;
          border-radius: 4px; background: #2b3036; color: #dde3ea; }
        input[type=text] { width: 150px; }
        input[type=number] { width: 60px; }
        input[type=color] { width: 34px; height: 24px; padding: 0; border: 1px solid #48505a;
                            border-radius: 4px; background: #2b3036; cursor: pointer; }
        .sw { width: 18px; height: 18px; border-radius: 3px; border: 1px solid #48505a;
              cursor: pointer; display: inline-block; }
        .sw:hover { border-color: #e8a06a; }
        .off { opacity: .45; }
        .hint { color: #7b8590; font-size: 11px; padding: 2px 12px 8px; line-height: 1.45; }
        #foot { padding: 6px 12px 10px; }
        #foot button { font: inherit; padding: 6px 12px; margin-right: 6px; border-radius: 4px;
                       border: 1px solid #48505a; background: #343b43; color: #dde3ea;
                       cursor: pointer; }
        #apply { background: #2e5a34; border-color: #3f7a47; }
        #status { padding: 0 12px 10px; color: #9aa5b1; min-height: 16px; white-space: pre-wrap;
                  line-height: 1.5; }
        #status.bad { color: #ffb4a8; }
        #touch { color: #dde3ea; font-size: 12px; padding: 4px 12px 0; }
      </style></head><body>
      <div id="bar">SketchUp <b id="ver">–</b> · text fonts: <b id="canfont">–</b></div>

      <div class="sec">
        <div class="h">What</div>
        <div class="row">
          <label><input type="checkbox" id="k_text" checked onchange="recount()"> Notes <span class="cnt" id="c_text"></span></label>
          <label><input type="checkbox" id="k_dim" checked onchange="recount()"> Dimensions <span class="cnt" id="c_dim"></span></label>
          <label><input type="checkbox" id="k_3d" checked onchange="recount()"> 3D labels <span class="cnt" id="c_3d"></span></label>
        </div>
        <div class="row"><span class="note">Dimensions take the colour but not the font — SketchUp gives Ruby no way to set a dimension font. 3D labels take the colour only; their face is geometry.</span></div>
      </div>

      <div class="sec">
        <div class="h">Where</div>
        <div class="row">
          <label><input type="radio" name="scope" value="all" checked onchange="recount()"> Whole model</label>
          <label><input type="radio" name="scope" value="sel" onchange="sketchup.refresh()"> My selection <span class="cnt" id="c_sel"></span></label>
          <label><input type="radio" name="scope" value="tag" id="s_tag" onchange="recount()"> One set</label>
          <select id="tag" onchange="pickTag()"></select>
        </div>
      </div>

      <div class="sec">
        <div class="h">Font <a id="mf" onclick="matchFont()"></a></div>
        <div class="row" id="fontrow">
          <label><input type="checkbox" id="f_on" checked onchange="dim()"> Change font</label>
          <input type="text" id="f_name" list="faces" placeholder="Arial">
          <datalist id="faces">
            <option value="Arial"><option value="Helvetica"><option value="Calibri">
            <option value="Segoe UI"><option value="Tahoma"><option value="Verdana">
            <option value="Times New Roman"><option value="Consolas">
          </datalist>
          <input type="number" id="f_size" min="1" max="1000" step="1"> pt
          <label><input type="checkbox" id="f_bold"> Bold</label>
          <label><input type="checkbox" id="f_italic"> Italic</label>
        </div>
      </div>

      <div class="sec">
        <div class="h">Colour <a id="mc" onclick="matchColour()"></a></div>
        <div class="row" id="colrow">
          <label><input type="checkbox" id="c_on" checked onchange="dim()"> Change colour</label>
          <input type="color" id="c_pick" oninput="syncHex(this.value)">
          <input type="text" id="c_hex" style="width:80px" oninput="syncPick(this.value)">
          <span class="sw" style="background:#ee6216" title="Brand orange #ee6216" onclick="setHex('#ee6216')"></span>
          <span class="sw" style="background:#000000" title="Black" onclick="setHex('#000000')"></span>
          <span class="sw" style="background:#3c3c3c" title="Dark grey #3c3c3c" onclick="setHex('#3c3c3c')"></span>
          <span class="sw" style="background:#ffffff" title="White" onclick="setHex('#ffffff')"></span>
        </div>
      </div>

      <div id="touch"></div>
      <div id="foot">
        <button id="apply" onclick="applyNow()">Apply</button>
        <button onclick="sketchup.refresh()">Refresh</button>
        <button onclick="useHouse()" title="Arial 12 regular, brand orange">House default</button>
      </div>
      <div class="hint">One undo step — Ctrl+Z puts every callout back. The values you apply
        become the defaults next time. Match majority fills in whatever most of the
        model's callouts already are.</div>
      <div id="status"></div>
      <script>
        var S = null;
        function $(id){ return document.getElementById(id); }
        function scope(){
          var r = document.querySelector('input[name=scope]:checked');
          var v = r ? r.value : 'all';
          return v === 'tag' ? 'tag:' + $('tag').value : v;
        }
        function counts(){
          if(!S) return {text:0, dim:0, '3d':0};
          var sc = scope();
          if(sc === 'sel') return S.sel;
          if(sc.indexOf('tag:') === 0){
            var n = sc.substr(4);
            for(var i=0;i<S.tags.length;i++) if(S.tags[i].name === n) return S.tags[i].counts;
            return {text:0, dim:0, '3d':0};
          }
          return S.all;
        }
        function kinds(){
          var out = [];
          if($('k_text').checked) out.push('text');
          if($('k_dim').checked) out.push('dim');
          if($('k_3d').checked) out.push('3d');
          return out;
        }
        function recount(){
          var c = counts(), ks = kinds(), parts = [], tot = 0;
          var lbl = {text:'notes', dim:'dimensions', '3d':'3D labels'};
          ks.forEach(function(k){ var n = c[k]||0; tot += n; parts.push(n + ' ' + lbl[k]); });
          $('touch').textContent = tot ? ('Will touch ' + tot + ' callout(s): ' + parts.join(', ') + '.')
                                       : 'Nothing in that scope matches — nothing would change.';
        }
        function pickTag(){ $('s_tag').checked = true; recount(); }
        function dim(){
          $('fontrow').className = 'row' + ($('f_on').checked ? '' : ' off');
          $('colrow').className  = 'row' + ($('c_on').checked ? '' : ' off');
        }
        function setHex(h){ $('c_hex').value = h; $('c_pick').value = h; }
        function syncHex(v){ $('c_hex').value = v; }
        function syncPick(v){ if(/^#[0-9a-fA-F]{6}$/.test(v)) $('c_pick').value = v.toLowerCase(); }
        function setFont(f){
          $('f_name').value = f.name; $('f_size').value = f.size;
          $('f_bold').checked = !!f.bold; $('f_italic').checked = !!f.italic;
        }
        function useHouse(){ if(!S) return; setFont(S.house); setHex(S.house.hex); }
        function matchFont(){ if(S && S.majority.font) setFont(S.majority.font); }
        function matchColour(){ if(S && S.majority.hex) setHex(S.majority.hex); }
        function fontLabel(f){
          return f.name + ' ' + f.size + (f.bold ? ' bold' : '') + (f.italic ? ' italic' : '');
        }
        function setState(json){
          S = JSON.parse(json);
          $('ver').textContent = S.version;
          $('canfont').textContent = S.can_font ? 'yes' : 'NO — needs SketchUp 2026.2; colour still works';
          ['text','dim','3d'].forEach(function(k){ $('c_' + k).textContent = '(' + (S.all[k]||0) + ')'; });
          var st = (S.sel.text||0) + (S.sel.dim||0) + (S.sel['3d']||0);
          $('c_sel').textContent = '(' + st + ')';
          var sel = $('tag'), keep = sel.value;
          sel.innerHTML = '';
          S.tags.forEach(function(t){
            var o = document.createElement('option');
            var n = (t.counts.text||0) + (t.counts.dim||0) + (t.counts['3d']||0);
            o.value = t.name; o.textContent = t.name + ' (' + n + ')';
            sel.appendChild(o);
          });
          if(keep) sel.value = keep;
          // Fields are only filled on the first state; a Refresh must not
          // throw away what is being typed.
          if(!$('f_name').value){ setFont(S.defaults); setHex(S.defaults.hex); }
          $('mf').textContent = S.majority.font
            ? 'Match majority: ' + fontLabel(S.majority.font) + ' (' + S.majority.font.n + ')' : '';
          $('mc').textContent = S.majority.hex
            ? 'Match majority: ' + S.majority.hex + ' (' + S.majority.hex_n + ')' : '';
          dim(); recount();
        }
        function applyNow(){
          sketchup.apply(JSON.stringify({
            scope: scope(), kinds: kinds(),
            font: { on: $('f_on').checked, name: $('f_name').value, size: $('f_size').value,
                    bold: $('f_bold').checked, italic: $('f_italic').checked },
            color: { on: $('c_on').checked, hex: $('c_hex').value }
          }));
        }
        function setStatus(t, bad){ $('status').textContent = t; $('status').className = bad ? 'bad' : ''; }
        window.addEventListener('load', function(){ sketchup.ready(); });
      </script></body></html>
    HTML
  end

  def self.push_state(model)
    return unless @dlg && @dlg.visible?
    @dlg.execute_script("setState(#{state_hash(model).to_json.inspect})")
  end

  def self.status(text, bad = false)
    return unless @dlg && @dlg.visible?
    @dlg.execute_script("setStatus(#{text.to_s.inspect}, #{bad ? 'true' : 'false'})")
  end

  def self.open
    model = Sketchup.active_model
    unless model
      UI.messagebox('No model is open.')
      return
    end
    if @dlg && @dlg.visible?
      @dlg.bring_to_front
      push_state(model)
      return
    end
    @dlg = UI::HtmlDialog.new(
      :dialog_title => 'Uniform callout font & colour',
      :preferences_key => PREF,
      :width => 560, :height => 520, :resizable => true,
      :style => UI::HtmlDialog::STYLE_DIALOG
    )
    @dlg.set_html(html)
    @dlg.add_action_callback('ready') do |_c|
      push_state(Sketchup.active_model)
    end
    @dlg.add_action_callback('refresh') do |_c|
      push_state(Sketchup.active_model)
      status('Reloaded.')
    end
    # Rescued wide: a raise inside apply has already aborted the operation,
    # and the one thing this window must never do is go quiet about it.
    @dlg.add_action_callback('apply') do |_c, payload|
      raw = (JSON.parse(payload.to_s) rescue {})
      begin
        ok, lines = apply(Sketchup.active_model, raw)
        push_state(Sketchup.active_model)
        status(lines.join("\n"), !ok)
      rescue Exception => e
        puts "WR_CalloutStyle FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n") if e.backtrace
        status("FAILED: #{e.class}: #{e.message} — nothing was changed (see the Ruby Console).", true)
      end
    end
    @dlg.show
    push_state(model)
  end
end

WR_CalloutStyle.open unless $wr_suppress_autorun || $wr_no_autorun
