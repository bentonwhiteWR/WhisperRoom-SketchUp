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
  # THE SHOT LIST IS BENTON'S, VERBATIM (10 Sep 2026), after the first real
  # run of 1.48.0 came back "the layouts are terrible":
  #
  #   "Almost always, I will have a 'front on' view. Find the door, step out
  #    like 15 ft or so. Straight on. Perspective. FYI I never use parellel
  #    perspective so dont use it either. This first front view is great to
  #    show dimensions... Then I would go to the left or right, so you see the
  #    booth at a bit of an angle. Still about the same height... Then usually
  #    one from 15-20ft high around this same angle. This is image. Great at
  #    showing dimensions. Sometimes a side view depending on how big the
  #    booth is, or if there are windows. Usually a back view to show
  #    ventilation (this usually requires a hidden wall). Then finally a Top
  #    Down view that shows dimensions"
  #
  # EVERY PLATE IS PERSPECTIVE EXCEPT THE TOP-DOWN. Benton first said it
  # flatly - "I never use parellel perspective so dont use it either" - and
  # then refined it the same day, 10 Sep 2026, having seen the plates:
  # "The top down should actually be the only one in parellel projection so
  # change that too."
  #
  # THAT REFINEMENT SUPERSEDES THE BLANKET RULE AND IS NOT A REGRESSION. A
  # top-down is a drafting plan and parallel is the correct convention for one
  # - it is what makes a dimension string on it measurable. Every other plate
  # is a photograph and stays perspective. 1.48.0's bug was four of six
  # parallel, not the concept.
  #
  # The key is :parallel and it appears on ONE plate. rbtest-autoset.py's
  # source gate enforces both halves - the plan is parallel, nothing else is -
  # rather than banning the key, because the rule changed, it did not vanish.
  #
  # WHAT THE OLD NAMES WERE, AND WHY THEY WENT. 1.48.0 made 01-exterior,
  # 02-dimensioned, 03-front, 04-ventilation, 05-plan. 02-dimensioned was
  # named for its ANNOTATIONS rather than its camera, which is part of why a
  # blank one was so confusing (see empty_shown_note); and with the front-on
  # shot promoted to first, "01-exterior" would have named a straight-on
  # product shot. Every id now names a CAMERA, and the annotations follow the
  # camera instead of the other way round.
  #
  # RE-RUNNABILITY, SAID OUT LOUD: the stamp's `plate` key IS these ids, so
  # scenes stamped by 1.48.x carry retired ids and will NOT be matched by this
  # version. They are still matched by TOKEN, so Remove still removes them -
  # and stale_plates below names them in the log rather than erasing a scene
  # Benton may have nudged. The one action that gets the corrected framing is
  # Remove, then Apply.
  #
  #   :az    :door or :vent - which tag the azimuth is read from
  #   :swing degrees added to it; 35 makes a three-quarter out of a head-on
  #   :el    elevation in degrees. 7 is standing eye height at the standoff
  #          below (a 66 in eye, a booth centre ~42 in up, ~16 ft back);
  #          40 is the "15-20 ft high" shot at the same standoff; 90 is
  #          straight down.
  #   :inside the camera goes INSIDE the booth (07-interior only)
  #
  # 06-PLAN IS 90, NOT 89. 1.48.0 shipped the plan at 89 and Benton's first
  # run came back "it's not even a top view". 89 was there to dodge a
  # degenerate up vector at straight down; it is not needed, because
  # WR_ProposalScenes.aim already swaps up to +Y at |el| >= 88 (observed, its
  # own source). At exactly 90 the azimuth stops mattering and the top-down
  # always lands +Y up, which is orientation-stable rather than accidental.
  #
  # '07-interior' is named so it still matches proposal-package.rb's
  # INTERIOR_RE (/interior|inside|in-booth|booth\s+in/i), which is what selects
  # the interior exposure value for a render row. Renaming it past that regex
  # would silently mis-expose it.
  PLATES = [
    { :id => '01-front',       :az => :door, :swing => 0.0,  :el => 7.0,
      :aim_at => :door,
      :on => true,  :what => 'Front on, square to the door FRAME' },
    { :id => '02-angled',      :az => :door, :swing => 35.0, :el => 7.0,
      :on => true,  :dual => true,
      :what => 'Angled, same height - cover hero (image + render)' },
    { :id => '03-high',        :az => :door, :swing => 35.0, :el => 40.0,
      :on => true,  :what => 'High angled (15-20 ft up) - always an image' },
    { :id => '04-side',        :az => :door, :swing => 90.0, :el => 7.0,
      :on => true,  :what => 'Side view' },
    { :id => '05-ventilation', :az => :vent, :swing => 25.0, :el => 10.0,
      :on => true,  :what => 'Rear view & ventilation' },
    { :id => '06-plan',        :az => :door, :swing => 0.0,  :el => 90.0,
      :parallel => true,
      :on => true,  :what => 'Top-down, dimensions (the ONE parallel plate)' },
    { :id => '07-interior',    :az => :door, :swing => 0.0,  :el => 0.0,
      :on => false, :inside => true, :render => :always,
      :what => 'Interior (off by default, ALWAYS a render)' }
  ].freeze

  # SIDE IS ON BY DEFAULT EVEN THOUGH HE SAID "sometimes". Turning a plate off
  # is one tick in the popover before Apply; a plate he wanted and did not get
  # costs a second run and a re-review. Interior stays the one opt-in plate,
  # because it is the only one whose camera is inside the booth.

  # THE STANDOFF. "step out like 15 ft or so" is the intent, not a constant:
  # a 96168 at 15 ft does not fit in a 35-degree frame, and a plate whose
  # subject is cropped is worse than one shot from 26 ft. So it scales with
  # the booth's own radius and lands at ~16 ft for a 4872 (radius ~60 in) and
  # ~26 ft for a 96168 (~106 in). 1.48.0 used WR_ProposalScenes.aim's own
  # radius * 3.2 + 60, which put a 4872 at 21 ft.
  STANDOFF_K = 2.6
  STANDOFF_C = 36.0

  # ------------------------------------------------- inside the booth --
  #
  # THE BOOTH WALL IS 1 INCH PER SIDE, and that is read off the catalogue
  # rather than guessed. Every model's EXTERIOR is its model number plus two
  # inches: 4872 -> 4'2" x 6'2" = 50 x 74, 96120 -> 8'2" x 10'2" = 98 x 122,
  # 96168 -> 8'2" x 14'2" = 98 x 170 (reference/booth-models.md, itself a copy
  # of models.json). The model number IS the interior. So the interior face
  # sits 1 in inboard of the shell a bounding box reports.
  BOOTH_WALL_T = 1.0

  # HOW FAR CLEAR OF THAT INTERIOR FACE THE INTERIOR EYE STANDS. Benton, 10
  # Sep 2026, having run the 1.50.0 plates for real: "The interior one was
  # slightly off though. It was almost perfect, but it needed to move like 2"
  # more inside the booth. It was kinda stuck in the wall."
  #
  # It is a FIXED clearance off the interior face and deliberately NOT a
  # fraction of anything. The old rule put the eye at radius * 0.55, and the
  # radius is the 3D diagonal, so it mixed width, depth and height and landed
  # somewhere different in every booth size: on a 4872 that is 2.2 in off the
  # interior face (inside a 70-degree camera's near plane, which is why the
  # panel vanished and the eye read as stuck in it), and on a 96168 it is 26 in
  # off the door wall - a different shot entirely. At 4 in the face is clear of
  # the near plane on every model, and the shot means the same thing whatever
  # booth it is pointed at.
  # TWO CORRECTIONS, BOTH BENTON'S, BOTH ABSOLUTE DISTANCES. 10 Sep 2026,
  # first: "it needed to move like 2\" more inside the booth. It was kinda
  # stuck in the wall" — which took this from the old radius * 0.55 (2.2 in
  # off the interior face on a 4872) to 4 in. Then, after seeing that: "Interior
  # needs to go towards the center of the booth like 18\" now or so" — a
  # FURTHER ~18 in inboard, so 4 + 18 = 22.
  #
  # IT STAYS FIXED RATHER THAN BECOMING PROPORTIONAL, and that is the call the
  # third correction turns on. Both of his corrections are absolute distances,
  # because what he is describing is where a PERSON stands — a couple of feet
  # inside the door, looking across the room. That reads the same in a 4872 and
  # a 96192. A proportional rule has already failed here once: radius * 0.55
  # was a fraction of the 3D DIAGONAL, so it mixed width, depth and height and
  # stood 2 in off the face in one booth and 26 in off it in another. Going
  # proportional again at 22 in would reintroduce exactly that.
  #
  # THE SMALL-BOOTH CASE IS REAL AND IS CLAMPED, NOT IGNORED. A 4230 is 32 in
  # deep, so "23 in inside the door" is past its far wall. interior_eye_dist
  # never lets the eye cross the booth centre; on the smallest booths it simply
  # lands at the centre, which is where a person in a 2'8" booth is standing
  # anyway.
  INTERIOR_EYE_CLEAR = 22.0

  # The interior lens. Wide on purpose — see aim_interior: at PLATE_FOV (35)
  # a camera 4 in off the interior face of a 4872 sees one panel and nothing
  # else. Named rather than inline so a check can pin it.
  INTERIOR_FOV = 70.0

  # How far the booth's own shell reaches from its centre along `az`: the exit
  # distance of a ray from the centre through an axis-aligned box of
  # half-extents hx, hy. Not simply "half a side", because the door azimuth is
  # read off a tag and is rarely exactly on an axis.
  def self.reach(hx, hy, az_deg)
    a  = az_deg.to_f * DEG
    cx = Math.cos(a).abs
    cy = Math.sin(a).abs
    ts = []
    ts << (hx.to_f / cx) if cx > 1.0e-9
    ts << (hy.to_f / cy) if cy > 1.0e-9
    ts.empty? ? 0.0 : ts.min
  end

  # Where the interior eye stands, as a distance from the booth centre along
  # the door azimuth. `half` is [hx, hy] off the booth's own bounds; nil means
  # the caller handed us no bounds, and the only thing left is the pre-1.50.2
  # proportional guess - apply always passes them, so that path is a
  # fallback and not a design.
  #
  # `frame_run` (1.55.0) is the door FRAME's own distance from the centre along
  # `az`, from door_run below, or nil. When it is known it names the door wall
  # plane and `half` is not consulted: `half` is the booth's UNION box, and the
  # union is skewed by anything that sticks out -- a leaf drawn open pushes it
  # past the door wall by the leaf's width, so "22 in inside the union edge" is
  # 22 in inside the LEAF, which can be outside the booth. Live, 11 Sep 2026:
  # the verify fixture's 38 in leaf put the eye 15 in outside its shell. The
  # same union skew is what 1.54.0 took out of the wall bearing. The frame is
  # in the wall by definition (it is what 01-front aims at), so it is the plane.
  def self.interior_eye_dist(half, radius, az, frame_run = nil)
    r = nil
    r = frame_run.to_f if !frame_run.nil? && frame_run.to_f > 0.0
    r = reach(half[0], half[1], az) if r.nil? && !half.nil?
    return radius.to_f * 0.55 if r.nil?
    d = r - BOOTH_WALL_T - INTERIOR_EYE_CLEAR
    # Never past the booth centre — see INTERIOR_EYE_CLEAR. Clamping at 0 puts
    # the eye ON the centre, which still looks across the booth because the
    # target sits on the far side of it.
    d > 0.0 ? d : 0.0
  end

  # How far the door frame sits from the booth centre ALONG the door azimuth:
  # the component of (anchor - centre) on the unit vector at `az`. `anchor` is
  # tag_anchor's frame centre in model space, or nil; nil in, nil out, and
  # interior_eye_dist falls back to the union box. Only the run along the
  # normal is used, so an off-centre door (the fixture's is 24 in off) does
  # not tilt anything -- the eye still stands on the centre line.
  def self.door_run(centre_a, anchor, az)
    return nil if anchor.nil? || centre_a.nil?
    a = az.to_f * DEG
    ((anchor[0].to_f - centre_a[0].to_f) * Math.cos(a)) +
      ((anchor[1].to_f - centre_a[1].to_f) * Math.sin(a))
  rescue StandardError
    nil
  end

  # 35 degrees is SketchUp's own default lens and a longer one than aim's 40:
  # less barrel on a product shot, and it is what Benton's hand-framed views
  # already are.
  PLATE_FOV = 35.0

  def self.standoff(radius)
    (radius.to_f * STANDOFF_K) + STANDOFF_C
  end

  # THE STANDOFF IS A GROUND RUN, NOT A SLANT RANGE, and that is the whole
  # reason the high plate works. Benton wants the angled shot and the high one
  # "around this same angle" - same place on the floor, camera lifted 15-20 ft.
  # If standoff were the slant range, raising the elevation would walk the
  # camera IN toward the booth instead of up, and the "high" shot would end up
  # 9 ft off the ground and 9 ft away. So divide by cos(el).
  #
  # At or past 80 degrees there is no meaningful ground run left (and cos(90)
  # is zero), so overhead the standoff is read as a HEIGHT above the booth
  # centre instead - which for a 4872 is ~16 ft up, ~12 ft clear of the roof.
  def self.plate_dist(el, radius)
    base = standoff(radius)
    e = el.to_f.abs
    return base if e >= 80.0
    base / Math.cos(e * DEG)
  end

  # Plates that hide NO walls. 06-plan: walls do not occlude from directly
  # above and the plan's job is to show the booth IN the room. 07-interior:
  # the occluders there are the booth's own panels, which are not wall units -
  # said out loud in the log rather than silently doing nothing.
  #
  # 05-ventilation is deliberately NOT here: Benton, "a back view to show
  # ventilation (this usually requires a hidden wall)". That IS the camera
  # cone rule, and it only fires if the plate's camera actually landed on the
  # page - which until 1.49.1 it did not (see apply).
  NO_WALL_PLATES = %w[06-plan 07-interior].freeze

  # RENDERS ARE A KNOB, NOT A CONSTANT. Default 2 (Benton, 10 Sep 2026);
  # 0-6 from the popover. Assigned down this fixed ladder, everything below
  # the line is IMAGE.
  #
  # THREE PLATES ARE NOT ON THE LADDER AT ALL.
  #
  #   03-high  "This is image", flatly.
  #   06-plan  the other dimension-carrying plate. A plate whose job is to
  #            carry a dimension string does not need photoreal materials, and
  #            the render lane is the expensive one.
  #   07-interior  the opposite case: it is a FORCED render (:render =>
  #            :always) and does not need the ladder's permission. Benton, 10
  #            Sep 2026: "fyi interior plate should always be a render."
  #
  # 02-angled CAME OFF THE LADDER AT 1.53.0 and that is not a demotion. It is
  # now a DUAL plate: its image half must stay an image, and its render half
  # ('02-angled r') is a forced render. Leaving the base id on the ladder would
  # have let the knob promote the IMAGE half and give Benton two renders and no
  # image, which is the opposite of what he asked for.
  #
  # 01-front is last ON the ladder for the dimensioned-plate reason above.
  RENDER_LADDER = %w[05-ventilation 04-side 01-front].freeze

  # ONE, NOT TWO, AND THAT IS A COST DECISION SAID OUT LOUD. Until 1.53.0 a
  # default run was 2 renders: 02-angled and 05-ventilation. The angled render
  # is now FORCED, so a knob of 2 would have made every default run 3 renders
  # -- 50% more of the expensive half, which Benton did not ask for. At 1 the
  # default is still exactly 2 renders (the forced angled + one off the
  # ladder), and what he gained is the angled IMAGE row he did ask for.
  DEFAULT_RENDERS = 1
  MAX_RENDERS = 6

  # ------------------------------------------------- forced renders --
  #
  # A plate carrying `:render => :always` is a render WHENEVER IT IS
  # PRODUCED, at any setting of the knob, zero included. Benton, 10 Sep 2026:
  # "fyi interior plate should always be a render."
  #
  # FORCED RENDERS ARE ADDITIVE AND SIT OUTSIDE THE LADDER. They do not
  # consume a slot from the render count, because the count is the answer to
  # "how many of the ordinary plates do you want rendered" and silently
  # demoting the angled hero because the interior box got ticked is precisely
  # the surprise this design has to avoid. Set the knob to 2 and tick the
  # interior and you get THREE renders — and the Apply summary says so, broken
  # out, rather than reporting a number that no longer means what it says.
  #
  # COST LIVES HERE, SO KEEP IT VISIBLE. Renders are the expensive half of
  # Benton's workflow. Forcing one on a plate that is OFF by default (this is
  # the only one) costs nothing until he asks for that plate. Forcing one on
  # an always-on plate would raise the floor of every single run, and that is
  # a different kind of decision — `rbtest-autoset.py`'s `fr6` fails if a
  # forced render ever appears on an `:on => true` plate, so making that
  # change means editing a check that says out loud what it costs.
  def self.forced_renders(ids)
    (ids || []).select do |id|
      next true if dual_render?(id)
      pl = plate(id)
      pl && pl[:render] == :always
    end
  end

  # ------------------------------------------- the dual image/render pair --
  #
  # Benton, 10 Sep 2026: "I also always want a regular image at angled, and a
  # render at angled. Should be the same scene, except with the render
  # setting."
  #
  # ONE SketchUp SCENE IS ONE GRID ROW WITH ONE MODE, so "the same scene with
  # two settings" has to be TWO PAGES SHARING A CAMERA. The machinery for that
  # turns out to be almost nothing: a dual plate emits a SECOND plate id that
  # is the first plus DUAL_SUFFIX, and `plate` resolves that id back to the
  # SAME row. Everything downstream then falls out for free --
  #
  #   camera      both ids read the same :az/:swing/:el, so they are aimed
  #               identically without anything special being written
  #   walls       wall_picks is keyed on the plate row, so both get the same
  #   annotations annot_picks likewise. They are the same shot; a difference
  #               between the two would be a defect.
  #   stamp       the plate key stays UNIQUE PER PAGE ('02-angled' and
  #               '02-angled r'), which is what identity needs
  #   remove      already matches on TOKEN, not plate, so it takes both halves
  #               and cannot leave an orphan
  #   re-run      page_for_plate matches each half on its own stamp, so
  #               neither half is recreated or duplicated
  #
  # THE SUFFIX IS ' r' TO MATCH THE FILENAME MARKER. The scene names come out
  # "MDL 4872 E 02-angled" and "MDL 4872 E 02-angled r" -- adjacent in the tab
  # bar, obvious which is which. proposal-package.rb's plan_names appends its
  # render mark only when the name does not already end in it, so the file is
  # "..._02-angled r.png" and not "..._02-angled r r.png".
  #
  # IF BENTON RE-FRAMES ONE OF THE TWO BY HAND, THEY DIVERGE AND STAY
  # DIVERGED. That is deliberate: auto-set does not re-aim a scene without the
  # box ticked, because framing is his call. A re-run will NOT silently
  # re-sync them. Ticking re-aim re-aims BOTH back to the computed camera,
  # which is the way to put them back together.
  DUAL_SUFFIX = ' r'.freeze

  def self.dual_render?(id)
    s = id.to_s
    return false unless s.end_with?(DUAL_SUFFIX)
    base = s[0...-DUAL_SUFFIX.length]
    pl = PLATES.find { |p| p[:id] == base }
    !pl.nil? && pl[:dual] ? true : false
  end

  def self.dual_render_id(id)
    "#{id}#{DUAL_SUFFIX}"
  end

  # STILL TO DO, NAMED RATHER THAN HALF-DONE (10 Sep 2026). Benton takes the
  # front-on and the angled shot TWICE - "I usually grab one that is an image
  # from this view, as well as a render" - one image carrying dimensions and
  # one clean render from the SAME camera. This table cannot say that: one
  # row is one page, and the stamp's `plate` key is unique per page. The shape
  # it wants is a :dual flag that emits two ids from one row ('01-front' and
  # '01-front-render'), aimed once and stamped twice, with the render one on
  # the ladder and the image one carrying the allowlist. That is a change to
  # the plate table, the stamp, the scene names, the ladder and the review
  # grid, so it is a separate piece of work and not this one.

  # ------------------------------------------------- the annotation rule --

  # DIMENSIONS ARE SHOWN ON EVERY PLATE (1.51.0). Benton, 10 Sep 2026, having
  # run the new plates: "Also please dont hide any of the dimensions on the
  # auto set. I dont like the way thats working right now. Will otpimize
  # later." That is an explicit, deliberate step back from the per-plate
  # dimension policy 1.50.0 shipped, and it is HIS call on a client-facing
  # default. **Do not "restore" the old behaviour thinking this was a
  # regression** — he intends to refine it himself.
  #
  # Any tag whose name is in the WR-Dims family is shown, on every plate.
  DIMS_RE = /\AWR-Dims(\z|-)/.freeze

  # NEVER shown by auto-set, on any plate, ever.
  #
  #   WR-Notes   the house-default ceiling banner — the literal D5 string
  #              ("Ceiling 8'-0\" - HOUSE DEFAULT, not measured. Confirm before
  #              quoting.") that went out on a client image on 30 Aug 2026.
  #
  # THIS GATE IS UNTOUCHED AND MUST STAY. Benton said *dimensions*, and a
  # construction note is not a dimension. Client-safe annotation mode was
  # removed at 1.47.0, so there is no second net behind this list.
  #
  # WR-Dims-Booth AND WR-Dims-Selection WERE ON THIS LIST UNTIL 1.51.0 and are
  # deliberately no longer. They were never here for safety — they were here
  # for legibility, because "a booth carrying both sets shows two different
  # footprints with nothing on the page to say which is which"
  # (proposal-scenes.rb, where that reasoning still lives and still governs
  # THAT tool). They are dimensions, Benton asked to see the dimensions, and
  # a legibility preference is exactly the kind of thing he is entitled to
  # overrule. The D5 gate did not weaken: it still refuses the one tag it was
  # built to refuse, and effective_shown still subtracts it last.
  NEVER_SHOWN = %w[WR-Notes].freeze

  # THE ALLOWLIST. A plate shows these family tags AND NOTHING ELSE — every
  # other family tag and every loose Untagged callout is hidden. A name here
  # that the model does not carry is simply not shown (opt-in by existence),
  # so a shop that has never made a WR-Notes-Vent set gets a clean plate 4.
  # WHAT THIS LIST IS FOR NOW. Since 1.51.0 every WR-Dims tag is shown on every
  # plate and does not need naming here, so what is left is the NOTE sets —
  # the WR-Notes-* annotation sets Benton makes by hand in
  # wr-scene-annotations.rb. Those are still strictly opt-in per plate, which
  # is the half of the allowlist that is still carrying weight: a note is text
  # of unknown content, and an unknown note on a customer image is the defect
  # this whole mechanism exists for.
  SHOWN_BY_PLATE = {
    '01-front'       => [],
    '02-angled'      => [],
    '03-high'        => [],
    '04-side'        => [],
    '05-ventilation' => %w[WR-Notes-Vent],
    '06-plan'        => %w[WR-Notes-Plan],
    '07-interior'    => []
  }.freeze

  # The family tags this plate may show, given the tags the model actually
  # carries. The NEVER_SHOWN subtraction is the second gate: it is what stops
  # a later edit to SHOWN_BY_PLATE putting WR-Notes back on a plate.
  # The family tags this plate may show, given the tags the model actually
  # carries: the note sets it names by hand, PLUS every dimension tag that
  # exists (1.51.0 — Benton's call, see NEVER_SHOWN). The NEVER_SHOWN
  # subtraction is still last and still the final word, so the D5 banner
  # cannot re-enter through either half.
  def self.effective_shown(plate_id, present)
    names = present.map { |n| n.to_s }
    allow = (SHOWN_BY_PLATE[plate_id.to_s] || [])
    ((allow & names) | names.grep(DIMS_RE)) - NEVER_SHOWN
  end

  # The full picks hash for one plate, in the picker's own polarity:
  # TICKED = HIDDEN. EVERY row is keyed, true or false — never a partial hash —
  # so a set shown on the previous plate cannot ride along into this one.
  #
  #   sets  [{ 'key' => 't:WR-Dims', 'name' => 'WR-Dims' }, ...]
  #   loose [{ 'key' => 'e:1234', 'kind' => 'text' | 'dim' }, ...]
  #
  # A LOOSE ROW IS JUDGED BY ITS KIND, AND THAT DISTINCTION IS REAL, NOT
  # INFERRED FROM A NAME. wr-scene-annotations.rb's item_hash already
  # classifies every annotation entity it finds: 'dim' for Sketchup
  # ::DimensionLinear / ::DimensionRadial, 'text' for Sketchup::Text. So:
  #
  #   a loose DIMENSION  is SHOWN  — it is a dimension, which is the thing
  #                                  Benton asked to stop hiding
  #   a loose TEXT       is HIDDEN — its content is unknown to every tool, it
  #                                  lands on Untagged, and SketchUp REFUSES
  #                                  to hide the Untagged tag. This is the
  #                                  case the allowlist was built for and it
  #                                  is not relaxed.
  #
  # A row with no kind at all is treated as TEXT and hidden: an unreadable
  # annotation must fail toward the conservative answer.
  def self.annot_picks(plate_id, sets, loose)
    shown = effective_shown(plate_id, (sets || []).map { |s| s['name'] })
    picks = {}
    (sets || []).each { |s| picks[s['key']] = !shown.include?(s['name'].to_s) }
    (loose || []).each { |it| picks[it['key']] = (it['kind'].to_s != 'dim') }
    picks
  end

  # What the policy IS, in one line, for the run log and the Apply summary.
  # Benton is changing a client-facing default; he should be able to read what
  # he now has without opening this file.
  def self.policy_line
    'POLICY: dimensions are shown on EVERY plate (every WR-Dims tag, plus ' \
      'loose dimension entities). Construction notes and untagged text are ' \
      'still hidden on every plate — WR-Notes never shows, and a WR-Notes-* ' \
      'set shows only on a plate that names it.'
  end

  # ------------------------------------ is there anything ON those tags? --
  #
  # THE ALLOWLIST CANNOT TELL YOU THIS AND NEITHER CAN THE REVIEW COLUMN.
  # Benton's first real run, 10 Sep 2026, on `MDL 4872 E (components)`: the
  # dimensioned plate came out with a clean booth and no annotation on it, and
  # the ANNOTATIONS column for that scene read "dims + doors" - i.e. the
  # allowlist had done exactly its job and WR-Dims / WR-Dims-Doors really were
  # visible on the page. The model simply had nothing drawn on them: a bare
  # booth component, no room, nothing dimensioned.
  #
  # From the column, "the tags are hidden" and "there is nothing on the tags"
  # look identical, and both render as a blank plate. So COUNT, and say so.
  # This does NOT widen the allowlist and must never be made to: that list is
  # the only thing standing between a construction note and a customer's
  # image. The honest fix for a model with no dimensions is to draw the
  # dimensions.

  # How many entities the model carries on each of `tags`. nil for a tag whose
  # walk failed - nil is "could not tell" and never counts as empty.
  def self.tag_counts(model, tags)
    out = {}
    (tags || []).each do |n|
      name = n.to_s
      out[name] = begin
        hits = []
        WR_ProposalScenes.walk(model.entities, name, hits, 0)
        hits.length
      rescue StandardError
        nil
      end
    end
    out
  end

  # The warning line for one plate, or nil when there is nothing to warn
  # about. It fires ONLY when the plate is allowed to show tags and EVERY one
  # of them is empty - a plate showing two sets where one has content is not
  # blank. A nil count (the walk failed) is not empty, so a failed read stays
  # quiet rather than telling Benton his dimensions are missing on no evidence.
  def self.empty_shown_note(shown, counts)
    names = (shown || []).map { |n| n.to_s }
    return nil if names.empty?
    return nil unless names.all? { |n| (counts || {})[n] == 0 }
    "NOTHING IS DRAWN on #{names.join(' + ')} - this plate will be BLANK. " \
      'The tags are shown, not hidden; the model carries no entities on them. ' \
      'Dimension the model first, then re-run AUTO-SET.'
  end

  # The run-level version: which of these plates come out blank, named.
  def self.blank_plates(ids, sets, counts)
    present = (sets || []).map { |s| s['name'] }
    (ids || []).select do |id|
      !empty_shown_note(effective_shown(id, present), counts).nil?
    end
  end

  # ------------------------------------------------- plates that retired --
  #
  # A page stamped by an older version with a plate id this version no longer
  # has. It is OURS (same token), so the containment rule allows touching it -
  # but it is NOT erased, because Benton may have renamed or nudged it. It is
  # NAMED, in the log and in the summary, with the one action that fixes it.
  def self.stale_plates(pages, token)
    live = PLATES.map { |pl| pl[:id] }
    token_pages(pages, token).reject do |pg|
      st = page_stamp(pg)
      st.nil? || live.include?(st['plate'].to_s)
    end
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
  # The ladder's share only — what the KNOB bought. Kept separate from the
  # forced rows so the summary can report the two halves honestly.
  def self.ladder_renders(n, plate_ids)
    want = n.to_i
    want = 0 if want < 0
    want = MAX_RENDERS if want > MAX_RENDERS
    RENDER_LADDER.select { |id| plate_ids.include?(id) }.first(want)
  end

  # Every plate that comes out as a render: the ladder's share plus the forced
  # rows. Ladder first so the order still reads down the ladder.
  def self.renders_for(n, plate_ids)
    (ladder_renders(n, plate_ids) + forced_renders(plate_ids)).uniq
  end

  def self.mode_for(plate_id, render_ids)
    render_ids.include?(plate_id.to_s) ? 'render' : 'image'
  end

  # ------------------------------------------------------------ azimuth --

  # A dual plate's render half resolves to the SAME row as its image half.
  # That is what makes the two identical in camera, walls and annotations
  # without any of those three knowing the pair exists.
  def self.plate(plate_id)
    s = plate_id.to_s
    found = PLATES.find { |p| p[:id] == s }
    return found if found
    return nil unless s.end_with?(DUAL_SUFFIX)
    base = s[0...-DUAL_SUFFIX.length]
    pl = PLATES.find { |p| p[:id] == base }
    (pl && pl[:dual]) ? pl : nil
  end

  # A dual plate contributes TWO ids, adjacent, image first.
  def self.plate_ids(interior = false)
    out = []
    PLATES.each do |p|
      next unless p[:on] || (interior && p[:inside])
      out << p[:id]
      out << dual_render_id(p[:id]) if p[:dual]
    end
    out
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
  # The entities of a booth container, whichever kind it is. A Group has
  # #entities; a ComponentInstance does NOT and raises NoMethodError, and
  # resolve_booth accepts both (it always has). Until 1.51.0 tag_az called
  # booth.entities bare and the rescue turned that raise into a silent -90
  # fallback on every component booth.
  def self.container_entities(booth)
    return booth.entities if booth.respond_to?(:entities)
    return booth.definition.entities if booth.respond_to?(:definition)
    nil
  end

  # WHICH WALL IS THE DOOR IN? Not "what bearing is the door's centre at".
  #
  # THE 1.50.x BUG, AND WHY IT ONLY SHOWED UP ON A BIG BOOTH. This used to
  # return the bearing from the booth's centre to the tagged part's centre. A
  # door is rarely centred along its own wall, and the further off-centre it
  # sits the more that bearing swings away from the wall's normal. On Benton's
  # MDL 96120 S (98 x 122 exterior) a door about 36 in off centre reads -120
  # instead of -90 — a 30-degree error, which is most of 02-angled's 35-degree
  # swing. That is exactly what he saw: "01-front" came out a three-quarter
  # and "02-angled" came out square-on, the two apparently swapped. They were
  # not swapped; both were aimed off a fabricated bearing.
  #
  # It passed every check because verify-autoset.rb's fixture booth has its
  # door centred on its wall, where the error is zero.
  #
  # A booth is a rectangular box and the door is in ONE of its four walls, so
  # the answer is a wall NORMAL, not a bearing to a point: take the offset in
  # booth-local space, normalise each axis by that axis's own half-extent
  # (a 36 in offset means something different across 98 in than across 122),
  # and the dominant one names the wall. Then rotate that axis into model
  # space, because the booth may be turned in the room.
  # THE PURE HALF, so the thing that was wrong is the thing that gets tested.
  # dx/dy is the offset from the booth centre to the tagged part's centre in
  # BOOTH-LOCAL space; hx/hy are the booth's own half-extents. Returns the unit
  # outward normal of the wall the part sits in, as [ux, uy].
  #
  # Normalising by each half-extent before comparing is the whole point: on a
  # 98 x 122 booth a 36 in offset is 0.73 of the way to the short wall but only
  # 0.59 of the way to the long one, and comparing raw inches would pick wrong.
  # WHICH WALL PLANE DOES THIS PART LIE IN? Read off the PART'S OWN SHAPE, not
  # off where it sits in the booth.
  #
  # THE 1.53.0 DEFECT, AND IT IS NOT WHAT IT LOOKED LIKE. The live run reported
  # the door anchor at [96.0, 23.0] and a bearing of 0.0 (+X) for a door in the
  # -Y wall. The frame picker was NOT at fault -- 96.0, 23.0 IS the door
  # frame's centre, exactly. What was wrong is that wall_axis normalised that
  # offset against the booth's UNION bounding box, and the union is skewed by
  # anything that sticks out: the swung leaf reaches y -14 and the vent housing
  # y 86, so the "centre" came out at y 36 when the shell's centre is y 54, and
  # the half-extents came out 48 x 50 for a shell that is 96 x 60. Under that
  # skew the frame scored 0.500 on x against 0.260 on y and the +X wall won.
  #
  # A real booth does the same thing: a door drawn open and a vent housing both
  # push the union past the shell.
  #
  # So stop asking where the part SITS and ask what SHAPE it is. A wall part is
  # long along its wall and thin across it, and the thin axis IS the wall's
  # normal. That needs no booth box at all, so nothing that sticks out can skew
  # it. The booth centre is then used only for the SIGN, which survives a much
  # rougher centre than the old rule did (here dy = -13 against a true -31, and
  # the sign is the same either way).
  #
  # IT REFUSES RATHER THAN GUESSING. A part that is not clearly longer one way
  # than the other is not identifiably in a wall, and this returns nil -- the
  # caller then says ASSUMED out loud. A fabricated bearing that reads
  # plausible is the exact failure that shipped twice tonight; the third time
  # it declines.
  ASPECT_MIN = 2.0

  def self.wall_normal(span_x, span_y, dx, dy)
    sx = span_x.to_f.abs
    sy = span_y.to_f.abs
    # A part with no horizontal extent at all names no wall. Guarded before
    # the ratios, because 0 >= 0 * ASPECT_MIN is TRUE and would have called a
    # degenerate part a Y wall (caught by wn8 while this was written).
    return nil if sx < 1.0e-6 && sy < 1.0e-6
    if sx >= sy * ASPECT_MIN
      # long in x, thin in y -> the wall runs along x, its normal is +/-Y
      [0.0, dy.to_f >= 0 ? 1.0 : -1.0]
    elsif sy >= sx * ASPECT_MIN
      [dx.to_f >= 0 ? 1.0 : -1.0, 0.0]
    end
  end

  # The pre-1.54.0 rule. KEPT ONLY AS THE LAST RESORT, for a tagged part whose
  # shape does not name a wall (a squarish block). It is the rule that failed
  # above, so it is used only when the better one has already declined, and the
  # caller still reports the bearing as READ rather than ASSUMED because it did
  # come off real geometry.
  def self.wall_axis(dx, dy, hx, hy)
    nx = hx.to_f > 1.0e-6 ? (dx.to_f / hx.to_f) : 0.0
    ny = hy.to_f > 1.0e-6 ? (dy.to_f / hy.to_f) : 0.0
    if nx.abs >= ny.abs
      [dx.to_f >= 0 ? 1.0 : -1.0, 0.0]
    else
      [0.0, dy.to_f >= 0 ? 1.0 : -1.0]
    end
  end

  # THE FRAME, NOT THE LEAF. Benton, 10 Sep 2026, after 1.51.0: "Front should
  # find the door frame really, rather than the door. It should be in front of
  # the door frame."
  #
  # The booth data distinguishes a DRFRM slot -- the frame, fixed in the wall
  # -- from the door leaf. A leaf can be drawn swung OPEN, and then its
  # geometry sits well away from the wall plane; union the two into one
  # bounding box and the centroid is somewhere in mid-air, so even the
  # wall-normal rule of 1.51.0 normalises against an offset that never came
  # from the wall. That is why the front plate was still not square.
  #
  # THIS DOES NOT TOUCH kind_of. wr-overlays.rb's kind_of returns :door for
  # both frame and leaf and has three callers (wr-overlays.rb:445, :849 for the
  # step, and this bearing). The step placement depends on finding "the door"
  # in that loose sense and works today, so nothing is repointed: the frame is
  # picked HERE, out of the parts already tagged WR-Booth-Door, and every
  # existing caller keeps the behaviour it has.
  #
  # HOW THE FRAME IS PICKED, without depending on a naming convention that
  # differs between builders (build-booth-components.rb names a DRFRM slot
  # "Right46Door"; booth-4260-s.rb tags by :sk instead):
  #
  #   1. If any tagged part's name says frame (/FRM|FRAME/i), use those.
  #   2. Otherwise use the part CLOSEST TO THE SHELL PLANE. Normalise each
  #      offset by its own half-extent, so 1.0 means "exactly at the shell",
  #      and score 1 - |n - 1|. A frame is IN the wall plane and scores ~1. A
  #      leaf swung inward sits short of it; a leaf swung outward sits past it;
  #      both are penalised, and symmetrically, which "largest offset wins"
  #      was not -- that rule picked a leaf swung out beyond the booth's own
  #      footprint, which is what the fm2 check caught while this was written.
  #      Geometric, so it holds whatever the parts are called.
  def self.frame_hits(hits, own)
    named = hits.select { |e| (e.name.to_s rescue '') =~ /FRM|FRAME/i }
    return named unless named.empty?
    hx = (own.max.x - own.min.x).to_f / 2.0
    hy = (own.max.y - own.min.y).to_f / 2.0
    best = nil
    best_n = -1.0
    hits.each do |e|
      c = e.bounds.center
      nx = hx > 1.0e-6 ? ((c.x - own.center.x).to_f / hx).abs : 0.0
      ny = hy > 1.0e-6 ? ((c.y - own.center.y).to_f / hy).abs : 0.0
      n = nx > ny ? nx : ny
      score = 1.0 - (n - 1.0).abs
      if score > best_n
        best_n = score
        best = e
      end
    end
    best ? [best] : []
  end

  # [centre, axis] for the tagged opening, in MODEL space: the frame's own
  # centre point, and the unit outward normal of the wall it sits in. nil when
  # there is nothing usable, and the caller says ASSUMED out loud.
  def self.tag_anchor(booth, tag_name)
    ents = container_entities(booth)
    return nil if ents.nil?
    hits = []
    WR_ProposalScenes.walk(ents, tag_name, hits, 0)
    return nil if hits.empty?
    own = Geom::BoundingBox.new
    ents.each { |e| own.add(e.bounds) }
    picked = frame_hits(hits, own)
    return nil if picked.empty?
    tb = Geom::BoundingBox.new
    picked.each { |e| tb.add(e.bounds) }
    hx = (own.max.x - own.min.x).to_f / 2.0
    hy = (own.max.y - own.min.y).to_f / 2.0
    dx = (tb.center.x - own.center.x).to_f
    dy = (tb.center.y - own.center.y).to_f
    return nil if Math.sqrt((dx * dx) + (dy * dy)) < 1.0
    # The FRAME'S OWN footprint names the wall plane; the offset only signs it.
    ax = wall_normal((tb.max.x - tb.min.x), (tb.max.y - tb.min.y), dx, dy)
    ax = wall_axis(dx, dy, hx, hy) if ax.nil?
    ux, uy = ax
    v = Geom::Vector3d.new(ux, uy, 0).transform(booth.transformation)
    return nil if v.length < 1.0e-6
    # The frame's centre in model space, at the BOOTH centre's height: the eye
    # height is the plate's business (:el), not the frame's.
    fc = tb.center.transform(booth.transformation)
    [[fc.x.to_f, fc.y.to_f, own.center.transform(booth.transformation).z.to_f],
     Math.atan2(v.y, v.x) / DEG]
  rescue StandardError
    nil
  end

  def self.tag_az(booth, tag_name)
    a = tag_anchor(booth, tag_name)
    a && a[1]
  end

  # THE FALLBACK STOPS BEING SILENT (1.51.0). A fabricated -90 bearing is what
  # let the wrong front shot ship, and it was invisible because every downstream
  # check asks "is the camera square to the bearing we computed" rather than
  # "did we compute one". Every run now says, by name, whether each side was
  # READ or ASSUMED, and how many tagged parts it read it from.
  def self.tag_az_line(booth, tag_name, label, az)
    n = begin
      ents = container_entities(booth)
      hits = []
      WR_ProposalScenes.walk(ents, tag_name, hits, 0) if ents
      hits.length
    rescue StandardError
      0
    end
    if az.nil?
      "         #{label}: ASSUMED — no usable #{tag_name} on this booth " \
        "(#{n} tagged part(s) found). Every plate aimed off it is a guess."
    else
      format('         %s: READ %.1f deg from %d %s part(s).',
             label, az, n, tag_name)
    end
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
    # The loose rows carry their KIND now (1.51.0): annot_picks shows a loose
    # dimension and hides loose text, and it cannot tell them apart without it.
    [inv[:sets].map { |s| { 'key' => s[:key], 'name' => s[:name] } },
     inv[:loose].map { |it| { 'key' => it[:key], 'kind' => it[:kind].to_s } }]
  end

  # ---------------------------------------------------------- the camera --

  # `half` is [hx, hy] off the booth's own bounding box. Only the interior
  # plate uses it - every exterior plate stands outside the booth, where the
  # standoff is what frames the shot - but it is threaded through here rather
  # than fetched inside, because aim_plate is the one place that already knows
  # which booth it is aiming at.
  # `anchor` is the door frame's own centre in model space, or nil. Only the
  # plate carrying :aim_at => :door uses it — Benton, 10 Sep 2026: "It should
  # be in front of the door frame." On a long wall with an off-centre door,
  # targeting the BOOTH centre leaves the door off to one side of the frame;
  # targeting the frame centres the thing the shot is of. Every other plate
  # frames the whole booth and still looks at its centre.
  def self.aim_plate(view, plate_id, centre_a, radius, door_az, vent_az, half = nil,
                     anchor = nil)
    p = plate(plate_id)
    look = (p[:aim_at] == :door && anchor) ? anchor : centre_a
    c = Geom::Point3d.new(look[0], look[1], look[2])
    return aim_interior(view, c, radius, (door_az || FALLBACK_AZ), half, anchor) if p[:inside]
    # Perspective everywhere except the one plate that carries :parallel (see
    # PLATES). dist and fov are auto-set's own; aim's own defaults are the
    # legacy tool's and are left alone.
    WR_ProposalScenes.aim(view, c, radius, az_for(plate_id, door_az, vent_az),
                          p[:el], !p[:parallel], plate_dist(p[:el], radius), PLATE_FOV)
  end

  # Inside the booth, looking back across it.
  #
  # ------------------------------------------------------------------------
  # THIS IS A TWO-POINT PERSPECTIVE, AND IT IS DELIBERATE. DO NOT "TIDY" IT.
  # ------------------------------------------------------------------------
  # Benton, 10 Sep 2026, on the 1.51.0 plates: "I like the interior camera
  # angle. Its a good feature honestly." He noticed it reads as locked
  # two-point perspective. Three lines below produce that, and each one is
  # load-bearing:
  #
  #   1. `dir` has a ZERO Z COMPONENT. The camera looks dead level, so no
  #      vertical in the booth is foreshortened.
  #   2. The up vector is WORLD VERTICAL (0, 0, 1), not the camera's own up.
  #   3. The camera is PERSPECTIVE.
  #
  # A perspective camera whose view direction is perpendicular to the vertical
  # axis leaves real verticals PARALLEL on screen instead of converging to a
  # third vanishing point — which is exactly the geometry SketchUp's own
  # Two-Point Perspective mode imposes, arrived at here by aiming level rather
  # than by setting a mode. Give this plate a non-zero :el, or tip the up
  # vector, and the verticals start converging and the look is gone.
  #
  # The 70-degree fov is the other half of it: a 35 inside a 4 ft booth sees
  # one panel. `rbtest-autoset.py` pins all four of these by name (in6-in10)
  # precisely because nothing about the three lines LOOKS important.
  #
  # The eye's distance along `dir` is a taste call and IS adjustable — that is
  # what interior_eye_dist and INTERIOR_EYE_CLEAR are. Moving the eye in or
  # out along a level direction does not tilt it, so the clearance fix of
  # 1.51.0 left the two-point look untouched.
  #
  # `anchor` is the door frame's centre in model space (tag_anchor), or nil.
  # It names the door wall plane the eye stands 22 in inside of; without it
  # the union box does, and the union is skewed by an open leaf -- see
  # interior_eye_dist.
  def self.aim_interior(view, centre, radius, az, half = nil, anchor = nil)
    a   = az * DEG
    dir = Geom::Vector3d.new(Math.cos(a), Math.sin(a), 0)
    run = door_run(centre.to_a, anchor, az)
    eye = centre.offset(dir, interior_eye_dist(half, radius, az, run))
    # The target only sets the orbit pivot: eye and target sit on the same
    # horizontal line through the centre, so the view DIRECTION is -dir
    # whatever this distance is. Moving the eye did not move the shot's aim.
    tgt = centre.offset(dir, -radius * 0.45)
    cam = view.camera
    # PROJECTION FIRST, POSITION LAST (1.55.0). Flipping a PARALLEL camera to
    # perspective makes SketchUp keep the target and re-derive the eye so the
    # parallel frame height still fills the lens: with 06-plan's height
    # (radius * 2.3) and the 35-degree lens it inherits, that is
    # 186.4 / (2 tan 17.5) = 295.6 in back from the target -- which is where
    # the live harness found this eye on 1.53.0 AND 1.54.0 (x 331.1, then
    # y -223.12, same 295.59 in both), 223 in outside the booth. 06-plan is
    # the plate aimed immediately before this one and it leaves the view
    # parallel. Setting the projection before the position means set() is the
    # last word on where the eye is, whatever the view was doing before.
    cam.perspective = true
    cam.fov = INTERIOR_FOV
    cam.set(eye, tgt, Geom::Vector3d.new(0, 0, 1))
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

    centre, radius, bbox = booth_frame(booth)
    # [hx, hy] for the interior eye. Taken off min/max rather than through
    # BoundingBox#width / #height / #depth, because in SketchUp #height is the
    # Y extent and #depth is Z -- a naming trap that would have handed the
    # interior camera the booth's HEIGHT as its plan half-depth, silently.
    half = begin
      [(bbox.max.x - bbox.min.x).to_f / 2.0, (bbox.max.y - bbox.min.y).to_f / 2.0]
    rescue StandardError
      nil
    end
    danchor = tag_anchor(booth, 'WR-Booth-Door')
    door    = danchor && danchor[1]
    dpoint  = danchor && danchor[0]
    vent    = tag_az(booth, 'WR-Booth-Vent')

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
    # Counted once for the whole run, over every tag any plate is allowed to
    # show. Cheap, and it is what turns a silently blank plate into a sentence.
    counts      = tag_counts(model, SHOWN_BY_PLATE.values.flatten.uniq - NEVER_SHOWN)
    stale       = stale_plates(pages.to_a, token)

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

    lines << policy_line
    lines << tag_az_line(booth, 'WR-Booth-Door', 'door side', door)
    lines << tag_az_line(booth, 'WR-Booth-Vent', 'vent side', vent)
    model.start_operation('AUTO-SET proposal scenes', true)
    begin
      booth.set_attribute(DICT, 'token', token)
      booth.set_attribute(DICT, 'label', label)

      ids.each do |id|
        page  = page_for_plate(pages.to_a, token, id)
        want  = scene_name(label, id)
        fresh = page.nil?

        if fresh
          # Aimed BEFORE the add as well as after it, so the page is born with
          # the right camera even on a build where PAGE_USE_CAMERA is not
          # defined and the explicit save below cannot run.
          aim_plate(view, id, centre, radius, door, vent, half, dpoint)
          page = pages.add(want)
          lines << "created  #{want}"
        elsif reaim
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

        # THE CAMERA HAS TO BE SAVED ONTO THE PAGE EXPLICITLY, AND ON THE
        # FRESH PATH TOO (1.48.2). Until now only the re-aim branch did this;
        # a newly created page was left to whatever `pages.add` captured, and
        # Benton's first real run came back with all five plates wearing one
        # camera — the viewport's — so 03-front was a three-quarter and
        # 05-plan an oblique. The order here is the fix: SELECT the page
        # first (selecting a page restores its camera, so aiming before that
        # can be undone by it), aim, refresh so the view has actually taken
        # it — proposal-scenes.rb has always called view.refresh between the
        # aim and the add, and auto-set dropped it — and then commit the
        # camera with page.update(PAGE_USE_CAMERA). write_scene below calls
        # page.update with the HIDDEN-state mask only (WR_SceneWalls
        # .update_mask = hidden objects | hidden geometry), so it will not do
        # this for us.
        #
        # It also has to happen before page_eye: the wall cone is computed
        # from the page's OWN saved camera, so a plate whose camera never
        # landed was also hiding the wrong walls.
        if fresh || reaim
          aim_plate(view, id, centre, radius, door, vent, half, dpoint)
          view.refresh
          page.update(PAGE_USE_CAMERA) if defined?(PAGE_USE_CAMERA)
        end

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

        lines.concat(plate_log(id, units, centre, eye, sets, loose, counts))
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
    # THE COUNT STAYS TRUTHFUL WITH A FORCED ROW IN IT. `renders` already
    # includes them, so the totals are right either way — but a bare "3
    # render" when the knob says 2 reads like a bug, so the two halves are
    # named.
    forced = forced_renders(ids)
    rsplit = forced.empty? ? '' :
             " (#{renders.size - forced.size} from the render count + " \
             "#{forced.size} always-render: #{forced.join(', ')})"
    msg = "AUTO-SET #{label}: #{n_new} scene(s) created, #{ents.size - n_new} updated, " \
          "#{renders.size} render#{rsplit} / #{ents.size - renders.size} image. " \
          'Read the WALLS and ANNOTATIONS columns before you export. ' + policy_line
    if door.nil?
      msg += ' WARNING: no usable WR-Booth-Door on this booth, so the door side ' \
             'was ASSUMED (-90). The front, angled, high, side and top-down plates ' \
             'are all aimed off that guess - check them before you export.'
    end
    blank = blank_plates(ids, sets, counts)
    unless blank.empty?
      msg += " NOTE: #{blank.join(', ')} will be BLANK - nothing is drawn on the " \
             'annotation tags those plates show. The tags are shown, not hidden. ' \
             'Dimension the model, then re-run.'
    end
    unless stale.empty?
      msg += " NOTE: #{stale.size} scene(s) from an older plate set are still here " \
             "(#{stale.map { |pg| pg.name.to_s }.join(', ')}). They keep their old " \
             'framing. Remove, then Apply, to get the whole corrected set.'
    end
    [true, msg, lines]
  end

  # Every wall this plate hides, with its dot product, and exactly which
  # annotation sets it shows. A wrong call has to be readable, not mysterious.
  def self.plate_log(id, units, centre, eye, sets, loose, counts = {})
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
    n_dim, n_txt = loose_split(loose)
    tail = []
    tail << "#{n_dim} loose dimension(s) shown" if n_dim > 0
    tail << "#{n_txt} loose text callout(s) hidden" if n_txt > 0
    out << "         shows: #{shown.empty? ? 'no annotations at all' : shown.join(' + ')}" \
           "#{tail.empty? ? '' : " — #{tail.join(', ')}"}"
    note = empty_shown_note(shown, counts)
    out << "         #{note}" if note
    out
  end

  # The loose rows split the way the log should report them.
  def self.loose_split(loose)
    dims = (loose || []).select { |it| it['kind'].to_s == 'dim' }
    [dims.size, (loose || []).size - dims.size]
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
    # A LOOSE DIMENSION IS NOT A WARNING. THIS IS WHAT THE ORANGE IS FOR.
    #
    # The cell goes orange to say "untagged TEXT is about to reach a customer
    # image" -- the one thing the annotation allowlist structurally cannot
    # catch, because SketchUp refuses to hide the Untagged tag. From 1.51.0
    # dimensions are shown on every plate at Benton's instruction, so a loose
    # DIMENSION entity started tripping it: the live run of 1.53.0 flagged a
    # clean plate orange over a dimension reading 5'.
    #
    # That is worse than a cosmetic wrong colour. A warning that fires on
    # something Benton asked to see is a warning he learns to ignore, and then
    # it is not protecting him from the text either. So the warning counts TEXT
    # only. Loose dimensions are still reported in the tip, as a fact, with no
    # warn -- he can see they are there without being told they are a problem.
    #
    # The 'dim'/'text' split is wr-scene-annotations.rb's own (item_hash: 'dim'
    # for DimensionLinear/DimensionRadial, 'text' for Sketchup::Text), not
    # something guessed from a string here.
    warn = false
    unless loose_shown.nil?
      dims = loose_shown.select { |it| it[:kind].to_s == 'dim' }
      text = loose_shown - dims
      if text.any?
        warn  = true
        label = "#{label} + #{text.size} loose"
        tip  += " — #{text.size} LOOSE/Untagged callout(s) still SHOWN: " +
                text.first(6).map { |it| it[:text].to_s }.join(' | ')
      end
      if dims.any?
        tip += " — #{dims.size} loose dimension(s) shown (dimensions are shown " \
               'on every plate; not a warning)'
      end
    end
    # 'loose' stays the TEXT count, because it is what drives the warning and
    # what every consumer reads as "things that should not be there".
    { 'label' => label, 'warn' => warn, 'tip' => tip, 'shown' => shown,
      'loose' => (loose_shown.nil? ? nil :
                  loose_shown.count { |it| it[:kind].to_s != 'dim' }),
      'loose_dims' => (loose_shown.nil? ? nil :
                       loose_shown.count { |it| it[:kind].to_s == 'dim' }) }
  end
end
