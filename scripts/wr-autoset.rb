# wr-autoset.rb — AUTO-SET: one click turns a selected booth into a finished
# proposal grid.
#
# NOT A COMMAND. This is a library, loaded by proposal-package.rb and driven
# from the AUTO-SET bar in that window. It is in wr_tools' SKIP list so it does
# not appear in the panel as something to run. (Same shape as wr-scene-sun.rb:
# the thing being pre-filled IS the proposal grid, so a second window would
# only make Benton alt-tab to review its work.)
#
# Spec: .forge/scoper/proposal-autoset.md. Benton, 10 Sep 2026: "select the
# whisperroom, then it would make scenes and label them accordingly. This way,
# it can be clicked a 2nd time on a 2nd booth... Almost do all of the work, and
# just have you review it before you export."
#
# WHAT IT DOES. Resolve a booth (viewport selection wins; otherwise a dropdown
# of the top-level containers whose NAME names a model). Create five scenes
# named after that booth — "MDL 96120 E 01-exterior" — mark each Skip/Image/
# Render, and write each scene's WALLS and ANNOTATIONS answer through the
# existing per-scene pickers. Then stop, because the review is the point.
#
# ------------------------------------------------------------------------
# THE ANNOTATION RULE IS AN ALLOWLIST. READ THIS BEFORE EDITING ANYTHING.
# ------------------------------------------------------------------------
# Client-safe annotation mode was removed at 1.47.0. The per-scene ANNOTATIONS
# picker is now the ONLY authority on what a customer image shows; there is no
# second net. So an auto-set plate SHOWS ONLY the annotation sets it names by
# hand (SHOWN_BY_PLATE), and EVERY other family tag plus EVERY loose Untagged
# callout is hidden.
#
# It is an allowlist and not a denylist because SketchUp REFUSES to hide the
# Untagged tag (observed: `tag.untagged_can_hide` FAILED live, see
# wr-scene-annotations.rb:35-42), hand-placed text lands on Untagged, and the
# CONTENT of that text is unknown to any tool. A denylist can only hide what it
# has heard of. An allowlist is the only policy under which unknown text cannot
# reach a customer.
#
# NEVER_SHOWN is a second gate on top of that — WR-Notes is the literal
# defect-D5 string (the `Ceiling 8'-0" - HOUSE DEFAULT` banner that went out on
# a client image on 30 Aug 2026). It exists so that a future edit to
# SHOWN_BY_PLATE cannot put one of those three back on a plate by accident.
# Do not "simplify" either list into a denylist.
#
# ------------------------------------------------------------------------
# IDEMPOTENCY RESTS ENTIRELY ON THE STAMP.
# ------------------------------------------------------------------------
# Every page auto-set creates carries a WR_AutoSet attribute dictionary:
# token, plate, version, centre. THE CONTAINMENT RULE: auto-set reads, writes
# and erases ONLY pages carrying a stamp with the token it is working on. A
# page with no stamp is NEVER touched, under any code path, Remove included —
# Benton keeps his own scenes.
#
# Matching is BY STAMP, NEVER BY NAME, so a scene he renamed by hand is
# updated in place rather than renamed back. And cameras are NOT re-aimed on a
# re-run unless he ticks the box: walls and annotations are POLICY and auto-set
# is the policy authority; the camera is TASTE and it is not (proposal-scenes.rb
# says the same thing in its own report: "THE EXACT ANGLE IS BENTON'S CALL").
#
#   load "C:/.../scripts/wr-autoset.rb"   (library; proposal-package.rb does it)

require 'sketchup.rb'
require 'json'

wr_as_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  # proposal-scenes.rb owns the tag family (ANNOT_RE, annot_tags,
  # SHOWN_ON_DIMENSIONED) and the camera maths (aim). Loaded as a library
  # only — a LOCAL holds the flag so a nested load cannot clobber it (the
  # 2026-08-27 dead-button bug).
  load File.join(File.dirname(__FILE__), 'proposal-scenes.rb')
ensure
  $wr_no_autorun = wr_as_autorun_was
end

