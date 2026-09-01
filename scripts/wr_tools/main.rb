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
    # Where the scripts live. Machines differ — the laptop keeps Documents local,
    # the desktop has it redirected into OneDrive, and the repo may sit at
    # Claude/Sketchup or Claude/Sketchup/WhisperRoom-SketchUp. Take the first
    # candidate that actually exists rather than hard-coding one machine. Set the
    # WR_SCRIPTS_DIR environment variable to override.
    #
    # THE BUNDLED COPY IS LAST ON PURPOSE, and the order is the whole design.
    #
    # install-plugin.py copies scripts/ into the plugin folder as well, so a
    # machine with no git checkout — a teammate's — still gets every script and
    # the plugin is self-contained. But on a machine that HAS the repo, the repo
    # wins, because editing a script there has to take effect on the next run
    # without a reinstall. Put the bundled copy first and every edit would
    # silently do nothing until install-plugin.py was run again, which is a
    # miserable thing to debug.
    BUNDLED = File.join(File.dirname(__FILE__), 'scripts').tr('\\', '/').freeze

    CANDIDATES = [
      ENV['WR_SCRIPTS_DIR'],
      File.join(ENV['USERPROFILE'].to_s, 'Documents/Claude/Sketchup/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'OneDrive/Documents/Claude/Sketchup/scripts'),
      File.join(ENV['USERPROFILE'].to_s, 'OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts'),
      BUNDLED
    ].compact.map { |p| p.tr('\\', '/') }.freeze

    SCRIPTS_DIR = (CANDIDATES.find { |p| File.directory?(p) } || BUNDLED)

    # True when running off the copy inside the plugin — i.e. a machine with no
    # repo. The panel says so, because "I edited the script and nothing changed"
    # is the failure that follows, and it is invisible otherwise.
    def self.bundled?
      SCRIPTS_DIR == BUNDLED
    end

    # Libraries other scripts `load`, not commands. wr-booth-data.rb is data for
    # build-booth.rb; wr-shading.rb is the shading contract both component-art
    # exporters share.
    SKIP     = ['wr_tools.rb', 'wr-booth-data.rb', 'wr-shading.rb',
                'wr-folder.rb', 'wr-deck.rb', 'wr-overlays.rb',
                'wr-roof-vent.rb', 'wr-bridge-lib.rb'].freeze
    PREF_KEY = 'WR_Tools'.freeze
    RECENT_N = 5

    # THREE TOOLBARS, NOT THREE ROWS. SketchUp gives no control over how a
    # single toolbar wraps — the user drags it and it wraps where it wraps.
    # What it does allow is several named toolbars, each docked, positioned and
    # shown independently from View > Toolbars. So "another row of favourites"
    # is three UI::Toolbar objects, which is better than a row: the V-Ray bar
    # can be hidden outright on a day that has no rendering in it.
    #
    # Bar 1 keeps the name 'WhisperRoom' so its saved screen position, and the
    # Panel / Folder / Console buttons that live on it, survive the upgrade.
    BARS = [
      { :key => 'w', :name => 'WhisperRoom',       :label => 'WhisperRoom' },
      { :key => 'v', :name => 'WhisperRoom V-Ray', :label => 'V-Ray' },
      { :key => 't', :name => 'WhisperRoom Tech',  :label => 'Tech' }
    ].freeze

    PIN_N    = 6                    # slots per bar
    SLOT_N   = BARS.length * PIN_N  # 18 across all three
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
    #
    # "# @icon <id>" is OPTIONAL and ADDITIVE. It names a symbol in the panel's
    # icon sprite. A script that does not declare one is resolved through
    # icon-map.json instead, so the icon rollout costs one JSON file rather than
    # an edit to every script — see icon_of.
    #
    # "# @rank <n>" is OPTIONAL and ADDITIVE, and it exists for one reason: a
    # few categories are LADDERS, not sets. Sorted alphabetically, "Build the
    # booth" opens with the fast low-detail block-out and buries the tool that
    # builds the customer's actual configuration — the eye lands on the first
    # row, so alphabetical there does not merely fail to help, it points at the
    # wrong tool. Lower ranks sort first; a script with no @rank sorts after
    # every ranked one, alphabetically among its peers. So ranking is opt-in per
    # script, costs nothing on the thirty that ignore it, and no script has to
    # be edited for the panel to render.
    def self.meta_of(path)
      title = nil
      blurb = []
      started = false
      abil = nil
      icon = nil
      rank = nil
      dialog = false
      File.foreach(path).with_index do |line, i|
        break if i > 60
        unless line =~ /^\s*#/
          break unless line.strip.empty?
          next
        end
        text = line.sub(/^\s*#\s?/, '').rstrip
        if text =~ /^@title\s+(.+)$/
          raw = Regexp.last_match(1).strip
          # The trailing "..." means "this one opens a dialog first". It is
          # stripped from the label — the panel draws a window glyph instead —
          # but the fact has to survive the strip or the glyph has nothing to
          # go on. rename() still round-trips the dots in the file itself.
          dialog = !(raw =~ /(\.\.\.|…)\z/).nil?
          title = raw.sub(/(\.\.\.|…)\z/, '').strip
          next
        end
        if text =~ /^@icon\s+(\S+)/
          icon = Regexp.last_match(1).strip
          next
        end
        # Integers only, and anything else is left as no rank at all rather
        # than silently becoming 0 — which would sort a typo to the top.
        if text =~ /^@rank\s+(-?\d+)\s*$/
          rank = Regexp.last_match(1).to_i
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
      [title, blurb.join(' '), abil, icon, dialog, rank]
    rescue StandardError
      [nil, '', nil, nil, false, nil]
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

    # A script that is not a daily tool says so itself, the same way an ability
    # does — "# @shelf dev", "# @shelf workshop", "# @shelf archive". The panel
    # keeps those off the default list behind a footer switch, but search still
    # finds them, so hiding never means losing. Parsed beside @cat rather than
    # kept in a list here, for the same reason abilities are: a list here would
    # drift away from the files it describes.
    SHELVES = %w[dev workshop archive].freeze

    # ------------------------------------------------------------- version --
    #
    # ONE file holds the version: wr_tools/VERSION. install-plugin.py copies
    # every file in wr_tools/, so it ships with the plugin, and the update
    # check fetches THAT SAME PATH from GitHub. One file cannot drift against
    # itself, which two (a constant here and a file in the repo) certainly
    # would.
    VERSION_FILE = File.join(File.dirname(__FILE__), 'VERSION').freeze
    # THE API, NOT raw.githubusercontent.com.
    #
    # raw sits behind a CDN that served a FIVE MINUTE STALE version in testing:
    # the API returned 1.2.9 while raw was still handing out 1.2.8, and a
    # cache-busting query string did not shift it. A push followed by "check
    # for the update" would show nothing -- exactly the moment the check has to
    # be right.
    #
    # The API with Accept: application/vnd.github.raw returns the file body
    # directly, no JSON to parse. Rate limited to 60/hour unauthenticated; this
    # asks once per panel open, so nobody will meet it.
    VERSION_URL  = 'https://api.github.com/repos/bentonwhiteWR/' \
                   'WhisperRoom-SketchUp/contents/scripts/wr_tools/VERSION'.freeze

    def self.version
      @version ||= (File.read(VERSION_FILE).strip rescue '0.0.0')
    end

    # "1.10.0" is NEWER than "1.9.0". String compare gets that backwards, so
    # compare the numbers as numbers. Anything unparseable sorts as 0 rather
    # than raising — a malformed VERSION should mean "no banner", never a
    # broken panel.
    def self.newer?(remote, local)
      r = remote.to_s.strip.split('.').map(&:to_i)
      l = local.to_s.strip.split('.').map(&:to_i)
      3.times do |i|
        a = r[i] || 0
        b = l[i] || 0
        return true  if a > b
        return false if a < b
      end
      false
    end

    # Asks GitHub once per session, in the background, and NEVER blocks the
    # panel. No network, no GitHub, a 404, junk in the file — all of them just
    # leave @remote nil and the banner never appears. An update notice is a
    # nicety; it must not be able to take the tool down.
    #
    # The request object is retained in @upd for the same reason booth-from-
    # link.rb retains its own: SketchUp garbage-collects a local one before the
    # response lands and the callback silently never runs.
    def self.check_update(&done)
      return if @checked
      @checked = true
      req = Sketchup::Http::Request.new(VERSION_URL, Sketchup::Http::GET)
      # Without the Accept header the API answers with JSON and the version
      # regex below rejects it, which would look exactly like 'no update'.
      (req.headers = { 'Accept' => 'application/vnd.github.raw',
                       'User-Agent' => 'WhisperRoom-Tools' }) rescue nil
      @upd = req
      req.start do |_r, res|
        begin
          if res.status_code == 200
            v = res.body.to_s.strip[0, 20]
            @remote = v if v =~ /\A\d+\.\d+(\.\d+)?\z/
          end
        rescue Exception
          @remote = nil
        end
        done.call if done
      end
    rescue Exception
      nil
    end

    # The repo this plugin's scripts came from, or nil when running off the
    # bundled copy. SCRIPTS_DIR is <repo>/scripts, so the repo is its parent —
    # and it only counts if it really is a git checkout.
    def self.repo_dir
      return nil if bundled?
      root = File.dirname(SCRIPTS_DIR)
      File.directory?(File.join(root, '.git')) ? root : nil
    end

    # ONE-CLICK UPDATE, and deliberately the boring version of it.
    #
    # It runs the two commands you would type: `git pull`, then the installer.
    # It does NOT download files itself and write them over the running plugin.
    # That version has to be all-or-nothing — a half-finished download leaves
    # the plugin broken and the panel you would fix it with is the thing that
    # broke. Git already solves that: a failed pull changes nothing, and the
    # installer is a script that has been run a hundred times.
    #
    # Overwriting the .rb files while SketchUp holds them is safe. They are
    # already parsed and in memory; the new ones are picked up at restart,
    # which is exactly what the manual route does today.
    def self.update_now
      root = repo_dir
      unless root
        push_note('No git checkout found - this is the bundled copy. ' \
                  'Clone the repo and run install-plugin.py to update.')
        return
      end
      push_note('Updating...')

      # THIS RUNS FROM A BATCH FILE, AND BOTH OF THE OBVIOUS SHORTCUTS FAILED.
      #
      # 1. Backticks return "" in SketchUp's Ruby on Windows. Measured:
      #    `git --version` -> "". The process spawns; it is the PIPE that does
      #    not work. So output has to go to a file and be read back.
      #
      # 2. system('cmd /c cd /d "..." && git pull ...') reported
      #    "fatal: not a git repository". Ruby sees the shell metacharacters and
      #    wraps the whole string in ANOTHER cmd, and the nesting rebinds the
      #    && : the cd runs in a child process that then exits, and git runs in
      #    SketchUp's own directory. The same string spawned directly works
      #    fine, which is what made it confusing.
      #
      # A batch file has none of that. Ruby launches one quoted path with no
      # metacharacters in it, so there is no second shell and nothing to
      # re-parse. cmd reads the file line by line exactly as written, and
      # `if errorlevel 1 exit /b 1` gives the "do not install on top of a failed
      # pull" rule without relying on && surviving anything.
      log = File.join(ENV['TEMP'].to_s, 'wr_update.log')
      bat = File.join(ENV['TEMP'].to_s, 'wr_update.bat')
      (File.delete(log) rescue nil)
      inst = File.join(root, 'scripts', 'install-plugin.py')
      begin
        File.open(bat, 'w') do |f|
          f.puts '@echo off'
          f.puts 'cd /d "' + root + '"'
          f.puts 'git pull > "' + log + '" 2>&1'
          f.puts 'if errorlevel 1 exit /b 1'
          f.puts 'python "' + inst + '" >> "' + log + '" 2>&1'
        end
        system('"' + bat + '"')
      rescue Exception => e
        push_note("Update failed to start: #{e.class}: #{e.message}")
        return
      end

      out = (File.read(log) rescue '')
      puts ''
      puts '=' * 66
      puts 'WHISPERROOM UPDATE'
      puts '=' * 66
      puts(out.to_s.empty? ? '  (no output - is git or python missing from PATH?)' : out)
      puts '=' * 66

      if out =~ /installed ->/
        # Let the next open ask GitHub again, so the banner clears once the new
        # version is really in place.
        @checked = false
        @remote  = nil
        push_note('Updated. RESTART SKETCHUP for it to take effect.')
      elsif out.to_s.empty?
        push_note('Update produced no output - git or python may not be on ' \
                  "SketchUp's PATH. See the Ruby Console.")
      else
        push_note("Update did not complete: #{out.to_s.lines.last.to_s.strip}")
      end
    end

    def self.update_ready?
      !@remote.nil? && newer?(@remote, version)
    end

    def self.remote_version
      @remote
    end

    # --------------------------------------------------------------- tabs --
    #
    # Two tabs, because a one-off client drawing is not a tool. The everyday
    # kit is what the panel is for; "CSUSB room 106" is a thing that was drawn
    # once for one customer and will never be run again, and it should not sit
    # between the booth builder and the exporters.
    #
    # "# @tab client" puts a script on the second tab. Anything without the
    # header stays on the first, so no existing script had to be edited to keep
    # working, and a typo lands a script on the DEFAULT tab rather than
    # vanishing into a tab nobody looks at.
    TABS = %w[tools client].freeze

    def self.tab_of(path)
      File.foreach(path).with_index do |line, i|
        break if i > 60
        next unless line =~ /^\s*#/
        m = line.match(/^\s*#\s*@tab\s+(\S+)/)
        next unless m
        t = m[1].strip.downcase
        return TABS.include?(t) ? t : 'tools'
      end
      'tools'
    rescue StandardError
      'tools'
    end

    def self.shelf_of(path)
      File.foreach(path).with_index do |line, i|
        break if i > 60
        next unless line =~ /^\s*#/
        m = line.match(/^\s*#\s*@shelf\s+(\S+)/)
        next unless m
        s = m[1].strip.downcase
        return SHELVES.include?(s) ? s : nil
      end
      nil
    rescue StandardError
      nil
    end

    def self.scan
      script_files.map { |path|
        title, blurb, abil, icon, dialog, rank = meta_of(path)
        mtime = File.mtime(path)
        name  = File.basename(path)
        {
          'file'    => path,
          'name'    => name,
          'title'   => title || pretty(name),
          'cat'     => cat_of(path),
          'shelf'   => shelf_of(path),
          'tab'     => tab_of(path),
          'icon'    => icon_of(name, icon),
          'dialog'  => dialog,
          'rank'    => rank,
          'blurb'   => blurb,
          # ago and name stay in the payload even though no row prints them any
          # more — the redesigned rows carry both in their tooltip.
          'ago'     => ago(mtime),
          'fresh'   => (Time.now - mtime) < FRESH_H * 3600,
          'stamp'   => mtime.to_i,
          'ability' => abil
        }
      }.sort_by { |s| -s['stamp'] }
    end

    # ------------------------------------------------------------ list icons --
    #
    # THE SEAM WITH THE ICON SET, and it is deliberately loose at both ends.
    #
    # Two files, neither of which this plugin can require to exist:
    #
    #   wr-icons.svg   one <svg> holding <symbol id="wr-..."> blocks. Shipped to
    #                  the panel verbatim as payload['sprite'] and injected
    #                  there; rows reference symbols with <use href="#wr-...">.
    #   icon-map.json  { "build-room.rb": "wr-room", ... } — filename to symbol
    #                  id, so the rollout costs one file instead of 40 header
    #                  edits.
    #
    # Resolution per script: its own "# @icon" line, then the map, then
    # DEFAULT_ICON. Ids are normalised to the "wr-" prefix so the map may be
    # written either way round without breaking.
    #
    # If EITHER file is missing every script still resolves to DEFAULT_ICON and
    # the panel still draws every row — a missing sprite must degrade to a plain
    # glyph, never to a blank list, because the list is the whole panel.

    DEFAULT_ICON = 'wr-default'.freeze

    def self.wr_id(id)
      s = id.to_s.strip
      return nil if s.empty?
      s.start_with?('wr-') ? s : "wr-#{s}"
    end

    def self.icon_map
      @icon_map ||= begin
        path = File.join(File.dirname(__FILE__), 'icon-map.json')
        out = {}
        if File.exist?(path)
          begin
            parsed = JSON.parse(File.read(path))
            out = parsed if parsed.is_a?(Hash)
          rescue StandardError
            out = {}
          end
        end
        out
      end
    rescue StandardError
      {}
    end

    def self.icon_of(name, declared)
      wr_id(declared) || wr_id(icon_map[name]) || DEFAULT_ICON
    rescue StandardError
      DEFAULT_ICON
    end

    # The sprite, read fresh on every render so dropping in a new wr-icons.svg
    # shows up on Rescan rather than at the next SketchUp launch — the same
    # promise the script folder makes.
    def self.sprite
      path = File.join(File.dirname(__FILE__), 'wr-icons.svg')
      File.exist?(path) ? File.read(path) : ''
    rescue StandardError
      ''
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
    # The three toolbars carry SLOT_N customisable buttons between them, PIN_N
    # on each. Each SLOT holds two
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
    # STORAGE. Two pipe-joined lists of exactly SLOT_N entries, positionally
    # aligned, with SLOT_EMPTY for an unused slot — read_list drops empty
    # strings, so a genuinely empty entry needs a placeholder or every slot
    # after it shifts up one.
    #
    # The list is FLAT across all three bars: index b * PIN_N + i is slot i of
    # bar b. That is what makes the upgrade from one 8-slot bar free — padding
    # an old 8-entry list out to 18 lands entries 7 and 8 on bar 2, which is
    # exactly where they belong. No migration branch, and nothing to get wrong.

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
      out = list.first(SLOT_N).map { |v| v.to_s.empty? ? SLOT_EMPTY : v.to_s }
      out + Array.new(SLOT_N - out.length, SLOT_EMPTY)
    end

    # Which bar a flat slot index belongs to, and its seat on that bar.
    def self.bar_of(i)
      BARS[i.to_i / PIN_N] || BARS[0]
    end

    def self.seat_of(i)
      (i.to_i % PIN_N) + 1
    end

    # "V-Ray 3" — how a slot is named everywhere a human reads it.
    def self.slot_label(i)
      "#{bar_of(i)[:label]} #{seat_of(i)}"
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
      return if i < 0 || i >= SLOT_N
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
        UI.messagebox("Toolbar slot #{slot_label(i)} is empty.\n\n" \
                      "Open the WhisperRoom panel and click #{slot_label(i)} in " \
                      "the Toolbars section to give it a script and an icon.")
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

    # Two prefixes now. wr-ico-*.svg is the purpose-built WhisperRoom set and it
    # is offered FIRST, because it is the one that says what a tool does; the
    # generic ico-*.svg library stays because saved slot preferences still point
    # at those ids and a slot that stopped resolving would drop back to a
    # numbered face. Ids are kept distinct by the prefix — a wr- id can never
    # collide with a legacy one.
    #
    # 'file' is resolved here rather than rebuilt in the panel. The panel used
    # to build "ico-<id>.svg" itself, which was one more place for the two to
    # disagree about the same slot.
    def self.icon_library
      dir = File.dirname(__FILE__)
      wr = Dir.glob(File.join(dir, 'wr-ico-*.svg')).sort.map { |p|
        id = "wr-#{File.basename(p, '.svg').sub(/\Awr-ico-/, '')}"
        { 'id' => id, 'label' => icon_labels[id] || pretty(id.sub(/\Awr-/, '')),
          'file' => File.basename(p), 'wr' => true }
      }
      old = Dir.glob(File.join(dir, 'ico-*.svg')).sort.map { |p|
        id = File.basename(p, '.svg').sub(/\Aico-/, '')
        { 'id' => id, 'label' => icon_labels[id] || pretty(id),
          'file' => File.basename(p), 'wr' => false }
      }
      wr + old
    rescue StandardError
      []
    end

    # An icon id from preferences, resolved to a file on disk. Saved prefs
    # predate the wr- set and hold bare ids like "ruler", so the legacy name is
    # tried first and both spellings of a wr- id resolve. Returns nil when
    # nothing matches, so the caller can fall through to its own default.
    def self.icon_file(id)
      return nil if blank?(id)
      dir = File.dirname(__FILE__)
      bare = id.to_s.sub(/\Awr-/, '')
      [File.join(dir, "ico-#{id}.svg"),
       File.join(dir, "wr-ico-#{bare}.svg"),
       File.join(dir, "icon-#{id}.svg")].find { |p| File.exist?(p) }
    rescue StandardError
      nil
    end

    # The FILE a slot's button wears, resolved from an explicit pair of lists so
    # the same three-step fallback answers for both the live preferences and
    # what the toolbar was built with.
    #
    #   1. the library icon the user picked
    #   2. the legacy per-script face, for slots assigned before the library
    #   3. the numbered star
    #
    # THE PANEL MUST USE THIS TOO. It used to draw a bare number whenever no
    # library icon had been picked, while the toolbar quietly fell through to
    # step 2 and drew the per-script face. Two rules for one slot, so the row in
    # the panel did not match the row above the viewport — reported, and fair.
    # Ruby resolves it once now and ships the answer to the panel.
    def self.face_path(i, names, icons)
      dir = File.dirname(__FILE__)
      chosen = icons[i]
      unless blank?(chosen)
        p = icon_file(chosen)
        return p if p
      end
      name = names[i]
      unless blank?(name)
        key = FAV_ICONS[name]
        p = key && File.join(dir, "icon-#{key}.svg")
        return p if p && File.exist?(p)
      end
      File.join(dir, "icon-fav-#{bar_of(i)[:key]}#{seat_of(i)}.svg")
    rescue StandardError
      File.join(File.dirname(__FILE__), 'icon-fav1.svg')
    end

    def self.slot_icon_path(i)
      face_path(i, slots, slot_icons)
    end

    # Basenames, for the panel — it loads them as <img src> relative to itself.
    def self.faces(names, icons)
      (0...SLOT_N).map { |i| File.basename(face_path(i, names, icons)) }
    end

    # What the REAL SketchUp toolbar is currently wearing, captured when the
    # buttons were built. Preferences move the moment you save a slot; the
    # native toolbar does not. Keeping both lets the panel show the difference
    # honestly instead of drawing a row that quietly disagrees with the one
    # above the viewport.
    def self.bound_slots
      @bound_slots || Array.new(SLOT_N, SLOT_EMPTY)
    end

    def self.bound_icons
      @bound_icons || Array.new(SLOT_N, SLOT_EMPTY)
    end

    # Slots whose saved mapping no longer matches the button on screen.
    def self.pending_slots
      (0...SLOT_N).select { |i|
        slots[i] != bound_slots[i] || slot_icons[i] != bound_icons[i]
      }
    end

    # Tooltips ARE settable after the command is created, so a slot can be
    # re-pointed without rebuilding the toolbar, and the ACTION is always
    # current because it resolves the slot list at click time.
    #
    # The ICON is re-assigned here too, and then the toolbar is asked to show
    # itself again, which on some builds forces a repaint. Neither is promised:
    # SketchUp offers no API to remove or rebuild a toolbar button, and
    # small_icon= after add_item is documented nowhere as repainting. So the
    # attempt is made, and whether it took is reported rather than assumed —
    # the panel marks a slot as pending until the next launch confirms it.
    def self.refresh_fav_labels
      return if @fav_cmds.nil?
      @fav_cmds.each_with_index do |cmd, i|
        s = favourite_at(i)
        text = s ? "#{s['title']}  (#{slot_label(i)})" : "#{slot_label(i)} — empty"
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
      # A nudge, not a rebuild. Harmless if it does nothing.
      (@toolbars || []).each { |tb| (tb.show if tb.visible?) rescue nil }
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
        'builtin'  => true,
        # Every other ability rides in on its script's own @cat and @icon. This
        # one has no script, so it declares both here — next to the definition,
        # which is the same rule.
        'cat'      => 'Add dimensions',
        'icon'     => 'wr-ghost'
      }]
    end

    def self.abilities
      out = builtin_abilities
      scan.each do |s|
        a = s['ability']
        next unless a
        # cat and icon travel with the ability so the panel can draw it as ONE
        # row inside its own category — the script and its switch are the same
        # tool, and drawing them twice under two names is what the redesign
        # removed.
        out << a.merge('id' => s['name'], 'file' => s['file'],
                       'script' => s['title'], 'builtin' => false,
                       'cat' => s['cat'], 'icon' => s['icon'],
                       'shelf' => s['shelf'])
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
    #
    # THE LOAD MUST BE GUARDED, and this was a real defect until 2026-08-15.
    #
    # Every ability script ends with a top-level autorun — the line that makes
    # `load "…/explode-view.rb"` in the Ruby Console actually do something. This
    # method loads the file to pick up edits, so without a guard flipping a
    # switch ALSO ran the script's normal entry point: a modal dialog appeared,
    # then the ability did the work a second time with different settings.
    # explode-view.rb's own header says the ability path exists precisely so a
    # modal never gets in the way of a toggle.
    #
    # BOTH globals are set because the scripts disagree about the name —
    # auto-dimension.rb reads $wr_suppress_autorun, the other four read
    # $wr_no_autorun. Setting both means neither script has to change and a new
    # ability written to either spelling is already covered. Restored after,
    # the way booth-from-link.rb and build-room.rb do it, because leaving them
    # set would silence the autorun for the next script RUN from the list —
    # which would look exactly like a dead button.
    def self.load_quietly(file)
      was_no, was_sup = $wr_no_autorun, $wr_suppress_autorun
      $wr_no_autorun = true
      $wr_suppress_autorun = true
      begin
        load file
      ensure
        $wr_no_autorun = was_no
        $wr_suppress_autorun = was_sup
      end
    end

    # RESCUE Exception HERE TOO, FOR THE REASON SPELLED OUT ABOVE run().
    #
    # This path `load`s a script and then `eval`s its @on/@off expression, so it
    # is a place a script's own code runs — and it used to rescue StandardError.
    # A SyntaxError in the loaded file descends from ScriptError, NOT
    # StandardError, so it sailed straight past that handler, out of the
    # action callback, and into SketchUp, which swallows it. Flipping a switch
    # would then do NOTHING AT ALL: no dimensions, no message box, not even the
    # "ABILITY FAILED" console line that was supposed to be the safety net. The
    # one failure mode this plugin cannot afford, in the one path whose whole
    # job is to re-read a file that is edited live from the repo.
    #
    # The console breadcrumb below exists for the same reason. It is printed
    # BEFORE anything can go wrong, so "did the click even reach Ruby?" — the
    # first question every one of these reports raises — is answerable by
    # looking at the Ruby Console instead of by guessing.
    def self.toggle(id, on)
      a = abilities.find { |x| x['id'] == id }
      return [false, "No such ability: #{id}"] unless a

      puts "ABILITY #{id} — switching #{on ? 'ON' : 'OFF'}"

      if a['builtin']
        ok, msg = toggle_ghost(on)
        set_state(id, on) if ok
        return [ok, msg]
      end

      unless File.exist?(a['file'].to_s)
        return [false, "Script is gone: #{a['file']}"]
      end
      load_quietly(a['file'])            # re-read every time, so edits take effect
      opts = values_for(a)
      expr = on ? a['on'] : a['off']
      result = eval(expr, binding, a['file'])   # rubocop:disable Security/Eval
      if result == false
        return [false, "#{a['label']} could not #{on ? 'start' : 'stop'} — see the console."]
      end
      set_state(id, on)
      [true, "#{a['label']} #{on ? 'on' : 'off'}"]
    rescue Exception => e
      script = File.basename(a && a['file'] ? a['file'].to_s : id.to_s)
      puts ''
      puts "ABILITY FAILED (#{id}, #{on ? 'on' : 'off'}): #{e.class}: #{e.message}"
      puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n") if e.backtrace
      # A broken script is not a "the switch did not take" note — it is a
      # damaged file, and it gets a box, the same as the run path gives one.
      if e.is_a?(ScriptError)
        UI.messagebox("#{script} failed to load:\n\n#{e.class}: #{e.message}\n\n" \
                      'This is a SYNTAX ERROR — the script did not even load, so the ' \
                      "switch could not do anything. The line number above is where " \
                      "to look.\n\nFull backtrace is in the Ruby Console.")
      end
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
    #
    # Read that fact off meta_of's DIALOG FLAG, not off the title it returns.
    # meta_of strips the dots before handing the title back — the panel draws a
    # glyph instead — so testing `title.end_with?('...')` was always false and
    # the dots could never be re-appended. Every rename of a dialog tool quietly
    # demoted it to a run-immediately one, permanently, because the fact was
    # then gone from the file. The flag is the only copy that survives the strip.

    def self.rename(name, title)
      base = File.basename(name.to_s)
      return [false, 'Not a script in this folder.'] if base != name.to_s || base.empty?
      return [false, 'That file is not renameable.'] if SKIP.include?(base)
      path = File.join(SCRIPTS_DIR, base)
      return [false, "Not found: #{base}"] unless File.exist?(path)

      want   = title.to_s.strip.gsub(/\s+/, ' ')
      dialog = meta_of(path)[4]
      # Accept either spelling on the way in, so a person who typed the dots
      # themselves does not end up with six of them.
      want += '...' if dialog && !want.empty? && !(want =~ /(\.\.\.|…)\z/)

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

    # RESCUE Exception, NOT StandardError, AND THE REASON MATTERS.
    #
    # A script with a syntax error raises SyntaxError, which descends from
    # ScriptError, NOT from StandardError. A `rescue StandardError` therefore
    # does not catch it: the exception escapes the action callback, SketchUp
    # swallows it, and clicking the script does NOTHING AT ALL. No dialog, no
    # console line, no clue. That is exactly how a broken save-scene-components
    # presented — "I click it but nothing happens" — and it cost a round trip to
    # work out that a script had been damaged rather than the panel.
    #
    # This is the second time this distinction has bitten this plugin; the first
    # took the whole extension down at load. Anywhere a script's own code runs,
    # rescue Exception.
    def self.run(path)
      unless File.exist?(path)
        UI.messagebox("Not found:\n#{path}")
        return false
      end
      remember(File.basename(path))
      load path
      true
    rescue Exception => e
      name = File.basename(path)
      puts ''
      puts "#{name} FAILED TO RUN: #{e.class}: #{e.message}"
      puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n") if e.backtrace
      hint = if e.is_a?(ScriptError)
               "\n\nThis is a SYNTAX ERROR — the script did not even load. The " \
               "line number above is where to look."
             else
               ''
             end
      UI.messagebox("#{name} failed:\n\n#{e.class}: #{e.message}#{hint}\n\n" \
                    'Full backtrace is in the Ruby Console.')
      false
    end

    # ------------------------------------------------------------------ panel --

    # ---------------------------------------------------------- panel state --
    #
    # Which categories are collapsed and whether the shelved tools are showing
    # are the panel's own furniture, not facts about the model, so they live in
    # preferences and survive a reopen. Pipe-joined for the reason every list
    # here is pipe-joined — read_default EVALS what it stored, so a quote in the
    # value takes the extension down at load. A category name cannot contain a
    # pipe.
    def self.collapsed
      read_list('ui_collapsed')
    end

    def self.set_collapsed(list)
      write_list('ui_collapsed', list.to_s.split(LIST_SEP).reject(&:empty?))
    end

    def self.dev_shown?
      read_pref('ui_dev', 'false') == 'true'
    end

    def self.set_dev_shown(on)
      write_pref('ui_dev', on ? 'true' : 'false')
    end

    def self.payload
      # Read the map once per render, not once per launch. Dropping a new
      # icon-map.json in and hitting Rescan has to work, the same way dropping
      # in a new script does — the memo is there to stop 28 reads inside one
      # render, not to freeze the file until the next launch.
      @icon_map = nil
      { 'dir' => SCRIPTS_DIR, 'bundled' => bundled?,
        # Version and the update banner. `update` is nil until GitHub has
        # answered, which is the whole point — the panel renders immediately
        # and the banner appears later if there is one, or never.
        'version' => version, 'update' => (update_ready? ? remote_version : nil),
        'can_update' => !repo_dir.nil?,
        # The icon sprite travels with the payload rather than being fetched by
        # the page: an HtmlDialog has no network guarantee and a file:// fetch
        # out of the dialog is not reliably permitted.
        'sprite' => sprite,
        'collapsed' => collapsed, 'dev' => dev_shown?,
        'scripts' => scan, 'abilities' => abilities,
        'recent' => recent, 'pinned' => pinned, 'note' => @note,
        'slots' => slots, 'slot_icons' => slot_icons,
        'icons' => icon_library, 'pin_n' => PIN_N,
        # Three bars, so the panel draws three labelled rows and names a slot
        # the same way the tooltip above the viewport does.
        'bars' => BARS.map { |b| { 'name' => b[:name], 'label' => b[:label] } },
        'slot_n' => SLOT_N,
        # What the slots WILL wear, and what the native toolbar is wearing right
        # now. They differ between saving a slot and the next launch, and the
        # panel shows that rather than drawing a row that disagrees with the
        # real one.
        'faces' => faces(slots, slot_icons),
        'bound_faces' => faces(bound_slots, bound_icons),
        'bound' => bound_slots,
        'pending' => pending_slots }
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
      d.add_action_callback('ready') do |_c|
        push
        # Ask GitHub AFTER the first render, never before. The panel must open
        # at the same speed with the network down as with it up; the banner
        # arrives on a second push whenever the answer does, or not at all.
        check_update { push }
      end
      d.add_action_callback('rescan')  { |_c| push }
      d.add_action_callback('update')  { |_c| update_now }
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
      # Panel furniture. Neither pushes a re-render: the page already knows what
      # it just did, and a full render would scroll the list out from under the
      # click that caused it.
      d.add_action_callback('collapse')  { |_c, list| set_collapsed(list) }
      d.add_action_callback('devtools')  { |_c, on| set_dev_shown(on.to_s == 'true') }
      d.add_action_callback('folder')  { |_c| UI.openURL('file:///' + SCRIPTS_DIR) }
      d.add_action_callback('console') { |_c| Sketchup.send_action('showRubyPanel:') }
      d.set_on_closed { @dlg = nil }
      @dlg = d
    end

    # Where the panel lands every time it is opened. Left side, clear of the
    # top of the screen. Small enough that it is on-screen on any monitor
    # anyone here actually uses.
    HOME_X = 60
    HOME_Y = 120

    # OPENING THE PANEL ALWAYS PUTS IT BACK. That is not a convenience, it is
    # the fix for a real trap.
    #
    # HtmlDialog remembers its last position under its preferences_key and
    # restores it on open. Move machines, undock a laptop, change a monitor
    # layout, and that saved position can be off the visible desktop. The
    # dialog then opens exactly where it was told to -- somewhere you cannot
    # see -- and, worse, it reports visible? == true, so the old
    # `visible? ? bring_to_front : show` faithfully raised a window that was
    # not on any screen. Clicking the toolbar button did nothing, repeatedly,
    # with no error anywhere. It cost a session to find.
    #
    # So position first, every time, then show. The cost is that a panel you
    # dragged somewhere you liked snaps back on the next open; that is the
    # trade Benton asked for, and it is the right one -- a window that is
    # always somewhere beats a window that is sometimes nowhere.
    def self.open_panel
      d = panel
      return unless d
      (d.set_position(HOME_X, HOME_Y) rescue nil)
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

      # ---- the agent bridge -------------------------------------------------
      #
      # OFF BY DEFAULT. wr_bridge.rb decides for itself whether to start, from
      # an `enabled` marker file in its own root — no marker, no timer, nothing
      # resident but the two menu items it adds here. See its header.
      #
      # RESCUE Exception, for the same reason every other load path in this file
      # does it: a SyntaxError descends from ScriptError, not StandardError, and
      # a fault in the bridge must never be able to take the panel and the
      # toolbars down with it. The console line is the only signal that the load
      # was even attempted.
      menu.add_separator
      begin
        load File.join(File.dirname(__FILE__), 'wr_bridge.rb')
        WhisperRoom::Bridge.add_menu(menu)
      rescue Exception => e
        puts "WR BRIDGE failed to load: #{e.class}: #{e.message}"
        puts e.backtrace.first(6).map { |l| "  #{l}" }.join("\n") if e.backtrace
        menu.add_item('Bridge: FAILED TO LOAD (see Ruby Console)') do
          UI.messagebox("The WhisperRoom bridge did not load:\n\n#{e.class}: #{e.message}")
        end
      end

      # ---- customisable slots, across three toolbars ------------------------
      #
      # All SLOT_N buttons are created here, once, at load (api-issue-tracker
      # #628). What each one RUNS is looked up at click time, so re-assigning a
      # slot in the panel takes effect immediately. The FACE is read from
      # preferences right here, before the command exists, because that is the
      # only moment SketchUp reliably takes it.
      #
      # Three toolbars rather than three rows, because SketchUp has no notion of
      # a row inside a toolbar — it wraps wherever the user drags it to. Three
      # named bars each get their own position, their own dock, and their own
      # entry in View > Toolbars, which is the thing actually wanted: the V-Ray
      # bar can be switched off entirely on a day with no rendering in it.
      #
      # A NEW BAR APPEARS ONLY AFTER A RESTART, and where SketchUp decides to
      # put it the first time is out of our hands. If V-Ray or Tech is nowhere
      # to be seen after the upgrade, it is in View > Toolbars, unticked or
      # parked off-screen — the same trap the panel window has hit before.
      @fav_cmds = []
      @toolbars = []
      # Snapshot what these buttons are being built with. From here until the
      # next launch this is the truth about the native toolbars, whatever the
      # preferences later say.
      @bound_slots = slots
      @bound_icons = slot_icons

      BARS.each_with_index do |bar, b|
        tb = UI::Toolbar.new(bar[:name])

        # The panel, the scripts folder and the console live on bar 1 only.
        # Repeating them on every bar would be three buttons doing one job.
        if b.zero?
          tb.add_item(command('WhisperRoom Panel', 'panel',
                              'Browse and run WhisperRoom scripts') { open_panel })
          tb.add_separator
        end

        PIN_N.times do |seat|
          i = (b * PIN_N) + seat
          s = favourite_at(i)
          label = s ? s['title'] : "Toolbar slot #{slot_label(i)}"
          cmd = UI::Command.new(label) { run_favourite(i) }
          icon = face_path(i, @bound_slots, @bound_icons)
          if File.exist?(icon)
            cmd.small_icon = icon
            cmd.large_icon = icon
          end
          @fav_cmds << cmd
          tb.add_item(cmd)
        end

        if b.zero?
          tb.add_separator
          tb.add_item(command('Scripts Folder', 'folder',
                              'Open the scripts folder') { UI.openURL('file:///' + SCRIPTS_DIR) })
          tb.add_item(command('Ruby Console', 'console',
                              'Open the Ruby Console') { Sketchup.send_action('showRubyPanel:') })
        end

        @toolbars << tb
        tb.show
      end

      @toolbar = @toolbars.first   # kept: older code paths still reach for it
      refresh_fav_labels
    end

    unless file_loaded?(__FILE__)
      build_ui
      file_loaded(__FILE__)
    end
  end
end
