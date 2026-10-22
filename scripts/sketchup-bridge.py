# -*- coding: utf-8 -*-
"""SUBMIT a Ruby job to a running SketchUp and read back what it did.

    python sketchup-bridge.py ping
    python sketchup-bridge.py eval "Sketchup.active_model.entities.length"
    python sketchup-bridge.py run  scripts/probe-vray.rb  [--timeout 120]
    python sketchup-bridge.py shot out.png [--width 1600]
    python sketchup-bridge.py enable | disable | status
    python sketchup-bridge.py log [--lines 40]

    common flags:  --su 2024|2026   --timeout N   --label "..."
                   --model PATH|FRAGMENT|pid:N   (which open file; see below)
                   --modal allow    --no-suppress  --write-root DIR
                   --json           --quiet

WHAT THIS IS FOR

SketchUp has no command line. Every check on a tool that needs a live model has
been a human clicking through the Ruby Console. scripts/rbtest-*.py covers the
PURE half of the Ruby logic outside SketchUp; this is the impure complement --
it runs the job INSIDE the running application and hands back stdout, the return
value, and any exception with its backtrace. The resident half is
scripts/wr_tools/wr_bridge.rb; read its header for the protocol.

It also exports submit(), so a future rbtest-live-*.py asserts against results
directly instead of parsing this program's printing:

    from importlib import import_module
    br = import_module('sketchup-bridge')
    r = br.submit('Sketchup.active_model.entities.length')
    assert r['status'] == 'ok' and r['value'] > 0

THE ONE THING THIS PROGRAM MUST NEVER DO IS HANG, and the second is report a
half-written result as an answer.

For the hang: the listener CANNOT time a job out. SketchUp's Ruby is
single-threaded, so once the job is running nothing else in SketchUp runs,
including the timer that would have to cancel it. Every timeout here is
enforced on this side, and a timeout is diagnosed rather than merely reported --
see diagnose() for the three facts it reads and the four verdicts it gives them.
None of them is exit 0.

For the half-written result: the listener writes <id>.result.tmp and renames it
into place, and `complete` is the LAST key in the file. A truncated file fails
JSON parse. A file that parses but has no `complete` is corrupt, and is reported
as corrupt -- never as a result. On either, this program re-reads a few times
before giving up, because the rename makes a genuine tear near-impossible and
the likelier cause of one bad read is an antivirus or a search indexer holding
the file open for a moment.

EXIT CODES -- they are the point of the tool, so they are specific:

    0  the job ran and returned
    1  the job RAISED (an ordinary result, not a bridge fault)
    2  usage error
    3  nothing is listening -- SketchUp closed, or the bridge not enabled
    4  the job started and SketchUp stopped answering (a modal, most likely)
    5  the job is still running, and the timeout was too short
    6  a safety fence refused the job before any of its code ran
    7  a result file was there but could not be read as a result

TWO FILES OPEN AT ONCE (1.85.0). Each SketchUp process listens in its own
slot, <root>/inst-<pid>/, and publishes the file it has open. `ping` lists them.
--model picks one: a full path, or a fragment of the file name, title or path
that matches exactly one open file, or pid:N. With ONE window open, --model is
not needed and nothing changes. With two or more and no --model, the job is
REFUSED (exit 6, no job code runs) and the open files are listed. A --model
that matches none, or more than one, is refused the same way. The environment
variable WR_BRIDGE_MODEL sets the default --model, so a session driving one
file can set it once and every submit() (render/, rbtest-live-*) follows it.
The job carries the model it was resolved against, and the listener refuses it
(reason wrong-model) if the window opened another file in the meantime.

An OLDER listener (pre-1.85, one shared in/ and no slots) is still driven for
the one-window case: with no live slot the job goes to the shared in/ exactly as
before. --model cannot be honoured by an old listener and is refused there;
reinstall the plugin and restart SketchUp.

VERSION SELECTION. 2024 and 2026 are both installed here and each gets its own
bridge root, so they cannot race for the same job. When both are listening this
defaults to 2026 (Benton, 30 Aug 2026); --su picks the other. When only one is
listening, that one is used whatever it is.
"""
import json
import os
import re
import shutil
import sys
import time

# BOTH streams. Backtraces and fence refusals go to stderr, and those carry the
# em-dashes and quoted paths this repo writes; on a cp1252 console they came
# back as replacement characters the first time round.
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

POLL_S = 0.1
FRESH_S = 3.0            # a heartbeat older than this is stale
CORRUPT_RETRIES = 5
DEFAULT_TIMEOUT = 60
PREFERRED = '2026'       # when both are listening

EXIT_OK, EXIT_RAISED, EXIT_USAGE = 0, 1, 2
EXIT_NOT_LISTENING, EXIT_BLOCKED, EXIT_RUNNING = 3, 4, 5
EXIT_REFUSED, EXIT_CORRUPT = 6, 7


