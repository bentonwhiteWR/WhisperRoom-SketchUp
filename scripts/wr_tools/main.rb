# WhisperRoom Tools — launcher panel, menu and toolbar.
#
# WHY A PANEL AND NOT JUST A MENU
#
# SketchUp cannot remove or rebuild a menu item once it is added — there is no
# API for it, and the old "Reload Scripts" command could only ever pop a
# message box saying so. That meant a new script in scripts/ did not appear
# until SketchUp was restarted, which is the wrong way round for a folder we
# add to constantly.
#
# The panel (UI::HtmlDialog, Chromium, SketchUp 2017+) rescans the folder every
# time it opens. Drop a .rb in, hit Rescan, run it. No restart, no reinstall.
# The menu is kept as a static fallback for whatever existed at load time.
#
# A script's label comes from its first "# @title" line; the blurb under it is
# the comment paragraph that follows. Both are optional.

require 'sketchup.rb'
require 'json'

module WhisperRoom
  module Tools
    # Where the repo's scripts/ folder lives. Machines differ — the laptop keeps
    # Documents local, the desktop has it redirected into OneDrive, and the repo
    # may sit at Claude/Sketchup or Claude/Sketchup/WhisperRoom-SketchUp. Take the
    # first candidate that actually exists rather than hard-coding one machine.
    # Set the WR_SCRIPTS_DIR environment variable to override on a new machine.
    CANDIDATES = [
      ENV['WR_SCRIPTS_DIR'],
      File.join(ENV['USERPROFILE'].to_s, 'Documents/Claude/Sketchup/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'OneDrive/Documents/Claude/Sketchup/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts')
    ].compact.map { |p| p.tr('\\', '/') }.freeze

    SCRIPTS_DIR = (CANDIDATES.find { |p| File.directory?(p) } || CANDIDATES[1])

    # Libraries other scripts `load`, not commands. wr-booth-data.rb is data for
    # build-booth.rb; wr-shading.rb is the shading contract both component-art
    # exporters share.
    SKIP     = ['wr_tools.rb', 'wr-booth-data.rb', 'wr-shading.rb'].freeze
    PREF_KEY = 'WR_Tools'.freeze
    RECENT_N = 5
    PIN_N    = 8        # favourites the strip holds before it gets crowded
    FRESH_H  = 24        # a script touched this recently gets a NEW pill

    # ---------------------------------------------------------------- scanning --

    def self.script_files
      return [] unless File.directory?(SCRIPTS_DIR)
      Dir.entries(SCRIPTS_DIR)
         .select { |f| f =~ /\.rb\z/i }
         .reject { |f| SKIP.include?(f) }
         .map    { |f| File.join(SCRIPTS_DIR, f) }
    end

    # Pull the @-directives and the comment paragraph out of a script header.
    #
    # A script becomes an ABILITY — a thing with an on and an off, rather than a
    # thing you run — purely by declaring it in its own header:
    #
    #   # @ability Exploded
    #   # @ability-blurb Pull the assembly apart; switch off to put it back.
    #   # @setting mode   choice  Axis|Radial|Vertical only  Direction
    #   # @setting spread number  60                         Spread (%)
    #   # @on  WR_ExplodeView.ability_on(opts)
    #   # @off WR_ExplodeView.ability_off(opts)
    #
    # Declaring it in the script rather than in a list here means a new ability
    # needs no edit to the plugin, and the declaration cannot drift away from the
    # code it describes.
    #
    # @setting is WHITESPACE-DELIMITED, so a choice value cannot contain a space:
    # write Axis|Radial|Vertical, not Axis|Radial|Vertical only. Everything after
    # the default is the human label and may contain spaces.
    def self.meta_of(path)
      title = nil
      blurb = []
      started = false
      abil = nil
      File.foreach(path).with_index do |line, i|
        break if i > 60
        unless line =~ /^\s*#/
          break unless line.strip.empty?
          next
        end
        text = line.sub(/^\s*#\s?/, '').rstrip
        if text =~ /^@title\s+(.+)$/
          title = Regexp.last_match(1).strip.sub(/\.\.\.\z/, '')
          next
        end
        if text =~ /^@ability\s+(.+)$/
          abil ||= { 'label' => nil, 'blurb' => '', 'settings' => [], 'on' => nil, 'off' => nil }
          abil['label'] = Regexp.last_match(1).strip
          next
        end
        if text =~ /^@ability-blurb\s+(.+)$/
          abil ||= { 'label' => nil, 'blurb' => '', 'settings' => [], 'on' => nil, 'off' => nil }
          abil['blurb'] = Regexp.last_match(1).strip
          next
        end
        if text =~ /^@setting\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/
          abil ||= { 'label' => nil, 'blurb' => '', 'settings' => [], 'on' => nil, 'off' => nil }
          key, kind, dflt, lbl = Regexp.last_match(1), Regexp.last_match(2),
                                 Regexp.last_match(3), Regexp.last_match(4).strip
          abil['settings'] << { 'key' => key, 'kind' => kind, 'default' => dflt,
                                'label' => (lbl.empty? ? key : lbl),
                                'choices' => (kind == 'choice' ? dflt.split('|') : []) }
          abil['settings'].last['default'] = dflt.split('|').first if kind == 'choice'
          next
        end
        if text =~ /^@(on|off)\s+(.+)$/
          abil ||= { 'label' => nil, 'blurb' => '', 'settings' => [], 'on' => nil, 'off' => nil }
          abil[Regexp.last_match(1)] = Regexp.last_match(2).strip
          next
        end
        next if text =~ /^@/
        if text.empty?
          break if started
          next
        end
        started = true
        blurb << text
        break if blurb.join(' ').length > 200
      end
      abil = nil unless abil && abil['label'] && abil['on'] && abil['off']
      [title, blurb.join(' '), abil]
    rescue StandardError
      [nil, '', nil]
    end

    def self.pretty(basename)
      basename.sub(/\.rb\z/i, '').tr('-_', '  ').split.map(&:capitalize).join(' ')
    end

    def self.ago(t)
      s = (Time.now - t).to_i
      return 'just now'    if s < 60
      m = s / 60
      return "#{m} min ago" if m < 60
      h = m / 60
      return "#{h} hr ago"  if h < 24
      d = h / 24
      return "#{d} d ago"   if d < 30
      "#{(d / 30.0).round} mo ago"
    end

    # Newest first — the thing being worked on is nearly always the thing to run.
    # A script's category comes from a "# @cat <name>" header line. Scripts
    # WITHOUT one — generated booth files, one-off layouts — sink to the
    # catch-all group at the bottom of the panel, which is exactly where a
    # run-once script belongs.
    def self.cat_of(path)
      File.foreach(path).with_index do |line, i|
        break if i > 60
        next unless line =~ /^\s*#/
        m = line.match(/^\s*#\s*@cat\s+(.+)$/)
        return m[1].strip if m
      end
      nil
    rescue StandardError
      nil
    end

    def self.scan
      script_files.map { |path|
        title, blurb, abil = meta_of(path)
        mtime = File.mtime(path)
        {
          'file'    => path,
          'name'    => File.basename(path),
          'title'   => title || pretty(File.basename(path)),
          'cat'     => cat_of(path),
          'blurb'   => blurb,
          'ago'     => ago(mtime),
          'fresh'   => (Time.now - mtime) < FRESH_H * 3600,
          'stamp'   => mtime.to_i,
          'ability' => abil
        }
      }.sort_by { |s| -s['stamp'] }
    end

    # ------------------------------------------------------------ preferences --
    #
    # NEVER store a string containing a double quote in a SketchUp default.
    #
    # `Sketchup.read_default` EVALS the stored string as Ruby, and
    # `write_default` does not escape quotes inside it. So a JSON array goes in
    # as `["a.rb"]` and comes back out as the eval source `"["a.rb"]"` — the
    # inner quote closes the literal and Ruby raises
    #
    #     SyntaxError: unexpected local variable or method, expecting end-of-input
    #
    # SyntaxError descends from ScriptError, NOT StandardError, so a plain
    # `rescue StandardError` does not catch it. That is how one starred script
    # took the whole extension down at load on 2026-08-10: the bad value was
    # written once, and every launch after it failed at `pinned`.
    #
    # Lists are therefore stored pipe-joined. `|` is illegal in a Windows
    # filename, so it cannot appear in a script name, and it is inert inside a
    # double-quoted Ruby literal. `read_pref` also rescues Exception and clears
    # a value it cannot read, so a default written by an older build heals
    # itself on the next launch instead of erroring forever.

    LIST_SEP = '|'.freeze

    def self.read_pref(key, fallback = '')
      Sketchup.read_default(PREF_KEY, key, fallback).to_s
    rescue Exception
      begin
        Sketchup.write_default(PREF_KEY, key, fallback.to_s)
      rescue Exception
        nil
      end
      fallback.to_s
    end

    def self.write_pref(key, value)
      Sketchup.write_default(PREF_KEY, key, value.to_s.delete('"'))
    rescue Exception
      nil
    end

    def self.read_list(key)
      read_pref(key).split(LIST_SEP).reject(&:empty?)
    end

    def self.write_list(key, list)
      write_pref(key, list.reject { |n| n.to_s.include?(LIST_SEP) }.join(LIST_SEP))
    end

    # ---------------------------------------------------------------- recents --

    def self.recent
      read_list('recent')
    end

    def self.remember(name)
      list = ([name] + recent.reject { |n| n == name }).first(RECENT_N)
      write_list('recent', list)
    end

    # ------------------------------------------------------- toolbar slots --
    #
    # The toolbar carries PIN_N customisable buttons. Each SLOT holds two
    # independent things — WHICH script it runs, and WHICH icon it wears — the
    # way a custom button on a Word ribbon does. Both are chosen in the panel's
    # Toolbar section; neither is hard-coded here.
    #
    # WHY THE ICON HAS TO BE BOUND AT LOAD, AND THE ACTION DOES NOT
    #
    # UI::Toolbar#add_item works at runtime, but on Windows it has a known
    # severe slowdown when the toolbar was docked in a previous session
    # (SketchUp api-issue-tracker #628), so every button has to be created once
    # at load. What a button RUNS is looked up at click time, so re-assigning a
    # slot takes effect immediately. What a button LOOKS LIKE is uploaded to the
    # native toolbar when the command is created; assigning small_icon later
    # does not reliably repaint, which is why eight identically-starred buttons
    # survived the last attempt at per-script faces. So the icon is read from
    # preferences BEFORE the command is built, and a changed icon appears at the
    # next SketchUp launch. The panel says so on screen rather than pretending.
    #
    # STORAGE. Two pipe-joined lists of exactly PIN_N entries, positionally
    # aligned, with SLOT_EMPTY for an unused slot — read_list drops empty
    # strings, so a genuinely empty entry needs a placeholder or every slot
    # after it shifts up one.

    SLOT_EMPTY = '-'.freeze

    # Fallback faces for slots assigned before the library existed. Not a
    # registry — anything not listed simply starts on the numbered star and the
    # picker changes it.
    FAV_ICONS = {
      'save-scene-components.rb'  => 'scenecomps',
      'build-booth-components.rb' => 'boothbuild',
      'booth-from-link.rb'        => 'boothlink',
      'elevation-export.rb'       => 'elevation',
      'angled-component-art.rb'   => 'angled'
    }.freeze

    def self.pad(list)
      out = list.first(PIN_N).map { |v| v.to_s.empty? ? SLOT_EMPTY : v.to_s }
      out + Array.new(PIN_N - out.length, SLOT_EMPTY)
    end

    def self.blank?(v)
      v.nil? || v.to_s.empty? || v.to_s == SLOT_EMPTY
    end

    # Script name per slot. Migrates the old flat 'pinned' list — which had no
    # slot positions, only an order — into slots the first time it is read, so
    # an existing set of favourites survives the upgrade.
    def self.slots
      raw = read_list('slots')
      if raw.empty?
        old = read_list('pinned')
        return pad(old) unless old.empty?
      end
      pad(raw)
    end

    def self.slot_icons
      pad(read_list('slot_icons'))
    end

    def self.write_slots(names, icons)
      write_list('slots', pad(names))
      write_list('slot_icons', pad(icons))
      write_list('pinned', pad(names).reject { |n| blank?(n) })   # panel stars
      refresh_fav_labels
    end

    # Assign, in one call, because assigning a script without an icon and then
    # an icon without a script is two chances to clobber the other field.
    def self.set_slot(i, name, icon)
      i = i.to_i
      return if i < 0 || i >= PIN_N
      names = slots
      ics   = slot_icons
      names[i] = blank?(name) ? SLOT_EMPTY : name.to_s
      ics[i]   = blank?(icon) ? SLOT_EMPTY : icon.to_s
      write_slots(names, ics)
    rescue StandardError
      nil
    end

    def self.clear_slot(i)
      set_slot(i, nil, nil)
    end

    # The star on a script row. It is a shortcut for "put this in the first free
    # slot" — no icon chosen, so the slot shows its number until one is picked.
    def self.toggle_pin(name)
      names = slots
      ics   = slot_icons
      at = names.index(name)
      if at
        names[at] = SLOT_EMPTY
        ics[at]   = SLOT_EMPTY
      else
        free = names.index { |n| blank?(n) }
        return if free.nil?          # every slot taken — the panel says so
        names[free] = name.to_s
      end
      write_slots(names, ics)
    rescue StandardError
      nil
    end

    def self.pinned
      slots.reject { |n| blank?(n) }
    end

    # What slot i currently points at, resolved against what is on disk so a
    # slot left behind by a deleted script cannot fire a dead button.
    def self.favourite_at(i)
      name = slots[i]
      return nil if blank?(name)
      scan.find { |s| s['name'] == name }
    end

    def self.run_favourite(i)
      s = favourite_at(i)
      if s.nil?
        UI.messagebox("Toolbar slot #{i + 1} is empty.\n\n" \
                      "Open the WhisperRoom panel and click slot #{i + 1} in the " \
                      "Toolbar row to give it a script and an icon.")
        return
      end
      run(s['file'])
      push
    end

    # ------------------------------------------------------- icon library --
    #
    # Every ico-*.svg in this folder is an offered icon. Adding one to the
    # library is dropping a file in — no edit here, no edit in the panel. Labels
    # come from ico-labels.txt (id TAB label) if make-icons.py wrote one;
    # otherwise the id is prettified, so a hand-added SVG still shows up named.

    def self.icon_labels
      @icon_labels ||= begin
        path = File.join(File.dirname(__FILE__), 'ico-labels.txt')
        out = {}
        if File.exist?(path)
          File.foreach(path) do |line|
            id, label = line.rstrip.split("\t", 2)
            out[id] = label unless id.nil? || id.empty?
          end
        end
        out
      end
    rescue StandardError
      {}
    end

    def self.icon_library
      Dir.glob(File.join(File.dirname(__FILE__), 'ico-*.svg')).sort.map { |p|
        id = File.basename(p, '.svg').sub(/\Aico-/, '')
        { 'id' => id, 'label' => icon_labels[id] || pretty(id) }
      }
    rescue StandardError
      []
    end

    # The file a slot's button should wear: the chosen library icon, else the
    # legacy per-script face, else the numbered star.
    def self.slot_icon_path(i)
      dir = File.dirname(__FILE__)
      chosen = slot_icons[i]
      unless blank?(chosen)
        p = File.join(dir, "ico-#{chosen}.svg")
        return p if File.exist?(p)
      end
      name = slots[i]
      unless blank?(name)
        key = FAV_ICONS[name]
        p = key && File.join(dir, "icon-#{key}.svg")
        return p if p && File.exist?(p)
      end
      File.join(dir, "icon-fav#{i + 1}.svg")
    rescue StandardError
      File.join(File.dirname(__FILE__), "icon-fav#{i + 1}.svg")
    end

    # Tooltips ARE settable after the command is created, so a slot can be
    # re-pointed without rebuilding the toolbar. The action is always current
    # either way, because it resolves the slot list at click time. The icon is
    # also re-assigned here on the chance that this SketchUp repaints it; the
    # panel does not promise that it will.
    def self.refresh_fav_labels
      return if @fav_cmds.nil?
      @fav_cmds.each_with_index do |cmd, i|
        s = favourite_at(i)
        text = s ? "#{s['title']}  (toolbar slot #{i + 1})" : "Toolbar slot #{i + 1} — empty"
        cmd.tooltip = text
        cmd.status_bar_text = s ? "Run #{s['name']}" : 'Assign it in the WhisperRoom panel'
        begin
          icon = slot_icon_path(i)
          if File.exist?(icon)
            cmd.small_icon = icon
            cmd.large_icon = icon
          end
        rescue StandardError
          nil
        end
      end
    rescue StandardError
      nil
    end

    # -------------------------------------------------------------- abilities --
    #
    # An ability is a thing with an ON and an OFF, as against a script, which is
    # a thing you run. The point is not to save a click: it is that toggling off
    # UNDOES the same work that toggling on did, so you stop filling a dialog in
    # every time you want to look at something a different way.
    #
    # STATE LIVES IN THE MODEL, not in the plugin. Whether this assembly is
    # exploded is a fact about the model, so it is stored on the model and it
    # survives save, close and reopen. Settings are per-user and live in prefs.
    #
    # A broken ability must not take the panel with it, so every call is wrapped
    # and reports its own failure onto its own card.

    ABIL_DICT = 'WR_Tools_Abilities'.freeze

    # Reference-only geometry, across every script in the folder. This is the one
    # ability with no script behind it — there is nothing to run, only tags to
    # show and hide, so it is built in.
    REF_TAGS = [
      'WR-Explode-Leaders',   # explode-view.rb
      'WR-Notes',             # build-room.rb, csusb-rooms.rb
      'STAND-Tubes',          # tube-drying-stand.rb
      'JIG-Parts',            # pendant-jig.rb
      'JIG-Dims'
    ].freeze

    def self.builtin_abilities
      [{
        'id'       => 'ghost',
        'label'    => 'Reference geometry',
        'blurb'    => 'Show the ghost parts and leader lines every script draws for ' \
                      'reference — tubes, housings, explode leaders, notes.',
        'settings' => [],
        'builtin'  => true
      }]
    end

    def self.abilities
      out = builtin_abilities
      scan.each do |s|
        a = s['ability']
        next unless a
        out << a.merge('id' => s['name'], 'file' => s['file'],
                       'script' => s['title'], 'builtin' => false)
      end
      out.each { |a| a['on_now'] = state(a['id']); a['values'] = values_for(a) }
      out
    end

    def self.state(id)
      m = Sketchup.active_model
      return false unless m
      m.get_attribute(ABIL_DICT, id, false) ? true : false
    rescue StandardError
      false
    end

    def self.set_state(id, on)
      m = Sketchup.active_model
      m.set_attribute(ABIL_DICT, id, on ? true : false) if m
    rescue StandardError
      nil
    end

    def self.values_for(a)
      out = {}
      (a['settings'] || []).each do |s|
        v = read_pref("set_#{a['id']}_#{s['key']}", s['default'])
        out[s['key']] = v.empty? ? s['default'] : v
      end
      out
    end

    def self.save_setting(id, key, value)
      write_pref("set_#{id}_#{key}", value)
    end

    # Every tag whose name is in REF_TAGS, plus anything ending in -Ref, so a
    # future script can opt in without editing this list.
    def self.ref_layers(model)
      model.layers.select { |l|
        REF_TAGS.include?(l.name) || l.name =~ /-Ref\z/i
      }
    end

    def self.toggle_ghost(on)
      model = Sketchup.active_model
      ls = ref_layers(model)
      if ls.empty?
        return [false, 'No reference tags in this model yet — build something first.']
      end
      ls.each { |l| l.visible = on }
      model.active_view.refresh rescue nil
      [true, "#{on ? 'Showing' : 'Hiding'} #{ls.size} reference tag(s)"]
    rescue StandardError => e
      [false, "#{e.class}: #{e.message}"]
    end

    # The @on / @off directives are Ruby, evaluated with `opts` bound to the
    # ability's saved settings. That is not a new risk: `load` already runs every
    # line of these files, and they are this repo's own scripts.
    def self.toggle(id, on)
      a = abilities.find { |x| x['id'] == id }
      return [false, "No such ability: #{id}"] unless a

      if a['builtin']
        ok, msg = toggle_ghost(on)
        set_state(id, on) if ok
        return [ok, msg]
      end

      unless File.exist?(a['file'].to_s)
        return [false, "Script is gone: #{a['file']}"]
      end
      load a['file']                     # re-read every time, so edits take effect
      opts = values_for(a)
      expr = on ? a['on'] : a['off']
      result = eval(expr, binding, a['file'])   # rubocop:disable Security/Eval
      if result == false
        return [false, "#{a['label']} could not #{on ? 'start' : 'stop'} — see the console."]
      end
      set_state(id, on)
      [true, "#{a['label']} #{on ? 'on' : 'off'}"]
    rescue StandardError => e
      puts "ABILITY FAILED (#{id}, #{on ? 'on' : 'off'}): #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      [false, "#{e.class}: #{e.message}"]
    end

    # --------------------------------------------------------------- renaming --
    #
    # A script's panel label is its "# @title" header line, so renaming one is
    # rewriting that line in the file. It happens here rather than in an editor
    # because the name you want is obvious exactly when you are looking at the
    # list, and never again.
    #
    # THE FILENAME IS DELIBERATELY NOT TOUCHED. Scripts reference each other by
    # filename — booth-from-link.rb loads build-booth-components.rb, both art
    # exporters load wr-shading.rb — the toolbar slots are stored by filename,
    # the menu built at load time points at paths, and git tracks the path. A
    # rename that moved the file would break all four silently, to change a
    # string that is only ever read by a human. So the label is what changes.
    #
    # Trailing "..." is a convention here: it means "this opens a dialog". If
    # the old title carried it, the new one keeps it, so the convention cannot
    # be lost by someone who did not know about it.

    def self.rename(name, title)
      base = File.basename(name.to_s)
      return [false, 'Not a script in this folder.'] if base != name.to_s || base.empty?
      return [false, 'That file is not renameable.'] if SKIP.include?(base)
      path = File.join(SCRIPTS_DIR, base)
      return [false, "Not found: #{base}"] unless File.exist?(path)

      want = title.to_s.strip.gsub(/\s+/, ' ')
      old  = meta_of(path)[0]
      want += '...' if old.to_s.end_with?('...') && !want.empty? && !want.end_with?('...')

      raw = File.open(path, 'rb') { |f| f.read }
      crlf = raw.include?("\r\n")
      body = raw.gsub("\r\n", "\n")
      lines = body.split("\n", -1)

      at = nil
      lines.each_with_index do |l, i|
        break if i > 60
        at = i if at.nil? && l =~ /^\s*#\s*@title\s+/
      end

      if want.empty?
        # No title line at all — the panel falls back to the prettified
        # filename, which is the right "reset to default".
        return [false, 'That script has no custom name to clear.'] if at.nil?
        lines.delete_at(at)
      elsif at
        lines[at] = "# @title #{want}"
      else
        lines.unshift("# @title #{want}")
      end

      out = lines.join("\n")
      out = out.gsub("\n", "\r\n") if crlf
      File.open(path, 'wb') { |f| f.write(out) }
      [true, want.empty? ? "#{base} reset to its filename." : "Renamed to #{want}"]
    rescue StandardError => e
      [false, "#{e.class}: #{e.message}"]
    end

    # ---------------------------------------------------------------- running --

    def self.run(path)
      unless File.exist?(path)
        UI.messagebox("Not found:\n#{path}")
        return false
      end
      remember(File.basename(path))
      load path
      true
    rescue StandardError => e
      UI.messagebox("#{File.basename(path)} failed:\n\n#{e.class}: #{e.message}\n\n" \
                    "#{e.backtrace.first(3).join("\n")}")
      false
    end

    # ------------------------------------------------------------------ panel --

    def self.payload
      { 'dir' => SCRIPTS_DIR, 'scripts' => scan, 'abilities' => abilities,
        'recent' => recent, 'pinned' => pinned, 'note' => @note,
        'slots' => slots, 'slot_icons' => slot_icons,
        'icons' => icon_library, 'pin_n' => PIN_N }
    end

    def self.push_note(msg)
      @note = msg
      push
      @note = nil
    end

    def self.push
      return unless @dlg
      @dlg.execute_script("WR.render(#{payload.to_json})")
    rescue StandardError
      nil
    end

    def self.panel
      return @dlg if @dlg

      html = File.join(File.dirname(__FILE__), 'panel.html')
      unless File.exist?(html)
        UI.messagebox("panel.html is missing from\n#{File.dirname(__FILE__)}\n\n" \
                      "Re-run scripts/install-plugin.py.")
        return nil
      end

      d = UI::HtmlDialog.new(
        :dialog_title    => 'WhisperRoom',
        :preferences_key => 'com.whisperroom.tools.panel',
        :scrollable      => true,
        :resizable       => true,
        :width           => 430,
        :height          => 640,
        :min_width       => 330,
        :min_height      => 300,
        :style           => UI::HtmlDialog::STYLE_DIALOG
      )
      d.set_file(html)
      d.add_action_callback('ready')   { |_c| push }
      d.add_action_callback('rescan')  { |_c| push }
      d.add_action_callback('run')     { |_c, file| run(file); push }
      d.add_action_callback('pin')     { |_c, name| toggle_pin(name); push }
      d.add_action_callback('rename') do |_c, name, title|
        _ok, msg = rename(name, title)
        refresh_fav_labels          # a renamed script retitles its toolbar slot
        push_note(msg)
      end
      # Slot editor. Both fields always travel together — see set_slot.
      d.add_action_callback('setslot') do |_c, i, name, icon|
        set_slot(i, name, icon)
        push_note(blank?(name) ? "Slot #{i.to_i + 1} cleared." :
                  "Slot #{i.to_i + 1} set. A new ICON appears when SketchUp next starts; " \
                  'the button already runs the new script.')
      end
      # A booth-builder link pasted into the panel's command bar. The run
      # callback carries no arguments, so the link is handed to
      # booth-from-link.rb through that script's own preference — its dialog
      # opens with the link already filled in.
      d.add_action_callback('buildlink') do |_c, url|
        begin
          Sketchup.write_default('WR_BoothLink', 'link', url.to_s.delete('"'))
        rescue Exception
          nil
        end
        f = File.join(SCRIPTS_DIR, 'booth-from-link.rb')
        if File.exist?(f)
          run(f)
        else
          UI.messagebox('booth-from-link.rb is not in the scripts folder.')
        end
        push
      end
      d.add_action_callback('ability') do |_c, id, on|
        _ok, msg = toggle(id, on.to_s == 'true')
        push_note(msg)
      end
      d.add_action_callback('setting') do |_c, id, key, value|
        save_setting(id, key, value)
        push
      end
      d.add_action_callback('folder')  { |_c| UI.openURL('file:///' + SCRIPTS_DIR) }
      d.add_action_callback('console') { |_c| Sketchup.send_action('showRubyPanel:') }
      d.set_on_closed { @dlg = nil }
      @dlg = d
    end

    def self.open_panel
      d = panel
      return unless d
      d.visible? ? d.bring_to_front : d.show
    end

    # ------------------------------------------------------------------- icons --

    # SVG renders crisply at any toolbar size; the old PNGs stay as a fallback
    # so a partial install still shows buttons rather than blanks.
    def self.icon_for(tag, size)
      dir = File.dirname(__FILE__)
      svg = File.join(dir, "icon-#{tag}.svg")
      return svg if File.exist?(svg)
      png = File.join(dir, "icon-#{tag}-#{size}.png")
      File.exist?(png) ? png : ''
    end

    # The action is taken as an explicit block and handed straight to
    # UI::Command. Using `yield` inside the command's own block would leave it
    # reaching back into a method frame that returned at load time, which is
    # exactly the kind of thing that works until it doesn't.
    def self.command(label, tag, status, &action)
      cmd = UI::Command.new(label, &action)
      cmd.tooltip         = label
      cmd.status_bar_text = status
      cmd.small_icon      = icon_for(tag, 24)
      cmd.large_icon      = icon_for(tag, 32)
      cmd
    end

    # --------------------------------------------------------------------- UI --

    def self.build_ui
      menu = UI.menu('Plugins').add_submenu('WhisperRoom')
      menu.add_item('WhisperRoom Panel...') { open_panel }
      menu.add_separator

      # Menus cannot be rebuilt later, so this list is frozen at load time.
      # The panel is the live one.
      scan.each { |s| menu.add_item(s['title']) { run(s['file']) } }

      menu.add_separator
      menu.add_item('Open Scripts Folder') { UI.openURL('file:///' + SCRIPTS_DIR) }
      menu.add_item('Ruby Console')        { Sketchup.send_action('showRubyPanel:') }

      tb = UI::Toolbar.new('WhisperRoom')
      tb.add_item(command('WhisperRoom Panel', 'panel',
                          'Browse and run WhisperRoom scripts') { open_panel })

      # ---- customisable slots on the toolbar -------------------------------
      #
      # All PIN_N buttons are created here, once, at load (api-issue-tracker
      # #628). What each one RUNS is looked up at click time, so re-assigning a
      # slot in the panel takes effect immediately. The FACE is read from
      # preferences right here, before the command exists, because that is the
      # only moment SketchUp reliably takes it.
      tb.add_separator
      @fav_cmds = []
      PIN_N.times do |i|
        s = favourite_at(i)
        label = s ? s['title'] : "Toolbar slot #{i + 1}"
        cmd = UI::Command.new(label) { run_favourite(i) }
        icon = slot_icon_path(i)
        if File.exist?(icon)
          cmd.small_icon = icon
          cmd.large_icon = icon
        end
        @fav_cmds << cmd
        tb.add_item(cmd)
      end
      refresh_fav_labels

      tb.add_separator
      tb.add_item(command('Scripts Folder', 'folder',
                          'Open the scripts folder') { UI.openURL('file:///' + SCRIPTS_DIR) })
      tb.add_item(command('Ruby Console', 'console',
                          'Open the Ruby Console') { Sketchup.send_action('showRubyPanel:') })
      tb.show
    end

    unless file_loaded?(__FILE__)
      build_ui
      file_loaded(__FILE__)
    end
  end
end
