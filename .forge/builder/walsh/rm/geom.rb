# Walsh v3 (21 Oct, Sarah's final plan): MDL 96168 S, roof mount, no platform/ramp, no new walls.
# Reuses the corner frame from ../corner/geom.rb (pure math). Only the save guard differs.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/corner/geom.rb'
module WalshRM
  WC = WalshCorner
  RM_SKP = 'Z:/Sketchup/ClientDrawings/Walsh Construction Tech Lab MDL 96168 S - Corner RM.skp'
  def self.save(m)
    pth = m.path.to_s.gsub(92.chr, '/')
    raise "refusing to save: open model is #{pth}" unless pth.casecmp?(RM_SKP)
    m.save(RM_SKP)
  end
  # v3 room: the full Tech Lab outline, no zigzag. A -> C (exterior) -> G (corner wall, existing) ->
  # SW [0, Y_S] (south wall) -> WTOP (west wall) -> A (NW angled wall). Take-off frame.
  def self.room
    g = WC.p(0, WC.d_on_y(0, WC::Y_S))
    [WC::A, WC::C, g, [0.0, WC::Y_S], WC::WTOP]
  end
  # (s, d) of a take-off point
  def self.sd(x, y)
    dx = x - WC::C[0]
    dy = y - WC::C[1]
    [dx * WC::SH[0] + dy * WC::SH[1], dx * WC::NH[0] + dy * WC::NH[1]]
  end
end
