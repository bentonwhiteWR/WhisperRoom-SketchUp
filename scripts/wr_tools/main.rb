# WhisperRoom Tools — menu + toolbar.
#
# Builds its menu from whatever .rb files live in SCRIPTS_DIR, so a new script
# needs no reinstall: drop it in the folder, hit WhisperRoom > Reload Scripts.
#
# A script's menu label comes from its first "# @title" comment line if it has
# one, otherwise from the filename.

require 'sketchup.rb'

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
    SKIP        = ['wr_tools.rb', 'wr-booth-data.rb'].freeze

    def self.scripts
      return [] unless File.directory?(SCRIPTS_DIR)
      Dir.entries(SCRIPTS_DIR)
         .select { |f| f =~ /\.rb\z/i }
         .reject { |f| SKIP.include?(f) }
         .sort
         .map { |f| { :file => File.join(SCRIPTS_DIR, f), :label => title_of(File.join(SCRIPTS_DIR, f), f) } }
    end

    def self.title_of(path, fallback)
      File.foreach(path) do |line|
        return Regexp.last_match(1).strip if line =~ /^#\s*@title\s+(.+)$/
        break if line !~ /^\s*#/ && line.strip != ''
      end
      fallback.sub(/\.rb\z/i, '').tr('-_', '  ').split.map(&:capitalize).join(' ')
    rescue StandardError
      fallback
    end

    def self.run(path)
      unless File.exist?(path)
        UI.messagebox("Not found:\n#{path}")
        return
      end
      load path
    rescue StandardError => e
      UI.messagebox("#{File.basename(path)} failed:\n\n#{e.class}: #{e.message}\n\n#{e.backtrace.first(3).join("\n")}")
    end

    # Rebuild the menu contents. SketchUp can't remove menu items once added, so
    # the menu is built once at load; Reload Scripts re-reads the FILES, which is
    # the part that actually changes while you work.
    def self.build_ui
      menu = UI.menu('Plugins').add_submenu('WhisperRoom')

      scripts.each do |s|
        menu.add_item(s[:label]) { run(s[:file]) }
      end

      menu.add_separator
      menu.add_item('Open Scripts Folder') { UI.openURL('file:///' + SCRIPTS_DIR) }
      menu.add_item('Reload Scripts') do
        n = scripts.size
        UI.messagebox("#{n} script#{n == 1 ? '' : 's'} in\n#{SCRIPTS_DIR}\n\n" \
                      "Newly added files appear after a SketchUp restart; existing " \
                      "ones are re-read from disk every time you run them.")
      end
      menu.add_item('Ruby Console') { Sketchup.send_action('showRubyPanel:') }

      tb = UI::Toolbar.new('WhisperRoom')
      scripts.first(6).each do |s|
        cmd = UI::Command.new(s[:label]) { run(s[:file]) }
        cmd.tooltip         = s[:label]
        cmd.status_bar_text = "Run #{File.basename(s[:file])}"
        cmd.small_icon = icon_for(s[:file], 24)
        cmd.large_icon = icon_for(s[:file], 32)
        tb.add_item(cmd)
      end
      console = UI::Command.new('Ruby Console') { Sketchup.send_action('showRubyPanel:') }
      console.tooltip         = 'Ruby Console'
      console.status_bar_text = 'Open the Ruby Console'
      console.small_icon = icon_for('console', 24)
      console.large_icon = icon_for('console', 32)
      tb.add_item(console)
      tb.show
    end

    # Pick an icon by what the script does, so the buttons are tellable apart.
    # Hovering still gives the full name; this just stops them all looking alike.
    def self.icon_for(path, size)
      name = File.basename(path.to_s).downcase
      tag = if    name == 'console'   then 'console'
            elsif name.include?('booth')  then 'booth'
            elsif name.include?('room')   then 'rooms'
            elsif name.include?('export') || name.include?('scene') then 'export'
            else 'generic'
            end
      png = File.join(File.dirname(__FILE__), "icon-#{tag}-#{size}.png")
      File.exist?(png) ? png : ''
    end

    unless file_loaded?(__FILE__)
      build_ui
      file_loaded(__FILE__)
    end
  end
end
