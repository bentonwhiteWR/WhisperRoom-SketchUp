# -*- coding: utf-8 -*-
"""SEE the roof unit land — build a roof-mounted booth and photograph it.

    python seat-shot.py <out-dir>

WHY A PICTURE AND NOT ONLY AN ASSERTION
---------------------------------------
scripts/rbtest-roofvent.py proves the arithmetic: on the four 84-in-wide models
the whole 3.25 in of slack goes on the LEFT and the part sits flush RIGHT. But
"right" is a claim about orientation, and a mirrored orientation passes every
numeric check ever written while putting the unit on the wrong side of four
booth models. CLAUDE.md warns about exactly this class of error — a draft once
told a client their work surface was on the wrong wall.

So this builds the booth for real and takes two photographs of it:

    top    looking straight down, +y up the image and +x to the RIGHT of it,
           with the DOOR (the S wall) at the bottom of the frame. The door is
           the orientation reference: the wall the portal calls "Front".
    front  a true (parallel-projection) elevation from in front of the booth
           looking at it, which is the viewpoint the words "left" and "right"
           are spoken from.

WHAT TO LOOK FOR
    8484 flat / 8484 VSS  — the roof unit's gap is on the LEFT of the frame and
                            its right edge is flush with the booth. If the gap
                            is on the right, the convention is mirrored.
    7272                  — the contrast case: gaps on BOTH sides, equal.
    8484 HX               — front elevation only. The same part, sitting on a
                            roof 10 in higher, with no +10 anywhere in the code
                            (wr-overlays measures the roof it built).

WHAT THE PICTURES SHOWED, 31 Aug 2026 (observed; measured off the PNGs, not
eyeballed - a front elevation separates the roof unit from the booth by row, so
the two extents can be read on their own scanlines):

    8484 flat   booth exterior x 274..1325 px = 86.0 in, so 12.22 px/in
                nominal footprint  286..1313 px = 84.0 in
                RM8484 roof unit   326..1313 px = 80.75 in
                -> gap LEFT 40 px = 3.27 in, gap RIGHT 0 px = 0.00 in
    8484 VSS    -> gap LEFT 30 px = 3.27 in, gap RIGHT 0 px = 0.00 in
    8484 HX     -> gap LEFT 27 px = 3.26 in, gap RIGHT 0 px = 0.00 in,
                   and the unit sits on a roof at z 92.00 instead of 82.00
    7272        -> gap LEFT 40 px, gap RIGHT 40 px, both 3.27 in. Centred.

The door (S0, hand R) is on the LEFT of every front elevation and at the BOTTOM
of every top view, which is the orientation reference: the front elevation looks
along +y with +x to the image's right, so image-right IS the booth's right, and
that is the side the unit is flush to.

MODEL SAFETY, the same fence as live-rm-report.py and repro-rm-cbl.py: the
active-model check lives INSIDE the Ruby job (a Python pre-flight is stale by
the time the job runs — demonstrated 31 Aug 2026), it refuses BY NAME on a
saved model, and build / photograph / erase all happen in ONE bridge job so a
window switch cannot leave geometry in one of Benton's files.
"""
import base64
import json
import os
import sys
from importlib import import_module

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))

PARTS_DIR = 'P:/Sketchup/NewMasterComponentList'

# MDL 8484 S, roof mounted. All four walls are 40 in panels; the three vent
# slots (N0, N1, E0) arrive as CABLE walls, which is what applyRoofVent leaves
# in the link. The door is on S0 — the FRONT wall — and is the orientation
# reference in every shot.
BOOTHS = {
    '8484': {
        'm': 'MDL 8484', 'v': 'S', 'rv': 1,
        'a': {'N0': 'STDWL40 CBL', 'N1': 'STDWL40 CBL',
              'S0': 'STDWL40 DRFRM R', 'S1': 'STDWL40',
              'E0': 'STDWL40 CBL', 'E1': 'STDWL40',
              'W0': 'STDWL40', 'W1': 'STDWL40'},
    },
    '7272': {
        'm': 'MDL 7272', 'v': 'S', 'rv': 1,
        'a': {'N0': 'STDWL46 CBL', 'N1': 'STDWL22',
              'S0': 'STDWL46 DRFRM R', 'S1': 'STDWL22',
              'E0': 'STDWL46 CBL', 'E1': 'STDWL22',
              'W0': 'STDWL46', 'W1': 'STDWL22'},
    },
}

