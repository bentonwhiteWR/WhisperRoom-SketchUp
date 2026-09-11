# Reintroduce each bug one at a time, run the suite, restore, report by name.
import subprocess, shutil, sys, os, re
ROOT = r'C:\Users\bento\Documents\Claude\Sketchup'
A = os.path.join(ROOT, 'scripts', 'wr-autoset.rb')
P = os.path.join(ROOT, 'scripts', 'proposal-scenes.rb')
MUT = [
 ('aim_interior set() before perspective= again', A,
  "    cam.perspective = true\n    cam.fov = INTERIOR_FOV\n    cam.set(eye, tgt, Geom::Vector3d.new(0, 0, 1))\n",
  "    cam.set(eye, tgt, Geom::Vector3d.new(0, 0, 1))\n    cam.perspective = true\n    cam.fov = INTERIOR_FOV\n"),
 ('WR_ProposalScenes.aim set() before perspective=', P,
  "      cam.perspective = true\n      cam.fov = (fov.nil? ? 40.0 : fov.to_f)\n      cam.set(eye, centre, up)\n",
  "      cam.set(eye, centre, up)\n      cam.perspective = true\n      cam.fov = (fov.nil? ? 40.0 : fov.to_f)\n"),
 ('interior plane read off the union box again', A,
  "    r = frame_run.to_f if !frame_run.nil? && frame_run.to_f > 0.0\n",
  "    r = nil\n"),
 ('door_run sign dropped (abs)', A,
  "    r = frame_run.to_f if !frame_run.nil? && frame_run.to_f > 0.0\n",
  "    r = frame_run.to_f.abs if !frame_run.nil?\n"),
 ('aim_plate stops handing the anchor to aim_interior', A,
  "(door_az || FALLBACK_AZ), half, anchor) if p[:inside]",
  "(door_az || FALLBACK_AZ), half, nil) if p[:inside]"),
]
for name, path, old, new in MUT:
    src = open(path, encoding='utf-8').read()
    assert src.count(old) == 1, (name, src.count(old))
    bak = src
    open(path, 'w', encoding='utf-8').write(src.replace(old, new))
    try:
        out = subprocess.run([sys.executable, os.path.join(ROOT, 'scripts', 'rbtest-autoset.py')],
                             capture_output=True, text=True).stdout
    finally:
        open(path, 'w', encoding='utf-8').write(bak)
    fails = re.findall(r'^\s+(\w+) FAIL.*$', out, re.M)
    print('%-52s -> %s' % (name, ', '.join(f + ' FAIL' for f in fails) or 'SURVIVED (no check failed)'))
