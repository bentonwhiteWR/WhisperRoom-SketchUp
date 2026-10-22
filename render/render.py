"""Client-job V-Ray frames through the bridge (WR_CMSRender, render/vray-render.rb), never blocking a job.
Portable copy of .forge/builder/holmdel/jobs/render.py (the UT round-2 driver): same settings, same output,
but the repo is found from this file's own location and the output folder is an argument.
Raw (linear) V-Ray output -> OUT/raw/<slug>.png, the sRGB-encoded PNG -> OUT/<slug>.png, where <slug> is the
scene name with spaces as '-'. Prints one JSON line per scene with exposure stats.
    python render/render.py --out "<WORK>/<client>-renders" [--w 1600 --h 900 --min 2.0 --thr 0.03 --ev 16.7 --wbk 4000] "01 hero" ...
<WORK> is resolved per person by the table in skills/whisperroom-client-job/SKILL.md; --out is required."""
import json, os, sys, time
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
from importlib import import_module  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
br = import_module('sketchup-bridge')
RB = os.path.join(REPO, 'render', 'vray-render.rb').replace('\\', '/')
LIGHTS = os.path.join(REPO, 'scripts', 'wr-drop-lights.rb').replace('\\', '/')


def opt(a, k, d):
    return a[a.index(k) + 1] if k in a else d


def main(a):
    flags = {'--w', '--h', '--min', '--thr', '--ev', '--out', '--wbk'}
    out = opt(a, '--out', None)
    if not out:
        sys.exit('render.py: --out <folder> is required (<WORK>/<client>-renders; see the path table in '
                 'skills/whisperroom-client-job/SKILL.md)')
    OUT = os.path.abspath(out).replace('\\', '/')
    pages = [x for i, x in enumerate(a) if x not in flags and (i == 0 or a[i - 1] not in flags)]
    w, h = int(opt(a, '--w', 1600)), int(opt(a, '--h', 900))
    os.makedirs(OUT + '/raw', exist_ok=True)
    r = br.submit("load '%s'\nR = WR_CMSRender\n[R.settings!(%d, %d, %s, %s), R.ev!(%s)]" %
                  (RB, w, h, opt(a, '--min', 2.0), opt(a, '--thr', 0.03), opt(a, '--ev', 16.7)), timeout=60, label='hl-rt-set')
    print(json.dumps({'settings': r.get('value'), 'err': r.get('error')}), flush=True)
    if '--wbk' in a:
        k = opt(a, '--wbk', '6500')
        rgb = "WR_DropLights.kelvin_rgb(%s)" % k if k != 'none' else "[1.0, 1.0, 1.0]"
        # WR_DropLights is defined once its script has loaded (any lights! run does it). In a fresh SketchUp
        # session it may not be: load it module-only ($wr_no_autorun keeps its dialog from opening).
        rb = ("unless defined?(WR_DropLights)\n"
              "  prev = $wr_no_autorun; $wr_no_autorun = true\n"
              "  begin; load '%s'; ensure; $wr_no_autorun = prev; end\n"
              "end\n"
              "sc = VRay::Context.active.scene\n"
              "rgb = %s\n"
              "mx = rgb.max.to_f\n"
              "sc.change { sc['/CameraPhysical'][:white_balance] = VRay::Color.new(rgb[0] / mx, rgb[1] / mx, rgb[2] / mx) }\n"
              "sc['/CameraPhysical'][:white_balance].to_s") % (LIGHTS, rgb)
        r = br.submit(rb, timeout=60, label='hl-rt-wb')
        print(json.dumps({'white_balance': r.get('value'), 'err': r.get('error')}), flush=True)
    for pg in pages:
        r = br.submit('WR_CMSRender.aim!(%s); WR_CMSRender.start!' % json.dumps(pg), timeout=60, label='hl-rt-start')
        if r.get('status') != 'ok':
            print(json.dumps({'page': pg, 'error': r.get('error')}), flush=True)
            continue
        t0 = time.time()
        while True:
            time.sleep(6)
            p = br.submit('WR_CMSRender.poll', timeout=45, label='hl-rt-poll')
            v = p.get('value') or {}
            if v.get('done') or time.time() - t0 > 900:
                break
        slug = pg.replace(' ', '-')
        raw = '%s/raw/%s.png' % (OUT, slug)
        s = br.submit('WR_CMSRender.save!(%s)' % json.dumps(raw), timeout=180, label='hl-rt-save', write_roots=[OUT + '/raw'])
        lin = np.asarray(Image.open(raw).convert('RGB')).astype(float) / 255
        srgb = np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
        Image.fromarray((np.clip(srgb, 0, 1) * 255).astype('uint8')).save('%s/%s.png' % (OUT, slug))
        L = srgb.mean(-1)
        print(json.dumps({'page': pg, 'render_s': (s.get('value') or {}).get('render_s'), 'mean': round(float(L.mean()), 3),
                          'clipped': round(float((srgb.max(-1) >= 0.999).mean()), 4), 'dark': round(float((L < 0.05).mean()), 4),
                          'out': '%s/%s.png' % (OUT, slug)}), flush=True)


if __name__ == '__main__':
    main(sys.argv[1:])
