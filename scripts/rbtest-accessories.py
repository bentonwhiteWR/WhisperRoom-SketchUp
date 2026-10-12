# -*- coding: utf-8 -*-
"""RUN wr-accessories.rb outside SketchUp.

    python rbtest-accessories.py

Same discipline as rbtest-roofvent.py: boots SketchUp's own CRuby 3.2 through
rbparse.py and loads wr-accessories.rb VERBATIM, whole. The file touches no
SketchUp API, so nothing is lifted or stubbed and the test cannot drift from
the code it tests.

WHAT IT ASSERTS
  1. the studio-light table: every model's part and count, the examples Benton
     was given (7272 = 1 x SL52, 7296 = 2 x SL29, 96144 = 3 x SL52), MDL 127 LP
     refused by name, an unknown model refused by name
  2. the bass-trap count: the link's bt is a bare flag, so the count comes
     from the package name alone; one pack when there is none
  3. the corner fill order (the wall opposite the door first) and the tiers
  4. the studio-light plan layout (1.83.0): each fixture longwise on ONE
     ceiling tile, never across a seam, every fitting tile once (widest first) before any doubles up, and a refusal
     when no tile is long enough
  5. the IEP beam plan: BOM counts, the RM rule, the derived 84 series

DRIFT CHECKS, run when the WhisperRoomQuote checkout is beside this repo: the
embedded SL table is compared row for row against lib/pl-data/
feature-rules.json `sl_by_model`, and the bass-trap packs against
quote-builder.html PRESET_QTY_OVERRIDES. A third check guards the premise
that a PACKAGE link needs no expanding: booth-builder.html's applyPackage()
turns on every accessory the package bills, so pk arrives WITH sl/ac/bt/vs/
ef/dk (see package_flags). The plugin cannot read that repo at
runtime (Gabe's machine has no checkout), which is why the figures are copied
- and a copy is exactly what drifts. Absent checkout: said, not failed.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

PROG = r'''
@@LIB@@

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

A = WR_Accessories

# --- 1. studio lights ------------------------------------------------------
check('25 models in the SL table', A::SL_BY_MODEL.length, 25)
check('only SL29 / SL52 parts',
      A::SL_BY_MODEL.values.map { |r| r[0] }.uniq.sort, %w[SL29 SL52])
check('7272 = 1 x SL52 replacing 2', A.sl_plan('MDL 7272 E'),
      { :part => 'SL52', :count => 1, :remove => 2 })
check('7296 = 2 x SL29', A.sl_plan('MDL 7296 S'),
      { :part => 'SL29', :count => 2, :remove => 2 })
check('96120 = 2 x SL52 replacing 3', A.sl_plan('MDL 96120 E'),
      { :part => 'SL52', :count => 2, :remove => 3 })
check('96144 = 3 x SL52', A.sl_plan('MDL 96144 S')[:count], 3)
check('9696 = 2 x SL52', A.sl_plan('MDL 9696 S')[:part], 'SL52')
check('4284 = 1 x SL52 (a 52 in fixture in a 42 in booth)',
      A.sl_plan('MDL 4284 S')[:part], 'SL52')
check('102186 = 4 x SL52', A.sl_plan('MDL 102186 E')[:count], 4)
check('MDL 127 LP is refused', A.sl_plan('MDL 127 LP S')[:error].nil?, false)
check('and by name', A.sl_plan('MDL 127 LP S')[:error].include?('127 LP'), true)
check('an unknown model is refused', A.sl_plan('MDL 9999 S')[:error].nil?, false)
check('and names the table', A.sl_plan('MDL 9999 S')[:error].include?('sl_by_model'), true)
check('excluded: 127 LP', A.excluded('MDL 127 LP E'), true)
check('excluded: not 12784-like digits', A.excluded('MDL 12784 S'), false)
check('excluded: an ordinary model', A.excluded('MDL 7272 S'), false)

# --- 2. bass traps ---------------------------------------------------------
check('no package: one pack, two traps', A.bass_trap_plan(nil)[:traps], 2)
check('and says so', A.bass_trap_plan(nil)[:source].include?('no package'), true)
check('Practice Basic: 3 packs', A.bass_trap_plan('Practice Basic')[:packs], 3)
check('Practice Deluxe: 6 traps', A.bass_trap_plan('Practice Deluxe')[:traps], 6)
check('Recording Studio: 6 traps', A.bass_trap_plan('Recording Studio')[:traps], 6)
check('Drum Booth: 8 traps', A.bass_trap_plan('Drum Booth')[:traps], 8)
check('Drum Studio: 4 packs', A.bass_trap_plan('Drum Studio')[:packs], 4)
check('a package with no override: one pack',
      A.bass_trap_plan('Voice Over Basic')[:packs], 1)
check('and names the package', A.bass_trap_plan('Voice Over Basic')[:source].include?('Voice Over Basic'), true)

# --- 3. corners ------------------------------------------------------------
check('back N (door on S): back corners first', A.corner_order('N'), %w[NW NE SW SE])
check('back S (door on N)', A.corner_order('S'), %w[SW SE NW NE])
check('back E (door on W)', A.corner_order('E'), %w[NE SE NW SW])
check('back W (door on E)', A.corner_order('W'), %w[NW SW NE SE])
check('no door: the portal Back (N)', A.corner_order(nil), %w[NW NE SW SE])
o = A.corner_order('N')
check('2 traps: the two back corners, tier 0', A.trap_slots(2, o), [['NW', 0], ['NE', 0]])
check('6 traps: all four, then the back two again one tier down',
      A.trap_slots(6, o),
      [['NW', 0], ['NE', 0], ['SW', 0], ['SE', 0], ['NW', 1], ['NE', 1]])
check('8 traps: two full tiers', A.trap_slots(8, o).map { |c, t| t }, [0, 0, 0, 0, 1, 1, 1, 1])
check('every corner names two walls, one N/S and one E/W',
      A::BT_CORNERS.values.all? { |ns, ew| %w[N S].include?(ns) && %w[E W].include?(ew) }, true)

# --- 4. studio-light layout: longwise on a tile, never across a seam ------
# 96120 E: tiles 48 + 24 + 48 along x, seals at x 49 and 73 (6.5 wide), room
# 4.25..117.75 x 4.25..93.75. Usable rects as wr-overlays cuts them.
t96120 = [[4.25, 4.25, 45.75, 93.75], [52.25, 4.25, 69.75, 93.75], [76.25, 4.25, 117.75, 93.75]]
l = A.sl_tile_layout(2, 52.0, t96120)
check('96120: both fixtures run along y (the seam direction)', l[:lights].map { |x| x[:orient] }, [:y, :y])
check('96120: the two wide tiles, one each, centred in them',
      l[:lights].map { |x| [x[:tile], x[:centre]] }, [[0, [25.0, 49.0]], [2, [97.0, 49.0]]])
l = A.sl_tile_layout(2, 52.0, [[4.25, 4.25, 45.75, 93.75], [52.25, 4.25, 93.75, 93.75]])  # 9696-ish
check('9696: one per tile, along y', l[:lights].map { |x| [x[:tile], x[:orient]] }, [[0, :y], [1, :y]])
l = A.sl_tile_layout(1, 52.0, [[4.25, 4.25, 69.75, 45.75]])       # 4872 E, one tile, long on x
check('single tile: along its long side', l[:lights].map { |x| x[:orient] }, [:x])
l = A.sl_tile_layout(3, 52.0, t96120)
check('3 fixtures, 3 tiles that fit: every tile takes one before any doubles up',
      l[:lights].map { |x| x[:tile] }, [0, 1, 2])
l = A.sl_tile_layout(4, 52.0, t96120)
check('4 fixtures on 3 tiles: the widest tile doubles up, spaced across it',
      l[:lights].map { |x| [x[:tile], x[:centre]] },
      [[0, [14.625, 49.0]], [0, [35.375, 49.0]], [1, [61.0, 49.0]], [2, [97.0, 49.0]]])
check('a fixture too long for every tile is refused',
      A.sl_tile_layout(1, 90.0, t96120)[:error].nil?, false)
check('a zero count is refused', A.sl_tile_layout(0, 29.0, t96120)[:error].nil?, false)

# --- 5. IEP ceiling beams (1.83.0) ----------------------------------------
b = A.iep_beam_plan('MDL 96120 E', true, false)
check('96120 E: 2 x U101 82 in under 94 in seals',
      [b[:count], b[:code], b[:length], b[:seal_len], b[:derived]], [2, 'U101', 82.0, 94.0, false])
b = A.iep_beam_plan('MDL 102144 E', true, false)
check('102144 E: 3 x U01 88 in under 100 in seals',
      [b[:count], b[:code], b[:length], b[:seal_len]], [3, 'U01', 88.0, 100.0])
check('102186 E: 4 beams', A.iep_beam_plan('MDL 102186 E', true, false)[:count], 4)
check('9696 E: 1 beam', A.iep_beam_plan('MDL 9696 E', true, false)[:count], 1)
b = A.iep_beam_plan('MDL 10284 E', true, false)
check('10284 E: 1 x IEP BEAM 8.5 (first figure 102, Benton)', [b[:count], b[:file], b[:seal_len]], [1, 'IEP BEAM 8.5', 100.0])
b = A.iep_beam_plan('MDL 84102 E', true, false)
check('84102 E: 2 x IEP BEAM 7 (first figure 84, 3 ceiling components)', [b[:count], b[:file]], [2, 'IEP BEAM 7'])
check('iep_series reads the FIRST figure', %w[10284 84102 96120 102186 8484 7296 4872].map { |d| A.iep_series(d) },
      ['102', '84', '96', '102', '84', nil, nil])
b = A.iep_beam_plan('MDL 96120 S', false, true)
check('96120 S + RM: the E count, from the RM rule', [b[:count], b[:code]], [2, 'U101'])
check('  and says the RM rule', b[:source].include?('RM rule'), true)
check('96120 S without RM: none', A.iep_beam_plan('MDL 96120 S', false, false)[:count], nil)
check('4872 E: none (72-series and smaller), not a note',
      [A.iep_beam_plan('MDL 4872 E', true, false)[:count], A.iep_beam_plan('MDL 4872 E', true, false)[:note]], [nil, false])
check('7272 E: none', A.iep_beam_plan('MDL 7272 E', true, false)[:count], nil)
check('7272 E + RM: none', A.iep_beam_plan('MDL 7272 E', true, true)[:count], nil)
check('7296 S + RM: none (below the 84 series)', A.iep_beam_plan('MDL 7296 S', false, true)[:count], nil)
b = A.iep_beam_plan('MDL 84102 S', false, true)
check('84102 S + RM: 2 x U02 = IEP BEAM 7 under 82 in seals', [b[:count], b[:code], b[:file], b[:seal_len]],
      [2, 'U02', 'IEP BEAM 7', 82.0])
b = A.iep_beam_plan('MDL 8484 E', true, false)
check('8484 E without RM: 1 x IEP BEAM 7 (Benton, 12 Oct)', [b[:count], b[:file]], [1, 'IEP BEAM 7'])
check('  and cites Benton', b[:source].include?('Benton'), true)
check('84126 E: 2', A.iep_beam_plan('MDL 84126 E', true, false)[:count], 2)
check('84102 S without RM: none', A.iep_beam_plan('MDL 84102 S', false, false)[:count], nil)
check('96120 E: IEP BEAM 8 by name', A.iep_beam_plan('MDL 96120 E', true, false)[:file], 'IEP BEAM 8')
check('102144 E: IEP BEAM 8.5 by name', A.iep_beam_plan('MDL 102144 E', true, false)[:file], 'IEP BEAM 8.5')
check('127 LP: none', A.iep_beam_plan('MDL 127 LP E', true, true)[:count], nil)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''

QUOTE = os.path.join(HERE, '..', '..', 'WhisperRoomQuote')


def drift(lib):
    """Compare the embedded copies against their sources, when present."""
    notes, bad = [], []
    fr = os.path.join(QUOTE, 'lib', 'pl-data', 'feature-rules.json')
    if not os.path.exists(fr):
        notes.append('SKIP drift (SL): %s not found' % fr)
    else:
        src = json.load(open(fr, encoding='utf-8'))['sl_by_model']
        part = {'T07': 'SL29', 'T08': 'SL52'}
        want = {}
        for k, v in src.items():
            m = re.match(r'MDL (\d+) [SE]$', k)
            if not m:
                continue  # 127 LP: excluded here on purpose
            (t, n), = v['add'].items()
            row = (part.get(t, t), n, v['remove']['T01'])
            if want.setdefault(m.group(1), row) != row:
                bad.append('sl_by_model: %s S and E rows differ' % m.group(1))
        have = {m.group(1): (m.group(2), int(m.group(3)), int(m.group(4)))
                for m in re.finditer(r"'(\d+)'\s*=>\s*\['(SL\d+)',\s*(\d+),\s*(\d+)\]", lib)}
        if have != want:
            for d in sorted(set(have) | set(want)):
                if have.get(d) != want.get(d):
                    bad.append('SL table %s: embedded %r, feature-rules.json %r'
                               % (d, have.get(d), want.get(d)))
        else:
            notes.append('PASS drift: SL table matches feature-rules.json (%d models)' % len(want))
    qb = os.path.join(QUOTE, 'quote-builder.html')
    if not os.path.exists(qb):
        notes.append('SKIP drift (bass traps): %s not found' % qb)
    else:
        txt = open(qb, encoding='utf-8').read()
        m = re.search(r'const PRESET_QTY_OVERRIDES = \{(.*?)\n\};', txt, re.S)
        src = {k: int(n) for k, n in re.findall(
            r"'([^']+)':\s*\{\s*'BASS TRAPS':\s*(\d+)", m.group(1) if m else '')}
        blk = re.search(r'BT_PACKS_BY_PACKAGE = \{(.*?)\}', lib, re.S)
        have = {k: int(n) for k, n in re.findall(r"'([^']+)'\s*=>\s*(\d+)", blk.group(1))}
        if not src:
            bad.append('PRESET_QTY_OVERRIDES could not be read from quote-builder.html')
        elif have != src:
            bad.append('bass-trap packs: embedded %r, quote-builder %r' % (have, src))
        else:
            notes.append('PASS drift: bass-trap packs match PRESET_QTY_OVERRIDES')
    notes2, bad2 = package_flags(txt if os.path.exists(qb) else None)
    notes3, bad3 = beam_drift(lib)
    return notes + notes2 + notes3, bad + bad2 + bad3


def beam_drift(lib):
    """The IEP beam table against base-bom.json and components-master.json:
    every model's U-code count on its E row (and ENV identical), no U-code on
    any S row, the beam count equal to the model's D101 / D12 seal packs, and
    the three parts' lengths. Plus the RM rule's text in packing-list.js, which
    is the only source for a roof-mounted Standard booth's count."""
    notes, bad = [], []
    bp = os.path.join(QUOTE, 'lib', 'pl-data', 'base-bom.json')
    cp = os.path.join(QUOTE, 'lib', 'pl-data', 'components-master.json')
    if not (os.path.exists(bp) and os.path.exists(cp)):
        return ['SKIP drift (IEP beams): base-bom.json / components-master.json not found'], []
    bom = json.load(open(bp, encoding='utf-8'))['models']
    cm = json.load(open(cp, encoding='utf-8'))['components']
    blk = re.search(r'IEP_BEAMS_BY_MODEL = \{(.*?)\}', lib, re.S)
    have = {k: int(n) for k, n in re.findall(r"'(\d+)'\s*=>\s*(\d+)", blk.group(1))}
    want = {}
    for name, row in bom.items():
        u = {c: q for c, q in row['components'].items() if c.startswith('U')}
        if not u:
            continue
        if row['variant'] not in ('E', 'ENV'):
            bad.append('base-bom %s (a %s row) carries %r - the table assumes only E/ENV do'
                       % (name, row['variant'], u))
            continue
        (code, n), = u.items()
        seals = row['components'].get('D101', 0) + row['components'].get('D12', 0)
        if seals != n:
            bad.append('base-bom %s: %s x%d but %d D101/D12 seal pack(s)' % (name, code, n, seals))
        if want.setdefault(row['size'], n) != n:
            bad.append('base-bom %s: E and ENV beam counts differ' % row['size'])
    if have != want:
        bad.append('IEP beam table: embedded %r, base-bom.json %r' % (have, want))
    for code, length in (('U101', 82), ('U01', 88), ('U02', 70)):
        if cm.get(code, {}).get('L') != length:
            bad.append('components-master %s length %r, embedded %d' % (code, cm.get(code, {}).get('L'), length))
    pl = os.path.join(QUOTE, 'lib', 'packing-list.js')
    if os.path.exists(pl):
        t = open(pl, encoding='utf-8').read()
        if not re.search(r"bom\.D101 \|\| 0\); i\+\+\) additions\.push\(\{ code: 'U101'", t) or            not re.search(r"bom\.D12  \|\| 0\); i\+\+\) additions\.push\(\{ code: 'U01'", t):
            bad.append('packing-list.js RM rule no longer adds U101 per D101 / U01 per D12 on an S booth')
    if not bad:
        notes.append('PASS drift: IEP beam table matches base-bom.json (%d models), part lengths and '
                     'the RM rule match' % len(want))
    return notes, bad