# --------------------------------------------------------------- the root --

def bridge_base():
    """The parent of the per-version roots, or None when overridden wholesale."""
    if os.environ.get('WR_BRIDGE_DIR'):
        return None
    return os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WhisperRoom', 'bridge')


def root_for(version):
    """WR_BRIDGE_DIR wins outright -- both sides read it, so an override has to
    override for both or the two halves would watch different directories."""
    env = os.environ.get('WR_BRIDGE_DIR')
    if env:
        return env
    return os.path.join(bridge_base(), 'SketchUp %s' % version)


def installed_versions():
    """Every SketchUp in Program Files, newest first, as bare years.

    BOTH LAYOUTS ARE CHECKED, and that is not defensiveness -- the two versions
    on this machine really do differ (observed 30 Aug 2026). 2024 puts
    SketchUp.exe straight in `SketchUp 2024\\`; 2026 nests it one deeper in
    `SketchUp 2026\\SketchUp\\`. Checking only the nested form silently found
    2026 alone, which is the sort of miss that reads as "2024 is not installed"
    rather than as a bug in the finder.
    """
    out = []
    for base in (os.environ.get('ProgramFiles', ''),
                 os.environ.get('ProgramFiles(x86)', '')):
        d = os.path.join(base, 'SketchUp')
        if os.path.isdir(d):
            for e in os.listdir(d):
                if not e.startswith('SketchUp 20'):
                    continue
                if (os.path.isfile(os.path.join(d, e, 'SketchUp.exe')) or
                        os.path.isfile(os.path.join(d, e, 'SketchUp', 'SketchUp.exe'))):
                    out.append(e.split()[-1])
    return sorted(set(out), reverse=True)


def exe_for(version):
    """The SketchUp.exe for a version, or None. Both layouts, as above."""
    for base in (os.environ.get('ProgramFiles', ''),
                 os.environ.get('ProgramFiles(x86)', '')):
        d = os.path.join(base, 'SketchUp', 'SketchUp %s' % version)
        for cand in (os.path.join(d, 'SketchUp.exe'),
                     os.path.join(d, 'SketchUp', 'SketchUp.exe')):
            if os.path.isfile(cand):
                return cand
    return None


def known_versions():
    """Versions worth looking at: installed, plus any that already have a root."""
    vs = set(installed_versions())
    base = bridge_base()
    if base and os.path.isdir(base):
        for e in os.listdir(base):
            if e.startswith('SketchUp 20'):
                vs.add(e.split()[-1])
    return sorted(vs, reverse=True)


def file_age(path):
    try:
        return time.time() - os.path.getmtime(path)
    except OSError:
        return None


def legacy_age(version):
    """Heartbeat age of a PRE-1.85 listener (root/alive), or None. A 1.85
    listener writes its heartbeat into its slot instead, so a fresh root/alive
    means an old plugin is running."""
    return file_age(os.path.join(root_for(version), 'alive'))


# ----------------------------------------------------------------- slots --
#
# A slot's heartbeat goes stale whenever its SketchUp is busy -- the listener
# cannot tick while a job, a render or a native operation holds the
# interpreter. So a stale heartbeat does NOT mean the window is gone, and
# treating it as gone would let a second job slip past the "two windows open"
# refusal onto the other window. Liveness is asked of Windows instead: is that
# pid still a running SketchUp.exe.

SLOT_PREFIX = 'inst-'
OPEN_STATES = ('listening', 'busy', 'stalled')
GONE_SWEEP_S = 60        # ping removes a gone slot silent at least this long


def _pid_image(pid):
    """(running, image_path) for a pid on Windows; (None, None) when unknown.

    NEVER os.kill(pid, 0) HERE: on Windows that calls TerminateProcess and
    would kill the SketchUp it was meant to ask about."""
    if os.name != 'nt':
        return None, None
    try:
        import ctypes
        from ctypes import wintypes
        k32 = ctypes.WinDLL('kernel32', use_last_error=True)
        k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        k32.OpenProcess.restype = wintypes.HANDLE
        k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        k32.QueryFullProcessImageNameW.argtypes = [
            wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
        k32.CloseHandle.argtypes = [wintypes.HANDLE]
        h = k32.OpenProcess(0x1000, False, int(pid))   # QUERY_LIMITED_INFORMATION
        if not h:
            # 87 ERROR_INVALID_PARAMETER: no such pid. Anything else (access
            # denied) means it exists but we may not look.
            return (False, None) if ctypes.get_last_error() == 87 else (None, None)
        try:
            code = wintypes.DWORD()
            if not k32.GetExitCodeProcess(h, ctypes.byref(code)):
                return None, None
            if code.value != 259:                       # STILL_ACTIVE
                return False, None
            buf = ctypes.create_unicode_buffer(1024)
            n = wintypes.DWORD(1024)
            if k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n)):
                return True, buf.value
            return True, None
        finally:
            k32.CloseHandle(h)
    except Exception:
        return None, None


