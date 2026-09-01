# -*- coding: utf-8 -*-
"""Re-trigger full-audit (1 Sep 2026) lane B findings 1 and 2 on the 1.19.2 files.

    python .forge/fixer/repro-shading-contract.py

Copies the CURRENT scripts/ into a temp dir, swaps in one file from commit
523dad1 (plugin 1.19.2) per case, and runs the offline harness there:

    lights   old rbtest-lights.py + new rbparse.py
             -> RuntimeError naming NameError ... WR_DropLights::LUMEN_GAIN
    export   old export-scenes.rb (no after_switch hook)
             -> shade1, shade2, shade4 FAIL: write_image saw the scene's own
                shadows/AO, and the log had no per-row read-back
    package  old proposal-package.rb (no shade_reapply)
             -> the lift fails by name

Then runs both harnesses on the real tree, which must be green.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPTS = os.path.join(REPO, 'scripts')
OLD = '523dad1'


def stage(tmp, old_files):
    d = tempfile.mkdtemp(prefix='wr-repro-', dir=tmp)
    os.mkdir(os.path.join(d, 'wr_tools'))
    for f in os.listdir(SCRIPTS):
        if f.endswith(('.py', '.rb')):
            shutil.copy(os.path.join(SCRIPTS, f), d)
    shutil.copy(os.path.join(SCRIPTS, 'wr_tools', 'VERSION'), os.path.join(d, 'wr_tools'))
    for f in old_files:
        # bytes, not text: the scripts carry em-dashes and Windows' default
        # console codec is cp1252.
        src = subprocess.run(['git', 'show', '%s:scripts/%s' % (OLD, f)], cwd=REPO,
                             capture_output=True, check=True).stdout
        open(os.path.join(d, f), 'wb').write(src)
    return d


def run(d, harness):
    r = subprocess.run([sys.executable, os.path.join(d, harness)],
                       capture_output=True)
    text = (r.stdout + r.stderr).decode('utf-8', 'replace')
    out = []
    for l in text.splitlines():
        if l.startswith('  got'):
            out += re.findall(r'shade\d [^|]*', l)      # the result, not EXPECT
        elif re.search(r'RuntimeError|at eval|no method|PASS', l):
            out.append(l.strip())
    return r.returncode, out


def main():
    tmp = tempfile.mkdtemp(prefix='wr-repro-root-')
    cases = [
        ('lights: old rbtest-lights.py',   ['rbtest-lights.py'],    'rbtest-lights.py'),
        ('export: old export-scenes.rb',   ['export-scenes.rb'],    'rbtest-proposal.py'),
        ('package: old proposal-package.rb', ['proposal-package.rb'], 'rbtest-proposal.py'),
    ]
    for title, old, harness in cases:
        rc, lines = run(stage(tmp, old), harness)
        print('== %s -> exit %d (expected non-zero)' % (title, rc))
        for l in lines[-5:]:
            print('   ' + l[:160])
    print('== real tree (expected exit 0)')
    for h in ('rbtest-lights.py', 'rbtest-proposal.py'):
        rc, lines = run(SCRIPTS, h)
        print('   %-20s exit %d  %s' % (h, rc, '; '.join(l for l in lines if 'PASS' in l)[:100]))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
