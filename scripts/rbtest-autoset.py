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
    wall_picks' cone test inverted                       -> wp1 FAIL
    05-plan dropped from NO_WALL_PLATES                  -> wp3 FAIL
    token_pages matched by NAME instead of stamp         -> sm2, sm3 FAIL
    WR-Notes put back on a plate                         -> an1, nv1, nv2 FAIL
    loose TEXT shown (the D5 guard)                      -> an2 FAIL
    loose dimensions hidden again                        -> an2b FAIL
    the interior eye put back at radius * 0.55           -> in1, in2, in3 FAIL
    the interior camera tilted off level                 -> in6 FAIL
    the interior up vector tipped                        -> in7 FAIL
    the interior fov reset to the exterior lens          -> in9 FAIL
    the front plate given a swing (not square to door)   -> cm2 FAIL
    the plan plate put back to el 89                     -> cm5 FAIL
    any plate given cam.perspective = false              -> cm1 FAIL
    03-high put on the RENDER_LADDER                     -> cm11 FAIL
    05-ventilation added to NO_WALL_PLATES               -> cm12 FAIL
    empty_shown_note made to fire on a partial count     -> eb3 FAIL
    renders_for's ladder reordered                       -> ld1 FAIL

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
class FakeCamera
  attr_accessor :perspective, :fov, :height
  attr_reader :eye, :target, :up
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

class FakeView
  attr_reader :camera
  def initialize; @camera = FakeCamera.new; end
  def refresh; true; end
end

module WR_ProposalScenes
%(shown_on_dimensioned)s
%(deg)s

%(aim)s
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
%(cos_cone)s
%(dims_re)s
%(booth_wall_t)s
%(interior_eye_clear)s
%(interior_fov)s
%(standoff_k)s
%(standoff_c)s
%(plate_fov)s
%(max_renders)s
%(default_renders)s
%(plates)s
%(no_wall_plates)s
%(render_ladder)s
%(never_shown)s
%(shown_by_plate)s

%(effective_shown)s

%(annot_picks)s

%(unit_vec)s

%(cone_dot)s

%(wall_picks)s

%(ladder_renders)s

%(forced_renders)s

%(renders_for)s

%(mode_for)s

%(plate)s

%(plate_ids)s

%(az_for)s

%(standoff)s

%(reach)s

%(wall_axis)s

%(frame_hits)s

%(interior_eye_dist)s

%(policy_line)s

%(loose_split)s

%(plate_dist)s

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
  SHOWN_BY_PLATE = {
    '01-exterior' => %%w[WR-Dims WR-Notes WR-Dims-Booth]
  }.freeze

%(effective_shown)s
end

