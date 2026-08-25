# Offline replay of save-scene-components.rb subject_for (name-first, v1.5.6)
# against the real dry-run manifest. No SketchUp, no Ruby - this reproduces the
# resolution logic in Python over the manifest's own scene/component columns.
#   python .forge/builder/replay-name-match.py [manifest.tsv]
import csv, re, sys
path = sys.argv[1] if len(sys.argv) > 1 else r'P:\Sketchup\NewMasterComponentList\_scene-components-dryrun.tsv'
rows = list(csv.DictReader(open(path, encoding='utf-8-sig'), delimiter='\t'))
# The set of definition names known to exist in the model. NOTE: this is the set
# the previous run RESOLVED to, so it is a subset of every definition in the
# model - a "gap" here could in principle be a definition no scene resolved to.
comps = set(r['component'] for r in rows)

def scene_label(n):
    n = n.strip()
    if n.startswith('(') and n.endswith(')') and n.index(')') == len(n) - 1:
        n = n[1:-1].strip()
    return n

named = gap = 0
for r in rows:
    w = scene_label(r['scene'])
    if w in comps:
        named += 1
        continue
    gap += 1
    near = sorted(c for c in comps if re.match(re.escape(w) + r'#\d+$', c))
    lead = 'no name match' + ('; model has ' + ', '.join('"%s"' % n for n in near) if near else '')
    print('  GAP  #%-4s %-28s %s; %s' % (r['n'], r['scene'], lead, r['how']))
print('\nname matches %d   model gaps %d   total %d' % (named, gap, len(rows)))
