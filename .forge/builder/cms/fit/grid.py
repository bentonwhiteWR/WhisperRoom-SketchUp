import sys
from PIL import Image, ImageDraw, ImageFont
P='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
S='C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/3e3afa98-6775-4f3d-8c84-5a7779910ab6/scratchpad/cms/'
def crop(photo, x0,y0,x1,y1, out, step=50, maxw=1400):
    im=Image.open(P+photo).convert('RGB').crop((x0,y0,x1,y1))
    sc=min(1.0, maxw/float(x1-x0), 1800/float(y1-y0)) if (x1-x0)>maxw or (y1-y0)>1800 else min(maxw/float(x1-x0), 1800/float(y1-y0), 3.0)
    im=im.resize((int((x1-x0)*sc), int((y1-y0)*sc)), Image.LANCZOS)
    d=ImageDraw.Draw(im)
    try: f=ImageFont.truetype('arial.ttf', 14)
    except: f=None
    for gx in range((x0//step+1)*step, x1, step):
        X=(gx-x0)*sc; big = gx%(step*4)==0
        d.line([(X,0),(X,im.size[1])], fill=(255,0,0) if big else (255,160,160), width=1)
        if big: d.text((X+2,2), str(gx), fill=(255,0,0), font=f)
    for gy in range((y0//step+1)*step, y1, step):
        Y=(gy-y0)*sc; big = gy%(step*4)==0
        d.line([(0,Y),(im.size[0],Y)], fill=(0,0,255) if big else (160,160,255), width=1)
        if big: d.text((2,Y+2), str(gy), fill=(0,0,255), font=f)
    im.save(S+out)
if __name__=='__main__':
    a=sys.argv
    crop(a[1], int(a[2]),int(a[3]),int(a[4]),int(a[5]), a[6], int(a[7]) if len(a)>7 else 50)