def pid_is_sketchup(pid):
    """True: a running SketchUp. False: gone, or the pid now belongs to some
    other program. None: Windows would not say."""
    running, image = _pid_image(pid)
    if running is not True:
        return running
    if image is None:
        return True
    return 'sketchup' in os.path.basename(image).lower()


def read_card(slot_dir):
    """The slot's model.json, or {} while it is missing or mid-replace."""
    try:
        with open(os.path.join(slot_dir, 'model.json'), 'r', encoding='utf-8') as fh:
            got = json.load(fh)
        return got if isinstance(got, dict) else {}
    except (OSError, ValueError):
        return {}


def slot_info(slot_dir, pid_check=None):
    """One slot as a dict: name, dir, pid, age, state, title, path, guid, card.

    state is listening (fresh heartbeat), busy (stale, a job is running),
    stalled (stale, the pid is still a SketchUp), stopped (bridge switched off
    in that window) or gone (the process has exited)."""
    pid_check = pid_check or pid_is_sketchup
    name = os.path.basename(slot_dir)
    pid = int(name[len(SLOT_PREFIX):])
    age = file_age(os.path.join(slot_dir, 'alive'))
    card = read_card(slot_dir)
    try:
        running = any(f.endswith('.running')
                      for f in os.listdir(os.path.join(slot_dir, 'run')))
    except OSError:
        running = False
    if age is not None and age < FRESH_S:
        state = 'listening'
    elif os.path.isfile(os.path.join(slot_dir, 'stopped')):
        state = 'stopped'
    else:
        alive = pid_check(pid)
        if alive is True:
            state = 'busy' if running else 'stalled'
        elif alive is None and running:
            state = 'busy'          # Windows would not say; trust the marker
        else:
            state = 'gone'
    return {'name': name, 'dir': slot_dir, 'pid': pid, 'age': age, 'state': state,
            'title': str(card.get('title', '')), 'path': str(card.get('path', '')),
            'guid': str(card.get('guid', '')), 'card': card}


def slots(version, pid_check=None):
    """Every slot under a version root, open or not, sorted by pid."""
    root = root_for(version)
    try:
        names = os.listdir(root)
    except OSError:
        return []
    out = []
    for n in names:
        d = os.path.join(root, n)
        if re.match(r'^inst-\d+$', n) and os.path.isdir(d):
            out.append(slot_info(d, pid_check))
    return sorted(out, key=lambda s: s['pid'])


def open_slots(version, pid_check=None):
    return [s for s in slots(version, pid_check) if s['state'] in OPEN_STATES]


def heartbeat_age(version):
    """Seconds since ANY listener of this version last ticked, or None."""
    ages = [a for a in [legacy_age(version)] + [s['age'] for s in slots(version)]
            if a is not None]
    return min(ages) if ages else None


def version_live(version, pid_check=None):
    """An open slot, or a fresh pre-1.85 heartbeat."""
    if open_slots(version, pid_check):
        return True
    age = legacy_age(version)
    return age is not None and age < FRESH_S


def is_enabled(version):
    return os.path.isfile(os.path.join(root_for(version), 'enabled'))


def survey():
    """[(version, enabled, heartbeat_age_or_None)] for everything we know of."""
    return [(v, is_enabled(v), heartbeat_age(v)) for v in known_versions()]


def sweep_gone(version, pid_check=None):
    """Remove slots whose process Windows says has EXITED and that have been
    silent GONE_SWEEP_S. Only a definite answer deletes; 'unknown' keeps the
    slot. Returns the names removed."""
    pid_check = pid_check or pid_is_sketchup
    gone = []
    for s in slots(version, pid_check):
        if s['state'] != 'gone' or (s['age'] is not None and s['age'] < GONE_SWEEP_S):
            continue
        if pid_check(s['pid']) is not False:
            continue
        try:
            shutil.rmtree(s['dir'])
            gone.append(s['name'])
        except OSError:
            pass
    return gone


def describe_slot(s):
    return '    pid %-6d  %-9s  %-30s  %s' % (
        s['pid'], s['state'], s['title'] or '(no model reported yet)',
        s['path'] or '(untitled / unsaved)')


def _np(p):
    return str(p).replace('\\', '/').strip().lower()