module T
  OUT = []
  def self.ck(name, ok, detail = nil)
    OUT << (ok ? "#{name} ok" : "#{name} FAIL#{detail ? ' ' + detail.to_s : ''}")
  end

  # The six plates a default run makes, and the seven that exist. Side is ON
  # by default even though Benton said "sometimes" -- see PLATES.
  DEFAULTS = %%w[01-front 02-angled 03-high 04-side 05-ventilation 06-plan]
  ALL      = DEFAULTS + %%w[07-interior]

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
  def self.cam(id, door = DOOR, vent = VENT)
    v = FakeView.new
    WR_AutoSet.aim_plate(v, id, CENTRE, RADIUS, door, vent, HALF)
    v.camera
  end

  # Where the eye ended up, relative to the booth centre, in the terms the
  # shot list is written in: compass bearing, height off the FLOOR, and how
  # far back along the ground.
  def self.shot(id, door = DOOR, vent = VENT)
    c = cam(id, door, vent)
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
    ck('ts6', WR_AutoSet.scene_name('MDL 96120 E', '01-front') ==
              'MDL 96120 E 01-front')
    # A booth genuinely named "Rack-2" must not be mistaken for the second
    # "Rack" -- which is why token and label are two stored keys, not one
    # parsed string.
    ck('ts7', WR_AutoSet.next_token([], 'Rack-2') == ['Rack-2', 'Rack-2'])

    # ---- the stamp, and the containment rule ----------------------------
    tok  = 'MDL 96120 E'
    mine = FakePage.new('MDL 96120 E 01-front',
                        { 'token' => tok, 'plate' => '01-front', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # RENAMED BY HAND. Same stamp, different name. Matched on the stamp, so it
    # is updated -- and never renamed back.
    ren  = FakePage.new('Hero shot for Steve',
                        { 'token' => tok, 'plate' => '02-angled', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # A HAND-MADE SCENE WEARING THE EXPECTED NAME AND NO STAMP. Nothing in
    # this tool may touch it, Remove included.
    fake = FakePage.new('MDL 96120 E 03-high')
    other = FakePage.new('MDL 4872 E 01-front',
                         { 'token' => 'MDL 4872 E', 'plate' => '01-front',
                           'version' => 1, 'centre' => '0.000,0.000,0.000' })
    pages = [mine, fake, ren, other]
    got = WR_AutoSet.token_pages(pages, tok)
    ck('sm1', got.length == 2, got.map { |p| p.name }.inspect)
    ck('sm2', !got.include?(fake), 'an UNSTAMPED page was matched')
    ck('sm3', got.include?(ren), 'a page renamed by hand was not matched')
    ck('sm4', WR_AutoSet.page_for_plate(pages, tok, '02-angled') == ren)
    ck('sm5', WR_AutoSet.page_for_plate(pages, tok, '03-high').nil?,
       'the unstamped page was returned for a plate it happens to be named after')
    ck('sm6', WR_AutoSet.tokens_in_use(pages) == [tok, 'MDL 4872 E'],
       WR_AutoSet.tokens_in_use(pages).inspect)
    ck('sm7', WR_AutoSet.page_stamp(fake).nil?)
    ck('sm8', WR_AutoSet.page_stamp(mine)['plate'] == '01-front')

    # ---- has the booth moved? -------------------------------------------
    ck('mv1', WR_AutoSet.centre_key([1.5, -2.25, 0]) == '1.500,-2.250,0.000',
       WR_AutoSet.centre_key([1.5, -2.25, 0]))
    ck('mv2', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [10.0, 20.0, 30.0]) == false)
    ck('mv3', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [46.0, 20.0, 30.0]) == true)
    ck('mv4', WR_AutoSet.centre_moved?('10.000,20.000,30.000', [10.5, 20.0, 30.0]) == false)
    # An unreadable stored centre is UNKNOWN, not MOVED: pre-ticking a re-aim
    # on no evidence would destroy a framing Benton fixed by hand.
    ck('mv5', WR_AutoSet.centre_moved?('', [10.0, 20.0, 30.0]) == false)

    # ---- the render ladder ----------------------------------------------
    # The clean plates render; the dimension-carrying ones are images.
    ck('ld1', WR_AutoSet.renders_for(2, DEFAULTS) == ['02-angled', '05-ventilation'],
       WR_AutoSet.renders_for(2, DEFAULTS).inspect)
    ck('ld2', WR_AutoSet.renders_for(0, DEFAULTS) == [])
    ck('ld3', WR_AutoSet.renders_for(3, DEFAULTS) ==
              ['02-angled', '05-ventilation', '04-side'])
    # 07-interior is a rung, but only when the run actually makes that plate.
    ck('ld4', WR_AutoSet.renders_for(4, DEFAULTS) ==
              ['02-angled', '05-ventilation', '04-side', '01-front'],
       WR_AutoSet.renders_for(4, DEFAULTS).inspect)
    # 07-interior is a FORCED render now, appended after the ladder's share
    # rather than occupying a rung of it.
    ck('ld5', WR_AutoSet.renders_for(4, ALL) ==
              ['02-angled', '05-ventilation', '04-side', '01-front', '07-interior'],
       WR_AutoSet.renders_for(4, ALL).inspect)
    # Only FIVE of the seven are on the ladder at all -- 03-high and 06-plan
    # can never be promoted, however high the knob goes.
    ck('ld6', WR_AutoSet.renders_for(99, DEFAULTS).length == 4,
       WR_AutoSet.renders_for(99, DEFAULTS).inspect)
    ck('ld7', WR_AutoSet.renders_for(-1, DEFAULTS) == [])
    ck('ld8', WR_AutoSet.mode_for('06-plan', ['02-angled']) == 'image')
    ck('ld9', WR_AutoSet.mode_for('02-angled', ['02-angled']) == 'render')
    ck('ld10', WR_AutoSet::DEFAULT_RENDERS == 2)

    # ---- FORCED RENDERS --------------------------------------------------
    # Benton, 10 Sep 2026: "fyi interior plate should always be a render."
    # A forced row is a render WHENEVER THE PLATE IS PRODUCED, at any setting
    # of the knob -- including ZERO, which is the case most likely to break.
    ck('fr1', WR_AutoSet.mode_for('07-interior',
                                  WR_AutoSet.renders_for(0, ALL)) == 'render',
       WR_AutoSet.renders_for(0, ALL).inspect)
    ck('fr2', (0..WR_AutoSet::MAX_RENDERS).all? do |n|
                WR_AutoSet.renders_for(n, ALL).include?('07-interior')
              end,
       'the interior plate can come out as an image')
    # ADDITIVE, NOT A SLOT. Ticking the interior box must not silently demote
    # the angled hero -- the knob answers "how many of the ORDINARY plates",
    # so 2 + the forced row is 3 renders, and the ladder's share is untouched.
    ck('fr3', WR_AutoSet.ladder_renders(2, ALL) == WR_AutoSet.ladder_renders(2, DEFAULTS),
       [WR_AutoSet.ladder_renders(2, ALL), WR_AutoSet.ladder_renders(2, DEFAULTS)].inspect)
    ck('fr4', WR_AutoSet.renders_for(2, ALL).length ==
              WR_AutoSet.renders_for(2, DEFAULTS).length + 1,
       WR_AutoSet.renders_for(2, ALL).inspect)
    # The plate is not on the ladder at all, so it cannot be double-counted.
    ck('fr5', !WR_AutoSet::RENDER_LADDER.include?('07-interior'),
       WR_AutoSet::RENDER_LADDER.inspect)
    # COST. A forced render on a plate that is OFF by default costs nothing
    # until Benton asks for that plate; on an always-on plate it would raise
    # the floor of EVERY run. If that ever needs to change, this check is what
    # makes it a decision rather than an accident -- edit it deliberately.
    ck('fr6', WR_AutoSet.forced_renders(ALL).all? { |id| WR_AutoSet.plate(id)[:on] == false },
       WR_AutoSet.forced_renders(ALL).inspect)
    ck('fr7', WR_AutoSet.forced_renders(DEFAULTS) == [],
       WR_AutoSet.forced_renders(DEFAULTS).inspect)

    # ---- the plate azimuths ---------------------------------------------
    # THE DOOR IS THE ANCHOR for everything except the vent shot. Benton:
    # "Find the door, step out like 15 ft or so. Straight on."
    ck('az1', WR_AutoSet.az_for('01-front', 12.0, nil) == 12.0,
       WR_AutoSet.az_for('01-front', 12.0, nil).inspect)
    ck('az2', WR_AutoSet.az_for('02-angled', 0.0, nil) == 35.0)
    ck('az3', WR_AutoSet.az_for('03-high', 0.0, nil) == 35.0)
    ck('az4', WR_AutoSet.az_for('05-ventilation', 0.0, 90.0) == 115.0)
    # No WR-Booth-Vent: the vent plate is just the opposite side, plus swing.
    ck('az5', WR_AutoSet.az_for('05-ventilation', 0.0, nil) == 205.0,
       WR_AutoSet.az_for('05-ventilation', 0.0, nil).inspect)
    # No WR-Booth-Door at all: the documented -90 fallback, which is exactly
    # the case the popover says out loud in orange BEFORE Apply.
    ck('az6', WR_AutoSet.az_for('01-front', nil, nil) == -90.0)
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
    ck('an2c', WR_AutoSet.annot_picks('01-front', [], [{ 'key' => 'e:999' }])['e:999'] == true,
       'an unreadable loose row was SHOWN')
    # EVERY DIMENSION TAG, ON EVERY PLATE (1.51.0).
    dims_all = %%w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Dims-Selection]
    ck('an3', shown_on('01-front').sort == dims_all.sort, shown_on('01-front').inspect)
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
    ck('an7', %%w[02-angled 04-side 07-interior].all? { |p| shown_on(p).sort == dims_all.sort },
       %%w[02-angled 04-side 07-interior].map { |p| shown_on(p) }.inspect)
    ck('an7b', ALL.all? { |p| (shown_on(p) - dims_all - %%w[WR-Notes-Vent WR-Notes-Plan]).empty? },
       'a plate is showing something that is neither a dimension nor its own note set')
    # FULL HASH: one key per set row plus one per loose row, and nothing else.
    pk = WR_AutoSet.annot_picks('01-front', sets, loose)
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
    ck('an11', WR_AutoSet.annot_picks('02-angled', [], []) == {})

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

    # ---- THE WALL CONE --------------------------------------------------
    # Booth at the origin; the camera 100 in away on +X at 12 degrees up --
    # the 01-exterior eye. Walls at the four compass points plus one sitting
    # on the booth centre, which is the degenerate case.
    centre = [0.0, 0.0, 0.0]
    eye    = [97.8, 0.0, 20.8]
    units  = [{ 'key' => 'w:front', 'c' => [50.0, 0.0, 40.0],  'label' => 'Room Wall 1' },
              { 'key' => 'w:back',  'c' => [-50.0, 0.0, 40.0], 'label' => 'Room Wall 2' },
              { 'key' => 'w:side',  'c' => [0.0, 50.0, 40.0],  'label' => 'Room Wall 3' },
              { 'key' => 'w:corner', 'c' => [40.0, 40.0, 40.0], 'label' => 'Room Wall 4' },
              { 'key' => 'w:onit',  'c' => [0.0, 0.0, 0.0],    'label' => 'Room Wall 5' }]
    p1 = WR_AutoSet.wall_picks('02-angled', units, centre, eye)
    hid = units.map { |u| u['key'] }.select { |k| p1[k] }
    ck('wp1', hid == ['w:front', 'w:corner'], hid.inspect)
    # PARTIAL HASHES ARE THE BUG. Every unit keyed, true or false, or a wall
    # hidden on the previous plate rides along into this one.
    ck('wp2', p1.keys.length == units.length, p1.keys.length.to_s)
    p2 = WR_AutoSet.wall_picks('06-plan', units, centre, eye)
    ck('wp3', p2.keys.length == units.length && p2.values.none? { |v| v },
       p2.inspect)
    p3 = WR_AutoSet.wall_picks('07-interior', units, centre, eye)
    ck('wp4', p3.values.none? { |v| v })
    # CANNOT-TELL SHOWS THE WALL. Failing toward showing a wall costs a
    # re-shot plate; failing toward hiding one costs a wrong image.
    ck('wp5', p1['w:onit'] == false)
    ck('wp6', WR_AutoSet.cone_dot([10.0, 0.0, 0.0], centre, centre).nil?)
    ck('wp7', WR_AutoSet.wall_picks('02-angled', [], centre, eye) == {})
    # The vent plate looks from the other side, so the other walls go.
    eye2 = [-97.8, 0.0, 20.8]
    p4   = WR_AutoSet.wall_picks('05-ventilation', units, centre, eye2)
    ck('wp8', units.map { |u| u['key'] }.select { |k| p4[k] } == ['w:back'],
       units.map { |u| u['key'] }.select { |k| p4[k] }.inspect)
    # The cone is 60 degrees off the eye direction, both ways.
    ck('wp9', WR_AutoSet::COS_CONE == 0.5)

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
    f = shot('01-front')
    ck('cm2', (f['az'] - DOOR).abs < 1.0e-6, f['az'].inspect)
    # ~16 ft back on the ground for this booth, which is "15 ft or so" and
    # not the 21 ft radius * 3.2 + 60 used to give.
    ck('cm3', f['run'] > 168.0 && f['run'] < 240.0, f['run'].round(1).to_s)
    # Standing eye height, not a bird. 4 ft - 8 ft off the floor.
    ck('cm4', f['z'] > 48.0 && f['z'] < 96.0, f['z'].round(1).to_s)

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
    ang = shot('02-angled')
    ck('cm10', (h['az'] - ang['az']).abs < 1.0e-6 &&
               (h['run'] - ang['run']).abs < 1.0, [h['run'], ang['run']].inspect)
    # "This is image." Not a render at ANY setting of the renders knob.
    ck('cm11', (0..WR_AutoSet::MAX_RENDERS).none? do |n|
                 WR_AutoSet.renders_for(n, ALL).include?('03-high')
               end,
       'the high shot can be promoted to a render')
    ck('cm11b', (0..WR_AutoSet::MAX_RENDERS).none? do |n|
                  WR_AutoSet.renders_for(n, ALL).include?('06-plan')
                end,
       'the top-down can be promoted to a render')

    # VENTILATION. "Usually a back view to show ventilation (this usually
    # requires a hidden wall)" -- so it must NOT be exempt from the wall cone.
    ck('cm12', !WR_AutoSet::NO_WALL_PLATES.include?('05-ventilation'),
       'the ventilation plate is exempt from the wall rule')
    vshot = shot('05-ventilation')
    ck('cm13', (vshot['az'] - (VENT + 25.0)).abs < 1.0e-6, vshot['az'].inspect)
    # A wall standing behind the booth on the vent side is hidden by the cone,
    # using the eye the REAL aim produced.
    vwall = [{ 'key' => 'w:rear', 'c' => [0.0, 90.0, 60.0], 'label' => 'Room Wall 2' },
             { 'key' => 'w:far',  'c' => [0.0, -90.0, 60.0], 'label' => 'Room Wall 1' }]
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
    # Only the front plate re-targets onto the frame; every other plate still
    # frames the whole booth.
    ck('fm6', WR_AutoSet.plate('01-front')[:aim_at] == :door)
    ck('fm7', (ALL - ['01-front']).none? { |id| WR_AutoSet.plate(id)[:aim_at] },
       (ALL - ['01-front']).select { |id| WR_AutoSet.plate(id)[:aim_at] }.inspect)
    # AIMED AT THE FRAME: with an off-centre door the eye stands on the wall
    # normal THROUGH THE FRAME, not through the booth centre.
    vv = FakeView.new
    anch = [36.0, -61.0, CENTRE[2]]
    WR_AutoSet.aim_plate(vv, '01-front', CENTRE, RADIUS, DOOR, VENT, HALF, anch)
    ck('fm8', (vv.camera.target.to_a[0] - 36.0).abs < 1.0e-9,
       vv.camera.target.to_a.inspect)
    ck('fm9', (vv.camera.eye.to_a[0] - 36.0).abs < 1.0e-6,
       'the eye is not on the frame normal')
    # With no anchor it falls back to the booth centre rather than raising.
    vv2 = FakeView.new
    WR_AutoSet.aim_plate(vv2, '01-front', CENTRE, RADIUS, DOOR, VENT, HALF, nil)
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

    # NO DOOR TAG AT ALL: the documented -90 fallback still produces a real
    # camera rather than raising.
    ck('cm18', shot('01-front', nil, nil)['az'] == WR_AutoSet::FALLBACK_AZ,
       shot('01-front', nil, nil)['az'].inspect)

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
    # A plate that shows nothing by design is not "blank" -- 02-angled is
    # meant to be clean, and telling Benton to dimension his model for it
    # would be noise.
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
         'sm1 sm2 sm3 sm4 sm5 sm6 sm7 sm8 '
         'mv1 mv2 mv3 mv4 mv5 '
         'ld1 ld2 ld3 ld4 ld5 ld6 ld7 ld8 ld9 ld10 '
         'fr1 fr2 fr3 fr4 fr5 fr6 fr7 '
         'az1 az2 az3 az4 az5 az6 az7 az8 az9 az10 az11 '
         'an1 an2 an2b an2c an3 an4 an5 an6 an7 an7b an8 an9 an10 an11 '
         'nv1 nv2 nv3 '
         'wp1 wp2 wp3 wp4 wp5 wp6 wp7 wp8 wp9 '
         'cm1 cm1b cm1c cm2 cm3 cm4 cm5 cm6 cm7 cm8 cm9 cm10 cm11 cm11b cm12 cm13 '
         'cm14 cm15 cm16 cm16b cm17 '
         'dr1 dr2 dr3 dr4 dr5 dr6 '
         'fm1 fm2 fm3 fm4 fm5 fm5b fm6 fm7 fm8 fm9 fm10 '
         'in1 in1b in1c in1d in2 in3 in4 in5 in6 in7 in8 in9 in10 '
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
        'cos_cone':        const_line('COS_CONE'),
        'dims_re':         const_line('DIMS_RE'),
        'booth_wall_t':    const_line('BOOTH_WALL_T'),
        'interior_eye_clear': const_line('INTERIOR_EYE_CLEAR'),
        'interior_fov':    const_line('INTERIOR_FOV'),
        'standoff_k':      const_line('STANDOFF_K'),
        'standoff_c':      const_line('STANDOFF_C'),
        'plate_fov':       const_line('PLATE_FOV'),
        'max_renders':     const_line('MAX_RENDERS'),
        'default_renders': const_line('DEFAULT_RENDERS'),
        'plates':          const_block('PLATES'),
        'no_wall_plates':  const_line('NO_WALL_PLATES'),
        'render_ladder':   const_block('RENDER_LADDER'),
        'never_shown':     const_line('NEVER_SHOWN'),
        'shown_by_plate':  const_block('SHOWN_BY_PLATE'),
        'effective_shown': rbtest.method_source(SRC, 'effective_shown'),
        'annot_picks':     rbtest.method_source(SRC, 'annot_picks'),
        'unit_vec':        rbtest.method_source(SRC, 'unit_vec'),
        'cone_dot':        rbtest.method_source(SRC, 'cone_dot'),
        'wall_picks':      rbtest.method_source(SRC, 'wall_picks'),
        'renders_for':     rbtest.method_source(SRC, 'renders_for'),
        'mode_for':        rbtest.method_source(SRC, 'mode_for'),
        'plate':           rbtest.method_source(SRC, 'plate'),
        'plate_ids':       rbtest.method_source(SRC, 'plate_ids'),
        'az_for':          rbtest.method_source(SRC, 'az_for'),
        'standoff':        rbtest.method_source(SRC, 'standoff'),
        'forced_renders':  rbtest.method_source(SRC, 'forced_renders'),
        'ladder_renders':  rbtest.method_source(SRC, 'ladder_renders'),
        'reach':           rbtest.method_source(SRC, 'reach'),
        'wall_axis':       rbtest.method_source(SRC, 'wall_axis'),
        'frame_hits':      rbtest.method_source(SRC, 'frame_hits'),
        'interior_eye_dist': rbtest.method_source(SRC, 'interior_eye_dist'),
        'policy_line':     rbtest.method_source(SRC, 'policy_line'),
        'loose_split':     rbtest.method_source(SRC, 'loose_split'),
        'plate_dist':      rbtest.method_source(SRC, 'plate_dist'),
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
    par = re.findall(r":id\s*=>\s*'([^']+)'[^}]*?:parallel\s*=>\s*true", src, re.S)
    if par != ['06-plan']:
        gone.append('the parallel plate(s) are %r -- it must be exactly '
                    "['06-plan']: the top-down is a drafting plan and every "
                    'other plate is a photograph' % (par,))
    if gone:
        print('  policy FAIL %s' % '; '.join(gone))
        return 1
    print('  policy ok - the annotation rule is still an allowlist plus a '
          'never-shown gate, and 06-plan is the only parallel plate')

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
        print('         stands 4 in clear of the interior wall face at any size.')
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
