import json, collections
d=json.load(open('rays.json'))
NOM={'S':4.38,'N':93.75,'W':4.38,'E':165.69}
SGN={'S':1,'N':-1,'W':1,'E':-1}
def grid(w):
    v=d['walls'][w]; return v['r0'],v['z0'],v['rows']
for w in 'SNWE':
    r0,z0,rows=grid(w)
    h=collections.Counter()
    for i,row in enumerate(rows):
        z=z0+0.5*i
        if not 4<z<79: continue
        for j,(nc,nm) in enumerate(row):
            if nc is not None and nm not in('Bass Trap',) and not nm.startswith('WR Duct') and abs(nc-NOM[w])<0.4: h[(round(nc,3),nm)]+=1
    print(w,'face histogram:',h.most_common(8))
# flat-run limits: a sample is 'free' if it is a wall face within 0.3 of nominal (no trap, cover, trim, glass, door)
def free(w,nc,nm):
    if nc is None: return False
    if nm=='Bass Trap' or nm.startswith('WR Duct') or nm.startswith('SL52') or nm.startswith('STDSS') or nm.startswith('IEP'): return False
    if nm in ('ENH LeftWADoor','LeftWADoorWithRamp','Group229','46Panel3236WDO'): return False
    p=(nc-NOM[w])*SGN[w]
    return -0.3<=p<=0.1
for w in 'SNWE':
    r0,z0,rows=grid(w)
    print('==',w)
    last=None
    for i,row in enumerate(rows):
        z=z0+0.5*i
        segs=[];cur=None
        for j,(nc,nm) in enumerate(row):
            a=r0+0.5*j
            if free(w,nc,nm):
                if cur is None: cur=[a,a]
                else: cur[1]=a
            else:
                if cur: segs.append(tuple(cur)); cur=None
        if cur: segs.append(tuple(cur))
        segs=[s for s in segs if s[1]-s[0]>=2]
        key=tuple(segs)
        if key!=last:
            print(f'  z {z:5.1f}: '+'  '.join(f'[{s[0]:.1f},{s[1]:.1f}]' for s in segs))
            last=key
