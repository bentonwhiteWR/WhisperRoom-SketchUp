# @title Set up the five proposal plates...
# @cat Scenes and images
# @rank 1
# @ability Proposal scenes
# @ability-blurb Create the five proposal plates; switch off to remove them.
# @on  WR_ProposalScenes.ability_on(opts)
# @off WR_ProposalScenes.ability_off(opts)
#
# Create the five proposal plates as scenes, in order, each carrying its own
# camera, tag visibility and style. Then export-scenes.rb turns them into
# correctly-named PNGs and the filenames drop straight into proposal-v2.json.
#
#   01-exterior     the booth in the finished room. Lead with this, always.
#   02-dimensioned  same three-quarter view with the ROOM dimensions switched ON
#                   (WR-Dims + WR-Dims-Doors). The booth and selection dimension
#                   tags are hidden on all five plates — see SHOWN_ON_DIMENSIONED.
#   03-side         side elevation, parallel projection
#   04-ventilation  rear three-quarter, aimed at the vented wall
#   05-plan         top-down with the door swing visible. Always close with this.
#
# THE DOOR SIDE IS READ, NOT GUESSED. build-booth.rb tags door frames
# WR-Booth-Door and vents WR-Booth-Vent, so the exterior view is aimed at the
# real door and the ventilation view at the real vent. With no booth tagged,
# it falls back to the model's front and says so.
#
# THE EXACT ANGLE IS BENTON'S CALL. This places sensible defaults and names the
# scenes correctly. Nudge any view and re-save that scene — the value here is
# the ordering and the per-scene tag state, not the framing.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-scenes.rb"