def match_slots(cands, query):
    """The slots `query` names, by tier: pid:N; an exact path; a whole file
    name (with or without .skp) or title; then any fragment of path or title.
    Returns the first tier that hits -- the caller insists on exactly one."""
    q = str(query).strip()
    m = re.match(r'(?i)^pid:(\d+)$', q)
    if m:
        return [s for s in cands if s['pid'] == int(m.group(1))]
    qn = _np(q)
    if not qn:
        return []
    paths = {qn}
    if '/' in q or '\\' in q:
        paths.add(_np(os.path.abspath(q)))

    def whole(s):
        base = os.path.basename(s['path'].replace('\\', '/'))
        names = {_np(base), _np(os.path.splitext(base)[0]), _np(s['title'])}
        return qn in (names - {''})

    tiers = (
        lambda s: bool(s['path']) and _np(s['path']) in paths,
        whole,
        lambda s: qn in _np(s['path']) or qn in _np(s['title']),
    )
    for t in tiers:
        hit = [s for s in cands if t(s)]
        if hit:
            return hit
    return []


def target_of(s):
    """What the job carries so the listener can re-check its active model."""
    if not s['card']:
        return None
    return {'pid': s['pid'], 'title': s['title'], 'path': s['path'], 'guid': s['guid']}


def pick_version(wanted):
    """Which SketchUp to talk to, and why -- returns (version, note).

    NO SILENT FALLBACK (GOAL rule): when nothing is listening this still returns
    a version, but the note says plainly that nothing answered there, and the
    caller turns that into exit 3 naming the directory it watched.
    """
    if wanted:
        return wanted, 'you asked for %s' % wanted

    if os.environ.get('WR_BRIDGE_DIR'):
        return 'override', 'WR_BRIDGE_DIR is set'

    live = [v for v in known_versions() if version_live(v)]
    if len(live) == 1:
        return live[0], 'the only SketchUp listening'
    if len(live) > 1:
        if PREFERRED in live:
            return PREFERRED, ('%s are both listening; %s is the default '
                               '(--su picks the other)'
                               % (' and '.join(sorted(live)), PREFERRED))
        return sorted(live)[-1], 'newest of the listening: %s' % ', '.join(sorted(live))

    vs = known_versions()
    if PREFERRED in vs:
        return PREFERRED, 'nothing is listening; assuming the default'
    return (vs[0] if vs else PREFERRED), 'nothing is listening; assuming the newest installed'


# ------------------------------------------------------------ submitting --

def new_id():
    return '%s-%d-%02d' % (time.strftime('%Y%m%d-%H%M%S'), os.getpid(),
                           int(time.time() * 100) % 100)


def read_result(path):
    """The result, or a string naming why this read is not one.

    THIS IS THE HALF-WRITTEN-RESULT GUARD and it is the most load-bearing
    function here. A truncated file raises out of json.loads. A file that parses
    but lacks the terminal `complete` key was caught mid-write by something that
    is not the rename, and is NOT a result -- returning it would be the silent
    poisoning of every test built on this bridge.
    """
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            raw = fh.read()
    except OSError as exc:
        return 'could not be read (%s)' % exc
    if not raw.strip():
        return 'was empty'
    try:
        got = json.loads(raw)
    except ValueError as exc:
        return 'did not parse as JSON (%s)' % exc
    if not isinstance(got, dict):
        return 'was JSON but not an object'
    if got.get('complete') is not True:
        return ('parsed but has no terminal "complete" key, so it was read '
                'mid-write and is not a result')
    return got


