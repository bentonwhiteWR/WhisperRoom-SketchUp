# -*- coding: utf-8 -*-
"""COMPOSE and RUN the SUN-OFF look matrix, and settle the ceiling question.

    python sunoff-drive.py capture     # snapshot the model first, once
    python sunoff-drive.py check       # prove the lights tag before spending a frame
    python sunoff-drive.py stageA      # the rig, sun off, the room as found
    python sunoff-drive.py stageB      # the CEILING axis, and a 3-sided room
    python sunoff-drive.py stageC --rooms '...' --rigs '...'
    python sunoff-drive.py restore     # put the model back
    python sunoff-drive.py assemble    # build sunoff-results.json

WHY THIS EXISTS, WHEN lookdev-drive.py ALREADY DOES A SWEEP
-----------------------------------------------------------
It does, and this reuses its harness (scripts/lookdev-matrix.rb) rather than
forking it -- the Ruby side gained an output-directory setter, a room axis and
a lights-tag assertion, and nothing else changed. What this file adds is the
COMPOSITION, because the questions are different:

  1. EVERY frame in the 68-frame look matrix that contained lights had the SUN
     ON. The one sun-off arm was rendered before the light tag was unhidden, so
     it had no rig in it at all. There is no sun-off-plus-rig frame anywhere in
     that matrix. That is the gap this closes: the booth carried by its own
     fixtures, with no sun.

  2. The host room HAS NO CEILING (observed). It is a four-walled box open to
     the sky, so sky light has been pouring straight down into every frame
     judged so far and doing a large share of the lighting. But a lot of
     WhisperRoom drawings are deliberately 2-3 sided rooms with walls left out
     so the camera can see in, so a full enclosure is not automatically right.
     The enclosure is therefore an AXIS, not an assumption.

THE THIRD CEILING ARM, AND WHAT HAPPENED TO IT
----------------------------------------------
The brief asked for a ceiling that blocks and bounces light without appearing
in frame -- the standard architectural matte trick -- IF V-Ray for SketchUp
supports it. IT DOES NOT, on this build. The V-Ray core mechanism is there
(MtlRenderStats.camera_visibility, reachable through a material's renderStats
userdata slot) but every attempt to write it hung SketchUp hard enough to need
a force-kill; the evidence is in lookdev-matrix.rb beside MATTE_SUPPORTED.
Faking it with a hidden tag would remove the ceiling from the render entirely,
which is precisely the trap that cost this project 68 frames, so it is NOT
faked. The supported stand-in swept instead is 'nosky': the sky is taken to
zero at the environment rather than blocked by geometry. It kills the free
skylight but provides no bounce surface, so 'ceil' and 'nosky' BRACKET the
matte ceiling -- a matte ceiling would have the light of 'ceil' and the
picture of 'open'.

NOBODY HERE PICKS THE WINNER. Every arm is rendered, named after its
variables, measured, and recorded. Benton chooses off the contact sheet.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT_DIR = r'C:\Users\bento\Desktop\BridgeTest-sunoff'
JSONL = os.path.join(OUT_DIR, '_frames.jsonl')
RESULTS = os.path.join(REPO, '.forge', 'builder', 'sunoff-results.json')
MATRIX_RB = os.path.join(HERE, 'lookdev-matrix.rb').replace('\\', '/')
SUNAIM_RB = os.path.join(HERE, 'wr-sun-aim.rb').replace('\\', '/')

W, H = 400, 225
MAX_MINUTES = 0.25          # the harness's own ceiling; Benton's setting is 0.0 = NO LIMIT
CHUNK = 1                   # one frame per bridge job -- see lookdev-drive.py, it is a correctness rule
BASE_EV = 12.0

EXT_CAM = '01 Booth Exterior Three-Quarter'
INT_CAM = '02 Booth Interior'


# ------------------------------------------------------------------ arms --

# THE ENCLOSURE AXIS. 'ceiling' is the harness's room spec; 'sky' is the
# /Environment Sky multiplier, which is the supported stand-in for a matte
# ceiling (see the module docstring).
#
#   id          walls  ceiling  sky   what it asks
#   w4-open       4     none    1.0   the room exactly as found today
#   w4-ceil       4     solid   1.0   the same room, capped
#   w4-nosky      4     none    0.0   open roof, but no sky light at all
#   w3-open       3     none    1.0   Benton's real 3-sided drawing, as found
#   w3-ceil       3     solid   1.0   3-sided but capped
#   w3-nosky      3     none    0.0   3-sided, no sky light
#
# 'sky' IS THE /SettingsEnvironment SLOT MULTIPLIER, NOT TexSky's.
# The first run of this sweep used /Environment Sky[intensity_multiplier] and
# it did NOTHING: the value read back as 0.0 and the twenty 'nosky' frames came
# back identical to their sky-on twins to four decimal places. The knob that
# works is /SettingsEnvironment's bg_/gi_/reflect_/refract_tex_mult, all four
# together. Those twenty frames were re-rendered with the working knob.
ROOMS = [
    ('w4-open',  4, 'none',    1.0),
    ('w4-ceil',  4, 'ceiling', 1.0),
    ('w4-nosky', 4, 'none',    0.0),
    ('w3-open',  3, 'none',    1.0),
    ('w3-ceil',  3, 'ceiling', 1.0),
    ('w3-nosky', 3, 'none',    0.0),
]
ROOM_BY_ID = dict((r[0], r) for r in ROOMS)

# The rig arms, unchanged from the look matrix's stage 2 so the two sweeps are
# comparable frame for frame. Each number is a MULTIPLIER on the intensity the
# rig was found at, never an invented absolute.
#                  id               room    booth   std
RIGS = [
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
RIG_BY_ID = dict((r[0], r) for r in RIGS)

# Stage B carries a SUBSET across the whole enclosure axis. These five span the
# range stage A covers -- the rig as found, the booth fixture alone, and the
# three booth multipliers that the sun-on matrix found viable -- without paying
# for thirteen arms times six rooms.
STAGE_B_RIGS = ['asfound', 'boothonly', 'booth4x', 'booth8x', 'booth16x']

EV_LADDER = [9.5, 11.0, 12.5, 14.0]


# ------------------------------------------------------------- ruby literal --

def rb(o):
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


def prelude():
    """Load the harness, point it at THIS sweep's folder, dialog suppressed."""
    return ('$wr_no_autorun = true\nload %s\nload %s\n'
            'WR_LookDev.out_dir = %s\n'
            % (rb(SUNAIM_RB), rb(MATRIX_RB), rb(OUT_DIR.replace('\\', '/'))))


