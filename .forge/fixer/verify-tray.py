# WITNESS: P:/Sketchup/NewMasterComponentList/_face-levels.tsv (380767 B, mtime 2026-08-26 19:38),
# the 370-part full-folder run. This file is the SOLE input; nothing here is compared
# against a repo snapshot of itself.
# Re-implements WR_Deck.contact_z (wr-deck.rb:622) and the OLD + NEW iep_upside_down?
# (build-booth-components.rb:~650) over the same tally the runtime would build.
import csv, collections, itertools
rows=collections.defaultdict(dict)
for r in csv.DictReader(open(r'P:/Sketchup/NewMasterComponentList/_face-levels.tsv',newline=''),delimiter='\t'):
    rows[r['file']][float(r['z'])]=float(r['area_sq_in'])

def contact_z(t, kind):
    if not t: return (None, False)
    peak=max(t.values()); lv=sorted(z for z,a in t.items() if a>=peak*0.05)
    if not lv: return (None, False)
    cands=[(a,b) for a,b in itertools.combinations(lv,2) if abs((b-a)-1.0)<0.05]
    pair=max(cands,key=lambda p:t[p[0]]+t[p[1]]) if cands else (lv[0],lv[-1])
    minor=[z for z in lv if not (pair[0]-0.02<=z<=pair[1]+0.02)]
    if not minor: return (pair[0], False)
    m=max(minor,key=lambda z:t[z]); above=m>(pair[0]+pair[1])/2.0
    return (pair[1] if above else pair[0], above if kind=='CL' else (not above))

def old(t):
    peak=max(t.values()); lv=sorted(z for z,a in t.items() if a>=peak*0.05)
    if len(lv)<2: return 'ABSTAIN(one level)'
    alo,ahi=t[lv[0]],t[lv[-1]]
    if ahi>=alo*2.0: return 'DOWN'
    if alo>=ahi*2.0: return 'UP-FLIP'
    return 'ABSTAIN(no cue)'

PLATE,RIMMAX,RIMMIN=0.50,0.25,10.0
def new(t):
    zs=sorted(t)
    if len(zs)<2: return 'ABSTAIN(one level)'
    peak=max(t.values()); alo,ahi=t[zs[0]],t[zs[-1]]
    ph,pl=ahi>=peak*PLATE, alo>=peak*PLATE
    rl=(alo<=peak*RIMMAX and alo>=RIMMIN); rh=(ahi<=peak*RIMMAX and ahi>=RIMMIN)
    if ph and rl: return 'DOWN'
    if pl and rh: return 'UP-FLIP'
    return 'ABSTAIN(no cue)'

enh=[f for f in sorted(rows) if f.startswith('ENH ') and 'CL' in f]
std=[f for f in sorted(rows) if f.startswith('STD') and not f.startswith('STDSS') and 'CL' in f]
print('== contact_z on ENH CL: any TRUE would override the mouth tell ==')
tr=[f for f in enh if contact_z(rows[f],'CL')[1]]
print('  ENH CL with contact_z upside_down==True:', tr if tr else 'NONE (all 23 return False)')
print()
print('%-22s %-18s %-18s %s'%('ENH CL part','OLD (shipped)','NEW','CHANGED'))
ch=0
for f in enh:
    o,n=old(rows[f]),new(rows[f])
    if o!=n: ch+=1
    print('%-22s %-18s %-18s %s'%(f,o,n,'<<<' if o!=n else ''))
print('\n  %d of %d ENH CL parts change verdict.'%(ch,len(enh)))
print('  NEW verdicts:',dict(collections.Counter(new(rows[f]) for f in enh)))
print()
print('== SAFETY: STD ceilings must still all abstain (harness property) ==')
print('  OLD:',dict(collections.Counter(old(rows[f]) for f in std)))
print('  NEW:',dict(collections.Counter(new(rows[f]) for f in std)))
print('  STD CL that NEW would decide:',[f for f in std if not new(rows[f]).startswith('ABSTAIN')])
print()
print('== SAFETY: STD floors (gated out by kind==CL, checked anyway) ==')
stdfl=[f for f in sorted(rows) if f.startswith('STD') and not f.startswith('STDSS') and 'FL' in f]
print('  NEW would decide on:',[f for f in stdfl if not new(rows[f]).startswith('ABSTAIN')])
