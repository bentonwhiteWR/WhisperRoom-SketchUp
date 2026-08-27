# WITNESSES (independent of the code under test; none is a snapshot of wr-deck.rb):
#   1. P:/Sketchup/NewMasterComponentList/*.skp                 - the folder listing
#   2. P:/Sketchup/NewMasterComponentList/_component-probe.tsv   - measured boxes
#   3. P:/Sketchup/NewMasterComponentList/_face-levels.tsv       - levels + bracket_edge
#   4. scripts/wr-booth-data.rb                                  - booth specs, parsed live
# Reports, per Standard booth and per deck, what v1.6.30 does and what v1.6.31 does.
import csv, re, os, glob, collections
DIR=r'P:/Sketchup/NewMasterComponentList'; INSET=1.0; TOL=0.35; SYM=0.08
NAME=re.compile(r'\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z',re.I)
meas={}
for r in csv.DictReader(open(os.path.join(DIR,'_component-probe.tsv'),newline=''),delimiter='\t'):
    meas[r['definition']]=(float(r['x']),float(r['y']))
lv=collections.defaultdict(dict); edge={}
for r in csv.DictReader(open(os.path.join(DIR,'_face-levels.tsv'),newline=''),delimiter='\t'):
    lv[r['file']][float(r['z'])]=float(r['area_sq_in'])
    e=r['bracket_edge'].strip(); edge[r['file']]=float(e) if e else None
def brk(f):
    e=edge.get(f)
    return None if e is None or abs(e-0.5)<SYM else e
def rim(f):
    t=lv[f]; pk=max(t.values()); return max(z for z,a in t.items() if a>=pk*0.05)
def own(f):   # bracket_edge of the part ITSELF: nil unless it has area above its rim
    return brk(f) if sum(a for z,a in lv[f].items() if z>rim(f)+0.02)>0 else None
cat=[]
for p in glob.glob(os.path.join(DIR,'STD*.skp')):
    b=os.path.splitext(os.path.basename(p))[0]; m=NAME.match(b.strip())
    if m: cat.append(dict(file=b,cross=float(m.group(1)),along=float(m.group(2)),
        kind=m.group(3).upper(),role=(m.group(4) or 'CTR').upper(),hand=(m.group(5) or '').upper()))
specs={}
src=open('scripts/wr-booth-data.rb',encoding='utf-8',errors='replace').read()
for m in re.finditer(r"'(MDL [0-9A-Za-z ]+)'\s*=>\s*\{(.*?)\}",src,re.S):
    w=re.search(r':w\s*=>\s*([0-9.]+)',m.group(2)); h=re.search(r':h\s*=>\s*([0-9.]+)',m.group(2))
    if w and h: specs[m.group(1)]=(float(w.group(1)),float(h.group(1)))
def tile(run,ws):
    ws=sorted(ws,reverse=True); big=ws[0]
    for k in range(int(run//big),-1,-1):
        rest=run-k*big
        if abs(rest)<TOL: return [big]*k
        hit=next((w for w in ws if abs(w-rest)<TOL),None)
        if hit is not None: return [big]*k+[hit]
def pick(pool,w,want,low):
    same=[c for c in pool if abs(c['along']-w)<TOL]
    if not same: return None
    br=[c for c in same if c['role']==want] or same
    hd=[c for c in br if c['hand']]
    if not hd: return br[0]
    return next((c for c in hd if c['hand']==('L' if low else 'R')),hd[0])
def plan(n,k):
    W,H=specs[n]; w,h=W-2*INSET,H-2*INSET
    for a,c,ax in ([(w,h,True),(h,w,False)] if w>=h else [(h,w,False),(w,h,True)]):
        pool=[x for x in cat if x['kind']==k and abs(x['cross']-c)<TOL]
        if not pool: continue
        cuts=tile(a,sorted({x['along'] for x in pool}))
        if cuts is None: continue
        out=[];pos=0.0
        for i,wd in enumerate(cuts):
            out.append(dict(part=pick(pool,wd,'SIDE' if i in(0,len(cuts)-1) else 'CTR',i==0),
                nom=wd,at=pos,low=i==0,last=(len(cuts)>1 and i==len(cuts)-1),ax=ax))
            pos+=wd
        return out,a
    return None,None
def am(f,nom):
    bx,by=meas[f]; d=sorted(((abs(bx-nom),bx),(abs(by-nom),by)))
    return d[0][1] if d[0][0]<=0.5 else float('nan')
def twin(f): 
    t=f.replace('CL','FL',1); return t if t in edge else None
def half(f,kind,low,new):
    o=own(f) if new else None
    if o is not None: e=o
    else:
        tw=twin(f) if kind=='CL' else f
        e=brk(tw) if tw else None
        if new and e is not None and kind=='CL': e=1.0-e
    if e is None: return not low
    return (e>0.5) if low else (e<0.5)
print('== FIX 1: floor perimeter (1/32). Last tile: gap at the FAR wall ==')
n1=0
for n in sorted(x for x in specs if x.endswith(' S')):
    for k in ('FL','CL'):
        ts,run=plan(n,k)
        if not ts: continue
        t=ts[-1]
        if not t['last']: continue
        f=t['part']['file']; a=am(f,t['nom'])
        if a!=a: print('  %-14s %s %-22s DEFECTIVE FILE, refused'%(n,k,f)); continue
        gap=run-(t['at']+a)
        if abs(gap)>1e-6:
            n1+=1; print('  %-14s %s %-22s was %.4f short of the wall -> now flush'%(n,k,f,gap))
print('  %d deck(s) move. Every one is a FLOOR; no ceiling moves.\n'%n1)
print('== FIX 2: ceiling plan rotation. End tiles whose half-turn CHANGES ==')
n2=0
for n in sorted(x for x in specs if x.endswith(' S')):
    ts,run=plan(n,'CL')
    if not ts: continue
    for t in ts:
        if not (t['low'] or t['last']): continue
        f=t['part']['file']
        o,nw=half(f,'CL',t['low'],False),half(f,'CL',t['low'],True)
        if o!=nw:
            n2+=1; print('  %-14s %-22s %-9s turned=%-5s -> turned=%-5s'%(
                n,f,'low end' if t['low'] else 'high end',o,nw))
print('  %d ceiling tile(s) change. Floors: 0.'%n2)
print('\n== CONTROL: does any FLOOR tile change? ==')
c=0
for n in sorted(x for x in specs if x.endswith(' S')):
    ts,run=plan(n,'FL')
    if not ts: continue
    for t in ts:
        f=t['part']['file']
        if half(f,'FL',t['low'],False)!=half(f,'FL',t['low'],True): c+=1;print('  CHANGED',n,f)
print('  %d floor tiles change turn (expected 0).'%c)
print('\n== CONTROL: the 96 series ceiling, the only measured cue ==')
for n in ('MDL 96120 S','MDL 96144 S','MDL 96168 S','MDL 96192 S','MDL 9696 S'):
    ts,_=plan(n,'CL')
    for t in ts:
        if t['low'] or t['last']:
            f=t['part']['file']
            print('  %-13s %-22s own=%-7s twin=%-7s turned %s -> %s'%(n,f,own(f),brk(twin(f)),
                half(f,'CL',t['low'],False),half(f,'CL',t['low'],True)))
