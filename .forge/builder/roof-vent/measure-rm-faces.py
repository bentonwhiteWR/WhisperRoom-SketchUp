# -*- coding: utf-8 -*-
"""RE-MEASURE the 44 RM roof parts by their FACES, and by their authored origin.

    python measure-rm-faces.py

The companion to measure-rm.py, which reads defn.bounds. That box is inflated by
anything non-face fused into an export - dimensions, text, construction geometry
- which is why wr-overlays.rb measures faces instead (geom_extents). Some of the
boxes measure-rm.py returned carry odd fractions (54.114, 80.750) that do not
look like authored hardware, so this measures the same parts face-only. It also
prints the low corner, which is what showed that RM102186.skp is the one file
NOT re-centred on its origin: it sits at (3.250, 4.000, 0), exactly its own
per-side offsets, and is therefore the only direct evidence of the authoring
datum. See the report this Builder handed back for what that means.

Result on 2026-08-31: the face box and the definition box agreed to the
thousandth on all 44 files, so the odd fractions are real geometry.

Writes rm-faces.json beside itself.

SAFETY: the Untitled-model assertion is inside the Ruby, before anything is
touched; definitions only, never an instance; every definition loaded is purged
and the purge read back.
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
MODELS = ['4260', '4284', '4872', '4896', '6060', '6084', '7272', '7296',
          '8484', '84102', '84126', '9696', '96120', '96144', '96168',
          '96192', '102102', '102126', '102144', '102168', '102186', '10284']

JOB = """
_m = Sketchup.active_model
unless _m.path.to_s.strip.empty?
  raise "refusing to run: the active model is a SAVED file - title " \\
        "#{_m.title.inspect}, path #{_m.path.inspect}. This probe loads and " \\
        "purges component definitions and runs only against an Untitled " \\
        "scratch model. Open a new model and re-run; do not switch models on " \\
        "anyone's behalf while they are working."
end
def _fbox(ents, tr, acc)
  ents.each do |e|
    if e.is_a?(Sketchup::Face)
      e.vertices.each do |v|
        p = v.position.transform(tr)
        acc[0] = p.x.to_f if acc[0].nil? || p.x.to_f < acc[0]
        acc[1] = p.y.to_f if acc[1].nil? || p.y.to_f < acc[1]
        acc[2] = p.z.to_f if acc[2].nil? || p.z.to_f < acc[2]
        acc[3] = p.x.to_f if acc[3].nil? || p.x.to_f > acc[3]
        acc[4] = p.y.to_f if acc[4].nil? || p.y.to_f > acc[4]
        acc[5] = p.z.to_f if acc[5].nil? || p.z.to_f > acc[5]
      end
    elsif e.is_a?(Sketchup::Group)
      _fbox(e.entities, tr * e.transformation, acc)
    elsif e.is_a?(Sketchup::ComponentInstance)
      _fbox(e.definition.entities, tr * e.transformation, acc)
    end
  end
  acc
end
_before = _m.definitions.map { |d| d.name }
_out = {}
%s.each do |n|
  _p = File.join(%s, n + '.skp')
  next unless File.exist?(_p)
  _d = _m.definitions.load(_p)
  _a = _fbox(_d.entities, Geom::Transformation.new, [nil] * 6)
  _kn = _d.entities.grep(Sketchup::ComponentInstance).map { |i| i.definition.name }
  _out[n] = {'box' => _a, 'nkids' => _d.entities.length, 'kinds' => _kn.tally,
             'bb' => [_d.bounds.width.to_f, _d.bounds.height.to_f,
                      _d.bounds.depth.to_f]}
end
_m.definitions.purge_unused
{'parts' => _out, 'leak' => _m.definitions.map { |d| d.name } - _before,
 'path' => _m.path.to_s}
"""


def main():
    br = import_module('sketchup-bridge')
    names = ['RM' + m for m in MODELS] + ['RM' + m + 'VSS' for m in MODELS]
    r = br.submit(JOB % (json.dumps(names), json.dumps(PARTS_DIR)),
                  timeout=900, label='rm-faces')
    if r.get('status') != 'ok':
        print('BRIDGE JOB FAILED: %s\n%s' % (r.get('status'), r.get('error') or ''))
        return 3
    v = r['value']
    print('model path (must be empty): %r' % v['path'])
    print('definitions leaked (must be []): %s' % v['leak'])
    print('')
    print('%-14s %-28s %-28s %s' % ('part', 'FACES x,y,z', 'defn bounds x,y,z',
                                    'low corner / children'))
    print('-' * 108)
    for n in names:
        p = v['parts'].get(n)
        if not p:
            print('%-14s MISSING' % n)
            continue
        b = p['box']
        print('%-14s %8.3f %8.3f %8.4f     %8.3f %8.3f %8.4f     '
              '%7.3f %7.3f %7.3f  %d %s' %
              (n, b[3] - b[0], b[4] - b[1], b[5] - b[2],
               p['bb'][0], p['bb'][1], p['bb'][2], b[0], b[1], b[2],
               p['nkids'], p['kinds']))
    out = os.path.join(HERE, 'rm-faces.json')
    with io.open(out, 'w', encoding='utf-8') as fh:
        json.dump(v, fh, indent=1)
    print('\nraw -> %s' % out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
