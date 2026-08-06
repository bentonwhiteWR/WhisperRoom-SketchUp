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
    SCRIPTS_DIR = 'C:/Users/bento/Documents/Claude/Sketchup/scripts'
    SKIP        = ['wr_tools.rb'].freeze

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
        cmd.small_icon = cmd.large_icon = icon_for(s[:file])
        tb.add_item(cmd)
      end
      console = UI::Command.new('Ruby Console') { Sketchup.send_action('showRubyPanel:') }
      console.tooltip = 'Ruby Console'
      console.small_icon = console.large_icon = icon_for(nil)
      tb.add_item(console)
      tb.show
    end

    # SketchUp wants an icon path; if none ships with the plugin it falls back to
    # a text button, which is fine and keeps this dependency-free.
    def self.icon_for(_path)
      png = File.join(File.dirname(__FILE__), 'icon.png')
      File.exist?(png) ? png : ''
    end

    unless file_loaded?(__FILE__)
      build_ui
      file_loaded(__FILE__)
    end
  end
end
