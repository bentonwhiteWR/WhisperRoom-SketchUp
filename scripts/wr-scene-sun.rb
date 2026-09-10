# wr-scene-sun.rb — the SUN column of the proposal package: save a sun
# position INTO a scene, per scene or into every scene.
#
# NOT A COMMAND. This is a library, loaded by proposal-package.rb. It is in
# wr_tools' SKIP list so it does not appear in the panel as something to run.
#
# ===========================================================================
# WHY THIS EXISTS (1.27.0). Benton, 10 Sep 2026: "I want to take a look at
# saving the sun from the light from here. It's seemingly being reset every
# time we are playing with a scene. I think it seems they're not saving
# where the sun is."
#
# DIAGNOSED BY READING, NOT RUN. The sun is SketchUp's ShadowInfo — the
# direction is NorthAngle + ShadowTime + Latitude/Longitude/TZOffset — and it
# lives in two places: the MODEL's live shadow_info (what the viewport shows
# right now) and, per scene, the PAGE's own saved copy. Light it from here
# (wr-sun-aim.rb) writes the LIVE one only; its own header says so ("it
# edits the model's live shadow_info only"). And every scene the proposal
# tools make saves shadow settings — proposal-scenes.rb sets
# use_shadow_info = true, SketchUp's default for a hand-made scene too — so
# clicking any scene tab puts THAT scene's stale saved sun straight back over
# the one he just aimed. proposal-package.rb documents the very same
# mechanism for shadows-on/off at 1.19.3. So the scenes are NOT failing to
# save the sun; they are saving it too well, and nothing ever wrote the
# aimed sun into them. The fix is a per-scene save, which is this file.
#
# It is the SketchUp sun, not V-Ray's. His words are "where the sun is" and
# "reset every time we are playing with a scene": V-Ray's /SunLight
# intensity does not move when a scene is clicked; ShadowInfo does. Nothing
# here touches V-Ray — no /SunLight, no intensity — see
# .forge/fixer/sun-blowout.md for why that knob is his and stays his.
# Whether V-Ray's sun FOLLOWS SketchUp's shadow settings (Chaos' default,
# reported, never probed here) decides whether a render moves with this;
# the viewport certainly does.
#
# WHAT A SAVE WRITES. With the page SELECTED: the five direction keys into
# model.shadow_info, use_shadow_info on, then page.update(PAGE_USE_SHADOWINFO)
# — SketchUp's own "Update scene: shadow settings", which snapshots the
# whole shadow block (DisplayShadows, Light, Dark included) as it stands.
# Those display flags are the shading contract's business at export time
# (wr-shading.rb re-forces them per row) and are not changed here; they are
# stored as they are. The page has to be selected for the same reason the
# walls and annotations tools insist on it: a page snapshot is of the live
# model, and selecting the page is what puts that scene's own state under it.
#
# NOT UNDOABLE BY CTRL+Z. page.update is outside SketchUp's undo (1.25.2), so
# every write here records what it overwrote and undo_last puts it back —
# the same one-step record the walls and annotations modules keep.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-scene-sun.rb"

require 'sketchup.rb'

