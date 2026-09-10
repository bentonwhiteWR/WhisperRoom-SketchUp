# @title Rotate booth dimensions
# @cat Add dimensions
# @rank 2
# @icon dim-booth
#
# Click a WhisperRoom: its dimension set moves to the next corner of the
# booth, rebuilt from the model — FR -> FL -> RL -> RR -> FR. The first press
# always puts the set on the other side, for a camera on that side.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/rotate-whisperroom-dimensions.rb"
#
# Benton, 10 Sep 2026: "could there be a button to 'rotate' to other side?
# These are shown on the right side. Sometimes they will need to be on left
# side depending on where we need to get the image of."
#
# A SECOND BUTTON, NOT A MODIFIER. It is what he asked for, it keeps
# Dimension a WhisperRoom meaning one thing (draw where the set is, so a
# re-run after moving a booth never also rotates it), and a key held while a
# tool is live would be invisible to Gabe and undiscoverable from the panel.
#
# IT REBUILDS, IT NEVER TRANSFORMS. The stored corner on the booth group is
# advanced, then the same path a fresh run uses: erase this booth's set,
# re-measure the parts, re-anchor, draw. No entity is moved or mirrored, so
# the set cannot drift off the geometry, and a booth moved between presses
# is measured where it now stands. If the new side is inside a wall the set
# is drawn anyway and the console says so — the operator asked for control;
# a tool that skipped to the corner it liked would be the settings dialog by
# another name.
#
# The module lives in dimension-whisperroom.rb; this file is the panel's
# button for one of its entry points.

wr_rot_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'dimension-whisperroom.rb')
ensure
  $wr_no_autorun = wr_rot_autorun_was
end

begin
  WR_BoothDims.run(:rotate) unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Rotate booth dimensions failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
