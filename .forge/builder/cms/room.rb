# Community Music School — the host classroom, camera-matched to the two
# client phone photos (no dimensions were supplied).
#
#   $wr_no_autorun = true
#   load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/cms/room.rb'
#   WR_CMS.run!            # rebuild the room from fit.json + features.json
#   WR_CMS.match!(:A)      # viewport = photo A's camera (or :B)
#
# EVERY DIMENSION HERE IS ESTIMATED FROM PHOTOS, NOT FIELD MEASURED. The
# numbers come from .forge/builder/cms/fit.json (a two-camera line fit, scale
# anchored on the 4-ft fluorescent run) and features.json (ray-cast feature
# positions). Nothing in this file is a measurement; see
# clients/community-music-school/notes.md for the estimate table.
#
# FRAME (inches): X = west->east, Y = south->north, Z up.
#   Wall 1 = north = the photos' Wall D  (booth backs onto it)   Y = L
#   Wall 2 = east  = Wall A, exterior, two steel windows         X = W
#   Wall 3 = south = Wall B, closet + whiteboard                 Y = 0
#   Wall 4 = west  = Wall C, entry door + transom, pipe riser    X = 0
#
# HOUSE CONVENTIONS kept so the house tools read the room (see
# .forge/builder/concept-art/scene-build.rb for where they were learned):
#   * a child 'Floor' on tag WR-Floor whose largest face is the floor polygon
#   * a child 'Walls' on tag WR-Room; wall pieces named "Wall <n> ..." so
#     wr-scene-walls / AUTO-SET hide a wall with everything on it
#   * the ceiling is a face at the Walls' top, INSIDE Walls ('Ceiling',
#     WR-Ceiling), so wr-drop-lights never treats it as an obstruction
# Walls are built OUTWARD from the interior faces; corners are mitred.
require 'json'

