# @title Clear WhisperRoom dimensions
# @cat Add dimensions
# @rank 3
# @icon dim-booth
#
# Click a WhisperRoom: its dimension set is removed. Press Esc with nothing
# picked to remove every booth's set in the model (it asks first).
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/clear-whisperroom-dimensions.rb"
#
# ONLY WHAT THE TOOL DREW. Per booth it erases the entities carrying that
# booth's id; Esc erases everything carrying WR_BoothDims/own, plus the
# leftovers of the retired dimension-booth.rb (WR_DimBooth/own) so that
# archive can be deleted next release. A hand-drawn dimension someone put on
# WR-Dims-Booth is never touched — the tag alone is not ownership.
#
# The module lives in dimension-whisperroom.rb; this file is the panel's
# button for one of its entry points.

wr_clr_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'dimension-whisperroom.rb')
ensure
  $wr_no_autorun = wr_clr_autorun_was
end

begin
  WR_BoothDims.run(:clear) unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Clear WhisperRoom dimensions failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