module WR_ProposalScenes
  DEG = Math::PI / 180.0

  PLATES = [
    { :name => '01-exterior',    :kind => :three_quarter, :az => 0.0,   :el => 12.0, :persp => true  },
    { :name => '02-dimensioned', :kind => :three_quarter, :az => 0.0,   :el => 20.0, :persp => false },
    { :name => '03-side',        :kind => :elevation,     :az => 90.0,  :el => 0.0,  :persp => false },
    { :name => '04-ventilation', :kind => :vent,          :az => 180.0, :el => 14.0, :persp => false },
    { :name => '05-plan',        :kind => :plan,          :az => 0.0,   :el => 89.0, :persp => false }
  ].freeze

  # Every WhisperRoom dimension tag, because a plate must not inherit whatever
  # visibility a tag happened to have when the scenes were made. This list was
  # two tags long and predated dimension-booth.rb (WR-Dims-Booth) and
  # dimension-selection.rb (WR-Dims-Selection), so those two froze at whatever
  # state they were in — booth catalogue numbers could land on the clean
  # exterior plate, or vanish from the dimensioned one. These are customer
  # plates; nothing on them gets to be accidental.
  DIM_TAGS = %w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Dims-Selection].freeze

  # What 02-dimensioned actually shows: the ROOM dimensions and its doors. The
  # other four plates show none of them.
  #
  # WR-Dims-Booth and WR-Dims-Selection are deliberately hidden on all five.
  # They are working dimensions, not proposal ones — Dimension Selection draws a
  # bounding box, and a booth carrying both sets shows two different footprints
  # with nothing on the page to say which is which. Deliberately off is the
  # conservative call, not a claim they never belong: if Benton wants booth
  # dimensions on plate 02, switch WR-Dims-Booth on and re-save that scene.
  SHOWN_ON_DIMENSIONED = %w[WR-Dims WR-Dims-Doors].freeze

  # ------------------------------------------------------------------ finding --

  def self.tagged(model, name)
    out = []
    walk(model.entities, name, out, 0)
    out
  end

  def self.walk(ents, name, out, depth)
    return if depth > 4
    ents.each do |e|
      out << e if e.respond_to?(:layer) && e.layer && e.layer.name == name
      case e
      when Sketchup::Group then walk(e.entities, name, out, depth + 1)
      when Sketchup::ComponentInstance then walk(e.definition.entities, name, out, depth + 1)
      end
    end
  end

  # Which way does the booth face? Work it out from where the door sits
  # relative to the booth's centre, rather than assuming a front.
  def self.heading_to(model, tag_name, centre)
    hits = tagged(model, tag_name)
    return nil if hits.empty?
    bb = Geom::BoundingBox.new
    hits.each { |e| bb.add(e.bounds) }
    v = bb.center - centre
    return nil if v.length < 1.0
    Math.atan2(v.y, v.x) / DEG
  end

  def self.subject_bounds(model)
    sel = model.selection
    bb = Geom::BoundingBox.new
    if sel.empty?
      bb.add(model.bounds)
    else
      sel.each { |e| bb.add(e.bounds) }
    end
    bb
  end

  # -------------------------------------------------------------------- tags --

  # `on` means "this is the dimensioned plate". Every tag in DIM_TAGS is set
  # either way, so none of the four is ever left to whatever it was.
  def self.set_dims(model, on)
    DIM_TAGS.each do |n|
      l = model.layers[n]
      (l.visible = (on && SHOWN_ON_DIMENSIONED.include?(n))) if l
    end
  end

  # ------------------------------------------------------------------ camera --

  def self.aim(view, centre, radius, az_deg, el_deg, persp)
    a = az_deg * DEG
    e = el_deg * DEG
    dir = Geom::Vector3d.new(Math.cos(e) * Math.cos(a),
                             Math.cos(e) * Math.sin(a),
                             Math.sin(e))
    dist = radius * 3.2 + 60.0
    eye = centre.offset(dir, dist)
    up  = (el_deg.abs >= 88.0) ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, 0, 1)
    cam = view.camera
    cam.set(eye, centre, up)
    if persp
      cam.perspective = true
      cam.fov = 40.0
    else
      cam.perspective = false
      cam.height = radius * 2.3
    end
    cam
  end

  # ------------------------------------------------------------------- build --

  # --- panel ability -------------------------------------------------------
  # The five plates are named and owned by this script, so switching off can
  # remove exactly those and leave any scene you made by hand alone.

  def self.scene_names
    PLATES.map { |p| p[:name] }
  end

  def self.ability_off(_opts = {})
    pages = Sketchup.active_model.pages
    n = 0
    scene_names.each do |nm|
      p = pages[nm]
      next unless p
      pages.erase(p)
      n += 1
    end
    puts ''
    puts "PROPOSAL SCENES — removed #{n} of #{PLATES.size} plate scene(s)"
    puts ''
    true
  rescue StandardError => e
    UI.messagebox("Removing proposal scenes failed:\n\n#{e.class}: #{e.message}")
    false
  end

  def self.ability_on(_opts = {})
    run(true)
  end

  # silent: skip the replace-these-scenes prompt. The ability path always
  # replaces, because a toggle cannot stop to ask a question.
  def self.run(silent = false)
    model = Sketchup.active_model
    view  = model.active_view
    pages = model.pages

    bb = subject_bounds(model)
    if bb.width.to_f < 1.0
      UI.messagebox("Nothing to frame.\n\nSelect the booth (or leave nothing selected " \
                    "to use the whole model) and try again.")
      return
    end
    centre = bb.center
    radius = bb.diagonal.to_f / 2.0

    clash = scene_names.select { |n| pages[n] }
    unless clash.empty?
      unless silent
        ans = UI.messagebox("These scenes already exist:\n  #{clash.join("\n  ")}\n\n" \
                            "Replace them?", MB_YESNOCANCEL)
        return unless ans == IDYES
      end
      clash.each { |n| pages.erase(pages[n]) if pages[n] }
    end

    # Read the real door and vent sides off the tags build-booth.rb writes.
    door_az = heading_to(model, 'WR-Booth-Door', centre)
    vent_az = heading_to(model, 'WR-Booth-Vent', centre)
    base_az = door_az || -90.0        # fallback: look from the model's -Y side

    prev_page = pages.selected_page
    prev_cam  = view.camera.clone rescue nil
    prev_dims = DIM_TAGS.map { |n| l = model.layers[n]; [n, l ? l.visible? : nil] }

    made = []
    begin
      PLATES.each do |p|
        set_dims(model, p[:name] == '02-dimensioned')

        az = case p[:kind]
             when :vent then (vent_az || (base_az + 180.0)) + 25.0
             when :plan then base_az
             else base_az + p[:az] + (p[:kind] == :three_quarter ? 35.0 : 0.0)
             end
        aim(view, centre, radius, az, p[:el], p[:persp])
        view.refresh

        page = pages.add(p[:name])
        page.use_camera             = true
        page.use_hidden_layers      = true
        page.use_rendering_options  = true
        page.use_shadow_info        = true
        page.use_axes               = false
        page.use_section_planes     = true
        page.transition_time        = 0
        made << p[:name]
      end
    ensure
      prev_dims.each { |n, v| l = model.layers[n]; (l.visible = v) if l && !v.nil? }
      view.camera = prev_cam if prev_cam
      pages.selected_page = prev_page if prev_page && prev_page.valid?
    end

    report(made, door_az, vent_az, bb)
  rescue StandardError => e
    UI.messagebox("Proposal scenes failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.report(made, door_az, vent_az, bb)
    puts ''
    puts 'PROPOSAL SCENES'
    puts ''
    made.each { |n| puts "  created  #{n}" }
    puts ''
    if door_az
      puts format('  Door side read from WR-Booth-Door at %.0f deg — the exterior and', door_az)
      puts '  plan views are aimed at the real door.'
    else
      puts '  NO WR-Booth-Door tag found, so the door side is ASSUMED to be -Y.'
      puts '  If the exterior view is looking at the back of the booth, that is why.'
    end
    if vent_az
      puts format('  Vent side read from WR-Booth-Vent at %.0f deg.', vent_az)
    else
      puts '  No WR-Booth-Vent tag — plate 04 is just the opposite side.'
    end
    puts ''
    puts '  Each scene stores its own camera, TAG VISIBILITY and style, so'
    puts "  02-dimensioned shows #{SHOWN_ON_DIMENSIONED.join(' + ')} and the other four hide them."
    puts '  WR-Dims-Booth and WR-Dims-Selection are hidden on ALL FIVE — working'
    puts '  dimensions, not proposal ones. Want booth dimensions on plate 02?'
    puts '  Switch WR-Dims-Booth on and re-save that scene.'
    puts ''
    puts '  THE ANGLES ARE DEFAULTS, NOT DECISIONS. Nudge any view you do not'
    puts '  like and re-save that scene — the ordering and the tag state are the'
    puts '  part worth automating; the framing is a taste call.'
    puts ''
    puts '  Next: run Export Scenes. The filenames come out in plate order and'
    puts '  drop straight into examples/<client>/proposal-v2.json.'
    puts ''
  end
end

WR_ProposalScenes.run unless $wr_no_autorun