def diagnose(root, jid, timeout_s, label):
    """Why no result arrived. Returns (exit_code, message).

    Three observable facts: is there a result after all, is <id>.running there,
    and is the heartbeat fresh. Read in that order, because the listener deletes
    .running BEFORE it writes the result -- so reading the result first closes
    the millisecond window where neither file exists.

    ON THE HEARTBEAT, AND WHAT A10 SETTLED. The listener cannot tick while a job
    is running: single-threaded, no preemption. So for ANY job that outlives
    FRESH_S the heartbeat is stale, and stale-vs-fresh cannot on its own separate
    "wedged" from "still working" -- unless a modal dialog runs a nested Windows
    message loop that keeps SketchUp's timers firing. Whether it does is the one
    thing the spec could not settle without SketchUp running. A10 settled it live;
    MODAL_KEEPS_TIMERS below records what was actually observed, and this function
    reads it rather than a guess.
    """
    late = os.path.join(root, 'out', '%s.result.json' % jid)
    if os.path.isfile(late):
        got = read_result(late)
        if isinstance(got, dict):
            return None, got                      # it landed on the last read

    running = os.path.isfile(os.path.join(root, 'run', '%s.running' % jid))
    try:
        age = time.time() - os.path.getmtime(os.path.join(root, 'alive'))
    except OSError:
        age = None
    fresh = age is not None and age < FRESH_S

    where = ('    watched  %s\n' % root)

    if not running and not fresh:
        return EXIT_NOT_LISTENING, (
            'SKETCHUP IS NOT LISTENING. Nothing claimed the job and the bridge '
            'heartbeat is %s.\n%s'
            '    The bridge is OFF BY DEFAULT. Three things to check, in order:\n'
            '      1. SketchUp is running.\n'
            '      2. It is the version this watched (--su 2024 / --su 2026).\n'
            '      3. The bridge is enabled:  python scripts/sketchup-bridge.py enable\n'
            '         then RESTART SketchUp -- nothing polls for the marker, so a\n'
            '         marker created while SketchUp is already up does not take\n'
            '         effect until it next starts. Or, without a restart:\n'
            '         Extensions > WhisperRoom > Bridge: enable.'
            % ('%.1f s old' % age if age is not None else 'absent', where))

    if not running and fresh:
        return EXIT_NOT_LISTENING, (
            'BRIDGE FAULT: the listener is alive (heartbeat %.1f s old) but never '
            'claimed the job.\n%s'
            '    The job file was  %s\n'
            '    That should be impossible -- the listener globs in/*.job.json '
            'four times a second. Check bridge.log:\n'
            '      python scripts/sketchup-bridge.py log'
            % (age, where, os.path.join(root, 'in', '%s.job.json' % jid)))

    wedged = fresh if MODAL_KEEPS_TIMERS else (not fresh)

    if running and wedged:
        return EXIT_BLOCKED, (
            'THE JOB STARTED AND SKETCHUP STOPPED ANSWERING after %g s.\n%s'
            '    job     %s\n'
            '    marker  %s\n'
            '    heartbeat %s\n'
            '    The likely cause is A MODAL DIALOG or a file picker sitting open '
            'and waiting for a click -- one the bridge could not intercept '
            '(UI::HtmlDialog#show_modal, a V-Ray dialog, or a native modal), or a '
            'long native operation that blocks Ruby.\n'
            '    Look at SketchUp. If a dialog is up, answering it lets the job '
            'finish; its late result lands harmlessly and no later run can pick it '
            'up, because every run has a new id.'
            % (timeout_s, where, label or '(unlabelled)',
               os.path.join(root, 'run', '%s.running' % jid),
               ('%.1f s old' % age if age is not None else 'absent')))

    return EXIT_RUNNING, (
        'THE JOB IS STILL RUNNING after its %g s timeout.\n%s'
        '    job     %s\n'
        '    heartbeat %s\n'
        '    Nothing is wrong; the timeout was too short. Re-run with a longer '
        '--timeout. The job you submitted is still going and will write its '
        'result when it finishes -- a later run cannot mistake it for its own.'
        % (timeout_s, where, label or '(unlabelled)',
           ('%.1f s old' % age if age is not None else 'absent')))


class NotListening(Exception):
    """Raised by submit() for anything that is not a job result. `code` is the
    exit code the CLI would have used; `message` is what it would have printed."""

    def __init__(self, code, message):
        Exception.__init__(self, message)
        self.code = code
        self.message = message


def resolve(version=None, model=None, pid_check=None):
    """Where a job goes: (box_dir, target_or_None, slot_or_None, version).

    Raises NotListening(EXIT_REFUSED) when the target is ambiguous or names no
    open file -- before anything is written, so no job code can run -- and
    NotListening(EXIT_NOT_LISTENING) when --model has nothing to match against.
    """
    if model:
        if version:
            versions = [version]
        elif os.environ.get('WR_BRIDGE_DIR'):
            versions = ['override']
        else:
            versions = known_versions()
        cands = []
        for v in versions:
            cands += [dict(s, version=v) for s in open_slots(v, pid_check)]
        if not cands:
            old = [v for v in versions
                   if legacy_age(v) is not None and legacy_age(v) < FRESH_S]
            if old:
                raise NotListening(EXIT_REFUSED, (
                    'REFUSED -- no job code ran. --model %r was given, but the SketchUp '
                    'listening (%s) runs a bridge older than 1.85.0, which cannot say '
                    'which file it has open, so the job could not be guaranteed to land '
                    'on that file.\n    Reinstall (python scripts/install-plugin.py) and '
                    'restart SketchUp, or drop --model if only one window is open.'
                    % (model, ', '.join(old))))
            raise NotListening(EXIT_NOT_LISTENING, (
                'SKETCHUP IS NOT LISTENING, so there is no open file for --model %r '
                'to match.\n    python scripts/sketchup-bridge.py ping   shows what '
                'the bridge can see.' % model))
        hit = match_slots(cands, model)
        if len(hit) == 1:
            s = hit[0]
            return s['dir'], target_of(s), s, s['version']
        if not hit:
            raise NotListening(EXIT_REFUSED, (
                'REFUSED -- no job code ran. --model %r matches none of the open '
                'files:\n%s\n    Pass a full path, a fragment unique to one file, or '
                'pid:N.' % (model, '\n'.join(describe_slot(s) for s in cands))))
        raise NotListening(EXIT_REFUSED, (
            'REFUSED -- no job code ran. --model %r matches %d open files:\n%s\n'
            '    Pass a full path, a fragment unique to one file, or pid:N.'
            % (model, len(hit), '\n'.join(describe_slot(s) for s in hit))))

    version, _why = pick_version(version)
    open_ = open_slots(version, pid_check)
    if len(open_) == 1:
        s = open_[0]
        return s['dir'], target_of(s), s, version
    if len(open_) > 1:
        raise NotListening(EXIT_REFUSED, (
            'REFUSED -- no job code ran. %d SketchUp windows are open (%s) and the '
            'job names no model, so it could land on the wrong file:\n%s\n'
            '    Pass --model <path, file-name fragment, or pid:N>, or set '
            'WR_BRIDGE_MODEL.'
            % (len(open_), version, '\n'.join(describe_slot(s) for s in open_))))
    # No slot: an older listener on the shared inbox, or nothing yet. Exactly
    # the pre-1.85 behaviour -- submit and let diagnose() explain a timeout.
    return root_for(version), None, None, version


