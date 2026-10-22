# -*- coding: utf-8 -*-
"""CHECK the bridge's two-files-open addressing without SketchUp running.

    python rbtest-bridge-slots.py

Two halves, both pure:

  CLIENT  sketchup-bridge.py's slot survey, --model matching and resolve(),
          against a fake bridge tree in a temp dir (WR_BRIDGE_DIR), with the
          Windows pid check replaced by a fake so slot states are chosen by the
          test. submit() is driven end to end against a fake listener thread
          for the one-window case, and checked to write NO job file when it
          refuses.

  LISTENER wr_bridge.rb's target_refusal and same_path?, lifted VERBATIM out
          of the file and run in SketchUp's own CRuby 3.2 through rbparse.py,
          with model_hash / live_peers / Process.pid stubbed. That is the guard
          that refuses a job when the window switched files.

What it cannot check: a real SketchUp writing a real slot, Ruby's rename over
an existing model.json, and two real processes. Those are the supervised
two-window procedure in the 1.85.0 HANDOFF.
"""
import json
import os
import re
import shutil
import sys
import tempfile
import threading
import time
from importlib import import_module

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

FAILS = []


def check(cond, what):
    print('  %s  %s' % ('ok  ' if cond else 'FAIL', what))
    if not cond:
        FAILS.append(what)


# ------------------------------------------------------------------ client --

def make_slot(root, pid, title, path, fresh=True, running=False, stopped=False,
              guid='g-%d'):
    d = os.path.join(root, 'inst-%d' % pid)
    for sub in ('in', 'run', 'out'):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    with open(os.path.join(d, 'model.json'), 'w', encoding='utf-8') as fh:
        json.dump({'title': title, 'path': path, 'guid': guid % pid, 'pid': pid}, fh)
    beat = os.path.join(d, 'alive')
    with open(beat, 'w') as fh:
        fh.write('x')
    if not fresh:
        old = time.time() - 600
        os.utime(beat, (old, old))
    if running:
        open(os.path.join(d, 'run', 'j.running'), 'w').close()
    if stopped:
        open(os.path.join(d, 'stopped'), 'w').close()
    return d