def submit(body, timeout=900, label='sunoff', fatal=True):
    import tempfile
    fd, path = tempfile.mkstemp(suffix='.rb', prefix='sunoff-')
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
            if fatal:
                raise SystemExit('bridge exit %d on %s' % (p.returncode, label))
            print('!! bridge exit %d on %s -- continuing' % (p.returncode, label))
        return p.stdout
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def run_specs(specs, label):
    """One bridge job per frame. Not a tuning knob -- within a single Ruby job
    only the FIRST render_production actually renders (observed twice, 30 Aug
    2026), so a second frame in the same job silently re-saves the first
    frame's pixels."""
    n = len(specs)
    for i in range(0, n, CHUNK):
        part = specs[i:i + CHUNK]
        body = (prelude() +
                'raise "no snapshot - run capture first" if WR_LookDev.snapshot.nil?\n' +
                'WR_LookDev.run!(%s).inspect\n' % rb(part))
        print('--- %s %d/%d  %s ---' % (label, i // CHUNK + 1, n, part[0]['id']))
        # NOT fatal: one frame that fails is one thumbnail, and losing the rest
        # of a 120-frame sweep to it would be the worse outcome. Failures land
        # in the JSONL and in the results file by name.
        submit(body, timeout=900, label='%s-%d' % (label, i // CHUNK + 1), fatal=False)


# ----------------------------------------------------------------- specs --

def base_set(room_id, rig_id, ev):
    walls, ceiling, sky = ROOM_BY_ID[room_id][1:]
    room_m, booth_m, std_m = RIG_BY_ID[rig_id][1:]
    return {
        'w': W, 'h': H, 'max_minutes': MAX_MINUTES, 'timeout_s': 180,
        'ev': ev,
        # THE POINT OF THE WHOLE SWEEP.
        'sun_enabled': False,
        'sun_multiplier': 1.0,
        # THE WORKING KNOB (see ROOMS). sky_multiplier is deliberately NOT
        # written -- it reads back but does not reach the render.
        'env_mult': sky,
        # WITHOUT THIS EVERY FRAME IS A NULL EXPERIMENT. The tag was found
        # hidden, and a light on a hidden tag never reaches the export.
        'tags': {'WR Lights': True},
        'room': {'walls': walls, 'ceiling': ceiling},
        'lights': {'room': room_m, 'booth': booth_m, 'standard': std_m},
    }


def spec(stage, room_id, rig_id, ev, cam_tag):
    cam = EXT_CAM if cam_tag == 'ext' else INT_CAM
    walls, ceiling, sky = ROOM_BY_ID[room_id][1:]
    room_m, booth_m, std_m = RIG_BY_ID[rig_id][1:]
    fid = 'S%s_%s_%s_ev%04.1f_%s' % (stage, room_id, rig_id, ev, cam_tag)
    return {
        'id': fid,
        'stage': stage,
        'camera': cam,
        # EVERY VARIABLE IN THE FILENAME, so a thumbnail on a contact sheet
        # never has to be traced back through a JSON file to be identified.
        'file': '%s.png' % fid,
        # THE HARNESS REFUSES TO RENDER THIS FRAME IF THE LIGHTS TAG IS HIDDEN.
        'require_lights': True,
        'timeout_s': 180,
        'vars': {
            'stage': {'A': 'rig-sun-off', 'B': 'enclosure', 'C': 'exposure'}[stage],
            'sun_enabled': False,
            'room': room_id, 'walls': walls, 'ceiling': ceiling,
            'env_multiplier': sky,
            'rig': rig_id,
            'room_multiplier': room_m, 'booth_multiplier': booth_m,
            'standard_multiplier': std_m,
            'ev': ev, 'camera': cam_tag,
        },
        'set': base_set(room_id, rig_id, ev),
    }


def stageA_specs():
    """The rig, sun off, in the room exactly as it is today (4 walls, open top).

    This is the frame that does not exist anywhere in the 68: the booth lit by
    its own fixtures with no sun. Both cameras every arm, because the question
    is whether one exposure can serve an interior and a room view."""
    return [spec('A', 'w4-open', rig, BASE_EV, cam)
            for rig, _, _, _ in RIGS for cam in ('ext', 'int')]


def stageB_specs():
    """The enclosure axis. Five rig arms across every room BUT w4-open, which
    stage A already rendered at the same EV -- re-rendering it would only add
    noise, not information."""
    return [spec('B', room, rig, BASE_EV, cam)
            for room, _, _, _ in ROOMS if room != 'w4-open'
            for rig in STAGE_B_RIGS
            for cam in ('ext', 'int')]


def nosky_specs():
    """Only the two no-sky rooms -- the arms the broken knob wasted."""
    return [spec('B', room, rig, BASE_EV, cam)
            for room in ('w4-nosky', 'w3-nosky')
            for rig in STAGE_B_RIGS
            for cam in ('ext', 'int')]


def stageC_specs(rooms, rigs):
    """An exposure ladder on whatever came out of A and B looking viable."""
    return [spec('C', room, rig, ev, cam)
            for room in rooms for rig in rigs
            for ev in EV_LADDER for cam in ('ext', 'int')]


# ------------------------------------------------------------- assembling --

def load_frames():
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
    sys.path.insert(0, HERE)
    import importlib
    iq = importlib.import_module('image-qa')
    out = {}
    for fr in frames:
        p = fr.get('path')
        if not p or not os.path.isfile(p):
            continue
        out[fr['id']] = iq.check(fr.get('file', ''), p, 'render')
    return out


def normalise(frames):
    """One `vars` schema across the whole file, whenever a frame was rendered.

    The stage A and B frames were written before the environment knob was
    corrected, so their vars carry `sky_multiplier` (the knob that did not
    work) instead of `env_multiplier` (the one that does). Their ROOM is
    authoritative either way -- it names the arm -- so the value is rederived
    from ROOM_BY_ID rather than trusted from the old field, and the old field
    is dropped so nothing downstream can read the dead knob by accident.

    A contact sheet built off two different schemas is a contact sheet with
    holes in it, so this is not cosmetic."""
    for fr in frames:
        v = fr.get('vars') or {}
        room = ROOM_BY_ID.get(v.get('room'))
        if room is not None:
            v['env_multiplier'] = room[3]
        v.pop('sky_multiplier', None)
    return frames


def assemble(extra=None):
    frames = normalise(load_frames())
    qa = qa_all(frames)
    for fr in frames:
        fr['image_qa'] = qa.get(fr['id'])

    # THE ASSERTION, ROLLED UP. If any frame reached the disk with the lights
    # tag hidden, the sweep is void and the results file has to say so at the
    # top rather than bury it.
    bad_tag = [f['id'] for f in frames
               if (f.get('measured') or {}).get('tag_wr_lights_visible') is not True]
    thin = [f['id'] for f in frames
            if ((f.get('measured') or {}).get('visible_light_instances') or 0) < 8]
    sun_on = [f['id'] for f in frames
              if (f.get('measured') or {}).get('sun_enabled') is not False]
    # THE ENVIRONMENT KNOB, ASSERTED. A frame that asked for no sky and did
    # not get it is the same class of wasted frame as one rendered with the
    # lights tag hidden, so it is named rather than averaged in.
    # AN ASSERTION THAT SKIPS IS NOT AN ASSERTION. The frames rendered before
    # the environment field existed carry no `measured.env_gi_tex_mult`, so a
    # naive check passes them by saying nothing -- which is how a green tick
    # ends up covering half a sweep. They are listed BY NAME instead.
    #
    # For the record, and it is a derivation rather than a measurement: every
    # unrecorded frame asked for env_multiplier 1.0, which is the as-found
    # value, and the code path those frames ran never wrote
    # /SettingsEnvironment at all. So they were at 1.0 by construction. That
    # is stated here rather than assumed silently.
    env_wrong, env_unrecorded = [], []
    for f in frames:
        want = (f.get('vars') or {}).get('env_multiplier')
        got = (f.get('measured') or {}).get('env_gi_tex_mult')
        if want is None:
            continue
        if got is None:
            env_unrecorded.append(f['id'])
            continue
        if abs(float(got) - float(want)) > 1e-6:
            env_wrong.append(f['id'])

    secs = [f.get('wall_seconds') for f in frames if isinstance(f.get('wall_seconds'), (int, float))]
    doc = {
        'generated': __import__('datetime').datetime.now().isoformat(timespec='seconds'),
        'sweep': 'sun-off + enclosure',
        'thumbnail_size': [W, H],
        'output_dir': OUT_DIR,
        'frame_count': len(frames),
        'assertions': {
            'lights_tag_visible_on_every_frame': not bad_tag,
            'frames_with_tag_hidden': bad_tag,
            'frames_with_fewer_than_8_light_instances': thin,
            'sun_disabled_on_every_frame': not sun_on,
            'frames_with_sun_still_on': sun_on,
            'env_multiplier_landed_on_every_frame': not env_wrong,
            'frames_where_env_multiplier_did_not_land': env_wrong,
            'frames_env_multiplier_measured': len(frames) - len(env_unrecorded),
            'frames_env_multiplier_unrecorded': env_unrecorded,
            'frames_env_multiplier_unrecorded_note':
                'rendered before measured.env_gi_tex_mult existed; all asked '
                'env_multiplier 1.0, which is the as-found value, and their code '
                'path never wrote /SettingsEnvironment - so 1.0 by construction, '
                'derived not measured',
        },
        'timing': {
            'frames_timed': len(secs),
            'total_seconds': round(sum(secs), 2) if secs else None,
            'mean_seconds': round(sum(secs) / len(secs), 2) if secs else None,
            'min_seconds': round(min(secs), 2) if secs else None,
            'max_seconds': round(max(secs), 2) if secs else None,
        },
        'axes': {
            'rooms': [{'id': r[0], 'walls': r[1], 'ceiling': r[2], 'env_multiplier': r[3]}
                      for r in ROOMS],
            'rigs': [{'id': r[0], 'room_multiplier': r[1], 'booth_multiplier': r[2],
                      'standard_multiplier': r[3]} for r in RIGS],
            'ev_ladder': EV_LADDER,
            'base_ev': BASE_EV,
            'cameras': {'ext': EXT_CAM, 'int': INT_CAM},
        },
        'frames': frames,
    }
    if extra:
        doc.update(extra)
    os.makedirs(os.path.dirname(RESULTS), exist_ok=True)
    with open(RESULTS, 'w', encoding='utf-8') as f:
        json.dump(doc, f, indent=2)
    print('wrote %s (%d frames)' % (RESULTS, len(frames)))
    if bad_tag:
        print('!!! %d FRAMES RENDERED WITH THE LIGHTS TAG HIDDEN -- THE SWEEP IS VOID' % len(bad_tag))
    return doc


# ------------------------------------------------------------------ main --

def main(argv):
    cmd = argv[1] if len(argv) > 1 else 'help'
    os.makedirs(OUT_DIR, exist_ok=True)

    if cmd == 'capture':
        submit(prelude() + 'WR_LookDev.capture!.length.to_s\n',
               timeout=180, label='sunoff-capture')
        return 0

    if cmd == 'check':
        # PROVE THE TAG BEFORE SPENDING A SINGLE FRAME. This is the whole
        # lesson of 30 Aug 2026 in one command.
        submit(prelude() +
               'm = Sketchup.active_model\n'
               'ly = m.layers["WR Lights"]\n'
               'was = ly.visible?\n'
               'ly.visible = true\n'
               'n = WR_LookDev.assert_lights_visible!\n'
               '"tag was_visible=#{was} now=#{ly.visible?} visible_light_instances=#{n}"\n',
               timeout=180, label='sunoff-check')
        return 0

    if cmd == 'restore':
        submit(prelude() + 'WR_LookDev.restore!\n', timeout=300, label='sunoff-restore')
        return 0

    if cmd == 'stageA':
        run_specs(stageA_specs(), 'stageA')
        assemble()
        return 0

    if cmd == 'stageB':
        run_specs(stageB_specs(), 'stageB')
        assemble()
        return 0

    if cmd == 'nosky':
        run_specs(nosky_specs(), 'nosky')
        assemble()
        return 0

    if cmd == 'stageC':
        rooms = json.loads(argv[argv.index('--rooms') + 1])
        rigs = json.loads(argv[argv.index('--rigs') + 1])
        run_specs(stageC_specs(rooms, rigs), 'stageC')
        assemble()
        return 0

    if cmd == 'assemble':
        assemble()
        return 0

    if cmd == 'count':
        print('stageA %d  stageB %d' % (len(stageA_specs()), len(stageB_specs())))
        return 0

    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
