import sys, importlib, glob, os, json, numpy as np
from PIL import Image
sys.path.insert(0, r"C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts")
iq = importlib.import_module("image-qa")
def meas(path):
    m = iq.measure(path)
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    L = 0.2126*a[...,0] + 0.7152*a[...,1] + 0.0722*a[...,2]
    h, w = L.shape
    s = a/255.0
    lin = np.where(s <= 0.04045, s/12.92, ((s+0.055)/1.055)**2.4)
    Ll = 0.2126*lin[...,0] + 0.7152*lin[...,1] + 0.0722*lin[...,2]
    return dict(mean=m['mean_luminance'], clip=m['clipped_fraction'], med=round(float(np.median(L)),2),
                ff=round(float(L[int(.30*h):int(.70*h), int(.32*w):int(.60*w)].mean() / L[int(.85*h):, :].mean()),4),
                rb=round(float(a[...,0].mean()/a[...,2].mean()),4), ceil_rb=round(float(a[:int(.10*h),:,0].mean()/a[:int(.10*h),:,2].mean()),4),
                nb=round(float(((L > 180) & (abs(a[...,0]-a[...,2]) < 8)).mean()),4), dark=round(float((L<32).mean()),4),
                linmean=round(float(lin.mean()),5), linmed=round(float(np.median(Ll)),5), size=a.shape[:2])
for d in sys.argv[1:]:
    fs = glob.glob(os.path.join(d, "*01-angled r.png"))
    for f in fs: print(os.path.basename(d), json.dumps(meas(f)))
    if not fs: print(os.path.basename(d), "NO RENDER FILE", os.listdir(d) if os.path.isdir(d) else 'no dir')
