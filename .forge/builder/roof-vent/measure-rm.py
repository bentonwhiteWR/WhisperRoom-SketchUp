# -*- coding: utf-8 -*-
"""MEASURE every per-model RM roof-vent part, and check Benton's stated offsets.

    python measure-rm.py            measure all 22 models (flat + VSS)
    python measure-rm.py --json F   also write the raw table to F

WHY

.forge/roof-vent-placement.md records Benton's stated offsets: 4 in front and
back (3 in on the 84 series), 3.125 in left and right on "most". He gave BOTH
edges of both axes, which over-determines the part's size:

    depth  should be  booth depth - 8      (- 6 on the 84 series)
    width  should be  booth width - 6.25

So the parts are checkable. This loads each RM<model>.skp into the running
SketchUp as a definition, reads its bounding box, and compares. Agreement
confirms the numbers AND the reference face empirically; disagreement is a
finding for Benton and nothing gets adjusted to fit.

It also falls out that any model whose box does not satisfy 3.125/side is an
exception to his hedged "most" - the list he could not give from memory.

SAFETY

The job asserts Sketchup.active_model.path is empty INSIDE the Ruby, before it
touches the model, and refuses by name otherwise. It loads DEFINITIONS only -
no instance, no geometry - and purges every definition it added, reading back
the definition list to confirm the purge. One job, no seam.
"""
import io
import json
import os
import sys
from importlib import import_module

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))

PARTS_DIR = 'P:/Sketchup/NewMasterComponentList'
CATALOG = os.path.join(os.path.dirname(os.path.dirname(REPO)),
                       'WhisperRoomQuote', 'whisperroom-catalog', 'data',
                       'models.json')

# The 22 models that have a per-model RM part (observed, directory listing).
MODELS = ['4260', '4284', '4872', '4896', '6060', '6084', '7272', '7296',
          '8484', '84102', '84126', '9696', '96120', '96144', '96168',
          '96192', '102102', '102126', '102144', '102168', '102186', '10284']

GUARD = (
    "_m = Sketchup.active_model\n"
    "if !_m.path.to_s.strip.empty?\n"
    "  raise \"refusing to run: the active model is a SAVED file - \" \\\n"
    "        \"title #{_m.title.inspect}, path #{_m.path.inspect}. This probe \" \\\n"
    "        \"loads and purges component definitions and runs only against an \" \\\n"
    "        \"Untitled scratch model. Open a new model and re-run; do not \" \\\n"
    "        \"switch models on anyone's behalf while they are working.\"\n"
    "end\n")

JOB = """
_m = Sketchup.active_model
_dir = %s
_names = %s
_before = _m.definitions.map { |d| d.name }
_out = {}
_names.each do |n|
  _p = File.join(_dir, n + '.skp')
  unless File.exist?(_p)
    _out[n] = {'missing' => true}
    next
  end
  begin
    _d = _m.definitions.load(_p)
    _b = _d.bounds
    _out[n] = {
      'defn'  => _d.name,
      'w'     => _b.width.to_f,
      'h'     => _b.height.to_f,
      'd'     => _b.depth.to_f,
      'minx'  => _b.min.x.to_f, 'miny' => _b.min.y.to_f, 'minz' => _b.min.z.to_f,
      'maxx'  => _b.max.x.to_f, 'maxy' => _b.max.y.to_f, 'maxz' => _b.max.z.to_f,
      'ents'  => _d.entities.length,
      'kids'  => _d.entities.grep(Sketchup::ComponentInstance).map { |i| i.definition.name }.uniq.sort,
      'groups'=> _d.entities.grep(Sketchup::Group).length
    }
  rescue Exception => e
    _out[n] = {'error' => "#{e.class}: #{e.message}"}
  end
end
_m.definitions.purge_unused
_after = _m.definitions.map { |d| d.name }
_leaked = _after - _before
{'parts' => _out, 'leaked_definitions' => _leaked,
 'model_path' => _m.path.to_s, 'defs_before' => _before.length,
 'defs_after' => _after.length}
"""


def job(names, parts_dir):
    return GUARD + JOB % (json.dumps(parts_dir), json.dumps(names))


def catalog_dims():
    """{model => (w, d, h)} exterior inches, from the catalogue stdDims."""
    d = json.load(io.open(CATALOG, encoding='utf-8'))
    fmt = d['tupleFormat']
    out = {}
    for row in d['models']:
        r = dict(zip(fmt, row))
        nums = []
        for part in r['stdDims'].split('x'):
            part = part.strip()
            ft = 0.0
            inch = 0.0
            if "'" in part:
                ft = float(part.split("'")[0].strip())
                part = part.split("'", 1)[1]
            part = part.replace('"', '').strip()
            if part:
                inch = float(part)
            nums.append(ft * 12 + inch)
        out[r['name']] = tuple(nums)
    return out


def main():
    br = import_module('sketchup-bridge')
    names = []
    for m in MODELS:
        names.append('RM' + m)
        names.append('RM' + m + 'VSS')
    r = br.submit(job(names, PARTS_DIR), timeout=900, label='measure-rm')
    print(r.get('stdout', ''))
    if r.get('status') != 'ok':
        print('BRIDGE JOB FAILED: %s\n%s' % (r.get('status'), r.get('error') or ''))
        return 3
    v = r['value']
    print('model path (must be empty): %r' % v['model_path'])
    print('definitions leaked (must be []): %s' % v['leaked_definitions'])
    print('')

    cat = catalog_dims()
    print('%-8s %-14s %-20s %-20s %-8s %s' %
          ('model', 'booth ext', 'part x,y (in)', 'per-side x / y', 'z', 'ents'))
    print('-' * 92)
    for m in MODELS:
        p = v['parts'].get('RM' + m) or {}
        if 'w' not in p:
            print('%-8s  %s' % (m, p))
            continue
        cw, cd = cat[m][0], cat[m][1]
        ox = (cw - p['w']) / 2.0
        oy = (cd - p['h']) / 2.0
        print('%-8s %5.1f x%6.1f  %8.3f x%8.3f  %7.3f /%8.3f  %7.3f  %d' %
              (m, cw, cd, p['w'], p['h'], ox, oy, p['d'], p['ents']))

    print('')
    print('%-8s %-20s %-10s %s' % ('model', 'VSS part x,y', 'VSS z', 'flat z / delta'))
    print('-' * 92)
    for m in MODELS:
        p = v['parts'].get('RM' + m + 'VSS') or {}
        f = v['parts'].get('RM' + m) or {}
        if 'w' not in p:
            print('%-8s  %s' % (m, p))
            continue
        fz = f.get('d')
        print('%-8s %8.3f x%8.3f  %8.3f   %s' %
              (m, p['w'], p['h'], p['d'],
               ('%8.3f  %+.3f' % (fz, p['d'] - fz)) if fz else 'n/a'))

    if '--json' in sys.argv:
        out = sys.argv[sys.argv.index('--json') + 1]
        with io.open(out, 'w', encoding='utf-8') as fh:
            json.dump({'parts': v['parts'], 'catalog': cat}, fh, indent=1)
        print('\nraw table -> %s' % out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
