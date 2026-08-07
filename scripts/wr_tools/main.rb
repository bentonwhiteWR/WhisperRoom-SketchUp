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

    # wr-booth-data.rb is data loaded by build-booth.rb, not a command.
    SKIP     = ['wr_tools.rb', 'wr-booth-data.rb'].freeze
    PREF_KEY = 'WR_Tools'.freeze
    RECENT_N = 5
    FRESH_H  = 24        # a script touched this recently gets a NEW pill

    # ---------------------------------------------------------------- scanning --

    def self.script_files
      return [] unless File.directory?(SCRIPTS_DIR)
      Dir.entries(SCRIPTS_DIR)
         .select { |f| f =~ /\.rb\z/i }
         .reject { |f| SKIP.include?(f) }
         .map    { |f| File.join(SCRIPTS_DIR, f) }
    end

    # Pull "@title" and the comment paragraph under it out of a script header.
    def self.meta_of(path)
      title = nil
      blurb = []
      started = false
      File.foreach(path).with_index do |line, i|
        break if i > 40
        unless line =~ /^\s*#/
          break unless line.strip.empty?
          next
        end
        text = line.sub(/^\s*#\s?/, '').rstrip
        if text =~ /^@title\s+(.+)$/
          title = Regexp.last_match(1).strip.sub(/\.\.\.\z/, '')
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
      [title, blurb.join(' ')]
    rescue StandardError
      [nil, '']
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
    def self.scan
      script_files.map { |path|
        title, blurb = meta_of(path)
        mtime = File.mtime(path)
        {
          'file'  => path,
          'name'  => File.basename(path),
          'title' => title || pretty(File.basename(path)),
          'blurb' => blurb,
          'ago'   => ago(mtime),
          'fresh' => (Time.now - mtime) < FRESH_H * 3600,
          'stamp' => mtime.to_i
        }
      }.sort_by { |s| -s['stamp'] }
    end

    # ---------------------------------------------------------------- recents --

    def self.recent
      JSON.parse(Sketchup.read_default(PREF_KEY, 'recent', '[]').to_s)
    rescue StandardError
      []
    end

    def self.remember(name)
      list = ([name] + recent.reject { |n| n == name }).first(RECENT_N)
      Sketchup.write_default(PREF_KEY, 'recent', list.to_json)
    rescue StandardError
      nil
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
      { 'dir' => SCRIPTS_DIR, 'scripts' => scan, 'recent' => recent }
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
