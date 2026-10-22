"""Client-job dimensioned plates: export scenes as plain SketchUp images, flatten onto white, and crop the white
margin away (tight framing), keeping a small even border. Dimension text is enlarged with write_image's
:scale_factor. Portable copy of .forge/builder/holmdel/jobs/plates.py (the UT round-2 driver): same output, but the
repo is found from this file's own location. Usage:
    python render/plates.py --out DIR [--w 2560 --h 1440 --sf 2.0 --nocrop] "04 dimensioned plan" ...
Raw exports -> DIR/raw/<slug>-plain.png ; finished plate -> DIR/<slug>.png. The client jobs pass --sf 1.5."""
import json, os, sys
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
from importlib import import_module  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
br = import_module('sketchup-bridge')


def opt(a, k, d):
    return a[a.index(k) + 1] if k in a else d


def crop_white(im, pad_frac=0.03, thr=246):
    a = np.asarray(im.convert('RGB'))
    mask = (a < thr).any(-1)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return im, None
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    pad = int(pad_frac * max(x1 - x0, y1 - y0))
    box = (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad + 1), min(im.height, y1 + pad + 1))
    out = Image.new('RGB', (box[2] - box[0], box[3] - box[1]), (255, 255, 255))
    out.paste(im.crop(box), (0, 0))
    return out, tuple(int(v) for v in box)


def main(a):
    flags = {'--out', '--w', '--h', '--sf'}
    pages = [x for i, x in enumerate(a) if x not in flags | {'--nocrop'} and (i == 0 or a[i - 1] not in flags)]
    out = opt(a, '--out', None)
    if not out:
        sys.exit('plates.py: --out <folder> is required (<WORK>/<client>-renders; see the path table in '
                 'skills/whisperroom-client-job/SKILL.md)')
    out = os.path.abspath(out).replace('\\', '/')
    w, h, sf = int(opt(a, '--w', 2560)), int(opt(a, '--h', 1440)), float(opt(a, '--sf', 2.0))
    os.makedirs(out + '/raw', exist_ok=True)
    for pg in pages:
        slug = pg.replace(' ', '-')
        raw = '%s/raw/%s-plain.png' % (out, slug)
        ruby = ("m = Sketchup.active_model; m.options['PageOptions']['TransitionTime'] = 0.0\n"
                "pg = m.pages[%s]; raise 'no page' unless pg\n"
                "m.pages.selected_page = pg\nv = m.active_view; v.camera = pg.camera\n"
                "v.write_image(:filename => %s, :width => %d, :height => %d, :antialias => true, :transparent => false, :scale_factor => %s)")
        r = br.submit(ruby % (json.dumps(pg), json.dumps(raw), w, h, sf), timeout=180, label='hl-plate', write_roots=[out + '/raw'])
        if r.get('status') != 'ok':
            print(json.dumps({'page': pg, 'error': (r.get('error') or {}).get('message')}), flush=True)
            continue
        im = Image.open(raw).convert('RGBA')
        bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg.convert('RGB')
        box = None
        if '--nocrop' not in a:
            im, box = crop_white(im)
        dest = '%s/%s.png' % (out, slug)
        im.save(dest)
        print(json.dumps({'page': pg, 'out': dest, 'size': im.size, 'crop': box}), flush=True)


if __name__ == '__main__':
    main(sys.argv[1:])
