# -*- coding: utf-8 -*-
"""EXERCISE the roof-unit reporting and refusals inside the running SketchUp.

    python live-rm-report.py            a plain MDL 7272 S roof-mount link
    python live-rm-report.py --hx       the same booth height-extended
    python live-rm-report.py --efs      the same booth with EFS in the payload
    python live-rm-report.py --vss      the same booth with stacked silencers
    python live-rm-report.py --nopart   rv = 1 on MDL 4242 S, which has no part

rbtest-roofvent.py covers wr-roof-vent.rb's logic offline. This is the other
half: that booth-from-link actually calls it, that the console says the right
thing, and that the model-gating refusal really stops the build. Same shape and
the same model-safety fence as .forge/fixer/roof-vent-cbl/repro-rm-cbl.py -
build, inspect and erase in ONE bridge job so a window switch cannot land
geometry in one of Benton's files, refuse by name unless the active model is
Untitled, and erase by the entityIDs captured at build time, reading back to
confirm the erase happened.

PASS means, per mode:
  (default) the ceiling line reads 93.31 in and the seating blocker is named
  --hx      93.31 becomes 103.31 and HX is named as a blocker
  --efs     EFS is named as a blocker rather than an edge being chosen
  --vss     the roof unit is quoted at 16.5, not the 10.3125 the file measures
  --nopart  NOTHING is built and the link is refused by name
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

# MDL 7272 S, roof mounted: both vent slots carry cable-wall packs, exactly as
# booth-builder.html's applyRoofVent leaves them. Same payload the cable-wall
# reproduction uses, so the two tests describe the same booth.
BASE = {
    'm': 'MDL 7272', 'v': 'S',
    'hx': 0, 'vs': 0, 'ef': 0, 'cs': 0, 'rp': 0, 'rv': 1,
    'a': {'N0': 'STDWL46 CBL', 'N1': 'STDWL22',
          'S0': 'STDWL46 DRFRM R', 'S1': 'STDWL22',
          'E0': 'STDWL46 CBL', 'E1': 'STDWL22',
          'W0': 'STDWL46', 'W1': 'STDWL22'},
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

JOB = """
_path = File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'booth-from-link.rb')
_src  = File.read(_path)
# The tool script ends in a top-level autorun that opens UI.inputbox; the bridge
# would raise ModalBlocked and nothing would run.
_src  = _src.sub(/\\nbegin\\n\\s*WR_BoothLink\\.run\\b.*\\z/m, "\\n")
eval(_src, TOPLEVEL_BINDING, _path)

_m = Sketchup.active_model
_before = _m.entities.map(&:entityID)
_payload = WR_BoothLink.hash_payload(%s)
raise 'the link did not decode' if _payload.nil?
_err = nil
begin
  WR_BoothLink.build_from_payload(_payload, 'dir' => %s, 'dry' => false)
rescue Exception => e
  _err = "#{e.class}: #{e.message}"
end
_new = _m.entities.reject { |e| _before.include?(e.entityID) }
_ids = _new.map(&:entityID)
_m.start_operation('live-rm-report cleanup', true)
_new.each { |e| e.erase! if e.valid? }
_m.commit_operation
_left = _ids.select { |i| _m.entities.any? { |e| e.entityID == i } }
{'error' => _err, 'created' => _ids.length, 'not_erased' => _left,
 'model_path' => _m.path.to_s}
"""


def link(payload):
    b = base64.b64encode(json.dumps(payload).encode('utf-8'))
    return ('https://sales.whisperroom.com/booth-builder#d=' +
            b.decode('ascii').replace('+', '-').replace('/', '_').rstrip('='))


def variant(argv):
    """(payload, [substrings the transcript must contain], expect_refusal)."""
    p = json.loads(json.dumps(BASE))
    if '--hx' in argv:
        p['hx'] = 1
        return p, ['103.31 in', 'RM7272_HX.skp'], False
    if '--efs' in argv:
        p['ef'] = 1
        return p, ['EFS (ef = 1)', 'might'], False
    if '--vss' in argv:
        p['vs'] = 1
        return p, ['+ 16.50 in of roof unit', 'RM7272VSS.skp'], False
    if '--nopart' in argv:
        p['m'] = 'MDL 4242'
        # 4242 ventilates one wall; the roof-mount fence needs that slot to
        # carry a cable-wall pack, so the ONLY complaint is the missing part.
        p['a'] = {'N0': 'STDWL40 CBL', 'S0': 'STDWL40 DRFRM R'}
        return p, ['has no roof part', 'NO ventilation at all'], True
    return p, ['93.31 in', 'seating is not confirmed', 'RM7272.skp'], False


def main():
    payload, wants, refuse = variant(sys.argv)
    br = import_module('sketchup-bridge')
    job = GUARD + JOB % (json.dumps(link(payload)), json.dumps(PARTS_DIR))
    r = br.submit(job, timeout=300, label='live-rm-report')
    out = r.get('stdout', '')
    print(out)
    if r.get('status') != 'ok':
        print('BRIDGE JOB FAILED: %s\n%s' % (r.get('status'), r.get('error') or ''))
        return 3
    v = r['value']
    print('-' * 70)
    print('model path (must be empty): %r' % v['model_path'])
    print('top-level entities created and erased: %d' % v['created'])
    print('entities left behind after the erase (must be []): %s' % v['not_erased'])
    if v['not_erased']:
        print('CLEANUP FAILED - geometry left in the model.')
        return 2
    bad = [w for w in wants if w not in out]
    if refuse and v['created'] != 0:
        bad.append('%d top-level entit(ies) were built where the link should '
                   'have been refused outright' % v['created'])
    if bad:
        print('FAIL:')
        for b in bad:
            print('    missing from the transcript: %s' % b)
        return 1
    print('PASS - %s' % ('the link was refused and nothing was built'
                         if refuse else 'the roof unit was reported as specified'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
