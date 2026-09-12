# -*- coding: utf-8 -*-
"""RUN wr-autoset.rb's pure half outside SketchUp.

    python rbtest-autoset.py

WHY THIS EXISTS
---------------
AUTO-SET (1.48.0) writes ten scenes' worth of answers in one click. Two of the
answers are customer-facing and silent when wrong, and one of them decides
whether re-running the tool destroys work:

  1. THE ANNOTATION ALLOWLIST. Client-safe annotation mode was removed at
     1.47.0, so the per-scene ANNOTATIONS picker is now the ONLY authority on
     what an exported plate shows -- there is no second net. A plate must show
     only the sets it names, with every other family tag AND every loose
     Untagged callout hidden. `WR-Notes` is the literal defect-D5 banner (the
     `Ceiling 8'-0" - HOUSE DEFAULT` string that went out on a client image on
     30 Aug 2026) and is on a never-shown list.
  2. THE WALL PICKS MUST BE A FULL HASH. Every wall unit keyed true or false,
     never a partial hash -- a wall hidden on the previous plate would
     otherwise ride along into this one.
  3. IDENTITY IS THE STAMP, NEVER THE NAME. Re-running matches pages by their
     WR_AutoSet stamp, so a scene Benton renamed by hand is UPDATED rather
     than renamed back, and a page with no stamp is never touched at all.

Those three are pure data in, data out, so they are the part that CAN be
proven before anyone opens SketchUp. This harness runs them in the same CRuby
3.2 VM rbparse.py borrows from SketchUp.

Like rbtest.py, THE METHOD SOURCE IS NOT COPIED HERE. Every method and every
constant is lifted verbatim out of wr-autoset.rb on each run, so the test
cannot drift from the code it tests -- edit the script and the next run tests
the edit.

WHAT IT PROVES / DOES NOT PROVE
-------------------------------
It proves the annotation policy, the wall cone, the render ladder, the plate
azimuths (including that plate 3 is now the DOOR side -- a front elevation --
and not the side elevation proposal-scenes.rb freezes), the booth token's
collision numbering, and the stamp's containment rule against fake pages.

It proves NOTHING about the writer: creating pages, selecting them, calling
WR_SceneWalls.write_scene / WR_SceneAnnotations.write_scene, the undo record,
or the review columns' deep read. Those need a real model and are covered by
.forge/builder/verify-autoset.rb, which Benton runs in an Untitled model.

CHECKED AGAINST ITSELF
----------------------
A test that cannot fail proves nothing. Mutation-checked when written -- RUN,
not assumed. Each of these reintroduced bugs makes the NAMED check fail:

    WR-Notes dropped from NEVER_SHOWN                    -> nv1, nv2 FAIL
    annot_picks stops keying the loose rows              -> an2, an8 FAIL
    SHOWN_BY_PLATE['01-exterior'] given a tag            -> an7 FAIL
    wall_picks emits only the hidden keys (partial hash) -> wp2, wp3 FAIL
    wall_picks back to the angular cone (1.60.0 rule)    -> bt3, bt4, bt7 FAIL
    segment_box_t counting a booth point INSIDE a wall  -> wp1, wp5, wp8, bt8 FAIL
    05-plan dropped from NO_WALL_PLATES                  -> wp3 FAIL
    token_pages matched by NAME instead of stamp         -> sm2, sm3 FAIL
    WR-Notes put back on a plate                         -> an1, nv1, nv2 FAIL
    loose TEXT shown (the D5 guard)                      -> an2 FAIL
    loose dimensions hidden again                        -> an2b FAIL
    the interior eye put back at radius * 0.55           -> in1, in2, in3 FAIL
    the interior camera tilted off level                 -> in6 FAIL
    the interior up vector tipped                        -> in7 FAIL
    the interior fov reset to the exterior lens          -> in9 FAIL
    aim_interior set() before perspective= again         -> in11, in12 FAIL
    WR_ProposalScenes.aim set() before perspective=      -> cm19 FAIL
    the interior plane read off the union box again      -> in12 FAIL
    door_run's sign dropped (abs)                        -> in14b FAIL
    the front plate given a swing (not square to door)   -> cm2 FAIL
    the plan plate put back to el 89                     -> cm5 FAIL
    any plate given cam.perspective = false              -> cm1 FAIL
    an IMAGE plate made a render at any count            -> cm11 FAIL
    05-ventilation added to NO_WALL_PLATES               -> cm12 FAIL
    empty_shown_note made to fire on a partial count     -> eb3 FAIL
    PLATES put back to the pre-1.56 front-first order    -> or1, or2, or3 FAIL
    the ladder reordered (not the plate order)           -> ld12, ld15 FAIL
    the angled render forced again at a count of zero    -> ld1, ld13, fr7 FAIL
    the pair emitted image-first again                   -> du2, ld14 FAIL
    the interior made to consume a render slot           -> fr4 FAIL
    effective_shown keyed on the raw id (not base_id)    -> du5 FAIL
    NO_WALL_PLATES checked on the raw id                 -> du5b FAIL
    page_for_plate no longer following RENUMBERED        -> mg1, mg3 FAIL
    stale_plates calling a RENUMBERED id stale           -> mg5 FAIL
    az_for back to the unconditional door +90 side       -> sd12, sd15 FAIL
    az_for honouring the side sign on 04-side only       -> sd13, vt17b FAIL
    side_swung? narrowed back to 04-side                 -> sd13, sd13c, vt17b FAIL
    side_swung? forgetting the swing test (any :door)    -> sd13c FAIL
    wall_shape? drifting from wall_normal at ASPECT_MIN  -> if2 FAIL
    inner_frame_pick ignoring the frame NAME             -> if8 FAIL
    inner_frame_pick ranked by box area, not aspect      -> the run RAISES at if7
                                                            (nil['name']), where
                                                            real Ruby would fail
                                                            it by name -- same
                                                            shape as sd16 below
    inner_frame_pick guessing when nothing is wall-shaped-> if9 FAIL
    door_axis back to the 1.68.0 order (frame only after
      the outer box fails the shape test)               -> fd3 FAIL
    frame_reading keeping every depth (slab gets a vote) -> fd2, fd4 FAIL
    frame_row_normal without the FRAME_SNAP_DEG test     -> fd5 FAIL
    frame_parts not composing (own transformation only)  -> fd1, fd2, fd4 FAIL
    frame_parts ignoring the door tag                    -> fd1, fd2 FAIL
    door_axis running the inner descent eagerly          -> fd3, fd6 FAIL
      (1.69.0, all six RUN on 12 Sep 2026, file restored, 303 green after)

    tag_anchor NOT descending into a one-piece door is the defect itself, and it
    is impure -- if4..if10 pin the pure half, and the live half was measured
    through scripts/sketchup-bridge.py against Benton's own model on 12 Sep 2026
    (door bearing 180 -> -90, side pick landing on the window). verify-autoset.rb
    section 10 is where it belongs in a model.
    pick_side ranking part count above the window        -> sd6 FAIL
    pick_side tie falling to door -90                    -> sd4, sd7, sd11, sd18 FAIL
    az_for back to the unconditional +swing on the vent  -> vt15, vt16, vt18 FAIL
    pick_vent taking the FIRST wall walked (no ordering) -> vt1, vt3, vt4 FAIL
    pick_vent's swing hand inverted                      -> vt3, vt4, vt8 FAIL
    pick_vent's tie-break rank dropped                   -> vt8, vt9, vt10 FAIL
    walls_line silent on an empty unit list              -> wl1, wl2 FAIL
    ceiling_picks never hiding (the ceiling stays)       -> cl2, cl3, cl4, cl12 FAIL
    06-plan dropped from CEILING_PLATES                  -> cl4, cl9, cl12, cl15 FAIL
    ceiling_over? ignoring the footprint (any flat box)  -> cl1, cl2, cl4 FAIL
    ceilings_line silent when none is found              -> cl10, cl11 FAIL
    rig_bound? never binding (the rig face stays)        -> rg1, rg3 FAIL
    hides_line dropping the light-rig mention            -> rg4 FAIL
    walls_line silent about the rig                      -> rg6 FAIL
    pick_side choosing a side with no door               -> sd16 (the run RAISES
                                                            there: this VM has no
                                                            NilClass#to_f, so the
                                                            fabricated normal blows
                                                            up where real Ruby would
                                                            fail sd16 by name)

THE CAMERA MATHS ARE RUN, NOT ASSERTED ABOUT
--------------------------------------------
The `cm` checks do not read :el out of the table and compare numbers -- that
would pass a table whose values never reach a camera, which is exactly the
1.48.0 defect (the plates were aimed and the aim never landed on the page).
They run the REAL WR_ProposalScenes.aim and the REAL WR_AutoSet.aim_plate
against a stub Geom and a stub Camera, and measure the eye that comes out:
where it stands relative to the booth, how far back, how high, and whether the
camera it left behind is a perspective one. A future edit that tilts the plan
or swings the front fails BY NAME.

What it still cannot prove is that SketchUp SAVES that camera onto the page.
That is the other half of the 1.48.0 defect and it needs a real model --
.forge/builder/verify-autoset.rb, section 10.

Do that again if you ever doubt it.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse   # noqa: E402
import rbtest    # noqa: E402

SRC = os.path.join(HERE, 'wr-autoset.rb')
SW  = os.path.join(HERE, 'wr-scene-walls.rb')


def const_line(name, src=SRC):
    """The verbatim defining line of a module-level constant."""
    for ln in open(src, encoding='utf-8').read().split('\n'):
        if re.match(r'^  %s\s*=' % re.escape(name), ln):
            return ln
    raise SystemExit('%s: no constant %s' % (os.path.basename(src), name))


def const_block(name, src=SRC):
    """A constant whose definition runs over more than one line, verbatim."""
    lines = open(src, encoding='utf-8').read().split('\n')
    out = []
    for ln in lines:
        if not out and not re.match(r'^  %s\s*=' % re.escape(name), ln):
            continue
        out.append(ln)
        if '.freeze' in ln:
            return '\n'.join(out)
    raise SystemExit('%s: no constant %s' % (os.path.basename(src), name))


# --------------------------------------------------------------------------
# The fixture. WR_ProposalScenes is stubbed down to the ONE thing wr-autoset
# reads from it at constant-definition time -- SHOWN_ON_DIMENSIONED, lifted
# from the real proposal-scenes.rb so the link between the two files is part
# of what is tested. FakePage is the minimum Sketchup::Page the stamp reader
# touches.
# --------------------------------------------------------------------------
FIXTURE = r'''
# The bare VM is the parser plus enough runtime to compile; a few core methods
# the real interpreter has are simply absent. Put back only what the lifted
# methods call, so each one still runs exactly as written (rbtest.py SHIMS).
class Integer
  def to_i; self; end
  def to_f; self * 1.0; end
end
class Float
  def to_f; self; end
end

# Enough Geom for the real aim() to run. Vector3d and Point3d carry three
# floats and one operation each; nothing here is clever, because anything
# clever would be testing the stub instead of the code.
module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    def to_a; [@x, @y, @z]; end
    def length; Math.sqrt((@x * @x) + (@y * @y) + (@z * @z)); end
  end

  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    def to_a; [@x, @y, @z]; end
    def offset(v, d)
      Point3d.new(@x + (v.x * d), @y + (v.y * d), @z + (v.z * d))
    end
  end
end

# The camera aim() actually writes to. `perspective` starts FALSE so that a
# plate which never sets it reads as parallel and fails cm1 -- the stub must
# not flatter the code.
#
# THE PARALLEL-TO-PERSPECTIVE SLIDE IS MODELLED, because it is what SketchUp
# does and it is what the 1.53.0 and 1.54.0 live runs measured. Flipping a
# parallel camera to perspective keeps the TARGET and moves the EYE back along
# the view direction until the parallel frame height fills the lens:
# dist = height / (2 tan(fov / 2)). Live, 11 Sep 2026: 06-plan left the view
# parallel at height radius * 2.3 = 186.40 with the 35-degree lens, and the
# interior eye that had been set 27 in from its target came back 295.59 in
# from it (186.40 / (2 tan 17.5) = 295.59), 223 in outside the booth. A stub
# that ignores this passes a set()-then-perspective= order that SketchUp
# overwrites -- 164 checks were green while that eye was wrong.
class FakeCamera
  attr_accessor :fov, :height
  attr_reader :eye, :target, :up, :perspective
  def initialize
    @perspective = false
    @fov = nil
    @height = nil
  end
  def set(eye, target, up)
    @eye = eye
    @target = target
    @up = up
  end
  def perspective=(v)
    if v && !@perspective && @eye && @target && @height
      f = (@fov || 35.0) * Math::PI / 180.0
      d = @height / (2.0 * Math.tan(f / 2.0))
      vx = @eye.x - @target.x
      vy = @eye.y - @target.y
      vz = @eye.z - @target.z
      n = Math.sqrt((vx * vx) + (vy * vy) + (vz * vz))
      if n > 1.0e-9
        @eye = Geom::Point3d.new(@target.x + (vx / n * d), @target.y + (vy / n * d),
                                 @target.z + (vz / n * d))
      end
    end
    @perspective = v
  end
end

# The minimum the frame picker touches: a name and a bounds centre.
class FakePt
  attr_reader :x, :y, :z
  def initialize(x, y, z = 0.0)
    @x = x.to_f
    @y = y.to_f
    @z = z.to_f
  end
end

class FakeBB
  attr_reader :center
  def initialize(cx, cy, hx, hy)
    @center = FakePt.new(cx, cy)
    @hx = hx.to_f
    @hy = hy.to_f
  end
  def max; FakePt.new(@center.x + @hx, @center.y + @hy); end
  def min; FakePt.new(@center.x - @hx, @center.y - @hy); end
end

class FakeEnt
  attr_reader :name, :bounds
  def initialize(name, cx, cy)
    @name = name
    @bounds = FakeBB.new(cx, cy, 1.0, 1.0)
  end
end

# 1.69.0: the minimum frame_parts walks -- a tag, a definition with a name,
# its own box and its children, and a transformation that answers to_a.
class FakeLayer
  attr_reader :name
  def initialize(name)
    @name = name
  end
end

class FakeTr
  def initialize(a)
    @a = a
  end
  def to_a; @a; end
end

class FakeBox3
  attr_reader :min, :max
  def initialize(mn, mx)
    @min = FakePt.new(mn[0], mn[1], mn[2])
    @max = FakePt.new(mx[0], mx[1], mx[2])
  end
end

class FakeDef
  attr_reader :name, :bounds, :entities
  def initialize(name, mn, mx, entities = [])
    @name = name
    @bounds = FakeBox3.new(mn, mx)
    @entities = entities
  end
end

class FakeInst
  attr_reader :name, :layer, :definition, :transformation
  def initialize(name, layer, defn, to_a)
    @name = name
    @layer = FakeLayer.new(layer)
    @definition = defn
    @transformation = FakeTr.new(to_a)
  end
end

# A loose face or edge: no transformation, no definition. The walk must step
# over it rather than raise.
class FakeLoose
end

class FakeView
  attr_reader :camera
  # `after_plan` hands back a view in the state 06-plan leaves it: parallel,
  # frame height radius * 2.3, the 35-degree lens still on the camera. That
  # is the view every interior aim in a default run is made onto.
  def initialize(after_plan = false, radius = 60.0)
    @camera = FakeCamera.new
    return unless after_plan
    @camera.set(Geom::Point3d.new(0, 0, 500), Geom::Point3d.new(0, 0, 42),
                Geom::Vector3d.new(0, 1, 0))
    @camera.fov = 35.0
    @camera.height = radius * 2.3
  end
  def refresh; true; end
end

module WR_ProposalScenes
%(shown_on_dimensioned)s
%(deg)s

%(aim)s
end

# The ceiling recogniser's pure half, verbatim from wr-scene-walls.rb.
module WR_SceneWalls
%(ceil_max_t)s
%(ceil_hint_max_t)s
%(ceil_min_span)s
%(ceil_name_re)s
%(ceil_tag)s

%(ceiling_shape)s

%(ceiling_hint)s

%(rig_bind_tol)s

%(rig_bound)s
end

# The minimum Sketchup::Page the stamp reader touches. `dict` nil means a page
# with NO WR_AutoSet dictionary -- a scene Benton made by hand, the thing the
# containment rule exists to protect.
class FakePage
  attr_accessor :name
  def initialize(name, dict = nil)
    @name = name
    @dict = dict
  end
  def get_attribute(dict_name, key, default = nil)
    return default unless @dict && dict_name == 'WR_AutoSet'
    @dict.key?(key) ? @dict[key] : default
  end
end

module WR_AutoSet
%(deg)s
%(dict)s
%(fallback_az)s
%(moved_tol)s
%(wall_pad)s
%(sight_min)s
%(aspect_min)s
%(window_re)s
%(side_plate)s
%(side_skip_tags)s
%(thin_max)s
%(vent_plate)s
%(ceiling_plates)s
%(ceil_above_tol)s
%(dual_suffix)s
%(dims_re)s
%(booth_wall_t)s
%(interior_eye_clear)s
%(interior_fov)s
%(standoff_k)s
%(standoff_c)s
%(plate_fov)s
%(plate_eye)s
%(vent_eye)s
%(el_min)s
%(el_max)s
%(default_renders)s
%(plates)s
%(renumbered)s
%(no_wall_plates)s
%(render_ladder)s
%(max_renders)s
%(never_shown)s
%(shown_by_plate)s

%(effective_shown)s

%(annot_picks)s

%(unit_vec)s

%(cone_dot)s

%(booth_targets)s

%(segment_box_t)s

%(sight_lines_crossed)s

%(unit_box)s

%(wall_picks)s

%(wall_log)s

%(ladder_renders)s

%(base_id)s

%(dual_render)s

%(dual_render_id)s

%(render_ids)s

%(mode_for)s

%(plate)s

%(plate_ids)s

%(run_ids)s

%(live_plate)s

%(stale_plates)s

%(extra_pages)s

%(auto_named)s

%(az_for)s

%(side_swung)s

%(part_wall)s

%(side_normals)s

%(side_score)s

%(pick_side)s

%(side_sign)s

%(side_line)s

%(vent_rank)s

%(wall_word)s

%(pick_vent)s

%(vent_line)s

%(walls_line)s

%(rig_counts)s

%(hides_line)s

%(ceiling_over)s

%(ceiling_picks)s

%(ceilings_line)s

%(ceiling_line)s

%(standoff)s

%(reach)s

%(wall_axis)s

%(wall_normal)s

%(frame_re)s

%(wall_shape)s

%(plan_aspect)s

%(inner_frame_pick)s

%(frame_snap_deg)s

%(frame_walk_depth)s

%(mat_mul)s

%(mat_apply)s

%(frame_parts)s

%(frame_row_normal)s

%(frame_reading)s

%(door_axis)s

%(annot_cell)s

%(frame_hits)s

%(interior_eye_dist)s

%(door_run)s

%(policy_line)s

%(loose_split)s

%(plate_dist)s

%(plate_el)s

%(aim_plate)s

%(aim_interior)s

%(tag_counts_unused)s%(empty_shown_note)s

%(blank_plates)s

%(sanitize_token)s

%(next_token)s

%(scene_name)s

%(centre_key)s

%(centre_from_key)s

%(moved_by)s

%(centre_moved)s

%(page_stamp)s

%(token_pages)s

%(page_for_plate)s

%(tokens_in_use)s
end

# THE GATE, ON ITS OWN. NEVER_SHOWN's whole job is to survive a future edit to
# SHOWN_BY_PLATE, so the only honest way to test it is to MAKE that edit: this
# module runs the REAL effective_shown and the REAL NEVER_SHOWN against a
# deliberately poisoned allowlist that puts WR-Notes on the hero plate. If the
# gate is gone, the D5 banner comes back out of here.
module WR_AutoSetPoison
%(never_shown)s
%(dims_re)s
%(dual_suffix)s
  SHOWN_BY_PLATE = {
    '01-exterior' => %%w[WR-Dims WR-Notes WR-Dims-Booth]
  }.freeze

%(base_id)s

%(effective_shown)s
end

module T
  OUT = []
  def self.ck(name, ok, detail = nil)
    OUT << (ok ? "#{name} ok" : "#{name} FAIL#{detail ? ' ' + detail.to_s : ''}")
  end

  # THE SIX IMAGE PLATES, IN BENTON'S ORDER (11 Sep 2026): angled leads,
  # front follows. Side is ON by default even though he said "sometimes" --
  # see PLATES. A render is an EXTRA scene in front of its image, so a run
  # at N renders is 6 + N pages.
  IMAGES   = ['01-angled', '02-front', '03-high', '04-side', '05-ventilation', '06-plan']
  # ONE render -- not the default any more, but still the shape mg9/mg10
  # pin when a run explicitly asks for one.
  ONE      = ['01-angled r'] + IMAGES
  # THE DEFAULT RUN, at DEFAULT_RENDERS 3 (1.63.0, Benton: "lets default
  # 3"): NINE pages -- the top three of the ladder rendered, each sitting
  # in front of its own image, then the rest of the images.
  DEFAULTS = ['01-angled r', '01-angled', '02-front r', '02-front',
              '03-high r', '03-high', '04-side', '05-ventilation', '06-plan']
  ALL      = DEFAULTS + ['07-interior']

  # Every annotation set a well-used model carries: the five the WR tools
  # write, the two opt-in sets AUTO-SET knows by name, and one Benton made
  # this afternoon that is on no allowlist at all.
  def self.sets
    %%w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Dims-Selection WR-Notes
       WR-Notes-Plan WR-Notes-Vent WR-Notes-Custom].map do |n|
      { 'key' => "t:#{n}", 'name' => n }
    end
  end

  # Hand-placed text on Untagged. SketchUp REFUSES to hide the Untagged tag,
  # so these are the rows an allowlist exists for: their content is unknown to
  # any tool, and every one of them is hidden on every plate.
  # TWO TEXT CALLOUTS AND ONE DIMENSION, because since 1.51.0 those are
  # treated differently and a fixture that carried only one kind could not
  # tell the two rules apart. The text rows are the D5 case and stay hidden
  # on every plate; the loose dimension is a dimension, and Benton asked for
  # the dimensions to stop being hidden.
  def self.loose
    [{ 'key' => 'e:101', 'kind' => 'text' },
     { 'key' => 'e:102', 'kind' => 'text' },
     { 'key' => 'e:103', 'kind' => 'dim' }]
  end

  def self.loose_text
    loose.select { |it| it['kind'] != 'dim' }
  end

  # The booth this fixture measures in: MDL 4872 E. Exterior 4'2" x 6'2" x
  # 7'1" = 50 x 74 x 85 (reference/booth-models.md), so the half-extents are
  # 25 x 37 and the model number 4872 IS the interior -- 1 in of wall a side.
  HALF = [25.0, 37.0]

  # The booth this repo draws most: MDL 4872 E, 48 x 72 x ~85, sitting on the
  # floor, so its centre is ~42 in up and its radius ~60 in. Every distance
  # claim below is in THIS booth's terms and says so.
  CENTRE = [0.0, 0.0, 42.0]
  RADIUS = 60.0
  DOOR   = -90.0      # the door faces -Y, the fixture in verify-autoset.rb
  VENT   = 90.0

  # Aim one plate for real and hand back the camera it left behind.
  # `side` is pick_side's sign; it reaches az_for through the real aim_plate.
  # `vshift` is pick_vent's sign; it reaches az_for on the vent plate only.
  def self.cam(id, door = DOOR, vent = VENT, after_plan = false, half = HALF, anchor = nil,
               side = 1, vshift = 1)
    v = FakeView.new(after_plan, RADIUS)
    WR_AutoSet.aim_plate(v, id, CENTRE, RADIUS, door, vent, half, anchor, side, vshift)
    v.camera
  end

  # Where the eye ended up, relative to the booth centre, in the terms the
  # shot list is written in: compass bearing, height off the FLOOR, and how
  # far back along the ground.
  def self.shot(id, door = DOOR, vent = VENT, side = 1, vshift = 1)
    c = cam(id, door, vent, false, HALF, nil, side, vshift)
    e = c.eye.to_a
    dx = e[0] - CENTRE[0]
    dy = e[1] - CENTRE[1]
    run = Math.sqrt((dx * dx) + (dy * dy))
    { 'az'  => (Math.atan2(dy, dx) * 180.0 / Math::PI),
      'run' => run,
      'z'   => e[2],
      'up'  => c.up.to_a,
      'persp' => c.perspective,
      'fov' => c.fov }
  end

  def self.shown_on_equal?(a, b, ss = sets)
    WR_AutoSet.annot_picks(a, ss, loose) == WR_AutoSet.annot_picks(b, ss, loose) &&
      shown_on(a, ss) == shown_on(b, ss)
  end

  def self.shown_on(plate, ss = sets)
    p = WR_AutoSet.annot_picks(plate, ss, loose)
    ss.map { |s| s['name'] }.reject { |n| p["t:#{n}"] }
  end

  def self.run
    # ---- tokens ---------------------------------------------------------
    ck('ts1', WR_AutoSet.sanitize_token('MDL 96120 E') == 'MDL 96120 E')
    ck('ts2', WR_AutoSet.sanitize_token('Booth: A/B') == 'Booth- A-B',
       WR_AutoSet.sanitize_token('Booth: A/B'))
    ck('ts3', WR_AutoSet.next_token([], 'MDL 4872 E') == ['MDL 4872 E', 'MDL 4872 E'])
    ck('ts4', WR_AutoSet.next_token(['MDL 4872 E'], 'MDL 4872 E') ==
              ['MDL 4872 E-2', 'MDL 4872 E (2)'],
       WR_AutoSet.next_token(['MDL 4872 E'], 'MDL 4872 E').inspect)
    ck('ts5', WR_AutoSet.next_token(['MDL 4872 E', 'MDL 4872 E-2'], 'MDL 4872 E') ==
              ['MDL 4872 E-3', 'MDL 4872 E (3)'])
    ck('ts6', WR_AutoSet.scene_name('MDL 96120 E', '02-front') ==
              'MDL 96120 E 02-front')
    # A booth genuinely named "Rack-2" must not be mistaken for the second
    # "Rack" -- which is why token and label are two stored keys, not one
    # parsed string.
    ck('ts7', WR_AutoSet.next_token([], 'Rack-2') == ['Rack-2', 'Rack-2'])

    # ---- the stamp, and the containment rule ----------------------------
    tok  = 'MDL 96120 E'
    mine = FakePage.new('MDL 96120 E 02-front',
                        { 'token' => tok, 'plate' => '02-front', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # RENAMED BY HAND. Same stamp, different name. Matched on the stamp, so it
    # is updated -- and never renamed back.
    ren  = FakePage.new('Hero shot for Steve',
                        { 'token' => tok, 'plate' => '01-angled', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # A HAND-MADE SCENE WEARING THE EXPECTED NAME AND NO STAMP. Nothing in
    # this tool may touch it, Remove included.
    fake = FakePage.new('MDL 96120 E 03-high')
    other = FakePage.new('MDL 4872 E 02-front',
                         { 'token' => 'MDL 4872 E', 'plate' => '02-front',
                           'version' => 1, 'centre' => '0.000,0.000,0.000' })
    pages = [mine, fake, ren, other]
    got = WR_AutoSet.token_pages(pages, tok)
    ck('sm1', got.length == 2, got.map { |p| p.name }.inspect)
    ck('sm2', !got.include?(fake), 'an UNSTAMPED page was matched')
    ck('sm3', got.include?(ren), 'a page renamed by hand was not matched')
    ck('sm4', WR_AutoSet.page_for_plate(pages, tok, '01-angled') == ren)
    ck('sm5', WR_AutoSet.page_for_plate(pages, tok, '03-high').nil?,
       'the unstamped page was returned for a plate it happens to be named after')
    ck('sm6', WR_AutoSet.tokens_in_use(pages) == [tok, 'MDL 4872 E'],
       WR_AutoSet.tokens_in_use(pages).inspect)
    ck('sm7', WR_AutoSet.page_stamp(fake).nil?)
    ck('sm8', WR_AutoSet.page_stamp(mine)['plate'] == '02-front')
    ck('sm9', WR_AutoSet.auto_named?(mine, 'MDL 96120 E') == true &&
              WR_AutoSet.auto_named?(ren, 'MDL 96120 E') == false &&
              WR_AutoSet.auto_named?(fake, 'MDL 96120 E') == false,
       'auto_named? does not tell the tool\'s own name from a hand-typed one')

    # ---- THE 1.56.0 RENUMBERING, AND THE SETS ALREADY OUT THERE ----------
    # Benton has real models carrying 1.53-1.55 sets stamped 01-front /
    # 02-angled / 02-angled r. An Update must FIND those pages for the shots
    # they still are, not create a second copy beside them and call the
    # originals stale. That is the highest-risk part of the renumbering.
    old_tok = 'MDL 4872 E OLD'
    o_front = FakePage.new('MDL 4872 E OLD 01-front',
                           { 'token' => old_tok, 'plate' => '01-front', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    o_ang   = FakePage.new('MDL 4872 E OLD 02-angled',
                           { 'token' => old_tok, 'plate' => '02-angled', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    o_angr  = FakePage.new('MDL 4872 E OLD 02-angled r',
                           { 'token' => old_tok, 'plate' => '02-angled r', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    o_high  = FakePage.new('MDL 4872 E OLD 03-high',
                           { 'token' => old_tok, 'plate' => '03-high', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    # A 1.48 id with NO successor in this table: genuinely stale.
    o_dim   = FakePage.new('MDL 4872 E OLD 02-dimensioned',
                           { 'token' => old_tok, 'plate' => '02-dimensioned', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    old_pages = [o_front, o_ang, o_angr, o_high, o_dim]
    ck('mg1', WR_AutoSet.page_for_plate(old_pages, old_tok, '02-front') == o_front,
       'the old 01-front page was not found for 02-front')
    ck('mg2', WR_AutoSet.page_for_plate(old_pages, old_tok, '01-angled') == o_ang)
    ck('mg3', WR_AutoSet.page_for_plate(old_pages, old_tok, '01-angled r') == o_angr,
       'the old angled render half was not found for 01-angled r')
    # A page ALREADY on the new id wins over one still on the old id.
    n_front = FakePage.new('MDL 4872 E OLD 02-front',
                           { 'token' => old_tok, 'plate' => '02-front', 'version' => 1,
                             'centre' => '0.000,0.000,0.000' })
    ck('mg4', WR_AutoSet.page_for_plate(old_pages + [n_front], old_tok, '02-front') == n_front)
    # Only RENUMBERED is followed -- nothing is guessed from a name.
    ck('mg4b', WR_AutoSet.page_for_plate(old_pages, old_tok, '02-front r').nil?,
       'a render half was matched to a page that never had one')
    # STALE IS ONLY WHAT HAS NO SUCCESSOR. The renumbered ids are live.
    st = WR_AutoSet.stale_plates(old_pages, old_tok)
    ck('mg5', st == [o_dim], st.map { |p| p.name }.inspect)
    ck('mg6', WR_AutoSet::RENUMBERED.values.all? { |v| WR_AutoSet.live_plate?(v) } &&
              WR_AutoSet::RENUMBERED.keys.all? { |k| WR_AutoSet.live_plate?(k) } &&
              !WR_AutoSet.live_plate?('02-dimensioned') &&
              !WR_AutoSet.live_plate?('07-interior r'),
       WR_AutoSet::RENUMBERED.inspect)
    # The old name IS the tool's own name for the old plate, so Update may
    # renumber it; a hand-typed one it may not.
    ck('mg7', WR_AutoSet.auto_named?(o_front, 'MDL 4872 E OLD') == true)
    # EXTRA: a run at 0 renders does not ask for the angled render half, so
    # the old '02-angled r' page is neither written nor stale -- it is left
    # alone and NAMED. run_ids is what plan and apply both ask.
    ids0 = WR_AutoSet.run_ids({ 'renders' => 0 })
    ex = WR_AutoSet.extra_pages(old_pages, old_tok, ids0)
    ck('mg8', ex == [o_angr], ex.map { |p| p.name }.inspect)
    ids1 = WR_AutoSet.run_ids({ 'renders' => 1 })
    ck('mg9', WR_AutoSet.extra_pages(old_pages, old_tok, ids1) == [],
       WR_AutoSet.extra_pages(old_pages, old_tok, ids1).map { |p| p.name }.inspect)
    ck('mg10', ids0 == IMAGES && ids1 == ONE &&
               WR_AutoSet.run_ids({}) == DEFAULTS &&
               WR_AutoSet.run_ids({ 'plates' => ['06-plan'] }) == ['06-plan'],
       [ids0, ids1].inspect)

    # ---- has the booth moved? -------------------------------------------
    ck('mv1', WR_AutoSet.centre_key([1.5, -2.25, 0]) == '1.500,-2.250,0.000',
       WR_AutoSet.centre_key([1.5, -2.25, 0]))
    ck('mv2', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [10.0, 20.0, 30.0]) == false)
    ck('mv3', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [46.0, 20.0, 30.0]) == true)
    ck('mv4', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [10.5, 20.0, 30.0]) == false)
    # An unreadable stored centre is UNKNOWN, not MOVED: pre-ticking a re-aim
    # on no evidence would destroy a framing Benton fixed by hand.
    ck('mv5', WR_AutoSet.centre_moved?('', [10.0, 20.0, 30.0]) == false)

    # ---- THE PLATE ORDER (1.56.0) ---------------------------------------
    # Benton, 11 Sep 2026: angled first, then front, high, side, ventilation,
    # plan. The numeric prefix IS the position, so 01-front became 02-front
    # and 02-angled became 01-angled. A mutant that puts the table back to
    # front-first fails here BY NAME.
    base = WR_AutoSet::PLATES.map { |p| p[:id] }
    ck('or1', base == IMAGES + ['07-interior'], base.inspect)
    ck('or2', base.first == '01-angled', base.first.inspect)
    ck('or3', base[1] == '02-front', base[1].inspect)
    # Every id's number is its 1-based position in the table.
    ck('or4', base.each_with_index.all? { |id, i| id.start_with?(format('%%02d-', i + 1)) },
       base.inspect)
    # NO PLATE RE-TARGETS ONTO THE DOOR FRAME ANY MORE (1.65.0). 1.51.x gave
    # 02-front :aim_at => :door for "It should be in front of the door
    # frame"; on a 12'-2" booth with the door in one end that centres the
    # DOOR and leaves bare wall down one side of the frame, which is what
    # Benton asked to change on 11 Sep 2026 ("be centered on that booth walls
    # face? Rather than on door?"). The :aim_at MECHANISM is left in
    # aim_plate, unused -- re-enabling it is one key in the table -- and
    # fm8/fm9 now pin that an anchor handed in IS IGNORED.
    pf = WR_AutoSet.plate('02-front')
    pa = WR_AutoSet.plate('01-angled')
    ck('or5', !pf.nil? && !pa.nil? && pf[:aim_at].nil? && pa[:aim_at].nil?,
       [pf, pa].inspect)

    # ---- the render ladder ----------------------------------------------
    # A RENDER IS AN EXTRA SCENE IN FRONT OF ITS IMAGE, walked down the plate
    # order. The count shapes the id LIST; it converts nothing.
    #
    # ZERO MEANS ZERO. Benton, 11 Sep 2026: "When I click '0' renders, it
    # still makes one though. Lets get that situated." The angled render is
    # no longer forced.
    ck('ld1', WR_AutoSet.plate_ids(false, 0) == IMAGES, WR_AutoSet.plate_ids(false, 0).inspect)
    ck('ld2', WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, 0)) == [],
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, 0)).inspect)
    # ONE: the angled render leads, then the six images. "the 1st scene would
    # be render angled. 2nd scene would be image angled. 3rd scene image
    # front".
    ck('ld3', WR_AutoSet.plate_ids(false, 1) == ONE, WR_AutoSet.plate_ids(false, 1).inspect)
    # TWO: "it would add a rendered front" -- directly before the front image.
    ck('ld4', WR_AutoSet.plate_ids(false, 2) ==
              ['01-angled r', '01-angled', '02-front r', '02-front', '03-high',
               '04-side', '05-ventilation', '06-plan'],
       WR_AutoSet.plate_ids(false, 2).inspect)
    # THREE: "if 3 were added, it would add a rendered high."
    p3 = WR_AutoSet.plate_ids(false, 3)
    ck('ld5', p3.include?('03-high r') && p3.index('03-high r') == p3.index('03-high') - 1 &&
              !p3.include?('04-side r'),
       p3.inspect)
    # SIX is every image led by its render; past six is still six.
    ck('ld6', WR_AutoSet.plate_ids(false, 6).length == 12 &&
              WR_AutoSet.plate_ids(false, 99) == WR_AutoSet.plate_ids(false, 6),
       WR_AutoSet.plate_ids(false, 99).inspect)
    ck('ld7', WR_AutoSet.plate_ids(false, -1) == IMAGES)
    # AN IMAGE PLATE IS NEVER A RENDER, at any count: the count adds scenes.
    ck('ld8', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                ids = WR_AutoSet.plate_ids(true, n)
                rs  = WR_AutoSet.render_ids(ids)
                IMAGES.all? { |id| WR_AutoSet.mode_for(id, rs) == 'image' }
              end,
       'an image plate came out as a render')
    ck('ld9', WR_AutoSet.mode_for('01-angled r', WR_AutoSet.render_ids(DEFAULTS)) == 'render')
    # THREE BY DEFAULT (1.63.0). The old ladder defaulted to two (forced
    # angled + ventilation), 1.56.0 cut it to one, and Benton asked for
    # three -- angled, front, high. Every render is V-Ray time on every
    # un-touched run, so if this number moves again it moved because
    # someone changed what a default run COSTS, and this check is where
    # they have to say so.
    ck('ld10', WR_AutoSet::DEFAULT_RENDERS == 3)
    ck('ld11', WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false)).length == 3 &&
               WR_AutoSet.plate_ids(false) == DEFAULTS,
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false)).inspect)
    # THE LADDER IS THE PLATE ORDER. Not a separate priority list any more.
    ck('ld12', WR_AutoSet::RENDER_LADDER == IMAGES, WR_AutoSet::RENDER_LADDER.inspect)
    # THE COUNT MEANS WHAT IT SAYS: n renders is n render scenes, and the six
    # images are always all there.
    ck('ld13', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                 ids = WR_AutoSet.plate_ids(false, n)
                 WR_AutoSet.render_ids(ids).length == n &&
                   (ids - WR_AutoSet.render_ids(ids)) == IMAGES
               end,
       (0..6).map { |n| WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, n)).length }.inspect)
    # EVERY RENDER SITS IMMEDIATELY BEFORE ITS IMAGE, at every count.
    ck('ld14', (1..WR_AutoSet::MAX_RENDERS).all? do |n|
                 ids = WR_AutoSet.plate_ids(false, n)
                 WR_AutoSet.render_ids(ids).all? do |r|
                   ids.index(r) == ids.index(WR_AutoSet.base_id(r)) - 1
                 end
               end,
       WR_AutoSet.plate_ids(false, 6).inspect)
    # The plates promoted at n are the FIRST n in plate order.
    ck('ld15', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                 WR_AutoSet.ladder_renders(n) == IMAGES.first(n)
               end,
       WR_AutoSet.ladder_renders(3).inspect)
    ck('ld16', WR_AutoSet::MAX_RENDERS == 6)

    # ---- THE INTERIOR: EXTRA, ALWAYS A RENDER, NEVER COUNTED -------------
    # Benton, 10 Sep 2026: "fyi interior plate should always be a render."
    # And 11 Sep 2026, asked whether it counts against the number typed:
    # "No, interior is extra and always a render."
    ck('fr1', WR_AutoSet.mode_for('07-interior',
                                  WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, 0))) == 'render',
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, 0)).inspect)
    ck('fr2', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, n)).include?('07-interior')
              end,
       'the interior plate can come out as an image')
    # EXTRA: exactly one more scene than the same run without it, and last.
    ck('fr3', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                with = WR_AutoSet.plate_ids(true, n)
                with.length == WR_AutoSet.plate_ids(false, n).length + 1 &&
                  with.last == '07-interior' &&
                  with[0...-1] == WR_AutoSet.plate_ids(false, n)
              end,
       WR_AutoSet.plate_ids(true, 2).inspect)
    # NOT COUNTED: knob n plus the box is n + 1 renders, the ladder's n
    # untouched.
    ck('fr4', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, n)).length == n + 1
              end,
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, 2)).inspect)
    ck('fr5', !WR_AutoSet::RENDER_LADDER.include?('07-interior'),
       WR_AutoSet::RENDER_LADDER.inspect)
    # COST, SAID OUT LOUD. The ONLY render that is not a paired render scene
    # sits on a plate that is OFF by default. A forced render on an always-on
    # plate raises the floor of every run -- that is the 1.53-1.55 angled
    # behaviour Benton asked to have removed, and this check is what makes
    # putting it back a decision rather than an accident.
    ck('fr6', WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, 6)).all? do |id|
                WR_AutoSet.dual_render?(id) || WR_AutoSet.plate(id)[:on] == false
              end,
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, 6)).inspect)
    # THE FLOOR OF A ZERO-RENDER RUN IS ZERO. This is item 1 of the 11 Sep
    # spec, pinned.
    ck('fr7', WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, 0)).length == 0,
       WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, 0)).inspect)
    # The interior never grows a paired render of its own.
    ck('fr8', (0..WR_AutoSet::MAX_RENDERS).none? do |n|
                WR_AutoSet.plate_ids(true, n).include?('07-interior r')
              end &&
              !WR_AutoSet.dual_render?('07-interior r') &&
              WR_AutoSet.plate('07-interior r').nil?,
       'the interior grew a render half')

    # ---- THE IMAGE/RENDER PAIR -------------------------------------------
    # Benton, 10 Sep 2026: "I also always want a regular image at angled, and
    # a render at angled. Should be the same scene, except with the render
    # setting." -- now the rule for every ladder plate.
    ck('du1', WR_AutoSet.plate_ids(false) == DEFAULTS, WR_AutoSet.plate_ids(false).inspect)
    # ADJACENT, RENDER FIRST (1.56.0 -- this was image-first until then).
    ck('du2', WR_AutoSet.plate_ids(false).index('01-angled r') ==
              WR_AutoSet.plate_ids(false).index('01-angled') - 1,
       WR_AutoSet.plate_ids(false).inspect)
    # ONE IMAGE, ONE RENDER at every count of one or more.
    ck('du3', (1..WR_AutoSet::MAX_RENDERS).all? do |n|
                rs = WR_AutoSet.render_ids(WR_AutoSet.plate_ids(false, n))
                rs.include?('01-angled r') && !rs.include?('01-angled')
              end,
       'the angled pair is not exactly one image and one render')
    # THE SAME SHOT. Both halves resolve to the SAME plate row, which is what
    # makes their camera, walls and annotations identical without anything
    # having to keep them in step.
    ck('du4', WR_AutoSet.plate('01-angled r').equal?(WR_AutoSet.plate('01-angled')) &&
              WR_AutoSet.plate('06-plan r').equal?(WR_AutoSet.plate('06-plan')),
       'the two halves resolve to different plate rows')
    # THE SUFFIX IS SEEN THROUGH by the annotation rule -- on the pair that
    # actually names a note set, so a raw-id lookup cannot pass by accident.
    ck('du5', shown_on_equal?('05-ventilation', '05-ventilation r') &&
              shown_on('05-ventilation r').include?('WR-Notes-Vent') &&
              shown_on_equal?('01-angled', '01-angled r'),
       [shown_on('05-ventilation'), shown_on('05-ventilation r')].inspect)
    # ... and by the wall rule: the plan's render hides no walls either.
    wp_r = WR_AutoSet.wall_picks('06-plan r',
                                 [{ 'key' => 'w:x', 'c' => [50.0, 0.0, 40.0] }],
                                 [0.0, 0.0, 0.0], [97.8, 0.0, 20.8])
    ck('du5b', wp_r == { 'w:x' => false }, wp_r.inspect)
    # Identical cameras, measured -- not asserted from the shared row.
    ia = shot('01-angled')
    ra = shot('01-angled r')
    ck('du6', (ia['az'] - ra['az']).abs < 1.0e-12 &&
              (ia['run'] - ra['run']).abs < 1.0e-12 &&
              (ia['z'] - ra['z']).abs < 1.0e-12,
       [ia, ra].inspect)
    fi = shot('02-front')
    fr = shot('02-front r')
    ck('du6b', (fi['az'] - fr['az']).abs < 1.0e-12 &&
               (fi['run'] - fr['run']).abs < 1.0e-12 &&
               (fi['z'] - fr['z']).abs < 1.0e-12,
       [fi, fr].inspect)
    # The stamp key stays UNIQUE PER PAGE, which is what identity needs.
    ck('du7', WR_AutoSet.scene_name('MDL 4872 E', '01-angled r') ==
              'MDL 4872 E 01-angled r',
       WR_AutoSet.scene_name('MDL 4872 E', '01-angled r'))
    ck('du8', WR_AutoSet.scene_name('MDL 4872 E', '01-angled') !=
              WR_AutoSet.scene_name('MDL 4872 E', '01-angled r'))
    # 'xx r' for something that is not a ladder plate resolves to nothing
    # rather than silently aliasing.
    ck('du9', !WR_AutoSet.dual_render?('zz r') && WR_AutoSet.plate('zz r').nil? &&
              WR_AutoSet.plate('01-angled rr').nil?,
       'a non-plate grew a render half')
    ck('du10', WR_AutoSet.dual_render?('01-angled r') &&
               !WR_AutoSet.dual_render?('01-angled') &&
               WR_AutoSet.dual_render?('06-plan r'))
    # THE FILENAME DOES NOT DOUBLE THE MARKER. proposal-package.rb appends its
    # mark only when the name does not already end in it.
    ck('du11', WR_AutoSet::DUAL_SUFFIX == ' r', WR_AutoSet::DUAL_SUFFIX.inspect)
    ck('du12', WR_AutoSet.base_id('02-front r') == '02-front' &&
               WR_AutoSet.base_id('02-front') == '02-front' &&
               WR_AutoSet.dual_render_id('02-front') == '02-front r')

    # ---- the plate azimuths ---------------------------------------------
    # THE DOOR IS THE ANCHOR for everything except the vent shot. Benton:
    # "Find the door, step out like 15 ft or so. Straight on."
    ck('az1', WR_AutoSet.az_for('02-front', 12.0, nil) == 12.0,
       WR_AutoSet.az_for('02-front', 12.0, nil).inspect)
    ck('az2', WR_AutoSet.az_for('01-angled', 0.0, nil) == 35.0)
    ck('az3', WR_AutoSet.az_for('03-high', 0.0, nil) == 35.0)
    ck('az4', WR_AutoSet.az_for('05-ventilation', 0.0, 90.0) == 115.0)
    # No WR-Booth-Vent: the vent plate is just the opposite side, plus swing.
    ck('az5', WR_AutoSet.az_for('05-ventilation', 0.0, nil) == 205.0,
       WR_AutoSet.az_for('05-ventilation', 0.0, nil).inspect)
    # No WR-Booth-Door at all: the documented -90 fallback, which is exactly
    # the case the popover says out loud in orange BEFORE Apply.
    ck('az6', WR_AutoSet.az_for('02-front', nil, nil) == -90.0)
    ck('az7', WR_AutoSet.az_for('06-plan', 12.0, nil) == 12.0)
    # NO PLATE CARRIES A PROJECTION KEY ANY MORE. A :persp key is the shape
    # that lets parallel projection creep back in one plate at a time.
    ck('az8', ALL.all? { |id| WR_AutoSet.plate(id)[:persp].nil? },
       'a plate is still carrying a :persp key')
    ck('az9', WR_AutoSet.plate_ids(false) == DEFAULTS, WR_AutoSet.plate_ids(false).inspect)
    ck('az10', WR_AutoSet.plate_ids(true) == ALL)
    # The interior plate's NAME has to keep matching proposal-package.rb's
    # INTERIOR_RE or the render row is silently mis-exposed.
    ck('az11', ('07-interior' =~ /interior|inside|in-booth|booth\s+in/i) ? true : false)

    # ---- THE SIDE PLATE PICKS ITS SIDE (1.57.0) -------------------------
    # Benton, 11 Sep 2026: "if it can always choose the side with more to
    # look at, a window is priority, then that would be ideal". The fixture
    # booth's door faces -Y (door normal [0, -1]), so door +90 is the +X wall
    # and door -90 is the -X wall.
    dax   = [0.0, -1.0]
    plusx = [1.0, 0.0]
    minx  = [-1.0, 0.0]
    ck('sd1', WR_AutoSet.side_normals(dax) == [plusx, minx],
       WR_AutoSet.side_normals(dax).inspect)
    # A part is placed in a wall by its SHAPE (wall_normal) and kept out of
    # the count when it is not thin across that wall. A 2 in panel on the +X
    # wall of a 50 x 74 booth; the same panel on the -X wall; a 50 x 74 floor
    # deck (aspect 1.5, not a wall); and a 48 x 120 deck on a long booth,
    # which wall_normal WOULD call a Y wall and the thin-span guard rejects.
    ck('sd2', WR_AutoSet.part_wall(2.0, 46.0, 24.0, 0.0, 50.0, 74.0) == plusx &&
              WR_AutoSet.part_wall(2.0, 46.0, -24.0, 5.0, 50.0, 74.0) == minx &&
              WR_AutoSet.part_wall(46.0, 2.0, 0.0, -36.0, 50.0, 74.0) == dax,
       [WR_AutoSet.part_wall(2.0, 46.0, 24.0, 0.0, 50.0, 74.0),
        WR_AutoSet.part_wall(2.0, 46.0, -24.0, 5.0, 50.0, 74.0)].inspect)
    ck('sd3', WR_AutoSet.part_wall(50.0, 74.0, 0.0, 0.0, 50.0, 74.0).nil? &&
              WR_AutoSet.part_wall(48.0, 120.0, 0.0, 0.0, 48.0, 120.0).nil?,
       WR_AutoSet.part_wall(48.0, 120.0, 0.0, 0.0, 48.0, 120.0).inspect)
    pt = lambda do |name, wall|
      { 'name' => name, 'key' => name.sub(/\A\w+i?\s+/, '').sub(/_HX\z/i, '').downcase,
        'wall' => wall }
    end
    solid_p = pt.call('E0  22PanelSolid', plusx)
    solid_p2 = pt.call('E1  22PanelSolid', plusx)      # same key: counts once
    solid_m = pt.call('W0  22PanelSolid', minx)
    win_m   = pt.call('W1  46Panel3236WDO', minx)
    win_p   = pt.call('E1  46Panel3236WDO', plusx)
    vent_m  = pt.call('W1  40VNT', minx)
    duct_m  = pt.call('W1 duct  Duct Cover', minx)
    back    = pt.call('N0  46PanelSolid', [0.0, 1.0])  # the vent wall: not a candidate
    # NOTHING TO CHOOSE BETWEEN: the pre-1.57.0 behaviour, door +90, and the
    # log says so. This is the usual booth and it must not change.
    e0 = WR_AutoSet.pick_side([], dax)
    ck('sd4', e0['sign'] == 1 && e0['ax'] == plusx && e0['why'].include?('+90'),
       e0.inspect)
    # A WINDOW WINS, on either side, over any number of other parts.
    w1 = WR_AutoSet.pick_side([solid_p, solid_p2, vent_m, win_m, back], dax)
    ck('sd5', w1['sign'] == -1 && w1['ax'] == minx &&
              w1['why'].include?('window') && w1['why'].include?('46Panel3236WDO'),
       w1.inspect)
    w2 = WR_AutoSet.pick_side([win_p, solid_m, vent_m, duct_m], dax)
    ck('sd6', w2['sign'] == 1 && w2['ax'] == plusx && w2['why'].include?('1 window'),
       w2.inspect)
    # A WINDOW ON BOTH SIDES, otherwise equal: a tie, door +90, and the log
    # names both windows.
    w3 = WR_AutoSet.pick_side([win_p, solid_p, win_m, solid_m], dax)
    ck('sd7', w3['sign'] == 1 && w3['why'].include?('BOTH') && w3['why'].include?('+90'),
       w3.inspect)
    # A WINDOW ON BOTH SIDES, one side with more distinct parts: that side.
    w4 = WR_AutoSet.pick_side([win_p, solid_p, win_m, solid_m, vent_m], dax)
    ck('sd8', w4['sign'] == -1 && w4['why'].include?('BOTH') &&
              w4['why'].include?('2 distinct part(s) against 1') == false &&
              w4['why'].include?('3 distinct part(s) against 2'),
       w4.inspect)
    # NO WINDOW EITHER SIDE: more distinct parts wins, either way round.
    n1 = WR_AutoSet.pick_side([solid_p, solid_p2, solid_m, vent_m, duct_m], dax)
    ck('sd9', n1['sign'] == -1 && n1['why'].include?('no window') &&
              n1['why'].include?('3 distinct part(s) against 1'),
       n1.inspect)
    n2 = WR_AutoSet.pick_side([solid_p, pt.call('E1  40VNT', plusx), solid_m], dax)
    ck('sd10', n2['sign'] == 1 && n2['why'].include?('2 distinct part(s) against 1'),
       n2.inspect)
    # TWO IDENTICAL PANELS ARE ONE THING TO LOOK AT, so they do not beat one
    # panel on the other side; and an _HX twin is the same part.
    n3 = WR_AutoSet.pick_side([solid_p, solid_p2, pt.call('E2  22PanelSolid_HX', plusx),
                               solid_m], dax)
    ck('sd11', n3['sign'] == 1 && n3['plus']['distinct'] == 1 && n3['why'].include?('tie'),
       n3.inspect)
    # THE SIGN REACHES THE SIDE PLATE AND ONLY THE SIDE PLATE. A mutant that
    # goes back to the unconditional +90 fails sd12 and sd15 by name.
    ck('sd12', WR_AutoSet.az_for('04-side', 0.0, nil) == 90.0 &&
               WR_AutoSet.az_for('04-side', 0.0, nil, 1) == 90.0 &&
               WR_AutoSet.az_for('04-side', 0.0, nil, -1) == -90.0 &&
               WR_AutoSet.az_for('04-side r', 0.0, nil, -1) == -90.0,
       [WR_AutoSet.az_for('04-side', 0.0, nil, -1),
        WR_AutoSet.az_for('04-side r', 0.0, nil, -1)].inspect)
    # 1.68.0: THE THREE-QUARTER PLATES SWING WITH THE SIDE PICK TOO. Benton,
    # 12 Sep 2026, on a pack whose side AND angled plates both went the wrong
    # way: "Same with the angled view ... it should kind of auto decide to go
    # towards the side where there's more features such as a window." Before
    # this, 01-angled and 03-high kept a fixed +35 whatever 04-side chose, so
    # the hero and the side elevation could disagree about the booth by
    # construction.
    ck('sd13', WR_AutoSet.az_for('01-angled', 0.0, nil, -1) == -35.0 &&
               WR_AutoSet.az_for('03-high', 0.0, nil, -1) == -35.0 &&
               WR_AutoSet.az_for('01-angled r', 0.0, nil, -1) == -35.0 &&
               WR_AutoSet.az_for('01-angled', 0.0, nil, 1) == 35.0 &&
               WR_AutoSet.az_for('03-high', 0.0, nil, 1) == 35.0,
       [WR_AutoSet.az_for('01-angled', 0.0, nil, -1),
        WR_AutoSet.az_for('03-high', 0.0, nil, -1)].inspect)
    # THE DOOR REFERENCE IS NOT OVERRIDDEN. The side pick governs which way a
    # plate SWINGS FROM the door, never what the door is: every plate with no
    # swing is unmoved by it, so the front stays square to the door wall and
    # the plan stays straight down. 05-ventilation reads its own bearing.
    ck('sd13b', WR_AutoSet.az_for('02-front', 0.0, nil, -1) == 0.0 &&
                WR_AutoSet.az_for('06-plan', 0.0, nil, -1) == 0.0 &&
                WR_AutoSet.az_for('07-interior', 0.0, nil, -1) == 0.0 &&
                WR_AutoSet.az_for('05-ventilation', 0.0, 90.0, -1) == 115.0,
       'the side sign moved a plate that does not swing off the door')
    # WHICH PLATES FOLLOW IT, stated as the property rather than a list.
    ck('sd13c', WR_AutoSet.side_swung?('01-angled') &&
                WR_AutoSet.side_swung?('03-high') &&
                WR_AutoSet.side_swung?('04-side') &&
                WR_AutoSet.side_swung?('04-side r') &&
                !WR_AutoSet.side_swung?('02-front') &&
                !WR_AutoSet.side_swung?('06-plan') &&
                !WR_AutoSet.side_swung?('07-interior') &&
                !WR_AutoSet.side_swung?('05-ventilation') &&
                !WR_AutoSet.side_swung?('nonesuch'),
       'side_swung? no longer names exactly the door-referenced swinging plates')
    # THE SIGN IS RE-DERIVED FROM THE CHOSEN WALL'S MODEL BEARING, so a
    # mirrored placement cannot swap hands; and it wraps at +/-180.
    ck('sd14', WR_AutoSet.side_sign(0.0, -90.0) == 1 &&
               WR_AutoSet.side_sign(180.0, -90.0) == -1 &&
               WR_AutoSet.side_sign(-180.0, -90.0) == -1 &&
               WR_AutoSet.side_sign(-170.0, 90.0) == 1 &&
               WR_AutoSet.side_sign(90.0, 0.0) == 1 &&
               WR_AutoSet.side_sign(-90.0, 0.0) == -1,
       [WR_AutoSet.side_sign(-180.0, -90.0), WR_AutoSet.side_sign(-170.0, 90.0)].inspect)
    # THROUGH THE REAL aim(): the side eye stands at door -90 when told to,
    # and at door +90 by default -- the fixture door is -90, so 180 and 0.
    ss = shot('04-side', DOOR, VENT, -1)
    sd = shot('04-side')
    ck('sd15', (ss['az'].abs - 180.0).abs < 1.0e-6 && sd['az'].abs < 1.0e-6,
       [ss['az'], sd['az']].inspect)
    # NO DOOR: nothing is chosen, the sign is +1, and the words say ASSUMED.
    nd = WR_AutoSet.pick_side([win_m, solid_p], nil)
    ck('sd16', nd['sign'] == 1 && nd['ax'].nil? && nd['why'].include?('ASSUMED'),
       nd.inspect)
    # THE LOG LINE: which side, at what bearing, and why -- in plain words.
    l1 = WR_AutoSet.side_line(w1.merge('az' => 180.0), 180.0)
    ck('sd17', l1.include?('side: door -90') && l1.include?('180.0 deg') &&
               l1.include?('window'), l1)
    l2 = WR_AutoSet.side_line(e0.merge('az' => 0.0), 0.0)
    ck('sd18', l2.include?('side: door +90') && l2.include?('+90 as before'), l2)
    ck('sd19', WR_AutoSet.side_line(nd, nil).include?('ASSUMED'),
       WR_AutoSet.side_line(nd, nil))
    ck('sd20', WR_AutoSet::SIDE_PLATE == '04-side' &&
               ('46Panel3236WDO' =~ WR_AutoSet::WINDOW_RE ? true : false) &&
               ('STDWL46 WDO3236' =~ WR_AutoSet::WINDOW_RE ? true : false) &&
               ('40VNT' =~ WR_AutoSet::WINDOW_RE).nil? &&
               ('Right46Door' =~ WR_AutoSet::WINDOW_RE).nil?,
       'WINDOW_RE no longer matches the WDO panel names and only them')

    # ---- THE VENT PLATE PICKS ITS WALL AND ITS SWING (1.57.1) -----------
    # Benton's MDL 96144 E: "Right (E0), Back (N0), Back (N1), Back (N2)" --
    # one vent on the +X wall, three on +Y, the +X one placed FIRST, which is
    # the order the old first-found tie went to. The door is on -Y.
    plusy = [0.0, 1.0]
    vp = lambda { |name, wall| { 'name' => name, 'wall' => wall } }
    e0 = vp.call('E0  40VNT', plusx)
    n0 = vp.call('N0  40VNT', plusy)
    n1 = vp.call('N1  40VNT', plusy)
    n2 = vp.call('N2  40VNT', plusy)
    w0 = vp.call('W0  40VNT', minx)
    s0 = vp.call('S0  40VNT', dax)
    # THE WALL WITH THREE ANCHORS THE SHOT, whichever part came first.
    b = WR_AutoSet.pick_vent([e0, n0, n1, n2], dax)
    ck('vt1', b['ax'] == plusy && b['n'] == 3, b.inspect)
    ck('vt2', WR_AutoSet.pick_vent([n0, n1, n2, e0], dax)['ax'] == plusy &&
              WR_AutoSet.pick_vent([n0, e0, n1, n2], dax)['ax'] == plusy,
       'the order the parts are walked in changed the answer')
    # THE SWING TURNS TOWARD THE SINGLE VENT: +X is +Y turned -90 (clockwise
    # in plan), so the local shift is -1; and the mirror case is +1.
    ck('vt3', b['sec'] == plusx && b['shift'] == -1, b.inspect)
    bm = WR_AutoSet.pick_vent([w0, n0, n1, n2], dax)
    ck('vt4', bm['sec'] == minx && bm['shift'] == 1, bm.inspect)
    # THE WORDS: which wall, how many on each, which way and why.
    ck('vt5', b['why'].include?('opposite the door') && b['why'].include?('3 (N0  40VNT, N1  40VNT, N2  40VNT)') &&
              b['why'].include?('against 1 on the door +90 wall (E0  40VNT)') &&
              b['why'].include?('swings toward the door +90 wall'),
       b['why'])
    # EVERY VENT ON ONE WALL: nothing to swing toward, +swing as before. The
    # common case and it must not move.
    one = WR_AutoSet.pick_vent([n0, n1], dax)
    ck('vt6', one['ax'] == plusy && one['sec'].nil? && one['shift'] == 1 &&
              one['why'].include?('as before'), one.inspect)
    # THE OTHER VENT ON THE WALL OPPOSITE: primary kept, swing +, said so.
    opp = WR_AutoSet.pick_vent([n0, n1, s0], dax)
    ck('vt7', opp['ax'] == plusy && opp['sec'].nil? && opp['shift'] == 1 &&
              opp['why'].include?('no single bearing shows both'), opp.inspect)
    # A TIE resolves the same way every run: opposite the door beats a side
    # wall, a side wall beats the door wall, and the log says it was a tie.
    t1 = WR_AutoSet.pick_vent([e0, n0], dax)
    t2 = WR_AutoSet.pick_vent([n0, e0], dax)
    ck('vt8', t1['ax'] == plusy && t2['ax'] == plusy && t1['why'].include?('tie') &&
              t1['sec'] == plusx && t1['shift'] == -1, [t1['ax'], t2['ax']].inspect)
    t3 = WR_AutoSet.pick_vent([e0, s0], dax)
    ck('vt9', t3['ax'] == plusx && WR_AutoSet.pick_vent([s0, e0], dax)['ax'] == plusx, t3.inspect)
    t4 = WR_AutoSet.pick_vent([e0, w0], dax)
    ck('vt10', t4['ax'] == plusx && WR_AutoSet.pick_vent([w0, e0], dax)['ax'] == plusx &&
               t4['sec'].nil?, t4.inspect)
    # NO DOOR KNOWN: the fixed order still decides, deterministically.
    ck('vt11', WR_AutoSet.pick_vent([e0, w0], nil)['ax'] == plusx &&
               WR_AutoSet.pick_vent([w0, e0], nil)['ax'] == plusx &&
               WR_AutoSet.pick_vent([e0, n0], nil)['ax'] == plusy,
       WR_AutoSet.pick_vent([w0, e0], nil).inspect)
    # NOTHING IN A WALL: nil, ASSUMED, and the unplaced parts are named.
    nv = WR_AutoSet.pick_vent([vp.call('Roof VNT', nil)], dax)
    ck('vt12', nv['ax'].nil? && nv['shift'] == 1 && nv['why'].include?('ASSUMED') &&
               nv['why'].include?('Roof VNT'), nv.inspect)
    ck('vt13', WR_AutoSet.pick_vent([], dax)['ax'].nil? &&
               WR_AutoSet.pick_vent([], dax)['why'].include?('ASSUMED'))
    lost = WR_AutoSet.pick_vent([n0, vp.call('Roof VNT', nil)], dax)
    ck('vt14', lost['ax'] == plusy && lost['why'].include?('not counted') &&
               lost['why'].include?('Roof VNT'), lost['why'])
    # THE SIGN REACHES THE VENT PLATE AND ONLY THE VENT PLATE, through the
    # real aim(). A mutant back to the unconditional +swing fails vt15/vt16.
    ck('vt15', WR_AutoSet.az_for('05-ventilation', DOOR, VENT) == VENT + 25.0 &&
               WR_AutoSet.az_for('05-ventilation', DOOR, VENT, 1, 1) == VENT + 25.0 &&
               WR_AutoSet.az_for('05-ventilation', DOOR, VENT, 1, -1) == VENT - 25.0 &&
               WR_AutoSet.az_for('05-ventilation r', DOOR, VENT, 1, -1) == VENT - 25.0,
       [WR_AutoSet.az_for('05-ventilation', DOOR, VENT, 1, -1)].inspect)
    vs_m = shot('05-ventilation', DOOR, VENT, 1, -1)
    vs_p = shot('05-ventilation', DOOR, VENT, 1, 1)
    ck('vt16', (vs_m['az'] - (VENT - 25.0)).abs < 1.0e-6 && (vs_p['az'] - (VENT + 25.0)).abs < 1.0e-6,
       [vs_m['az'], vs_p['az']].inspect)
    ck('vt17', WR_AutoSet.az_for('01-angled', 0.0, nil, 1, -1) == 35.0 &&
               WR_AutoSet.az_for('03-high', 0.0, nil, 1, -1) == 35.0 &&
               WR_AutoSet.az_for('04-side', 0.0, nil, 1, -1) == 90.0 &&
               WR_AutoSet.az_for('02-front', 0.0, nil, 1, -1) == 0.0,
       'a plate other than 05-ventilation moved with the vent shift')
    # THE TWO SIGNS DO NOT CROSS. `side` turns the door plates, `vshift` turns
    # the vent plate, and neither reaches the other's plates -- checked
    # together because 1.68.0 widened the first one's reach.
    ck('vt17b', WR_AutoSet.az_for('01-angled', 0.0, nil, -1, 1) == -35.0 &&
                WR_AutoSet.az_for('01-angled', 0.0, nil, -1, -1) == -35.0 &&
                WR_AutoSet.az_for('05-ventilation', 0.0, 90.0, -1, -1) == 65.0 &&
                WR_AutoSet.az_for('05-ventilation', 0.0, 90.0, -1, 1) == 115.0,
       [WR_AutoSet.az_for('01-angled', 0.0, nil, -1, -1),
        WR_AutoSet.az_for('05-ventilation', 0.0, 90.0, -1, -1)].inspect)
    # NO VENT AT ALL still falls back to opposite the door, + swing, as before.
    ck('vt18', WR_AutoSet.az_for('05-ventilation', DOOR, nil, 1, -1) == DOOR + 180.0 - 25.0 &&
               WR_AutoSet.az_for('05-ventilation', DOOR, nil) == DOOR + 180.0 + 25.0,
       WR_AutoSet.az_for('05-ventilation', DOOR, nil, 1, -1).inspect)
    # THE LOG LINE: bearing, the swing's sign and size, and the words.
    vl = WR_AutoSet.vent_line(b.merge('az' => 90.0), 90.0)
    ck('vt19', vl.include?('vent:') && vl.include?('90.0 deg') && vl.include?('swung -25 deg') &&
               vl.include?('3 (N0  40VNT'), vl)
    vl2 = WR_AutoSet.vent_line(one.merge('az' => 90.0), 90.0)
    ck('vt20', vl2.include?('swung +25 deg') && vl2.include?('as before'), vl2)
    ck('vt21', WR_AutoSet.vent_line(nv, nil).include?('ASSUMED') &&
               WR_AutoSet::VENT_PLATE == '05-ventilation', WR_AutoSet.vent_line(nv, nil))

    # ---- THE WALL RULE SAYS WHAT IT HAD (1.57.1) ------------------------
    # Ten plates of "all shown" on Benton's model read like a clean result;
    # it was the rule finding NO wall units at all. That is said in words.
    wl0 = WR_AutoSet.walls_line([], ['Room', 'MDL 96144 E (components)'])
    ck('wl1', wl0.include?('NO wall units') && wl0.include?('NO plate can hide a wall') &&
              wl0.include?('"Wall 1"') && wl0.include?('Room, MDL 96144 E (components)') &&
              wl0.include?('Name walls for the scene picker'), wl0)
    ck('wl2', WR_AutoSet.walls_line([], []).include?('nothing at all'))
    wl1 = WR_AutoSet.walls_line([{ 'room' => 'Room', 'wall' => 1 }, { 'room' => 'Room', 'wall' => 2 },
                                 { 'room' => 'Office', 'wall' => 1 }], ['Room'])
    ck('wl3', wl1.include?('3 wall unit(s)') && wl1.include?('Room: Wall 1, 2') &&
              wl1.include?('Office: Wall 1') && !wl1.include?('NO wall'), wl1)

    # ---- THE CEILING (1.58.1) -------------------------------------------
    # "a 'high' render, it should hide a ceiling as well if it has a
    # ceiling". A booth 96 x 60 x 84 centred at the origin (top z 84) under a
    # take-off ceiling slab at z 96..100 covering 0..240 x 0..192 -- but the
    # booth is at (0,0), so build the boxes around it. Also a floor at z 0, a
    # neighbouring room's ceiling that does not cover the centre, and one
    # squeezed exactly onto the roof.
    cbox  = [-120.0, -96.0, 96.0, 120.0, 96.0, 100.0]
    fbox  = [-120.0, -96.0, 0.0, 120.0, 96.0, 0.0]
    nbox  = [130.0, -96.0, 96.0, 370.0, 96.0, 100.0]
    tight = [-120.0, -96.0, 83.5, 120.0, 96.0, 84.0]
    top_z = 84.0
    ck('cl1', WR_AutoSet.ceiling_over?(cbox, CENTRE, top_z) &&
              !WR_AutoSet.ceiling_over?(fbox, CENTRE, top_z) &&
              !WR_AutoSet.ceiling_over?(nbox, CENTRE, top_z) &&
              WR_AutoSet.ceiling_over?(tight, CENTRE, top_z),
       [WR_AutoSet.ceiling_over?(cbox, CENTRE, top_z), WR_AutoSet.ceiling_over?(fbox, CENTRE, top_z)].inspect)
    ceils = [{ 'key' => 'c:1', 'label' => 'Room Ceiling', 'box' => cbox },
             { 'key' => 'c:2', 'label' => 'Room Floor',   'box' => fbox },
             { 'key' => 'c:3', 'label' => 'Office Ceiling', 'box' => nbox }]
    # THE HIGH PLATE HIDES IT, the floor and the neighbour stay, and every
    # unit is keyed (the partial-hash bug, again).
    hp = WR_AutoSet.ceiling_picks('03-high', ceils, CENTRE, top_z)
    ck('cl2', hp == { 'c:1' => true, 'c:2' => false, 'c:3' => false }, hp.inspect)
    ck('cl3', WR_AutoSet.ceiling_picks('03-high r', ceils, CENTRE, top_z)['c:1'] == true)
    # THE PLAN PLATE HIDES IT TOO -- the coordinator's call, one line to
    # reverse (drop '06-plan' from CEILING_PLATES) and this fails by name.
    pp = WR_AutoSet.ceiling_picks('06-plan', ceils, CENTRE, top_z)
    ck('cl4', pp['c:1'] == true && pp['c:2'] == false && pp.keys.length == 3, pp.inspect)
    # ... and its WALLS are exactly as before: none hidden.
    pw = [{ 'key' => 'w:a', 'c' => [50.0, 0.0, 40.0], 'label' => 'Room Wall 1' },
          { 'key' => 'w:b', 'c' => [0.0, 50.0, 40.0], 'label' => 'Room Wall 2' }]
    ck('cl5', WR_AutoSet.wall_picks('06-plan', pw, CENTRE, [97.8, 0.0, 300.0]).values.none? { |v| v } &&
              WR_AutoSet::NO_WALL_PLATES.include?('06-plan'))
    # THE EYE-HEIGHT PLATES AND THE INTERIOR LEAVE IT ALONE, keyed false.
    q6 = WR_AutoSet.ceiling_picks('01-angled', ceils, CENTRE, top_z)
    ck('cl6', q6.keys.length == 3 && q6.values.none? { |v| v }, q6.inspect)
    ck('cl7', ['02-front', '04-side', '05-ventilation', '07-interior', '01-angled r'].all? { |id|
                q = WR_AutoSet.ceiling_picks(id, ceils, CENTRE, top_z)
                q.keys.length == 3 && q.values.none? { |v| v }
              }, 'a plate other than 03-high / 06-plan hid the ceiling')
    # NO CEILING AT ALL: an empty hash, nothing written, today's behaviour.
    ck('cl8', WR_AutoSet.ceiling_picks('03-high', [], CENTRE, top_z) == {} &&
              WR_AutoSet.ceiling_picks('03-high', nil, CENTRE, top_z) == {})
    # THE LOG, run level: found and hidden on which plates ...
    l1 = WR_AutoSet.ceilings_line(ceils, CENTRE, top_z)
    ck('cl9', l1.include?('ceiling: 1 over the booth') && l1.include?('Room Ceiling (z 96 to 100 in)') &&
              l1.include?('hidden on 03-high and 06-plan') && !l1.include?('Floor'), l1)
    # ... or none, with what it looked for and what it saw instead.
    l0 = WR_AutoSet.ceilings_line([ceils[1], ceils[2]], CENTRE, top_z)
    ck('cl10', l0.include?('ceiling: none over the booth') && l0.include?('12 in thick') &&
               l0.include?('48 in each way') && l0.include?('z 84 in') &&
               l0.include?('2 flat, broad group(s) seen but none qualifies') &&
               l0.include?('Room Floor (z 0 to 0 in)') && l0.include?('will look through'), l0)
    ck('cl11', WR_AutoSet.ceilings_line([], CENTRE, top_z).include?('nothing flat and broad in the model at all'))
    # The per-plate line: on the two plates only.
    ck('cl12', WR_AutoSet.ceiling_line('03-high', ceils, hp) == '         hides ceiling Room Ceiling' &&
               WR_AutoSet.ceiling_line('06-plan r', ceils, pp).to_s.include?('hides ceiling Room Ceiling') &&
               WR_AutoSet.ceiling_line('03-high', [], {}).include?('none hidden') &&
               WR_AutoSet.ceiling_line('01-angled', ceils, hp).nil?,
       WR_AutoSet.ceiling_line('03-high', ceils, hp).inspect)
    # THE RECOGNISER'S SHAPE RULE, as it runs in wr-scene-walls.rb: a slab
    # 4 in thick is a ceiling; a 96 in wall is not; a 36 in door swing is
    # too small; a 20 in deep hung ceiling needs its name to say so; the
    # take-off tag, the drop-lights attribute and the name each count.
    ck('cl13', WR_SceneWalls.ceiling_shape?([0, 0, 96, 240, 192, 100], false) &&
               !WR_SceneWalls.ceiling_shape?([0, 0, 0, 240, 4, 96], false) &&
               !WR_SceneWalls.ceiling_shape?([0, 0, 0, 36, 36, 0], false) &&
               !WR_SceneWalls.ceiling_shape?([0, 0, 80, 240, 192, 100], false) &&
               WR_SceneWalls.ceiling_shape?([0, 0, 80, 240, 192, 100], true) &&
               !WR_SceneWalls.ceiling_shape?(nil, true))
    ck('cl14', WR_SceneWalls.ceiling_hint?('Ceiling', '', nil) &&
               WR_SceneWalls.ceiling_hint?('WR Lights Ceiling', 'WR-Lights', nil) &&
               WR_SceneWalls.ceiling_hint?('Slab', 'WR-Ceiling', nil) &&
               WR_SceneWalls.ceiling_hint?('Group#12', 'Layer0', 'ceiling') &&
               !WR_SceneWalls.ceiling_hint?('Floor', 'WR-Floor', nil) &&
               !WR_SceneWalls.ceiling_hint?('Wall 2', 'WR-Room', 'wall'))
    ck('cl15', WR_AutoSet::CEILING_PLATES == ['03-high', '06-plan'] && WR_AutoSet::CEIL_ABOVE_TOL == 1.0)

    # ---- THE LIGHT RIG'S BORROWED WALLS (1.59.1) --------------------------
    # Benton: "using 'drop in the lights' and having it add walls actually
    # creates a wall when the 'actual' wall is hidden". A borrowed face
    # stands 1/16 in inside the real wall's solid; bound by POSITION it is
    # a piece of that wall. Real Wall 2 of a 240 x 192 room at (600, 400):
    # solid y 588..592, x 600..840, z 0..96. The rig face on its run sits at
    # y 588.0625, full length, floor to 96.
    wall2 = [600.0, 588.0, 0.0, 840.0, 592.0, 96.0]
    face2 = [600.0, 588.0625, 0.0, 840.0, 588.0625, 96.0]
    ck('rg1', WR_SceneWalls.rig_bound?(face2, wall2), 'the face inside Wall 2 did not bind')
    # Not bound: a face on the far wall, one standing 10 in off the plane,
    # one reaching above the wall, one on the room's other axis.
    ck('rg2', !WR_SceneWalls.rig_bound?([600.0, 400.0, 0.0, 840.0, 400.0, 96.0], wall2) &&
              !WR_SceneWalls.rig_bound?([600.0, 578.0, 0.0, 840.0, 578.0, 96.0], wall2) &&
              !WR_SceneWalls.rig_bound?([600.0, 588.0625, 0.0, 840.0, 588.0625, 120.0], wall2) &&
              !WR_SceneWalls.rig_bound?([596.0, 400.0, 0.0, 596.0, 592.0, 96.0], wall2) &&
              !WR_SceneWalls.rig_bound?(nil, wall2) && !WR_SceneWalls.rig_bound?(face2, nil))
    ck('rg3', WR_SceneWalls::RIG_BIND_TOL == 2.0 &&
              WR_SceneWalls.rig_bound?([600.0, 586.5, 0.0, 840.0, 586.5, 96.0], wall2) &&
              !WR_SceneWalls.rig_bound?([600.0, 585.5, 0.0, 840.0, 585.5, 96.0], wall2))
    # THE LOG: a hidden wall says its rig faces went with it; the run line
    # counts bound and open-run faces and says what a hidden one does to
    # the render.
    ck('rg4', WR_AutoSet.hides_line('Room Wall 2 (north)', 9, 1, 9) ==
              '         hides Room Wall 2 (north) -- it stands between the camera and the booth: 9 of 9 sight lines to the booth cross it + 1 light-rig wall face bound to it' &&
              WR_AutoSet.hides_line('Room Wall 2', 3, 2).include?('3 of 9 sight lines') &&
              WR_AutoSet.hides_line('Room Wall 2', 3, 2).include?('2 light-rig wall faces bound') &&
              !WR_AutoSet.hides_line('Room Wall 2', 9, 0).include?('light-rig') &&
              !WR_AutoSet.hides_line('Room Wall 2', 9, nil).include?('light-rig'),
       WR_AutoSet.hides_line('Room Wall 2 (north)', 9, 1, 9))
    rig_units = [{ 'room' => 'Room', 'wall' => 1, 'kind' => 'wall', 'rig' => 0 },
                 { 'room' => 'Room', 'wall' => 2, 'kind' => 'wall', 'rig' => 1 },
                 { 'room' => 'Light rig (open run)', 'wall' => 3, 'kind' => 'rig', 'rig' => 1 }]
    ck('rg5', WR_AutoSet.rig_counts(rig_units) == [1, 1] && WR_AutoSet.rig_counts([]) == [0, 0])
    rl = WR_AutoSet.walls_line(rig_units, ['Room'])
    ck('rg6', rl.include?('3 wall unit(s)') && rl.include?('Room: Wall 1, 2') &&
              !rl.include?('Light rig (open run): Wall') &&
              rl.include?('light rig: 2 borrowed wall face(s)') &&
              rl.include?('1 bound to the real wall') && rl.include?('1 on open run(s)') &&
              rl.include?('renders that side of the room OPEN'), rl)
    # NO RIG: the line is exactly the 1.58.0 line.
    plain = [{ 'room' => 'Room', 'wall' => 1, 'kind' => 'wall', 'rig' => 0 }]
    ck('rg7', !WR_AutoSet.walls_line(plain, ['Room']).include?('light rig'))
    # AN OPEN-RUN FACE IS A WALL TO THE CONE: same picks as a named wall.
    ru = [{ 'key' => 'r:9', 'c' => [50.0, 0.0, 48.0], 'box' => [50.0, -150.0, 0.0, 50.0, 150.0, 96.0], 'label' => 'WR Lights Wall 3 (light rig, open run)', 'kind' => 'rig' }]
    ck('rg8', WR_AutoSet.wall_picks('01-angled', ru, [0.0, 0.0, 0.0], [97.8, 0.0, 20.8])['r:9'] == true &&
              WR_AutoSet.wall_picks('06-plan', ru, [0.0, 0.0, 0.0], [97.8, 0.0, 20.8])['r:9'] == false)

    # ---- THE ANNOTATION ALLOWLIST ---------------------------------------
    # an1/an2 are the two that matter most in this file.
    ck('an1', ALL.all? { |p| WR_AutoSet.annot_picks(p, sets, loose)['t:WR-Notes'] == true },
       'WR-Notes -- the D5 banner -- is SHOWN on a plate')
    # an2 IS THE D5 GUARD AND IT DID NOT RELAX AT 1.51.0. Loose TEXT is text
    # of unknown content that lands on Untagged, and SketchUp refuses to hide
    # the Untagged tag -- this is the case the allowlist exists for.
    ck('an2', ALL.all? do |p|
                pk = WR_AutoSet.annot_picks(p, sets, loose)
                loose_text.all? { |it| pk[it['key']] == true }
              end,
       'a loose/Untagged TEXT callout is SHOWN on a plate')
    # ... but a loose DIMENSION is shown, on every plate. Benton, 10 Sep 2026:
    # "please dont hide any of the dimensions on the auto set."
    ck('an2b', ALL.all? { |p| WR_AutoSet.annot_picks(p, sets, loose)['e:103'] == false },
       'a loose DIMENSION is hidden on a plate')
    # A row whose kind is missing or unreadable is treated as text and hidden.
    ck('an2c', WR_AutoSet.annot_picks('02-front', [], [{ 'key' => 'e:999' }])['e:999'] == true,
       'an unreadable loose row was SHOWN')
    # EVERY DIMENSION TAG, ON EVERY PLATE (1.51.0).
    dims_all = %%w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Dims-Selection]
    ck('an3', shown_on('02-front').sort == dims_all.sort, shown_on('02-front').inspect)
    ck('an4', shown_on('05-ventilation').sort == (dims_all + ['WR-Notes-Vent']).sort,
       shown_on('05-ventilation').inspect)
    # Opt-in BY EXISTENCE: a shop that has never made that set gets a clean
    # plate rather than an error.
    no_vent = sets.reject { |s| s['name'] == 'WR-Notes-Vent' }
    # The NOTE set is still opt-in BY EXISTENCE: a shop that never made
    # WR-Notes-Vent gets the dimensions and no note.
    ck('an5', shown_on('05-ventilation', no_vent).sort == dims_all.sort,
       shown_on('05-ventilation', no_vent).inspect)
    ck('an6', shown_on('06-plan').sort == (dims_all + ['WR-Notes-Plan']).sort,
       shown_on('06-plan').inspect)
    # THE PLATES THAT USED TO SHOW NOTHING NOW SHOW THE DIMENSIONS, AND ONLY
    # THE DIMENSIONS. This assertion moved on purpose at 1.51.0; the one below
    # it (an7b) is the part that did not move.
    ck('an7', %%w[01-angled 04-side 07-interior].all? { |p| shown_on(p).sort == dims_all.sort },
       %%w[01-angled 04-side 07-interior].map { |p| shown_on(p) }.inspect)
    ck('an7b', ALL.all? { |p| (shown_on(p) - dims_all - %%w[WR-Notes-Vent WR-Notes-Plan]).empty? },
       'a plate is showing something that is neither a dimension nor its own note set')
    # FULL HASH: one key per set row plus one per loose row, and nothing else.
    pk = WR_AutoSet.annot_picks('02-front', sets, loose)
    ck('an8', pk.keys.length == sets.length + loose.length, pk.keys.length.to_s)
    # an9 WAS THE OPPOSITE ASSERTION UNTIL 1.51.0 -- it required WR-Dims-Booth
    # and WR-Dims-Selection to be HIDDEN everywhere. They are dimensions,
    # Benton asked for the dimensions, and they came off NEVER_SHOWN. That was
    # a legibility preference, never the D5 safety gate; an1 is the safety
    # gate and it is untouched.
    ck('an9', ALL.all? do |p|
                q = WR_AutoSet.annot_picks(p, sets, loose)
                q['t:WR-Dims-Booth'] == false && q['t:WR-Dims-Selection'] == false
              end,
       'a working-dimension tag is HIDDEN on a plate')
    # A set made this afternoon is matched live by the family regex and is on
    # no allowlist, so it is hidden -- not invisible to the tool, hidden BY it.
    ck('an10', ALL.all? { |p| WR_AutoSet.annot_picks(p, sets, loose)['t:WR-Notes-Custom'] == true })
    # A model with no annotations at all: an empty hash, not a crash.
    ck('an11', WR_AutoSet.annot_picks('01-angled', [], []) == {})

    # ---- the never-shown gate -------------------------------------------
    # THE GATE IS WR-Notes AND ONLY WR-Notes NOW, and that is the whole list
    # it has to be: the D5 banner. If this ever reads [] the gate is gone.
    ck('nv1', WR_AutoSet::NEVER_SHOWN == ['WR-Notes'],
       WR_AutoSet::NEVER_SHOWN.inspect)
    # THE POISONED ALLOWLIST NAMES WR-Notes ON THE HERO PLATE. The gate must
    # still refuse it -- and WR-Dims-Booth now legitimately comes through,
    # which is the 1.51.0 change, not a hole.
    ck('nv2', WR_AutoSetPoison.effective_shown('01-exterior',
                %%w[WR-Dims WR-Notes WR-Dims-Booth]).sort ==
              ['WR-Dims', 'WR-Dims-Booth'],
       WR_AutoSetPoison.effective_shown('01-exterior',
                %%w[WR-Dims WR-Notes WR-Dims-Booth]).inspect)
    ck('nv3', WR_AutoSet.policy_line.include?('EVERY plate') &&
              WR_AutoSet.policy_line.include?('still hidden'),
       WR_AutoSet.policy_line)

    # ---- THE WALL RULE: A LINE OF SIGHT, NOT A CONE (1.60.1) -----------
    # Booth at the origin (box +/-48 x +/-30 x 0..84); the camera 98 in away
    # on +X at 12 degrees up. Four walls of a 300 x 300 room plus one
    # sitting on the booth centre, which is the degenerate case.
    centre = [0.0, 0.0, 42.0]
    bbox   = [-48.0, -30.0, 0.0, 48.0, 30.0, 84.0]
    eye    = [97.8, 0.0, 20.8]
    wall   = lambda { |key, label, box| { 'key' => key, 'label' => label, 'box' => box,
                                          'c' => [(box[0] + box[3]) / 2.0, (box[1] + box[4]) / 2.0, (box[2] + box[5]) / 2.0] } }
    units  = [wall.call('w:front', 'Room Wall 1', [88.0, -150.0, 0.0, 92.0, 150.0, 96.0]),
              wall.call('w:back',  'Room Wall 2', [-92.0, -150.0, 0.0, -88.0, 150.0, 96.0]),
              wall.call('w:side',  'Room Wall 3', [-150.0, 88.0, 0.0, 150.0, 92.0, 96.0]),
              wall.call('w:other', 'Room Wall 4', [-150.0, -92.0, 0.0, 150.0, -88.0, 96.0]),
              wall.call('w:onit',  'Room Wall 5', [-1.0, -1.0, 41.0, 1.0, 1.0, 43.0])]
    p1 = WR_AutoSet.wall_picks('01-angled', units, centre, eye, bbox)
    hid = units.map { |u| u['key'] }.select { |k| p1[k] }
    ck('wp1', hid == ['w:front'], hid.inspect)
    # PARTIAL HASHES ARE THE BUG. Every unit keyed, true or false, or a wall
    # hidden on the previous plate rides along into this one.
    ck('wp2', p1.keys.length == units.length, p1.keys.length.to_s)
    p2 = WR_AutoSet.wall_picks('06-plan', units, centre, eye, bbox)
    ck('wp3', p2.keys.length == units.length && p2.values.none? { |v| v },
       p2.inspect)
    p3 = WR_AutoSet.wall_picks('07-interior', units, centre, eye, bbox)
    ck('wp4', p3.values.none? { |v| v })
    # CANNOT-TELL SHOWS THE WALL. A box the booth centre sits inside is not
    # "between"; a degenerate cone reads nil.
    ck('wp5', p1['w:onit'] == false)
    ck('wp6', WR_AutoSet.cone_dot([10.0, 0.0, 0.0], centre, centre).nil?)
    ck('wp7', WR_AutoSet.wall_picks('01-angled', [], centre, eye, bbox) == {})
    # The vent plate looks from the other side, so the other wall goes.
    eye2 = [-97.8, 0.0, 20.8]
    p4   = WR_AutoSet.wall_picks('05-ventilation', units, centre, eye2, bbox)
    ck('wp8', units.map { |u| u['key'] }.select { |k| p4[k] } == ['w:back'],
       units.map { |u| u['key'] }.select { |k| p4[k] }.inspect)
    ck('wp9', WR_AutoSet::SIGHT_MIN == 1 && WR_AutoSet::WALL_PAD == 0.5)

    # ---- THE FOUR SITUATIONS (1.60.1) -----------------------------------
    # Benton: "If there is a wall between the booth and the camera, yeah it
    # should hide that wall. But these views do not have a wall between the
    # booth and the camera and they are still hiding." Booth as above; the
    # front camera 260 in out on -Y at 72 in up. Walls of a LONG room, the
    # shape the cone got wrong: their centres sit well along their length.
    b_front = wall.call('w:F', 'Room Wall 1', [-150.0, -100.0, 0.0, 150.0, -96.0, 96.0])   # between
    b_far   = wall.call('w:R', 'Room Wall 2', [-150.0, 96.0, 0.0, 150.0, 100.0, 96.0])     # beyond
    b_left  = wall.call('w:L', 'Room Wall 3', [-150.0, -300.0, 0.0, -146.0, 100.0, 96.0])  # beside, long toward the camera
    b_right = wall.call('w:S', 'Room Wall 4', [146.0, -100.0, 0.0, 150.0, 100.0, 96.0])    # beside
    b_far2  = wall.call('w:R2', 'Room Wall 2b', [0.0, 96.0, 0.0, 600.0, 100.0, 96.0])       # beyond, centre off toward +X
    e_front = [0.0, -260.0, 72.0]
    e_diag  = [300.0, -260.0, 72.0]
    e_corner = [250.0, -200.0, 72.0]
    e_inside = [0.0, -80.0, 60.0]
    four = [b_front, b_far, b_left, b_right]
    pf = WR_AutoSet.wall_picks('02-front', four, centre, e_front, bbox)
    # 1. WALL BETWEEN CAMERA AND BOOTH -> hidden (the 05-ventilation case).
    ck('bt1', pf['w:F'] == true, pf.inspect)
    # 2. WALL BEYOND THE BOOTH -> stays up (his front shot).
    ck('bt2', pf['w:R'] == false, pf.inspect)
    # 3. WALL BESIDE THE BOOTH, inside the old cone -> stays up (his side
    # shot). The cone's own number is recorded so the regression is
    # visible: the long side wall's centre is at (-148, -100), which from
    # the booth reads 0.73 toward the camera -- the old rule hid it.
    ck('bt3', pf['w:L'] == false && pf['w:S'] == false &&
              WR_AutoSet.cone_dot(b_left['c'], centre, e_front) > 0.5,
       "#{pf.inspect} cone #{WR_AutoSet.cone_dot(b_left['c'], centre, e_front)}")
    # 2 again, hardest form: a far wall whose centre lies toward the
    # camera's side reads 0.58 in the cone and is BEYOND the booth.
    pd = WR_AutoSet.wall_picks('01-angled', [b_far2, b_front], centre, e_diag, bbox)
    ck('bt4', pd['w:R2'] == false && pd['w:F'] == true &&
              WR_AutoSet.cone_dot(b_far2['c'], centre, e_diag) > 0.5,
       "#{pd.inspect} cone #{WR_AutoSet.cone_dot(b_far2['c'], centre, e_diag)}")
    # 4. CAMERA OUTSIDE THE ROOM LOOKING IN through the near corner: both
    # near walls are between (the corner Benton lowers by hand), the far
    # two stay up. The right wall is crossed by corner sight lines only.
    pc = WR_AutoSet.wall_picks('01-angled', four, centre, e_corner, bbox)
    ck('bt5', pc['w:F'] == true && pc['w:S'] == true && pc['w:R'] == false && pc['w:L'] == false,
       pc.inspect)
    ck('bt6', WR_AutoSet.sight_lines_crossed(b_right['box'], e_corner, [centre]) == 0 &&
              WR_AutoSet.sight_lines_crossed(b_right['box'], e_corner, WR_AutoSet.booth_targets(centre, bbox)) > 0,
       'the side wall on the corner shot is caught by a corner sight line, not the centre one')
    # CAMERA INSIDE THE ROOM: the wall behind the camera is not between.
    pi = WR_AutoSet.wall_picks('02-front', four, centre, e_inside, bbox)
    ck('bt7', pi.values.none? { |v| v }, pi.inspect)
    # THE SEGMENT TEST ITSELF: entry at t = 0.61 (the padded near face); nil
    # for a point inside the box; nil when the box is past the point.
    t = WR_AutoSet.segment_box_t(e_front, centre, b_front['box'])
    ck('bt8', !t.nil? && (t - 0.61).abs < 0.01 &&
              WR_AutoSet.segment_box_t(e_front, [0.0, -98.0, 40.0], b_front['box']).nil? &&
              WR_AutoSet.segment_box_t(e_front, centre, b_far['box']).nil? &&
              WR_AutoSet.segment_box_t(e_front, centre, nil).nil?, t.inspect)
    # A ZERO-THICK LIGHT-RIG FACE is a box too, by the pad.
    face = wall.call('r:1', 'WR Lights Wall 1', [-150.0, -98.0, 0.0, 150.0, -98.0, 96.0])
    ck('bt9', WR_AutoSet.wall_picks('02-front', [face], centre, e_front, bbox)['r:1'] == true)
    # NINE TARGETS with a box, one without; a unit with no box is a 2 in cube.
    ck('bt10', WR_AutoSet.booth_targets(centre, bbox).length == 9 &&
               WR_AutoSet.booth_targets(centre, nil).length == 1 &&
               WR_AutoSet.unit_box({ 'c' => [5.0, 5.0, 5.0] }) == [4.0, 4.0, 4.0, 6.0, 6.0, 6.0])
    # wall_log carries the count and the total, and the words say why.
    wlg = WR_AutoSet.wall_log('02-front', four, centre, e_front, bbox)
    ck('bt11', wlg[0][2] == 9 && wlg[0][3] == true && wlg[0][4] == 9 && wlg[1][2] == 0 && wlg[1][3] == false,
       wlg.inspect)
    hl = WR_AutoSet.hides_line('Room Wall 1 (south)', 9, 1, 9)
    ck('bt12', hl.include?('hides Room Wall 1 (south) -- it stands between the camera and the booth: 9 of 9 sight lines to the booth cross it') &&
               hl.include?('+ 1 light-rig wall face bound to it'), hl)

    # THE SWING DOES NOT MOVE THE OCCLUDER (1.57.1). Benton: "the wall behind
    # the 3 vent sets would still be hidden". With the primary vent wall on
    # +Y and the REAL vent eye swung 25 deg either way, the room wall behind
    # +Y is in the cone (dot cos 25 = 0.91) and the two side walls (at 65
    # deg, dot 0.42) are not -- whichever hand the swing took.
    vwalls = [wall.call('w:behind', 'Room Wall 2', [-150.0, 88.0, 0.0, 150.0, 92.0, 96.0]),
              wall.call('w:plus',   'Room Wall 3', [-92.0, -150.0, 0.0, -88.0, 150.0, 96.0]),
              wall.call('w:minus',  'Room Wall 4', [88.0, -150.0, 0.0, 92.0, 150.0, 96.0]),
              wall.call('w:far',    'Room Wall 1', [-150.0, -92.0, 0.0, 150.0, -88.0, 96.0])]
    e_plus  = cam('05-ventilation', DOOR, VENT, false, HALF, nil, 1, 1).eye.to_a
    e_minus = cam('05-ventilation', DOOR, VENT, false, HALF, nil, 1, -1).eye.to_a
    wp_plus  = WR_AutoSet.wall_picks('05-ventilation', vwalls, CENTRE, e_plus)
    wp_minus = WR_AutoSet.wall_picks('05-ventilation', vwalls, CENTRE, e_minus)
    ck('wp10', wp_plus['w:behind'] == true && wp_plus['w:plus'] == false &&
               wp_plus['w:minus'] == false && wp_plus['w:far'] == false, wp_plus.inspect)
    ck('wp11', wp_minus['w:behind'] == true && wp_minus['w:plus'] == false &&
               wp_minus['w:minus'] == false && wp_minus['w:far'] == false, wp_minus.inspect)

    # ---- THE CAMERAS, RUN NOT ASSERTED ----------------------------------
    # Benton, 10 Sep 2026, after the 1.48.0 plates came back wrong:
    # "I never use parellel perspective so dont use it either."
    # ONE PARALLEL PLATE, AND IT IS THE TOP-DOWN. Benton, 10 Sep 2026: "The
    # top down should actually be the only one in parellel projection so
    # change that too." Both halves are asserted: the plan IS parallel, and
    # nothing else is. cm1 used to read "no plate is parallel"; that rule was
    # superseded, not abandoned.
    flat = ALL.reject { |id| cam(id).perspective }
    ck('cm1', flat == ['06-plan'], flat.inspect)
    ck('cm1b', (ALL - ['06-plan']).all? { |id| cam(id).height.nil? },
       'a perspective plate set a parallel-projection frame height')
    ck('cm1c', !cam('06-plan').height.nil? && cam('06-plan').height > 0,
       cam('06-plan').height.inspect)

    # FRONT ON. "Find the door, step out like 15 ft or so. Straight on."
    f = shot('02-front')
    ck('cm2', (f['az'] - DOOR).abs < 1.0e-6, f['az'].inspect)
    # ~16 ft back on the ground for this booth, which is "15 ft or so" and
    # not the 21 ft radius * 3.2 + 60 used to give.
    ck('cm3', f['run'] > 168.0 && f['run'] < 240.0, f['run'].round(1).to_s)
    # Standing eye height, not a bird. 4 ft - 8 ft off the floor.
    ck('cm4', f['z'] > 48.0 && f['z'] < 96.0, f['z'].round(1).to_s)

    # THE EYE HEIGHT IS THE SAME ON EVERY BOOTH (1.64.0). This is the whole
    # point of plate_el, and the defect it replaces: :el was a fixed 7
    # degrees, the standoff scales with the booth, and eye_z = centre_z +
    # standoff * tan(el) -- so a bigger booth got a higher camera. The 4872
    # this suite is written around landed the intended 66"; the 96144 E
    # Benton shot on 11 Sep 2026 landed 75" and read as looking down from
    # near the ceiling ("the camera should be about 1' lower because its
    # close to the ceiling").
    #
    # Asserted the way it is meant to hold: the three ground plates put the
    # eye at PLATE_EYE, and they do it for a small booth AND a large one --
    # a 96144 E is ~88" of plan radius against this suite's 60. An assertion
    # at ONE radius could not have caught the bug.
    eye_at = lambda do |id, r|
      v = FakeView.new(false, r)
      WR_AutoSet.aim_plate(v, id, CENTRE, r, DOOR, VENT, HALF, nil, 1, 1)
      v.camera.eye.to_a[2]
    end
    small = %%w[01-angled 02-front 04-side].map { |id| eye_at.call(id, RADIUS) }
    big   = %%w[01-angled 02-front 04-side].map { |id| eye_at.call(id, 88.0) }
    ck('cm4b', (small + big).all? { |z| (z - WR_AutoSet::PLATE_EYE).abs < 0.5 },
       [small.map { |z| z.round(1) }, big.map { |z| z.round(1) }].inspect)
    # The ventilation plate keeps its lift over the others -- ~10", which is
    # what its old 10 degrees bought it -- and is equally booth-independent.
    vz = [eye_at.call('05-ventilation', RADIUS), eye_at.call('05-ventilation', 88.0)]
    ck('cm4c', vz.all? { |z| (z - WR_AutoSet::VENT_EYE).abs < 0.5 } &&
               WR_AutoSet::VENT_EYE > WR_AutoSet::PLATE_EYE,
       vz.map { |z| z.round(1) }.inspect)
    # The HIGH plate has no :eye and must be untouched by any of this: it is
    # still the fixed 40-degree shot, so its eye DOES rise with the booth.
    ck('cm4d', eye_at.call('03-high', 88.0) > eye_at.call('03-high', RADIUS) + 24.0,
       [eye_at.call('03-high', RADIUS).round(1), eye_at.call('03-high', 88.0).round(1)].inspect)
    # plate_el itself: it must REFUSE rather than return a silly angle when
    # the geometry is outside the band, and fall back to the plate's own :el.
    ck('cm4e', WR_AutoSet.plate_el('03-high', 42.0, 60.0) == 40.0 &&
               WR_AutoSet.plate_el('01-angled', 42.0, nil) == 7.0 &&
               WR_AutoSet.plate_el('01-angled', 500.0, 60.0) == 7.0 &&
               WR_AutoSet.plate_el('01-angled', 60.5, 60.0) == 7.0,
       [WR_AutoSet.plate_el('03-high', 42.0, 60.0),
        WR_AutoSet.plate_el('01-angled', 500.0, 60.0),
        WR_AutoSet.plate_el('01-angled', 60.5, 60.0)].inspect)

    # TOP DOWN. Genuinely straight down: the eye is over the booth, not
    # beside it. At el 89 the run was ~4 in and this check is what fails.
    pl = shot('06-plan')
    ck('cm5', pl['run'] < 0.01, pl['run'].inspect)
    ck('cm6', pl['z'] > CENTRE[2] + 120.0, pl['z'].round(1).to_s)
    # Straight down makes world Z the view direction, so up must NOT be Z.
    ck('cm7', pl['up'] == [0.0, 1.0, 0.0], pl['up'].inspect)
    ck('cm8', pl['persp'] == false, 'the top-down is NOT parallel-projected')

    # THE HIGH SHOT. "one from 15-20ft high around this same angle."
    h = shot('03-high')
    ck('cm9', h['z'] > 168.0 && h['z'] < 252.0, h['z'].round(1).to_s)
    # "around this same angle": same bearing and same ground run as the
    # angled shot, camera lifted. This is what plate_dist's 1/cos(el) buys --
    # without it, raising the elevation walks the camera in toward the booth.
    ang = shot('01-angled')
    ck('cm10', (h['az'] - ang['az']).abs < 1.0e-6 &&
               (h['run'] - ang['run']).abs < 1.0, [h['run'], ang['run']].inspect)
    # "This is image." The high IMAGE is never a render at ANY count -- the
    # count adds a '03-high r' scene beside it (from 3 up) and converts
    # nothing. Same for the top-down (from 6).
    ck('cm11', (0..WR_AutoSet::MAX_RENDERS).none? do |n|
                 rs = WR_AutoSet.render_ids(WR_AutoSet.plate_ids(true, n))
                 rs.include?('03-high') || rs.include?('06-plan')
               end,
       'the high shot or the top-down image was promoted to a render')
    ck('cm11b', (0..2).none? { |n| WR_AutoSet.plate_ids(true, n).include?('03-high r') } &&
                (3..6).all? { |n| WR_AutoSet.plate_ids(true, n).include?('03-high r') } &&
                (0..5).none? { |n| WR_AutoSet.plate_ids(true, n).include?('06-plan r') } &&
                WR_AutoSet.plate_ids(true, 6).include?('06-plan r'),
       'the high / plan render scenes do not appear at exactly 3 and 6')

    # VENTILATION. "Usually a back view to show ventilation (this usually
    # requires a hidden wall)" -- so it must NOT be exempt from the wall cone.
    ck('cm12', !WR_AutoSet::NO_WALL_PLATES.include?('05-ventilation'),
       'the ventilation plate is exempt from the wall rule')
    vshot = shot('05-ventilation')
    ck('cm13', (vshot['az'] - (VENT + 25.0)).abs < 1.0e-6, vshot['az'].inspect)
    # A wall standing behind the booth on the vent side is hidden by the cone,
    # using the eye the REAL aim produced.
    vwall = [{ 'key' => 'w:rear', 'c' => [0.0, 90.0, 48.0], 'box' => [-150.0, 88.0, 0.0, 150.0, 92.0, 96.0], 'label' => 'Room Wall 2' },
             { 'key' => 'w:far',  'c' => [0.0, -90.0, 48.0], 'box' => [-150.0, -92.0, 0.0, 150.0, -88.0, 96.0], 'label' => 'Room Wall 1' }]
    vp = WR_AutoSet.wall_picks('05-ventilation', vwall, CENTRE, cam('05-ventilation').eye.to_a)
    ck('cm14', vp['w:rear'] == true && vp['w:far'] == false, vp.inspect)

    # THE SIDE VIEW is square off the door wall, 90 degrees round.
    sd = shot('04-side')
    ck('cm15', ((sd['az'] - DOOR) - 90.0).abs < 1.0e-6, sd['az'].inspect)

    # A LONGER LENS THAN aim's own default 40, on every EXTERIOR plate. The
    # interior plate keeps its own wide 70, because a 35 inside a 4 ft booth
    # sees a panel and nothing else -- that is aim_interior's own number and
    # it is meant to differ.
    # The plan is parallel, so it has no lens at all -- every OTHER exterior
    # plate carries the one number.
    ck('cm16', (DEFAULTS - ['06-plan']).all? { |id| cam(id).fov == WR_AutoSet::PLATE_FOV },
       DEFAULTS.map { |id| [id, cam(id).fov] }.inspect)
    ck('cm16b', cam('07-interior').fov > WR_AutoSet::PLATE_FOV,
       cam('07-interior').fov.inspect)

    # cm17 USED TO ASK "is the eye closer than the RADIUS" -- the 3D diagonal,
    # which is larger than any half-extent, so it was true of a camera sitting
    # outside the booth and proved nothing. in4 below asks the real question.
    ic = cam('07-interior')
    ck('cm17', ic.eye.to_a[2] == CENTRE[2], ic.eye.to_a.inspect)

    # ---- WHICH WALL IS THE DOOR IN? ------------------------------------
    # THE 1.50.x DEFECT, PINNED. tag_az used to return the bearing to the
    # door's CENTRE. A door is rarely centred along its own wall, and on
    # Benton's MDL 96120 S (98 x 122 exterior, door ~36 in off centre) that
    # read -120 instead of -90 -- most of 02-angled's 35-degree swing, which
    # is why 01-front came out a three-quarter and 02-angled came out
    # square-on. The answer must be the wall's NORMAL, not a bearing to a
    # point.
    #
    # 98 x 122 exterior -> half-extents 49 x 61. Door in the -Y wall.
    ck('dr1', WR_AutoSet.wall_axis(0.0, -61.0, 49.0, 61.0) == [0.0, -1.0],
       WR_AutoSet.wall_axis(0.0, -61.0, 49.0, 61.0).inspect)
    # THE CASE THAT SHIPPED WRONG: 36 in off centre along the wall. The old
    # rule gave -120.5 deg; the wall normal is still -90.
    ck('dr2', WR_AutoSet.wall_axis(36.0, -61.0, 49.0, 61.0) == [0.0, -1.0],
       WR_AutoSet.wall_axis(36.0, -61.0, 49.0, 61.0).inspect)
    # Even hard against the corner it is still that wall, not the other one.
    ck('dr3', WR_AutoSet.wall_axis(48.0, -61.0, 49.0, 61.0) == [0.0, -1.0],
       WR_AutoSet.wall_axis(48.0, -61.0, 49.0, 61.0).inspect)
    # A door genuinely in the +X wall reads +X, offset along it or not.
    ck('dr4', WR_AutoSet.wall_axis(49.0, 30.0, 49.0, 61.0) == [1.0, 0.0],
       WR_AutoSet.wall_axis(49.0, 30.0, 49.0, 61.0).inspect)
    # NORMALISED BY EACH HALF-EXTENT, not compared in raw inches: 44 in of x
    # is 0.90 of the way out across 49, while 50 in of y is only 0.82 across
    # 61 -- so this is the +X wall even though the y offset is the bigger
    # number. Comparing inches would pick the wrong wall.
    ck('dr5', WR_AutoSet.wall_axis(44.0, 50.0, 49.0, 61.0) == [1.0, 0.0],
       WR_AutoSet.wall_axis(44.0, 50.0, 49.0, 61.0).inspect)
    # A degenerate half-extent must not divide by zero or pick a wall it
    # cannot see.
    ck('dr6', WR_AutoSet.wall_axis(0.0, -61.0, 0.0, 61.0) == [0.0, -1.0],
       WR_AutoSet.wall_axis(0.0, -61.0, 0.0, 61.0).inspect)

    # ---- WHICH WALL PLANE IS THE PART IN? --------------------------------
    # THE 1.53.0 LIVE DEFECT, AND IT WAS NOT THE FRAME PICKER. The run
    # reported the anchor at [96.0, 23.0] -- which IS the fixture's door frame
    # centre, exactly -- and then a bearing of 0.0 (+X) for a door in the -Y
    # wall. What failed is that the offset was normalised against the booth's
    # UNION bounding box, and the union is skewed by whatever sticks out: the
    # swung leaf reaches y -14, the vent housing y 86, so the centre read y 36
    # where the shell's is y 54 and the half-extents read 48 x 50 for a 96 x 60
    # shell. The frame then scored 0.500 on x against 0.260 on y and +X won.
    #
    # The rule now reads the PART'S OWN SHAPE: long along its wall, thin across
    # it, and the thin axis is the normal. No booth box, so nothing that sticks
    # out can skew it.
    #
    # The fixture's door frame is 36 in long and 2 in thick, in the -Y wall.
    ck('wn1', WR_AutoSet.wall_normal(36.0, 2.0, 25.5, -13.0) == [0.0, -1.0],
       WR_AutoSet.wall_normal(36.0, 2.0, 25.5, -13.0).inspect)
    # THE EXACT LIVE NUMBERS, with the skewed offset that beat the old rule.
    # dx/hx was 0.500 and dy/hy only -0.260, so the old rule said +X; the shape
    # says -Y whatever the offset is.
    ck('wn2', WR_AutoSet.wall_axis(25.5, -13.0, 48.0, 50.0) == [1.0, 0.0],
       'the OLD rule no longer reproduces the defect it is here to document')
    ck('wn3', WR_AutoSet.wall_normal(36.0, 2.0, 25.5, -13.0) !=
              WR_AutoSet.wall_axis(25.5, -13.0, 48.0, 50.0),
       'the new rule agrees with the rule that shipped the bug')
    # A part in the +Y wall signs the other way.
    ck('wn4', WR_AutoSet.wall_normal(36.0, 2.0, 0.0, 31.0) == [0.0, 1.0],
       WR_AutoSet.wall_normal(36.0, 2.0, 0.0, 31.0).inspect)
    # A part in an X wall: thin in x, long in y.
    ck('wn5', WR_AutoSet.wall_normal(2.0, 36.0, -47.0, 4.0) == [-1.0, 0.0],
       WR_AutoSet.wall_normal(2.0, 36.0, -47.0, 4.0).inspect)
    # AND THE ORIGINAL 96120 CASE still lands on the wall, off-centre door and
    # all -- a 46 in frame in a 1 in wall, 36 in along it.
    ck('wn6', WR_AutoSet.wall_normal(46.0, 1.0, 36.0, -61.0) == [0.0, -1.0],
       WR_AutoSet.wall_normal(46.0, 1.0, 36.0, -61.0).inspect)
    # IT REFUSES RATHER THAN GUESSING. A squarish block is not identifiably in
    # a wall, so it returns nil and the caller says ASSUMED out loud.
    ck('wn7', WR_AutoSet.wall_normal(30.0, 24.0, 10.0, -20.0).nil?,
       WR_AutoSet.wall_normal(30.0, 24.0, 10.0, -20.0).inspect)
    ck('wn8', WR_AutoSet.wall_normal(0.0, 0.0, 1.0, 1.0).nil?)
    ck('wn9', WR_AutoSet::ASPECT_MIN == 2.0, WR_AutoSet::ASPECT_MIN.inspect)

    # ---------------------------------------------------------- 1.68.0: the
    # ONE-PIECE DOOR. Benton's live MDL 4872 S carries its frame and its leaf
    # inside a single "S0  Left46Door" component, so frame_hits returns the
    # whole assembly and its 46.00 x 31.99 footprint names no wall. (1.68.0
    # said the 32 was a leaf "drawn swung open". It is not: the leaf is closed
    # and in the wall, and the 32 is its nested containers' boxes re-boxed
    # through rotations that cancel -- see fd2 and the 1.69.0 DEVLOG entry.) So
    # wall_normal declines, the pre-1.54.0 wall_axis fallback runs against the
    # skewed union box, and it called the door wall +/-X on a 0.6 percent
    # margin when the door is in the -Y wall. 02-front then photographed a
    # blank end panel with no door in the frame at all.
    #
    # THE NUMBERS BELOW ARE THE LIVE ONES, read out of that model on 12 Sep
    # 2026 through the bridge, not invented for the test.

    # The shape half of wall_normal's question, asked on its own.
    ck('if1', WR_AutoSet.wall_shape?(46.0, 17.88) &&
              !WR_AutoSet.wall_shape?(46.0, 31.99) &&
              WR_AutoSet.wall_shape?(22.0, 1.0) &&
              !WR_AutoSet.wall_shape?(0.0, 0.0) &&
              WR_AutoSet.wall_shape?(1.8, 46.0),
       'wall_shape? no longer agrees with wall_normal about what names a wall')
    # EXACTLY ASPECT_MIN COUNTS, and a hair under does not. wall_normal uses
    # >=, so this must too or the two disagree at the boundary.
    ck('if2', WR_AutoSet.wall_shape?(20.0, 10.0) &&
              !WR_AutoSet.wall_shape?(19.999, 10.0) &&
              (WR_AutoSet.wall_normal(20.0, 10.0, 0.0, -5.0).nil? ? false : true) &&
              WR_AutoSet.wall_normal(19.999, 10.0, 0.0, -5.0).nil?,
       'wall_shape? and wall_normal disagree at exactly ASPECT_MIN')
    ck('if3', WR_AutoSet.plan_aspect(46.0, 17.88).round(3) == 2.573 &&
              WR_AutoSet.plan_aspect(36.69, 31.99).round(3) == 1.147 &&
              WR_AutoSet.plan_aspect(0.0, 0.0) == 0.0 &&
              WR_AutoSet.plan_aspect(46.0, 0.0) == 1.0e9,
       [WR_AutoSet.plan_aspect(46.0, 17.88), WR_AutoSet.plan_aspect(36.69, 31.99)].inspect)

    # THE LIVE PAIR. The frame is named and is the long thin one;
    # Component#393 -- the leaf's outermost container, whose box the rotations
    # below it inflated -- is neither. Either signal alone picks the frame,
    # which is the point of having two.
    frm  = { 'name' => 'Std door frame 46"#7', 'span' => [46.0, 17.88], 'ctr' => [25.0, 2.75] }
    leaf = { 'name' => 'Component#393',        'span' => [36.69, 31.99], 'ctr' => [25.02, 0.91] }
    ck('if4', WR_AutoSet.inner_frame_pick([frm, leaf]) == frm &&
              WR_AutoSet.inner_frame_pick([leaf, frm]) == frm,
       WR_AutoSet.inner_frame_pick([frm, leaf]).inspect)
    # and the wall that then comes out is the -Y one, off the live offset
    # (own centre y 18.0, so dy = 2.75 - 18.0).
    ck('if5', WR_AutoSet.wall_normal(46.0, 17.88, 25.0 - 49.69, 2.75 - 18.0) == [0.0, -1.0],
       WR_AutoSet.wall_normal(46.0, 17.88, 25.0 - 49.69, 2.75 - 18.0).inspect)
    # THE OLD PATH, PINNED AS THE BUG IT WAS: the whole assembly names no
    # wall, and the fallback's two normalised offsets are a coin flip that
    # went the wrong way. If this ever stops being true the note above is
    # stale.
    ck('if6', WR_AutoSet.wall_normal(46.0, 31.99, -24.687, -17.087).nil? &&
              WR_AutoSet.wall_axis(-24.687, -17.087, 60.313, 42.0) == [-1.0, 0.0] &&
              ((-24.687 / 60.313).abs - (-17.087 / 42.0).abs).abs < 0.003,
       'the 12 Sep 2026 defect no longer reproduces from its own numbers')

    # NO NAME SAYING FRAME: the aspect alone must still find it.
    ck('if7', WR_AutoSet.inner_frame_pick(
                [{ 'name' => 'Component#1', 'span' => [36.69, 31.99], 'ctr' => [0.0, 0.0] },
                 { 'name' => 'Component#2', 'span' => [46.0, 17.88], 'ctr' => [1.0, 2.0] }]
              )['name'] == 'Component#2',
       'inner_frame_pick stopped falling back to the aspect when nothing is named')
    # A NAME SAYING FRAME BEATS A FATTER ASPECT -- the builder's word wins.
    ck('if8', WR_AutoSet.inner_frame_pick(
                [{ 'name' => 'blade', 'span' => [100.0, 1.0], 'ctr' => [0.0, 0.0] },
                 { 'name' => 'Std door FRAME', 'span' => [46.0, 17.88], 'ctr' => [1.0, 2.0] }]
              )['name'] == 'Std door FRAME',
       'a named frame no longer beats an unnamed sliver')
    # IT REFUSES RATHER THAN GUESSING. Nothing wall-shaped inside, nothing
    # returned -- the caller then keeps its old fallback instead of being
    # handed a fabricated wall.
    ck('if9', WR_AutoSet.inner_frame_pick([leaf]).nil? &&
              WR_AutoSet.inner_frame_pick([]).nil? &&
              WR_AutoSet.inner_frame_pick(nil).nil? &&
              WR_AutoSet.inner_frame_pick(
                [{ 'name' => 'door FRAME', 'span' => [30.0, 29.0], 'ctr' => [0.0, 0.0] }]
              ).nil?,
       'inner_frame_pick fabricated a wall from a part that does not name one')
    # A ROW WITH NO SPAN IS SKIPPED, NOT RAISED ON.
    ck('if10', WR_AutoSet.inner_frame_pick(
                 [{ 'name' => 'ghost', 'span' => nil },
                  { 'name' => 'frame', 'span' => [46.0, 17.88], 'ctr' => [0.0, 0.0] }]
               )['name'] == 'frame',
       'inner_frame_pick no longer survives a row with no span')
    ck('if11', ('Std door frame 46' =~ WR_AutoSet::FRAME_RE ? true : false) &&
               ('E1 46DRFRM' =~ WR_AutoSet::FRAME_RE ? true : false) &&
               ('Left46Door' =~ WR_AutoSet::FRAME_RE).nil?,
       'FRAME_RE no longer matches the frame names and only them')

    # ---------------------------------------------------------- 1.69.0: THE
    # DOOR FRAME COMES FIRST. Benton, 12 Sep 2026: "For future reference, find
    # the side the door frame is on. That side is the FRONT." Until 1.69.0 the
    # frame was a fallback, read only after the whole door's box failed the
    # shape test.
    #
    # THE DOOR BELOW IS THE LIVE ONE. Every to_a array and every definition
    # box was read out of Benton's model through the bridge on 12 Sep 2026:
    # the door (own +90), its frame (own -90, so net 0), and the leaf's chain
    # Component#393 (-60) > Component#297 (+160) > slab (-100), net +90, which
    # is the slab lying in the wall. The slab's definition name says "door
    # frame" -- a real trap, kept.
    i16 = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
    t_door  = [0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 49.0, -1.2742, 0.0, 1.0]
    t_frame = [0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.7742, 44.0, 0.0, 1.0]
    t_393   = [0.5, -0.866, 0.0, 0.0, 0.866, 0.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -11.4776, 31.4434, 2.875, 1.0]
    t_297   = [-0.9397, 0.342, 0.0, 0.0, -0.342, -0.9397, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 29.2549, 7.9825, 0.0, 1.0]
    t_slab  = [-0.1736, -0.9848, 0.0, 0.0, 0.9848, -0.1736, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.253, 8.1214, 0.0, 1.0]
    slab_d  = FakeDef.new('Std door 30"  for 46" door frame#3', [0.0, -3.0, 0.0], [2.5, 27.3729, 75.25])
    d297    = FakeDef.new('Component#297', [-0.1355, 0.9062, 0.0], [30.2101, 9.7863, 75.25],
                          [FakeInst.new('', 'Layer0', slab_d, t_slab)])
    d393    = FakeDef.new('Component#393', [-2.4804, -1.2599, 0.0], [29.0723, 17.4635, 75.25],
                          [FakeInst.new('', 'Layer0', d297, t_297)])
    frame_d = FakeDef.new('Std door frame 46"#7', [-3.0, -6.6875, 0.0], [43.0, 11.1875, 81.0])
    door_d  = FakeDef.new('Left46Door', [-13.8089, 1.0, 0.0], [18.1824, 47.0, 81.0],
                          [FakeLoose.new,
                           FakeInst.new('', 'Layer0', frame_d, t_frame),
                           FakeInst.new('', 'Layer0', d393, t_393)])
    wall_d  = FakeDef.new('46PanelSolid', [0.0, 0.0, 0.0], [46.0, 2.0, 81.0])
    # A window frame on the WALLS tag: named frame, never the door's.
    wdo_d   = FakeDef.new('WDO FRAME', [0.0, 0.0, 0.0], [2.0, 30.0, 40.0])
    booth_ents = [FakeLoose.new,
                  FakeInst.new('W0  46PanelSolid', 'WR-Booth-Walls', wall_d, i16),
                  FakeInst.new('E1  WDO', 'WR-Booth-Walls', wdo_d, i16),
                  FakeInst.new('S0  Left46Door', 'WR-Booth-Door', door_d, t_door)]
    ocx = 49.69
    ocy = 18.0
    near = lambda { |a, b| (a.to_f - b.to_f).abs < 0.01 }

    # THE WALK FINDS THE FRAME BY NAME UNDER THE DOOR TAG, composes every
    # level, and lands on a frame whose NET x-axis is [1, 0] in booth space
    # although its own is [0, -1]. It stops at the frame (the frame's
    # adaptors and hinges are never rows), keeps the slab as a deeper row
    # because its name says frame, and never returns the window frame.
    rows = WR_AutoSet.frame_parts(booth_ents, 'WR-Booth-Door')
    fr = rows.find { |r| r['name'] == 'Std door frame 46"#7' }
    sl = rows.find { |r| r['name'] =~ /Std door 30/ }
    ck('fd1', rows.length == 2 && !fr.nil? && !sl.nil? &&
              fr['depth'] == 1 && sl['depth'] == 3 &&
              near.call(fr['m'][0], 1.0) && near.call(fr['m'][1], 0.0) &&
              rows.none? { |r| r['name'] =~ /WDO/ },
       rows.map { |r| [r['name'], r['depth'], r['m'][0].round(3), r['m'][1].round(3)] }.inspect)

    # ROTATIONS THAT CANCEL. The slab's composed x-axis is [0, 1] -- in the
    # wall -- while one level up Component#297's is [-0.985, -0.174] and
    # Component#393's own box, carried into the booth, is 36.69 x 31.99 and
    # names no wall. That box is what 1.68.0 called an open leaf. The frame's
    # composed reading still names the -Y wall, at the frame's live centre.
    m297 = WR_AutoSet.mat_mul(WR_AutoSet.mat_mul(t_door, t_393), t_297)
    m393 = WR_AutoSet.mat_mul(t_door, t_393)
    xs = []
    ys = []
    [[-2.4804, -1.2599], [29.0723, -1.2599], [-2.4804, 17.4635], [29.0723, 17.4635]].each do |p|
      q = WR_AutoSet.mat_apply(m393, p[0], p[1], 0.0)
      xs << q[0]
      ys << q[1]
    end
    got_fd2 = WR_AutoSet.frame_reading(rows, ocx, ocy)
    ck('fd2', near.call(sl['m'][0], 0.0) && near.call(sl['m'][1], 1.0) &&
              near.call(m297[0], -0.985) && near.call(m297[1], -0.174) &&
              !WR_AutoSet.wall_shape?(xs.max - xs.min, ys.max - ys.min) &&
              !got_fd2.nil? && got_fd2[0] == 0.0 && got_fd2[1] == -1.0 &&
              near.call(got_fd2[2], 25.0) && near.call(got_fd2[3], 2.75),
       [sl['m'][0, 2], m297[0, 2], [xs.max - xs.min, ys.max - ys.min], got_fd2].inspect)

    # THE ORDER ITSELF. An outer door box that PASSES the shape test and
    # names a different wall (+X here) must not be consulted when a frame
    # reading exists, and the inner descent must not even run.
    own4 = [ocx, ocy, 60.313, 42.0]
    fake_outer = { 'span' => [20.0, 46.0], 'ctr' => [80.0, 10.0] }
    calls = []
    spy = lambda { calls << 1; nil }
    via_frame = WR_AutoSet.door_axis([0.0, -1.0, 25.0, 2.75], fake_outer, spy, own4)
    via_outer = WR_AutoSet.door_axis(nil, fake_outer, spy, own4)
    ck('fd3', via_frame == [0.0, -1.0, 25.0, 2.75, 'frame'] &&
              via_outer == [1.0, 0.0, 80.0, 10.0, 'outer'] &&
              calls.empty?,
       [via_frame, via_outer, calls.length].inspect)

    # THE SHALLOWEST FRAME WINS. The same door with its slab genuinely swung
    # 90 degrees open: the slab row now names the other wall. It is three
    # levels down against the frame's one, so it does not get a vote.
    open_slab = sl.merge('m' => WR_AutoSet.mat_mul(sl['m'],
                  [0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]))
    solo = WR_AutoSet.frame_row_normal(open_slab, ocx, ocy)
    got_fd4 = WR_AutoSet.frame_reading([open_slab, fr], ocx, ocy)
    ck('fd4', !solo.nil? && solo[1] == 0.0 &&
              !got_fd4.nil? && got_fd4[0, 2] == [0.0, -1.0],
       [solo, got_fd4].inspect)

    # IT DECLINES RATHER THAN GUESSING. A frame 35 degrees off both booth
    # axes, a frame tipped so its long axis is vertical, a square frame, and
    # two frames at the same depth that disagree all give no reading.
    rot35 = [Math.cos(35.0 * Math::PI / 180.0), Math.sin(35.0 * Math::PI / 180.0), 0.0, 0.0,
             -Math.sin(35.0 * Math::PI / 180.0), Math.cos(35.0 * Math::PI / 180.0), 0.0, 0.0,
             0.0, 0.0, 1.0, 0.0, 25.0, 2.75, 0.0, 1.0]
    tipped = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 25.0, 2.75, 0.0, 1.0]
    box46 = { 'min' => [-23.0, -9.0, 0.0], 'max' => [23.0, 9.0, 81.0], 'depth' => 1 }
    skew  = box46.merge('m' => rot35)
    tip   = box46.merge('m' => tipped)
    sq    = { 'min' => [0.0, 0.0, 0.0], 'max' => [30.0, 29.0, 81.0], 'depth' => 1, 'm' => i16 }
    east  = box46.merge('m' => [0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 100.0, 18.0, 0.0, 1.0])
    ck('fd5', WR_AutoSet.frame_reading([skew], ocx, ocy).nil? &&
              WR_AutoSet.frame_reading([tip], ocx, ocy).nil? &&
              WR_AutoSet.frame_reading([sq], ocx, ocy).nil? &&
              WR_AutoSet.frame_reading([fr, east], ocx, ocy).nil? &&
              !WR_AutoSet.frame_reading([fr], ocx, ocy).nil? &&
              WR_AutoSet::FRAME_SNAP_DEG == 20.0,
       [WR_AutoSet.frame_reading([skew], ocx, ocy), WR_AutoSet.frame_reading([tip], ocx, ocy),
        WR_AutoSet.frame_reading([fr, east], ocx, ocy)].inspect)

    # NO FRAME, CLEAN FALLBACK, and every 1.68.0 answer comes back unchanged:
    # a door with nothing named frame yields no rows and no reading; a
    # wall-shaped outer box is read as before without the descent running;
    # the one-piece door still opens up to its inner frame; nothing inside
    # still ends at the wall_axis coin flip, pinned as it was in if6; and no
    # outer box at all is nil, not a fabricated wall.
    bare_d = FakeDef.new('Left46Door', [0.0, 0.0, 0.0], [46.0, 30.0, 81.0],
                         [FakeInst.new('', 'Layer0', FakeDef.new('Component#1', [0.0, 0.0, 0.0], [30.0, 2.5, 75.0]), i16)])
    bare = [FakeInst.new('S0  Left46Door', 'WR-Booth-Door', bare_d, t_door)]
    calls2 = []
    spy2 = lambda { calls2 << 1; nil }
    frm_row = { 'name' => 'Std door frame 46"#7', 'span' => [46.0, 17.88], 'ctr' => [25.0, 2.75] }
    ck('fd6', WR_AutoSet.frame_parts(bare, 'WR-Booth-Door') == [] &&
              WR_AutoSet.frame_reading([], ocx, ocy).nil? &&
              WR_AutoSet.frame_reading(nil, ocx, ocy).nil? &&
              WR_AutoSet.door_axis(nil, { 'span' => [46.0, 17.88], 'ctr' => [25.0, 2.75] }, spy2, own4) ==
                [0.0, -1.0, 25.0, 2.75, 'outer'] && calls2.empty? &&
              WR_AutoSet.door_axis(nil, { 'span' => [46.0, 31.99], 'ctr' => [25.003, 0.913] },
                                   lambda { frm_row }, own4) == [0.0, -1.0, 25.0, 2.75, 'inner'] &&
              WR_AutoSet.door_axis(nil, { 'span' => [46.0, 31.99], 'ctr' => [25.003, 0.913] },
                                   lambda { nil }, own4)[0, 2] == [-1.0, 0.0] &&
              WR_AutoSet.door_axis(nil, { 'span' => [46.0, 31.99], 'ctr' => [25.003, 0.913] },
                                   lambda { nil }, own4)[4] == 'axis' &&
              WR_AutoSet.door_axis(nil, nil, spy2, own4).nil?,
       [WR_AutoSet.frame_parts(bare, 'WR-Booth-Door').length,
        WR_AutoSet.door_axis(nil, { 'span' => [46.0, 17.88], 'ctr' => [25.0, 2.75] }, spy2, own4),
        calls2.length].inspect)

    # THE MATRIX HELPERS: column-major like Geom::Transformation#to_a, a * b
    # applies b first, [15] scale honoured; and a frame sitting on the booth
    # centre names nothing (the same 1 in guard the old path had).
    ident = WR_AutoSet.mat_mul(t_door, [0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.2742, 49.0, 0.0, 1.0])
    ck('fd7', ident.each_with_index.all? { |v, i| near.call(v, i16[i]) } &&
              WR_AutoSet.mat_apply(t_door, 1.0, 0.0, 0.0).map { |v| v.round(4) } == [49.0, -0.2742, 0.0] &&
              WR_AutoSet.mat_apply([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.5],
                                   2.0, 3.0, 0.0) == [4.0, 6.0, 0.0] &&
              WR_AutoSet.door_axis([0.0, -1.0, ocx + 0.5, ocy], nil, nil, own4).nil?,
       [ident.map { |v| v.round(3) }, WR_AutoSet.mat_apply(t_door, 1.0, 0.0, 0.0)].inspect)

    # ---- A LOOSE DIMENSION IS NOT AN ORANGE WARNING ----------------------
    # The orange cell says "untagged TEXT is about to reach a customer image".
    # Since 1.51.0 dimensions show on every plate, so a loose DIMENSION started
    # tripping it -- the 1.53.0 live run flagged a clean plate orange over a
    # dimension reading 5'. A warning that fires on something Benton asked to
    # see is one he learns to ignore, and then it stops protecting him from the
    # text too.
    fam = %%w[WR-Dims WR-Dims-Doors]
    dim1 = [{ :key => 'e:1', :kind => 'dim',  :text => "5'" }]
    txt1 = [{ :key => 'e:2', :kind => 'text', :text => 'note to self' }]
    c_d = WR_AutoSet.annot_cell(fam, [], dim1)
    ck('oc1', c_d['warn'] == false, c_d.inspect)
    ck('oc2', c_d['loose'] == 0 && c_d['loose_dims'] == 1, c_d.inspect)
    # ... but it is still REPORTED, as a fact rather than a problem.
    ck('oc3', c_d['tip'].include?('loose dimension'), c_d['tip'])
    # LOOSE TEXT STILL WARNS. This is the D5 guard in the review column.
    c_t = WR_AutoSet.annot_cell(fam, [], txt1)
    ck('oc4', c_t['warn'] == true, c_t.inspect)
    ck('oc5', c_t['loose'] == 1, c_t.inspect)
    ck('oc6', c_t['tip'].include?('LOOSE/Untagged'), c_t['tip'])
    # A DIMENSION MUST NOT MASK TEXT when both are present.
    c_b = WR_AutoSet.annot_cell(fam, [], dim1 + txt1)
    ck('oc7', c_b['warn'] == true && c_b['loose'] == 1 && c_b['loose_dims'] == 1,
       c_b.inspect)
    # An unreadable page is still reported as unreadable, never as clean.
    ck('oc8', WR_AutoSet.annot_cell(fam, nil, nil)['warn'] == true)
    # The deep read not having run still means "does not claim to know".
    ck('oc9', WR_AutoSet.annot_cell(fam, [], nil)['loose'].nil?)

    # ---- THE DOOR FRAME, NOT THE LEAF ------------------------------------
    # Benton, 10 Sep 2026, after 1.51.0: "Front should find the door frame
    # really, rather than the door." A leaf drawn SWUNG OPEN sits away from the
    # wall plane, and unioned with the frame it drags the centroid into mid
    # air -- so even the wall-normal rule normalises against an offset that
    # never came from the wall.
    #
    # FakeEnt is the minimum the picker touches: a name and a bounds centre.
    own96 = FakeBB.new(0.0, 0.0, 49.0, 61.0)
    frame = FakeEnt.new('S0  Right46Door', 36.0, -60.0)
    leaf  = FakeEnt.new('S0  Right46DoorLeaf', 60.0, -20.0)   # swung out past the shell
    leaf_in = FakeEnt.new('S0  Right46DoorLeaf', 38.0, -43.0)  # swung inward
    # By NAME first, when a builder names the frame.
    named = FakeEnt.new('S0  Right46DRFRM', 36.0, -60.0)
    got = WR_AutoSet.frame_hits([leaf, named], own96)
    ck('fm1', got == [named], got.map { |e| e.name }.inspect)
    # Otherwise GEOMETRICALLY: the part hardest against a wall is the frame.
    got2 = WR_AutoSet.frame_hits([leaf, frame], own96)
    ck('fm2', got2 == [frame], got2.map { |e| e.name }.inspect)
    # The swung leaf ALONE would have given a bearing that is not the wall's.
    bad = WR_AutoSet.wall_axis(60.0 - 0.0, -20.0 - 0.0, 49.0, 61.0)
    ck('fm3', bad == [1.0, 0.0], bad.inspect)
    # ... and the frame gives the real one.
    good = WR_AutoSet.wall_axis(36.0, -60.0, 49.0, 61.0)
    ck('fm4', good == [0.0, -1.0], good.inspect)
    # A leaf swung INWARD is short of the shell; the frame still wins.
    got3 = WR_AutoSet.frame_hits([leaf_in, frame], own96)
    ck('fm5', got3 == [frame], got3.map { |e| e.name }.inspect)
    ck('fm5b', WR_AutoSet.frame_hits([], own96) == [])
    # NO plate re-targets now (1.65.0) -- every plate frames the whole booth.
    ck('fm6', WR_AutoSet::PLATES.none? { |p| p[:aim_at] },
       WR_AutoSet::PLATES.select { |p| p[:aim_at] }.map { |p| p[:id] }.inspect)
    # The RENDER half of the front plate is the same plate, so it re-targets
    # too -- both halves are excluded, and every other id must still frame
    # the whole booth. (ALL carries '02-front r' since the default went to
    # three renders.)
    ck('fm7', (ALL - ['02-front', '02-front r']).none? { |id| WR_AutoSet.plate(id)[:aim_at] },
       (ALL - ['02-front', '02-front r']).select { |id| WR_AutoSet.plate(id)[:aim_at] }.inspect)
    # AIMED AT THE FRAME: with an off-centre door the eye stands on the wall
    # normal THROUGH THE FRAME, not through the booth centre.
    vv = FakeView.new
    anch = [36.0, -61.0, CENTRE[2]]
    WR_AutoSet.aim_plate(vv, '02-front', CENTRE, RADIUS, DOOR, VENT, HALF, anch)
    # 1.65.0 INVERTS THESE TWO. Until now an anchor handed to the front plate
    # moved the target onto the door frame (x = 36). Benton asked for the
    # booth's wall face instead, so the anchor is now IGNORED and the target
    # is the booth centre (x = 0) -- asserted with an anchor supplied, which
    # is the only way to tell "ignored" from "never passed".
    ck('fm8', (vv.camera.target.to_a[0] - CENTRE[0]).abs < 1.0e-9,
       vv.camera.target.to_a.inspect)
    ck('fm9', (vv.camera.eye.to_a[0] - CENTRE[0]).abs < 1.0e-6,
       "the eye is off the booth centre: #{vv.camera.eye.to_a.inspect}")
    # With no anchor it falls back to the booth centre rather than raising.
    vv2 = FakeView.new
    WR_AutoSet.aim_plate(vv2, '02-front', CENTRE, RADIUS, DOOR, VENT, HALF, nil)
    ck('fm10', vv2.camera.target.to_a == CENTRE, vv2.camera.target.to_a.inspect)

    # ---- INSIDE THE BOOTH ------------------------------------------------
    # A FIXED CLEARANCE OFF THE INTERIOR FACE, NOT A FRACTION. Benton, 10 Sep
    # 2026: "it needed to move like 2\" more inside the booth. It was kinda
    # stuck in the wall." HALF is a real 4872 E; the door faces -Y, so the
    # booth's shell reaches 37 in that way and the interior face is at 36.
    idist = WR_AutoSet.interior_eye_dist(HALF, RADIUS, DOOR)
    ck('in1', (idist - (37.0 - 1.0 - WR_AutoSet::INTERIOR_EYE_CLEAR)).abs < 1.0e-9,
       idist.inspect)
    # THE SECOND CORRECTION, 10 Sep 2026: "Interior needs to go towards the
    # center of the booth like 18\" now or so" -- a further ~18 in inboard of
    # the 4 in that 1.51.0 shipped.
    ck('in1b', (WR_AutoSet::INTERIOR_EYE_CLEAR - 22.0).abs < 1.0e-9,
       WR_AutoSet::INTERIOR_EYE_CLEAR.inspect)
    ck('in1c', (idist - 14.0).abs < 1.0e-9, idist.inspect)
    # A BOOTH TOO SHALLOW TO STAND 23 IN INSIDE ITS DOOR clamps at the centre
    # rather than going negative and putting the eye outside the far wall. A
    # 4230 is 44 x 32 exterior, so its door wall is 16 in from centre.
    ck('in1d', WR_AutoSet.interior_eye_dist([22.0, 16.0], 30.0, DOOR) == 0.0,
       WR_AutoSet.interior_eye_dist([22.0, 16.0], 30.0, DOOR).inspect)
    # The eye stands clear of the INTERIOR face by the named clearance.
    clear = (WR_AutoSet.reach(HALF[0], HALF[1], DOOR) -
             WR_AutoSet::BOOTH_WALL_T) - idist
    ck('in2', (clear - WR_AutoSet::INTERIOR_EYE_CLEAR).abs < 1.0e-9, clear.inspect)
    # ... AND IT IS THE SAME CLEARANCE IN A BOOTH THREE TIMES THE SIZE. The
    # old radius * 0.55 stood 2.2 in off the face on a 4872 and 26 in off it
    # on a 96168; that is the bug, not the 2 inches.
    big = [49.0, 85.0]     # MDL 96168 E, 8'2" x 14'2" exterior
    bclear = (WR_AutoSet.reach(big[0], big[1], DOOR) - WR_AutoSet::BOOTH_WALL_T) -
             WR_AutoSet.interior_eye_dist(big, 106.8, DOOR)
    ck('in3', (bclear - clear).abs < 1.0e-9, [clear, bclear].inspect)
    # The eye is genuinely inside the shell, on both.
    ck('in4', idist < WR_AutoSet.reach(HALF[0], HALF[1], DOOR), idist.inspect)
    # reach takes the NEARER face on an off-axis azimuth, not the wider one.
    ck('in5', (WR_AutoSet.reach(25.0, 37.0, 0.0) - 25.0).abs < 1.0e-9,
       WR_AutoSet.reach(25.0, 37.0, 0.0).inspect)

    # THE TWO-POINT PERSPECTIVE. Benton, 10 Sep 2026: "I like the interior
    # camera angle. Its a good feature honestly." A perspective camera looking
    # DEAD LEVEL with a WORLD-VERTICAL up vector leaves real verticals
    # parallel on screen instead of converging -- the same geometry SketchUp's
    # Two-Point Perspective mode imposes. Each of the three things that
    # produces it gets its own check, because none of them looks important.
    ic2 = cam('07-interior')
    idir = [ic2.target.to_a[0] - ic2.eye.to_a[0],
            ic2.target.to_a[1] - ic2.eye.to_a[1],
            ic2.target.to_a[2] - ic2.eye.to_a[2]]
    ck('in6', idir[2].abs < 1.0e-9, "view direction z = #{idir[2]}")
    ck('in7', ic2.up.to_a == [0.0, 0.0, 1.0], ic2.up.to_a.inspect)
    ck('in8', ic2.perspective == true, 'the interior plate is parallel-projected')
    ck('in9', ic2.fov == WR_AutoSet::INTERIOR_FOV, ic2.fov.inspect)
    # And the eye is level with the booth centre -- moving it inboard must not
    # tilt it, which is the thing the clearance fix had to not break.
    ck('in10', (ic2.eye.to_a[2] - CENTRE[2]).abs < 1.0e-9, ic2.eye.to_a.inspect)

    # THE EYE SURVIVES BEING AIMED ONTO A PARALLEL CAMERA (1.55.0). 06-plan
    # is aimed immediately before the interior and leaves the view parallel;
    # SketchUp's parallel-to-perspective flip keeps the target and re-derives
    # the eye from the frame height (FakeCamera models it). Live on 1.53.0 and
    # 1.54.0 the interior eye came back 295.59 in from its target instead of
    # 27, i.e. 223 in OUTSIDE the booth, and the suite was green because the
    # stub had no such flip. The eye must be exactly where interior_eye_dist
    # put it whichever projection the view was in beforehand.
    ic3 = cam('07-interior', DOOR, VENT, true)
    ck('in11', (ic3.eye.to_a[1] - (CENTRE[1] - idist)).abs < 1.0e-9,
       "interior eye #{ic3.eye.to_a.inspect} after a parallel plate, wanted y #{-idist}")
    # ... and the exterior plates too: same set()/perspective= order in
    # WR_ProposalScenes.aim. Re-running Apply with the plan scene selected is
    # a parallel view for every plate that follows.
    f_fresh = cam('02-front')
    f_plan  = cam('02-front', DOOR, VENT, true)
    ck('cm19', f_fresh.eye.to_a == f_plan.eye.to_a,
       "front eye #{f_plan.eye.to_a.inspect} after a parallel plate vs " \
       "#{f_fresh.eye.to_a.inspect} on a fresh view")

    # THE DOOR WALL PLANE COMES OFF THE FRAME, NOT THE UNION BOX (1.55.0).
    # A leaf drawn open 36 in pushes the union half-depth from 37 to 55, and
    # "22 in inside the union edge" is then 22 in inside the LEAF: 4 in off
    # the real interior face, the 1.50.x shot Benton called "stuck in the
    # wall". With the frame anchor (in the wall, y -37) the eye stands 22 in
    # inside the real face whatever sticks out.
    skew   = [25.0, 55.0]
    anchor = [10.0, -37.0, 42.0]         # the frame, 10 in off centre, IN the -Y wall
    ic4 = cam('07-interior', DOOR, VENT, true, skew, anchor)
    ck('in12', (ic4.eye.to_a[1] - (CENTRE[1] - idist)).abs < 1.0e-9,
       "interior eye #{ic4.eye.to_a.inspect} with the union skewed by an open leaf, " \
       "wanted y #{-idist}")
    # The off-centre frame does not drag the eye sideways: it stays on the
    # booth's centre line, the anchor gives only the plane.
    ck('in12b', (ic4.eye.to_a[0] - CENTRE[0]).abs < 1.0e-9, ic4.eye.to_a.inspect)
    # No anchor (no door tag): the union box is still the fallback, so the
    # eye moves with it rather than the tool refusing to aim.
    ic5 = cam('07-interior', DOOR, VENT, true, skew, nil)
    ck('in13', (ic5.eye.to_a[1] - (CENTRE[1] - (55.0 - 1.0 - 22.0))).abs < 1.0e-9,
       ic5.eye.to_a.inspect)
    # door_run is the run ALONG the normal only, and a frame on the wrong
    # side (negative run) is refused rather than aimed at.
    ck('in14', (WR_AutoSet.door_run([0.0, 0.0, 42.0], anchor, DOOR) - 37.0).abs < 1.0e-9,
       WR_AutoSet.door_run([0.0, 0.0, 42.0], anchor, DOOR).inspect)
    # -10 rather than -37: an abs() would turn -37 into the fixture's own
    # 37 and pass by coincidence; abs(-10) = 10 clamps to 0 and is caught.
    ck('in14b', (WR_AutoSet.interior_eye_dist(HALF, RADIUS, DOOR, -10.0) - idist).abs < 1.0e-9,
       WR_AutoSet.interior_eye_dist(HALF, RADIUS, DOOR, -10.0).inspect)

    # NO DOOR TAG AT ALL: the documented -90 fallback still produces a real
    # camera rather than raising.
    ck('cm18', shot('02-front', nil, nil)['az'] == WR_AutoSet::FALLBACK_AZ,
       shot('02-front', nil, nil)['az'].inspect)

    # ---- THE BLANK PLATE EXPLAINS ITSELF --------------------------------
    # The model Benton ran on carried no dimensions at all, and a plate that
    # SHOWS WR-Dims while the model has none looks identical to one that hides
    # them. Counting is the only way to tell, and it must not widen anything.
    none = { 'WR-Dims' => 0, 'WR-Dims-Doors' => 0, 'WR-Dims-Booth' => 0,
             'WR-Dims-Selection' => 0, 'WR-Notes-Plan' => 0, 'WR-Notes-Vent' => 0 }
    some = none.merge({ 'WR-Dims' => 14 })
    ck('eb1', !WR_AutoSet.empty_shown_note(['WR-Dims', 'WR-Dims-Doors'], none).nil?)
    ck('eb2', WR_AutoSet.empty_shown_note(['WR-Dims', 'WR-Dims-Doors'], none)
                        .include?('BLANK'))
    # PARTIAL IS NOT BLANK. One populated tag means the plate has content.
    ck('eb3', WR_AutoSet.empty_shown_note(['WR-Dims', 'WR-Dims-Doors'], some).nil?,
       WR_AutoSet.empty_shown_note(['WR-Dims', 'WR-Dims-Doors'], some).inspect)
    # A plate that shows nothing by design is not "blank" -- a plate with an
    # empty allowlist and no dims present is meant to be clean, and telling
    # Benton to dimension his model for it would be noise.
    ck('eb4', WR_AutoSet.empty_shown_note([], none).nil?)
    # COULD NOT TELL IS NOT EMPTY. A failed walk returns nil and must stay
    # quiet rather than claim the dimensions are missing.
    ck('eb5', WR_AutoSet.empty_shown_note(['WR-Dims'], { 'WR-Dims' => nil }).nil?)
    ck('eb6', WR_AutoSet.empty_shown_note(['WR-Dims'], {}).nil?)
    # The run-level list names the dimensioned plates and leaves the clean
    # ones out of it.
    # Every plate shows dimensions now, so on a model with none drawn EVERY
    # plate is blank and says so -- which is exactly the model Benton ran on.
    ck('eb7', WR_AutoSet.blank_plates(ALL, sets, none) == ALL,
       WR_AutoSet.blank_plates(ALL, sets, none).inspect)
    ck('eb8', WR_AutoSet.blank_plates(ALL, sets, some) == [],
       WR_AutoSet.blank_plates(ALL, sets, some).inspect)

    OUT.join(' | ')
  end
end

# A raise part-way through must not throw away the checks that already ran --
# a mutant that breaks one method often raises in the NEXT one, and "RAISED"
# on its own does not say which check bit. Whatever ran, reports.
(begin
  T.run
rescue Exception => e
  (T::OUT + ['RAISED ' + e.message.to_s]).join(' | ')
end).dup
'''

NAMES = ('ts1 ts2 ts3 ts4 ts5 ts6 ts7 '
         'sm1 sm2 sm3 sm4 sm5 sm6 sm7 sm8 sm9 '
         'mg1 mg2 mg3 mg4 mg4b mg5 mg6 mg7 mg8 mg9 mg10 '
         'mv1 mv2 mv3 mv4 mv5 '
         'or1 or2 or3 or4 or5 '
         'ld1 ld2 ld3 ld4 ld5 ld6 ld7 ld8 ld9 ld10 ld11 ld12 ld13 ld14 ld15 ld16 '
         'fr1 fr2 fr3 fr4 fr5 fr6 fr7 fr8 '
         'du1 du2 du3 du4 du5 du5b du6 du6b du7 du8 du9 du10 du11 du12 '
         'az1 az2 az3 az4 az5 az6 az7 az8 az9 az10 az11 '
         'sd1 sd2 sd3 sd4 sd5 sd6 sd7 sd8 sd9 sd10 sd11 sd12 sd13 sd13b sd13c '
         'sd14 sd15 '
         'sd16 sd17 sd18 sd19 sd20 '
         'vt1 vt2 vt3 vt4 vt5 vt6 vt7 vt8 vt9 vt10 vt11 vt12 vt13 vt14 vt15 '
         'vt16 vt17 vt17b vt18 vt19 vt20 vt21 '
         'wl1 wl2 wl3 '
         'cl1 cl2 cl3 cl4 cl5 cl6 cl7 cl8 cl9 cl10 cl11 cl12 cl13 cl14 cl15 '
         'rg1 rg2 rg3 rg4 rg5 rg6 rg7 rg8 '
         'an1 an2 an2b an2c an3 an4 an5 an6 an7 an7b an8 an9 an10 an11 '
         'nv1 nv2 nv3 '
         'wp1 wp2 wp3 wp4 wp5 wp6 wp7 wp8 wp9 '
         'bt1 bt2 bt3 bt4 bt5 bt6 bt7 bt8 bt9 bt10 bt11 bt12 '
         'wp10 wp11 '
         'cm1 cm1b cm1c cm2 cm3 cm4 cm4b cm4c cm4d cm4e cm5 cm6 cm7 cm8 cm9 cm10 cm11 cm11b cm12 cm13 '
         'cm14 cm15 cm16 cm16b cm17 '
         'dr1 dr2 dr3 dr4 dr5 dr6 '
         'wn1 wn2 wn3 wn4 wn5 wn6 wn7 wn8 wn9 '
         'if1 if2 if3 if4 if5 if6 if7 if8 if9 if10 if11 '
         'fd1 fd2 fd3 fd4 fd5 fd6 fd7 '
         'oc1 oc2 oc3 oc4 oc5 oc6 oc7 oc8 oc9 '
         'fm1 fm2 fm3 fm4 fm5 fm5b fm6 fm7 fm8 fm9 fm10 '
         'in1 in1b in1c in1d in2 in3 in4 in5 in6 in7 in8 in9 in10 '
         'in11 cm19 in12 in12b in13 in14 in14b '
         'cm18 '
         'eb1 eb2 eb3 eb4 eb5 eb6 eb7 eb8').split()
EXPECT = ' | '.join('%s ok' % n for n in NAMES)


def main():
    ps = os.path.join(HERE, 'proposal-scenes.rb')
    prog = FIXTURE % {
        'shown_on_dimensioned': const_line('SHOWN_ON_DIMENSIONED', ps),
        # The REAL aim(), lifted out of proposal-scenes.rb, so the camera the
        # cm checks measure is the camera SketchUp would be handed.
        'aim':             rbtest.method_source(ps, 'aim'),
        'deg':             const_line('DEG'),
        'dict':            const_line('DICT'),
        'fallback_az':     const_line('FALLBACK_AZ'),
        'moved_tol':       const_line('MOVED_TOL'),
        'wall_pad':        const_line('WALL_PAD'),
        'sight_min':       const_line('SIGHT_MIN'),
        'booth_targets':   rbtest.method_source(SRC, 'booth_targets'),
        'segment_box_t':   rbtest.method_source(SRC, 'segment_box_t'),
        'sight_lines_crossed': rbtest.method_source(SRC, 'sight_lines_crossed'),
        'unit_box':        rbtest.method_source(SRC, 'unit_box'),
        'wall_log':        rbtest.method_source(SRC, 'wall_log'),
        'aspect_min':      const_line('ASPECT_MIN'),
        'window_re':       const_line('WINDOW_RE'),
        'side_plate':      const_line('SIDE_PLATE'),
        'side_skip_tags':  const_line('SIDE_SKIP_TAGS'),
        'thin_max':        const_line('THIN_MAX'),
        'part_wall':       rbtest.method_source(SRC, 'part_wall'),
        'side_normals':    rbtest.method_source(SRC, 'side_normals'),
        'side_score':      rbtest.method_source(SRC, 'side_score'),
        'pick_side':       rbtest.method_source(SRC, 'pick_side'),
        'side_sign':       rbtest.method_source(SRC, 'side_sign'),
        'side_line':       rbtest.method_source(SRC, 'side_line'),
        'vent_plate':      const_line('VENT_PLATE'),
        'vent_rank':       rbtest.method_source(SRC, 'vent_rank'),
        'wall_word':       rbtest.method_source(SRC, 'wall_word'),
        'pick_vent':       rbtest.method_source(SRC, 'pick_vent'),
        'vent_line':       rbtest.method_source(SRC, 'vent_line'),
        'walls_line':      rbtest.method_source(SRC, 'walls_line'),
        'rig_counts':      rbtest.method_source(SRC, 'rig_counts'),
        'hides_line':      rbtest.method_source(SRC, 'hides_line'),
        'rig_bind_tol':    const_line('RIG_BIND_TOL', SW),
        'rig_bound':       rbtest.method_source(SW, 'rig_bound'),
        'ceiling_plates':  const_line('CEILING_PLATES'),
        'ceil_above_tol':  const_line('CEIL_ABOVE_TOL'),
        # 'ceiling_over' (not 'ceiling_over?'): the regex \b after the name.
        'ceiling_over':    rbtest.method_source(SRC, 'ceiling_over'),
        'ceiling_picks':   rbtest.method_source(SRC, 'ceiling_picks'),
        'ceilings_line':   rbtest.method_source(SRC, 'ceilings_line'),
        'ceiling_line':    rbtest.method_source(SRC, 'ceiling_line'),
        # The recogniser's pure half, lifted from wr-scene-walls.rb into a
        # stub of its module, so the shape rule the log quotes is the one
        # that runs in the model.
        'ceil_max_t':      const_line('CEIL_MAX_T', SW),
        'ceil_hint_max_t': const_line('CEIL_HINT_MAX_T', SW),
        'ceil_min_span':   const_line('CEIL_MIN_SPAN', SW),
        'ceil_name_re':    const_line('CEIL_NAME_RE', SW),
        'ceil_tag':        const_line('CEIL_TAG', SW),
        'ceiling_shape':   rbtest.method_source(SW, 'ceiling_shape'),
        'ceiling_hint':    rbtest.method_source(SW, 'ceiling_hint'),
        'dual_suffix':     const_line('DUAL_SUFFIX'),
        'dims_re':         const_line('DIMS_RE'),
        'booth_wall_t':    const_line('BOOTH_WALL_T'),
        'interior_eye_clear': const_line('INTERIOR_EYE_CLEAR'),
        'interior_fov':    const_line('INTERIOR_FOV'),
        'standoff_k':      const_line('STANDOFF_K'),
        'standoff_c':      const_line('STANDOFF_C'),
        'plate_fov':       const_line('PLATE_FOV'),
        'plate_eye':       const_line('PLATE_EYE'),
        'vent_eye':        const_line('VENT_EYE'),
        'el_min':          const_line('EL_MIN'),
        'el_max':          const_line('EL_MAX'),
        'max_renders':     const_line('MAX_RENDERS'),
        'default_renders': const_line('DEFAULT_RENDERS'),
        'plates':          const_block('PLATES'),
        'renumbered':      const_block('RENUMBERED'),
        'no_wall_plates':  const_line('NO_WALL_PLATES'),
        'render_ladder':   const_block('RENDER_LADDER'),
        'never_shown':     const_line('NEVER_SHOWN'),
        'shown_by_plate':  const_block('SHOWN_BY_PLATE'),
        'effective_shown': rbtest.method_source(SRC, 'effective_shown'),
        'annot_picks':     rbtest.method_source(SRC, 'annot_picks'),
        'unit_vec':        rbtest.method_source(SRC, 'unit_vec'),
        'cone_dot':        rbtest.method_source(SRC, 'cone_dot'),
        'wall_picks':      rbtest.method_source(SRC, 'wall_picks'),
        'render_ids':      rbtest.method_source(SRC, 'render_ids'),
        'mode_for':        rbtest.method_source(SRC, 'mode_for'),
        'plate':           rbtest.method_source(SRC, 'plate'),
        'plate_ids':       rbtest.method_source(SRC, 'plate_ids'),
        'run_ids':         rbtest.method_source(SRC, 'run_ids'),
        # 'live_plate' (not 'live_plate?'): see the centre_moved note below.
        'live_plate':      rbtest.method_source(SRC, 'live_plate'),
        'stale_plates':    rbtest.method_source(SRC, 'stale_plates'),
        'extra_pages':     rbtest.method_source(SRC, 'extra_pages'),
        'auto_named':      rbtest.method_source(SRC, 'auto_named'),
        'az_for':          rbtest.method_source(SRC, 'az_for'),
        # 'side_swung' / 'wall_shape' (not the ? forms): method_source
        # appends \b and ? gives it no word boundary to land on. Same
        # trick as 'live_plate' and 'centre_moved' above.
        'side_swung':      rbtest.method_source(SRC, 'side_swung'),
        'standoff':        rbtest.method_source(SRC, 'standoff'),
        'base_id':         rbtest.method_source(SRC, 'base_id'),
        'dual_render':     rbtest.method_source(SRC, 'dual_render'),
        'dual_render_id':  rbtest.method_source(SRC, 'dual_render_id'),
        'ladder_renders':  rbtest.method_source(SRC, 'ladder_renders'),
        'reach':           rbtest.method_source(SRC, 'reach'),
        'wall_axis':       rbtest.method_source(SRC, 'wall_axis'),
        'wall_normal':     rbtest.method_source(SRC, 'wall_normal'),
        'frame_re':        const_line('FRAME_RE'),
        'wall_shape':      rbtest.method_source(SRC, 'wall_shape'),
        'plan_aspect':     rbtest.method_source(SRC, 'plan_aspect'),
        'inner_frame_pick': rbtest.method_source(SRC, 'inner_frame_pick'),
        'frame_snap_deg':  const_line('FRAME_SNAP_DEG'),
        'frame_walk_depth': const_line('FRAME_WALK_DEPTH'),
        'mat_mul':         rbtest.method_source(SRC, 'mat_mul'),
        'mat_apply':       rbtest.method_source(SRC, 'mat_apply'),
        'frame_parts':     rbtest.method_source(SRC, 'frame_parts'),
        'frame_row_normal': rbtest.method_source(SRC, 'frame_row_normal'),
        'frame_reading':   rbtest.method_source(SRC, 'frame_reading'),
        'door_axis':       rbtest.method_source(SRC, 'door_axis'),
        'annot_cell':      rbtest.method_source(SRC, 'annot_cell'),
        'frame_hits':      rbtest.method_source(SRC, 'frame_hits'),
        'interior_eye_dist': rbtest.method_source(SRC, 'interior_eye_dist'),
        'door_run':        rbtest.method_source(SRC, 'door_run'),
        'policy_line':     rbtest.method_source(SRC, 'policy_line'),
        'loose_split':     rbtest.method_source(SRC, 'loose_split'),
        'plate_dist':      rbtest.method_source(SRC, 'plate_dist'),
        'plate_el':        rbtest.method_source(SRC, 'plate_el'),
        'aim_plate':       rbtest.method_source(SRC, 'aim_plate'),
        'aim_interior':    rbtest.method_source(SRC, 'aim_interior'),
        # tag_counts needs a real model to walk, so it is NOT lifted -- only
        # the pure half of the blank-plate answer is testable here. The
        # counting itself is verify-autoset.rb's job.
        'tag_counts_unused': '',
        'empty_shown_note': rbtest.method_source(SRC, 'empty_shown_note'),
        'blank_plates':    rbtest.method_source(SRC, 'blank_plates'),
        'sanitize_token':  rbtest.method_source(SRC, 'sanitize_token'),
        'next_token':      rbtest.method_source(SRC, 'next_token'),
        'scene_name':      rbtest.method_source(SRC, 'scene_name'),
        'centre_key':      rbtest.method_source(SRC, 'centre_key'),
        'centre_from_key': rbtest.method_source(SRC, 'centre_from_key'),
        'moved_by':        rbtest.method_source(SRC, 'moved_by'),
        # 'centre_moved' (not 'centre_moved?'): method_source appends \b and
        # ? gives it no word boundary to land on. Same trick as
        # rbtest-proposal.py's 'autorun' / 'booth_name'.
        'centre_moved':    rbtest.method_source(SRC, 'centre_moved'),
        'page_stamp':      rbtest.method_source(SRC, 'page_stamp'),
        'token_pages':     rbtest.method_source(SRC, 'token_pages'),
        'page_for_plate':  rbtest.method_source(SRC, 'page_for_plate'),
        'tokens_in_use':   rbtest.method_source(SRC, 'tokens_in_use'),
    }

    # THE ALLOWLIST MUST NOT HAVE BECOME A DENYLIST. Checked on the SOURCE,
    # because a rewrite that keeps every method name would still pass every
    # fixture above while inverting the policy: a plate that hides a named
    # list and shows everything else is the one shape this file forbids.
    src = open(SRC, encoding='utf-8').read()
    gone = []
    if 'SHOWN_BY_PLATE' not in src:
        gone.append('SHOWN_BY_PLATE (the allowlist) is gone')
    if 'NEVER_SHOWN' not in src:
        gone.append('NEVER_SHOWN (the second gate) is gone')
    if re.search(r'^\s*HIDDEN_BY_PLATE\s*=', src, re.M):
        gone.append('a HIDDEN_BY_PLATE denylist has appeared')
    # THE PROJECTION RULE, ENFORCED ON THE SOURCE. Benton refined the blanket
    # no-parallel rule on 10 Sep 2026: "The top down should actually be the
    # only one in parellel projection". So the gate enforces BOTH halves
    # rather than banning the key -- the rule changed, it did not vanish, and
    # this is the thing standing between us and a silent slide back to 1.48,
    # where four of six plates were parallel.
    if re.search(r':persp\s*=>', src):
        gone.append('a :persp key is back in the plate table -- projection is '
                    'carried by :parallel on exactly one plate, see PLATES')
    # THE WALL RULE HAS TO BE WIRED IN, not merely present. wn1-wn9 prove
    # wall_normal is right; nothing offline can prove tag_anchor CALLS it,
    # because tag_anchor needs a real Geom and a real booth transformation.
    # This mutant survived the first mutation run for exactly that reason, so
    # the wiring is checked on the source instead: wall_normal first, the old
    # union-box rule only as the nil fallback.
    if not re.search(r'ax\s*=\s*wall_normal\(', src):
        gone.append('tag_anchor no longer asks wall_normal for the wall plane '
                    '-- the union-box offset rule is what shipped the 1.53.0 '
                    'wrong-wall bearing, see wall_normal')
    if not re.search(r'ax\s*=\s*wall_axis\([^)]*\)\s*if\s+ax\.nil\?', src):
        gone.append('the union-box offset rule is no longer guarded by '
                    '`if ax.nil?` -- it is the last resort, not the rule')
    par = re.findall(r":id\s*=>\s*'([^']+)'[^}]*?:parallel\s*=>\s*true", src, re.S)
    if par != ['06-plan']:
        gone.append('the parallel plate(s) are %r -- it must be exactly '
                    "['06-plan']: the top-down is a drafting plan and every "
                    'other plate is a photograph' % (par,))
    if gone:
        print('  policy FAIL %s' % '; '.join(gone))
        return 1
    print('  policy ok - the annotation rule is still an allowlist plus a '
          'never-shown gate, 06-plan is the only parallel plate, and the '
          'wall plane is read from the part not the union box')

    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('wr-autoset: the annotation allowlist, the wall cone, the render '
          'ladder, the plate azimuths and the stamp')
    if got == EXPECT:
        print('  PASS - %d checks' % len(NAMES))
        print('         Dimensions show on all seven plates; WR-Notes and every')
        print('         loose TEXT callout are hidden on all seven; the wall picks')
        print('         name every unit; re-runs match on the stamp and never on')
        print('         the name, and an unstamped scene is untouchable.')
        print('         The interior plate is a locked two-point perspective and')
        print('         stands 22 in clear of the interior wall face at any size,')
        print('         off the door FRAME plane, whatever projection the view')
        print('         was in when it was aimed.')
        print('         The cm checks RAN the real aim(): front-on is square to')
        print('         the door ~16 ft back at eye height, the top-down is')
        print('         genuinely straight down, the high shot is 17 ft up at')
        print('         the angled bearing, the door bearing is a WALL NORMAL')
        print('         rather than a bearing to the door, and 06-plan is the')
        print('         only parallel-projected plate.')
        return 0
    exp = EXPECT.split(' | ')
    act = got.split(' | ')
    print('  FAIL')
    if len(act) != len(exp):
        print('  got      %s' % got)
        print('  expected %d checks, got %d' % (len(exp), len(act)))
        return 1
    for e, a in zip(exp, act):
        if e != a:
            print('    %s' % a)
    return 1


if __name__ == '__main__':
    sys.exit(main())
