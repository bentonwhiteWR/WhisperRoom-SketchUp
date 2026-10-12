# Walsh Construction / PHAME - Tech Lab (room 13), built from the vector take-off
# in clients/walsh-construction/takeoff-vector.json.
#
# WHY NOT build-takeoff.rb: the take-off format is rectilinear (E/S/W/N runs) and
# this room has three angled walls. This script feeds the measured polygon
# straight into WR_BuildRoom's own polygon-generic pieces (mitre, wall_run, door,
# quad) and the shared dimension engine (WR_AutoDimension.dimension_face, with
# the door jambs handed over the same way build-takeoff.rb 1.84.0 does), so the
# walls, door and dimensions are the house standard - only the polygon source
# differs.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/clients/walsh-construction/build-techlab.rb"
#
# NOT MEASURED: ceiling 96" (8'-0" house default, ASSUMED, unconfirmed);
# wall thickness 4" (house default, cosmetic). Everything else is plan-vector
# at 1/8" = 1'-0", +/-0.6 in from line weight.

module WR_WalshTechLab
  ROOM = 'Tech Lab 13'.freeze
  CEIL = 96.0      # ASSUMED: 8'-0" house default. Benton 12 Oct: "assume 8' ceiling but we don't know"
  THICK = 4.0      # house default, cosmetic
  SLAB = 4.0
  # clockwise from the NW-most corner (the apex), inches, origin = interior SW corner
  PTS = [
    [104.409, 332.713],   # 0 apex: NW angled wall x exterior wall
    [292.958, 178.397],   # 1 east angled wall x exterior wall
    [243.520, 118.080],   # 2 east angled x east vertical
    [243.520,   0.000],   # 3 SE
    [  0.000,   0.000],   # 4 SW
    [  0.000, 205.120]    # 5 west x NW angled
  ].freeze
  # door 24: on run 3 (south, heading W from SE), near jamb 203.52 from SE = 4.0 from SW
  DOORS = [{ 'run' => 3, 'at' => 203.52, 'w' => 36.0, 'h' => 80.0, 'hinge' => 'far', 'tag' => '24' }].freeze

  def self.build
    $wr_suppress_autorun = true
    load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-room.rb'
    load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/auto-dimension.rb'
    $wr_suppress_autorun = false
    br = WR_BuildRoom
    m = Sketchup.active_model
    m.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    t_floor = br.tag(m, 'WR-Floor', [230, 230, 230])
    t_wall  = br.tag(m, 'WR-Room', [120, 128, 140])
    t_door  = br.tag(m, 'WR-Doors', [238, 98, 22])
    t_leaf  = br.tag(m, 'WR-Doors-Leaf', [200, 130, 60])
    t_note  = br.tag(m, 'WR-Notes', [90, 90, 96])
    t_ceil  = br.tag(m, 'WR-Ceiling', [200, 205, 212])
    m.start_operation('Walsh: Tech Lab', true)
    begin
      pts = PTS.map { |x, y| br.pt(x, y) }
      ccw = br.signed_area(pts) > 0
      outer = br.mitre(pts, ccw, THICK)
      g = m.entities.add_group
      g.name = ROOM
      g.set_attribute('wr_takeoff', 'room', ROOM)
      fg = g.entities.add_group
      floor = fg.entities.add_face(pts)
      floor.reverse! if floor.normal.z < 0
      fg.name = 'Floor'
      fg.layer = t_floor
      fg.material = br.material(m, br::MAT_FLOOR)
      wg = g.entities.add_group
      wg.name = 'Walls'
      wg.layer = t_wall
      walls = 0
      pts.size.times do |i|
        rd = DOORS.select { |d| d['run'] == i }
        walls += br.wall_run(wg, pts, outer, i, ccw, THICK, CEIL, rd, 80.0)
      end
      wg.material = br.material(m, br::MAT_WALL)
      dg = g.entities.add_group
      dg.name = 'Doors'
      mat = br.material(m, br::MAT_DOOR)
      DOORS.each do |d|
        br.door(dg, pts, d['run'], ccw, THICK, d['at'], d['w'], d['h'], d['hinge'], t_door, t_leaf, mat)
      end
      cg = g.entities.add_group
      br.quad(cg.entities, pts, CEIL, CEIL + SLAB)
      cg.name = 'Ceiling'
      cg.layer = t_ceil
      # notes: the assumed ceiling, in the model at the room
      t = m.entities.add_text("CEILING 8'-0\" ASSUMED (house default) - NOT CONFIRMED. " \
                              'Benton 12 Oct 2026: "assume 8\' ceiling but we don\'t know". Confirm before quoting.',
                              Geom::Point3d.new(20, 150, CEIL))
      t.layer = t_note
      t2 = m.entities.add_text('Tech Lab 13 walls: plan-vector take-off, A1.1 at 1/8"=1\'-0", +/-0.6 in. ' \
                               'Door 24 3\'-0" x 6\'-8" per plan note. Door 1 is in Storage 17 (not built).',
                               Geom::Point3d.new(20, 120, 0))
      t2.layer = t_note
      boxes = DOORS.map do |d|
        a = pts[d['run']]
        b = pts[(d['run'] + 1) % pts.size]
        u = (b - a).normalize
        bb = Geom::BoundingBox.new
        bb.add(a.offset(u, d['at']))
        bb.add(a.offset(u, d['at'] + d['w']))
        bb
      end
      dims = WR_AutoDimension.dimension_face(floor, :doors => boxes)
      m.commit_operation
      WR_AutoDimension.report(dims)
      { 'walls' => walls, 'dims' => dims.reject { |k, _| k == :created } }
    rescue Exception => e
      m.abort_operation
      puts "FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      raise
    end
  end
end
WR_WalshTechLab.build unless $wr_no_autorun