def submit(ruby, timeout=DEFAULT_TIMEOUT, version=None, label=None,
           modal='raise', suppress_autorun=True, write_roots=None, model=None):
    """Run `ruby` inside SketchUp and return its result dict.

    `model` picks the open file (a path, a fragment unique to one file, or
    pid:N) and defaults to $WR_BRIDGE_MODEL. With one window open it can be
    left out. An ambiguous or unmatched target raises
    NotListening(EXIT_REFUSED) before any job file is written.

    Raises NotListening (carrying the CLI exit code) for every outcome that is
    not a job result: nothing listening, wedged, still running, corrupt. A job
    that RAISED is an ordinary return -- status 'error' with a populated
    'error' -- because a raise is a result, and the caller asserting on status
    is exactly the discipline this bridge exists to make possible.
    """
    if model is None:
        model = os.environ.get('WR_BRIDGE_MODEL') or None
    # `root` from here on is the job's BOX: a slot, or the shared inbox of an
    # older listener. Every path below, diagnose() included, is relative to it.
    root, target, _slot, version = resolve(version, model)
    jid = new_id()

    for sub in ('in', 'run', 'out'):
        try:
            os.makedirs(os.path.join(root, sub), exist_ok=True)
        except OSError:
            pass

    job = {
        'id': jid,
        'created': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'label': label or '',
        'ruby': ruby,
        'timeout_s': timeout,
        'suppress_autorun': bool(suppress_autorun),
        'modal': modal,
        'write_roots': list(write_roots or []),
    }
    if target:
        job['target'] = target

    # WRITE TO .tmp AND RENAME, so the listener can never glob a half-written
    # job. os.replace is atomic within a directory on NTFS. Same trick the
    # listener uses for the result, for the same reason, in the other direction.
    tmp = os.path.join(root, 'in', '%s.job.tmp' % jid)
    with open(tmp, 'w', encoding='utf-8') as fh:
        json.dump(job, fh)
    os.replace(tmp, os.path.join(root, 'in', '%s.job.json' % jid))

    out = os.path.join(root, 'out', '%s.result.json' % jid)
    deadline = time.time() + timeout
    while time.time() < deadline:
        if os.path.isfile(out):
            for attempt in range(CORRUPT_RETRIES):
                got = read_result(out)
                if isinstance(got, dict):
                    return got
                time.sleep(POLL_S)
            raise NotListening(EXIT_CORRUPT,
                               'THE RESULT FILE COULD NOT BE READ AS A RESULT after '
                               '%d tries.\n    %s\n    It %s.\n'
                               '    This is reported rather than guessed at on purpose: a '
                               'half-written result read as a complete one would poison '
                               'every test built on this bridge.'
                               % (CORRUPT_RETRIES, out, got))
        time.sleep(POLL_S)

    code, payload = diagnose(root, jid, timeout, label)
    if code is None:
        return payload
    raise NotListening(code, payload)


# --------------------------------------------------- what A10 settled ------
#
# OBSERVED LIVE, 30 Aug 2026, SketchUp 2026 (26.2.243). THE SPEC GUESSED THIS
# THE OTHER WAY ROUND, and the guess would have made every long job report as a
# wedge.
#
# UI.start_timer KEEPS FIRING while a native modal dialog is up. With
# UI.messagebox('block me') open and waiting, the heartbeat was sampled once a
# second for eleven seconds and never aged past 0.08 s. A modal on Windows runs
# a nested message loop, and SketchUp's timers ride it.
#
# So the two cases separate cleanly, but in the INVERSE of the spec's table:
#
#   .running present + heartbeat FRESH -> Ruby is blocked while the message
#       loop still runs. That is a modal. Exit 4.   (measured: 0.2 s)
#   .running present + heartbeat STALE -> the timer cannot fire because the
#       job itself is occupying the interpreter. That is an ordinary long job
#       whose timeout was too short. Exit 5.        (measured: 4.9 s)
#
# Both directions were run: the modal gave exit 4, and a deliberate 20 s busy
# loop under a 5 s timeout gave exit 5. Had this come out the other way the two
# cases would have been indistinguishable from outside and the spec's named
# fallback -- the .running file's own age against timeout_s -- would have been
# the only signal, and a weaker one, since it cannot tell them apart either.
#
# This is a recorded measurement, not a preference. diagnose() is only as right
# as this line, so re-run A10 before changing it.
MODAL_KEEPS_TIMERS = True


