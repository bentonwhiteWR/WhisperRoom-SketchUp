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
    plate 3 put back to the side elevation (az +90)      -> az1 FAIL
    renders_for's ladder reordered                       -> ld1 FAIL

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

module WR_ProposalScenes
%(shown_on_dimensioned)s
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

%(renders_for)s

%(mode_for)s

%(plate)s

%(plate_ids)s

%(az_for)s

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

  FIVE = %%w[01-exterior 02-dimensioned 03-front 04-ventilation 05-plan]
  SIX  = FIVE + %%w[06-interior]

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
  def self.loose
    [{ 'key' => 'e:101' }, { 'key' => 'e:102' }]
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
    ck('ts6', WR_AutoSet.scene_name('MDL 96120 E', '01-exterior') ==
              'MDL 96120 E 01-exterior')
    # A booth genuinely named "Rack-2" must not be mistaken for the second
    # "Rack" -- which is why token and label are two stored keys, not one
    # parsed string.
    ck('ts7', WR_AutoSet.next_token([], 'Rack-2') == ['Rack-2', 'Rack-2'])

    # ---- the stamp, and the containment rule ----------------------------
    tok  = 'MDL 96120 E'
    mine = FakePage.new('MDL 96120 E 01-exterior',
                        { 'token' => tok, 'plate' => '01-exterior', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # RENAMED BY HAND. Same stamp, different name. Matched on the stamp, so it
    # is updated -- and never renamed back.
    ren  = FakePage.new('Hero shot for Steve',
                        { 'token' => tok, 'plate' => '02-dimensioned', 'version' => 1,
                          'centre' => '10.000,20.000,30.000' })
    # A HAND-MADE SCENE WEARING THE EXPECTED NAME AND NO STAMP. Nothing in
    # this tool may touch it, Remove included.
    fake = FakePage.new('MDL 96120 E 03-front')
    other = FakePage.new('MDL 4872 E 01-exterior',
                         { 'token' => 'MDL 4872 E', 'plate' => '01-exterior',
                           'version' => 1, 'centre' => '0.000,0.000,0.000' })
    pages = [mine, fake, ren, other]
    got = WR_AutoSet.token_pages(pages, tok)
    ck('sm1', got.length == 2, got.map { |p| p.name }.inspect)
    ck('sm2', !got.include?(fake), 'an UNSTAMPED page was matched')
    ck('sm3', got.include?(ren), 'a page renamed by hand was not matched')
    ck('sm4', WR_AutoSet.page_for_plate(pages, tok, '02-dimensioned') == ren)
    ck('sm5', WR_AutoSet.page_for_plate(pages, tok, '03-front').nil?,
       'the unstamped page was returned for a plate it happens to be named after')
    ck('sm6', WR_AutoSet.tokens_in_use(pages) == [tok, 'MDL 4872 E'],
       WR_AutoSet.tokens_in_use(pages).inspect)
    ck('sm7', WR_AutoSet.page_stamp(fake).nil?)
    ck('sm8', WR_AutoSet.page_stamp(mine)['plate'] == '01-exterior')

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
    ck('ld1', WR_AutoSet.renders_for(2, FIVE) == ['01-exterior', '03-front'],
       WR_AutoSet.renders_for(2, FIVE).inspect)
    ck('ld2', WR_AutoSet.renders_for(0, FIVE) == [])
    ck('ld3', WR_AutoSet.renders_for(3, FIVE) ==
              ['01-exterior', '03-front', '04-ventilation'])
    # 06-interior is a rung, but only when the run actually makes that plate.
    ck('ld4', WR_AutoSet.renders_for(4, FIVE) ==
              ['01-exterior', '03-front', '04-ventilation', '02-dimensioned'],
       WR_AutoSet.renders_for(4, FIVE).inspect)
    ck('ld5', WR_AutoSet.renders_for(4, SIX) ==
              ['01-exterior', '03-front', '04-ventilation', '06-interior'])
    ck('ld6', WR_AutoSet.renders_for(99, FIVE).length == 5)
    ck('ld7', WR_AutoSet.renders_for(-1, FIVE) == [])
    ck('ld8', WR_AutoSet.mode_for('05-plan', ['01-exterior']) == 'image')
    ck('ld9', WR_AutoSet.mode_for('01-exterior', ['01-exterior']) == 'render')
    ck('ld10', WR_AutoSet::DEFAULT_RENDERS == 2)

    # ---- the plate azimuths ---------------------------------------------
    # az1 IS THE Q2 CHANGE. proposal-scenes.rb's plate 3 is a SIDE elevation
    # at az +90; both real proposal packs ask for a FRONT elevation with the
    # door open, so AUTO-SET aims plate 3 straight at the door side.
    ck('az1', WR_AutoSet.az_for('03-front', 12.0, nil) == 12.0,
       WR_AutoSet.az_for('03-front', 12.0, nil).inspect)
    ck('az2', WR_AutoSet.az_for('01-exterior', 0.0, nil) == 35.0)
    ck('az3', WR_AutoSet.az_for('02-dimensioned', 0.0, nil) == 35.0)
    ck('az4', WR_AutoSet.az_for('04-ventilation', 0.0, 90.0) == 115.0)
    # No WR-Booth-Vent: plate 04 is just the opposite side, plus the swing.
    ck('az5', WR_AutoSet.az_for('04-ventilation', 0.0, nil) == 205.0,
       WR_AutoSet.az_for('04-ventilation', 0.0, nil).inspect)
    # No WR-Booth-Door at all: the documented -90 fallback, which is exactly
    # the case the popover says out loud in orange BEFORE Apply.
    ck('az6', WR_AutoSet.az_for('03-front', nil, nil) == -90.0)
    ck('az7', WR_AutoSet.az_for('05-plan', 12.0, nil) == 12.0)
    ck('az8', WR_AutoSet.plate('03-front')[:el] == 0.0 &&
              WR_AutoSet.plate('03-front')[:persp] == false,
       'plate 3 is not a parallel elevation')
    ck('az9', WR_AutoSet.plate_ids(false) == FIVE, WR_AutoSet.plate_ids(false).inspect)
    ck('az10', WR_AutoSet.plate_ids(true) == SIX)
    # The interior plate's NAME has to keep matching proposal-package.rb's
    # INTERIOR_RE or the render row is silently mis-exposed.
    ck('az11', ('06-interior' =~ /interior|inside|in-booth|booth\s+in/i) ? true : false)

    # ---- THE ANNOTATION ALLOWLIST ---------------------------------------
    # an1/an2 are the two that matter most in this file.
    ck('an1', SIX.all? { |p| WR_AutoSet.annot_picks(p, sets, loose)['t:WR-Notes'] == true },
       'WR-Notes -- the D5 banner -- is SHOWN on a plate')
    ck('an2', SIX.all? do |p|
                pk = WR_AutoSet.annot_picks(p, sets, loose)
                loose.all? { |it| pk[it['key']] == true }
              end,
       'a loose/Untagged callout is SHOWN on a plate')
    ck('an3', shown_on('02-dimensioned') == ['WR-Dims', 'WR-Dims-Doors'],
       shown_on('02-dimensioned').inspect)
    ck('an4', shown_on('04-ventilation') == ['WR-Notes-Vent'],
       shown_on('04-ventilation').inspect)
    # Opt-in BY EXISTENCE: a shop that has never made that set gets a clean
    # plate rather than an error.
    no_vent = sets.reject { |s| s['name'] == 'WR-Notes-Vent' }
    ck('an5', shown_on('04-ventilation', no_vent) == [], shown_on('04-ventilation', no_vent).inspect)
    ck('an6', shown_on('05-plan') == ['WR-Dims', 'WR-Dims-Doors', 'WR-Notes-Plan'],
       shown_on('05-plan').inspect)
    ck('an7', %%w[01-exterior 03-front 06-interior].all? { |p| shown_on(p) == [] },
       'a clean plate is showing an annotation set')
    # FULL HASH: one key per set row plus one per loose row, and nothing else.
    pk = WR_AutoSet.annot_picks('02-dimensioned', sets, loose)
    ck('an8', pk.keys.length == sets.length + loose.length, pk.keys.length.to_s)
    ck('an9', SIX.all? do |p|
                q = WR_AutoSet.annot_picks(p, sets, loose)
                q['t:WR-Dims-Booth'] == true && q['t:WR-Dims-Selection'] == true
              end,
       'a working-dimension tag is SHOWN on a plate')
    # A set made this afternoon is matched live by the family regex and is on
    # no allowlist, so it is hidden -- not invisible to the tool, hidden BY it.
    ck('an10', SIX.all? { |p| WR_AutoSet.annot_picks(p, sets, loose)['t:WR-Notes-Custom'] == true })
    # A model with no annotations at all: an empty hash, not a crash.
    ck('an11', WR_AutoSet.annot_picks('01-exterior', [], []) == {})

    # ---- the never-shown gate -------------------------------------------
    ck('nv1', WR_AutoSet::NEVER_SHOWN.sort ==
              ['WR-Dims-Booth', 'WR-Dims-Selection', 'WR-Notes'],
       WR_AutoSet::NEVER_SHOWN.inspect)
    ck('nv2', WR_AutoSetPoison.effective_shown('01-exterior',
                %%w[WR-Dims WR-Notes WR-Dims-Booth]) == ['WR-Dims'],
       WR_AutoSetPoison.effective_shown('01-exterior',
                %%w[WR-Dims WR-Notes WR-Dims-Booth]).inspect)

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
    p1 = WR_AutoSet.wall_picks('01-exterior', units, centre, eye)
    hid = units.map { |u| u['key'] }.select { |k| p1[k] }
    ck('wp1', hid == ['w:front', 'w:corner'], hid.inspect)
    # PARTIAL HASHES ARE THE BUG. Every unit keyed, true or false, or a wall
    # hidden on the previous plate rides along into this one.
    ck('wp2', p1.keys.length == units.length, p1.keys.length.to_s)
    p2 = WR_AutoSet.wall_picks('05-plan', units, centre, eye)
    ck('wp3', p2.keys.length == units.length && p2.values.none? { |v| v },
       p2.inspect)
    p3 = WR_AutoSet.wall_picks('06-interior', units, centre, eye)
    ck('wp4', p3.values.none? { |v| v })
    # CANNOT-TELL SHOWS THE WALL. Failing toward showing a wall costs a
    # re-shot plate; failing toward hiding one costs a wrong image.
    ck('wp5', p1['w:onit'] == false)
    ck('wp6', WR_AutoSet.cone_dot([10.0, 0.0, 0.0], centre, centre).nil?)
    ck('wp7', WR_AutoSet.wall_picks('01-exterior', [], centre, eye) == {})
    # The vent plate looks from the other side, so the other walls go.
    eye2 = [-97.8, 0.0, 20.8]
    p4   = WR_AutoSet.wall_picks('04-ventilation', units, centre, eye2)
    ck('wp8', units.map { |u| u['key'] }.select { |k| p4[k] } == ['w:back'],
       units.map { |u| u['key'] }.select { |k| p4[k] }.inspect)
    # The cone is 60 degrees off the eye direction, both ways.
    ck('wp9', WR_AutoSet::COS_CONE == 0.5)

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
         'az1 az2 az3 az4 az5 az6 az7 az8 az9 az10 az11 '
         'an1 an2 an3 an4 an5 an6 an7 an8 an9 an10 an11 '
         'nv1 nv2 '
         'wp1 wp2 wp3 wp4 wp5 wp6 wp7 wp8 wp9').split()
EXPECT = ' | '.join('%s ok' % n for n in NAMES)


def main():
    ps = os.path.join(HERE, 'proposal-scenes.rb')
    prog = FIXTURE % {
        'shown_on_dimensioned': const_line('SHOWN_ON_DIMENSIONED', ps),
        'deg':             const_line('DEG'),
        'dict':            const_line('DICT'),
        'fallback_az':     const_line('FALLBACK_AZ'),
        'moved_tol':       const_line('MOVED_TOL'),
        'cos_cone':        const_line('COS_CONE'),
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
    if gone:
        print('  policy FAIL %s' % '; '.join(gone))
        return 1
    print('  policy ok - the annotation rule is still an allowlist plus a '
          'never-shown gate')

    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('wr-autoset: the annotation allowlist, the wall cone, the render '
          'ladder, the plate azimuths and the stamp')
    if got == EXPECT:
        print('  PASS - %d checks' % len(NAMES))
        print('         WR-Notes and every loose callout are hidden on all six')
        print('         plates, the wall picks name every unit, plate 3 is a')
        print('         FRONT elevation, re-runs match on the stamp and never')
        print('         on the name, and an unstamped scene is untouchable')
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
