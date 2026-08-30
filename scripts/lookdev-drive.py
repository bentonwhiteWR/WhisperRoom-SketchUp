# -*- coding: utf-8 -*-
"""COMPOSE and RUN the look-development matrix, then assemble its results.

    python lookdev-drive.py capture          # snapshot the model first
    python lookdev-drive.py stage1
    python lookdev-drive.py stage2
    python lookdev-drive.py stage3 --rig ARM_ID
    python lookdev-drive.py restore          # put the model back
    python lookdev-drive.py assemble         # build lookdev-results.json

WHY THE MATRIX LIVES HERE AND NOT IN RUBY
-----------------------------------------
scripts/lookdev-matrix.rb knows how to render ONE frame and how to put the
model back. It holds no matrix of its own on purpose: composing the sweep,
chunking it into bridge jobs, running image-qa over the output and joining the
two halves is all work that is easier to get right — and far easier to change
between stages — outside SketchUp.

THE STAGES NARROW. Stage 1 sweeps the environment on one fixed exterior
camera. Stage 2 carries stage 1's best-scoring arm and sweeps the room-versus-
booth light balance on BOTH cameras, because the whole question is whether one
exposure can serve both. Stage 3 carries a balanced rig and walks an EV ladder
on both cameras, against the as-found rig as a control, so "does a single EV
work now" is answered by comparison rather than assertion.

"BEST-SCORING" IS A MECHANICAL CRITERION, NOT A LOOK VERDICT. Where a later
stage has to carry one arm forward, it is chosen by scripts/image-qa.py's own
numbers and the choice is recorded in the results file. Nobody here is picking
the look; Benton picks the look from the contact sheet.

CHUNKING. Each bridge job runs at most CHUNK frames so that no single job
outlives its timeout, and so a failure costs one chunk rather than a stage.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT_DIR = r'C:\Users\bento\Desktop\BridgeTest-lookdev'
JSONL = os.path.join(OUT_DIR, '_frames.jsonl')
RESULTS = os.path.join(REPO, '.forge', 'builder', 'lookdev-results.json')
MATRIX_RB = os.path.join(HERE, 'lookdev-matrix.rb').replace('\\', '/')

SUNAIM_RB = os.path.join(HERE, 'wr-sun-aim.rb').replace('\\', '/')


def prelude():
    """Load the sun tool and the harness into the job, dialog suppressed.

    $wr_no_autorun stops wr-sun-aim.rb running its UI on load. Without it the
    load itself puts a modal in front of a batch render that nothing on this
    side can answer -- the exact failure that cost this pass two restarts."""
    return ('$wr_no_autorun = true\nload %s\nload %s\n'
            % (rb(SUNAIM_RB), rb(MATRIX_RB)))


W, H = 400, 225

# ONE FRAME PER BRIDGE JOB. This is not a tuning knob -- it is a correctness
# requirement, and it was found the expensive way.
#
# OBSERVED 30 Aug 2026, twice, across two different sweeps: within a single
# Ruby job only the FIRST VRay::Command.render_production actually renders.
# The second and every later call return normally and the renderer never
# leaves idle, so the frame is "finished" instantly and save_vfb_image writes
# out the PREVIOUS frame's pixels. Eight arms of a sun sweep came back as
# eight byte-identical files with eight identical QA scores. Nothing raised.
#
# The renderer evidently needs Ruby to return to SketchUp's message loop
# before it will start another production render, which is almost certainly
# the real reason proposal-package.rb drives its renders from a UI timer
# rather than a loop. A bridge job per frame gets the same effect for a
# fraction of the machinery: the job ends, control goes back to SketchUp, and
# the next job starts clean. The overhead is well under a second against
# frames that take seconds.
CHUNK = 1

# A THUMBNAIL SWEEP NEEDS A TIME BUDGET, in minutes.
#
# MEASURED THE HARD WAY, 30 Aug 2026. The first attempt at stage 1 carried no
# budget, because Benton's Medium quality leaves progressive_maxTime at 0.0 --
# which is not "fast", it is NO LIMIT. One frame ran past fifteen minutes and
# the sweep had to be abandoned. 0.25 min = 15 s is a ceiling, not a target:
# an easy frame still finishes in seconds, and a hard one comes out noisy
# instead of never. The budget is recorded on every frame.
MAX_MINUTES = 0.25

EXT_CAM = '01 Booth Exterior Three-Quarter'
INT_CAM = '02 Booth Interior'

# Stage 1 is exposed at a FIXED EV so its arms are comparable to each other.
# EV 12 is pass 2's OBSERVED room/exterior value -- the exposure Benton judged
# best for this camera -- not a number chosen here.
STAGE1_EV = 12.0

# Sun times, chosen BY MEASURED ELEVATION rather than by the clock.
#
# The model sits at Boulder CO (lat 40.02, TZOffset -7) while Time.parse uses
# this machine's local zone, so a wall-clock hour here is NOT the solar hour --
# which is exactly why these were picked off a live scan of SketchUp's own
# SunDirection rather than reasoned about. Elevation is re-measured and
# recorded on every frame; these strings are the inputs, never the claim.
#
#   current  2026-11-08 08:30  elev ~28 deg   Benton's own setting today
#   low      2026-11-08 11:00  elev ~8 deg    the hard raking sun, prime suspect
#   mid      2026-03-21 11:00  elev ~34 deg
#   high     2026-06-21 08:00  elev ~73 deg   the highest this location reaches
SUN_CURRENT = '2026-11-08 08:30:00'
SUN_LOW = '2026-11-08 11:00:00'
SUN_MID = '2026-03-21 11:00:00'
SUN_HIGH = '2026-06-21 08:00:00'


# ------------------------------------------------------------- ruby literal --

def rb(o):
    """A Python value as a Ruby literal. Only the types the specs use."""
    if o is None:
        return 'nil'
    if o is True:
        return 'true'
    if o is False:
        return 'false'
    if isinstance(o, (int, float)):
        return repr(o)
    if isinstance(o, str):
        return '"' + o.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(o, list):
        return '[' + ','.join(rb(x) for x in o) + ']'
    if isinstance(o, dict):
        return '{' + ','.join('%s=>%s' % (rb(k), rb(v)) for k, v in o.items()) + '}'
    raise TypeError('cannot render %r as Ruby' % (o,))


def submit(body, timeout=900, label='lookdev'):
    """Run a Ruby job through the bridge. Raises on anything but exit 0."""
    import tempfile
    fd, path = tempfile.mkstemp(suffix='.rb', prefix='lookdev-')
    os.close(fd)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(body)
    try:
        cmd = [sys.executable, os.path.join(HERE, 'sketchup-bridge.py'), 'run',
               path, '--su', '2026', '--timeout', str(timeout), '--label', label]
        p = subprocess.run(cmd, capture_output=True, text=True,
                           encoding='utf-8', errors='replace')
        sys.stdout.write(p.stdout or '')
        if p.returncode != 0:
            sys.stderr.write(p.stderr or '')
            raise SystemExit('bridge exit %d on %s' % (p.returncode, label))
        return p.stdout
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def run_specs(specs, label):
    """Submit specs in chunks so no one job outlives its timeout."""
    for i in range(0, len(specs), CHUNK):
        part = specs[i:i + CHUNK]
        body = (prelude() +
                'raise "no snapshot - run capture first" if WR_LookDev.snapshot.nil?\n' +
                'WR_LookDev.run!(%s).inspect\n' % rb(part))
        print('--- %s chunk %d/%d (%d frames) ---'
              % (label, i // CHUNK + 1, (len(specs) + CHUNK - 1) // CHUNK, len(part)))
        submit(body, timeout=900, label='%s-%d' % (label, i // CHUNK + 1))


# ----------------------------------------------------------------- stages --

def stage1_specs():
    """The environment and the sun, on one fixed exterior camera.

    Driven through scripts/wr-sun-aim.rb ("Light It From Here"), which already
    solves for a sun ELEVATION and already keeps the deliberate azimuth offset
    that stops every visible face being lit square-on. The arms are:

      sun-off        sky only, the sun disabled outright
      matchcam       match_cam TRUE -- the CONTROL, i.e. what the renders do
                     today. On a level camera this lands on ELEV_MIN = 8 deg,
                     which is the hard raking sun the DEVLOG complains about.
      elev15/35/60/85  explicit elevations, match_cam FALSE
      off-30 / off+60  the azimuth offset itself swept at a fixed elevation,
                     because the offset is the control that makes a panel read
                     as a solid and it deserves a row of its own

    Requested AND achieved elevation are recorded per frame: clamp_elev floors
    at 8 and ceilings at 85, and solve_elevation bisects to a tolerance, so the
    two can differ and the picture belongs to the achieved one."""
    base = {'w': W, 'h': H, 'max_minutes': MAX_MINUTES, 'ev': STAGE1_EV,
            'timeout_s': 120,
            'lights': {'room': 1.0, 'booth': 1.0, 'standard': 1.0},
            'sun_multiplier': 1.0, 'sky_multiplier': 1.0}
    OFF = 30.0
    arms = [
        ('sun-off',    {'sun_enabled': False}),
        ('matchcam',   {'sun_enabled': True,
                        'sun_aim': {'match_cam': True, 'offset_deg': OFF}}),
        ('elev15',     {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 15.0, 'offset_deg': OFF}}),
        ('elev35',     {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 35.0, 'offset_deg': OFF}}),
        ('elev60',     {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 60.0, 'offset_deg': OFF}}),
        ('elev85',     {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 85.0, 'offset_deg': OFF}}),
        ('elev35-offneg30', {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 35.0, 'offset_deg': -30.0}}),
        ('elev35-off60', {'sun_enabled': True,
                        'sun_aim': {'match_cam': False, 'elev_deg': 35.0, 'offset_deg': 60.0}}),
    ]
    out = []
    for name, over in arms:
        s = dict(base)
        s.update(over)
        sa = s.get('sun_aim') or {}
        out.append({
            'id': 'S1_%s' % name,
            'stage': 1,
            'camera': EXT_CAM,
            'file': 'S1_env-%s_ext.png' % name,
            'vars': {'stage': 'environment', 'env': name,
                     'sun_enabled': s.get('sun_enabled'),
                     'match_cam': sa.get('match_cam'),
                     'elev_requested': sa.get('elev_deg'),
                     'offset_deg': sa.get('offset_deg'),
                     'ev': STAGE1_EV, 'camera': 'exterior'},
            'set': s,
        })
    return out


# The room-versus-booth balance sweep. Each arm is a multiplier on the
# intensity the rig was FOUND at, so every number here is a ratio against
# Benton's own rig rather than an invented absolute.
STAGE2_ARMS = [
    ('asfound',        1.0,    1.0,  1.0),
    ('room050',        0.5,    1.0,  1.0),
    ('room025',        0.25,   1.0,  1.0),
    ('room0125',       0.125,  1.0,  1.0),
    ('room00625',      0.0625, 1.0,  1.0),
    ('boothonly',      0.0,    1.0,  0.0),
    ('lightsoff',      0.0,    0.0,  0.0),
    ('booth4x',        1.0,    4.0,  1.0),
    ('booth8x',        1.0,    8.0,  1.0),
    ('booth16x',       1.0,   16.0,  1.0),
    ('room050booth4x', 0.5,    4.0,  1.0),
    ('room025booth8x', 0.25,   8.0,  1.0),
    ('stdoff',         1.0,    1.0,  0.0),
]


def stage2_specs(env_set):
    """Carry stage 1's arm, sweep the light balance on BOTH cameras.

    Both cameras every time, because the question this stage exists to settle
    is whether ONE exposure can serve an interior and a room view. A balance
    that only ever gets looked at from outside cannot answer it."""
    out = []
    for name, room, booth, std in STAGE2_ARMS:
        for cam, tag in ((EXT_CAM, 'ext'), (INT_CAM, 'int')):
            s = dict(env_set)
            s.update({'w': W, 'h': H, 'max_minutes': MAX_MINUTES,
                      'ev': STAGE1_EV, 'timeout_s': 150,
                      # WITHOUT THIS THE WHOLE STAGE IS A NULL EXPERIMENT.
                      # The "WR Lights" tag was found hidden, which excludes
                      # every light from the export -- the first run of this
                      # stage swept the rig from as-found down to all-off and
                      # got images identical to four decimal places.
                      'tags': {'WR Lights': True},
                      'lights': {'room': room, 'booth': booth, 'standard': std}})
            out.append({
                'id': 'S2_%s_%s' % (name, tag),
                'stage': 2,
                'camera': cam,
                'file': 'S2_rig-%s_room%.4f-booth%.2f-std%.2f_%s.png'
                        % (name, room, booth, std, tag),
                'vars': {'stage': 'light-balance', 'rig': name,
                         'room_multiplier': room, 'booth_multiplier': booth,
                         'standard_multiplier': std,
                         'ev': STAGE1_EV, 'camera': tag},
                'set': s,
            })
    return out


EV_LADDER = [8.0, 9.5, 11.0, 12.5, 14.0]


def stage3_specs(env_set, rigs):
    """An EV ladder on both cameras, against every rig named.

    rigs is [(label, room, booth, std)]. The as-found rig is always included
    as a CONTROL: without it, "one EV now works" is a claim with nothing to
    compare against."""
    out = []
    for label, room, booth, std in rigs:
        for ev in EV_LADDER:
            for cam, tag in ((EXT_CAM, 'ext'), (INT_CAM, 'int')):
                s = dict(env_set)
                s.update({'w': W, 'h': H, 'max_minutes': MAX_MINUTES,
                          'ev': ev, 'timeout_s': 150,
                          'tags': {'WR Lights': True},
                          'lights': {'room': room, 'booth': booth,
                                     'standard': std}})
                out.append({
                    'id': 'S3_%s_ev%04.1f_%s' % (label, ev, tag),
                    'stage': 3,
                    'camera': cam,
                    'file': 'S3_rig-%s_ev%04.1f_%s.png' % (label, ev, tag),
                    'vars': {'stage': 'exposure', 'rig': label,
                             'room_multiplier': room, 'booth_multiplier': booth,
                             'standard_multiplier': std,
                             'ev': ev, 'camera': tag},
                    'set': s,
                })
    return out


# ------------------------------------------------------------- assembling --

def load_frames():
    """Every frame record the Ruby side wrote, last write per id winning."""
    if not os.path.isfile(JSONL):
        return []
    by_id = {}
    with open(JSONL, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except ValueError:
                continue
            by_id[r.get('id')] = r
    return [by_id[k] for k in sorted(by_id)]


def qa_all(frames):
    """image-qa's own numbers for every frame, joined by path.

    Imported rather than shelled out to, so the thresholds and the profile
    logic are literally the same code the proposal gate uses."""
    sys.path.insert(0, HERE)
    import importlib
    iq = importlib.import_module('image-qa')
    out = {}
    for fr in frames:
        p = fr.get('path')
        if not p:
            continue
        out[fr['id']] = iq.check(fr.get('file', ''), p, 'render')
    return out


def assemble(extra=None):
    frames = load_frames()
    qa = qa_all(frames)
    for fr in frames:
        fr['image_qa'] = qa.get(fr['id'])
    doc = {
        'generated': __import__('datetime').datetime.now().isoformat(timespec='seconds'),
        'thumbnail_size': [W, H],
        'output_dir': OUT_DIR,
        'frame_count': len(frames),
        'frames': frames,
    }
    if extra:
        doc.update(extra)
    os.makedirs(os.path.dirname(RESULTS), exist_ok=True)
    with open(RESULTS, 'w', encoding='utf-8') as f:
        json.dump(doc, f, indent=2)
    print('wrote %s (%d frames)' % (RESULTS, len(frames)))
    return doc


def best_arm(frames, stage, key='env'):
    """The arm image-qa likes best, by distance from mid-grey among PASSes.

    Mechanical and stated as such: this only decides what the NEXT stage
    carries, never what ships."""
    best, score = None, None
    for fr in frames:
        if fr.get('stage') != stage:
            continue
        q = fr.get('image_qa') or {}
        if q.get('status') != 'PASS':
            continue
        d = abs(q.get('mean_luminance', 0) - 0.40)
        if score is None or d < score:
            best, score = fr['vars'].get(key), d
    return best


# ------------------------------------------------------------------ main --

def main(argv):
    cmd = argv[1] if len(argv) > 1 else 'help'

    if cmd == 'capture':
        submit(prelude() + 'WR_LookDev.capture!.length.to_s\n',
               timeout=120, label='lookdev-capture')
        return 0

    if cmd == 'safeframes':
        # Benton asked for Safe Frame ON and left on (30 Aug 2026). It is set
        # here, ONCE, and deliberately NOT restored by restore! -- it is his
        # preference now, not something this sweep borrowed. It is also kept
        # out of every scene.change that writes the render size, because
        # doing both in one transaction silently loses the size (see the
        # comment on apply! in lookdev-matrix.rb).
        on = 'off' not in argv
        submit('load %s\nWR_LookDev.safe_frames!(%s).inspect\n'
               % (rb(MATRIX_RB), 'true' if on else 'false'),
               timeout=120, label='lookdev-safeframes')
        return 0

    if cmd == 'restore':
        submit(prelude() + 'WR_LookDev.restore!\n',
               timeout=180, label='lookdev-restore')
        return 0

    if cmd == 'stage1':
        run_specs(stage1_specs(), 'stage1')
        assemble()
        return 0

    if cmd == 'stage2':
        env = json.loads(argv[argv.index('--env') + 1]) if '--env' in argv else {}
        run_specs(stage2_specs(env), 'stage2')
        assemble()
        return 0

    if cmd == 'stage3':
        env = json.loads(argv[argv.index('--env') + 1]) if '--env' in argv else {}
        rigs = json.loads(argv[argv.index('--rigs') + 1])
        run_specs(stage3_specs(env, [tuple(r) for r in rigs]), 'stage3')
        assemble()
        return 0

    if cmd == 'assemble':
        assemble()
        return 0

    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
