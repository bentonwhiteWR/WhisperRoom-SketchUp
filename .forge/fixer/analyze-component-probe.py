#!/usr/bin/env python3
r"""
analyze-component-probe.py -- width-axis / _HX-pair analysis of the component probe.

WITNESS (read this before trusting any output):
  The single input is  P:\Sketchup\NewMasterComponentList\_component-probe.tsv
  written 2026-08-26 17:26 by scripts/probe-components.rb running inside SketchUp
  over the 370 .skp files in that folder.

  That TSV is an INDEPENDENT witness for the documents this script audits: it is a
  fresh measurement of the .skp component files themselves, not a copy of, and not
  derived from, any .md document or any .rb source in this repo. This matters --
  see .forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md for the 2026-08-26
  retraction caused by checking an artifact against a stale copy of itself.

  This script reads only. It writes nothing to P: and touches no .rb file.

Usage:  python analyze-component-probe.py <path-to-_component-probe.tsv>
"""
import csv, sys, re, collections

TSV = sys.argv[1] if len(sys.argv) > 1 else r"P:\Sketchup\NewMasterComponentList\_component-probe.tsv"
rows = list(csv.DictReader(open(TSV), delimiter='\t'))
by = {r['definition']: r for r in rows}

def fx(r, k): return float(r[k])
def square(r): return abs(fx(r,'x') - fx(r,'y')) < 0.01

print("rows: %d" % len(rows))
print("runs: %s" % dict(collections.Counter(r['runs'] for r in rows)))
print("anchors: %s" % collections.Counter(r['origin_anchor'] for r in rows).most_common())

# --- 1. square parts: `runs` is decided by float noise below display precision ---
sq = [r for r in rows if square(r)]
print("\n[1] SQUARE parts (|x-y| < 0.01in) -- `runs` here is NOT an authoring choice,")
print("    it is the >= tie-break in probe-components.rb:80 resolving sub-0.0001 noise.")
for r in sq:
    print("    %-26s x=%-9s y=%-9s runs=%s" % (r['definition'], r['x'], r['y'], r['runs']))

# --- 2. _HX pairing ---
pairs = [(h[:-3], h) for h in by if h.endswith('_HX') and h[:-3] in by]
orphan = [h for h in by if h.endswith('_HX') and h[:-3] not in by]
print("\n[2] _HX pairs: %d paired, %d orphan" % (len(pairs), len(orphan)))
for o in orphan: print("    ORPHAN (no non-HX twin): %s" % o)

diff = [(b,h) for b,h in pairs if by[b]['runs'] != by[h]['runs']]
diff_real = [(b,h) for b,h in diff if not square(by[b]) and not square(by[h])]
print("    axis-differing pairs: %d total, %d real (rest are square-noise)" % (len(diff), len(diff_real)))
d = collections.Counter((by[b]['runs'], by[h]['runs']) for b,h in diff_real)
print("    directions non-HX -> HX: %s" % dict(d))

# --- 3. the +10in HX rule, and parts that violate it ---
print("\n[3] HX height rule: z(HX) == z(non-HX) + 10in")
for b,h in sorted(pairs):
    dz = round(fx(by[h],'z') - fx(by[b],'z'), 4)
    if dz != 10.0:
        print("    VIOLATION %-30s z=%-10s -> %-32s z=%-10s dz=%+.4f"
              % (b, by[b]['z'], h, by[h]['z'], dz))

# --- 4. HX files that are dimensionally identical to their non-HX twin ---
print("\n[4] _HX definitions IDENTICAL to their non-HX twin (HX rework never applied):")
for b,h in sorted(pairs):
    B,H = by[b], by[h]
    key = lambda r: (r['x'], r['y'], r['z'], r['origin_anchor'], r['entities'],
                     r['origin_x'], r['origin_y'], r['origin_z'])
    if key(B) == key(H):
        print("    %-28s == %-30s x=%s y=%s z=%s anchor=%s ents=%s"
              % (b, h, B['x'], B['y'], B['z'], B['origin_anchor'], B['entities']))

# --- 5. reproduce the probe's own "length vs the number in the name" check ---
# rule copied from scripts/probe-components.rb:187-193 -- leading digits of the
# FILENAME, skipped if < 5, flagged if |len - want| > 0.02
print("\n[5] length vs the number in the name (probe's own rule):")
off = []
for r in rows:
    m = re.match(r'^(\d+)', r['file'])
    if not m: continue
    want = float(m.group(1))
    if want < 5: continue
    dd = fx(r,'length') - want
    if abs(dd) > 0.02: off.append((r['file'], want, fx(r,'length'), dd))
print("    %d part(s) do not measure their name" % len(off))
for f,w,L,dd in sorted(off):
    print("    %-30s name %-6.1f measures %10.4f (%+.4f)" % (f,w,L,dd))