# The quote SKU that means each accessory, and the booth-builder state key
# applyPackage() turns on for it (which designPayload() emits as the link flag).
PKG_SKU_TO_KEY = [('AP ', 'ap'), ('SL ', 'studioLight'), ('BASS TRAPS', 'bassTraps'),
                  ('VSS ', 'vss'), ('EFS ', 'efs'), ('Office Desk', 'desk'), ('HEPA ', 'hepa')]


def package_flags(qb_txt):
    """THE PREMISE the importer rests on (1.77.3): a package link does NOT need
    expanding, because booth-builder.html's applyPackage() switches on every
    accessory the package contains and designPayload() emits them as sl / ac /
    bt / vs / ef / dk / hp beside pk. Checked three ways, so a change to the
    encoder that would make pk-only links possible fails here, not in a model:
      a. applyPackage() still does `for (const k in p.o) state[k] = true`;
      b. designPayload() still maps ap->ac, studioLight->sl, bassTraps->bt;
      c. every BOOTH_PRESETS package SKU list (quote-builder.html) that bills
         AP / SL / BASS TRAPS / VSS / EFS / a desk / HEPA has the matching key
         in booth-builder PACKAGES[..].o, and no key the quote does not bill."""
    notes, bad = [], []
    bb = os.path.join(QUOTE, 'booth-builder.html')
    if qb_txt is None or not os.path.exists(bb):
        return ['SKIP drift (package flags): booth-builder.html / quote-builder.html not found'], []
    btxt = open(bb, encoding='utf-8').read()
    if not re.search(r'for \(const k in p\.o\) state\[k\] = true;', btxt):
        bad.append('applyPackage() no longer sets state[k] for every package content - '
                   'a package link may now carry pk WITHOUT sl/ac/bt; the importer must expand pk')
    for flag, key in (('ac', 'ap'), ('sl', 'studioLight'), ('bt', 'bassTraps'),
                      ('vs', 'vss'), ('ef', 'efs'), ('dk', 'desk')):
        if not re.search(r'\b%s: state\.%s \? 1 : 0' % (flag, key), btxt):
            bad.append('designPayload() no longer emits %s from state.%s' % (flag, key))
    rows = dict(re.findall(r"^\s*'([^']+)':\s*\{\s*m: '[^']+',\s*v: '[SE]',\s*o: \{([^}]*)\}",
                           btxt, re.M))
    pm = re.search(r'const BOOTH_PRESETS = \{(.*?)\n\};', qb_txt, re.S)
    presets = dict(re.findall(r'^\s*"([^"]+)":\s*\[(.*)\],?\s*$', pm.group(1) if pm else '', re.M))
    if len(rows) != 19:
        bad.append('booth-builder PACKAGES: read %d rows, expected 19' % len(rows))
    for name, o in sorted(rows.items()):
        keys = set(re.findall(r'(\w+): 1', o))
        skus = re.findall(r'"((?:[^"\\]|\\.)*)"', presets.get(name, ''))
        if not skus:
            bad.append('package %r has no BOOTH_PRESETS row in quote-builder.html' % name)
            continue
        for prefix, key in PKG_SKU_TO_KEY:
            billed = any(s.startswith(prefix) for s in skus)
            if billed != (key in keys):
                bad.append('package %r: quote %s %s, booth-builder o.%s %s'
                           % (name, 'bills' if billed else 'does not bill', prefix.strip(),
                              key, 'set' if key in keys else 'absent'))
    if not bad:
        notes.append('PASS drift: %d package links carry their accessory flags '
                     '(applyPackage + designPayload + BOOTH_PRESETS agree)' % len(rows))
    return notes, bad


def main():
    lib = open(os.path.join(HERE, 'wr-accessories.rb'), encoding='utf-8').read()
    got = rbparse.rb_eval(rbparse.boot(), PROG.replace('@@LIB@@', lib))
    print(got)
    notes, bad = drift(lib)
    for n in notes:
        print(n)
    for b in bad:
        print('FAIL (drift) ' + b)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') and not bad else 1


if __name__ == '__main__':
    sys.exit(main())
