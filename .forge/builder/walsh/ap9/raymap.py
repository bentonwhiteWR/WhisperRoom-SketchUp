import json
from PIL import Image, ImageDraw
d=json.load(open('rays.json'))
NOM={'S':4.38,'N':93.75,'W':4.38,'E':165.69}
SGN={'S':1,'N':-1,'W':1,'E':-1}
S=4  # px per sample (0.5 in)
for w,v in d['walls'].items():
    rows=v['rows']; nz=len(rows); nr=len(rows[0])
    im=Image.new('RGB',(nr*S,nz*S),'white'); dr=ImageDraw.Draw(im)
    for i,row in enumerate(rows):
        for j,(nc,nm) in enumerate(row):
            if nc is None: c=(0,0,0)
            else:
                p=(nc-NOM[w])*SGN[w]
                if nm=='Bass Trap': c=(150,80,200)
                elif nm.startswith('WR Duct'): c=(240,150,40)
                elif p< -5: c=(80,200,255)    # through glass
                elif nm.startswith('IEP'): c=(200,0,0)
                elif nm.startswith('SL52') or nm.startswith('STDSS'): c=(255,230,0)
                elif p>0.5: c=(255,60,60)
                elif p>0.03: c=(255,170,170)
                elif p>-0.03: c=(200,200,200)
                elif p>-0.1: c=(170,170,170)
                elif p>-0.2: c=(140,140,140)
                elif p>-0.5: c=(110,110,110)
                else: c=(60,60,60)
            y=(nz-1-i)*S
            dr.rectangle([j*S,y,j*S+S-1,y+S-1],fill=c)
    # grid every 12 in
    for k in range(0,nr,24): dr.line([(k*S,0),(k*S,nz*S)],fill=(0,120,0))
    for k in range(0,nz,24): dr.line([(0,(nz-1-k)*S),(nr*S,(nz-1-k)*S)],fill=(0,120,0))
    im.save(f'raymap_{w}.png')
    print(w, im.size, 'run0',v['r0'],'z0',v['z0'])