# -------------------------------------------------------------- printing --

def show(res, quiet=False):
    """Print a result the way a human reads it, and return the exit code."""
    status = res.get('status')

    if not quiet and res.get('stdout'):
        sys.stdout.write(res['stdout'])
        if not res['stdout'].endswith('\n'):
            sys.stdout.write('\n')
    if res.get('stderr'):
        sys.stderr.write(res['stderr'])
        if not res['stderr'].endswith('\n'):
            sys.stderr.write('\n')

    if status == 'ok':
        if not quiet:
            print('-> %s   (%s, %.3fs)'
                  % (res.get('value_repr', ''), res.get('value_class', '?'),
                     res.get('elapsed_s', 0)))
            for a in res.get('artifacts', []):
                print('   wrote %s' % a)
        return EXIT_OK

    err = res.get('error') or {}
    if status == 'refused':
        # A fence stopped it BEFORE any job code ran. The empty stdout above is
        # part of the evidence, and it is worth saying so out loud.
        print('REFUSED (%s) -- no job code ran.' % res.get('reason', '?'), file=sys.stderr)
        print(err.get('message', ''), file=sys.stderr)
        return EXIT_REFUSED

    print('%s: %s' % (err.get('class', 'Error'), err.get('message', '')), file=sys.stderr)
    for line in err.get('backtrace', []):
        print('    %s' % line, file=sys.stderr)
    cause = err.get('cause')
    while cause:
        print('  caused by %s: %s' % (cause.get('class'), cause.get('message')),
              file=sys.stderr)
        cause = cause.get('cause')
    return EXIT_RAISED


# -------------------------------------------------------------- commands --

def cmd_ping(opts):
    rows = survey()
    if not rows:
        print('No SketchUp found in Program Files and no bridge root yet.')
        return EXIT_NOT_LISTENING

    live = 0
    for (v, enabled, _age) in rows:
        swept = sweep_gone(v)
        all_ = slots(v)
        open_ = [s for s in all_ if s['state'] in OPEN_STATES]
        lage = legacy_age(v)
        old = lage is not None and lage < FRESH_S
        if open_:
            state = '%d window%s open' % (len(open_), '' if len(open_) == 1 else 's')
        elif old:
            state = 'LISTENING, pre-1.85 listener (heartbeat %.1fs)' % lage
        elif all_ or lage is not None:
            state = 'silent'
        else:
            state = 'never started'
        if open_ or old:
            live += 1
        print('  SketchUp %-6s  marker:%-8s  %s' % (v, 'on' if enabled else 'OFF', state))
        print('                  %s' % root_for(v))
        for s in all_:
            beat = ('heartbeat %.1fs' % s['age']) if s['age'] is not None else 'no heartbeat'
            print('%s   %s' % (describe_slot(s), beat))
        if open_ and old:
            print('    ALSO a pre-1.85 listener (heartbeat %.1fs): a SketchUp started before '
                  'the plugin was updated. Restart it; it still serves the old shared '
                  'inbox only.' % lage)
        for n in swept:
            print('    swept %s (its SketchUp has exited)' % n)

    if live:
        v, why = pick_version(opts.get('su'))
        print('')
        print('A job with no --su goes to SketchUp %s (%s).' % (v, why))
        try:
            _box, _t, s, _v = resolve(opts.get('su'), opts.get('model') or
                                      os.environ.get('WR_BRIDGE_MODEL') or None)
            if s:
                print('A job%s would run in pid %d: %s' % (
                    ' with --model %s' % opts['model'] if opts.get('model') else '',
                    s['pid'], s['path'] or s['title'] or '(untitled)'))
        except NotListening as exc:
            print(exc.message.replace('REFUSED -- no job code ran. ', 'A job would be REFUSED: '))
        return EXIT_OK

    print('')
    print('Nothing is listening. The bridge is OFF BY DEFAULT:')
    print('   python scripts/sketchup-bridge.py enable   then RESTART SketchUp,')
    print('   or, with SketchUp already up, Extensions > WhisperRoom > Bridge: enable.')
    return EXIT_NOT_LISTENING


