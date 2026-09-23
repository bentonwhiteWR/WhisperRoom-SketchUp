"""Contact sheet of the 800 px V-Ray tests, one tile per distinct scene camera, labelled with scene names.
Contains photo-derived imagery (window backdrops), so it goes to the gitignored compare/ folder."""
import os, json
from PIL import Image, ImageDraw, ImageFont
T = 'Z:/Sketchup/ClientDrawings/Community Music School - renders/tests/'
ROWS = [('01-angled', 'AUTO-SET 01-angled r  (+ image plate 01-angled)'), ('02-front', 'AUTO-SET 02-front r  (+ 02-front)'),
        ('03-high', 'AUTO-SET 03-high r  (+ 03-high)'), ('04-side', 'AUTO-SET 04-side r  (+ 04-side)'),
        ('05-ventilation', 'AUTO-SET 05-ventilation r  (+ 05-ventilation)'), ('06-plan', 'AUTO-SET 06-plan r  (+ 06-plan)'),
        ('07-interior', 'AUTO-SET 07-interior'), ('L01-exterior', 'legacy 01-exterior'), ('L02-dimensioned', 'legacy 02-dimensioned'),
        ('L03-side', 'legacy 03-side'), ('L04-ventilation', 'legacy 04-ventilation'), ('L05-plan', 'legacy 05-plan'),
        ('PA-photo-A', 'Photo A - long view'), ('PB-photo-B', 'Photo B - corner view')]
try:
    font = ImageFont.truetype('arial.ttf', 22)
except Exception:
    font = ImageFont.load_default()
W, H, B, cols = 800, 600, 36, 3
rows = (len(ROWS) + cols - 1) // cols
sheet = Image.new('RGB', (cols * W, rows * (H + B)), (30, 30, 30))
d = ImageDraw.Draw(sheet)
stats = {}
for i, (k, label) in enumerate(ROWS):
    x, y = (i % cols) * W, (i // cols) * (H + B)
    f = T + 'c-' + k + '-final.png'
    if os.path.exists(f):
        sheet.paste(Image.open(f).convert('RGB').resize((W, H)), (x, y + B))
    else:
        d.text((x + 20, y + B + 280), 'NO FRAME', fill=(255, 80, 80), font=font)
    try:
        jp = T + 'c-' + k + '-r2.json'
        j = json.load(open(jp if os.path.exists(jp) else T + 'c-' + k + '.json'))
        fin = json.loads(j['finish'])
        stats[k] = (fin['mean_lum'], fin['clipped'], fin['dark_frac'])
    except Exception as e:
        stats[k] = str(e)[:40]
    s = stats[k]
    txt = label + ('   mean %.2f clip %.3f dark %.3f' % s if isinstance(s, tuple) else '   ' + s)
    d.text((x + 8, y + 6), txt, fill='white', font=font)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'compare', 'scene-contact-sheet.png')
sheet.save(out)
print(os.path.abspath(out))
print(json.dumps(stats))
