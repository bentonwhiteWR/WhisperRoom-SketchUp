# wr_tools.rb — WhisperRoom menu + toolbar for SketchUp.
#
# INSTALL ONCE:
#   Copy this file AND the wr_tools folder into
#     %APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\
#   Restart SketchUp. You get a "WhisperRoom" menu and a toolbar.
#
# After that you never open the Ruby Console again. Every .rb in the repo's
# scripts/ folder except this loader shows up as a menu item automatically, so
# any new script appears without reinstalling anything — just hit Reload
# Scripts. wr_tools/main.rb locates that folder itself (see CANDIDATES there).

require 'sketchup.rb'
require 'extensions.rb'

module WhisperRoom
  module Tools
    PLUGIN_DIR = File.join(File.dirname(__FILE__), 'wr_tools')

    unless file_loaded?(__FILE__)
      ext = SketchupExtension.new('WhisperRoom Tools', File.join(PLUGIN_DIR, 'main.rb'))
      ext.description = 'Room builds, booth assembly and scene export, on a menu and toolbar.'
      ext.version     = '1.0.0'
      ext.creator     = 'WhisperRoom'
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