def cmd_enable(opts, on):
    v, why = pick_version(opts.get('su'))
    root = root_for(v)
    for sub in ('in', 'run', 'out', 'art'):
        os.makedirs(os.path.join(root, sub), exist_ok=True)
    marker = os.path.join(root, 'enabled')
    if on:
        with open(marker, 'w', encoding='utf-8') as fh:
            fh.write(time.strftime('%Y-%m-%dT%H:%M:%S'))
        print('marker written  %s' % marker)
        age = heartbeat_age(v)
        if age is not None and age < FRESH_S:
            print('SketchUp %s is already listening. Nothing further to do.' % v)
        else:
            # SAY IT RATHER THAN LEAVE IT TO BE WONDERED AT. The listener reads
            # the marker at LOAD, so nothing polls for it appearing.
            print('RESTART SketchUp %s for this to take effect -- nothing polls for'
                  ' the marker.' % v)
            print('Or, without a restart: Extensions > WhisperRoom > Bridge: enable.')
    else:
        if os.path.isfile(marker):
            os.remove(marker)
            print('marker removed  %s' % marker)
            print('The listener re-reads the marker every tick, so it stops within'
                  ' a second. No restart needed.')
        else:
            print('already disabled  %s' % root)
    return EXIT_OK


def cmd_log(opts):
    v, _why = pick_version(opts.get('su'))
    p = os.path.join(root_for(v), 'bridge.log')
    if not os.path.isfile(p):
        print('no log yet at %s' % p)
        return EXIT_NOT_LISTENING
    n = int(opts.get('lines') or 40)
    with open(p, 'r', encoding='utf-8', errors='replace') as fh:
        lines = fh.readlines()
    sys.stdout.write(''.join(lines[-n:]))
    return EXIT_OK


SHOT_RUBY = """\
load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')
WRB.shot(%s, %d)
"""


def usage(msg=None):
    if msg:
        print('sketchup-bridge: %s' % msg, file=sys.stderr)
        print('', file=sys.stderr)
    print(__doc__.strip(), file=sys.stderr)
    return EXIT_USAGE


def main(argv):
    args, opts = [], {}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--json':
            opts['json'] = True
        elif a == '--quiet':
            opts['quiet'] = True
        elif a == '--no-suppress':
            opts['no_suppress'] = True
        elif a.startswith('--'):
            key = a[2:].replace('-', '_')
            i += 1
            if i >= len(argv):
                return usage('%s needs a value' % a)
            if key == 'write_root':
                opts.setdefault('write_roots', []).append(argv[i])
            else:
                opts[key] = argv[i]
        else:
            args.append(a)
        i += 1

    if not args:
        return usage()
    cmd, rest = args[0], args[1:]

    if cmd == 'ping' or cmd == 'status':
        return cmd_ping(opts)
    if cmd == 'enable':
        return cmd_enable(opts, True)
    if cmd == 'disable':
        return cmd_enable(opts, False)
    if cmd == 'log':
        return cmd_log(opts)

    if cmd == 'eval':
        if len(rest) != 1:
            return usage('eval takes exactly one Ruby string')
        ruby, label = rest[0], opts.get('label') or 'eval'
    elif cmd == 'run':
        if len(rest) != 1:
            return usage('run takes exactly one .rb path')
        path = rest[0]
        if not os.path.isfile(path):
            return usage('no such file: %s' % path)
        # THE WIRE FORMAT ALWAYS CARRIES THE SOURCE, never a path for the far
        # side to read. A result is then reproducible from the job file alone,
        # and the two halves cannot disagree about which version of a file ran.
        with open(path, 'r', encoding='utf-8', errors='replace') as fh:
            ruby = fh.read()
        label = opts.get('label') or os.path.basename(path)
    elif cmd == 'shot':
        if len(rest) != 1:
            return usage('shot takes exactly one output .png path')
        out = os.path.abspath(rest[0])
        ruby = SHOT_RUBY % (json.dumps(out.replace('\\', '/')),
                            int(opts.get('width') or 1600))
        label = 'shot'
        opts.setdefault('write_roots', []).append(os.path.dirname(out))
    else:
        return usage('unknown command: %s' % cmd)

    timeout = float(opts.get('timeout') or DEFAULT_TIMEOUT)
    modal = opts.get('modal') or 'raise'
    if modal not in ('raise', 'allow'):
        return usage('--modal takes raise or allow')
    if modal == 'allow' and timeout < 10:
        # modal:"allow" means a human is expected to answer a dialog. Pairing
        # that with a short timeout guarantees a misleading exit 4.
        return usage('--modal allow needs --timeout 10 or more; somebody has to '
                     'have time to answer the dialog')

    try:
        res = submit(ruby, timeout=timeout, version=opts.get('su'), label=label,
                     modal=modal, suppress_autorun=not opts.get('no_suppress'),
                     write_roots=opts.get('write_roots'), model=opts.get('model'))
    except NotListening as exc:
        print(exc.message, file=sys.stderr)
        return exc.code

    if opts.get('json'):
        print(json.dumps(res, indent=2))
        return {'ok': EXIT_OK, 'error': EXIT_RAISED,
                'refused': EXIT_REFUSED}.get(res.get('status'), EXIT_CORRUPT)

    return show(res, quiet=opts.get('quiet'))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
