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
     1,000 each at Showroom (12); Bright x2 / Dim x0.5. (The booth-interior
     budget line went with the role at 1.44.0.)
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
 20. grid_count — THE OVERLAPPING-ROW FIX (Benton, observed 2026-08-28:
     "one side would always get overlapping lights, like an extra row
     they squeezed in on top"). A room side that is an exact multiple of
     the spacing arrives from transformed geometry as 192.0000000001, and
     a bare ceil() answers 3 rows where 2 were meant — on that axis only.
     Pinned both as the raw count and as a whole grid: a 16' x 12' room at
     8' ceiling, Soft, with 1e-7" of float noise on the long side must
     land 2 x 2 = FOUR lights, not 3 x 2 = six. Reverting the fix in
     wr-drop-lights.rb makes this line fail.
 21. kelvin_rgb and THE LUMEN COLUMN (1.9.9). The Kelvin curve is pinned
     at 6600 K, which is white by construction, plus two shipped answers
     and both clamp ends. Then, in place of the deleted scalar column:
     layer_lumens against Brightness and the enclosure trims; area_scale
     with BOTH clamps (the lumen table is quoted for a 192 sq ft room and
     a real room is not that room); the seven-role table's instance count,
     visible count, distinct Kelvins and per-budget totals — a rig with
     fewer than five distinct colour temperatures fails outright, because
     one colour on everything is the fault this rewrite exists to fix; the
     Warmth offset; the fixture geometry maths (a ring closes, a shell
     costs 4n faces, five fixtures stay inside the 600-face budget); the
     sconce row at its 3" standoff with the inward wall normal; and the
     pendant corner and ceiling pair, both booth-relative.
 22. param_agrees? — the read-back comparator. Every plugin write is read
     back and compared, because a V-Ray parameter that silently refuses a
     write is a black render an hour later. An integer flag and a boolean
     are the same answer (the dump prints invisible as 0/1, `each` yields
     true/false); floats compare with tolerance; a colour compares
     component-wise; anything else is a mismatch, never a shrug.
 23. in_box? — the stale-sweep containment test with BOX_TOL slack. Room
     lights mount FLUSH (DROP = 0) so their origin lies exactly on the
     room bbox's top face; an exclusive test would miss every one of them
     on a re-press and DOUBLE the grid.
 24. booth_like? — the untagged-booth secondary test, banded to the real
     catalog envelope (reference/booth-models.md): the smallest (4230)
     and largest (102186) booths and a caster-lifted 7272 are in; a
     light, a room, a desk, a shallow cabinet, a long partition, and a
     room-height shaft are out.
 25. floor_child? — the WR-Floor tag or an exact "floor" name, any case:
     the predicate room_info reads a room by and the sibling-ROOM
     keep-out skip keys on (the live "keep-out: ROOM 2" incident, where
     an L-shaped neighbour room's bounding box punched a hole in this
     room's grid).
 27. THE HIDDEN WALL (1.31.2, Benton: "the walls arent being made when I
     select them"): Hide walls per scene hides a wall by its entity flag
     and the geometry stays, so 1.28.0's scan judged every run of a
     "3-sided" room walled and borrowed nothing. run_report carries a
     hidden flag per face: a run with only a hidden face reads OPEN with
     hidden 1; the counts, the nearest-miss distance (an outer face 4"
     out) and the run length are what the console now prints per run.
 26. THE WALL SCAN (1.28.0, "add walls"): face_on_edge? / open_edges —
     which floor-polygon runs have no wall. On the 12x15 room with 96"
     walls: runs 0-2 walled (run 0 split at a door, run 1 with its OUTER
     face 4" out as well), run 3 carrying only a baseboard, a door leaf
     swung 90 degrees, and nothing else — run 3 alone is open; an inner
     face within the 1" tolerance closes it, one 2" off does not, a
     parallel on-plane face that does not OVERLAP the run (the far end of
     a long wall) does not, and a face overlapping by less than the
     tolerance does not. The L has six runs and all six must be walled
     for it to read closed; drop one and that run is named. The truth
     table pins each of the four tests individually — including the
     oblique partition off a run's corner, the one face only the parallel
     test rejects (a swung leaf is also thrown out by the on-plane test,
     so it alone would let that mutant live; it did, once).

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

MUTATION-CHECKED 2026-08-28 (the V-Ray light API rebuild, same protocol
— each mutation applied to wr-drop-lights.rb, this test run, FAIL
confirmed, mutation reverted): grid_count's snap clause deleted (the
overlapping row comes straight back, on the noisy axis only);
GRID_SNAP 0.0625 -> 0.0 (same); GRID_SNAP -> 100.0 (over-snapping: a
room that HAS earned its extra row loses it); grid_count's `n -= 1`
made `n -= 2`; kelvin_rgb green branch cut over AT 66 instead of below
it; scalar_intensity area factor dropped (every fixture emits the
reference power regardless of size); REF_INTENSITY 30 -> 60;
param_agrees? boolean/integer bridge removed (invisible = true reads
back as 1 and would be reported as a FAILED write on every single
light); param_agrees? float tolerance made exact; in_box? BOX_TOL
dropped to 0 (a light one snap proud of the ceiling plane stops being
found by the stale sweep, so a re-press doubles the grid). All ten
KILLED
and reverted. NOT coverable here: create_light, configure_light,
write_params, read_param, vray_api_missing, vray_context, collect_lights and
erase_lights are V-Ray/SketchUp-API-side and are unverified until a
live press — they are why every VRay:: call in that file is
individually rescued and why every write is read back.

MUTATION-CHECKED 2026-08-30 (1.9.9, the seven-role lumen rig — each
mutation applied to wr-drop-lights.rb, this test run, FAIL confirmed,
mutation reverted): TRIM_OPEN4 0.35 -> 1.00 (an open room stops being
trimmed); enclosure_trim's 3-wall and 4-wall arms swapped; shell_faces
4n -> 2n (the fixture face budget stops being real); area_scale's upper
clamp removed; its lower clamp removed; area_scale forgetting the
sq in -> sq ft conversion; the sconce's 300 lm per sphere -> 600 (the
fixture emits twice its product figure); layer_kelvin ignoring the
Warmth offset (Neutral stops shifting the palette); wall_normal flipped
(sconces mount facing OUT of the room); SCONCE_STANDOFF 3" -> 24"
(grazing becomes a wall wash). All ten KILLED. The upper-clamp mutation
SURVIVED on the first pass and the `as` check was added for it — which
is the only reason it is in this list.
NOT coverable here and unverified except by the live press recorded in
.forge/builder/rig-build-results.json: create_sphere, the F1/F2/F3
geometry builders (tube / cone_shell / disc_solid touch the SketchUp
Entities API), add_ceiling, remove_ceilings_verified!, model_probe,
stamp_exposure!, stamp_tag_into_pages and assert_lights_visible!.

MUTATION-CHECKED 2026-09-10 night (1.44.0, the booth interior role
removed, same protocol): the :booth row put back into LIGHT_LAYERS (`lt`
counts seven roles, eleven instances, a 1200 booth budget and names
nobooth0); :booth put back into BOOTH_ROLES (`br` names it). Both KILLED
and reverted. NOT coverable here: the two placement branches now
reporting instead of placing, and the stale sweep on a model that still
carries a pre-1.44.0 :booth light -- SketchUp-side, unverified until a
press on such a model.

MUTATION-CHECKED 2026-09-10 night (1.43.1, the walls default, same
protocol): WALLS_DEFAULT 'all' -> 'none' (the old default back; `wd`
names it); walls_mode(nil) falling to 'none' (an old preset drops the
control to "No" again). Both KILLED and reverted. NOT coverable here:
the dialog's JS fallback (DEFAULTS.walls) -- read it, not run.

MUTATION-CHECKED 2026-09-10 night (1.43.0, the key light backed out to
8', same protocol -- each applied to wr-drop-lights.rb, this test run,
FAIL confirmed, reverted): ACCENT_OUT 96 -> 42 (the field change
reverted; `ko96` names it); accent_tilt returning the old fixed 35
regardless of standoff (at 96" the beam hits the floor short of the
booth); accent_standoff's margin test dropped (a light body half in the
wall); its keep-out test dropped (a key inside a sibling booth); its
walk-back never stepping (one miss = no key, the old behaviour); its
floor `min` ignored (a key pulled in to 0" -- on the door face). All six
KILLED. NOT coverable here: the placement wiring and the rotation --
SketchUp-API-side, unverified until a press and a render.

MUTATION-CHECKED 2026-09-10 night (1.41.0, the ISO stamp removed and its
five stops moved onto the fixtures, same protocol -- each mutation
applied to wr-drop-lights.rb, this test run, FAIL confirmed, reverted):
CAMERA_GAIN 32 -> 1.0 (the stamp removed WITHOUT the rescale -- the
exact "dark exports" regression, every written figure five stops under);
CAMERA_GAIN -> 10.0 (a plausible-looking wrong factor: `lm` and `cg`
both name it); rig_camera_gain compensating on every ISO (a user's ISO
400 gets a quietly countered rig); rig_camera_gain never compensating
(a legacy-stamped model where the undo was declined gets a rig 32x hot);
camera_verdict's record test dropped (a 3200 Benton set himself is
offered an "undo" of a write this tool never made); ev_of forgetting
the ISO term (3200 reads EV 14.23 again -- loose end 4 reopened).
All six KILLED. NOT coverable here: read_exposure, undo_legacy_stamp!
(the one write left, read back by name), ask_undo_legacy_stamp and the
verdict's wiring into `run` -- SketchUp/V-Ray-API-side, unverified
until a press on a fresh model and on a model still carrying the stamp.

MUTATION-CHECKED 2026-09-10 evening (1.31.2 hidden-wall fix, same
protocol): run_report's hidden branch removed so a hidden face counts as
visible (reproduces the field report exactly — `oe-`, nothing open);
the near-miss window dropped (the console loses its "nearest face is X"
off" line). Both KILLED and reverted.

MUTATION-CHECKED 2026-09-10 (1.28.0 wall scan, same protocol — each
mutation applied to wr-drop-lights.rb, this test run, FAIL confirmed,
reverted): face_on_edge? parallel test dropped (SURVIVED on the first
pass — the swung-leaf case is also rejected by the on-plane test — and
the oblique-partition case was added for it; KILLED after); on-plane
tolerance dropped (the OUTER face 4" out closes a run); overlap test
forced true (the far end of a long wall closes the near run); z_need
dropped (a baseboard closes a side); open_edges none? -> any? (every
walled run reads open). All five KILLED. NOT coverable here:
existing_walls (the SketchUp face scan feeding these), add_walls,
find_owned / erase_owned! / find_walls, nested_lights, sweep_point, and
the `into` container the place lambda now takes — SketchUp-API-side,
unverified until a live press and a render.

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
           'accent_axis', 'subject_veto',
           'fallback_verdict', 'light_words?', 'room_structure_child?',
           'doors_container?', 'door_child_kind', 'tag', 'floor_child?',
           'booth_like?', 'grid_count', 'kelvin_rgb',
           'param_agrees?', 'in_box?', 'enclosure_trim', 'layer_lumens',
           'layer_kelvin', 'area_scale', 'ring_points', 'shell_faces', 'fixture_faces',
           'wall_points', 'sconce_points', 'wall_normal', 'far_corner',
           'ceiling_pair', 'face_on_edge?', 'open_edges', 'face_offset',
           'run_report', 'fill_runs', 'exposure_ratio', 'stops_of', 'ev_of',
           'camera_verdict', 'rig_camera_gain', 'accent_tilt',
           'accent_standoff', 'walls_mode', 'default_settings',
           'door_face_normal', 'accent_place', 'audit_verdict']
SCALARS = ['DROP', 'BOOTH_DROP', 'EDGE_MIN', 'EDGE_CAP', 'KEEPOUT_PAD',
           'HEADROOM', 'TARGET_FC', 'CU', 'WASH_STANDOFF',
           'WASH_SPACING', 'WASH_MAX', 'ACCENT_OUT', 'ACCENT_AIM_DROP', 'ACCENT_MIN',
           'ACCENT_STEP', 'ACCENT_MARGIN', 'ACCENT_FAN_STEP', 'ACCENT_FAN_MAX',
           'FACTORY_INTENSITY', 'MIN_ROOM_H',
           'MIN_ROOM_AREA', 'BOOTH_SIDE_MIN', 'BOOTH_SIDE_MAX',
           'BOOTH_H_MIN', 'BOOTH_H_MAX', 'GRID_SNAP', 'BOX_TOL',
           'UNITS_LUMENS', 'FACE_FLIP', 'TRIM_OPEN4', 'TRIM_OPEN3', 'SEG',
           'FIXTURE_FACES_MAX', 'REF_ROOM_SQFT', 'REF_BOOTH_SQFT',
           'AREA_SCALE_MIN', 'AREA_SCALE_MAX', 'PENDANT_AFF', 'SCONCE_AFF',
           'SCONCE_STANDOFF', 'RIM_OUT', 'RIM_TILT', 'FOAM_OFFSET',
           'EXPO_FACTORY_ISO', 'EXPO_LEGACY_ISO', 'EXPO_F', 'EXPO_SHUTTER',
           'WALL_TOL', 'WALL_MIN_SHARE',
           'WALL_NEAR', 'WALL_OUT',
           # 1.10.0 added LUMEN_GAIN to layer_lumens; this list was not
           # updated and the whole harness raised NameError on every commit
           # from then to 1.19.2. Anything layer_lumens multiplies by must be
           # lifted here, or the suite is red for a reason the log hides.
           'LUMEN_GAIN',
           # 1.41.0: the ISO stamp is gone and its five stops moved onto the
           # fixtures. Same rule as LUMEN_GAIN -- anything layer_lumens
           # multiplies by is lifted here.
           'CAMERA_GAIN']
STRINGS = ['TAG', 'WR_MODE_DICT', 'DICT', 'WALLS_DEFAULT']
BLOCKS = ['ROOM_CHILD_TAGS', 'ROOM_CHILD_NAMES', 'LIGHT_LAYERS', 'BOOTH_ROLES']


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
  # tag() records that IT created the WR Lights tag, so remove_rig! can take
  # the tag back and the removal's tag-list check can pass. The stub only has
  # to accept the write; what it records is not what this check is about.
  def set_attribute(_d, _k, _v); true; end
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
  # THE OVERLAPPING-ROW ROOM: 16' x 12', 8' ceiling. The long side is an
  # exact multiple of the Soft spacing (192 = 2 x 96) and arrives from
  # transformed geometry with float noise on it — which is precisely when
  # a bare ceil() squeezes a third row onto that ONE axis.
  NOISY = [[0.0, 0.0], [192.0000001, 0.0], [192.0000001, 144.0], [0.0, 144.0]]

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
    out << format('lm %d %d %d %d',
                  downlight_lumens(a, 4, 1.0), downlight_lumens(a, 12, 1.0),
                  downlight_lumens(a, 4, 2.0), downlight_lumens(a, 4, 0.5))

    out << format('thr %s %s %s', edge_threshold(48.0, 24.0, 22.5).round(2),
                  edge_threshold(96.0, 36.0, 45.0).round(2),
                  edge_threshold(96.0, 15.0, 15.0).round(2))

    out << 'axis35 ' + accent_axis(-1, 0).map { |v| v.round(2) }.join(',') +
           ' ' + accent_axis(0, -3).map { |v| v.round(2) }.join(',')

    # 9b -- THE KEY STANDOFF (1.43.0; Benton: "backed up like 8 ft"). The
    # shipped constants are pinned by VALUE -- 96" out, aiming 60" below
    # the mount plane, never closer than 42", 24"-panel margin -- and the
    # tilt is derived: 42/60 is exactly the old 35 deg, 96/60 is 58 deg,
    # degenerate inputs aim straight down / straight at the face.
    out << format('ko96 %.0f,%.0f,%.0f,%.0f,%.0f t%.1f,%.1f,%.1f,%.1f',
                  ACCENT_OUT, ACCENT_AIM_DROP, ACCENT_MIN, ACCENT_STEP, ACCENT_MARGIN,
                  accent_tilt(42.0, 60.0), accent_tilt(96.0, 60.0),
                  accent_tilt(0.0, 60.0), accent_tilt(96.0, 0.0))

    # 9c -- accent_standoff, the walk-back. The 12x15 room (144 x 180), a
    # booth against the far wall with its door facing -y, door centre at
    # (72, 96), door normal (0, -1): (a) 96" out lands at y=0 -- ON the
    # floor edge, inside the 12" margin, so it walks back to 84 (y=12,
    # exactly the margin); (b) a taller room (y to 300, door at y=200)
    # fits the full 96; (c) same room with a keep-out band across y
    # 100..118 in front of the door -- 96/90/84 out land inside it, 78
    # (y=122) is the first point clear -> 78; (d) a shallow room with only
    # 30" in front of the door: nil, the key is skipped rather than pulled
    # in past ACCENT_MIN; (e) 42" exactly available: 42.
    rect_tall = [[0.0, 0.0], [144.0, 0.0], [144.0, 300.0], [0.0, 300.0]]
    sa = accent_standoff([72.0, 96.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0)
    sb = accent_standoff([72.0, 200.0], 0.0, -1.0, rect_tall, [], 96.0, 42.0, 6.0, 12.0)
    sc = accent_standoff([72.0, 200.0], 0.0, -1.0, rect_tall,
                         [[0.0, 100.0, 144.0, 118.0]], 96.0, 42.0, 6.0, 12.0)
    sd = accent_standoff([72.0, 30.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0)
    se = accent_standoff([72.0, 54.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0)
    out << 'ks ' + [sa, sb, sc, sd, se].map { |v| v.nil? ? '-' : format('%.0f', v) }.join(',')

    # 9e -- door_face_normal (1.66.0): the door faces the booth-box side its
    # panel box lies against. (a) the live desktop model, 11 Sep 2026: door
    # panel x 349.5..381.5 on a booth x 349.5..469 -> west, [-1,0] (the old
    # centre-to-centre line gave [-0.77,0.64] and pulled the key in to 48");
    # (b) a panel flush with the +y end -> [0,1]; (c) a corner panel touching
    # two sides: 30" across x, 46" across y -> the thinner crossing wins,
    # west; (d) a zero-width booth box -> nil.
    dfa = door_face_normal([349.5, 331.9, 469.0, 466.8], [349.5, 412.3, 381.5, 458.3])
    dfb = door_face_normal([0.0, 0.0, 96.0, 160.0], [20.0, 140.0, 66.0, 160.0])
    dfc = door_face_normal([0.0, 0.0, 96.0, 144.0], [0.0, 0.0, 30.0, 46.0])
    dfd = door_face_normal([0.0, 0.0, 0.0, 144.0], [0.0, 0.0, 1.0, 1.0])
    out << 'dfn ' + [dfa, dfb, dfc, dfd].map { |v|
      v.nil? ? '-' : v.map { |x| format('%.0f', x) }.join(',')
    }.join(';')

    # 9f -- accent_place, the fan (1.66.0). (a) the perpendicular fits: 96 at
    # 0 deg; (b) door 40" from the wall it faces: nothing on the perpendicular
    # (42" lands 2" past the edge), +/-15..45 all land inside the 12" margin,
    # +60 deg (cos 60 = 0.5) walks back from 96 to 54 (y = 40 - 27 = 13) ->
    # 54 at +60; (c) 20" of room: even 60 deg cannot clear the margin -> nil,
    # KEY SKIPPED; (d) the 9c (a) case is unchanged at 84 / 0 deg.
    apa = accent_place([72.0, 200.0], 0.0, -1.0, rect_tall, [], 96.0, 42.0, 6.0, 12.0, 15.0, 60.0)
    apb = accent_place([72.0, 40.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0, 15.0, 60.0)
    apc = accent_place([72.0, 20.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0, 15.0, 60.0)
    apd = accent_place([72.0, 96.0], 0.0, -1.0, RECT, [], 96.0, 42.0, 6.0, 12.0, 15.0, 60.0)
    out << 'ap ' + [apa, apb, apc, apd].map { |v|
      v.nil? ? '-' : format('%.0f@%+.0f', v[0], v[3])
    }.join(';')

    # 9g -- audit_verdict (1.66.0): clean; a ghost; a rig light at the 30 lm
    # factory default (dead, and NOT also counted as wrong); a wrong value; a
    # missing plugin; a disabled light (dead).
    rows_ok = [['/R', 3200000.0, true, :rig, 3200000.0], ['/Standard Light', 2500.0, true, :model, nil]]
    va = audit_verdict(rows_ok, [])
    vb = audit_verdict(rows_ok + [['/R#9', 480000.0, true, :ghost, nil]], [])
    vc = audit_verdict([['/R', 30.0, true, :rig, 3200000.0]], [])
    vd = audit_verdict([['/R', 3000000.0, true, :rig, 3200000.0]], [])
    ve = audit_verdict(rows_ok, ['/R#3'])
    vf = audit_verdict([['/R', 3200000.0, false, :rig, 3200000.0]], [])
    out << 'av ' + [va, vb, vc, vd, ve, vf].map { |v|
      (v['ok'] ? 'ok' : 'BAD') + format('%d,%d,%d,%d', v['ghosts'].size, v['dead'].size, v['wrong'].size, v['missing'].size)
    }.join(';')

    # 9d -- THE WALLS DEFAULT. 1.43.1 made it 'all' ("default the drop down
    # to be 'on every run'"); 1.63.0 makes it 'hidden', because 'all' sealed
    # a room that was DRAWN 2-sided and walled the camera out (Benton, 11 Sep
    # 2026: "its making all 4 sides ... this does not need to be doing
    # this"). 1.64.2 makes it 'open': 'hidden' turned out to be INERT at the
    # only moment the tool runs -- a wall is hidden per SCENE and there are no
    # scenes yet on the fresh model Drop in the lights is pressed on, so
    # nothing ever qualified ("its not doing the walls with this setting").
    # 'open' keeps the half that mattered: a run with a VISIBLE wall is still
    # never doubled.
    # walls_mode: a missing key (a pre-1.28.0 preset) gets whatever
    # the default now is, the 1.28.0 checkbox true/false still means
    # open/none, explicit strings pass through, junk is No. The ceiling
    # default stays on.
    ds = default_settings
    out << 'wd ' + [ds['walls'], ds['ceiling'] ? 'cap' : 'open',
                    walls_mode(nil), walls_mode(true), walls_mode(false),
                    walls_mode('open'), walls_mode('all'), walls_mode('none'),
                    walls_mode('junk')].join(',')

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

    # 20 — grid_count: THE OVERLAPPING-ROW FIX. In order: an exact
    # multiple stays 2 rows; the SAME length with 1e-7" of float noise on
    # it must STILL be 2 (a bare ceil answers 3 — that is the bug);
    # likewise 3 rows at the Showroom spacing; a genuinely short room
    # keeps 2; a room 4" longer than one spacing still earns its second
    # row (the sourced ceil rule from interior-lighting-design.md §1.2 is
    # preserved, only its float hazard is removed); one spacing exactly is
    # one row; a tiny room is one row; 2.5 spacings is 3.
    out << 'gc ' + [grid_count(192.0, 96.0), grid_count(192.0000001, 96.0),
                    grid_count(144.0000001, 48.0), grid_count(191.9, 96.0),
                    grid_count(100.0, 96.0), grid_count(96.0, 96.0),
                    grid_count(30.0, 96.0), grid_count(240.0, 96.0),
                    grid_count(96.0, 0.0)].join(',')

    # 20b — the same fix seen as a whole grid: 2 x 2 = FOUR lights in the
    # noisy 16' x 12' room, never the six a bare ceil produces.
    g = grid_points(NOISY, 96.0, :soft, [])
    out << format('noisy %s fb%d', pts_s(g[:pts]), g[:fallback] ? 1 : 0)

    # 21 — kelvin_rgb: white at 6600 K by construction, the two shipped
    # answers, and both clamp ends.
    out << 'kr ' + [3000, 3500, 6600, 10000, 1000]
                   .map { |k| kelvin_rgb(k).map { |v| format('%.3f', v) }.join(',') }
                   .join(' ')

    # 21b — THE LUMEN COLUMN, 1.9.9. There is no scalar anchor and no area
    # correction any more: in Luminous Power mode intensity IS the output.
    # Brightness multiplies, the enclosure trim multiplies room roles only,
    # and the booth roles never trim.
    #
    # Since 1.10.0 every figure is ALSO multiplied by LUMEN_GAIN (10.0, the
    # eyeballed calibration in wr-drop-lights.rb). The expectation below is
    # pinned at what the tool actually WRITES to V-Ray -- 2000 lm of product
    # spec goes out as 20000 -- rather than dividing the gain back out, so
    # a change to the calibration shows up here by name instead of hiding
    # behind a tidy product number.
    out << 'lm ' + [layer_lumens(2000.0, 1.0, 1.0),
                    layer_lumens(2000.0, 2.0, 1.0),
                    layer_lumens(2000.0, 0.5, 1.0),
                    layer_lumens(2000.0, 1.0, enclosure_trim(false, 4)),
                    layer_lumens(2000.0, 1.0, enclosure_trim(false, 3)),
                    layer_lumens(800.0, 1.0, enclosure_trim(true, 4))]
                   .map { |v| format('%.0f', v) }.join(',')

    # 21b2 — area_scale: the lumen table is quoted for a 192 sq ft room, and
    # a real room is not that room. Both clamps must bite — without the upper
    # one a big hall multiplies the rig without limit.
    out << 'as ' + [area_scale(192.0 * 144.0, REF_ROOM_SQFT),
                    area_scale(320.0 * 144.0, REF_ROOM_SQFT),
                    area_scale(24.0 * 144.0, REF_ROOM_SQFT),
                    area_scale(4000.0 * 144.0, REF_ROOM_SQFT),
                    area_scale(30.0 * 144.0, REF_BOOTH_SQFT),
                    area_scale(0.0, REF_ROOM_SQFT)]
                   .map { |v| format('%.3f', v) }.join(',')

    # 21c — THE SIX-ROLE LAYER TABLE (seven until 1.44.0: the 800 lm booth
    # interior light is GONE — every WhisperRoom carries BoothLighting.skp
    # already, and the rig's copy "always misses"). Its budgets must total
    # the design figures, EXACTLY FIVE fixtures must be visible, and the rig
    # must carry at least five distinct Kelvins — a single-hue rig is the
    # fault this whole rewrite exists to fix, so it fails outright here.
    # :booth must be absent from BOTH the table and BOOTH_ROLES, and the
    # booth budget is the foam graze alone.
    roles = [:ceiling, :key, :pendant, :sconce, :rim, :foam]
    tot = lambda { |b| roles.select { |r| LIGHT_LAYERS[r][:budget] == b }
                            .inject(0.0) { |a, r| a + LIGHT_LAYERS[r][:lumens] *
                                                  LIGHT_LAYERS[r][:n] *
                                                  LIGHT_LAYERS[r][:emitters] } }
    kelvins = roles.map { |r| LIGHT_LAYERS[r][:kelvin] }.uniq
    out << format('lt roles%d inst%d visroles%d visfix%d k%d room%.0f booth%.0f units%.0f',
                  roles.size,
                  roles.inject(0) { |a, r| a + LIGHT_LAYERS[r][:n] * LIGHT_LAYERS[r][:emitters] },
                  roles.count { |r| LIGHT_LAYERS[r][:visible] },
                  roles.select { |r| LIGHT_LAYERS[r][:visible] }
                       .inject(0) { |a, r| a + LIGHT_LAYERS[r][:n] },
                  kelvins.size, tot.call(:room), tot.call(:booth), UNITS_LUMENS) +
           format(' nobooth%d br%s', LIGHT_LAYERS.key?(:booth) ? 0 : 1,
                  BOOTH_ROLES.map(&:to_s).join('+'))

    # 21d — the Kelvin offset SHIFTS the palette and never flattens it.
    out << 'ko ' + roles.map { |r| layer_kelvin(LIGHT_LAYERS[r][:kelvin], 500) }
                        .join(',')

    # 21e — the fixture geometry maths, outside SketchUp: a ring closes, a
    # shell costs 4n faces, and the five fixtures of a full rig stay inside
    # the face budget at the shipped segment count.
    rp = ring_points(0.0, 0.0, 9.0, 4)
    out << format('fx %s shell%d faces%d budget%d',
                  rp.map { |p| format('%.1f/%.1f', p[0], p[1]) }.join(' '),
                  shell_faces(SEG), fixture_faces(2, 1, 2, SEG),
                  fixture_faces(2, 1, 2, SEG) <= FIXTURE_FACES_MAX ? 1 : 0)

    # 21f — the sconce row: 3" off the wall, two of them, and the inward
    # wall normal that the backplate is pushed along.
    sp = sconce_points(RECT, 0, [])
    nn = wall_normal(RECT, 0)
    out << format('sc %s n%.0f,%.0f', pts_s(sp), nn[0], nn[1])

    # 21g — the pendant corner and the ceiling pair, both booth-relative.
    fc = far_corner(RECT, 10.0, 10.0, 36.0)
    cp = ceiling_pair([[48.0, 45.0], [48.0, 135.0], [96.0, 45.0], [96.0, 135.0]],
                      10.0, 10.0)
    out << format('pp %.1f,%.1f %s', fc[0], fc[1], pts_s(cp))

    # 22 — param_agrees?, the read-back comparator. An integer flag and a
    # boolean are the same answer; floats compare with tolerance; a
    # colour-like object compares component-wise; a real mismatch is a
    # mismatch.
    out << 'pa ' + [param_agrees?(true, 1), param_agrees?(true, 1.0),
                    param_agrees?(false, 0), param_agrees?(true, 0),
                    param_agrees?(30.0, 30), param_agrees?(30.0, 30.000001),
                    param_agrees?(30.0, 31.0), param_agrees?(0.0, 0.0),
                    param_agrees?([1.0, 0.695, 0.431], [1.0, 0.695, 0.431]),
                    param_agrees?([1.0, 0.695, 0.431], [1.0, 0.695, 0.9]),
                    param_agrees?('x', 'x'), param_agrees?('x', 'y')]
                   .map { |b| b ? '1' : '0' }.join

    # 23 — in_box?: a FLUSH-mounted light's origin lies exactly on the
    # room's top face. Inside, exactly on the face, one snap above it, and
    # the far bottom corner are all IN; an inch above the ceiling and an
    # inch outside a wall are both OUT. Line 2 is the one that matters:
    # without BOX_TOL it reads as OUT and every re-press doubles the grid.
    box = [0.0, 0.0, 0.0, 120.0, 120.0, 96.0]
    out << 'ib ' + [in_box?(60.0, 60.0, 48.0, box),
                    in_box?(60.0, 60.0, 96.0, box),
                    in_box?(60.0, 60.0, 96.0625, box), # a literal 1/16",
                    # NOT BOX_TOL: a test that reads the constant it is
                    # pinning moves with it and pins nothing.
                    in_box?(0.0, 0.0, 0.0, box),
                    in_box?(60.0, 60.0, 97.0, box),
                    in_box?(-1.0, 60.0, 48.0, box)]
                   .map { |b| b ? '1' : '0' }.join

    # 24 — booth_like? against real catalog envelopes
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

    # 25 — floor_child?: the WR-Floor tag or an exact "floor" name (any
    # case) — the predicate room_info reads a room by and the sibling-ROOM
    # keep-out skip keys on (the "keep-out: ROOM 2" incident).
    out << 'fc ' + [floor_child?('WR-Floor', 'anything'),
                    floor_child?('Layer0', 'floor'),
                    floor_child?('Layer0', 'Floor'),
                    floor_child?('Layer0', 'floorboard'),
                    floor_child?('WR-Booth-Deck', 'panel')]
                   .map { |b| b ? '1' : '0' }.join

    # 26 — THE WALL SCAN. Faces are [nx, ny, pts_xy, z_top]; z_need is
    # halfway up a 96" room (WALL_MIN_SHARE 0.5 -> 48").
    zn = 96.0 * WALL_MIN_SHARE
    good = [0.0, 1.0, [[0.0, 0.0], [144.0, 0.0]], 96.0]
    out << 'foe ' + [face_on_edge?(0.0, 0.0, 144.0, 0.0, good, WALL_TOL, zn),
                     # (1) perpendicular — an open door leaf
                     face_on_edge?(0.0, 0.0, 144.0, 0.0,
                                   [1.0, 0.0, [[36.0, 0.0], [36.0, 36.0]], 80.0], WALL_TOL, zn),
                     # (2) parallel but the OUTER face, 4" off the run
                     face_on_edge?(0.0, 0.0, 144.0, 0.0,
                                   [0.0, 1.0, [[0.0, -4.0], [144.0, -4.0]], 96.0], WALL_TOL, zn),
                     # (3) on-plane, parallel, but past the end of the run
                     face_on_edge?(0.0, 0.0, 144.0, 0.0,
                                   [0.0, 1.0, [[200.0, 0.0], [300.0, 0.0]], 96.0], WALL_TOL, zn),
                     # (4) a baseboard
                     face_on_edge?(0.0, 0.0, 144.0, 0.0,
                                   [0.0, 1.0, [[0.0, 0.0], [144.0, 0.0]], 4.0], WALL_TOL, zn),
                     # (1) again, the case ONLY the parallel test catches: a
                     # 45-degree partition starting at the run's own corner
                     # is on-plane at that corner and overlaps the run in
                     # projection — the leaf above is also thrown out by (2).
                     face_on_edge?(0.0, 0.0, 144.0, 0.0,
                                   [0.7071, -0.7071, [[0.0, 0.0], [50.0, 50.0]], 96.0], WALL_TOL, zn)]
                    .map { |b| b ? '1' : '0' }.join
    a3 = [[0.0, 1.0, [[0.0, 0.0], [54.0, 0.0]], 96.0],          # run 0, left of the door
          [0.0, 1.0, [[90.0, 0.0], [144.0, 0.0]], 96.0],        # run 0, right of the door
          [-1.0, 0.0, [[144.0, 0.0], [144.0, 180.0]], 96.0],    # run 1 inner
          [1.0, 0.0, [[148.0, 0.0], [148.0, 180.0]], 96.0],     # run 1 OUTER face
          [0.0, -1.0, [[0.0, 180.0], [144.0, 180.0]], 96.0],    # run 2
          [1.0, 0.0, [[0.0, 0.0], [0.0, 180.0]], 4.0],          # run 3: baseboard only
          [0.0, 1.0, [[0.0, 60.0], [36.0, 60.0]], 80.0],        # run 3: leaf swung open
          [0.7071, 0.7071, [[0.0, 180.0], [50.0, 130.0]], 96.0]] # run 3: oblique partition off its corner
    oe = lambda { |poly, faces| r = open_edges(poly, faces, WALL_TOL, zn); r.empty? ? '-' : r.join(',') }
    lall = [[0.0, 1.0, [[0.0, 0.0], [144.0, 0.0]], 96.0],
            [1.0, 0.0, [[144.0, 0.0], [144.0, 180.0]], 96.0],
            [0.0, 1.0, [[72.0, 180.0], [144.0, 180.0]], 96.0],
            [1.0, 0.0, [[72.0, 108.0], [72.0, 180.0]], 96.0],
            [0.0, 1.0, [[0.0, 108.0], [72.0, 108.0]], 96.0],
            [1.0, 0.0, [[0.0, 0.0], [0.0, 108.0]], 96.0]]
    out << 'oe ' + [oe.call(RECT, a3),
                    oe.call(RECT, a3 + [[1.0, 0.0, [[0.5, 0.0], [0.5, 180.0]], 96.0]]),
                    oe.call(RECT, a3 + [[1.0, 0.0, [[2.0, 0.0], [2.0, 180.0]], 96.0]]),
                    oe.call(RECT, a3[2..4] + [[1.0, 0.0, [[0.0, 0.0], [0.0, 180.0]], 96.0],
                                              [0.0, 1.0, [[200.0, 0.0], [300.0, 0.0]], 96.0]]),
                    oe.call(RECT, a3 + [[1.0, 0.0, [[0.0, 179.6], [0.0, 300.0]], 96.0]]),
                    oe.call(LPOLY, lall),
                    oe.call(LPOLY, lall[0..3] + lall[5..5])].join(' ')

    # 27 — THE HIDDEN WALL (1.31.2, "the walls arent being made"). The same
    # rectangle with all four inner faces present, run 3's HIDDEN: run 3
    # must read open with hidden 1, and run_report must carry the
    # measurements the console prints — visible/hidden counts, the
    # nearest-miss distance (run 1's outer face at 4" when its inner face
    # is hidden too), and the run length.
    hidden3 = a3[0..4] + [[1.0, 0.0, [[0.0, 0.0], [0.0, 180.0]], 96.0, true]]
    rr = run_report(RECT, hidden3, WALL_TOL, zn)
    out << 'rr ' + rr.map { |r| format('%s%d/%d/%s/%.0f', r[:walled] ? 'W' : 'O',
                                       r[:faces], r[:hidden],
                                       r[:near] ? format('%.1f', r[:near]) : '-',
                                       r[:len]) }.join(' ') +
           ' oe' + oe.call(RECT, hidden3)
    both = [a3[0], a3[1], a3[2][0..3] + [true], a3[3], a3[4]]
    rr2 = run_report(RECT, both, WALL_TOL, zn)
    out << 'rr2 ' + rr2.map { |r| format('%s%d/%d/%s', r[:walled] ? 'W' : 'O',
                                         r[:faces], r[:hidden],
                                         r[:near] ? format('%.1f', r[:near]) : '-') }.join(' ')

    # 27b -- WHICH RUNS GET A BORROWED FACE (1.63.0). `rr2` above is the
    # ideal fixture: run 1 has a visible wall, run 2's only face is HIDDEN,
    # run 3 has a visible wall, run 4 has no face at all. Benton's 2-sided
    # room is run 4 repeated, and the old default filled it. The new
    # default 'hidden' must pick run 2 ALONE -- put back the seal the scene
    # took away, never double a visible wall, never close a side that was
    # drawn open. 'open' still takes 2 and 4, 'all' still takes everything,
    # 'none' nothing; and a scan that FAILED (wrep nil) must borrow nothing
    # on every mode but 'all', which needs no scan.
    fr = lambda { |m, w| (fill_runs(m, 4, w).map { |i| i + 1 }.join(',')) }
    out << 'fr ' + [fr.call('hidden', rr2), fr.call('open', rr2),
                    fr.call('all', rr2), fr.call('none', rr2),
                    fr.call('hidden', nil), fr.call('open', nil),
                    fr.call('all', nil)].map { |v| v.empty? ? '-' : v }.join(' ')

    # 28 -- THE CAMERA, READ NOT WRITTEN (1.41.0; the 1.32.0 retune window
    # and its retune_rows are gone). exposure_ratio / stops_of stay for the
    # console's "N stops hot/dark" line: 100 -> 3200 is 1/32 = five stops;
    # the factory camera (100 -> 100) is NO ratio (nil), as are nil / zero /
    # negative readings.
    er = lambda { |a, b| v = exposure_ratio(a, b); v.nil? ? '-' : format('%.5g', v) }
    out << 'er ' + [er.call(100.0, 3200.0), er.call(100.0, 100.0), er.call(100, 3200),
                    er.call(nil, 3200.0), er.call(100.0, 0.0), er.call(-1, 5),
                    er.call(100.0, 800.0)].join(',') +
           format(' st%.1f,%.1f,%s', stops_of(1.0 / 32), stops_of(0.125),
                  stops_of(nil).nil? && stops_of(0.0).nil? ? '-' : 'BAD')

    # 28b -- ev_of, ISO counted: the factory camera f/8 @ 1/300 @ 100 is
    # EV 14.23 (observed, DEVLOG); the retired stamp's 3200 is 9.23, five
    # stops under; ISO 800 is three stops; nil on any missing or zero reading.
    ev = lambda { |f, sh, i| v = ev_of(f, sh, i); v.nil? ? '-' : format('%.2f', v) }
    out << 'ev ' + [ev.call(8.0, 300.0, 100.0), ev.call(8.0, 300.0, 3200.0),
                    ev.call(8, 300, 800), ev.call(nil, 300.0, 100.0),
                    ev.call(8.0, 0.0, 100.0), ev.call(8.0, 300.0, nil)].join(',')

    # 28c -- camera_verdict, the five cases. Factory ISO with no record is
    # the normal press; factory WITH a record is a hand-undone stamp
    # (stale); 3200 WITH a record is this tool's own legacy stamp (the
    # only case that earns the undo question); 3200 WITHOUT a record is
    # Benton's (user); anything else is his; an unreadable ISO is named.
    # Integer readings agree with the float constants (param_agrees?).
    out << 'cv ' + [camera_verdict(100.0, nil), camera_verdict(100.0, 'ISO 3200, 2026-09-10'),
                    camera_verdict(3200.0, 'ISO 3200, 2026-09-10'), camera_verdict(3200.0, nil),
                    camera_verdict(3200, 'x'), camera_verdict(400.0, nil),
                    camera_verdict(400.0, 'x'), camera_verdict(nil, 'x'),
                    camera_verdict(0.0, nil), camera_verdict('100', nil)].join(',')

    # 28d -- rig_camera_gain. THE FACTOR: a fresh model at the factory ISO
    # gets CAMERA_GAIN = 32 (five stops, 3200/100 = 2^5); a legacy-stamped
    # model where the undo was declined is compensated to exactly 1.0, so
    # that model's rig is the rig it always had; compensation is never
    # applied to a user ISO (400 -> still 32), and a bad ISO cannot break it.
    out << 'cg ' + [rig_camera_gain(100.0, false), rig_camera_gain(3200.0, true),
                    rig_camera_gain(400.0, false), rig_camera_gain(400.0, true),
                    rig_camera_gain(nil, true), rig_camera_gain(0.0, true)]
                   .map { |v| format('%.4g', v) }.join(',')

    # 28e -- layer_lumens with the camera factor threaded: the 3-argument
    # call (every caller before 1.41.0) is the factory-camera figure; the
    # compensated call reproduces the pre-1.41.0 written value exactly.
    out << 'lc ' + [layer_lumens(2000.0, 1.0, 1.0),
                    layer_lumens(2000.0, 1.0, 1.0, rig_camera_gain(3200.0, true)),
                    layer_lumens(800.0, 1.0, 1.0, 32.0)]
                   .map { |v| format('%.0f', v) }.join(',')

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
    # THE WALL WASH, RE-SPACED (1.64.0). Benton's 11 Sep 2026 set came
    # back with the washed wall in discrete pools and dark gaps. Spacing
    # went 1.5 -> 1.0 x standoff and the per-wall cap 4 -> 6, so a 12 ft
    # run now carries SIX fixtures 24 in apart instead of four at 36 --
    # the pools overlap. The lumens are unchanged and divide across the
    # larger count, so this is a distribution change, not a brighter rig.
    'washR 132.0,156.0;108.0,156.0;84.0,156.0;60.0,156.0;36.0,156.0;12.0,156.0',
    'washL 132.0,156.0;108.0,156.0;84.0,156.0',
    'washK 108.0,156.0;84.0,156.0;60.0,156.0;36.0,156.0;12.0,156.0',
    'lm 3000 1000 6000 1500',
    'thr 22.5 36.0 18.0',
    'axis35 0.0,1.0 -1.0,0.0',
    'ko96 96,60,42,6,12 t35.0,58.0,0.0,90.0',
    # (a) 84: y=12 is the first point 12" clear of the near edge. (b) 96.
    # (c) keep-out spans y 100..118; 96 -> y=104 inside, 90 -> 110 inside,
    # 84 -> 116 inside, 78 -> 122 clear -> 78. (d) 30" of room: 42 lands at
    # y=-12, outside -> nil. (e) door at y=54: 42 -> y=12, on the margin -> 42.
    'ks 84,96,78,-,42',
    'dfn -1,0;0,1;-1,0;-',
    'ap 96@+0;54@+60;-;84@+0',
    'av ok0,0,0,0;BAD1,0,0,0;BAD0,1,0,0;BAD0,0,1,0;BAD0,0,0,1;BAD0,1,0,0',
    'wd open,cap,open,open,none,open,all,none,none',
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
    'gc 2,2,3,2,2,1,1,3,1',
    'noisy 48.0,36.0;48.0,108.0;144.0,36.0;144.0,108.0 fb0',
    'kr 1.000,0.695,0.431 1.000,0.755,0.552 1.000,1.000,1.000 '
    '0.791,0.855,1.000 1.000,0.266,0.000',
    # 21b: LUMEN_GAIN x CAMERA_GAIN = x320 on (2000, 2000x2, 2000x0.5,
    # 2000x0.35, 2000x0.25, 800 untrimmed) -- the values WRITTEN to V-Ray,
    # not the product table. 1.41.0: the five stops the retired ISO stamp
    # supplied at the camera now ride on the fixtures. 2000 lm of product
    # spec leaves as 640,000.
    'lm 640000,1280000,320000,224000,160000,256000',
    # AREA_SCALE_MAX 3.0 -> 6.0 (1.65.0): the cap that was meant to stop a
    # HALL getting a stadium's worth was capping a 1600 sq ft SHOWROOM at
    # the light for 576 sq ft. The 4th value is the over-cap case and it
    # is the only one that moves; the floor (0.5) is untouched.
    'as 1.000,1.667,0.500,5.000,1.250,1.000',
    'lt roles6 inst10 visroles3 visfix5 k6 room10800 booth400 units1 nobooth1 brkey+rim+foam',
    # THE TWO FILL LAYERS WENT NEUTRAL (1.64.0). Ceiling ambient
    # 3500 -> 4200 K and the key 3200 -> 3600 K. The 11 Sep 2026 set
    # measured a mean of R112/G78/B65 -- red nearly double blue -- so a
    # white ceiling rendered orange and the room read as orange rather
    # than warmly lit. The pendant (2700) and sconces (3000) are NOT
    # touched: they are the accents, and the warmth is meant to live
    # there. These figures carry the +500 offset the check applies.
    'ko 4700,4100,3200,3500,5500,4000',
    'fx 9.0/0.0 0.0/9.0 -9.0/0.0 -0.0/-9.0 shell64 faces394 budget1',
    'sc 36.0,3.0;108.0,3.0 n0,1',
    'pp 121.5,151.9 96.0,135.0;48.0,135.0',
    'pa 111011011010',
    'ib 111100',
    'bl 111000000',
    'fc 11100',
    'foe 100000',
    'oe 3 - 3 0 3 - 4',
    'rr W2/0/-/144 W1/0/4.0/180 W1/0/-/144 O0/1/-/180 oe3',
    'rr2 W2/0/- O0/1/4.0 W1/0/- O0/0/-',
    'fr 2 2,4 1,2,3,4 - - - 1,2,3,4',
    'er 0.03125,-,0.03125,-,-,-,0.125 st5.0,3.0,-',
    'ev 14.23,9.23,11.23,-,-,-',
    'cv factory,stale_record,legacy_stamped,user_iso,legacy_stamped,user_iso,'
    'user_iso,unreadable,unreadable,unreadable',
    'cg 32,1,32,32,32,32',
    'lc 640000,20000,256000',
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

# 1.20.0 -- snapshot reads the LIVE annotation family (a set made by
# wr-scene-annotations.rb is an annotation tag like any other), so the lift
# needs the family's owner. It answers with the same two fixture tags, which
# keeps every check below comparing against exactly what it did before.
module WR_ProposalScenes
  def self.annot_tags(_model)
    WR_Mode::ANNOT_TAGS
  end
end

module WR_Mode
  # One dimension tag and one note tag, so the transcript stays short but
  # ANNOT_TAGS is the real two-family list wr-mode.rb manages from 1.9.3 -- the
  # tag that carries build-room.rb's ceiling banner has the same polarity as a
  # dimension and must be in every snapshot.
  DIM_TAGS   = ['WR-Dims'].freeze
  NOTE_TAGS  = ['WR-Notes'].freeze
  ANNOT_TAGS = (DIM_TAGS + NOTE_TAGS).freeze
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
