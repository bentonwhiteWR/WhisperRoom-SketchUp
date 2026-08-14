# @title Angled Component Art...
# @cat Export art
#
# The Iso30 component library: every part shot at four fixed angled cameras on
# one shared canvas, so a web page can composite a whole booth by translation
# alone. Built to ANGLED-RENDER-BRIEF.md in
# WhisperRoomQuote\tools\sketchup-scene-export\.
#
# ===========================================================================
# HOW A SCENE FINDS ITS COMPONENT — read this before changing anything
#
# In the master file every component sits in ONE LONG ROW and they are ALL
# VISIBLE AT ONCE. A scene does not isolate anything; it only points the camera
# at one of them, and its name is a label like "(Left46Door)".
#
# Two earlier versions failed on exactly that. One walked definitions by name
# and could not name a thing. The next measured "what is visible", which in this
# file is the whole row — hundreds of feet — so the view height became enormous,
# every part rendered a few pixels wide, and the camera ended up inside the model
# and produced black frames.
#
# So the chain is:
#
#     the scene's CAMERA TARGET   ->  nearest component instance  =  the subject
#     the subject's DEFINITION NAME  ->  the filename
#     everything else hidden          ->  neighbours stay out of frame
#
# The definition name is used because that is what the importer matches on. The
# scene name is only a label. The dry run prints scene -> component for every
# row so the mapping can be checked before anything is written.
# ===========================================================================
#
# REGISTRATION — the contract with the web page:
#
#     the subject's own insertion point sits at the CENTRE PIXEL of every image,
#     and every image in a run shares one canvas and one view height.
#
# Section 3 of the brief says "target = component centroid", which is not the
# same thing — a centroid moves with the part's shape, so the registration point
# would differ per component and the page would need a table of offsets. The
# insertion point is something the page already knows. Where a subject has no
# usable insertion point the bounds centre is used instead, and the dry run says
# which was used per part.
#
# PARALLEL PROJECTION IS MANDATORY (section 2). camera.perspective = false is
# set explicitly on every render, never inherited. In perspective the same panel
# at the left and right of a room are different pictures and the library is
# worthless — and it fails silently. Batch 0's translation test is the proof.
#
# LIGHTING. Line art, per section 6: hidden-line render mode, shadows off,
# textures off, no depth cue, no fat profile edges. Shaded mode plus the default
# sun is what made an earlier run come out dark; the flat set once shipped at
# mean luma 55/255 and had to be rescued with a gamma lift. Not repeating that.
#
# ROOF-MOUNT COMPONENTS ARE OUT OF SCOPE for now, on Benton's instruction.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/angled-component-art.rb"

require 'sketchup.rb'
require 'fileutils'

