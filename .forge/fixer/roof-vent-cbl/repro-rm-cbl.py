# -*- coding: utf-8 -*-
"""REPRODUCE (and then re-run to disprove) the roof-mounted-vent wrong-wall bug.

    python repro-rm-cbl.py            build the RM booth live, print what landed
    python repro-rm-cbl.py --enh      the same design as an ENHANCED booth
    python repro-rm-cbl.py --half     a HALF-APPLIED roof-mount link; must refuse
    python repro-rm-cbl.py --link     just print the #d= share link and exit

THE BUG

booth-builder.html's applyRoofVent() rewrites every ' VNT' pack to ' CBL'
BEFORE the share link is serialised, so a roof-mount link arrives carrying
'STDWL46 CBL'. booth-from-link.rb's component_for had no CBL branch, so the
pack was untranslatable, the slot was left unassigned, and
build-booth-components' guess_component filled it from the layout's own
:sk => 'VNT'. The booth built VENT walls on a booth whose walls are cable
walls, while the console printed only "rv: roof-mounted vent (out of scope
per GOAL)" — which reads as "we skipped the roof unit", not "we drew the
wrong walls".

WHAT THIS DOES

Builds a real MDL 7272 S roof-mount design from a self-contained #d= link
inside the running SketchUp, reads back the component that landed on each of
the two former vent slots (N0, E0), and erases everything it created by
entityID, confirming the erase. Build, inspect and erase are ONE bridge job so
a window switch cannot land geometry in Benton's file mid-run, and the job
refuses by name unless the active model is Untitled.

The payload is built here rather than copied from a browser so the test is
self-contained. Its pack strings are the portal's own constructors —
solidPack/ventPack/doorPack at booth-builder.html:2937-2939 — with
applyRoofVent's ' VNT' -> ' CBL' substitution applied to the two slots
wr-booth-data.rb marks :sk => 'VNT' on this layout.

PASS means: N0 and E0 carry 46PanelCBL (ENH 41.5PanelCBL under --enh). FAIL
means they carry 46VNT — the reported bug.

--half hand-edits E0 back to 'STDWL46 VNT', which is the half-applied roof
mount the fence exists for: half the walls swapped, and on a real RM booth that
means the booth ships either double-ventilated or not ventilated at all. PASS
there means NOTHING was built.
"""
import base64
import json
import os
import sys
from importlib import import_module

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SCRIPTS = os.path.join(REPO, 'scripts')
sys.path.insert(0, SCRIPTS)

PARTS_DIR = 'P:/Sketchup/NewMasterComponentList'

# MDL 7272 S. Two vent slots (N0, E0) per wr-booth-data.rb and per the
# catalogue's own vents figure for 7272 (2, models.json). Under roof mount both
# are cable walls.
PAYLOAD = {
    'm': 'MDL 7272', 'v': 'S',
    'hx': 0, 'vs': 0, 'ef': 0, 'cs': 0, 'rp': 0,
    'rv': 1,
    'a': {
        'N0': 'STDWL46 CBL',      # was STDWL46 VNT
        'N1': 'STDWL22',
        'S0': 'STDWL46 DRFRM R',
        'S1': 'STDWL22',
        'E0': 'STDWL46 CBL',      # was STDWL46 VNT
        'E1': 'STDWL22',
        'W0': 'STDWL46',
        'W1': 'STDWL22',
    },
}
VENT_SLOTS = ['N0', 'E0']


def link(payload=None):
    b = base64.b64encode(json.dumps(payload or PAYLOAD).encode('utf-8'))
    return ('https://sales.whisperroom.com/booth-builder#d=' +
            b.decode('ascii').replace('+', '-').replace('/', '_').rstrip('='))


# The scratch-model fence, INSIDE the job, in the same single-threaded run as
# the build — a Python-side pre-flight is already stale by the time the job
# executes. Same shape as scripts/eval-floorplan.py's SCRATCH_GUARD.
GUARD = (
    "_m = Sketchup.active_model\n"
    "if !_m.path.to_s.strip.empty?\n"
    "  raise \"refusing to build: the active model is a SAVED file - \" \\\n"
    "        \"title #{_m.title.inspect}, path #{_m.path.inspect}. This repro \" \\\n"
    "        \"builds and erases geometry and runs only against an Untitled \" \\\n"
    "        \"scratch model. Open a new model and re-run; do not switch \" \\\n"
    "        \"models on anyone's behalf while they are working.\"\n"
    "end\n")


