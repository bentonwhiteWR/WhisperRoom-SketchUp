#!/usr/bin/env python3
"""Replay WR_BuildBoothComponents' per-booth IEP wall lift, in Python, against
the REAL constant table in build-booth-components.rb and the REAL generated
layouts in wr-booth-data.rb.

There is no Ruby outside SketchUp on this machine, so this is the only way to
see what iep_wall_lift / iep_wall_lift_measured? answer for a booth. It is a
reimplementation, not the code itself - but it does NOT hard-code the table:
it parses IEP_WALL_LIFT and IEP_WALL_LIFT_DEFAULT out of the .rb, so a row
edited there and not here shows up as a changed answer rather than as a pass.

What it cannot see: whether 0.7500 is the right lift for any booth. That is
Benton's eye on a built shell, and only three booths have been looked at.

Run:  python .forge/builder/replay-iep-wall-lift.py
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, 'scripts', 'build-booth-components.rb')
DATA = os.path.join(REPO, 'scripts', 'wr-booth-data.rb')

fails = []
checks = 0


def check(label, got, want):
    global checks
    checks += 1
    if got != want:
        fails.append('%s\n      got  %r\n      want %r' % (label, got, want))


# ------------------------------------------------------- parse the real .rb --
src = open(SRC, encoding='utf-8').read()

m = re.search(r'^\s*IEP_WALL_LIFT_DEFAULT\s*=\s*([\d.]+)\s*$', src, re.M)
if not m:
    sys.exit('IEP_WALL_LIFT_DEFAULT not found in %s' % SRC)
DEFAULT = float(m.group(1))

m = re.search(r'^\s*IEP_WALL_LIFT\s*=\s*\{(.*?)\}\.freeze', src, re.M | re.S)
if not m:
    sys.exit('IEP_WALL_LIFT table not found in %s' % SRC)
TABLE = {}
for k, v in re.findall(r"'([^']+)'\s*=>\s*([\d.]+)", m.group(1)):
    TABLE[k] = float(v)

# part_top_z must take the lift as an argument - the whole point of the change
# is that it is not read from module state that a second build could inherit.
PTZ_SIG = re.search(r'def self\.part_top_z\(([^)]*)\)', src)
PTZ_BODY = re.search(r'def self\.part_top_z\([^)]*\)\s*\r?\n(.*?)\r?\n\s*end', src, re.S)


def iep_wall_lift(key):
    """WR_BuildBoothComponents.iep_wall_lift, transcribed."""
    return TABLE.get(str(key), DEFAULT)


def iep_wall_lift_measured(key):
    """WR_BuildBoothComponents.iep_wall_lift_measured?, transcribed."""
    return str(key) in TABLE


def part_top_z(inner, hx, lift):
    """part_top_z + part_height, transcribed. ENH_WALL_H 79.5 / _HX 89.5."""
    h = (89.5 if hx else 79.5) if inner else (91.0 if hx else 81.0)
    return h + (lift if inner else 0.0)


# ------------------------------------------------- the real Enhanced layouts --
data = open(DATA, encoding='utf-8').read()
E_KEYS = re.findall(r"^\s*'(MDL \S+ E)'\s*=>\s*\{", data, re.M)
E_KEYS = sorted(set(E_KEYS))

print('=== 1. what was parsed out of the source ==========================')
print('  %s' % os.path.relpath(SRC, REPO))
print('    IEP_WALL_LIFT_DEFAULT = %s' % DEFAULT)
for k, v in TABLE.items():
    print('    %-14s -> %s' % (k, v))
print('  %s' % os.path.relpath(DATA, REPO))
print('    %d Enhanced layouts' % len(E_KEYS))
print('  part_top_z(%s)' % (PTZ_SIG.group(1) if PTZ_SIG else '?? NOT FOUND'))
print('')

print('=== 2. the three measured booths ==================================')
# Benton's three readings, quoted in the constant's comment. These are the
# assertions the change exists to satisfy.
check('4872 E lift', iep_wall_lift('MDL 4872 E'), 0.75)
check('4872 E measured?', iep_wall_lift_measured('MDL 4872 E'), True)
check('6060 E lift', iep_wall_lift('MDL 6060 E'), 0.6875)
check('6060 E measured?', iep_wall_lift_measured('MDL 6060 E'), True)
check('102144 E lift', iep_wall_lift('MDL 102144 E'), 0.75)
check('102144 E measured?', iep_wall_lift_measured('MDL 102144 E'), True)
for k in ('MDL 4872 E', 'MDL 6060 E', 'MDL 102144 E'):
    print('  %-14s %.4f  measured=%s' % (k, iep_wall_lift(k), iep_wall_lift_measured(k)))
print('  the table holds exactly three rows, and only three booths were looked at')
check('table size', len(TABLE), 3)
print('')

print('=== 3. a booth nobody has measured ================================')
for k in ('MDL 9696 E', 'MDL 96192 E', 'MDL 4230 E'):
    check('%s lift' % k, iep_wall_lift(k), 0.75)
    check('%s measured?' % k, iep_wall_lift_measured(k), False)
    print('  %-14s %.4f  measured=%s  <- DEFAULT, flagged in the build report'
          % (k, iep_wall_lift(k), iep_wall_lift_measured(k)))
check('the default is 0.7500', DEFAULT, 0.75)
# A Standard key must not be in the table either, and its parts never ask.
check('a Standard key is not measured', iep_wall_lift_measured('MDL 4872 S'), False)
print('')

print('=== 4. every Enhanced layout ======================================')
print('  %-16s %8s  %-9s %-9s %s' % ('BOOTH', 'LIFT', 'SOURCE', 'TOP OF', 'SPLIT lo/hi of the 1.5'))
n_meas = 0
for k in E_KEYS:
    lift = iep_wall_lift(k)
    meas = iep_wall_lift_measured(k)
    n_meas += 1 if meas else 0
    top = part_top_z(True, False, lift)
    print('  %-16s %8.4f  %-9s %-9.4f %.4f / %.4f'
          % (k, lift, 'measured' if meas else 'DEFAULT', top, lift, 81.0 - top))
    # The inner wall is 79.5 in an 81 nominal, so the two gaps must sum to 1.5.
    check('%s gaps sum to 1.5' % k, round(lift + (81.0 - top), 6), 1.5)
    check('%s outer part is never lifted' % k, part_top_z(False, False, lift), 81.0)
    check('%s HX outer part is never lifted' % k, part_top_z(False, True, lift), 91.0)
print('  %d of %d Enhanced layouts have a measured lift; %d take the default'
      % (n_meas, len(E_KEYS), len(E_KEYS) - n_meas))
check('25 Enhanced layouts', len(E_KEYS), 25)
check('3 measured of 25', n_meas, 3)
print('')

print('=== 5. the plumbing, read off the source ==========================')
# The lift must reach part_top_z as an argument. A module-level "current booth"
# would be inherited by the next build in the same long-lived SketchUp session,
# which is the failure mode this shape exists to make impossible.
check('part_top_z takes a lift argument',
      [a.strip() for a in (PTZ_SIG.group(1) if PTZ_SIG else '').split(',')],
      ['part', 'hx', 'lift'])
body = PTZ_BODY.group(1) if PTZ_BODY else ''
check('part_top_z no longer reads the constant', 'IEP_WALL_LIFT' in body, False)
print('  def self.part_top_z(%s)' % PTZ_SIG.group(1))
print('  %s' % body.strip())
# Resolved once per build, from the key build_booth is handed.
check('build_booth resolves the lift once',
      len(re.findall(r'^\s*lift = iep_wall_lift\(key\)\s*$', src, re.M)), 1)
check('build_booth resolves measured? once',
      len(re.findall(r'^\s*lift_measured = iep_wall_lift_measured\?\(key\)\s*$', src, re.M)), 1)
check('exactly one part_top_z call site',
      len(re.findall(r'(?<!def self\.)part_top_z\(p, ', src)), 1)
# v1.6.33: the call site passes p_lift, which IS the resolved lift with the
# vent family's drop taken off it. The assertion's intent is unchanged - the
# lift is still resolved once in build_booth and passed down, and there is
# still exactly one place that decides a part's top z.
check('the call site passes the resolved lift',
      len(re.findall(r"part_top_z\(p, cfg\['hx'\], p_lift\)", src)), 1)
check('p_lift starts as the resolved lift',
      len(re.findall(r'^\s*p_lift = lift\s*$', src, re.M)), 1)
check('the vent drop applies to INNER vent parts only',
      len(re.findall(r"p_lift -= vent_drop if inner\?\(p\) && iep_vent_part\?\(r\[:name\]\)", src)), 1)
check('the vent drop is resolved once, beside the lift',
      len(re.findall(r'^\s*vent_drop = iep_vent_lift_drop\(key\)\s*$', src, re.M)), 1)
check('a booth with no vent figure drops nothing',
      re.search(r'IEP_VENT_LIFT_DROP_DEFAULT = ([\d.]+)', src).group(1), '0.0')
VENT_TABLE = {}
_vm = re.search(r'^\s*IEP_VENT_LIFT_DROP\s*=\s*\{(.*?)\}\.freeze', src, re.M | re.S)
for _k, _v in re.findall(r"'([^']+)'\s*=>\s*([\d.]+)", _vm.group(1) if _vm else ''):
    VENT_TABLE[_k] = float(_v)
check('the 102144 E vent drop is 1/16', VENT_TABLE.get('MDL 102144 E'), 0.0625)
check('one booth has been looked at for the vent', len(VENT_TABLE), 1)
check('no Standard key in the vent table',
      any(k.endswith(' S') for k in VENT_TABLE), False)
# One vent test, used everywhere. The three name-driven vent rules
# (iep_vent_part?, iep_trim_end, iep_room_proud x2) must all ask the same
# question, or a part can be a vent for its trim and not for its lift.
check('every vent test uses one regex', src.count(r'/VNT|NV\b/i'), 4)
# v1.6.33: three of these carried a literal 0x08 BACKSPACE where the \b
# word boundary was meant (introduced v1.6.12, a shell heredoc eating the
# escape). The VNT alternative still matched, so every booth built so far
# was unaffected - but an NV part could never be recognised as a vent and
# would silently take the panel family's room-proud figure.
check('no control character survives in the source', chr(8) in src, False)
check('the vent-yaw block asks iep_vent_part?',
      len(re.findall(r'is_vent = iep_vent_part\?\(r\[:name\]\)', src)), 1)
# No module state: nothing assigns a current booth onto the module.
check('no @@ class variable was introduced', '@@' in src, False)
check('no module-level current-booth ivar',
      bool(re.search(r'^\s*@(cur|current|booth)_?\w*\s*=', src, re.M)), False)
print('  resolved once in build_booth, passed down, one call site: OK')
print('')

print('=== 6. the build says so out loud =================================')
# The unmeasured case must be NAMED, the way IEP_ROOM_PROUD names a width it
# has no figure for. Both are pushed into the same `warn` block.
check('unmeasured booth pushes a warn line',
      bool(re.search(r'if spec\[:eiw\] && shell != .outer. && !lift_measured', src)), True)
check('the warn line names IEP_WALL_LIFT_DEFAULT',
      bool(re.search(r'IEP wall lift #\{lift\} is IEP_WALL_LIFT_DEFAULT', src)), True)
check('the report line prints this booth\'s figure',
      bool(re.search(r'underside lifted #\{lift\}', src)), True)
check('the report line says measured or defaulted',
      bool(re.search(r'lift_src = lift_measured \?', src)), True)
check('the dead global-constant claim is gone',
      'MEASURED ON THE 6060 E, and the 4872 E measured 0.75' in src, False)
print('  report line: names the figure and whether it was measured')
print('  warn block:  names the booth by key when the default is used')
print('')

print('=== 7. what this harness CANNOT see ===============================')
print('  - whether 0.7500 is right for ANY booth not in the table. Two of')
print('    three measured it and the 4872 E is the only probe-backed one;')
print('    that is why it is the default, and it is still a guess for the')
print('    other 22 layouts.')
print('  - the 6060 E and 102144 E figures are Benton\'s eye, no probe.')
print('  - whether the running SketchUp has this code at all. A Ruby module')
print('    keeps its constants until SketchUp restarts (see IEP_VENT_YAW).')
print('    Nothing here is evidence about a booth built before the restart.')
print('  - anything about the Standard path beyond "the lift is 0.0", which')
print('    is asserted above but only in this reimplementation.')
print('')

if fails:
    print('%d of %d CHECKS FAILED' % (len(fails), checks))
    for f in fails:
        print('  ' + f)
    sys.exit(1)
print('ALL %d CHECKS PASS' % checks)