# The shading contract, shared with export-component-art.rb. Loaded rather than
# required so an edit takes effect without restarting SketchUp.
load File.join(File.dirname(__FILE__), 'wr-shading.rb')
# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_AngledArt
  PREF = 'WR_AngledArt'.freeze

  # Eye direction FROM the target. ELEVATION IS FIXED AT 30 DEG and must stay
  # there — z is always 0.5 and the "Iso30" in every filename depends on it.
  #
  #     x = cos(elev) * cos(azim)   y = cos(elev) * sin(azim)   z = sin(elev)
  #
  # The AZIMUTH used to be frozen at 45, which is where 0.6124 = cos(30)*cos(45)
  # came from. At 45 the near and far corner seam seals of the SQUARE 7272 booth
  # project to exactly the same screen point — separation 0.0 in, a flat diamond
  # with nothing to read. Off 45 they separate (9.1 in at 40, 12.7 in at 38,
  # 16.4 in at 36). So the azimuth is now a dropdown and the table below is
  # derived from it at run time. 45 is still the default, so an unchanged run
  # reproduces the old frozen constants to the digit.
  ELEV      = 30.0
  DEF_AZIM  = 45.0

  # Rounded to 4 places on purpose: that is the precision the frozen table was
  # written at, so at azimuth 45 these come out bit-identical to what shipped.
  # (+ 0.0 turns a -0.0 from a rounded-away tiny negative back into 0.0.)
  def self.cam_vec(azim)
    e = ELEV * Math::PI / 180.0
    a = azim  * Math::PI / 180.0
    [(Math.cos(e) * Math.cos(a)).round(4) + 0.0,
     (Math.cos(e) * Math.sin(a)).round(4) + 0.0,
     Math.sin(e).round(4) + 0.0]
  end

  # A rigid rig: four cameras 90 deg apart, ExtR sitting ON the chosen azimuth
  # and the rest following. The NAMES keep their relative positions whatever the
  # azimuth — they are baked into the output filenames and into the importer.
  def self.build_cams(azim)
    [['ExtL', cam_vec(azim + 90.0)],
     ['ExtR', cam_vec(azim)],
     ['IntL', cam_vec(azim + 180.0)],
     ['IntR', cam_vec(azim + 270.0)]]
  end

  # The corner seam seal gets four, but not these four (section 8c). ExtNear and
  # IntFar sit 45 deg off the rig (azimuth 90 and 270 back when the rig was at
  # 45). That 45 offset is PRESERVED DELIBERATELY: the whole set rotates rigidly
  # with the azimuth rather than staying pinned to 90/270, so the corner family
  # keeps the same relationship to the other three that it had at 45.
  def self.build_corner_cams(azim)
    [['ExtNear', cam_vec(azim + 45.0)],
     ['ExtL',    cam_vec(azim + 90.0)],
     ['ExtR',    cam_vec(azim)],
     ['IntFar',  cam_vec(azim + 225.0)]]
  end

  def self.azimuth
    @azimuth || DEF_AZIM
  end

  # Set once per run from the dropdown, before anything measures or renders.
  def self.azimuth=(deg)
    a = deg.to_f
    a = DEF_AZIM unless a.finite? && a > 0.0 && a < 360.0
    @azimuth     = a
    @cams        = build_cams(a)
    @corner_cams = build_corner_cams(a)
  end

  def self.cams
    @cams ||= build_cams(azimuth)
  end

  def self.corner_cams
    @corner_cams ||= build_corner_cams(azimuth)
  end

  # "45" not "45.0" when it is a whole number, so the console reads like the
  # dropdown the number came from.
  def self.azim_label
    azimuth == azimuth.round ? azimuth.round.to_s : format('%.1f', azimuth)
  end

  # Printed, never hard-coded: a report that names a camera the run did not use
  # is worse than no report at all.
  def self.cam_labels(table = cams)
    table.map { |n, d| format('%-7s(%+.4f,%+.4f,%+.4f)', n, d[0], d[1], d[2]) }
  end

  EXT = %w[ExtL ExtR].freeze
  INT = %w[IntL IntR].freeze
  ALL = %w[ExtL ExtR IntL IntR].freeze

  SOLID  = %w[Component_46PanelSolid Component_40PanelSolid Component_22PanelSolid
              Component_16PanelSolid Component_43Panel Component_31Panel
              Component_28Panel Component_19Panel Component_7Panel].freeze
  CBL    = %w[Component_46PanelCBL Component_40PanelCBL].freeze
  WDO    = %w[Component_46Panel3230WDO Component_46Panel3236WDO Component_46Panel3242WDO
              Component_46Panel3248WDO Component_40Panel2630WDO Component_40Panel2636WDO
              Component_40Panel2642WDO Component_40Panel2648WDO Component_43Panel2636WDO
              Component_43Panel2648WDO Component_31Panel1648WDO].freeze
  DOORS  = %w[Component_46Door Component_40Door Component_WADoor
              Component_Right46Door Component_Right40Door Component_RightWADoor].freeze
  RAMPS  = %w[Component_WADoorWithRamp Component_RightWADoorWithRamp].freeze
  NV     = %w[Component_46NV Component_40NV].freeze
  VNT_BASE = %w[Component_46VNT Component_40VNT].freeze
  # Casing is deliberately inconsistent in the source and is matched exactly by
  # the importer. Do NOT normalise these.
  VNT_VAR  = %w[Component_46VNT_VSS Component_46VNT_EFS Component_46VNT_VSS_EFS
                Component_40VNT_VSS Component_40VNT_EFS Component_40VNT_VSS_EFS].freeze
  VNT_CP   = %w[Component_46VntCP Component_46vnt_VSS_CP Component_46Vnt_EFS_CP
                Component_46Vnt_VSS_EFS_CP Component_40Vnt_CP Component_40Vnt_VSS_CP
                Component_40Vnt_EFS_CP Component_40Vnt_VSS_EFS_CP].freeze
  MIDSEAL  = %w[Component_MidWallSeamSeal].freeze
  FURNITURE = %w[Component_DeskSmall Component_DeskLarge Component_MJP
                 Component_StepFront].freeze
  CORNER   = 'Component_CornerSeamSeal'.freeze

  def self.master
    m = {}
    (SOLID + CBL + WDO + DOORS + VNT_BASE + MIDSEAL).each { |n| m[n] = ALL }
    (NV + RAMPS + VNT_VAR + VNT_CP).each { |n| m[n] = EXT }
    FURNITURE.each { |n| m[n] = INT }
    m[CORNER] = corner_cams.map(&:first)
    m
  end

  DEFAULTS = {
    'batch' => '0 — one component, four images, STOP',
    'pick'  => 'batch',
    'dir'   => 'C:/Users/bento/Documents/Claude/WhisperRoomQuote/assets/AllBoothComponents/Iso30',
    'px'    => '2400',
    'azim'  => '45',
    'view'  => 'auto',
    'frame' => 'Part centred (fills the frame)',
    # Interior is the style this component library is shot in, and
    # export-component-art.rb defaults to the same string. Naming it beats
    # "leave the style alone": the viewport's style is whatever was last clicked,
    # so the old default made the two sets match only by luck.
    'style' => 'Style: Interior',
    # Shadow Dark, shared with export-component-art.rb. Both default to the same
    # value so the two sets start identical; raising it lifts the oblique faces
    # of an Iso30 view toward the flat-on faces of an elevation.
    'dark'  => WR_Shading::DEF_DARK.to_s,
    'over'  => 'No',
    'recov' => 'Yes',
    'dry'   => 'Yes'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[batch pick dir px azim view frame style dark ao over recov dry]
    prompts = ['Batch',
               'Scenes — batch / current / 1-7,12 / text',
               'Output folder',
               'Canvas (px, square)',
               'Azimuth (deg) — 45 stacks the 7272 corners',
               'View height — auto, or inches',
               'Frame on',
               'Style',
               'Shadow Dark (0-100) — raise it to lift oblique faces',
               'Viewport shading (AO) — second opaque pass per image',
               'Overwrite files already there',
               'Recover brightness after export (new graphics engine)',
               'Dry run — measure and list only']
    defaults = keys.map do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      v.empty? ? DEFAULTS[k] : v
    end
    # Every style IN THE MODEL is offered by name. The exporter never activates
    # scenes — it reads each scene's stored camera directly, to skip a few
    # hundred scene transitions — so a scene's own style NEVER applies by
    # itself: the render uses whatever style the viewport happens to have. That
    # is how a batch expected in Construction Documentation Style came out with
    # no edge lines. Picking the style here makes it explicit and repeatable.
    style_opts = ["Leave the style alone (the model's own)",
                  'Bold edges — model style, profiles forced on',
                  'Shaded, no textures',
                  'Line art (hidden line, no shadows)',
                  'PROBE — one camera, every style, for comparison']
    begin
      Sketchup.active_model.styles.each { |s| style_opts << "Style: #{s.name}" }
    rescue StandardError
    end

    # lists is POSITIONAL against prompts — one entry per prompt, in the same
    # order, '' where the field is free text. One missing '' shifts every
    # dropdown below it onto the wrong field, silently. Count them if you edit.
    lists = ['0 — one component, four images, STOP|' \
             '1 — exterior: walls, windows, doors, vents, seals|' \
             '2 — exterior: caster-plate vent walls|' \
             '3 — interiors and furniture|' \
             '4 — every scene, all four images',   # batch
             '',                                   # pick
             '',                                   # dir
             '',                                   # px
             '45|40|38|36|35',                     # azim
             '',                                   # view
             'Part centred (fills the frame)|Insertion point at centre (registration)',
             style_opts.join('|'),                 # style
             '',                                   # dark
             'No|Yes',                             # ao
             'Yes|No',                             # over
             'Yes|No',                             # recov
             'Yes|No']                             # dry
    # The folder slot is patched by INDEX rather than position, so reordering
    # the fields later cannot silently point the dropdown at the wrong one.
    di = keys.index('dir')
    defaults[di], lists[di] = WR_Folder.field('angled', DEFAULTS['dir'])

    res = UI.inputbox(prompts, defaults, lists, 'Angled Component Art (Iso30)')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }
    # A modal cannot be raised from inside another modal, so the browser opens
    # only now, after the inputbox is gone.
    cfg['dir'] = WR_Folder.resolve(cfg['dir'], 'angled', 'Where should the Iso30 images go?')
    return nil if cfg['dir'].nil?
    keys.each { |k| Sketchup.write_default(PREF, k, cfg[k]) }
    cfg
  end

  # --------------------------------------------------------------- selection --


  # Which SCENES to work on. Scene names in the master file are labels like
  # "(Left46Door)" — they are not the component names the importer matches on,
  # so nothing here filters by the component families. That happens after each
  # scene's subject has been resolved, by DEFINITION name.
  def self.select_scenes(model, spec)
    pages = model.pages.to_a
    s = spec.to_s.strip.downcase
    return [pages, "all #{pages.size} scenes"] if s.empty? || s == 'batch' || s == 'all'

    if s == 'current' || s == 'this'
      pg = model.pages.selected_page
      return [[], 'current — but no scene is selected'] if pg.nil?
      return [[pg], "current: #{pg.name}"]
    end

    picked = []
    misses = []
    s.split(',').map(&:strip).reject(&:empty?).each do |tok|
      hit = if tok =~ /\A(\d+)\s*-\s*(\d+)\z/
              a = Regexp.last_match(1).to_i
              b = Regexp.last_match(2).to_i
              a, b = b, a if a > b
              (a..b).map { |n| pages[n - 1] }.compact
            elsif tok =~ /\A\d+\z/
              n = tok.to_i
              [n >= 1 ? pages[n - 1] : nil].compact
            else
              pages.select { |p| p.name.to_s.downcase.include?(tok) }
            end
      hit.empty? ? misses << tok : picked.concat(hit)
    end
    picked = picked.uniq { |p| p.name }
    note = spec.to_s.strip
    note += "  — nothing matched #{misses.join(', ')}" unless misses.empty?
    [picked, note]
  end

  # Cameras for a resolved component. The batch decides the default set; the
  # master map refines it when the definition name is one we know. A name we do
  # not recognise still renders — with all four — and is reported, because on a
  # first run through a new file seeing the real names matters more than
  # enforcing a list.
  #
  # Batches 1, 2 and 3 give a part TWO images, because a wall panel photographed
  # from inside the booth and from outside it is two different pictures and the
  # other two cameras would only ever see its back. Batch 4 overrides that and
  # takes all four of everything — four times the files and four times the run
  # time, so it is the deliberate choice, not the default.
  #
  # The batch does NOT decide which scenes run. That is the Scenes field alone.
  # The only batch that touches the scene list is 0, which cuts it to one.
  def self.cams_for(name, batch)
    m = master[name]
    case batch.to_s[0, 1]
    when '0' then ALL
    when '1' then m == INT ? INT : EXT
    when '2' then EXT
    when '3' then m == EXT ? EXT : INT
    when '4' then ALL
    else m || ALL
    end
  end

  def self.cam_dir(suffix)
    row = cams.find { |s, _d| s == suffix } || corner_cams.find { |s, _d| s == suffix }
    row ? row[1] : nil
  end

  # ------------------------------------------------------------------ camera --

  def self.basis(dir)
    fwd = Geom::Vector3d.new(-dir[0], -dir[1], -dir[2])
    fwd.normalize!
    right = fwd.cross(Z_AXIS)
    right.normalize!
    [fwd, right, right.cross(fwd)]
  end

  # dist MUST clear the geometry. Distance does not affect scale in a parallel
  # projection, which is why an earlier version used a flat 1000 in — but if the
  # view height is bigger than that the camera ends up INSIDE the model and you
  # get a black frame, because you are looking at the back of a face. Scale it.
  def self.aim(view, dir, target, view_h, dist = nil)
    d = dist || [view_h * 6.0, 1000.0].max
    eye = Geom::Point3d.new(target.x + dir[0] * d,
                            target.y + dir[1] * d,
                            target.z + dir[2] * d)
    cam = view.camera
    cam.set(eye, target, Z_AXIS)
    cam.perspective  = false     # section 2. Never inherited, always set.
    cam.aspect_ratio = 1.0       # without this the render takes the viewport aspect
    cam.height       = view_h    # last: set() can reset the projection
    cam
  end

  def self.screen(p, dir, target)
    _f, right, up = basis(dir)
    v = Geom::Vector3d.new(p.x - target.x, p.y - target.y, p.z - target.z)
    [v % right, v % up]
  end

  # --------------------------------------------------- what the scene shows --



  # The registration point: the part's own insertion point when the scene shows
  # exactly one thing, which is the normal case. With several, fall back to the
  # centre of what is visible and say so — the framing still works, but the page
  # cannot assume the origin is the datum.
  # ============================================================================
  # HOW A SCENE IS LINKED TO A COMPONENT
  #
  # In the master file every component sits in one long row and they are ALL
  # visible at once. A scene does not isolate anything — it only points the
  # camera at one of them. So "what is visible" is the entire row, hundreds of
  # feet of it, and framing to that makes each part a few pixels wide and puts
  # the camera inside the model.
  #
  # The link is therefore the SCENE'S OWN CAMERA. Its target is aimed at the
  # part the scene is about, so the nearest component instance to that target
  # IS the subject. That component is then isolated for the render, and its
  # DEFINITION NAME — not the scene name — gives the filename, because the
  # definition is what the importer matches on.
  # ============================================================================

  def self.subject_for(model, page)
    cam = (page.camera rescue nil)
    return [nil, nil, 'scene has no camera'] if cam.nil?
    t = cam.target
    best = nil
    bestd = nil
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      bb = e.bounds
      next unless bb.valid?
      d = bb.contains?(t) ? 0.0 : t.distance(bb.center).to_f
      if bestd.nil? || d < bestd
        bestd = d
        best = e
      end
    end
    return [nil, nil, 'no component found near the scene camera'] if best.nil?
    how = bestd < 0.001 ? 'camera inside it' : format('%.0f in from the camera target', bestd)
    [best, best.bounds, how]
  end

  # The importer matches on the component name, so take it from the definition.
  # The scene name here is a label like "(Left46Door)" and is not the contract.
  # SketchUp's own auto-names — "Component#57", "Group#12". They carry no
  # meaning and must never reach a filename: the importer matches on the name
  # and a wrong one is ignored silently.
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  def self.subject_name(e, page)
    if e.is_a?(Sketchup::ComponentInstance)
      n = (e.definition.name.to_s.strip rescue '')
      return n unless n.empty? || n =~ AUTONAME
    end
    n = (e.name.to_s.strip rescue '')
    return n unless n.empty? || n =~ AUTONAME
    # Fall back to the scene's own label, which in this file is the useful one:
    # "(LeftWADoorWithRamp)" -> "LeftWADoorWithRamp".
    page.name.to_s.strip.sub(/\A\(/, '').sub(/\)\z/, '')
  end

  # Datum for the camera: the subject's own insertion point when it has one,
  # else the centre of its bounds.
  def self.datum_of(e)
    if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      o = (e.transformation.origin rescue nil)
      return [o, 'insertion point'] if o && e.bounds.contains?(o)
    end
    [e.bounds.center, 'bounds centre']
  end

  # Half-extent needed, in inches, for this bbox under this camera.
  def self.needed(bb, dir, target)
    wx = 0.0
    wy = 0.0
    8.times do |i|
      sx, sy = screen(bb.corner(i), dir, target)
      wx = sx.abs if sx.abs > wx
      wy = sy.abs if sy.abs > wy
    end
    [wx, wy]
  end

  # ------------------------------------------------------------------- style --

  LINE_ART = { 'RenderMode' => 1, 'Texture' => false, 'DisplayFog' => false,
               'DrawGround' => false, 'DrawHorizon' => false, 'DepthCue' => false,
               'DrawProfilesOnly' => false, 'DrawSilhouette' => false,
               'ExtendLines' => false, 'DisplayColorByLayer' => false }.freeze
  SHADED   = { 'RenderMode' => 2, 'Texture' => false, 'DisplayFog' => false,
               'DrawGround' => false, 'DrawHorizon' => false, 'DepthCue' => false }.freeze

  # Materials and textures stay as the model has them; edges and profiles are
  # forced on and heavy. For when the export needs the construction-document
  # look and the named style is not in the model. apply_style reads every key
  # back, so a key this SketchUp build does not accept shows up in the
  # diagnostics as stuck rather than failing silently.
  BOLD_EDGES = { 'EdgeDisplayMode' => 1, 'DrawSilhouettes' => true,
                 'SilhouetteWidth' => 3 }.freeze

  # Ground, horizon and fog always go off — real alpha needs it whatever the
  # style, and a scene can put an opaque sky back, so it is re-applied after
  # every scene change rather than once at the start. NOTHING ELSE is touched
  # unless a style is explicitly chosen: the model's own style is what the flat
  # set was shot with, and overriding it silently is how the renders stopped
  # looking like the rest of the library.
  # Confirmed against the real model (MASTERCOMPONENTSV1, style "Interior",
  # SketchUp 24.0.553). Every one of these fills or tints the whole frame, so
  # any of them left on means write_image returns an OPAQUE image — the alpha
  # channel came back 191 everywhere until these were found.
  #
  #   DisplayWatermarks  a watermark is a full-frame image. Semi-transparent,
  #                      it composites over everything and is why the corner
  #                      pixel read RGBA(0,0,0,191) instead of transparent.
  #   AmbientOcclusion   was on at distance 5.0, intensity 0.41 — this is what
  #                      darkened the part and the background together.
  #   DrawGround / DrawHorizon / DisplayFog   the usual sky-and-ground fills.
  #
  # None of these change the geometry's own appearance, so turning them off
  # still honours "use the model's own style".
  #
  # THE LIST NOW LIVES IN wr-shading.rb, shared with export-component-art.rb.
  # One definition is the point: the flat set and this set are shown side by
  # side, and they drifted apart because each script had its own copy.
  TRANSPARENCY = WR_Shading::TRANSPARENCY

  def self.find_style(model, name)
    hit = nil
    model.styles.each { |s| hit = s if s.name == name }
    hit
  rescue StandardError
    nil
  end

  # The shadow half of the contract is the same object export-component-art.rb
  # pushes, so the two sets shade identically. It is kept in a module ivar
  # because apply_style is called from four places and threading one more
  # argument through all of them is four chances to pass the wrong one.
  def self.dark
    @dark ||= WR_Shading::DEF_DARK
  end

  def self.dark=(v)
    @dark = WR_Shading.dark_value(v)
  end

  def self.push_style(model, mode)
    ro = model.rendering_options
    want, shadows = case mode
                    when /Line art/     then [LINE_ART.merge(TRANSPARENCY), true]
                    when /Shaded/       then [SHADED.merge(TRANSPARENCY),   true]
                    when /\ABold edges/ then [BOLD_EDGES.merge(TRANSPARENCY), false]
                    else                     [TRANSPARENCY.dup,             false]
                    end
    saved = { :ro => {}, :shadows => nil, :touch => shadows, :style => nil }

    # A named style is SELECTED for the run and restored afterwards. This is the
    # only way a scene's intended style reaches the export, since scenes are
    # never activated. The transparency keys still overlay it — a style's own
    # sky or watermark would otherwise make the alpha channel opaque again.
    if mode =~ /\AStyle: (.+)\z/
      name = Regexp.last_match(1)
      st = find_style(model, name)
      if st.nil?
        puts "  *** STYLE NOT IN THIS MODEL: #{name.inspect} — using the active style."
      else
        saved[:style] = (model.styles.selected_style.name rescue nil)
        begin
          model.styles.selected_style = st
        rescue StandardError => e
          saved[:style] = nil
          puts "  *** COULD NOT SELECT STYLE #{name.inspect}: #{e.class} — using the active style."
        end
      end
    end

    want.each_key { |k| saved[:ro][k] = (ro[k] rescue nil) }
    # Every shadow key the contract touches is remembered, not just
    # DisplayShadows — Light, Dark and UseSunForAllShading are now set too, and
    # a run that changed them without restoring them would leave the model
    # looking different from how it was opened.
    saved[:shade] = {}
    si = model.shadow_info
    WR_Shading::SHADOW_KEYS.each { |k| saved[:shade][k] = (si[k] rescue nil) }
    saved[:shadows] = saved[:shade]['DisplayShadows']
    [saved, want, shadows]
  end

  # Sets each key and READS IT BACK. A rescue that swallows a failed write is
  # how a setting can look applied and not be — which is exactly what happened
  # with the watermark. Anything that refuses to change is recorded so it shows
  # up in the diagnostics instead of being lost.
  def self.apply_style(model, want, touch_shadows = false)
    ro = model.rendering_options
    @stuck = []
    want.each do |k, v|
      begin
        ro[k] = v
      rescue StandardError => e
        @stuck << "#{k}: write raised #{e.class}"
        next
      end
      got = (ro[k] rescue :unreadable)
      @stuck << "#{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    # The shadow contract goes on EVERY time, not only when the chosen style
    # mode asked to touch shadows. It is what makes an oblique face in the Iso30
    # set shade the same way it does in the flat set, and it is the one number
    # (Dark) that closes the brightness gap between them.
    si = model.shadow_info
    WR_Shading.shadow_want(dark).each do |k, v|
      begin
        si[k] = v
      rescue StandardError => e
        @stuck << "shadow #{k}: write raised #{e.class}"
        next
      end
      got = (si[k] rescue :unreadable)
      @stuck << "shadow #{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    @stuck
  end

  def self.pop_style(model, saved)
    ro = model.rendering_options
    saved[:ro].each { |k, v| (ro[k] = v) rescue nil unless v.nil? }
    si = model.shadow_info
    (saved[:shade] || {}).each { |k, v| (si[k] = v) rescue nil unless v.nil? }
    if saved[:style]
      st = find_style(model, saved[:style])
      (model.styles.selected_style = st) rescue nil if st
    end
  end

  # Every rendering-option key SketchUp exposes, probed one at a time so a key
  # missing in this version cannot take the whole dump with it. each_key is not
  # used because if it raises, the rescue swallows the entire block and you get
  # nothing — which is exactly what happened.
  RO_PROBE = %w[
    BackgroundColor BandColor ConstructionColor DepthQueWidth DisplayColorByLayer
    DisplayDims DisplayFog DisplayInstanceAxes DisplaySectionCuts DisplaySketchAxes
    DisplayText DisplayWatermarks DrawBackEdges DrawGround DrawHidden DrawHorizon
    DrawLineEnds DrawProfilesOnly DrawSilhouettes DrawUnderside EdgeColorMode
    EdgeDisplayMode EdgeType ExtendLines FaceBackColor FaceColorMode FaceFrontColor
    FogColor FogEndDist FogStartDist FogUseBkColor ForegroundColor GroundColor
    GroundTransparency HideConstructionGeometry HorizonColor InactiveFade
    InactiveHidden InstanceFade InstanceHidden JitterEdges LineEndWidth LineExtension
    MaterialTransparency ModelTransparency RenderMode SectionActiveColor
    SectionCutFilled SectionCutWidth SectionDefaultCutColor SectionInactiveColor
    ShowViewName SilhouetteWidth SkyColor Texture TransparencySort
    AmbientOcclusion AmbientOcclusionDistance AmbientOcclusionIntensity
    DisplayAmbientOcclusion UseSunForAllShading
  ].freeze

  def self.dump_diagnostics(model, cfg, measured, view_h, px)
    dir = cfg['dir'].to_s
    FileUtils.mkdir_p(dir)
    path = File.join(dir, '_diagnostics.txt')
    ro = model.rendering_options
    si = model.shadow_info

    File.open(path, 'w') do |f|
      f.puts "ANGLED COMPONENT ART — diagnostics"
      f.puts "model      #{model.title}"
      f.puts "style      #{(model.styles.selected_style.name rescue 'unknown')}"
      f.puts "batch      #{cfg['batch']}"
      f.puts "frame on   #{cfg['frame']}"
      f.puts "style opt  #{cfg['style']}"
      f.puts "view       #{cfg['view']}  -> #{format('%.3f', view_h)} in at #{px} px"
      f.puts "azimuth    #{azim_label} deg (elevation #{format('%g', ELEV)})"
      f.puts "dark       #{dark} (Light #{WR_Shading::DEF_LIGHT})"
      f.puts "cameras    #{cam_labels.join('  ')}"
      f.puts "corner 8c  #{cam_labels(corner_cams).join('  ')}"
      f.puts ''
      f.puts 'SCENE -> COMPONENT'
      measured.each_with_index do |m, i|
        if m[:bad]
          f.puts format('  %3d  %-30s  *** %s', i + 1, m[:page].name, m[:bad])
        else
          bb = m[:bounds]
          f.puts format('  %3d  %-30s -> %-34s %-9s  %.1f x %.1f x %.1f in  [%s]',
                        i + 1, m[:page].name, m[:name], m[:cams].join(' '),
                        bb.width.to_f, bb.height.to_f, bb.depth.to_f, m[:how])
        end
      end
      f.puts ''
      f.puts 'TRANSPARENCY KEYS — applied, then read back'
      stuck = apply_style(model, TRANSPARENCY, false)
      TRANSPARENCY.each do |k, v|
        got = (ro[k] rescue :unreadable)
        mark = got == v ? 'ok  ' : '*** '
        f.puts format('  %s%-26s wanted %-6s now %s', mark, k, v.to_s, got.to_s)
      end
      if stuck.nil? || stuck.empty?
        f.puts '  all applied cleanly'
      else
        f.puts '  COULD NOT SET:'
        stuck.each { |s| f.puts "    #{s}" }
        f.puts '  -> these must be turned off in the style itself; the API will not do it.'
      end

      # AFTER the apply above, not before. The first version of this block sat
      # up with the header and reported DisplayWatermarks and AmbientOcclusion
      # as true — the state the model was FOUND in, under a heading that said
      # "as rendered". The readback two lines up proved they had in fact been
      # turned off. A diagnostic that reports the wrong moment is worse than no
      # diagnostic, because it gets believed.
      f.puts ''
      f.puts 'SHADING CONTRACT AS RENDERED — diff this block against the flat run'
      WR_Shading.describe(model).each { |l| f.puts "  #{l}" }
      f.puts ''
      f.puts 'RENDERING OPTIONS (blank value = key not present in this SketchUp)'
      RO_PROBE.sort.each do |k|
        v = begin
              ro[k]
            rescue StandardError
              nil
            end
        f.puts format('  %-32s %s', k, v.nil? ? '' : v.to_s)
      end
      f.puts ''
      f.puts 'SHADOW INFO'
      %w[DisplayShadows UseSunForAllShading Light Dark SunRise SunSet
         EdgesCastShadows DisplayOnGroundPlane].each do |k|
        v = begin
              si[k]
            rescue StandardError
              nil
            end
        f.puts format('  %-32s %s', k, v.nil? ? '' : v.to_s)
      end
      f.puts ''
      f.puts 'EDITING CONTEXT'
      f.puts "  active_path              #{(model.active_path || 'nil (top level - correct)')}"
      f.puts "  contexts closed on entry #{@closed}"
      f.puts "  InactiveFade             #{(ro['InactiveFade'] rescue 'n/a')}"
      f.puts "  InstanceFade             #{(ro['InstanceFade'] rescue 'n/a')}"
      f.puts '  If active_path is not nil, everything outside it renders at'
      f.puts '  InactiveFade brightness and transparency comes back wrong.'
      f.puts ''
      f.puts 'SKETCHUP'
      f.puts "  version   #{Sketchup.version}"
    end
    path
  rescue StandardError => e
    puts "  (could not write diagnostics: #{e.class}: #{e.message})"
    nil
  end

  # One part, one camera (ExtL), rendered under every combination worth testing.
  # Each file is named for exactly what was changed, so comparing them says
  # which variable is responsible rather than leaving it to be inferred.
  def self.probe(model, cfg, m, view_h, px)
    return puts('  PROBE: nothing measured to probe.') if m.nil?
    view = model.active_view
    ro   = model.rendering_options
    dir  = cam_dir('ExtL')
    FileUtils.mkdir_p(cfg['dir'])

    tops = model.entities.select do |e|
      e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
    end
    prev_hidden = tops.map { |e| [e, e.hidden?] }
    prev_lay    = model.layers.map { |l| [l, l.visible?] }
    keep = %w[RenderMode Texture DrawGround DrawHorizon DisplayFog
              DisplayWatermarks AmbientOcclusion DrawSilhouettes ExtendLines
              DepthCue DisplayColorByLayer]
    prev_ro = keep.map { |k| [k, (ro[k] rescue nil)] }

    tests = [
      ['1-model-style-transparent',  {},                                  true],
      ['2-model-style-opaque',       {},                                  false],
      ['3-shaded-no-texture',        { 'RenderMode' => 2, 'Texture' => false }, true],
      ['4-hidden-line',              { 'RenderMode' => 1, 'Texture' => false }, true],
      ['5-hidden-line-opaque',       { 'RenderMode' => 1, 'Texture' => false }, false],
      ['6-wireframe',                { 'RenderMode' => 0 },               false]
    ]

    begin
      model.layers.each { |l| (l.visible = true) rescue nil }
      tops.each { |e| (e.hidden = true) rescue nil }
      m[:subject].hidden = false

      tests.each do |name, opts, trans|
        prev_ro.each { |k, v| (ro[k] = v) rescue nil unless v.nil? }
        TRANSPARENCY.each { |k, v| (ro[k] = v) rescue nil } if trans
        opts.each { |k, v| (ro[k] = v) rescue nil }
        aim(view, dir, m[:datum], view_h)
        view.refresh
        path = File.join(cfg['dir'], "_Probe_#{name}.png")
        ok = view.write_image(:filename => path, :width => 900, :height => 900,
                              :antialias => true, :transparent => trans)
        puts format('  probe %-28s transparent=%-5s  %s', name, trans, ok ? 'ok' : 'FAILED')
      end
    ensure
      prev_ro.each { |k, v| (ro[k] = v) rescue nil unless v.nil? }
      prev_hidden.each { |e, h| (e.hidden = h) if e.valid? }
      prev_lay.each { |l, v| (l.visible = v) rescue nil }
    end

    puts ''
    puts '  PROBE WRITTEN — six files, _Probe_*.png, all the same part and camera.'
    puts '    1 vs 2  does :transparent itself darken the render?'
    puts '    1 vs 3  is it the texture?'
    puts '    1 vs 4  is it the shading?'
    puts '    4 vs 5  does transparency darken line art too?'
    puts '    6       geometry only, no faces at all.'
    puts ''
    UI.messagebox("Probe written: 6 files named _Probe_*.png in\n#{cfg['dir']}")
  rescue StandardError => e
    puts "  PROBE FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(3)
  end

  # ============================================================================
  # CLOSE EVERY OPEN EDITING CONTEXT FIRST — this is not optional
  #
  # If a group or component is open for editing, SketchUp draws everything
  # OUTSIDE that context at InactiveFade, which in this model is 0.25. Since the
  # exporter renders top-level parts, that means every render came back at a
  # quarter brightness. The arithmetic is exact:
  #
  #     opaque      white 255 background  ->  255 x 0.25          = 64
  #     transparent same background       ->  black at 255 x 0.75 = alpha 191
  #
  # Both numbers appeared in the probe, from this one cause. It survived turning
  # off the watermark, the occlusion, shadows and textures, because it is not a
  # style setting at all.
  # ============================================================================
  def self.close_contexts(model)
    n = 0
    while model.active_path && n < 20
      break unless model.close_active
      n += 1
    end
    n
  rescue StandardError
    n
  end

  # ============================================================================
  # THE GRAPHICS ENGINE TRADE-OFF — why this step exists
  #
  # SketchUp 24.0.553's NEW graphics engine composites a uniform 75% black layer
  # over everything write_image produces, in colour and in alpha:
  #
  #     out_rgb   = 0.25 * src_rgb
  #     out_alpha = 191.25 + 0.25 * src_alpha
  #
  # Measured exactly, not fitted: a wireframe export contains only the values
  # {0, 4, 8 ... 64} — multiples of four capped at 255 * 0.25 — and every
  # anti-aliased edge pixel lands where the alpha formula predicts.
  #
  # The CLASSIC engine exports correctly but renders chrome and other reflective
  # materials as flat black, which is worse: a wrong colour is a wrong image,
  # where a uniformly darkened one is exactly recoverable.
  #
  # So: keep the new engine, and undo the composite afterwards. The inverse is
  # pure arithmetic. It costs two bits of colour depth, which is invisible on
  # line art and mild on shaded fabric — and it keeps chrome.
  # ============================================================================
  def self.recover(cfg)
    fixer = File.join(File.dirname(__FILE__), 'fix-angled-alpha.py')
    unless File.exist?(fixer)
      puts "  RECOVERY SKIPPED — #{fixer} is missing."
      return false
    end
    cmd = "python \"#{fixer.tr('/', '\\')}\" \"#{cfg['dir'].tr('/', '\\')}\" --inplace"
    puts "  recovering brightness: #{cmd}"
    ok = system(cmd)
    if ok
      puts '  recovery done — files corrected in place.'
    else
      puts '  *** RECOVERY FAILED. Is python on PATH? Run it by hand:'
      puts "      #{cmd}"
      puts '  *** The PNGs are exported but still 75% dark until you do.'
    end
    ok
  rescue StandardError => e
    puts "  recovery error: #{e.class}: #{e.message}"
    false
  end

  # Marries each AO colour pass to its transparent mask: RGB from the opaque
  # AO shot, alpha from the clean transparent shot. Runs AFTER recover(), so
  # both images are already un-darkened. One known soft spot: semi-transparent
  # rim pixels take their colour from the opaque render, so a faint dark
  # fringe is possible against very light page backgrounds.
  def self.combine_ao(cfg)
    script = File.join(File.dirname(__FILE__), 'combine-ao.py')
    unless File.exist?(script)
      puts "  AO COMBINE SKIPPED — #{script} is missing."
      return false
    end
    cmd = "python \"#{script.tr('/', '\\')}\" \"#{cfg['dir'].tr('/', '\\')}\""
    puts "  combining AO passes: #{cmd}"
    ok = system(cmd)
    puts ok ? '  AO combine done.' : '  *** AO COMBINE FAILED — _aocolor files left in place.'
    ok
  rescue StandardError => e
    puts "  AO combine error: #{e.class}: #{e.message}"
    false
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\nThis exporter is scene-driven: " \
                    "each scene isolates one component and names it.")
      return
    end

    cfg = ask
    return unless cfg

    px   = cfg['px'].to_i
    px   = 2400 if px < 200 || px > 6000
    # Before anything measures or renders: the whole camera table hangs off this.
    self.azimuth = cfg['azim']
    self.dark    = cfg['dark']
    dry  = cfg['dry'] == 'Yes'
    over = cfg['over'] == 'Yes'
    ao   = cfg['ao'] == 'Yes'

    chosen, pick_note = select_scenes(model, cfg['pick'])
    chosen = chosen.first(1) if cfg['batch'].to_s.start_with?('0')   # Step 0: one, then stop
    if chosen.empty?
      UI.messagebox("No scenes selected.\n\n#{pick_note}\n\nUse batch, current, " \
                    "numbers like 1-7,12, or text from a scene name.")
      return
    end

    # Anything open for editing fades everything else to InactiveFade. Close it
    # before measuring or rendering — see close_contexts.
    @closed = close_contexts(model)
    puts "  closed #{@closed} open editing context(s) before rendering" if @closed > 0

    @rm_before = (model.rendering_options['RenderMode'] rescue nil)
    saved, want, shad = push_style(model, cfg['style'])
    pages    = model.pages
    view     = model.active_view
    prev_pg  = pages.selected_page
    prev_cam = (view.camera.clone rescue nil)
    prev_tt  = model.options['PageOptions']['TransitionTime']
    model.options['PageOptions']['TransitionTime'] = 0

    measured = []
    begin
      # ---- pass 1: measure. Nothing is written, so a bad frame costs nothing.
      # No page selection needed — the scene's stored camera is read directly,
      # which also avoids a few hundred scene transitions.
      chosen.each do |page|
        subj, bb, found = subject_for(model, page)
        if subj.nil?
          measured << { :page => page, :cams => ALL, :bad => found }
          next
        end
        cams = cams_for(subject_name(subj, page), cfg['batch'])
        d, dhow = if cfg['frame'].to_s.start_with?('Insertion')
                    datum_of(subj)
                  else
                    [bb.center, 'bounds centre']
                  end
        worst = 0.0
        cams.each do |c|
          wx, wy = needed(bb, cam_dir(c), d)
          worst = wx if wx > worst
          worst = wy if wy > worst
        end
        measured << { :page => page, :cams => cams, :subject => subj,
                      :name => subject_name(subj, page), :datum => d,
                      :bounds => bb, :how => "#{found}, #{dhow}", :half => worst }
      end

      good  = measured.reject { |m| m[:bad] }
      worst = good.map { |m| m[:half] }.max.to_f
      view_h = if cfg['view'].to_s.strip.downcase == 'auto'
                 [(worst * 2.0 * 1.05), 12.0].max
               else
                 v = cfg['view'].to_f
                 v <= 0 ? [(worst * 2.0 * 1.05), 12.0].max : v
               end
      scale = px / view_h

      puts ''
      puts "ANGLED COMPONENT ART — Iso30#{dry ? '   (DRY RUN, nothing written)' : ''}"
      puts ''
      puts "  batch          #{cfg['batch']}"
      puts "  picked         #{pick_note}"
      puts "  out            #{cfg['dir']}"
      puts "  style          #{cfg['style']}"
      puts format('  dark           %d  (Light %d, sun-for-shading off, shadows off)',
                  dark, WR_Shading::DEF_LIGHT)
      puts '  >> Style, Dark and Recover must MATCH the flat run in'
      puts '  >> export-component-art.rb, or the two sets will not sit together.'
      puts format('  canvas         %d x %d px, square, transparent', px, px)
      puts '  projection     PARALLEL — perspective = false, aspect_ratio = 1.0'
      puts format('  azimuth        %s deg  (elevation fixed at %s — z = 0.5, the "Iso30")',
                  azim_label, format('%g', ELEV))
      puts format('  cameras        %s', cam_labels[0, 2].join('  '))
      puts format('                 %s', cam_labels[2, 2].join('  '))
      puts format('  corner (8c)    %s', cam_labels(corner_cams)[0, 2].join('  '))
      puts format('                 %s', cam_labels(corner_cams)[2, 2].join('  '))
      puts format('  view height    %.3f in  (%s)   -> %.6f in/px',
                  view_h, cfg['view'].to_s.strip.downcase == 'auto' ? 'auto-fitted to the union' : 'as typed',
                  1.0 / scale)
      puts format('  registration   each part\'s own origin at pixel (%d, %d) — the centre',
                  px / 2, px / 2)
      puts ''
      puts '   #   SCENE                      ->  COMPONENT (from the definition)      CAMS       SIZE in'
      known = master
      measured.each_with_index do |m, i|
        if m[:bad]
          puts format('  %3d   %-26s  *** %s', i + 1, m[:page].name, m[:bad])
        else
          bb = m[:bounds]
          mark = known.key?(m[:name]) ? ' ' : '?'
          puts format('  %3d %s %-26s ->  %-34s %-9s %5.1f x %5.1f x %5.1f',
                      i + 1, mark, m[:page].name, m[:name], m[:cams].join(' '),
                      bb.width.to_f, bb.height.to_f, bb.depth.to_f)
        end
      end
      unmapped = measured.reject { |m| m[:bad] }.reject { |m| known.key?(m[:name]) }
      unless unmapped.empty?
        puts ''
        puts format('  ? = %d component name(s) are not in the library list, so they get all', unmapped.size)
        puts '      four cameras by default. If those names look right, the list in this'
        puts '      script needs updating to match them — that is the mapping to fix.'
      end
      puts ''
      bad = measured.count { |m| m[:bad] }
      puts "  #{good.size} scene(s) measured, #{bad} with nothing visible"
      puts ''

      # One oversized scene rescales EVERY image in the run, which is what makes
      # a component look like it vanished. Name it rather than let it hide in an
      # average.
      unless good.size < 2
        sizes = good.map { |m| m[:half] * 2.0 }.sort
        med = sizes[sizes.size / 2]
        big = good.select { |m| m[:half] * 2.0 > med * 2.0 }
        unless big.empty?
          puts '  *** THESE SCENES ARE MORE THAN TWICE THE MEDIAN SIZE. Auto view'
          puts format('  *** height is set by the largest, so all %d images are scaled to', good.size)
          puts format('  *** them and everything else shrinks. Median is %.1f in.', med)
          big.each { |m| puts format('        %-32s %8.1f in', m[:page].name, m[:half] * 2.0) }
          puts '  *** Exclude them with the Scenes field, or type a view height.'
          puts ''
        end
      end

      # The style's own rendering options, dumped verbatim. Transparency and
      # exposure both live in here and the key names differ between SketchUp
      # versions, so this is read off the running model rather than guessed.
      # Written to a file as well as the console. A few hundred lines scrolls
      # off, and copying it out of the Ruby Console by hand is a poor use of
      # anyone's time.
      diag = dump_diagnostics(model, cfg, measured, view_h, px)
      puts "  DIAGNOSTICS WRITTEN TO  #{diag}" if diag
      puts ''
      puts '  DIAGNOSTICS'
      puts format('    RenderMode   %s -> %s', @rm_before.inspect,
                  (model.rendering_options['RenderMode'] rescue 'n/a').inspect)
      puts format('    eye distance %.1f in  (6x the view height, min 1000 — it MUST', [view_h * 6.0, 1000.0].max)
      puts '                 clear the geometry or the frame renders black)'
      puts format('    scale        %.5f in/px at %d px', view_h / px, px)
      puts ''

      if dry
        puts '  DRY RUN — run again with Dry run = No to render.'
        puts ''
        UI.messagebox("Dry run: #{good.size} scene(s), #{good.sum { |m| m[:cams].size }} image(s).\n" \
                      "View height #{format('%.1f', view_h)} in.\n" \
                      "#{bad} scene(s) show nothing.\n\n" \
                      "The console has the scene -> component table and the full\n" \
                      "list of rendering options for the style that is on.")
        return
      end

      # ---- style probe: same part, same camera, every style, plus one with
      # transparency off entirely. Six small files that between them say which
      # variable is actually making the render dark, instead of another guess.
      if cfg['style'].to_s.start_with?('PROBE')
        probe(model, cfg, good.first, view_h, px)
        return
      end

      # ---- pass 2: render, one isolated component at a time.
      #
      # Everything at top level goes hidden once, then each subject is revealed
      # for its four shots and hidden again. Without this the neighbouring parts
      # in the row sit in frame, because they are only inches away.
      FileUtils.mkdir_p(cfg['dir'])
      written = 0
      failed  = []

      tops = model.entities.select do |e|
        e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      end
      prev_hidden = tops.map { |e| [e, e.hidden?] }
      prev_lay    = model.layers.map { |l| [l, l.visible?] }

      begin
        model.layers.each { |l| (l.visible = true) rescue nil }
        tops.each { |e| (e.hidden = true) rescue nil }
        apply_style(model, want, shad)

        good.each_with_index do |m, i|
          subj = m[:subject]
          next unless subj && subj.valid?
          subj.hidden = false
          begin
            m[:cams].each do |c|
              path = File.join(cfg['dir'], "#{m[:name]}_Iso30_#{c}.png")
              if !over && File.exist?(path)
                puts "  skip  #{File.basename(path)}"
                next
              end
              aim(view, cam_dir(c), m[:datum], view_h)
              apply_style(model, want, shad)
              view.refresh
              Sketchup.status_text = "Iso30 #{i + 1}/#{good.size}: #{m[:name]} #{c}"
              ok = view.write_image(:filename => path, :width => px, :height => px,
                                    :antialias => true, :transparent => true)
              # Viewport-shading pass. Ambient occlusion is the soft contact
              # shading the viewport shows and the export loses — it must be
              # OFF for the transparent shot because it tints the whole frame
              # and kills the alpha. So: same camera, AO back on, opaque
              # background. The transparent shot above becomes the alpha MASK,
              # this one carries the colour; combine-ao.py marries them.
              if ao && ok
                (model.rendering_options['AmbientOcclusion'] = true) rescue nil
                view.refresh
                ok2 = view.write_image(:filename => path.sub(/\.png\z/, '_aocolor.png'),
                                       :width => px, :height => px,
                                       :antialias => true, :transparent => false)
                failed << "#{File.basename(path)} (AO pass)" unless ok2
                (model.rendering_options['AmbientOcclusion'] = false) rescue nil
              end
              if ok
                written += 1
                puts "  ok    #{File.basename(path)}"
              else
                failed << File.basename(path)
                puts "  FAIL  #{File.basename(path)}"
              end
            end
          ensure
            subj.hidden = true if subj.valid?
          end
        end
      ensure
        prev_hidden.each { |e, h| (e.hidden = h) if e.valid? }
        prev_lay.each { |l, v| (l.visible = v) rescue nil }
      end

      recover(cfg) if cfg['recov'] == 'Yes'
      combine_ao(cfg) if ao

      tt = cfg['batch'].to_s.start_with?('0') ? translation_test(model, cfg, px, view_h, good.first) : nil
      report(cfg, px, view_h, scale, written, failed, tt)
    ensure
      pop_style(model, saved)
      model.options['PageOptions']['TransitionTime'] = prev_tt
      if prev_pg
        pages.selected_page = prev_pg
      elsif prev_cam
        view.camera = prev_cam
      end
      Sketchup.status_text = ''
    end
  rescue StandardError => e
    UI.messagebox("Angled Component Art failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  # Section 2's proof: the same part 60" apart must be identical but shifted.
  # Rendered by moving the CAMERA, which is equivalent under parallel projection
  # and does not touch the model.
  def self.translation_test(model, cfg, px, view_h, first)
    return nil if first.nil?
    view  = model.active_view
    dir   = cam_dir('ExtL')
    # The frame has to hold the part at BOTH positions or the second one runs
    # off the canvas and its silhouette clips to the frame edge — which reads
    # as "the shape changed" when nothing changed at all. A 60 in shift inside
    # a 116 in frame is over half the width, so widen the frame for the test.
    shift_len = 60.0
    view_h = view_h + 2.0 * shift_len
    scale = px / view_h
    _f, right, up = basis(dir)
    shift = Geom::Vector3d.new(shift_len, 0, 0)
    dx =  (shift % right) * scale
    dy = -(shift % up) * scale
    d  = first[:datum]
    files = []
    [['A', d],
     ['B', Geom::Point3d.new(d.x - shift.x, d.y - shift.y, d.z - shift.z)]].each do |tag, t|
      aim(view, dir, t, view_h)
      view.refresh
      path = File.join(cfg['dir'], "_TranslationTest_#{tag}.png")
      view.write_image(:filename => path, :width => px, :height => px,
                       :antialias => true, :transparent => true)
      files << File.basename(path)
    end
    { :files => files, :dx => dx, :dy => dy }
  end

  def self.report(cfg, px, view_h, scale, written, failed, tt)
    puts ''
    puts '  ================= HAND THIS BACK WITH THE IMAGES ================='
    puts ''
    puts '  Camera construction, verbatim:'
    puts format('    azimuth %s deg, elevation %s deg  ' \
                '(x = cos(elev)cos(azim), y = cos(elev)sin(azim), z = sin(elev))',
                azim_label, format('%g', ELEV))
    puts format('    dir = %s', cam_labels[0, 2].join('   '))
    puts format('          %s', cam_labels[2, 2].join('   '))
    puts format('    corner seam seal (8c) = %s', cam_labels(corner_cams)[0, 2].join('   '))
    puts format('                            %s', cam_labels(corner_cams)[2, 2].join('   '))
    puts '    target = the component instance\'s transformation.origin'
    puts '    eye    = target + dir * 1000.0        # distance is irrelevant'
    puts '    cam.set(eye, target, Z_AXIS)'
    puts '    cam.perspective  = false'
    puts '    cam.aspect_ratio = 1.0'
    puts format('    cam.height       = %.4f              # inches, the view extent', view_h)
    puts ''
    puts format('  Scale         %.6f in/px  (%.6f px/in)', 1.0 / scale, scale)
    puts format('  Registration  each component\'s own origin at pixel (%d, %d) of %d x %d',
                px / 2, px / 2, px, px)
    puts ''
    if tt
      puts '  TRANSLATION TEST (section 2) — proof the projection is parallel:'
      puts "    #{tt[:files].join('  and  ')}"
      puts format('    B must equal A shifted by exactly (%+.2f, %+.2f) px and be', tt[:dx], tt[:dy])
      puts '    identical otherwise. Any change in SHAPE means perspective crept'
      puts '    in and nothing else in this run is usable.'
      puts ''
    end
    puts "  Written #{written}, failed #{failed.size}"
    failed.each { |f| puts "    FAILED  #{f}" }
    puts ''
    puts '  STILL TO CONFIRM BY EYE — I cannot see the output:'
    puts '    - in ExtL the panel runs away to the LEFT, so its RIGHT edge is'
    puts '      nearest and drawn lowest. If backwards, swap the azimuth signs'
    puts '      in build_cams — do NOT swap the filenames.'
    puts '    - the CORNER SEAM SEAL first: at azimuth 45 its near and far seals'
    puts '      land on the same point on the square 7272 and there is nothing'
    puts '      to read. Off 45 they must visibly separate.'
    puts '    - line art: white faces, thin dark edges, no shading, no shadow.'
    puts '    - transparency is real alpha, not white.'
    puts ''
    UI.messagebox("Iso30: #{written} written, #{failed.size} failed.\n\n" \
                  "Console has the camera construction, the scale and the\n" \
                  "registration pixel to hand back with the images.")
  end
end

WR_AngledArt.run