GUARD = (
    "_m = Sketchup.active_model\n"
    "if !_m.path.to_s.strip.empty?\n"
    "  raise \"refusing to build: the active model is a SAVED file - \" \\\n"
    "        \"title #{_m.title.inspect}, path #{_m.path.inspect}. This check \" \\\n"
    "        \"builds and erases geometry and runs only against an Untitled \" \\\n"
    "        \"scratch model. Open a new model and re-run; do not switch \" \\\n"
    "        \"models on anyone's behalf while they are working.\"\n"
    "end\n")

# Cameras are set explicitly rather than through Sketchup.send_action, which is
# asynchronous and would photograph whatever the view happened to be showing.
# Parallel projection on both, so a flush edge reads as flush.
JOB = r"""
_path = File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'booth-from-link.rb')
_src  = File.read(_path)
_src  = _src.sub(/\nbegin\n\s*WR_BoothLink\.run\b.*\z/m, "\n")
eval(_src, TOPLEVEL_BINDING, _path)

_m = Sketchup.active_model
_before = _m.entities.map(&:entityID)
_payload = WR_BoothLink.hash_payload(%(LINK)s)
raise 'the link did not decode' if _payload.nil?
_err = nil
begin
  WR_BoothLink.build_from_payload(_payload, 'dir' => %(DIR)s, 'dry' => false)
rescue Exception => e
  _err = "#{e.class}: #{e.message}\n" + e.backtrace.first(6).join("\n")
end
_new = _m.entities.reject { |e| _before.include?(e.entityID) }
_ids = _new.map(&:entityID)

# What actually landed, measured out of the model rather than predicted.
_booth = _new.grep(Sketchup::Group).find { |g| g.name.to_s.include?('(components)') }
_facts = {}
if _booth
  _bb = _booth.bounds
  _facts['booth'] = [_bb.min.x.to_f, _bb.min.y.to_f, _bb.min.z.to_f,
                     _bb.max.x.to_f, _bb.max.y.to_f, _bb.max.z.to_f]
  _unit = _booth.entities.grep(Sketchup::ComponentInstance)
                .find { |i| i.name.to_s.include?('roof unit') }
  if _unit
    _ub = _unit.bounds
    _facts['unit_name'] = _unit.name.to_s
    _facts['unit'] = [_ub.min.x.to_f, _ub.min.y.to_f, _ub.min.z.to_f,
                      _ub.max.x.to_f, _ub.max.y.to_f, _ub.max.z.to_f]
    # Gaps to the booth's NOMINAL footprint, which is 1 in inboard of the
    # exterior on every side. The booth is built in booth-local coordinates
    # spanning 0..w by 0..h (wr-booth-data.rb's polygons), so the exterior is
    # taken from the known w/h rather than from _booth.bounds: an open door
    # leaf reaches OUTSIDE the footprint and would poison the read-back.
    # LEFT is low x, RIGHT is high x - see wr-roof-vent.rb's header for why.
    _facts['gap_left']  = _ub.min.x.to_f - 1.0
    _facts['gap_right'] = (%(EXTW)s - 1.0) - _ub.max.x.to_f
    _facts['gap_front'] = _ub.min.y.to_f - 1.0
    _facts['gap_back']  = (%(EXTH)s - 1.0) - _ub.max.y.to_f
    _facts['sits_on_roof'] = _ub.min.z.to_f
    _facts['booth_roof']   = _bb.max.z.to_f - (_ub.max.z.to_f - _ub.min.z.to_f)
  end
end

_shots = []
if _booth
  _bb = _booth.bounds
  _cx = (_bb.min.x.to_f + _bb.max.x.to_f) / 2.0
  _cy = (_bb.min.y.to_f + _bb.max.y.to_f) / 2.0
  _cz = (_bb.min.z.to_f + _bb.max.z.to_f) / 2.0
  _v  = _m.active_view
  %(SHOTS)s
end

_m.start_operation('seat-shot cleanup', true)
_new.each { |e| e.erase! if e.valid? }
_m.commit_operation
_left = _ids.select { |i| _m.entities.any? { |e| e.entityID == i } }
{'error' => _err, 'created' => _ids.length, 'not_erased' => _left,
 'model_path' => _m.path.to_s, 'facts' => _facts, 'shots' => _shots}
"""