module WR_AutoSet
  DEG  = Math::PI / 180.0
  DICT = 'WR_AutoSet'.freeze
  # Stamp format. Bump only when the KEYS change; a page written by an older
  # format is still matched on token, which is the only key identity needs.
  STAMP_VERSION = 1

  # No WR-Booth-Door tag anywhere under the booth: look from the model's -Y
  # side, the same fallback proposal-scenes.rb has always used. The popover
  # says so IN ORANGE BEFORE Apply, because this is how you get a hero shot of
  # the back of the booth.
  FALLBACK_AZ = -90.0

  # How far off the stored centre a booth has to move before the Update path
  # pre-ticks "re-aim cameras". 1" because that is the wall gap Benton draws
  # to (CLAUDE.md); anything smaller is float noise.
  MOVED_TOL = 1.0

  # ------------------------------------------------------------- plates --
  #
  # PLATE 3 IS A FRONT ELEVATION, AND THAT IS A CHANGE. proposal-scenes.rb
  # makes `03-side`, a SIDE elevation at az +90 (observed, its PLATES array).
  # Both real proposal packs on disk ask for a FRONT elevation with the door
  # open — proposals/examples/example-client/proposal-v2.json ("Front
  # Elevation", stem `front`) and proposals/examples/peoplesspace (two front
  # renders, `07-front-render-left-door` / `09-front-render-right-door`). So
  # the frozen side elevation looks like a defect rather than a preference,
  # and auto-set aims plate 3 at the real door side. Benton's answer, 10 Sep
  # 2026: switch to front.
  #
  #   :az    :door or :vent — which tag the azimuth is read from
  #   :swing degrees added to it; 35 makes a three-quarter out of a head-on
  #   :el    elevation in degrees; 89 is the plan
  #   :inside the camera goes INSIDE the booth (06-interior only)
  #
  # '06-interior' is named so it matches proposal-package.rb's INTERIOR_RE
  # (/interior|inside|in-booth|booth\s+in/i), which is what selects the
  # interior exposure value for a render row. Renaming it would silently
  # mis-expose it.
  PLATES = [
    { :id => '01-exterior',    :az => :door, :swing => 35.0, :el => 12.0, :persp => true,
      :on => true,  :what => 'Main Render / cover hero' },
    { :id => '02-dimensioned', :az => :door, :swing => 35.0, :el => 20.0, :persp => false,
      :on => true,  :what => 'Dimensioned View' },
    { :id => '03-front',       :az => :door, :swing => 0.0,  :el => 0.0,  :persp => false,
      :on => true,  :what => 'Front Elevation' },
    { :id => '04-ventilation', :az => :vent, :swing => 25.0, :el => 14.0, :persp => false,
      :on => true,  :what => 'Rear View & Ventilation' },
    { :id => '05-plan',        :az => :door, :swing => 0.0,  :el => 89.0, :persp => false,
      :on => true,  :what => 'Top-Down Floor Plan' },
    { :id => '06-interior',    :az => :door, :swing => 0.0,  :el => 0.0,  :persp => true,
      :on => false, :inside => true, :what => 'Interior (off by default)' }
  ].freeze

  # Plates that hide NO walls. 05-plan: walls do not occlude from directly
  # above and the plan's job is to show the booth IN the room. 06-interior:
  # the occluders there are the booth's own panels, which are not wall units —
  # said out loud in the log rather than silently doing nothing.
  NO_WALL_PLATES = %w[05-plan 06-interior].freeze

  # RENDERS ARE A KNOB, NOT A CONSTANT. Default 2 (Benton, 10 Sep 2026);
  # 0-6 from the popover. Assigned down this fixed ladder, everything below
  # the line is IMAGE. Exterior first because it is the cover in both packs;
  # front second because peoplesspace renders both its front options; the
  # dimensioned plate and the plan are LAST on purpose — a plate whose job is
  # to carry a dimension string does not need photoreal materials, and the
  # render lane is the expensive one.
  RENDER_LADDER = %w[01-exterior 03-front 04-ventilation
                     06-interior 02-dimensioned 05-plan].freeze
  DEFAULT_RENDERS = 2
  MAX_RENDERS = 6

  # ------------------------------------------------- the annotation rule --

  # NEVER shown by auto-set, on any plate, ever.
  #   WR-Notes          the house-default ceiling banner — the literal D5 string
  #   WR-Dims-Booth     working dimensions: a booth carrying both shows two
  #   WR-Dims-Selection different footprints with nothing saying which is which
  #                     (proposal-scenes.rb:120-129 — that reasoning is lifted,
  #                     not invented).
  NEVER_SHOWN = %w[WR-Notes WR-Dims-Booth WR-Dims-Selection].freeze

  # THE ALLOWLIST. A plate shows these family tags AND NOTHING ELSE — every
  # other family tag and every loose Untagged callout is hidden. A name here
  # that the model does not carry is simply not shown (opt-in by existence),
  # so a shop that has never made a WR-Notes-Vent set gets a clean plate 4.
  SHOWN_BY_PLATE = {
    '01-exterior'    => [],                                        # hero: clean or it isn't a hero
    '02-dimensioned' => WR_ProposalScenes::SHOWN_ON_DIMENSIONED,   # the existing, reviewed answer
    '03-front'       => [],                                        # elevation reads as a product shot
    '04-ventilation' => %w[WR-Notes-Vent],
    '05-plan'        => WR_ProposalScenes::SHOWN_ON_DIMENSIONED + %w[WR-Notes-Plan],
    '06-interior'    => []
  }.freeze

  # The family tags this plate may show, given the tags the model actually
  # carries. The NEVER_SHOWN subtraction is the second gate: it is what stops
  # a later edit to SHOWN_BY_PLATE putting WR-Notes back on a plate.
  def self.effective_shown(plate_id, present)
    allow = (SHOWN_BY_PLATE[plate_id.to_s] || [])
    ((allow & present.map { |n| n.to_s }) - NEVER_SHOWN)
  end

  # The full picks hash for one plate, in the picker's own polarity:
  # TICKED = HIDDEN. EVERY row is keyed, true or false — never a partial hash —
  # so a set shown on the previous plate cannot ride along into this one.
  #
  #   sets  [{ 'key' => 't:WR-Dims', 'name' => 'WR-Dims' }, ...]
  #   loose [{ 'key' => 'e:1234' }, ...]      every one of them is hidden
  def self.annot_picks(plate_id, sets, loose)
    shown = effective_shown(plate_id, (sets || []).map { |s| s['name'] })
    picks = {}
    (sets || []).each { |s| picks[s['key']] = !shown.include?(s['name'].to_s) }
    (loose || []).each { |it| picks[it['key']] = true }
    picks
  end

  # ------------------------------------------------------- the wall rule --
  #
  # A static per-plate wall preset cannot work: which wall blocks a shot
  # depends on where the booth sits in the room. wr-scene-walls.rb's :side is
  # a compass HINT relative to the wall's own room and says so (side_of, line
  # 109). So the rule is computed from the camera instead.
  #
  #   Hide wall W when  (centre(W) - C).norm . (E - C).norm  >  cos 60
  #
  # i.e. hide the walls standing between the camera and the booth. Show every
  # other wall. On the door-side three-quarter that is usually the two walls
  # of the near corner — which is what Benton does by hand today with
  # wr-lower-walls.rb ("I usually find the corner where the WhisperRoom is and
  # lower those two adjacent walls").
  COS_CONE = 0.5

  def self.unit_vec(a, b)
    vx = a[0].to_f - b[0].to_f
    vy = a[1].to_f - b[1].to_f
    vz = a[2].to_f - b[2].to_f
    m  = Math.sqrt((vx * vx) + (vy * vy) + (vz * vz))
    return nil if m < 1.0e-6
    [vx / m, vy / m, vz / m]
  end

  # The dot product the rule turns on, or nil when either vector is degenerate
  # (a wall centred on the booth, a camera at the booth centre). nil means
  # "cannot tell", and cannot-tell SHOWS the wall — failing toward showing a
  # wall costs a re-shot plate; failing toward hiding one costs a wrong image.
  def self.cone_dot(wall_c, centre, eye)
    w = unit_vec(wall_c, centre)
    e = unit_vec(eye, centre)
    return nil if w.nil? || e.nil?
    (w[0] * e[0]) + (w[1] * e[1]) + (w[2] * e[2])
  end

  # EVERY unit keyed, true or false. units: [{ 'key' => .., 'c' => [x,y,z] }].
  # Objects are never in this list — auto-set writes WALL units only, so a
  # booth, a chair or the other booth is never auto-hidden.
  def self.wall_picks(plate_id, units, centre, eye)
    none  = NO_WALL_PLATES.include?(plate_id.to_s)
    picks = {}
    (units || []).each do |u|
      d = none ? nil : cone_dot(u['c'], centre, eye)
      picks[u['key']] = (!d.nil? && d > COS_CONE)
    end
    picks
  end

  # Same walk, but keeping the dot so a wrong call is readable rather than
  # mysterious. [[key, label, dot, hidden], ...]
  def self.wall_log(plate_id, units, centre, eye)
    none = NO_WALL_PLATES.include?(plate_id.to_s)
    (units || []).map do |u|
      d = none ? nil : cone_dot(u['c'], centre, eye)
      [u['key'], u['label'].to_s, d, (!d.nil? && d > COS_CONE)]
    end
  end

  # ------------------------------------------------------- render ladder --

  # The plate ids that become RENDER rows: the first n rungs of the ladder
  # that are actually in this run's plate list. Everything else is IMAGE.
  def self.renders_for(n, plate_ids)
    want = n.to_i
    want = 0 if want < 0
    want = MAX_RENDERS if want > MAX_RENDERS
    RENDER_LADDER.select { |id| plate_ids.include?(id) }.first(want)
  end

  def self.mode_for(plate_id, render_ids)
    render_ids.include?(plate_id.to_s) ? 'render' : 'image'
  end

  # ------------------------------------------------------------ azimuth --

  def self.plate(plate_id)
    PLATES.find { |p| p[:id] == plate_id.to_s }
  end

  def self.plate_ids(interior = false)
    PLATES.select { |p| p[:on] || (interior && p[:id] == '06-interior') }.map { |p| p[:id] }
  end

  # Where the camera stands, in degrees. door_az/vent_az are read off the
  # booth's own WR-Booth-Door / WR-Booth-Vent tags; either may be nil.
  def self.az_for(plate_id, door_az, vent_az)
    p = plate(plate_id)
    return nil unless p
    base = door_az.nil? ? FALLBACK_AZ : door_az.to_f
    if p[:az] == :vent
      (vent_az.nil? ? (base + 180.0) : vent_az.to_f) + p[:swing]
    else
      base + p[:swing]
    end
  end

  # --------------------------------------------------------- the token --
  #
  # Two booths named "MDL 4872 E" is the collision case a NAME cannot
  # survive, so the name is cosmetic and the IDENTITY is a stored token. It
  # lives in the WR_AutoSet dictionary on the booth Group, written once on
  # first Apply and read on every later run.
  #
  # ENTITY ID IS DELIBERATELY NOT THE TOKEN: it is unreadable in a scene tab,
  # and its stability across a save/reopen is ASSUMED, not observed. A token
  # made from the name is readable, and the ordinal makes it unique.

  # Characters that are safe in a scene name AND in an attribute value.
  def self.sanitize_token(name)
    s = name.to_s.strip.gsub(%r{[\\/:\*\?"<>\|]}, '-').gsub(/\s+/, ' ').strip
    s.empty? ? 'booth' : s
  end

  # [token, label] for `base`, given the tokens already claimed in this model.
  # The token is the identity; the label is what Benton reads in a scene tab.
  # They are stored as two keys rather than one parsed string, so a booth
  # genuinely named "Rack-2" cannot be mistaken for the second "Rack".
  def self.next_token(taken, base)
    b = sanitize_token(base)
    return [b, b] unless taken.include?(b)
    n = 2
    n += 1 while taken.include?("#{b}-#{n}")
    ["#{b}-#{n}", "#{b} (#{n})"]
  end

  # "MDL 96120 E 01-exterior". Booth-first: with two booths in a pack the
  # booth is the disambiguator, and SketchUp's scene tabs truncate from the
  # right. Ordering is NOT carried by the name — plan_names prefixes the file
  # with the scene's TABLE POSITION (scene_prefix), so the export comes out
  # ordered whatever the names say.
  def self.scene_name(label, plate_id)
    "#{label} #{plate_id}"
  end

  def self.centre_key(pt)
    format('%.3f,%.3f,%.3f', pt[0].to_f, pt[1].to_f, pt[2].to_f)
  end

  def self.centre_from_key(s)
    parts = s.to_s.split(',')
    return nil unless parts.size == 3
    parts.map { |v| v.to_f }
  rescue StandardError
    nil
  end

  # Has the booth moved far enough since the scenes were aimed that the
  # framing is now wrong? An unreadable stored centre means "unknown" — which
  # is NOT "moved", because pre-ticking a re-aim on a page whose history we
  # cannot read would destroy a framing on no evidence.
  def self.moved_by(stored_key, live_centre)
    was = centre_from_key(stored_key)
    return nil if was.nil?
    dx = was[0] - live_centre[0].to_f
    dy = was[1] - live_centre[1].to_f
    dz = was[2] - live_centre[2].to_f
    Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
  end

  def self.centre_moved?(stored_key, live_centre, tol = MOVED_TOL)
    d = moved_by(stored_key, live_centre)
    return false if d.nil?
    d > tol.to_f
  end

  # ------------------------------------------------------------- stamps --

  # The stamp on a page, or nil. nil means "not ours" and NOTHING may touch it.
  def self.page_stamp(page)
    return nil unless page
    tok = page.get_attribute(DICT, 'token', nil)
    return nil if tok.nil? || tok.to_s.empty?
    { 'token'   => tok.to_s,
      'plate'   => page.get_attribute(DICT, 'plate', '').to_s,
      'version' => page.get_attribute(DICT, 'version', 0).to_i,
      'centre'  => page.get_attribute(DICT, 'centre', '').to_s }
  rescue StandardError
    nil
  end

  def self.stamp_page(page, token, plate_id, centre)
    page.set_attribute(DICT, 'token',   token.to_s)
    page.set_attribute(DICT, 'plate',   plate_id.to_s)
    page.set_attribute(DICT, 'version', STAMP_VERSION)
    page.set_attribute(DICT, 'centre',  centre_key(centre))
  end

  # THE CONTAINMENT RULE, in one method. Every read, update, rename and erase
  # path in this file goes through here, so an unstamped page cannot be
  # reached by any of them. Matched BY STAMP, never by name: a scene Benton
  # renamed by hand is still his set's, and Update rewrites it in place
  # instead of renaming it back.
  def self.token_pages(pages, token)
    (pages || []).select do |pg|
      st = page_stamp(pg)
      st && st['token'] == token.to_s
    end
  end

  def self.page_for_plate(pages, token, plate_id)
    token_pages(pages, token).find { |pg| page_stamp(pg)['plate'] == plate_id.to_s }
  end

  # Every token any page in this model claims — what next_token must avoid.
  def self.tokens_in_use(pages)
    (pages || []).map { |pg| st = page_stamp(pg); st && st['token'] }.compact.uniq
  end

  # ============================================================ live half ==
  # Nothing below here is pure, and nothing below here has been proven
  # offline. It is exercised by .forge/builder/verify-autoset.rb in a real
  # Untitled model.

  # A top-level container's booth-ness, delegated to the proposal package's
  # own test so there is ONE answer (name-matching only — it reports what the
  # model SAYS, never what a booth might be).
  def self.booth_named?(nm)
    if defined?(WR_ProposalPackage) && WR_ProposalPackage.respond_to?(:booth_name?)
      WR_ProposalPackage.booth_name?(nm)
    else
      s = nm.to_s
      !s.empty? && !!(s =~ /\bMDL\b/ || s =~ /\b\d{3,6}\s?[SE]\b/)
    end
  end

  def self.top_containers(model)
    model.entities.to_a.select do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
  rescue StandardError
    []
  end

  def self.container_name(e)
    nm = (e.name.to_s.strip rescue '')
    return nm unless nm.empty?
    (e.definition.name.to_s.strip rescue '')
  rescue StandardError
    ''
  end

  # THE RESOLVER. Selection wins; the list is the fallback. Reuses
  # WR_SceneWalls.subtree_ids to climb a viewport selection back to its
  # top-level container — the same containment walk the walls picker uses, so
  # clicking a door panel resolves to the booth exactly as it does there.
  #
  # Returns [booth_or_nil, note]. `note` is what the popover prints; a refusal
  # names what was hit rather than saying "select a booth".
  def self.resolve_booth(model, want_name = nil)
    tops = top_containers(model)
    if tops.empty?
      return [nil, 'This model has no top-level groups or components at all. ' \
                   'Build or place a booth first (Build booth).']
    end

    unless want_name.nil? || want_name.to_s.empty?
      hit = tops.find { |e| container_name(e) == want_name.to_s }
      return [hit, hit && booth_named?(container_name(hit)) ? nil : not_a_booth_note(want_name)] if hit
      return [nil, "\"#{want_name}\" is no longer in this model — hit Rescan."]
    end

    sel = (model.selection.to_a rescue [])
    unless sel.empty?
      ids = {}
      sel.each { |e| ids[e.entityID] = true }
      hits = tops.select do |top|
        under = (defined?(WR_SceneWalls) ? WR_SceneWalls.subtree_ids(top) : { top.entityID => true })
        under.keys.any? { |id| ids[id] }
      end
      if hits.size == 1
        b = hits.first
        return [b, booth_named?(container_name(b)) ? nil : not_a_booth_note(container_name(b))]
      elsif hits.size > 1
        return [nil, "Your selection reaches #{hits.size} top-level containers (" +
                     hits.map { |e| container_name(e) }.join(', ') +
                     '). Select one booth and try again.']
      end
    end

    named = tops.select { |e| booth_named?(container_name(e)) }
    return [named.first, nil] if named.size == 1
    return [nil, nil] unless named.empty?     # several: the dropdown decides
    [nil, 'Nothing in this model names a booth model (no "MDL" and no ' \
          'catalogue number). Pick a container from the list, or name the ' \
          'booth group after its model.']
  end

  # Said, not refused. Benton may have a hand-named booth, and refusing here
  # would be the tool second-guessing him.
  def self.not_a_booth_note(nm)
    "\"#{nm}\" does not name a booth model; scenes will be named after it anyway."
  end

  # The dropdown: booths first, then every other named top-level container,
  # so a hand-drawn model does not dead-end.
  def self.booth_choices(model)
    rows = top_containers(model).map do |e|
      nm = container_name(e)
      { 'name' => nm.empty? ? "unnamed ##{e.entityID}" : nm,
        'booth' => booth_named?(nm) ? true : false }
    end
    rows.sort_by { |r| [r['booth'] ? 0 : 1, r['name'].downcase] }
  end

  # ------------------------------------------------------ booth geometry --

  # The booth's bounds centre and radius, in MODEL space.
  def self.booth_frame(booth)
    bb = booth.bounds
    [bb.center.to_a, (bb.diagonal.to_f / 2.0), bb]
  end

  # The azimuth of a tagged part relative to the booth's own centre.
  #
  # Computed in the booth's LOCAL space and then rotated into model space as a
  # VECTOR (Vector3d#transform applies rotation/scale and ignores translation),
  # so a booth placed anywhere in the room still reads its own door correctly.
  # The room-local-vs-model-space confusion this avoids is the bug
  # wr-scene-walls.rb#side_of already fixed once, live, 31 Aug 2026.
  #
  # CAVEAT, stated rather than hidden: entities nested deeper than the booth
  # report bounds in their own parent's space, so this assumes the containers
  # between the booth and the tagged part carry identity transforms — which is
  # what the build tools produce. A wrong read falls back to FALLBACK_AZ and
  # the popover says so in orange BEFORE Apply.
  def self.tag_az(booth, tag_name)
    hits = []
    WR_ProposalScenes.walk(booth.entities, tag_name, hits, 0)
    return nil if hits.empty?
    own = Geom::BoundingBox.new
    booth.entities.each { |e| own.add(e.bounds) }
    tb = Geom::BoundingBox.new
    hits.each { |e| tb.add(e.bounds) }
    v = tb.center - own.center
    return nil if v.length < 1.0
    v = v.transform(booth.transformation)
    return nil if v.length < 1.0e-6
    Math.atan2(v.y, v.x) / DEG
  rescue StandardError
    nil
  end

  # Wall units as wall_picks wants them: key, label and a MODEL-space centre.
  # Walls only — object_units (the booths, the furniture) are deliberately
  # never auto-hidden.
  def self.wall_geometry(model)
    st = WR_SceneWalls.scan(model)
    (st[:walls] || []).map do |u|
      bb = Geom::BoundingBox.new
      u[:pieces].each { |g| bb.add(g.bounds) if g.valid? }
      side = u[:side].to_s
      { 'key' => u[:key], 'c' => bb.center.to_a,
        'label' => "#{u[:room]} Wall #{u[:wall]}#{side.empty? ? '' : " (#{side})"}" }
    end
  rescue StandardError
    []
  end

  # The annotation rows as annot_picks wants them, from the picker's own
  # inventory so the keys are the keys write_scene understands.
  def self.annot_rows(model)
    inv = WR_SceneAnnotations.inventory(model)
    [inv[:sets].map { |s| { 'key' => s[:key], 'name' => s[:name] } },
     inv[:loose].map { |it| { 'key' => it[:key] } }]
  end

  # ---------------------------------------------------------- the camera --

  def self.aim_plate(view, plate_id, centre_a, radius, door_az, vent_az)
    p = plate(plate_id)
    c = Geom::Point3d.new(centre_a[0], centre_a[1], centre_a[2])
    return aim_interior(view, c, radius, (door_az || FALLBACK_AZ)) if p[:inside]
    WR_ProposalScenes.aim(view, c, radius, az_for(plate_id, door_az, vent_az),
                          p[:el], p[:persp])
  end

  # Inside the booth, looking back across it. A STARTING POINT, not a
  # decision — nudge it and re-save that scene, like every other plate.
  def self.aim_interior(view, centre, radius, az)
    a   = az * DEG
    dir = Geom::Vector3d.new(Math.cos(a), Math.sin(a), 0)
    eye = centre.offset(dir, radius * 0.55)
    tgt = centre.offset(dir, -radius * 0.45)
    cam = view.camera
    cam.set(eye, tgt, Geom::Vector3d.new(0, 0, 1))
    cam.perspective = true
    cam.fov = 70.0
    cam
  end

  # ----------------------------------------------------------- the plan --
  #
  # What Apply WOULD do, computed before anything is written, so the popover
  # can show it and the log can name it. It reads the model; it writes nothing.
  def self.plan(model, booth, opts = {})
    ids     = opts['plates'] || plate_ids(opts['interior'] ? true : false)
    renders = renders_for(opts.key?('renders') ? opts['renders'] : DEFAULT_RENDERS, ids)
    pages   = model.pages.to_a
    taken   = tokens_in_use(pages)
    stored  = booth.get_attribute(DICT, 'token', nil)
    if stored.nil? || stored.to_s.empty?
      token, label = next_token(taken, container_name(booth))
      fresh = true
    else
      token = stored.to_s
      label = booth.get_attribute(DICT, 'label', token).to_s
      fresh = false
    end
    mine = token_pages(pages, token)
    centre, _radius, bb = booth_frame(booth)
    door  = tag_az(booth, 'WR-Booth-Door')
    vent  = tag_az(booth, 'WR-Booth-Vent')
    moved = mine.map { |pg| moved_by(page_stamp(pg)['centre'], centre) }.compact.max
    rows  = ids.map do |id|
      pg   = page_for_plate(pages, token, id)
      want = scene_name(label, id)
      { 'plate'   => id,
        'what'    => plate(id)[:what],
        'name'    => pg ? pg.name.to_s : want,
        'want'    => want,
        'mode'    => mode_for(id, renders),
        'exists'  => pg ? true : false,
        'renamed' => (pg && pg.name.to_s != want) ? true : false }
    end
    { 'token'    => token,
      'label'    => label,
      'fresh'    => fresh,
      'booth'    => container_name(booth),
      'isbooth'  => booth_named?(container_name(booth)),
      'size'     => size_label(bb),
      'door'     => door,
      'vent'     => vent,
      'existing' => mine.size,
      'moved'    => moved,
      'movedfar' => (!moved.nil? && moved > MOVED_TOL),
      'renders'  => renders,
      'rows'     => rows,
      'walls'    => wall_geometry(model).size,
      'orphans'  => orphan_tokens(model),
      'offpages' => (WR_SceneWalls.pages_not_saving_hidden(model) |
                     WR_SceneAnnotations.pages_not_saving(model)) }
  end

  def self.size_label(bb)
    f = lambda { |v| (Sketchup.format_length(v) rescue format('%.1f"', v.to_f)) }
    "#{f.call(bb.width)} x #{f.call(bb.depth)} x #{f.call(bb.height)}"
  rescue StandardError
    ''
  end

  # ----------------------------------------------------------- the write --
  #
  # ONE start_operation for the whole run. The per-scene writes go through
  # each module's own write_scene — which is documented as having NO
  # transaction of its own precisely so a caller can own the operation — and
  # NOT through apply/apply_all: apply would nest an operation per page, and
  # apply_all writes THE SAME picks into every scene, which is the one thing
  # these picks must not be.
  #
  # Each page is SELECTED before it is written, because page.update snapshots
  # the model as it stands and selecting the page is what restores that
  # scene's own state for everything that is not a row here.
  #
  # mode: 'create' | 'update' | 'add' | 'remove'
  def self.apply(model, booth, opts = {})
    unless defined?(WR_ProposalPackage)
      return [false, 'AUTO-SET needs the proposal package loaded (it stores the ' \
                     'Skip/Image/Render mark).', []]
    end
    what = (opts['mode'] || 'create').to_s
    return remove(model, booth, opts) if what == 'remove'

    ids     = opts['plates'] || plate_ids(opts['interior'] ? true : false)
    renders = renders_for(opts.key?('renders') ? opts['renders'] : DEFAULT_RENDERS, ids)
    reaim   = opts['reaim'] ? true : false
    pages   = model.pages
    view    = model.active_view

    centre, radius, = booth_frame(booth)
    door = tag_az(booth, 'WR-Booth-Door')
    vent = tag_az(booth, 'WR-Booth-Vent')

    taken  = tokens_in_use(pages.to_a)
    stored = booth.get_attribute(DICT, 'token', nil).to_s
    if what == 'add' || stored.empty?
      base = stored.empty? ? container_name(booth) : stored
      token, label = next_token(taken, base)
      reaim = true                      # a brand-new set has nothing to preserve
    else
      token = stored
      label = booth.get_attribute(DICT, 'label', token).to_s
    end

    # Key indexes first: both modules' write_scene reads its own @units, and
    # both are rebuilt by these two calls. wall_geometry calls WR_SceneWalls
    # .scan, annot_rows calls WR_SceneAnnotations.inventory.
    units       = wall_geometry(model)
    sets, loose = annot_rows(model)

    start   = pages.selected_page
    ents    = []
    lines   = []
    prev_tr = begin
      t = model.options['PageOptions']['ShowTransition']
      model.options['PageOptions']['ShowTransition'] = false
      t
    rescue StandardError
      nil
    end

    model.start_operation('AUTO-SET proposal scenes', true)
    begin
      booth.set_attribute(DICT, 'token', token)
      booth.set_attribute(DICT, 'label', label)

      ids.each do |id|
        page  = page_for_plate(pages.to_a, token, id)
        want  = scene_name(label, id)
        fresh = page.nil?

        if fresh
          aim_plate(view, id, centre, radius, door, vent)
          page = pages.add(want)
          lines << "created  #{want}"
        elsif reaim
          pages.selected_page = page
          aim_plate(view, id, centre, radius, door, vent)
          # THE CAMERA HAS TO BE SAVED EXPLICITLY. write_scene below calls
          # page.update with the HIDDEN-state mask only (WR_SceneWalls
          # .update_mask = hidden objects | hidden geometry), so without this
          # line a re-aim would move the viewport and the scene would put the
          # old camera straight back the next time it was clicked.
          page.update(PAGE_USE_CAMERA) if defined?(PAGE_USE_CAMERA)
          lines << "re-aimed #{page.name}"
        elsif page.name.to_s != want
          # RENAMED BY HAND. Updated, never renamed back — matched on the
          # stamp, so the name is his to keep.
          lines << "updated  #{page.name}  (renamed by hand; left as it is)"
        else
          lines << "updated  #{page.name}"
        end

        page.use_camera            = true
        page.use_hidden_layers     = true
        page.use_hidden_objects    = true if page.respond_to?(:use_hidden_objects=)
        page.use_rendering_options = true
        page.use_shadow_info       = true
        page.use_axes              = false
        page.use_section_planes    = true
        page.transition_time       = 0

        pages.selected_page = page
        eye = page_eye(page, view)

        wpicks = wall_picks(id, units, centre, eye)
        apicks = annot_picks(id, sets, loose)
        ents << { :page => page, :name => page.name.to_s, :new => fresh,
                  :wbefore => (fresh ? nil : WR_SceneWalls.snapshot_keys(wpicks.keys)),
                  :abefore => (fresh ? nil : WR_SceneAnnotations.snapshot_keys(apicks.keys)) }

        WR_SceneWalls.write_scene(page, wpicks)
        WR_SceneAnnotations.write_scene(page, apicks)
        WR_ProposalPackage.set_mode(page, mode_for(id, renders))
        stamp_page(page, token, id, centre)

        lines.concat(plate_log(id, units, centre, eye, sets, loose))
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      restore_transition(model, prev_tr)
      return [false, "AUTO-SET failed and was rolled back: #{e.class}: #{e.message}", lines]
    end

    remember_write(model, label, ents)
    restore_page(model, start)
    restore_transition(model, prev_tr)
    n_new = ents.count { |e| e[:new] }
    msg = "AUTO-SET #{label}: #{n_new} scene(s) created, #{ents.size - n_new} updated, " \
          "#{renders.size} render / #{ents.size - renders.size} image. " \
          'Read the WALLS and ANNOTATIONS columns before you export.'
    [true, msg, lines]
  end

  # Every wall this plate hides, with its dot product, and exactly which
  # annotation sets it shows. A wrong call has to be readable, not mysterious.
  def self.plate_log(id, units, centre, eye, sets, loose)
    out = []
    hid = wall_log(id, units, centre, eye).select { |r| r[3] }
    if NO_WALL_PLATES.include?(id)
      why = id == '05-plan' ? 'nothing occludes from above' :
            "the occluders are the booth's own panels, which are not wall units"
      out << "         walls: none hidden (#{why})"
    elsif hid.empty?
      out << '         walls: none in the camera cone'
    else
      hid.each { |_k, lab, d, _h| out << format('         hides %s  (dot %.2f)', lab, d) }
    end
    shown = effective_shown(id, sets.map { |s| s['name'] })
    out << "         shows: #{shown.empty? ? 'no annotations at all' : shown.join(' + ')}" \
           "#{loose.empty? ? '' : " — #{loose.size} loose callout(s) hidden"}"
    out
  end

  # The eye the wall rule is computed from: the page's OWN saved camera. On a
  # scene Benton nudged by hand that is his framing, which is the point — the
  # walls follow the camera, the camera does not follow the walls.
  def self.page_eye(page, view)
    c = page.camera
    return c.eye.to_a if c
    view.camera.eye.to_a
  rescue StandardError
    view.camera.eye.to_a
  end

  # REMOVE: this token's stamped pages, and nothing else. A page with no stamp
  # is not reachable from here — token_pages is the only way in.
  def self.remove(model, booth, opts = {})
    pages = model.pages
    token = (opts['token'] || (booth && booth.get_attribute(DICT, 'token', nil))).to_s
    if token.empty?
      return [false, 'No auto-set token on that booth — nothing of mine to remove.', []]
    end
    mine = token_pages(pages.to_a, token)
    return [false, "No stamped scenes for #{token} — nothing removed.", []] if mine.empty?
    names = mine.map { |pg| pg.name.to_s }
    model.start_operation("AUTO-SET: remove this booth's scenes", true)
    begin
      mine.each { |pg| pages.erase(pg) }
      booth.delete_attribute(DICT) if booth && booth.respond_to?(:delete_attribute)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Remove failed and was rolled back: #{e.class}: #{e.message}", []]
    end
    @last_write = nil
    [true, "Removed #{names.size} auto-set scene(s) for #{token}. Scenes with no " \
           'AUTO-SET stamp were not touched.', names.map { |n| "erased   #{n}" }]
  end

  # Stamped pages whose booth is gone — offered, never erased silently.
  def self.orphan_tokens(model)
    live = {}
    top_containers(model).each do |e|
      t = (e.get_attribute(DICT, 'token', nil) rescue nil)
      live[t.to_s] = true if t
    end
    tokens_in_use(model.pages.to_a).reject { |t| live[t] }
  end

  def self.remove_token(model, token)
    pages = model.pages
    mine  = token_pages(pages.to_a, token)
    return [false, "No stamped scenes for #{token}.", []] if mine.empty?
    names = mine.map { |pg| pg.name.to_s }
    model.start_operation('AUTO-SET: remove orphaned scenes', true)
    begin
      mine.each { |pg| pages.erase(pg) }
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Remove failed and was rolled back: #{e.class}: #{e.message}", []]
    end
    @last_write = nil
    [true, "Removed #{names.size} orphaned scene(s) for #{token}.",
     names.map { |n| "erased   #{n}" }]
  end

  def self.restore_page(model, page)
    model.pages.selected_page = page if page && page.valid?
  rescue StandardError
    nil
  end

  def self.restore_transition(model, prev)
    return if prev.nil?
    model.options['PageOptions']['ShowTransition'] = prev
  rescue StandardError
    nil
  end

  # ---- UNDO LAST APPLY ----------------------------------------------------
  #
  # page.update is outside SketchUp's undo stack (1.25.2), so Ctrl+Z cannot
  # reverse a scene write and both scene modules record what they overwrote.
  # Auto-set writes MANY pages, so one module-level step is not enough: this
  # records the pages it CREATED (to erase) and, for pages it UPDATED, each
  # one's prior walls and annotations snapshot. Same contract as the others —
  # one step, this session, this model, used up when taken — so the window's
  # UNDO LAST APPLY picks it up through WR_ProposalPackage.undo_mod.
  def self.last_write
    @last_write
  end

  def self.model_key(model)
    model.guid
  rescue StandardError
    model.object_id
  end

  def self.remember_write(model, label, entries)
    return if entries.nil? || entries.empty?
    @last_write = { :model => model_key(model), :what => "AUTO-SET — #{label}",
                    :label => label, :pages => entries, :at => Time.now }
  end

  def self.undo_summary(model)
    lw = @last_write
    return nil unless lw && lw[:model] == model_key(model)
    names = lw[:pages].select { |e| e[:page] && e[:page].valid? }.map { |e| e[:name] }
    return nil if names.empty?
    { 'what' => lw[:what], 'scenes' => names,
      'at' => lw[:at].strftime('%H:%M'), 'module' => 'WR_AutoSet' }
  rescue StandardError
    nil
  end

  def self.undo_last(model)
    lw = @last_write
    unless lw
      return [false, 'Nothing to put back — no auto-set has been recorded in this ' \
                     'SketchUp session.']
    end
    unless lw[:model] == model_key(model)
      return [false, 'The last auto-set was on a different model — nothing put back.']
    end
    entries = lw[:pages].select { |e| e[:page] && e[:page].valid? }
    return [false, 'The scenes the last auto-set wrote no longer exist.'] if entries.empty?
    # Rebuild both key indexes: the snapshots are keyed on entity ids.
    WR_SceneWalls.scan(model)
    WR_SceneAnnotations.inventory(model)
    start  = model.pages.selected_page
    erased = []
    put    = []
    model.start_operation('Put back the last AUTO-SET', true)
    begin
      entries.each do |e|
        if e[:new]
          erased << e[:name]
          model.pages.erase(e[:page])
          next
        end
        model.pages.selected_page = e[:page]
        WR_SceneWalls.write_snapshot(e[:page], e[:wbefore]) if e[:wbefore]
        WR_SceneAnnotations.write_snapshot(e[:page], e[:abefore]) if e[:abefore]
        put << e[:name]
      end
      model.commit_operation
    rescue StandardError => ex
      model.abort_operation
      restore_page(model, start)
      return [false, "Put back failed and was rolled back: #{ex.class}: #{ex.message}"]
    end
    restore_page(model, start)
    @last_write = nil
    [true, "Put back the last auto-set: #{erased.size} scene(s) erased" \
           "#{erased.empty? ? '' : " (#{erased.join(', ')})"}, #{put.size} restored" \
           "#{put.empty? ? '' : " (#{put.join(', ')})"}. That was the one step " \
           'there is — it is used up. The Skip/Image/Render marks on the restored ' \
           'scenes are not reversed; set them in the grid.']
  end

  # ------------------------------------------------- the review surface --
  #
  # §4.3 of the spec, and a REQUIRED part of this feature rather than polish:
  # the WALLS and ANNOTATIONS columns rendered stateless buttons until now, so
  # after auto-set wrote ten scenes there was nothing on screen to review —
  # which defeats the whole ask ("just have you review it before you export").
  #
  # TWO READS, DELIBERATELY SPLIT BY COST.
  #   SHALLOW (always, no page selection): the tags a page hides, straight off
  #     Sketchup::Page#layers — OBSERVED to return the HIDDEN layers
  #     (proposal-package.rb:3004-3011, scripted run 31 Aug 2026).
  #   DEEP (selects each page in turn): the wall units' and loose callouts'
  #     per-entity hidden state, which lives in the page's own snapshot and
  #     cannot be read any other way.
  #
  # The spec flagged the deep read's cost as ASSUMED and unmeasured. It is now
  # MEASURED on the machine it runs on: the pass is timed, the time goes to the
  # window's log, and if it blows DEEP_BUDGET the deep read is switched off for
  # the session and the columns SAY SO rather than being quietly slow. The
  # caller caches this — it must not run on every mark click.
  DEEP_BUDGET = 2.5

  def self.deep?
    @deep = true if @deep.nil?
    @deep
  end

  def self.deep=(v)
    @deep = v ? true : false
  end

  # { n => { 'walls' => .., 'annots' => .. }, '_deep' =>, '_ms' =>, '_n' => }
  def self.row_states(model)
    pages = model.pages.to_a
    out   = { '_deep' => false, '_ms' => 0.0, '_n' => pages.size }
    return out if pages.empty?

    family = WR_ProposalScenes.annot_tags(model).select { |n| (model.layers[n] rescue nil) }
    pages.each_with_index do |pg, i|
      hidden = (pg.layers.map { |l| l.name.to_s } rescue nil)
      out[i + 1] = { 'walls' => nil, 'annots' => annot_cell(family, hidden, nil) }
    end
    return out unless deep?

    t0    = Time.now
    units = (WR_SceneWalls.scan(model)[:walls] rescue [])
    loose = (WR_SceneAnnotations.inventory(model)[:loose] rescue [])
    start = model.pages.selected_page
    prev_tr = begin
      t = model.options['PageOptions']['ShowTransition']
      model.options['PageOptions']['ShowTransition'] = false
      t
    rescue StandardError
      nil
    end
    begin
      pages.each_with_index do |pg, i|
        model.pages.selected_page = pg
        hid = units.select { |u| u[:pieces].all? { |g| ((g.valid? && g.hidden?) rescue false) } }
        out[i + 1]['walls'] = { 'total' => units.size, 'hidden' => hid.size,
                                'names' => hid.first(8).map { |u| WR_SceneWalls.unit_label(u) } }
        shown_loose = loose.reject { |it| ((it[:ent].valid? && it[:ent].hidden?) rescue true) }
        out[i + 1]['annots'] = annot_cell(family, (pg.layers.map { |l| l.name.to_s } rescue nil),
                                          shown_loose)
      end
    ensure
      restore_page(model, start)
      restore_transition(model, prev_tr)
    end
    ms = (Time.now - t0).to_f
    out['_deep'] = true
    out['_ms']   = ms
    if ms > DEEP_BUDGET
      self.deep = false
      out['_slow'] = true
    end
    out
  end

  # What one ANNOTATIONS cell says. `hidden_tags` nil means the page's state
  # could not be read — reported as unreadable, never as "clean". `loose_shown`
  # nil means the deep read did not run, so the cell does not claim to know.
  def self.annot_cell(family, hidden_tags, loose_shown)
    if hidden_tags.nil?
      return { 'label' => 'unreadable', 'warn' => true, 'loose' => nil,
               'tip' => "This scene's tag state could not be read. Open the picker." }
    end
    shown = family - hidden_tags
    label = if shown.empty?
              'all hidden'
            elsif shown.sort == WR_ProposalScenes::SHOWN_ON_DIMENSIONED.sort
              'dims + doors'
            else
              "#{shown.size} shown"
            end
    tip  = shown.empty? ? 'No annotation set is shown on this scene.' :
           "Shown: #{shown.join(', ')}"
    warn = false
    unless loose_shown.nil?
      n = loose_shown.size
      if n > 0
        warn  = true
        label = "#{label} + #{n} loose"
        tip  += " — #{n} LOOSE/Untagged callout(s) still SHOWN: " +
                loose_shown.first(6).map { |it| it[:text].to_s }.join(' | ')
      end
    end
    { 'label' => label, 'warn' => warn, 'tip' => tip,
      'shown' => shown, 'loose' => (loose_shown.nil? ? nil : loose_shown.size) }
  end
end
