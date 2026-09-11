# @title Set up the five proposal plates (legacy - fixed five, no booth)...
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

  # THIS TABLE IS THE LEGACY FIVE AND IT IS DELIBERATELY NOT BENTON'S NEW SHOT
  # LIST. On 10 Sep 2026 he said he never uses parallel projection, and
  # wr-autoset.rb's plates were rebuilt around that (all perspective, front-on
  # first, a 15-20 ft high shot, a true top-down). These five were left alone
  # ON PURPOSE: their NAMES are the contract export-scenes.rb, wr-pack-export.rb
  # and the proposal packs on disk are written against, and changing their
  # cameras under those names would move output nobody asked to move. Use
  # AUTO-SET for a new pack; this stays for the fixed-five workflow and to own
  # the tag family. THE THREE PARALLEL PLATES BELOW ARE KNOWN TO DISAGREE WITH
  # HIS STATED PREFERENCE - that is a decision, not an oversight.
  PLATES = [
    { :name => '01-exterior',    :kind => :three_quarter, :az => 0.0,   :el => 12.0, :persp => true  },
    { :name => '02-dimensioned', :kind => :three_quarter, :az => 0.0,   :el => 20.0, :persp => false },
    { :name => '03-side',        :kind => :elevation,     :az => 90.0,  :el => 0.0,  :persp => false },
    { :name => '04-ventilation', :kind => :vent,          :az => 180.0, :el => 14.0, :persp => false },
    { :name => '05-plan',        :kind => :plan,          :az => 0.0,   :el => 89.0, :persp => false }
  ].freeze

  # Every WhisperRoom dimension tag, because a plate must not inherit whatever
  # visibility a tag happened to have when the scenes were made. This list was
  # two tags long and predated the booth tool (WR-Dims-Booth — now
  # dimension-whisperroom.rb, which kept the tag name on purpose) and
  # dimension-selection.rb (WR-Dims-Selection), so those two froze at whatever
  # state they were in — booth catalogue numbers could land on the clean
  # exterior plate, or vanish from the dimensioned one. These are customer
  # plates; nothing on them gets to be accidental.
  DIM_TAGS = %w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Dims-Selection].freeze

  # CONSTRUCTION NOTES -- text, not dimensions, and until 30 Aug 2026 nothing
  # in the toolset knew they existed. build-room.rb writes a Sketchup::Text
  # banner ("Ceiling 8'-0\" - HOUSE DEFAULT, not measured. Confirm before
  # quoting.") onto WR-Notes. WR-Notes is NOT a dimension tag, so it was in no
  # mode's tag list, so NO mode ever hid it -- and it went out on a client
  # image on 30 Aug 2026 (defect D5). It is listed separately from DIM_TAGS
  # rather than folded into it because DIM_TAGS also drives which plate shows
  # the room's dimensions, and a note is not a dimension.
  NOTE_TAGS = %w[WR-Notes].freeze

  # Every tag that carries construction annotation. Anything added here is
  # hidden by render mode, offered by the per-scene ANNOTATIONS picker and
  # reported by the proposal package's manifest. (Until 1.46.0 it was also
  # the list the package's "Client-safe" export pass hid; that mode is gone.)
  ANNOT_TAGS = (DIM_TAGS + NOTE_TAGS).freeze

  # THE FAMILY IS A PATTERN, NOT JUST THE FIVE FROZEN NAMES (1.20.0).
  #
  # ANNOT_TAGS above is the five names the WR tools themselves write, and it
  # stays frozen because seven call sites and two test harnesses name it. But
  # wr-scene-annotations.rb lets Benton MAKE annotation sets — "WR-Notes-Plan",
  # "WR-Notes-Vent" — and a set outside the family would be invisible to
  # every consumer that matches the family by name: the picker's SET rows,
  # the manifest's annotation_tags_shown / _hidden, render mode's policy.
  #
  # So the family is matched LIVE against the model's own tags: anything named
  # WR-Dims, WR-Notes, or either with a "-suffix". Every consumer calls
  # annot_tags(model) instead of reading the constant, so a set created this
  # afternoon is known to tonight's export.
  ANNOT_RE = /\AWR-(Dims|Notes)(\z|-)/.freeze

  # The five frozen names PLUS every family tag this model actually carries.
  # Rescued to the constant: an unreadable layer collection must not take a
  # consumer down with it, and the five are always the right floor.
  def self.annot_tags(model)
    (ANNOT_TAGS + model.layers.map { |l| l.name.to_s }.grep(ANNOT_RE)).uniq
  rescue StandardError
    ANNOT_TAGS.dup
  end

  # The tag name a typed set name becomes. A name already in the family is
  # taken verbatim (so "WR-Dims-Booth" means that tag, not a nested one);
  # anything else gets the WR-Notes- prefix, because a set outside the family
  # is a set no consumer can see. nil for an empty name — the caller says
  # so rather than inventing "WR-Notes-".
  def self.annot_set_name(user)
    s = user.to_s.strip
    return nil if s.empty?
    return s if s =~ ANNOT_RE
    slug = s.gsub(/[^A-Za-z0-9 _-]/, '').strip.gsub(/[\s_]+/, '-')
    slug = slug.gsub(/-+/, '-').sub(/\A-+/, '').sub(/-+\z/, '')
    return nil if slug.empty?
    "WR-Notes-#{slug}"
  end

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

  # dist and fov are OPTIONAL and default to nil, which means "the numbers
  # this tool has always used". wr-autoset.rb passes its own (WR_AutoSet
  # .standoff / PLATE_FOV) because Benton's shot list names a standoff -
  # "step out like 15 ft or so" - and radius * 3.2 + 60 puts a 4872 at 21 ft.
  # Passing nil changes nothing, so this file's own five plates are untouched.
  #
  # The up vector swaps to +Y at |el| >= 88 because at straight down the
  # world Z axis IS the view direction and (0,0,1) is degenerate. That guard
  # is what lets a caller ask for el 90 rather than fudging 89.
  def self.aim(view, centre, radius, az_deg, el_deg, persp, dist = nil, fov = nil)
    a = az_deg * DEG
    e = el_deg * DEG
    dir = Geom::Vector3d.new(Math.cos(e) * Math.cos(a),
                             Math.cos(e) * Math.sin(a),
                             Math.sin(e))
    dist = (radius * 3.2 + 60.0) if dist.nil?
    eye = centre.offset(dir, dist)
    up  = (el_deg.abs >= 88.0) ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, 0, 1)
    cam = view.camera
    if persp
      # PROJECTION BEFORE POSITION. Flipping a parallel camera to perspective
      # makes SketchUp keep the target and re-derive the eye from the parallel
      # frame height, so a set() done BEFORE the flip is overwritten by it --
      # measured live on wr-autoset's interior plate, 11 Sep 2026: an eye set
      # 27 in from the target came back 295.6 in from it. set() goes last so
      # it is the last word, whatever projection the view was in.
      cam.perspective = true
      cam.fov = (fov.nil? ? 40.0 : fov.to_f)
      cam.set(eye, centre, up)
    else
      cam.set(eye, centre, up)
      cam.perspective = false
      cam.height = radius * 2.3     # last: set() can reset the frame height
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
    puts '  THERE IS A BOOTH-AWARE VERSION OF THIS NOW (1.48.0). The proposal'
    puts '  package window has an AUTO-SET bar: pick a booth, click once, and'
    puts '  get scenes NAMED AFTER THAT BOOTH, marked Skip/Image/Render, with'
    puts '  the per-scene WALLS and ANNOTATIONS answers already written -- and'
    puts '  clickable again on a second booth without a name collision. This'
    puts '  script stays: it is the fixed five, globally named, and it owns the'
    puts '  tag family (DIM_TAGS / NOTE_TAGS / ANNOT_RE / annot_tags) that'
    puts '  AUTO-SET and every other consumer reads. Note that AUTO-SET makes'
    puts '  plate 3 a FRONT elevation; the 03-side above is a SIDE elevation.'
    puts ''
  end
end

WR_ProposalScenes.run unless $wr_no_autorun
