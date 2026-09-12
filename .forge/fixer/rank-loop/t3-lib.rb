# t3 cycle lib. IDENTICAL to .forge/fixer/rank-loop/d-lib.rb except that
# DCYC.room / DCYC.booth are hard-coded to the group NAMED "Room" there, and
# this model's room group is named "CSUSB Chaparral 106". That hard-coding is
# INTERVENTION 5 in the run log: the shipped drop tool takes its subjects from
# the viewport SELECTION, and an unattended caller has no selection, so every
# headless caller has to name the subjects itself.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'

module DCYC
  ROOM_NAME = 'CSUSB Chaparral 106'.freeze
  def self.room
    model.entities.grep(Sketchup::Group).find { |g| g.name == ROOM_NAME }
  end
end