TOP = """  _cam = Sketchup::Camera.new(Geom::Point3d.new(_cx, _cy, _cz + 600),
                              Geom::Point3d.new(_cx, _cy, _cz),
                              Geom::Vector3d.new(0, 1, 0))
  _cam.perspective = false
  _v.camera = _cam
  _v.zoom(_booth)
  _v.zoom(0.75)   # back off so the booth edge is inside the frame
  _v.write_image(:filename => %s, :width => 1600, :height => 1600,
                 :antialias => true, :transparent => false)
  _shots << %s
"""

FRONT = """  _cam = Sketchup::Camera.new(Geom::Point3d.new(_cx, _cy - 600, _cz),
                              Geom::Point3d.new(_cx, _cy, _cz),
                              Geom::Vector3d.new(0, 0, 1))
  _cam.perspective = false
  _v.camera = _cam
  _v.zoom(_booth)
  _v.zoom(0.75)   # back off so the booth edge is inside the frame
  _v.write_image(:filename => %s, :width => 1600, :height => 1200,
                 :antialias => true, :transparent => false)
  _shots << %s
"""


def link(payload):
    b = base64.b64encode(json.dumps(payload).encode('utf-8'))
    return ('https://sales.whisperroom.com/booth-builder#d=' +
            b.decode('ascii').replace('+', '-').replace('/', '_').rstrip('='))


# Exterior footprint, x then y, from wr-booth-data.rb's :w / :h (observed).
EXT = {'8484': (86.0, 86.0), '7272': (74.0, 74.0)}

CASES = [
    # (label, model key, extra payload, which views)
    ('8484-flat', '8484', {}, ('top', 'front')),
    ('8484-vss', '8484', {'vs': 1}, ('top', 'front')),
    ('8484-hx', '8484', {'hx': 1}, ('front',)),
    ('7272-centred', '7272', {}, ('top', 'front')),
]


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else HERE)
    os.makedirs(out_dir, exist_ok=True)
    br = import_module('sketchup-bridge')
    rc = 0
    for label, key, extra, views in CASES:
        payload = json.loads(json.dumps(BOOTHS[key]))
        payload.update(extra)
        shots = ''
        for v in views:
            path = os.path.join(out_dir, '%s-%s.png' % (label, v)).replace('\\', '/')
            q = json.dumps(path)
            shots += (TOP if v == 'top' else FRONT) % (q, q)
        job = GUARD + (JOB.replace('%(LINK)s', json.dumps(link(payload)))
                          .replace('%(DIR)s', json.dumps(PARTS_DIR))
                          .replace('%(SHOTS)s', shots)
                          .replace('%(EXTW)s', repr(EXT[key][0]))
                          .replace('%(EXTH)s', repr(EXT[key][1])))
        r = br.submit(job, timeout=600, label='seat-shot ' + label,
                      write_roots=[out_dir])
        out = r.get('stdout', '')
        print('=' * 74)
        print('CASE %s' % label)
        for line in out.split('\n'):
            if ('roof unit' in line.lower() or 'ROOF' in line or 'CEILING' in line
                    or 'SEATED' in line or 'nominal footprint' in line
                    or 'roof measured' in line):
                print('    ' + line.strip())
        if r.get('status') != 'ok':
            print('BRIDGE JOB FAILED: %s\n%s' % (r.get('status'), r.get('error') or ''))
            rc = 3
            continue
        v = r['value']
        if v['error']:
            print('    THE BUILD RAISED: %s' % v['error'])
            rc = 1
        f = v.get('facts') or {}
        if f.get('unit'):
            print('    %s   left %.4f  right %.4f  front %.4f  back %.4f'
                  % (f['unit_name'], f['gap_left'], f['gap_right'],
                     f['gap_front'], f['gap_back']))
            print('    unit underside z %.4f (booth-world)' % f['sits_on_roof'])
        else:
            print('    NO ROOF UNIT IN THE MODEL')
            rc = 1
        print('    shots: %s' % ', '.join(v.get('shots') or []))
        print('    entities built and erased: %d, left behind: %s'
              % (v['created'], v['not_erased']))
        if v['not_erased']:
            print('    CLEANUP FAILED')
            rc = 2
        print('    model path (must be empty): %r' % v['model_path'])
    return rc


if __name__ == '__main__':
    sys.exit(main())