module WR_CMS
  DICT = 'wr_cms'.freeze
  # Resolved from this file so the laptop and desktop checkouts both work.
  DIR  = File.dirname(File.expand_path(__FILE__)).freeze
  T    = 4.0        # interior wall thickness (house default, cosmetic)

  def self.model; Sketchup.active_model; end
  def self.fit;   @fit ||= JSON.parse(File.read(File.join(DIR, 'fit.json'))); end
  def self.feat
    f = File.join(DIR, 'features.json')
    File.exist?(f) ? JSON.parse(File.read(f)) : {}
  end
  def self.reload!; @fit = nil; end

  # ------------------------------------------------------------ materials --
  def self.pbr(name, rgb, rough, metal = nil)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m.roughness_enabled = true
    m.roughness_factor = rough.to_f
    if metal
      m.metalness_enabled = true
      m.metallic_factor = metal.to_f
    else
      m.metalness_enabled = false
    end
    m
  end

  def self.materials!
    c = feat['colours'] || {}
    col = ->(k, d) { c[k] || d }
    @m = {
      carpet:  pbr('CMS Carpet',      col.call('carpet',  [92, 102, 126]), 0.95),
      upper:   pbr('CMS Wall Cream',  col.call('upper',   [226, 218, 194]), 0.85),
      lower:   pbr('CMS Wall Tan',    col.call('lower',   [206, 176, 136]), 0.85),
      stripe:  pbr('CMS Stripe Teal', col.call('stripe',  [44, 76, 74]), 0.6),
      ceiling: pbr('CMS Ceiling',     col.call('ceiling', [226, 222, 208]), 0.9),
      oak:     pbr('CMS Oak',         col.call('oak',     [166, 108, 56]), 0.45),
      reveal:  pbr('CMS Reveal White', col.call('reveal', [236, 232, 220]), 0.8)
    }
  end

  def self.layer(name); model.layers[name] || model.layers.add(name); end

  # A prism: 2D footprint (CCW or CW, any) extruded z0..z1, own group.
  def self.prism(ents, pts2, z0, z1, m = nil, name = nil)
    return nil if (z1 - z0).abs < 0.01
    g = ents.add_group
    f = g.entities.add_face(pts2.map { |x, y| [x, y, z0] })
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    g.material = m if m
    g.name = name if name
    g
  end

  def self.box(ents, x0, y0, z0, x1, y1, z1, m = nil, name = nil)
    x0, x1 = [x0, x1].minmax
    y0, y1 = [y0, y1].minmax
    return nil if (x1 - x0) < 0.01 || (y1 - y0) < 0.01
    prism(ents, [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], [z0, z1].min, [z0, z1].max, m, name)
  end

  # ----------------------------------------------------------------- room --
  def self.dims
    [fit['L'].to_f, fit['W'].to_f, fit['H'].to_f, fit['zc'].to_f]
  end

  # wall thickness per wall number (east wall is the thick exterior masonry)
  def self.thick(n)
    n == 2 ? (feat['east_thickness'] || 16.0).to_f : T
  end

  # Mitred footprint of wall n along its full length (interior face -> out).
  def self.footprint(n)
    l, w, = dims
    t1, t2, t3, t4 = thick(1), thick(2), thick(3), thick(4)
    case n
    when 1 then [[0, l], [w, l], [w + t2, l + t1], [-t4, l + t1]]
    when 2 then [[w, 0], [w, l], [w + t2, l + t1], [w + t2, -t3]]
    when 3 then [[0, 0], [w, 0], [w + t2, -t3], [-t4, -t3]]
    when 4 then [[0, 0], [0, l], [-t4, l + t1], [-t4, -t3]]
    end
  end

  def self.erase_mine
    doomed = model.entities.select { |e| e.get_attribute(DICT, 'role') }
    model.entities.erase_entities(doomed) unless doomed.empty?
    doomed.length
  end

  def self.build_shell!
    l, w, h, zc = dims
    m = @m
    root = model.entities.add_group
    root.name = 'CMS Classroom'
    root.set_attribute(DICT, 'role', 'room')
    e = root.entities

    fl = e.add_group
    fl.name = 'Floor'
    fl.layer = layer('WR-Floor')
    ff = fl.entities.add_face([0, 0, 0], [w, 0, 0], [w, l, 0], [0, l, 0])
    ff.reverse! if ff.normal.z < 0
    fl.material = m[:carpet]

    wg = e.add_group
    wg.name = 'Walls'
    wg.layer = layer('WR-Room')
    we = wg.entities
    stripe = (feat['stripe_h'] || 1.25).to_f
    (1..4).each do |n|
      fp = footprint(n)
      prism(we, fp, 0, zc - stripe / 2, m[:lower], "Wall #{n} lower")
      prism(we, fp, zc - stripe / 2, zc + stripe / 2, m[:stripe], "Wall #{n} stripe")
      prism(we, fp, zc + stripe / 2, h, m[:upper], "Wall #{n} upper")
    end

    cg = we.add_group
    cg.name = 'Ceiling'
    cg.layer = layer('WR-Ceiling')
    t1, t2, t3, t4 = thick(1), thick(2), thick(3), thick(4)
    cf = cg.entities.add_face([-t4, -t3, h], [w + t2, -t3, h], [w + t2, l + t1, h], [-t4, l + t1, h])
    cf.reverse! if cf.normal.z > 0
    cf.material = m[:ceiling]
    cf.back_material = m[:ceiling]
    root
  end

  # ------------------------------------------------------------- cameras --
  # The photo's own camera: position, aim and FOV from the fit, aspect locked
  # to the photo so a write_image at the photo's aspect lines up pixel-true.
  def self.camera_for(key)
    c = fit["cam#{key}"]
    cam = Sketchup::Camera.new(Geom::Point3d.new(*c['eye']), Geom::Point3d.new(*c['target']),
                               Geom::Vector3d.new(*c['up']), true, c['fov_v'].to_f)
    cam.aspect_ratio = c['img'][0].to_f / c['img'][1].to_f
    # SketchUp measures the FOV across the NARROWER side once an aspect is
    # locked: fov_is_height? came back false for the portrait photo A camera
    # (observed 22 Sep 2026), so the vertical figure was applied to the width
    # and the view read 0.75x too wide. Give it the matching figure.
    cam.fov = c['fov_h'].to_f if cam.respond_to?(:fov_is_height?) && !cam.fov_is_height?
    cam
  end

  def self.match!(key = :A)
    model.active_view.camera = camera_for(key)
    model.active_view.refresh rescue nil
    "viewport on photo #{key} match"
  end

  def self.scenes!
    %w[A B].each do |k|
      name = "Photo match #{k}"
      pg = model.pages[name] || model.pages.add(name)
      model.pages.selected_page = pg
      model.active_view.camera = camera_for(k)
      pg.update(1) # camera only
      pg.set_attribute(DICT, 'role', 'photo-match')
    end
  end

  def self.run!
    reload!
    out = []
    model.start_operation('CMS: host classroom', true)
    begin
      materials!
      out << "erased #{erase_mine} old CMS groups"
      build_shell!
      model.commit_operation
    rescue Exception
      model.abort_operation
      raise
    end
    out << match!(:A)
    out
  end
end

WR_CMS.run!.each { |l| puts l } unless $wr_no_autorun
