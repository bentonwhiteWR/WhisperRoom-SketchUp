# -*- coding: utf-8 -*-
"""RUN wr-drop-lights.rb's pure placement logic outside SketchUp.

    python rbtest-lights.py

Same idea and same VM as rbtest.py / rbtest-overlays.py (read their headers):
the method sources are lifted VERBATIM from wr-drop-lights.rb on every run,
so the test cannot drift from the code — editing a method changes what runs
here.

WHAT IS EXERCISED — the whole pure section of wr-drop-lights.rb, against the
worked examples in .forge/researcher/interior-lighting-design.md:

  1. axis_points — the centred formula x_i = L(2i+1)/(2n).
  2. grid_points on the researcher's 12x15 room, 8' ceiling: Soft density
     must land exactly 4 lights at (3',3.75') offsets; Showroom must land
     all 12 (edge gaps 22.5" — the natural-gap cap on the edge threshold is
     what admits them; see edge_threshold's comment in the .rb).
  3. THE L-SHAPE: same room with a 6'x6' notch. The bbox grid point inside
     the notch must be culled by point_in_poly? alone — no special L case
     exists, the polygon tests ARE the L handling.
  4. Keep-out: a 7'x8' booth footprint (inflated 12") must cull exactly the
     four grid points over/next to it and re-flow nothing.
  5. Tiny room (30"x30"): every candidate fails the 18" edge floor — the
     single-centroid clause answers with one light, flagged.
  6. Wall-to-wall keep-out: everything culled — centroid fallback again,
     and the centroid is the AREA centroid (81, 76.5 on the L), never the
     bbox centre.
  7. Wall wash: opposite_edge picks the far antiparallel wall; 24" standoff;
     n = clamp(ceil(len/36"), 2, 4); positions centred; culled by keep-outs.
  8. Lumens: 180 sqft x 40 fc / 0.6 = 12,000 lm -> 3,000 each at Soft (4),
     1,000 each at Showroom (12); Bright x2 / Dim x0.5; booth 24 sqft x
     30 fc / 0.6 = 1,200.
  9. accent_axis — the rotation axis that tips -Z toward the booth face.
 10. subject_veto — the light-as-room incident guard: a 24"-tall subject
     and a shoebox floor are refused; a 6'+/9sqft+ room passes; the
     refusal text names the offending number.
 11. fallback_verdict — the multi-fallback rule: 0 or 1 fallback proceeds,
     2 or more refuses, and the refusal lists what fired and how many.
 12. light_words? — the pure core of vray_light?: BOTH "vray" and "light"
     must appear ("Daylight house" alone must not match).
 13. THE LIVE UTHSC ROOM (the 2026-08-27 "grid fully culled" refusal):
     239.25" x 268.25" (444.92 sf), 8' walls, Soft density. Must land the
     full 3x3 grid, and the new :diag accounting must show 9 candidates
     with zero rejections. Several lights, never one.
 14. Same room with a booth-sized keep-out (90x90 + 12" pad) in a corner:
     exactly one grid point dies, EIGHT remain — no centroid fallback.
 15. Same room with a wall-to-wall keep-out — what the room's own SUITE
     ancestor became when the old obstruction scan read model top level
     instead of the room's siblings. Fallback fires, and :diag must charge
     all nine candidates to the keep-out test, naming the culprit class.
 16. room_structure_child? — the obstruction child filter: floor/walls/
     doors are excluded by tag, or by name CASE-INSENSITIVELY (build-room
     writes "Walls", uthsc-audiology-rooms.rb writes "walls"); a booth
     child must NOT be excluded.
 17. doors_container? / door_child_kind — door detection matched to what
     the generators really write: build-room's "Doors">"Opening N"
     (WR-Doors) with "Door leaf N"/"Swing N" (WR-Doors-Leaf), and the
     UTHSC script's WR-Doors-tagged "doors" holding 'door leaf ...' solids
     and no Opening markers at all (the live "no door found" room).
 18. MOUNT PLANE: room lights sit FLUSH with the wall top (DROP = 0 —
     Benton's live render, 2026-08-27: a 6" drop drew a visible "light
     line" along the walls) while the closed-top booth keeps BOOTH_DROP =
     6" so its interior light clears the roof tray. Guards against the 6"
     room figure creeping back.
 19. THE 1.7.3/1.7.4 TAG REGRESSION: tag() must NEVER hide the "WR Lights"
     tag — in a draft-mode model it stays visible (the shipped 1.7.3 code
     hid it at placement, and the next manual V-Ray pass rendered unlit),
     a hidden tag is shown again in every mode, a fresh tag is born
     visible, and the console line says the tag is VISIBLE and names the
     Draft/Render toggle as the owner of hiding. Run against stub
     model/layer classes; the method itself is lifted verbatim.
 20. plugin_verdict — the /Rectangle Light incident (2026-08-27, observed
     live: seeds naming a plugin absent from the model's V-Ray scene
     placed, listed in the Asset Editor, and emitted nothing): a found
     plugin is :ok, an absent one :dangling (refused by name), an
     unanswerable scene :unknown (placed, loudly), a missing reference
     :no_ref (refused — not a working V-Ray light).
 21. plugin_listed? — exact plugin names, tolerant of a leading "/" on
     either side, never a substring match.
 22. booth_like? — the untagged-booth secondary test, banded to the real
     catalog envelope (reference/booth-models.md): the smallest (4230)
     and largest (102186) booths and a caster-lifted 7272 are in; a
     light, a room, a desk, a shallow cabinet, a long partition, and a
     room-height shaft are out.
 23. floor_child? — the WR-Floor tag or an exact "floor" name, any case:
     the predicate room_info reads a room by and the sibling-ROOM
     keep-out skip keys on (the live "keep-out: ROOM 2" incident, where
     an L-shaped neighbour room's bounding box punched a hole in this
     room's grid).

ALSO EXERCISED, from wr-mode.rb (same verbatim-lift protocol, second
program): the pin_light_tags snapshot pin — leaving render mode with
"WR Lights" hidden must NOT memorise hidden as the render-mode state (the
self-persisting unlit-render trap); light keys are pinned to the mode's
polarity, dim keys keep the remember-what-was-showing contract untouched,
a pre-LIGHT_TAGS snapshot gets the key filled, and nil/dim-less snapshots
pass through.

MUTATION-CHECKED 2026-08-27 (each mutation applied to wr-drop-lights.rb,
this test run, FAIL confirmed, mutation reverted): centred formula
(2i+1)->(2i); point_in_poly? crossing short-circuit (inside=true); edge
threshold dropped to 0; in_keepout? forced false; CU 0.6->0.5; centroid
/6a -> /2a; opposite_edge nearest-instead-of-farthest; WASH_SPACING
1.5->1.0. Note: flipping the ray-cast comparison (px < x_at -> px > x_at)
is NOT catchable — left and right crossing parity are equal for any closed
polygon, so that mutant is semantically equivalent, not a survivor.

MUTATION-CHECKED 2026-08-27 (validation additions, same protocol):
MIN_ROOM_H 72.0->20.0 (veto stops firing on the 24" light); MIN_ROOM_AREA
1296.0->50.0 (shoebox floor passes); fallback_verdict size<=1 -> size<=2
(two fallbacks slip through); light_words? vray term dropped (Daylight
matches). Each made this test FAIL and was reverted.

MUTATION-CHECKED 2026-08-27 evening (tag/mount/pin additions, same
protocol): tag() given a trailing `t.visible = false if mode == 'draft'`
(the 1.7.3 regression re-applied — note a hide placed BEFORE the
show-again branch is self-healed by it and is NOT a faithful mutant);
DROP 0.0->6.0; pin_light_tags weakened to fill-only (the old backfill
semantics — the exact memorisation trap); pin polarity flipped
render<->draft. All four KILLED (test failed) and were reverted. NOT
coverable here: wr-mode's to_mode wiring of the pin into its three
save/apply sites, and everything layer/render-side — SketchUp-API-side,
unverified until a live toggle and render.

MUTATION-CHECKED 2026-08-27 night (draft-is-flat additions to wr-mode.rb,
same protocol — each mutation applied, this test run, FAIL confirmed,
reverted): DEFAULT draft DisplayShadows false->true (the old shadows-on
default re-applied); pin_draft_flat polarity flipped draft<->render;
pin_draft_flat weakened to fill-only (the exact heal-loss trap — a
poisoned snapshot keeps its memorised shadows); apply_snapshot ro values
mis-written into shadow_info instead of rendering_options; apply_snapshot
ro read-back deleted (a silently-refused AmbientOcclusion key goes
unreported); pin_policy dropping the flat pin. All six KILLED. NOT
coverable here: whether this SketchUp build honours the AmbientOcclusion
rendering_options key at all (the key name is lifted from
angled-component-art.rb's live probe of SketchUp 24.0.553, and the
read-back names it as stuck if refused), and to_mode's live wiring —
SketchUp-API-side, unverified until a real toggle.

MUTATION-CHECKED 2026-08-27 late (plugin-resolution / sibling-room /
untagged-booth additions, same protocol — each applied, this test run,
FAIL confirmed, reverted): plugin_verdict absent-plugin arm :dangling ->
:unknown (a dead seed stops being refused); plugin_verdict no_ref -> :ok
(a dictionary-less seed passes); plugin_listed? normalisation dropped
(p == name — the leading-slash tolerance gone); BOOTH_SIDE_MIN 30->20
(the 26"-deep cabinet becomes a booth); BOOTH_SIDE_MAX 190->900 (the
200" partition becomes a booth); BOOTH_H_MIN 78->20 (the desk becomes a
booth); BOOTH_H_MAX 94->120 (the room-height shaft becomes a booth);
floor_child? name match made case-sensitive ("Floor" stops reading as a
floor). All eight KILLED. NOT coverable here: the V-Ray scene readers
(vray_scene / scene_plugin_names / plugin_probe / main_plugin_of), the
rebuild-from-source flow, and the sibling-room skip's wiring in
obstructions() — SketchUp/V-Ray-API-side, unverified until a live press.

MUTATION-CHECKED 2026-08-27 (UTHSC-incident additions, same protocol):
grid_points diag mis-charge (keep-out rejections counted as edge);
in_keepout? forced false; room_structure_child? name match made
case-sensitive; door_child_kind leaf regex made case-sensitive;
doors_container? name alternative dropped (tag only); grid nx ceil->floor.
All six KILLED (test failed) and were reverted. NOT coverable here: the
obstruction scan's siblings-not-model.entities fix and the reload guard
are SketchUp-API-side — the first is the actual incident fix and is
unverified until a live press.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

SRC = os.path.join(HERE, 'wr-drop-lights.rb')


def lift_method(lines, name):
    """Verbatim `def self.<name>` .. its closing two-space `end`."""
    pat = re.compile(r'^  def self\.%s(?![A-Za-z0-9_?!])' % re.escape(name))
    start = None
    for i, ln in enumerate(lines):
        if pat.match(ln):
            start = i
            break
    if start is None:
        raise SystemExit('wr-drop-lights.rb: no method self.%s' % name)
    for j in range(start + 1, len(lines)):
        if lines[j] == '  end':
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-drop-lights.rb: self.%s never closes' % name)


def lift_scalar(lines, name):
    """Verbatim single-line `  NAME = <number>` assignment (comment ok)."""
    pat = re.compile(r'^  %s\s*=\s*[-\d.]+\s*(#.*)?$' % re.escape(name))
    for ln in lines:
        if pat.match(ln):
            return ln
    raise SystemExit('wr-drop-lights.rb: no scalar constant %s' % name)


def lift_string(lines, name):
    """Verbatim single-line `  NAME = '...'.freeze` assignment (comment ok)."""
    pat = re.compile(r"^  %s\s*=\s*'[^']*'\.freeze\s*(#.*)?$" % re.escape(name))
    for ln in lines:
        if pat.match(ln):
            return ln
    raise SystemExit('wr-drop-lights.rb: no string constant %s' % name)


METHODS = ['grid_spacing', 'axis_points', 'point_in_poly?', 'seg_dist',
           'edge_dist', 'poly_signed_area', 'poly_area', 'poly_centroid',
           'in_keepout?', 'edge_threshold', 'grid_points', 'nearest_edge',
           'opposite_edge', 'wash_points', 'downlight_lumens',
           'booth_lumens', 'accent_axis', 'subject_veto',
           'fallback_verdict', 'light_words?', 'room_structure_child?',
           'doors_container?', 'door_child_kind', 'tag', 'floor_child?',
           'booth_like?', 'norm_plugin', 'plugin_listed?', 'plugin_verdict']
SCALARS = ['DROP', 'BOOTH_DROP', 'EDGE_MIN', 'EDGE_CAP', 'KEEPOUT_PAD',
           'HEADROOM', 'TARGET_FC', 'BOOTH_FC', 'CU', 'WASH_STANDOFF',
           'WASH_SPACING', 'ACCENT_OUT', 'ACCENT_TILT', 'MIN_ROOM_H',
           'MIN_ROOM_AREA', 'BOOTH_SIDE_MIN', 'BOOTH_SIDE_MAX',
           'BOOTH_H_MIN', 'BOOTH_H_MAX']
STRINGS = ['TAG', 'WR_MODE_DICT']
BLOCKS = ['ROOM_CHILD_TAGS', 'ROOM_CHILD_NAMES']


def lift_block(lines, name):
    """Verbatim multi-line `  NAME = ...` constant, through its `.freeze`."""
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith('  %s = ' % name):
            start = i
            break
    if start is None:
        raise SystemExit('wr-drop-lights.rb: no constant %s' % name)
    for j in range(start, len(lines)):
        if lines[j].rstrip().endswith('.freeze'):
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('wr-drop-lights.rb: %s never freezes' % name)

FIXTURE = r'''
# Stub tag/layer/model — just enough surface for the verbatim tag() method.
# No Sketchup::Color stub on purpose: tag() guards the color write with a
# rescue, and the stub-less NameError proves that guard holds.
class FakeTag
  attr_accessor :color
  def initialize(vis); @vis = vis; end
  def visible?; @vis; end
  def visible=(v); @vis = v; end
end
class FakeLayers
  def initialize(seed); @h = seed; end
  def [](n); @h[n]; end
  def add(n); @h[n] = FakeTag.new(true); end
end
class FakeModel
  attr_reader :layers
  def initialize(mode, tag_vis)
    seed = tag_vis.nil? ? {} : { 'WR Lights' => FakeTag.new(tag_vis) }
    @layers = FakeLayers.new(seed)
    @mode = mode
  end
  def get_attribute(_d, k); k == 'current' ? @mode : nil; end
end

module WR_DropLights
  LOG = []
  def self.puts(s = ''); LOG << s.to_s; end # capture tag()'s console lines

__CONSTS__

__METHODS__

  # The researcher's worked room: 12' x 15', 8' ceiling.
  RECT = [[0.0, 0.0], [144.0, 0.0], [144.0, 180.0], [0.0, 180.0]]
  # Same room with a 6' x 6' notch out of the top-left: a first-class L.
  LPOLY = [[0.0, 0.0], [144.0, 0.0], [144.0, 180.0], [72.0, 180.0],
           [72.0, 108.0], [0.0, 108.0]]
  TINY = [[0.0, 0.0], [30.0, 0.0], [30.0, 30.0], [0.0, 30.0]]
  # The LIVE room the 2026-08-27 refusal happened in: UTHSC Audiology
  # Room 1, 19'-11 1/4" x 22'-4 1/4" (444.92 sf), 8' walls.
  UROOM = [[0.0, 0.0], [239.25, 0.0], [239.25, 268.25], [0.0, 268.25]]

  def self.pts_s(pts)
    pts.map { |p| p.map { |v| v.round(2) }.join(',') }.join(';')
  end

  def self.check
    out = []

    out << 'axis ' + axis_points(144.0, 3).map { |v| v.round(2) }.join(',')

    g = grid_points(RECT, 96.0, :soft, [])
    out << format('soft4 %s s%s fb%d', pts_s(g[:pts]), g[:s].round(2),
                  g[:fallback] ? 1 : 0)

    g = grid_points(RECT, 96.0, :showroom, [])
    has = g[:pts].any? { |p| (p[0] - 24.0).abs < 1e-6 && (p[1] - 22.5).abs < 1e-6 }
    out << format('show12 n%d has%d s%s', g[:pts].size, has ? 1 : 0, g[:s].round(2))

    g = grid_points(LPOLY, 96.0, :soft, [])
    out << format('Lsoft %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    # A 7'x8' booth at (6,6)-(90,90), pre-inflated by KEEPOUT_PAD = 12.
    g = grid_points(RECT, 96.0, :showroom, [[-6.0, -6.0, 102.0, 102.0]])
    miss = g[:pts].none? { |p| p[0] < 102.0 && p[1] < 102.0 }
    out << format('keepout n%d clear%d', g[:pts].size, miss ? 1 : 0)

    g = grid_points(TINY, 96.0, :soft, [])
    out << format('tiny %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    g = grid_points(RECT, 96.0, :soft, [[-1000.0, -1000.0, 1000.0, 1000.0]])
    out << format('cullall %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    out << 'Lcentroid ' + poly_centroid(LPOLY).map { |v| v.round(2) }.join(',')

    out << format('edist %s %s', edge_dist(36.0, 45.0, LPOLY).round(2),
                  edge_dist(70.0, 110.0, LPOLY).round(2))

    out << 'inpoly ' + [point_in_poly?(36.0, 135.0, LPOLY),
                        point_in_poly?(108.0, 135.0, LPOLY),
                        point_in_poly?(81.0, 76.5, LPOLY)]
                       .map { |b| b ? '1' : '0' }.join(' ')

    out << format('near %d', nearest_edge(RECT, 72.0, 0.5))
    out << format('opp %d %d', opposite_edge(RECT, 0), opposite_edge(LPOLY, 0))

    out << 'washR ' + pts_s(wash_points(RECT, 2, []))
    out << 'washL ' + pts_s(wash_points(LPOLY, 2, []))
    out << 'washK ' + pts_s(wash_points(RECT, 2, [[120.0, 150.0, 132.0, 162.0]]))

    a = poly_area(RECT)
    out << format('lm %d %d %d %d %d',
                  downlight_lumens(a, 4, 1.0), downlight_lumens(a, 12, 1.0),
                  downlight_lumens(a, 4, 2.0), downlight_lumens(a, 4, 0.5),
                  booth_lumens(3456.0, 1.0))

    out << format('thr %s %s %s', edge_threshold(48.0, 24.0, 22.5).round(2),
                  edge_threshold(96.0, 36.0, 45.0).round(2),
                  edge_threshold(96.0, 15.0, 15.0).round(2))

    out << 'axis35 ' + accent_axis(-1, 0).map { |v| v.round(2) }.join(',') +
           ' ' + accent_axis(0, -3).map { |v| v.round(2) }.join(',')

    # 10 — the light-as-room incident: Benton's 24"-tall rectangle light
    # (a) and a 100 sqin floor (b) are vetoed; 71.9" (c) is still below the
    # 72" bar; a 12'x20' room at 8' (d) passes. The veto text must carry
    # the offending number (the 24).
    out << 'veto ' + [subject_veto(24.0, 100000.0),
                      subject_veto(96.0, 100.0),
                      subject_veto(71.9, 100000.0),
                      subject_veto(96.0, 34560.0)]
                     .map { |v| v ? '1' : '0' }.join +
           ((v = subject_veto(24.0, 100000.0)) && v.include?('24') ? ' msg1' : ' msg0')

    # 11 — the multi-fallback rule: 0 and 1 proceed (nil), 2 and 3 refuse,
    # and the refusal names the count and the fired fallbacks.
    fv = fallback_verdict(%w[x y])
    out << 'fbv ' + [fallback_verdict([]), fallback_verdict(['a']),
                     fallback_verdict(%w[a b]), fallback_verdict(%w[a b c])]
                    .map { |v| v ? '1' : '0' }.join +
           (fv && fv.include?('x') && fv.include?('y') && fv.include?('2') ? ' list1' : ' list0')

    # 12 — light_words?: needs BOTH vray and light.
    out << 'lw ' + [light_words?('SketchUp VRay dict: lights'),
                    light_words?('V-Ray Rectangle Light'),
                    light_words?('Daylight house'),
                    light_words?('vray infinite plane')]
                   .map { |b| b ? '1' : '0' }.join

    # 13 — the live UTHSC room, no keep-outs: a 445 sqft room at Soft
    # density MUST land a full 3x3 grid, with the diagnostics accounting
    # for every candidate. The 2026-08-27 run reported "grid fully culled"
    # here, which this line proves is impossible without a phantom keep-out
    # (it was the room's own suite ancestor, swallowed by the old top-level
    # obstruction scan).
    g = grid_points(UROOM, 96.0, :soft, [])
    d = g[:diag]
    out << format('uroom n%d fb%d cand%d rej%d,%d,%d thr%s', g[:pts].size,
                  g[:fallback] ? 1 : 0, d[:cand], d[:out], d[:edge],
                  d[:keep], d[:thr].round(2))

    # 14 — a booth-sized keep-out in the SW corner (a 90x90 booth inflated
    # by the 12" pad): exactly one grid point dies, EIGHT lights remain —
    # never the single-centroid fallback.
    g = grid_points(UROOM, 96.0, :soft, [[-12.0, -12.0, 102.0, 102.0]])
    d = g[:diag]
    out << format('ubooth n%d fb%d keep%d', g[:pts].size,
                  g[:fallback] ? 1 : 0, d[:keep])

    # 15 — the incident replayed: one wall-to-wall keep-out (what the suite
    # group became). The centroid fallback fires and the diagnostics must
    # charge all nine candidates to the keep-out test, not the others.
    g = grid_points(UROOM, 96.0, :soft, [[-12.0, -12.0, 900.0, 900.0]])
    d = g[:diag]
    out << format('usuite %s fb%d rej%d,%d,%d', pts_s(g[:pts]),
                  g[:fallback] ? 1 : 0, d[:out], d[:edge], d[:keep])

    # 16 — room_structure_child?: the room's own floor/walls/doors are
    # NEVER keep-outs — by tag, or by name CASE-INSENSITIVELY (build-room
    # writes "Walls", the UTHSC script writes "walls") — while a wall-like
    # booth child MUST still become one.
    out << 'rsc ' + [room_structure_child?('WR-Room', 'walls'),
                     room_structure_child?('Layer0', 'walls'),
                     room_structure_child?('Layer0', 'Walls'),
                     room_structure_child?('WR-Room-Upper', 'whatever'),
                     room_structure_child?('Layer0', 'WhisperRoom 7272 E'),
                     room_structure_child?('WR-Booth-Walls', 'panel')]
                    .map { |b| b ? '1' : '0' }.join

    # 17 — the door classifiers against what the two generators REALLY
    # write: build-room.rb's untagged "Doors" container holding "Opening N"
    # (WR-Doors) / "Door leaf N" / "Swing N" (WR-Doors-Leaf), and the UTHSC
    # script's WR-Doors-tagged "doors" container holding 'door leaf ...'
    # solids and a loose swing arc — the live "no door found" room.
    out << 'dc ' + [doors_container?('Layer0', 'Doors'),
                    doors_container?('WR-Doors', 'doors'),
                    doors_container?('WR-Doors', 'Opening 3'),
                    doors_container?('Layer0', 'Floor')]
                   .map { |b| b ? '1' : '0' }.join
    # 18 — mount plane: room lights FLUSH with the wall top (Benton's
    # render, 2026-08-27 — the 6" drop drew a "light line" on the walls);
    # the closed-top booth keeps a real 6" drop to clear its roof tray.
    out << format('mount %.1f %.1f', DROP, BOOTH_DROP)

    # 19 — the 1.7.3 tag regression: placement NEVER hides "WR Lights".
    # (a) draft-mode model, visible tag — the shipped regression hid it
    # here; (b) draft-mode model, hidden tag — healed to visible; (c)
    # render mode, hidden — shown; (d) no tag yet — born visible. The
    # console must say VISIBLE and hand hiding to the Draft/Render toggle.
    LOG.clear
    a = tag(FakeModel.new('draft', true)).visible?
    b = tag(FakeModel.new('draft', false)).visible?
    say = LOG.any? { |l| l.include?('VISIBLE') } &&
          LOG.any? { |l| l.include?('Draft/Render') }
    c = tag(FakeModel.new('render', false)).visible?
    d = tag(FakeModel.new(nil, nil)).visible?
    out << 'tag ' + [a, b, c, d].map { |v| v ? '1' : '0' }.join +
           (say ? ' say1' : ' say0')

    out << 'dk ' + [door_child_kind('WR-Doors', 'Opening 3') == :opening,
                    door_child_kind('Layer0', 'door leaf 36" ASSUMED, swings in') == :leaf,
                    door_child_kind('WR-Doors-Leaf', 'Door leaf 3') == :leaf,
                    door_child_kind('WR-Doors-Leaf', 'Swing 3').nil?,
                    door_child_kind('Layer0', 'wall').nil?]
                   .map { |b| b ? '1' : '0' }.join

    # 20 — plugin_verdict: the /Rectangle Light incident decision table.
    # found -> ok; absent -> dangling (refuse by name); scene would not
    # answer -> unknown (place, loudly); no reference at all -> no_ref
    # (refuse: not a working V-Ray light), whatever `exists` says.
    out << 'pv ' + [plugin_verdict('/Rectangle Light', true) == :ok,
                    plugin_verdict('/Rectangle Light', false) == :dangling,
                    plugin_verdict('/Rectangle Light', nil) == :unknown,
                    plugin_verdict(nil, true) == :no_ref,
                    plugin_verdict('  ', false) == :no_ref]
                   .map { |b| b ? '1' : '0' }.join

    # 21 — plugin_listed?: exact names, tolerant of a leading "/" on
    # either side, never a substring match.
    out << 'pl ' + [plugin_listed?('/Standard Light', ['/CameraPhysical', '/Standard Light']),
                    plugin_listed?('Standard Light', ['/Standard Light']),
                    plugin_listed?('/Standard Light', ['Standard Light']),
                    plugin_listed?('/Rectangle Light', ['/Standard Light']),
                    plugin_listed?('/Light', ['/Standard Light'])]
                   .map { |b| b ? '1' : '0' }.join

    # 22 — booth_like? against real catalog envelopes
    # (reference/booth-models.md): 4230 Std 44x32x83 (the smallest) and
    # 102186 Enh 104x188x85 (the largest) are in; a 7272 lifted 5" on a
    # caster plate (74x74x88) is in; a 24x48 rectangle light, the live
    # UTHSC ROOM 1 itself (239x268x96), a 30"-tall desk, a 26"-deep
    # cabinet, a 200"-long partition at booth height, and a 74x74 shaft
    # at room height are all out — the last two isolate the upper side
    # and height bounds the room case cannot.
    out << 'bl ' + [booth_like?(44.0, 32.0, 83.0),
                    booth_like?(104.0, 188.0, 85.0),
                    booth_like?(74.0, 74.0, 88.0),
                    booth_like?(24.0, 48.0, 2.0),
                    booth_like?(239.25, 268.25, 96.0),
                    booth_like?(30.0, 60.0, 30.0),
                    booth_like?(44.0, 26.0, 83.0),
                    booth_like?(74.0, 200.0, 83.0),
                    booth_like?(74.0, 74.0, 96.0)]
                   .map { |b| b ? '1' : '0' }.join

    # 23 — floor_child?: the WR-Floor tag or an exact "floor" name (any
    # case) — the predicate room_info reads a room by and the sibling-ROOM
    # keep-out skip keys on (the "keep-out: ROOM 2" incident).
    out << 'fc ' + [floor_child?('WR-Floor', 'anything'),
                    floor_child?('Layer0', 'floor'),
                    floor_child?('Layer0', 'Floor'),
                    floor_child?('Layer0', 'floorboard'),
                    floor_child?('WR-Booth-Deck', 'panel')]
                   .map { |b| b ? '1' : '0' }.join

    out.join(' | ')
  end
end
WR_DropLights.check
'''

EXPECT = ' | '.join([
    'axis 24.0,72.0,120.0',
    'soft4 36.0,45.0;36.0,135.0;108.0,45.0;108.0,135.0 s96.0 fb0',
    'show12 n12 has1 s48.0',
    'Lsoft 36.0,45.0;108.0,45.0;108.0,135.0 fb0',
    'keepout n8 clear1',
    'tiny 15.0,15.0 fb1',
    'cullall 72.0,90.0 fb1',
    'Lcentroid 81.0,76.5',
    'edist 36.0 2.0',
    'inpoly 0 1 1',
    'near 0',
    'opp 2 2',
    'washR 126.0,156.0;90.0,156.0;54.0,156.0;18.0,156.0',
    'washL 126.0,156.0;90.0,156.0',
    'washK 90.0,156.0;54.0,156.0;18.0,156.0',
    'lm 3000 1000 6000 1500 1200',
    'thr 22.5 36.0 18.0',
    'axis35 0.0,1.0 -1.0,0.0',
    'veto 1110 msg1',
    'fbv 0011 list1',
    'lw 1100',
    'uroom n9 fb0 cand9 rej0,0,0 thr36.0',
    'ubooth n8 fb0 keep1',
    'usuite 119.63,134.13 fb1 rej0,0,9',
    'rsc 111100',
    'dc 1100',
    'mount 0.0 6.0',
    'tag 1111 say1',
    'dk 11111',
    'pv 11111',
    'pl 11100',
    'bl 111000000',
    'fc 11100',
])

# ---- second program: wr-mode.rb's snapshot pins -------------------------
#
# Trap 1 (lights): hide "WR Lights" while IN render mode, toggle away, and
# the leave-mode snapshot memorises hidden as "the render state" — every
# future render entry re-hides the lights, silently, forever.
# pin_light_tags (lifted verbatim from wr-mode.rb, with its LIGHT_TAGS
# list) must pin light keys to the mode's polarity while leaving the dim
# keys' remember-what-was-showing contract alone.
#
# Trap 2 (shadows/AO — Benton, 2026-08-27 evening: "draft mode still shows
# shadows"): every model toggled before the draft-is-flat fix stored a
# draft snapshot with DisplayShadows true and no 'ro' key at all, so a
# DEFAULT change alone can never fix an already-toggled model.
# pin_draft_flat must HEAL such a snapshot — DisplayShadows forced off,
# the 'ro' hash created with AmbientOcclusion off — while a render
# snapshot passes through as pure memory (V-Ray owns that look). Also
# exercised with stub model classes: snapshot() records AmbientOcclusion
# under 'ro' from model.rendering_options (NOT shadow_info — the two-API
# split is the whole reason shadows-off never removed the AO puddles),
# and apply_snapshot() writes it back, read-back included, naming a
# refusing key as "render-option AmbientOcclusion" in the stuck list.

MODE_SRC = os.path.join(HERE, 'wr-mode.rb')

MODE_FIXTURE = r'''
# Stubs for the SketchUp surface snapshot/apply_snapshot touch. FakeOpts
# stands in for both shadow_info and rendering_options; a key on its
# refuse list no-ops the write SILENTLY, exactly how RenderingOptions
# treats a key a SketchUp build does not know — only read-back catches it.
module WR_Shading
  DEF_LIGHT = 80
  DEF_DARK  = 45
  SHADOW_KEYS = %w[DisplayShadows UseSunForAllShading Light Dark].freeze
end
class FakeOpts
  def initialize(seed = {}, refuse = [])
    @h = seed
    @refuse = refuse
  end
  def [](k); @h[k]; end
  def []=(k, v); @h[k] = v unless @refuse.include?(k); end
end
class FakeModel
  attr_reader :shadow_info, :rendering_options
  def initialize(si, ro)
    @shadow_info = si
    @rendering_options = ro
  end
  def layers; {}; end
  def styles; nil; end # snapshot's style read is rescue-guarded
end

module WR_Mode
  DIM_TAGS = ['WR-Dims'].freeze
__CONSTS__

__METHODS__

  def self.check
    out = []
    # leaving render with "WR Lights" hidden: pinned back to true, dim
    # keys untouched either way round.
    s = { 'dims' => { 'WR Lights' => false, 'WR-Dims' => false, 'WR-Notes' => true } }
    pin_light_tags(s, 'render')
    out << 'rpin ' + [s['dims']['WR Lights'] == true,
                      s['dims']['WR-Dims'] == false,
                      s['dims']['WR-Notes'] == true].map { |b| b ? '1' : '0' }.join
    # draft polarity: a visible light tag is pinned back to hidden.
    s = { 'dims' => { 'WR Lights' => true } }
    pin_light_tags(s, 'draft')
    out << format('dpin %d', s['dims']['WR Lights'] == false ? 1 : 0)
    # a pre-LIGHT_TAGS snapshot (key absent entirely): the pin fills it.
    s = { 'dims' => {} }
    pin_light_tags(s, 'render')
    out << format('fill %d', s['dims']['WR Lights'] == true ? 1 : 0)
    # nil and dim-less snapshots pass through untouched.
    out << format('nil %d%d', pin_light_tags(nil, 'render').nil? ? 1 : 0,
                  pin_light_tags({}, 'render') == {} ? 1 : 0)

    # THE HEAL: a real pre-fix draft snapshot — shadows memorised ON, no
    # 'ro' key anywhere. pin_draft_flat forces DisplayShadows off and
    # CREATES the ro hash with AO off, while sun, Light/Dark and the dim
    # keys keep their remembered values.
    s = { 'dims' => { 'WR-Dims' => true },
          'shadow' => { 'DisplayShadows' => true, 'UseSunForAllShading' => true,
                        'Light' => 70, 'Dark' => 60 } }
    pin_draft_flat(s, 'draft')
    out << 'heal ' + [s['shadow']['DisplayShadows'] == false,
                      s['ro'].is_a?(Hash) && s['ro']['AmbientOcclusion'] == false,
                      s['shadow']['UseSunForAllShading'] == true,
                      s['shadow']['Light'] == 70 && s['shadow']['Dark'] == 60,
                      s['dims']['WR-Dims'] == true].map { |b| b ? '1' : '0' }.join
    # render side: shadows/AO are pure MEMORY — pass through untouched.
    s = { 'shadow' => { 'DisplayShadows' => true },
          'ro' => { 'AmbientOcclusion' => true } }
    pin_draft_flat(s, 'render')
    out << 'rmem ' + [s['shadow']['DisplayShadows'] == true,
                      s['ro']['AmbientOcclusion'] == true].map { |b| b ? '1' : '0' }.join
    # nil passes through; pin_policy applies BOTH pins in one call.
    s = { 'dims' => { 'WR Lights' => true },
          'shadow' => { 'DisplayShadows' => true } }
    pin_policy(s, 'draft')
    out << 'both ' + [pin_draft_flat(nil, 'draft').nil?,
                      s['dims']['WR Lights'] == false,
                      s['shadow']['DisplayShadows'] == false,
                      s['ro']['AmbientOcclusion'] == false].map { |b| b ? '1' : '0' }.join
    # the shipped DEFAULTs: draft flat (shadows AND AO off), render
    # photographic (shadows on, AO deliberately left alone — empty ro).
    out << 'def ' + [DEFAULT['draft']['shadow']['DisplayShadows'] == false,
                     DEFAULT['draft']['ro']['AmbientOcclusion'] == false,
                     DEFAULT['render']['shadow']['DisplayShadows'] == true,
                     DEFAULT['render']['ro'] == {}].map { |b| b ? '1' : '0' }.join
    # apply_snapshot lands AO in rendering_options and shadows in
    # shadow_info, reads both back, and a silently-refused render-option
    # key is named in the stuck list rather than lost.
    si = FakeOpts.new({ 'DisplayShadows' => true })
    ro = FakeOpts.new({ 'AmbientOcclusion' => true })
    stuck = apply_snapshot(FakeModel.new(si, ro),
                           { 'shadow' => { 'DisplayShadows' => false },
                             'ro' => { 'AmbientOcclusion' => false } })
    ok = stuck.empty? && si['DisplayShadows'] == false && ro['AmbientOcclusion'] == false
    stuck = apply_snapshot(FakeModel.new(FakeOpts.new({}), FakeOpts.new({}, ['AmbientOcclusion'])),
                           { 'ro' => { 'AmbientOcclusion' => false } })
    named = stuck.size == 1 && stuck[0].include?('AmbientOcclusion') &&
            stuck[0].include?('render-option')
    out << format('apply %d%d', ok ? 1 : 0, named ? 1 : 0)
    # snapshot records the live AO value under 'ro', from rendering_options.
    snap = snapshot(FakeModel.new(FakeOpts.new({ 'DisplayShadows' => true }),
                                  FakeOpts.new({ 'AmbientOcclusion' => true })))
    out << format('snap %d', snap['ro'] == { 'AmbientOcclusion' => true } ? 1 : 0)
    out.join(' | ')
  end
end
WR_Mode.check
'''

MODE_EXPECT = ' | '.join(['rpin 111', 'dpin 1', 'fill 1', 'nil 11',
                          'heal 11111', 'rmem 11', 'both 1111',
                          'def 1111', 'apply 11', 'snap 1'])


def compare(title, got, expect):
    print(title)
    if got == expect:
        print('  PASS  (%d checks in one transcript)' % len(expect.split(' | ')))
        return 0
    ge = got.split(' | ')
    ee = expect.split(' | ')
    for i in range(max(len(ge), len(ee))):
        g = ge[i] if i < len(ge) else '(missing)'
        e = ee[i] if i < len(ee) else '(unexpected)'
        mark = 'ok  ' if g == e else 'FAIL'
        print('  %s got %-60s want %s' % (mark, g, e))
    return 1


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    consts = '\n'.join([lift_scalar(lines, c) for c in SCALARS] +
                       [lift_string(lines, c) for c in STRINGS] +
                       [lift_block(lines, c) for c in BLOCKS])
    prog = (FIXTURE
            .replace('__CONSTS__', consts)
            .replace('__METHODS__', '\n\n'.join(lift_method(lines, m) for m in METHODS)))
    lib = rbparse.boot()
    rc = compare('wr-drop-lights pure placement: grid, L-shape, keep-outs, '
                 'centroid, wash, lumens, mount plane, tag regression',
                 rbparse.rb_eval(lib, prog), EXPECT)

    mlines = open(MODE_SRC, encoding='utf-8').read().split('\n')
    mode_methods = ['pin_light_tags', 'pin_draft_flat', 'pin_policy',
                    'snapshot', 'apply_snapshot']
    mode_consts = ['LIGHT_TAGS', 'RO_KEYS', 'DEFAULT']
    mprog = (MODE_FIXTURE
             .replace('__CONSTS__', '\n'.join(lift_block(mlines, c) for c in mode_consts))
             .replace('__METHODS__', '\n\n'.join(lift_method(mlines, m) for m in mode_methods)))
    rc |= compare('wr-mode snapshot pins: lights and draft-flatness are '
                  'policy, never memory (incl. the poisoned-snapshot heal)',
                  rbparse.rb_eval(lib, mprog), MODE_EXPECT)
    return rc


if __name__ == '__main__':
    sys.exit(main())
