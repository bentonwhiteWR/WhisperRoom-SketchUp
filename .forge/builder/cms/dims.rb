# Community Music School -- host-room dimensions (ALL ESTIMATED FROM PHOTOS) and the two
# photo-match scenes.  Needs room.rb loaded first (WR_CMS.dims / camera_for).
#
#   WR_CMS.room_dims!     erase + redraw every room dimension, corner/wall label and the plan note
#   WR_CMS.photo_scenes!  create/refresh "Photo A - long view" / "Photo B - corner view" (camera only)
#   WR_CMS.check!         what a save must still contain (dims, labels, note, both scenes)
#
# Rows follow scripts/dimension-room-now.rb: chain 36 in outside the exterior face, the
# openings row 13 in beyond it, the overall 28 in beyond it. Every string is overridden to the
# value rounded to the inch + " EST." (1/16 in precision would imply a survey; tolerance is +-1 ft).
#
# Tag: "CMS Room Dims (EST)" -- deliberately NOT a WR-Dims* name: the desktop's installed plugin
# (1.67.7) predates auto-dimension.rb's exact-membership fix, and a prefix test there erases every
# WR-Dims* tag's dimensions when the "Dimension the room" ability is toggled. Stamp: wr_cms_dims.
module WR_CMS
  DDICT = 'wr_cms_dims'.freeze
  DTAG  = 'CMS Room Dims (EST)'.freeze
  # Benton, 22 Sep: the top-down view carries this, verbatim.
  NOTE  = "HOST ROOM DIMENSIONS NOT PROVIDED. ALL ROOM DIMENSIONS ARE ESTIMATED FROM CLIENT PHOTOS (±1 FT) AND MUST BE CONFIRMED ON SITE.".freeze
  # the same words, broken into lines so the note stays inside the free floor south of the booth
  NOTE_LINES = ["HOST ROOM DIMENSIONS NOT PROVIDED.", "ALL ROOM DIMENSIONS ARE ESTIMATED", "FROM CLIENT PHOTOS (±1 FT) AND MUST",
                "BE CONFIRMED ON SITE."].freeze
  SCENES = { 'A' => 'Photo A - long view', 'B' => 'Photo B - corner view' }.freeze

  def self.ftin(v)
    t = v.round
    "#{t / 12}'-#{t % 12}\""
  end

  def self.dim_erase!
    ents = model.entities
    doomed = ents.select { |e| e.valid? && e.get_attribute(DDICT, 'own', false) }
    ents.erase_entities(doomed) unless doomed.empty?
    doomed.length
  end

  def self.stamp(e, kind)
    e.set_attribute(DDICT, 'own', true)
    e.set_attribute(DDICT, 'kind', kind)
    e.layer = @dtag
    e
  end

  # a linear dimension between two plan points at floor level, offset by vec
  def self.dline(a, b, vec, kind, inches = nil)
    ents = model.entities
    pa = Geom::Point3d.new(*a)
    pb = Geom::Point3d.new(*b)
    ca = stamp(ents.add_cpoint(pa), 'anchor')
    cb = stamp(ents.add_cpoint(pb), 'anchor')
    d = ents.add_dimension_linear([ca, pa], [cb, pb], Geom::Vector3d.new(*vec))
    d.text = "#{ftin(inches || pa.distance(pb).to_f)} EST."
    d.set_attribute(DDICT, 'inches', pa.distance(pb).to_f.round(1))
    # a short segment's text cannot fit between its own extension lines: put it past the end
    if pa.distance(pb).to_f < 16.0 && d.respond_to?(:text_position=)
      d.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END
    end
    stamp(d, kind)
  end

  def self.label(txt, pt, kind = 'label')
    t = model.entities.add_text(txt, Geom::Point3d.new(*pt))
    t.display_leader = false rescue nil
    stamp(t, kind)
  end

  # chain along a wall. pts = the u stations in order (corner ... corner); face(u) -> [x,y,0]
  # Rounded to the inch by largest remainder, so a chain's printed segments always sum to its
  # printed total (independent rounding put Wall C's chain 1 in over its overall).
  def self.chain(stations, face, vec, kind)
    segs = stations.each_cons(2).map { |a, b| (b - a).abs }
    fl = segs.map(&:floor)
    short = (segs.sum.round - fl.sum)
    order = segs.each_index.sort_by { |i| -(segs[i] - fl[i]) }
    order.first(short).each { |i| fl[i] += 1 }
    stations.each_cons(2).each_with_index.map { |(a, b), i| dline(face.call(a), face.call(b), vec, kind, fl[i]) }
  end

  def self.room_dims!
    l, w, h, = dims
    @dtag = model.layers[DTAG] || model.layers.add(DTAG)
    out = []
    model.start_operation('CMS: room dimensions (EST.)', true)
    begin
      out << "erased #{dim_erase!}"
      off = ->(n) { thick(n) + 36.0 }
      # Wall A carries three rows (jog chain, windows, overall): 30 in apart so the texts clear.
      e = [off.call(2), off.call(2) + 30.0, off.call(2) + 60.0]
      # Wall C's rows start beyond the corridor modelled behind the entry door (it reaches X -111).
      cc = 111.0 + 30.0
      wv = [cc, cc + 13.0, cc + 28.0]
      s = [off.call(3), off.call(3) + 13.0, off.call(3) + 28.0]
      nn = [off.call(1), off.call(1) + 13.0, off.call(1) + 28.0]
      fa = ->(y) { [w, y, 0.0] }   # Wall A face, stations = Y from corner A/B
      fb = ->(x) { [x, 0.0, 0.0] } # Wall B face, stations = X from corner B/C
      fc = ->(y) { [0.0, y, 0.0] } # Wall C face, stations = Y from corner B/C
      fd = ->(x) { [x, l, 0.0] }   # Wall D face
      # WALL A (east): chain of every jog at the floor -- window niches (4 in deep) and the pilaster
      # (7 in proud) -- then the windows off their corners, then the overall.
      w2, w1 = WIN[1], WIN[0]
      chain([0.0, w2[:y0], w2[:y1], PIL[:y0], PIL[:y1], w1[:y0], w1[:y1], l], fa, [e[0], 0, 0], 'chain A')
      chain([0.0, w2[:y0], w2[:y1]], fa, [e[1], 0, 0], 'openings A (off corner A/B)')
      chain([w1[:y0], w1[:y1], l], fa, [e[1], 0, 0], 'openings A (off corner A/D)')
      dline(fa.call(0.0), fa.call(l), [e[2], 0, 0], 'overall A')
      # pilaster projection + niche depth, dimensioned in plan at the pilaster
      dline([w, PIL[:y0] + 3.0, 0.0], [w - PIL[:d], PIL[:y0] + 3.0, 0.0], [0, -14.0, 0], 'pilaster depth') # end = room side, so its text lands in the room
      # WALL B (south): closet opening off corner B/C, closing on corner A/B; overall
      chain([0.0, CLOSET[:x0], CLOSET[:x1], w], fb, [0, -s[0], 0], 'chain B + closet (off corner B/C)')
      dline(fb.call(0.0), fb.call(w), [0, -s[2], 0], 'overall B')
      # WALL C (west): entry door off corner B/C, closing on corner C/D; overall
      chain([0.0, ENTRY[:y0], ENTRY[:y1], l], fc, [-wv[0], 0, 0], 'chain C + entry door (off corner B/C)')
      dline(fc.call(0.0), fc.call(l), [-wv[2], 0, 0], 'overall C')
      # WALL D (north, the booth wall): straight -- one run is its chain and overall
      dline(fd.call(0.0), fd.call(w), [0, nn[0], 0], 'overall D')
      # ceiling height (vertical, at corner C/D)
      dline([0.0, l, 0.0], [0.0, l, h], [-30.0, 30.0, 0], 'ceiling height')
      # labels + the plan note
      # Corner name labels REMOVED (Benton, 22 Sep). The chains still dimension doors and windows
      # off the room's corners; only the CORNER x/y text is gone.
      # Wall labels sit on FREE floor or outside the wall: the booth (X 18-164, Y 155-254) covers the
      # room's north half, and a label under it cannot be read in the top-down scene.
      label("WALL A (exterior, 2 windows)", [w - 76, 104, 0])
      label("WALL B (closet, whiteboard)", [w / 2 - 30, 14, 0])
      label("WALL C (entry door)", [8, 58, 0])
      label("WALL D (booth wall)", [w / 2 - 25, l + thick(1) + 12, 0])
      # the plan note: free floor between Wall B's whiteboard and the booth's door swing
      label("#{NOTE_LINES.join("\n")}\nCeiling height #{ftin(h)} EST. (±6 in).",
            [22, 92, 0], 'plan note')
      model.commit_operation
    rescue Exception
      model.abort_operation
      raise
    end
    out + [check!]
  end

  def self.photo_scenes!
    ps = model.pages
    before = ps.selected_page
    SCENES.each do |k, name|
      pg = ps[name] || ps.add(name)
      ps.selected_page = pg
      model.active_view.camera = camera_for(k)
      # camera only: never lock tags, style, shadows, axes, hidden geometry or section planes
      %i[use_axes= use_hidden_layers= use_hidden_geometry= use_hidden_objects= use_rendering_options=
         use_section_planes= use_shadow_info= use_style=].each { |m| pg.send(m, false) if pg.respond_to?(m) }
      pg.use_camera = true
      pg.update(1)
      pg.set_attribute(DICT, 'role', 'photo-match')
      pg.set_attribute(DICT, 'photo', k)
    end
    ps.selected_page = before if before
    check!
  end

  def self.check!
    ents = model.entities
    mine = ents.select { |e| e.valid? && e.get_attribute(DDICT, 'own', false) }
    dimsn = mine.grep(Sketchup::Dimension)
    bad = dimsn.reject { |d| d.text.to_s.end_with?('EST.') }
    note = mine.grep(Sketchup::Text).any? { |t| t.text.gsub("\n", ' ').include?(NOTE) }
    sc = SCENES.map do |k, name|
      pg = model.pages[name]
      next [name, false] unless pg
      c = pg.camera
      ref = camera_for(k)
      [name, true, pg.use_camera?, (pg.use_hidden_layers? rescue nil), (pg.use_style? rescue nil),
       c.fov.round(2) == ref.fov.round(2), c.aspect_ratio.round(4) == ref.aspect_ratio.round(4),
       c.eye.distance(ref.eye).to_f < 0.01]
    end
    { 'dims' => dimsn.length, 'dims_not_EST' => bad.length, 'labels' => mine.grep(Sketchup::Text).length,
      'plan_note' => note, 'scenes' => sc }
  end
end