module WR_SceneSun
  # The keys that place the sun. SunDirection is derived from them and is
  # read back, never written. DisplayShadows / Light / Dark are deliberately
  # NOT here — that is the shading contract's territory.
  SUN_KEYS = %w[ShadowTime NorthAngle Latitude Longitude TZOffset].freeze

  # Light it from here's own defaults, so a scene aimed from this column and
  # one aimed from the standalone tool land the same way.
  DEFAULT_OFFSET = 30.0
  DEFAULT_ELEV   = 35.0

  def self.update_mask
    defined?(PAGE_USE_SHADOWINFO) ? PAGE_USE_SHADOWINFO : 0
  end

  # ------------------------------------------------------------ reading --

  def self.azimuth_of(vec)
    return nil unless vec
    a = Math.atan2(vec.x.to_f, vec.y.to_f) * 180.0 / Math::PI
    a += 360.0 if a < 0.0
    a
  rescue StandardError
    nil
  end

  def self.elevation_of(vec)
    return nil unless vec
    r = vec.z.to_f
    r = 1.0 if r > 1.0
    r = -1.0 if r < -1.0
    Math.asin(r) * 180.0 / Math::PI
  rescue StandardError
    nil
  end

  # A sun as a plain hash: the five keys plus the derived bearing/height, so
  # the same shape is stored, compared, shown and written back.
  def self.read_sun(si)
    return nil if si.nil?
    sun = {}
    SUN_KEYS.each do |k|
      sun[k] = (si[k] rescue nil)
    end
    dir = (si['SunDirection'] rescue nil)
    sun['az'] = azimuth_of(dir)
    sun['el'] = elevation_of(dir)
    sun
  end

  # The sun a page has SAVED, read off the page's own ShadowInfo without
  # selecting it. nil when the page does not save shadow settings (or the
  # API gives nothing back) — never a guess from the live model.
  def self.page_sun(page)
    return nil unless page && page.valid?
    return nil if page.respond_to?(:use_shadow_info?) && !page.use_shadow_info?
    si = (page.shadow_info rescue nil)
    read_sun(si)
  end

  # For the dialog: numbers rounded for reading, the time as a clock string.
  def self.sun_json(sun)
    return nil if sun.nil?
    t = sun['ShadowTime']
    { 'az'    => sun['az'].nil? ? nil : sun['az'].round(1),
      'el'    => sun['el'].nil? ? nil : sun['el'].round(1),
      'north' => sun['NorthAngle'].nil? ? nil : sun['NorthAngle'].to_f.round(1),
      'time'  => (t.respond_to?(:strftime) ? t.strftime('%d %b %H:%M') : t.to_s),
      'lat'   => sun['Latitude'].nil? ? nil : sun['Latitude'].to_f.round(2) }
  end

  def self.describe(sun)
    return 'not saved' if sun.nil?
    az = sun['az'].nil? ? '?' : format('%.0f', sun['az'])
    el = sun['el'].nil? ? '?' : format('%.0f', sun['el'])
    "bearing #{az} deg, height #{el} deg"
  end

  # Scenes that will NOT put a sun back when selected, by name.
  def self.pages_not_saving(model)
    model.pages.to_a.select do |pg|
      pg.respond_to?(:use_shadow_info?) && !pg.use_shadow_info?
    end.map { |pg| pg.name.to_s }
  rescue StandardError
    []
  end

  def self.fix_pages(model)
    fixed  = []
    failed = []
    model.pages.each do |pg|
      next unless pg.respond_to?(:use_shadow_info?) && !pg.use_shadow_info?
      begin
        pg.use_shadow_info = true
        fixed << pg.name.to_s
      rescue StandardError => e
        failed << "#{pg.name}: #{e.class}"
      end
    end
    msg = fixed.empty? ? 'Every scene already saves shadow settings.' :
                         "Fixed: #{fixed.join(', ')}."
    msg += " FAILED: #{failed.join(', ')}." unless failed.empty?
    [failed.empty?, msg]
  end

  # ------------------------------------------------------------ writing --

  # The write itself, NO operation of its own (the caller owns it). Call it
  # only with `page` SELECTED — see the header. Returns what was read back.
  def self.write_scene(page, sun)
    model = page.model
    si = model.shadow_info
    SUN_KEYS.each do |k|
      next if sun[k].nil?
      si[k] = sun[k]
    end
    page.use_shadow_info = true if page.respond_to?(:use_shadow_info=) &&
                                   page.respond_to?(:use_shadow_info?) &&
                                   !page.use_shadow_info?
    page.update(update_mask)
    read_sun(si)
  end

  def self.restore_page(model, page)
    model.pages.selected_page = page if page && page.valid?
  rescue StandardError
    nil
  end

  # One sun into one scene. `sun` is a read_sun hash.
  def self.apply(model, page, sun)
    return [false, 'No scene to save into.'] unless page && page.valid?
    return [false, 'No sun to save — nothing was read.'] if sun.nil?
    start  = model.pages.selected_page
    before = page_sun(page)
    model.start_operation('Save sun into scene', true)
    begin
      model.pages.selected_page = page
      got = write_scene(page, sun)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      return [false, "Save failed and was rolled back: #{e.class}: #{e.message}"]
    end
    remember_write(model, 'sun', [{ :page => page, :name => page.name.to_s, :before => before }])
    restore_page(model, start)
    [true, "Sun saved into scene \"#{page.name}\": #{describe(got)}. Ctrl+Z will NOT " \
           'put the old one back — UNDO LAST APPLY will.']
  end

  # The SAME sun into every page given, one operation. Callers confirm
  # first (confirm_all?); this is mechanism. Returns
  # [ok, message, { :written => [names], :unsaved => [names] }].
  def self.apply_all(model, sun, pages = nil)
    pages = (pages || model.pages.to_a).select { |pg| pg && pg.valid? }
    return [false, 'No scenes to write into.'] if pages.empty?
    return [false, 'No sun to save — nothing was read.'] if sun.nil?
    start   = model.pages.selected_page
    written = []
    entries = []
    model.start_operation('Save sun into every scene', true)
    begin
      pages.each do |pg|
        entries << { :page => pg, :name => pg.name.to_s, :before => page_sun(pg) }
        model.pages.selected_page = pg
        write_scene(pg, sun)
        written << pg.name.to_s
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      return [false, 'Save to every scene failed and was rolled back: ' \
                     "#{e.class}: #{e.message}"]
    end
    remember_write(model, 'sun', entries)
    restore_page(model, start)
    [true, "Sun (#{describe(sun)}) saved into #{written.size} scene(s). Ctrl+Z will " \
           'NOT put the old ones back — UNDO LAST APPLY will.',
     { :written => written, :unsaved => [] }]
  end

  # Aim the sun from a scene's OWN camera through Light it from here, then
  # save what it produced into that scene. The page's camera is handed to
  # WR_SunAim in place of the view so a scene transition still animating
  # cannot feed it a half-way camera. Two operations (the aim owns its own),
  # both recorded: the sun write here is what UNDO LAST APPLY puts back.
  def self.aim(model, page, offset, match_cam, elev)
    return [false, 'No scene to aim from.'] unless page && page.valid?
    unless defined?(WR_SunAim) && WR_SunAim.respond_to?(:light_it_from_here)
      return [false, 'Light it from here (wr-sun-aim.rb) is not loaded.']
    end
    cam = (page.camera rescue nil)
    return [false, "Scene \"#{page.name}\" has no saved camera to aim from."] if cam.nil?
    start = model.pages.selected_page
    model.pages.selected_page = page
    fake_view = Struct.new(:camera).new(cam)
    r = WR_SunAim.light_it_from_here(model, fake_view, offset.to_f, match_cam ? true : false,
                                     elev.to_f)
    unless r[:ok]
      restore_page(model, start)
      return [false, "Light it from here did not run: #{r[:reason]}"]
    end
    ok, msg = apply(model, page, read_sun(model.shadow_info))
    restore_page(model, start)
    return [false, msg] unless ok
    note = r[:calibration_confident] ? '' : ' (aim reported LOW CONFIDENCE — check it in the viewport)'
    [true, "Aimed from \"#{page.name}\"'s camera, offset #{format('%+.0f', offset.to_f)} deg: " \
           "#{msg}#{note}"]
  end

  # Same prompt shape as WR_SceneWalls.confirm_all?.
  def self.confirm_all?(pages, sun)
    names = pages.map { |pg| pg.name.to_s }
    shown = names.first(12)
    shown << "… and #{names.size - 12} more" if names.size > 12
    UI.messagebox("Save this sun (#{describe(sun)}) into #{pages.size} scene(s)?\n\n" \
                  "#{shown.join("\n")}\n\n" \
                  "Each of those scenes' saved sun will be REPLACED.\n\n" \
                  "Ctrl+Z will NOT put them back (a scene's saved snapshot is outside " \
                  "SketchUp's undo). UNDO LAST APPLY puts this one back - one step, " \
                  'this SketchUp session only.',
                  MB_YESNO) == IDYES
  end

  # ---- UNDO LAST APPLY (1.26.1 shape) ---------------------------------------
  # The same one-step record the walls and annotations modules keep, so the
  # proposal package's one button covers all three. `before` is the page's
  # OWN saved sun (page_sun) read before the write, nil when it saved none.

  def self.last_write
    @last_write
  end

  def self.model_key(model)
    model.guid
  rescue StandardError
    model.object_id
  end

  def self.remember_write(model, what, entries)
    return if entries.nil? || entries.empty?
    @last_write = { :model => model_key(model), :what => what,
                    :pages => entries, :at => Time.now }
  end

  def self.undo_summary(model)
    lw = @last_write
    return nil unless lw && lw[:model] == model_key(model)
    names = lw[:pages].select { |e| e[:page].valid? }.map { |e| e[:name] }
    return nil if names.empty?
    { 'what' => lw[:what], 'scenes' => names,
      'at' => lw[:at].strftime('%H:%M'), 'module' => 'WR_SceneSun' }
  rescue StandardError
    nil
  end

  def self.undo_last(model)
    lw = @last_write
    return [false, 'Nothing to put back — no sun save has been recorded in this ' \
                   'SketchUp session.'] unless lw
    unless lw[:model] == model_key(model)
      return [false, 'The last sun save was on a different model — nothing put back.']
    end
    entries = lw[:pages].select { |e| e[:page] && e[:page].valid? }
    return [false, 'The scenes the last sun save wrote to no longer exist.'] if entries.empty?
    start = model.pages.selected_page
    put   = []
    none  = []
    model.start_operation('Put back sun per scene', true)
    begin
      entries.each do |e|
        if e[:before].nil?
          none << e[:name]           # it saved no sun before; nothing to put back
          next
        end
        model.pages.selected_page = e[:page]
        write_scene(e[:page], e[:before])
        put << e[:name]
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      return [false, "Put back failed and was rolled back: #{e.class}: #{e.message}"]
    end
    restore_page(model, start)
    @last_write = nil
    msg = "Put back the saved sun on #{put.size} scene(s): #{put.join(', ')} " \
          "(as it was at #{lw[:at].strftime('%H:%M')})."
    msg += " #{none.size} scene(s) had no saved sun before and were left as written: " \
           "#{none.join(', ')}." unless none.empty?
    msg += ' That was the one step there is — it is used up.'
    [true, msg]
  end
end
