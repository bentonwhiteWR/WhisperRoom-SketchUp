"""Opaque-black share of a test frame: alpha from <base>-alpha.png, luminance from <base>-final.png
(display-encoded). Prints JSON: opaque, transparent, opaque_black(<0.03), opaque_black(<0.06)."""
import sys, json, numpy as np
from PIL import Image
base = sys.argv[1]
a = np.asarray(Image.open(base + '-alpha.png').convert('RGBA')).astype(float) / 255
f = np.asarray(Image.open(base + '-final.png').convert('RGB')).astype(float) / 255
alpha = a[..., 3]
lum = 0.2126 * f[..., 0] + 0.7152 * f[..., 1] + 0.0722 * f[..., 2]
op = alpha > 0.5
print(json.dumps({'opaque': round(float(op.mean()), 3), 'transparent': round(float((alpha < 0.05).mean()), 3),
                  'opaque_black_03': round(float((op & (lum < 0.03)).mean()), 3),
                  'opaque_black_06': round(float((op & (lum < 0.06)).mean()), 3), 'mean_lum_opaque': round(float(lum[op].mean()), 3)}))
