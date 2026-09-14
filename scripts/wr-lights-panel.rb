# @title Adjust interior lights...
# @cat V-Ray renders
# @rank 4
# @icon lights
#
# THE MAIN LIGHTS WINDOW (1.70.0). Every room's dropped rig, one card each:
# a whole-rig brightness slider (10-300%, log scale, 100% = what the drop
# wrote), each light type on its own slider with an on/off switch and a
# Kelvin box, the booth's own interior light, Check & repair against V-Ray,
# Remove this rig, and a "Drop in lights" button for the current selection.
#
# Nothing needs to be selected to open it. It is modeless: leave it open
# while you work.
#
# The engine lives in wr-drop-lights.rb (WR_DropLights.show_rigs); this file
# only loads that module WITHOUT its autorun and opens the window.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-lights-panel.rb"

module WR_LightsPanel
  def self.drop_file
    File.join(File.dirname(__FILE__), 'wr-drop-lights.rb')
  end

  # Loaded fresh each press so an edited wr-drop-lights.rb is picked up, with
  # BOTH autorun flags up (main.rb's load_quietly note: the scripts disagree
  # about the name) and restored after, so the next script run from the panel
  # still autoruns.
  def self.open
    was_no, was_sup = $wr_no_autorun, $wr_suppress_autorun
    $wr_no_autorun = true
    $wr_suppress_autorun = true
    begin
      load drop_file
    ensure
      $wr_no_autorun = was_no
      $wr_suppress_autorun = was_sup
    end
    WR_DropLights.show_rigs(Sketchup.active_model)
  end
end

unless $wr_suppress_autorun || $wr_no_autorun
  begin
    WR_LightsPanel.open
  rescue Exception => e
    puts "Adjust interior lights FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n") if e.backtrace
    UI.messagebox("Adjust interior lights failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
  end
end
