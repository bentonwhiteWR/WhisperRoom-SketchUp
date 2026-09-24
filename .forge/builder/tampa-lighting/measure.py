"""Mean sRGB of named patches in a hero render (800x450). Patches are fixed pixel boxes on the hero frame."""
import sys, json
import numpy as np
from PIL import Image
P = {'front_face': (410, 130, 490, 290), 'left_face': (140, 90, 220, 200), 'ceiling': (300, 5, 500, 20),
     'floor': (300, 380, 500, 440), 'right_wall': (700, 150, 780, 250), 'door_leaf': (590, 110, 605, 250)}
for f in sys.argv[1:]:
    a = np.asarray(Image.open(f).convert('RGB')).astype(float)
    out = {}
    for k, (x0, y0, x1, y1) in P.items():
        m = a[y0:y1, x0:x1].reshape(-1, 3).mean(0)
        out[k] = [int(v) for v in m] + [round(m[2] / max(m[0], 1), 2)]
    print(f.split('/')[-1], json.dumps(out))
