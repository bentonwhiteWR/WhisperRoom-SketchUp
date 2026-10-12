# Build the per-wall survey JSON (wall-local 2D rects) from dump.json + the ray findings.
import json
D=json.load(open('dump.json'))
def wall_of(it):
    b=it['box']; d=it['def']
    if d=='Bass Trap': return 'S'  # handled separately (corner)
    x0,x1,y0,y1,z0,z1=b
    if x1<0: return 'OUTSIDE'
    if y0<8 and y1<9: return 'S'
    if y1>89 and y0>88: return 'N'
    if x0<8 and x1<9: return 'W'
    if x0>160: return 'E'
    return '?'
def rect(w,b):
    x0,x1,y0,y1,z0,z1=b
    return [x0,x1,z0,z1] if w in 'SN' else [y0,y1,z0,z1]
walls={w:{'pieces':[],'fixed':[]} for w in 'SNEW'}
staged=[]
for it in D['items']:
    d=it['def']; b=it.get('body',it['box'])
    if d.startswith('Audimute') or d.startswith('Foam'):
        w=wall_of(dict(it,box=b))
        if w=='OUTSIDE': staged.append({'name':it['name'],'def':d,'box':b}); continue
        walls[w]['pieces'].append({'name':it['name'],'def':d,'rect':rect(w,b),'depth':[b[2],b[3]] if w in 'SN' else [b[0],b[1]],'fabric':it.get('fabric')})
    elif d.startswith('WR Duct'):
        w=wall_of(it); walls[w]['fixed'].append({'kind':'cover','name':it['name'].strip(),'rect':rect(w,it['box'])})
    elif d=='Bass Trap':
        b=it['box']
        for w in ('S','E' if b[0]>100 else 'W'):
            walls[w]['fixed'].append({'kind':'trap','name':it['name'],'rect':rect(w,b)})
    elif d.startswith('IEP BEAM') or d=='STDSS CL8':
        for w in 'SN': walls[w]['fixed'].append({'kind':'beam' if 'IEP' in d else 'ceiling seal','name':it['name'] or d,'rect':rect(w,it['box'])})
# observed by ray (ap9-rays.rb), booth-local inches
walls['N']['fixed']+= [{'kind':'window trim','name':'N0i window trim (glass inside)','rect':[7.5,42.5,37.2,76.1]},
                       {'kind':'window trim','name':'N1i window trim (glass inside)','rect':[55.5,90.5,37.2,76.1]},
                       {'kind':'door','name':'N3i door frame + leaf + glass','rect':[121.25,165.75,0.75,80.25]}]
walls['E']['fixed'].append({'kind':'door frame return','name':'N3i frame face (ray: flat to y 93.0, blocked at 93.5)','rect':[93.0,93.75,0.75,80.25]})
walls['W']['fixed'].append({'kind':'window panel return','name':'N0i panel edge (ray: flat to y 92.5 at z>=37.5, 93.0 below)','rect':[92.5,93.75,0.75,80.25]})
meta={'units':'inches, booth-local (booth group transform is a pure translation: +61.89,+11.63,+1.3125 in room coords)',
 'wall_local':'S,N: run = booth x; E,W: run = booth y; z = booth z. From inside facing a wall, S runs right-to-left in x, E runs right-to-left in y (back corner at y 0 is on the right), W runs left-to-right in y, N runs left-to-right in x.',
 'faces_observed':{'S':'4.25 (H-strip 4.313 at z ~40-41.5)','N':'93.75 (window-panel H-strip 93.688 at z ~22.5-23; N2i strip at z ~40)','E':'165.75 (H-strip 165.688 at z ~40-41)','W':'4.25 (H-strip 4.313)'},
 'floor_top':2.75,'ceiling_tile_underside':80.25,
 'usable_run':{'S':[16.38,153.69],'N':[4.25,121.25],'E':[16.38,93.0],'W':[16.38,92.5]},
 'staged_outside':staged,
 'source':'ap9-dump.rb (bounds, Audimute body boxes) + ap9-rays.rb (0.5 in ray grid, foam+AP hidden) on the live model, 12 Oct 2026'}
json.dump({'meta':meta,'walls':walls},open('C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/ap9-survey.json','w'),indent=1)
for w in 'SNEW': print(w, len(walls[w]['pieces']),'pieces', len(walls[w]['fixed']),'fixed')
print('staged',[s['name'] for s in staged])