def job(payload, parts_dir):
    """Build, read back, erase — one job, no seam a window switch can enter."""
    return GUARD + """
_path = File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'booth-from-link.rb')
_src  = File.read(_path)
# The tool script ends in a top-level autorun that opens UI.inputbox. Strip it;
# the bridge would raise ModalBlocked and nothing would run.
_src  = _src.sub(/\\nbegin\\n\\s*WR_BoothLink\\.run\\b.*\\z/m, "\\n")
eval(_src, TOPLEVEL_BINDING, _path)

_m = Sketchup.active_model
_before = _m.entities.map(&:entityID)
_link = %s
_payload = WR_BoothLink.hash_payload(_link)
raise 'the link did not decode' if _payload.nil?

_err = nil
begin
  WR_BoothLink.build_from_payload(_payload, 'dir' => %s, 'dry' => false)
rescue Exception => e
  _err = "#{e.class}: #{e.message}"
end

_new = _m.entities.reject { |e| _before.include?(e.entityID) }
_ids = _new.map(&:entityID)
_slots = {}
_new.grep(Sketchup::Group).each do |g|
  g.entities.grep(Sketchup::ComponentInstance).each do |i|
    n = i.name.to_s
    next if n.empty?
    _slots[n.split(/\\s\\s+/).first] = n.split(/\\s\\s+/).last
  end
end

# Erase by the entityIDs captured at build time — nothing else.
_m.start_operation('repro cleanup', true)
_new.each { |e| e.erase! if e.valid? }
_m.commit_operation
_left = _ids.select { |i| _m.entities.any? { |e| e.entityID == i } }

{'error' => _err, 'created' => _ids.length, 'slots' => _slots,
 'not_erased' => _left, 'model_path' => _m.path.to_s}
""" % (json.dumps(link(payload)), json.dumps(parts_dir))


def variant(argv):
    """(payload, {slot => wanted component}, expect_refusal).

    An ENHANCED booth is BOTH shells, not a swapped one, so its cable wall has
    to land twice: the Standard part on the outer slot and the IEP part on the
    inner slot the layout calls '<slot>i'. Checking only one of them would pass
    on the exact substitution ENH_MISSING_ABORTS exists to stop.
    """
    p = json.loads(json.dumps(PAYLOAD))
    if '--enh' in argv:
        p['v'] = 'E'
        want = {}
        for s in VENT_SLOTS:
            want[s] = '46PanelCBL'
            want[s + 'i'] = 'ENH 41.5PanelCBL'
        return p, want, False
    if '--half' in argv:
        p['a']['E0'] = 'STDWL46 VNT'      # the swap, half done
        return p, {}, True
    return p, dict((s, '46PanelCBL') for s in VENT_SLOTS), False


def main():
    if '--link' in sys.argv:
        print(link(variant(sys.argv)[0]))
        return 0
    payload, want, refuse = variant(sys.argv)
    br = import_module('sketchup-bridge')
    r = br.submit(job(payload, PARTS_DIR), timeout=300, label='repro-rm-cbl')
    print(r.get('stdout', ''))
    if r.get('status') != 'ok':
        print('BRIDGE JOB FAILED: %s\n%s' %
              (r.get('status'), r.get('error') or ''))
        return 3
    v = r['value']
    print('-' * 70)
    print('model path (must be empty): %r' % v['model_path'])
    print('top-level entities created and erased: %d' % v['created'])
    print('entities left behind after the erase (must be []): %s' % v['not_erased'])
    if v['error']:
        print('build raised: %s' % v['error'])
    if v['not_erased']:
        print('CLEANUP FAILED — geometry left in the model.')
        return 2
    if refuse:
        # The refusal ends in a UI.messagebox, which the bridge turns into a
        # raise; that raise IS the refusal reaching a human. What matters is
        # that no geometry was placed.
        if v['created'] == 0 and 'REFUSED' in r.get('stdout', ''):
            print('PASS — the half-applied roof-mount link was refused and '
                  'nothing was built.')
            return 0
        print('FAIL — a half-applied roof-mount link built %d top-level '
              'entit(ies) instead of being refused.' % v['created'])
        return 1
    bad = []
    for s in sorted(want):
        got = v['slots'].get(s)
        print('  slot %-4s built as %s' % (s, got))
        if got != want[s]:
            bad.append('%s built as %s, wanted %s' % (s, got, want[s]))
    if bad:
        print('FAIL — the roof-mount booth built the wrong walls:')
        for b in bad:
            print('    ' + b)
        return 1
    print('PASS — both former vent slots built cable walls.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