def client_tests():
    br = import_module('sketchup-bridge')
    tmp = tempfile.mkdtemp(prefix='wrbridge-test-')
    os.environ['WR_BRIDGE_DIR'] = tmp
    os.environ.pop('WR_BRIDGE_MODEL', None)
    alive_pids = set()
    fake = lambda pid: pid in alive_pids          # noqa: E731

    def reset():
        for n in os.listdir(tmp):
            p = os.path.join(tmp, n)
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
        alive_pids.clear()

    try:
        print('client: slot states')
        reset()
        make_slot(tmp, 101, 'Walsh', r'Z:\Sketchup\ClientDrawings\Walsh Tech Lab.skp')
        make_slot(tmp, 102, 'ISL 7296', r'Z:\Sketchup\ClientDrawings\ISL 7296.skp',
                  fresh=False, running=True)
        make_slot(tmp, 103, 'Old', r'C:\x\Old.skp', fresh=False)
        make_slot(tmp, 104, 'Off', r'C:\x\Off.skp', fresh=False, stopped=True)
        make_slot(tmp, 105, 'Stalled', r'C:\x\Stalled.skp', fresh=False)
        alive_pids.update({102, 104, 105})
        st = {s['pid']: s['state'] for s in br.slots('override', fake)}
        check(st == {101: 'listening', 102: 'busy', 103: 'gone', 104: 'stopped',
                     105: 'stalled'}, 'listening/busy/gone/stopped/stalled read right: %s' % st)
        opn = [s['pid'] for s in br.open_slots('override', fake)]
        check(opn == [101, 102, 105], 'a BUSY window still counts as open (%s)' % opn)

        print('client: --model matching')
        reset()
        make_slot(tmp, 201, 'Walsh Tech Lab', r'Z:\Sketchup\ClientDrawings\Walsh Tech Lab.skp')
        make_slot(tmp, 202, 'Walsh Tech Lab v2', r'Z:\Sketchup\ClientDrawings\Walsh Tech Lab v2.skp')
        make_slot(tmp, 203, 'Untitled', '')
        c = br.open_slots('override', fake)
        pids = lambda q: [s['pid'] for s in br.match_slots(c, q)]  # noqa: E731
        check(pids(r'z:/sketchup/clientdrawings/WALSH TECH LAB.skp') == [201],
              'exact path, case and slash insensitive')
        check(pids('Walsh Tech Lab') == [201], 'whole title beats a fragment that hits both')
        check(pids('Walsh Tech Lab v2.skp') == [202], 'whole file name with .skp')
        check(pids('walsh') == [201, 202], 'an ambiguous fragment returns both')
        check(pids('v2') == [202], 'a unique fragment')
        check(pids('pid:203') == [203], 'pid:N')
        check(pids('untitled') == [203], 'an untitled model by its title')
        check(pids('nothing-like-it') == [], 'no match is empty')

        print('client: resolve()')
        try:
            br.resolve(None, None, fake)
            check(False, 'two+ windows and no --model must refuse')
        except br.NotListening as e:
            check(e.code == br.EXIT_REFUSED and 'Walsh Tech Lab v2' in e.message,
                  'two+ windows, no --model: REFUSED (exit 6) and the files listed')
        for q in ('walsh', 'nope'):
            try:
                br.resolve(None, q, fake)
                check(False, '--model %s must refuse' % q)
            except br.NotListening as e:
                check(e.code == br.EXIT_REFUSED, '--model %r refused (exit 6)' % q)
        box, tgt, s, _v = br.resolve(None, 'v2', fake)
        check(s['pid'] == 202 and box.endswith('inst-202') and
              tgt['path'].endswith('Walsh Tech Lab v2.skp') and tgt['guid'] == 'g-202',
              '--model v2 resolves to pid 202 with its path and guid as the target')

        reset()
        make_slot(tmp, 301, 'Only', r'C:\x\Only.skp')
        make_slot(tmp, 302, 'Dead', r'C:\x\Dead.skp', fresh=False)   # pid not alive
        box, tgt, s, _v = br.resolve(None, None, fake)
        check(s['pid'] == 301 and tgt['path'] == r'C:\x\Only.skp',
              'ONE open window, no --model: goes there (a gone slot is ignored)')

        print('client: back-compat with a pre-1.85 listener')
        reset()
        with open(os.path.join(tmp, 'alive'), 'w') as fh:
            fh.write('x')
        box, tgt, s, _v = br.resolve(None, None, fake)
        check(box == tmp and tgt is None and s is None,
              'no slot + fresh root heartbeat: the shared in/ with no target, as before')
        try:
            br.resolve(None, 'anything', fake)
            check(False, '--model against an old listener must refuse')
        except br.NotListening as e:
            check(e.code == br.EXIT_REFUSED and '1.85.0' in e.message,
                  '--model against an old listener: refused, says to reinstall')

        print('client: submit() end to end against a fake listener')
        reset()
        d = make_slot(tmp, os.getpid(), 'Me', r'C:\x\Me.skp')
        seen = {}
        stop = threading.Event()

        def listener():
            inbox = os.path.join(d, 'in')
            while not stop.is_set():
                for f in os.listdir(inbox):
                    if f.endswith('.job.json'):
                        job = json.load(open(os.path.join(inbox, f), encoding='utf-8'))
                        os.remove(os.path.join(inbox, f))
                        seen.update(job)
                        res = {'id': job['id'], 'status': 'ok', 'value': 42,
                               'value_repr': '42', 'value_class': 'Integer',
                               'stdout': '', 'stderr': '', 'complete': True}
                        out = os.path.join(d, 'out', '%s.result.json' % job['id'])
                        json.dump(res, open(out + '.tmp', 'w'))
                        os.replace(out + '.tmp', out)
                with open(os.path.join(d, 'alive'), 'w') as fh:
                    fh.write('x')
                time.sleep(0.05)

        t = threading.Thread(target=listener, daemon=True)
        t.start()
        try:
            r = br.submit('1 + 1', timeout=10, label='t')
            check(r['value'] == 42 and seen.get('target', {}).get('path') == r'C:\x\Me.skp',
                  'one window: submit() lands in the slot and carries the target')
            os.environ['WR_BRIDGE_MODEL'] = 'nothing-open-by-this-name'
            try:
                br.submit('1 + 1', timeout=2)
                check(False, 'WR_BRIDGE_MODEL that matches nothing must refuse')
            except br.NotListening as e:
                check(e.code == br.EXIT_REFUSED, 'WR_BRIDGE_MODEL is honoured as the default --model')
            os.environ.pop('WR_BRIDGE_MODEL', None)
        finally:
            stop.set()
            t.join(2)

        reset()
        alive_pids.update({401, 402})
        a = make_slot(tmp, 401, 'A', r'C:\x\A.skp')
        b = make_slot(tmp, 402, 'B', r'C:\x\B.skp')
        try:
            br.submit('raise "must never run"', timeout=2)
            check(False, 'submit with two windows and no model must refuse')
        except br.NotListening as e:
            jobs = [f for x in (a, b, tmp) if os.path.isdir(os.path.join(x, 'in'))
                    for f in os.listdir(os.path.join(x, 'in'))]
            check(e.code == br.EXIT_REFUSED and not jobs,
                  'refusal writes NO job file anywhere (%s)' % jobs)

        print('client: sweep')
        reset()
        make_slot(tmp, 501, 'Gone', r'C:\x\Gone.skp', fresh=False)
        make_slot(tmp, 502, 'Busy', r'C:\x\Busy.skp', fresh=False, running=True)
        alive_pids.add(502)
        swept = br.sweep_gone('override', fake)
        left = sorted(os.listdir(tmp))
        check(swept == ['inst-501'] and left == ['inst-502'],
              'ping sweeps only a slot whose process has exited (%s, left %s)' % (swept, left))
        check(br.sweep_gone('override', lambda pid: None) == [],
              'an unknown pid answer never deletes')

        print('client: the real Windows pid check')
        os.environ.pop('WR_BRIDGE_DIR', None)
        running, image = br._pid_image(os.getpid())
        check(running is True and image and image.lower().endswith('.exe'),
              'this python is seen as running (%s)' % image)
        check(br.pid_is_sketchup(os.getpid()) is False,
              'and is NOT mistaken for a SketchUp')
        import subprocess
        p = subprocess.Popen([sys.executable, '-c', 'pass'])
        p.wait()
        check(br.pid_is_sketchup(p.pid) is False, 'an exited pid is gone')
    finally:
        os.environ.pop('WR_BRIDGE_DIR', None)
        os.environ.pop('WR_BRIDGE_MODEL', None)
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------- listener --

