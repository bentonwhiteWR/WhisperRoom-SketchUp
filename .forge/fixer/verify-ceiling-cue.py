# WITNESS: P:/Sketchup/NewMasterComponentList/_face-levels.tsv (the 370-part
# full-folder run of 2026-08-26 19:38). SOLE input. Nothing here is compared
# against a repo snapshot of itself or of wr-deck.rb.
# Re-implements WR_Deck.rim_z (wr-deck.rb:237) and WR_Deck.contact_z
# (wr-deck.rb:622) to answer two questions the deck builder never asks:
#   Q1 which STANDARD CL parts carry a cue of their OWN (area above rim_z)?
#   Q2 does any STANDARD CL part get flip==true AND tile along its own Y?
#      (an X-axis 180 mirrors Y, so that pair would reverse the tiling axis)
import csv, collections, itertools
rows = collections.defaultdict(dict); short = {}
for r in csv.DictReader(open(r'P:/Sketchup/NewMasterComponentList/_face-levels.tsv',
                             newline=''), delimiter='\t'):
    rows[r['file']][float(r['z'])] = float(r['area_sq_in'])
    short[r['file']] = r['short_axis']

def rim_z(t):
    peak = max(t.values())
    return max(z for z, a in t.items() if a >= peak * 0.05)

def contact_z(t, kind):
    peak = max(t.values()); lv = sorted(z for z, a in t.items() if a >= peak*0.05)
    if not lv: return (None, False)
    cands = [(a,b) for a,b in itertools.combinations(lv,2) if abs((b-a)-1.0) < 0.05]
    pair = max(cands, key=lambda p: t[p[0]]+t[p[1]]) if cands else (lv[0], lv[-1])
    minor = [z for z in lv if not (pair[0]-0.02 <= z <= pair[1]+0.02)]
    if not minor: return (pair[0], False)
    m = max(minor, key=lambda z: t[z]); above = m > (pair[0]+pair[1])/2.0
    return (pair[1] if above else pair[0], above if kind=='CL' else (not above))

std_cl = [f for f in sorted(rows) if f.startswith('STD') and not f.startswith('STDSS')
          and 'CL' in f]
print('%-22s %-7s %-8s %-7s %-9s %s' % ('STD CL part','rim_z','area>rim','flip','short_ax','sub-plate hardware (z:area below rim)'))
own = 0; risky = []
for f in std_cl:
    t = rows[f]; rz = rim_z(t); cz, flip = contact_z(t, 'CL')
    above = sum(a for z, a in t.items() if z > rz + 0.02)
    if above > 0: own += 1
    if flip and short[f] == 'Y': risky.append(f)
    below = sorted((z, a) for z, a in t.items() if z < cz - 0.02)
    # the sub-plate pan: the biggest level below the contact plane. Hardware is
    # everything under THAT.
    pan = max(below, key=lambda p: p[1])[0] if below else None
    hw = [(z, a) for z, a in below if pan is not None and z < pan - 0.02]
    print('%-22s %-7.4f %-8.2f %-7s %-9s %s' % (
        f, rz, above, flip, short[f],
        ' '.join('%.4f:%.2f' % p for p in hw) if hw else '(none)'))
print('\nQ1: %d of %d Standard CL parts carry any area ABOVE their rim '
      '(a cue of their own under the CURRENT rule).' % (own, len(std_cl)))
print('Q2: Standard CL parts with flip==true AND short axis Y '
      '(where the X-180 would mirror the tiling axis):', risky if risky else 'NONE')
print('\nSanity - the same for the STD FL twins, which DO drive the turn today:')
for f in sorted(rows):
    if f.startswith('STD') and not f.startswith('STDSS') and 'FL' in f and 'SIDE' in f:
        t = rows[f]; rz = rim_z(t)
        print('  %-22s rim %.4f  area above rim %8.2f  short_ax %s'
              % (f, rz, sum(a for z, a in t.items() if z > rz + 0.02), short[f]))
