# WITNESSES (three, independent, none a copy of the code under test):
#   1. P:/Sketchup/NewMasterComponentList/*.skp        - the real file list (catalogue glob)
#   2. P:/Sketchup/NewMasterComponentList/_component-probe.tsv - MEASURED box sizes
#   3. scripts/wr-booth-data.rb                        - the booth specs (w/h), parsed live
# This file re-implements WR_Deck.tile / order_cuts / plan / pick and the seating
# arithmetic of WR_Deck.build (wr-deck.rb:738-870) in Python. It is NOT compared
# against any snapshot of wr-deck.rb. The point: catalogue() derives :cross/:along
# from the NAME DIGITS (wr-deck.rb:341), so tile stations are NOMINAL, while build
# seats each tile by its MEASURED transformed min corner. That mismatch is the bug.
import csv, re, os, sys, glob

DIR = r'P:/Sketchup/NewMasterComponentList'
INSET = 1.0
TOL = 0.35
NAME = re.compile(r'\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z', re.I)

# --- witness 2: measured boxes -------------------------------------------
meas = {}
with open(os.path.join(DIR, '_component-probe.tsv'), newline='') as fh:
    for r in csv.DictReader(fh, delimiter='\t'):
        meas[r['definition']] = (float(r['x']), float(r['y']))

# --- witness 1: the real folder ------------------------------------------
cat = []
for p in glob.glob(os.path.join(DIR, 'STD*.skp')):
    base = os.path.splitext(os.path.basename(p))[0]
    m = NAME.match(base.strip())
    if not m: continue
    cat.append(dict(file=base, cross=float(m.group(1)), along=float(m.group(2)),
                    kind=m.group(3).upper(), role=(m.group(4) or 'CTR').upper(),
                    hand=(m.group(5) or '').upper()))

# --- witness 3: the specs ------------------------------------------------
specs = {}
src = open('scripts/wr-booth-data.rb', encoding='utf-8', errors='replace').read()
for m in re.finditer(r"'(MDL [0-9A-Za-z ]+)'\s*=>\s*\{(.*?)\}", src, re.S):
    body = m.group(2)
    w = re.search(r':w\s*=>\s*([0-9.]+)', body); h = re.search(r':h\s*=>\s*([0-9.]+)', body)
    if w and h: specs[m.group(1)] = (float(w.group(1)), float(h.group(1)))

def tile(run, widths):
    widths = sorted(widths, reverse=True)
    if not widths or widths[0] <= 0: return None
    big = widths[0]; n = int(run // big)
    for k in range(n, -1, -1):
        rest = run - k * big
        if abs(rest) < TOL: return [big] * k
        hit = next((w for w in widths if abs(w - rest) < TOL), None)
        if hit is not None: return [big] * k + [hit]
    return None

def pick(pool, width, want, at_low_end):
    same = [c for c in pool if abs(c['along'] - width) < TOL]
    if not same: return None
    byrole = [c for c in same if c['role'] == want] or same
    handed = [c for c in byrole if c['hand']]
    if not handed: return byrole[0]
    want_h = 'L' if at_low_end else 'R'
    return next((c for c in handed if c['hand'] == want_h), handed[0])

def along_meas(f, nom):
    # The measured extent along the TILING axis. Pick whichever box dimension the
    # nominal along-width is nearer to; a part more than 1/2 in from BOTH of its
    # own box dimensions is a defective file and is reported as such, not guessed.
    bx, by = meas[f]
    d = sorted(((abs(bx-nom), bx), (abs(by-nom), by)))
    return d[0][1] if d[0][0] <= 0.5 else float('nan')

def plan(name, kind):
    W, H = specs[name]
    w, h = W - 2*INSET, H - 2*INSET
    orders = [(w,h,True),(h,w,False)] if w >= h else [(h,w,False),(w,h,True)]
    for a_len, c_len, a_is_x in orders:
        pool = [c for c in cat if c['kind'] == kind and abs(c['cross'] - c_len) < TOL]
        if not pool: continue
        cuts = tile(a_len, sorted({c['along'] for c in pool}))
        if cuts is None: continue
        out, pos = [], 0.0
        for i, wd in enumerate(cuts):
            part = pick(pool, wd, 'SIDE' if (i == 0 or i == len(cuts)-1) else 'CTR', i == 0)
            out.append(dict(part=part, nom=wd, at=pos, low=(i == 0),
                            last=(i == len(cuts)-1), a_is_x=a_is_x))
            pos += wd
        return out, a_len, a_is_x
    return None, None, None

def report(name):
    print('=== %s   spec %g x %g ===' % (name, *specs[name]))
    for kind in ('FL', 'CL'):
        tiles, run, a_is_x = plan(name, kind)
        if tiles is None:
            print('  %s: no tiling' % kind); continue
        print('  %s  run %.4f along %s   (perimeter %.4f .. %.4f)'
              % (kind, run, 'X' if a_is_x else 'Y', INSET, INSET + run))
        for t in tiles:
            f = t['part']['file']
            bx, by = meas.get(f, (float('nan'),)*2)
            am = along_meas(f, t['nom'])
            lo = INSET + t['at']; hi = lo + am
            flag = ''
            if t['last']:
                gap = (INSET + run) - hi
                flag = '   <== %+.4f at the HIGH perimeter (%s)' % (
                    -gap, '%d/32 SHORT' % round(gap*32) if abs(gap) > 1e-6 else 'flush')
            elif t['low']:
                flag = '   (low perimeter: flush by construction)'
            print('    %-20s nom %6.2f  meas %8.4f  station %8.4f  spans %8.4f .. %8.4f%s'
                  % (f, t['nom'], am, lo, lo, hi, flag))
    print()

targets = sys.argv[1:] or ['MDL 84126 S', 'MDL 7272 S', 'MDL 6060 S', 'MDL 96120 S', 'MDL 7296 S', 'MDL 96168 S']
for t in targets: report(t)

print('=== EVERY Standard booth: high-perimeter shortfall on each deck ===')
print('%-16s %-34s %-34s' % ('booth', 'FL last tile shortfall', 'CL last tile shortfall'))
bad = 0
for name in sorted(n for n in specs if n.endswith(' S')):
    line = []
    for kind in ('FL', 'CL'):
        tiles, run, _ = plan(name, kind)
        if tiles is None: line.append('no tiling'); continue
        t = tiles[-1]; f = t['part']['file']
        if f not in meas: line.append('%s UNMEASURED' % f); continue
        am = along_meas(f, t['nom']); gap = (INSET + run) - (INSET + t['at'] + am)
        line.append('%-22s %+.4f' % (f, -gap))
        if abs(gap) > 1e-6: bad += 1
    print('%-16s %-34s %-34s' % (name, line[0], line[1]))
print('\n%d deck(s) end short of the high perimeter.' % bad)