def bridge_method(name):
    """`def self.<name>` ... its `end`, verbatim, from wr_bridge.rb (whose
    methods sit at four spaces, inside module Bridge)."""
    path = os.path.join(HERE, 'wr_tools', 'wr_bridge.rb')
    lines = open(path, encoding='utf-8').read().split('\n')
    for i, ln in enumerate(lines):
        if re.match(r'^    def self\.%s(\(|\s|$)' % re.escape(name), ln):
            for j in range(i + 1, len(lines)):
                if lines[j] == '    end':
                    return '\n'.join(lines[i:j + 1])
    raise SystemExit('wr_bridge.rb: no method self.%s' % name)


GUARD = r'''
module Process
  def self.pid; 4242; end
end
module B
  def self.root; 'C:/b/SketchUp 2026'; end
  def self.model_hash; @now; end
  def self.live_peers; @peers; end
  def self.set(now, peers, box); @now = now; @peers = peers; @box = box; end
%s
%s
end

def show(r); r.nil? ? 'RUN' : r[0]; end

out = []
here = { 'title' => 'Walsh', 'path' => 'Z:\\Sketchup\\Walsh.skp', 'guid' => 'g1' }
slot = 'C:/b/SketchUp 2026/inst-4242'
B.set(here, [], slot)
out << show(B.target_refusal('target' => { 'path' => 'z:/sketchup/WALSH.skp', 'guid' => 'zz' }))
out << show(B.target_refusal('target' => { 'path' => 'Z:\\Sketchup\\Other.skp', 'title' => 'Other' }))
out << show(B.target_refusal({}))
untitled = { 'title' => 'Untitled', 'path' => '', 'guid' => 'u1' }
B.set(untitled, [], slot)
out << show(B.target_refusal('target' => { 'path' => '', 'guid' => 'u1' }))
out << show(B.target_refusal('target' => { 'path' => '', 'guid' => 'u2' }))
B.set(here, [], slot)
out << show(B.target_refusal('target' => { 'path' => '', 'guid' => 'g1' }))
peer = [{ 'name' => 'inst-1', 'title' => 'ISL', 'path' => 'Z:/ISL.skp' }]
B.set(here, peer, 'C:/b/SketchUp 2026')
r = B.target_refusal({})
out << show(r)
out << (r && r[1].include?('ISL') && r[1].include?('Walsh') ? 'LISTED' : 'UNLISTED')
B.set(here, [], 'C:/b/SketchUp 2026')
out << show(B.target_refusal({}))
B.set(here, peer, slot)
out << show(B.target_refusal({}))
out.join(' ')
'''

GUARD_WANT = [
    ('RUN', 'same path, different case/slashes/guid: runs'),
    ('wrong-model', 'the window has a different file open: refused'),
    ('RUN', 'a job with no target in this slot: runs (only reachable with one window)'),
    ('RUN', 'untitled, same guid: runs'),
    ('wrong-model', 'untitled, different guid (File > New since): refused'),
    ('wrong-model', 'addressed to an untitled model, a saved file is open now: refused'),
    ('ambiguous-target', 'OLD client job in the shared inbox with a peer listening: refused'),
    ('LISTED', '...and the refusal lists both open files'),
    ('RUN', 'OLD client job in the shared inbox, this the only window: runs'),
    ('RUN', 'untargeted job in OWN slot ignores peers (the client already refused that case)'),
]


def listener_tests():
    print('listener: target_refusal (verbatim from wr_bridge.rb, in SketchUp CRuby)')
    import rbparse
    prog = GUARD % (bridge_method('same_path?'), bridge_method('target_refusal'))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog).split(' ')
    for (want, what), g in zip(GUARD_WANT, got):
        check(g == want, '%s (%s)' % (what, g))
    check(len(got) == len(GUARD_WANT), 'all %d guard cases ran' % len(GUARD_WANT))


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    client_tests()
    listener_tests()
    print('')
    if FAILS:
        print('%d FAILED' % len(FAILS))
        return 1
    print('all passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
