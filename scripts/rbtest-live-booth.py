# -*- coding: utf-8 -*-
"""BUILD EVERY BOOTH IN THE CATALOGUE, INSIDE A LIVE SKETCHUP, AND WRITE DOWN
WHAT LANDED WHERE.

    python rbtest-live-booth.py keys                    the 50, from the data file
    python rbtest-live-booth.py selftest                offline, no SketchUp
    python rbtest-live-booth.py dry                     all 50, dry runs
    python rbtest-live-booth.py dry   --keys "MDL 6060 S,MDL 6060 E"
    python rbtest-live-booth.py build --keys "MDL 6060 S"     real geometry
    python rbtest-live-booth.py diff  <baseline-dir>

    flags:  --out DIR   --su 2026   --timeout N   --dir P:/...   --hx
            --overlay efp   --keep-going / --stop-on-raise   --quiet

WHAT THIS IS AND WHY IT EXISTS

There are 50 booth keys (25 sizes x {Standard, Enhanced}) and each one assembles
from real .skp parts off P:/Sketchup/NewMasterComponentList. Whether they all
still assemble correctly -- the floors and ceilings above all -- has been a
hand-eyeball job nobody finishes. This turns it into a diffable artifact: one
manifest per key, written to disk, so the NEXT run is a `diff` and not another
afternoon of squinting at the Ruby Console.

This is the impure sibling of scripts/rbtest-*.py. Those run booth Ruby in a
bare CRuby VM (scripts/rbparse.py) and cannot see a component library or a
model. This one drives the real WR_BuildBoothComponents.build_booth inside the
running application, over scripts/sketchup-bridge.py. Read that file's header
for the protocol; read scripts/wr_tools/wr_bridge.rb's for the fences.

WHERE THE MANIFEST COMES FROM -- CAPTURED, NOT REIMPLEMENTED

The landed-bounds print already exists, in WR_Deck.build (scripts/wr-deck.rb,
around line 1130) and WR_Deck.seals (around line 1561). Per placed floor and
ceiling part it prints the filename, whether it was flipped or turned, the
contact z, the landed min/max x/y/z RE-MEASURED FROM THE PLACED INSTANCE, and
the wall-joint edge station. That print IS the floor/ceiling manifest. This
program captures the job's whole stdout verbatim into <key>.txt and parses the
interesting lines out of it into <key>.json. It computes no bounds of its own
for the deck, on purpose: a second implementation of the same measurement would
drift from the first and the drift would be reported as a booth defect.

The .json ALSO carries a whole-booth instance census -- every ComponentInstance
inside the booth group with its name, definition, tag and bounds, read back off
the model after the build. That is a different measurement from the deck print
(it covers walls, seals, corners, foam and options too) and it is additional to
it, never a substitute.

THE CLEAN-MODEL PROBLEM, AND HOW IT IS SOLVED

50 builds cannot share one model, and a build that inherited geometry from the
previous key would silently corrupt every manifest after the first. The obvious
route -- Sketchup.file_new between keys -- is the wrong one: on a dirty model it
opens a native save-or-discard prompt, and the bridge cannot intercept a native
modal (it patches UI.messagebox and friends, not the application's own file
dialogs). A wedged SketchUp needing a human click is exactly what this harness
must never produce, so file_new is not used at all.

Instead each job starts with WRB.scratch! (scripts/wr-bridge-lib.rb): a
start_operation, entities.clear!, commit, definitions.purge_unused,
materials.purge_unused. No dialog can arise from any of it. It returns a census
taken AFTER the wipe, and this harness ASSERTS that census total is zero before
it lets build_booth run -- so no-carryover is proven per key and the proof is
recorded in the manifest as `pre`, not merely assumed. A key whose `pre.total`
is not 0 is reported as a harness failure, not as a booth result.

WRB.scratch! refuses on a saved model by design, which is the second half of the
guarantee: this harness only ever runs against an Untitled scratch model, and
fails BY NAME naming the open drawing if one is loaded. Open the model you want
wiped before starting; nothing here opens or closes one.

Definitions are purged between keys deliberately. It costs a re-read of each
.skp from the P: share and it is most of the wall-clock time. The alternative --
keeping the definition cache warm across keys -- makes key N's result depend on
keys 1..N-1, which is the one property a golden baseline cannot have.

THE DRY RUN ALWAYS ENDS IN A DIALOG, AND THAT IS NOT A FAILURE

build_booth finishes a dry run with a UI.messagebox summarising it, and takes
the same route when parts are missing ("N component(s) missing or unusable").
Under the bridge every UI.messagebox raises ModalBlocked instead of opening, so
EVERY dry run comes back as a raise. The job therefore rescues ModalBlocked
separately from every other exception and records its text in `dialog`. Nothing
is lost by this: in both paths the messagebox is the last statement, after the
full console report has already been printed. A real exception still lands in
`error`, and the two are never merged -- distinguishing them is most of what
this program is for.

WHAT A KEY'S VERDICT MEANS

    clean     build_booth ran to its end with nothing flagged
    flagged   ran to its end, but flagged parts, warnings or named refusals
    missing   parts could not be resolved -- nothing was built, by design
    raised    a real exception, with a backtrace, in `error`
    harness   the bridge or the clean-model check failed; not a booth result

`raised` and `harness` are counted and named separately in the tally, because a
harness fault reported as a booth defect wastes a day.

NAMED REFUSALS THIS HARNESS DOES AND DOES NOT REACH

The overlay refusals (EFP, caster plate `cs`, step `sp`) live in
WR_Overlays.place_all and fire only when cfg['overlay'] asks for that option, so
they appear only under --overlay. The link-level refusals (bass traps `bt`,
Audimute `ac`, studio light `sl`, roof vent `rv`) live in booth-from-link.rb,
NOT in build_booth, and this harness does not reach them at all -- it calls the
programmatic entry point directly. Said here rather than left as a silent gap.
"""
import json
import os
import re
import sys
import time
from importlib import import_module

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DATA_RB = os.path.join(HERE, 'wr-booth-data.rb')
DEFAULT_OUT = os.path.join(REPO, '.forge', 'builder', 'booth-matrix')
DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'

# The representative real-build set, from the Phase 0 assignment. 6060 S/E carry
# the 40/16 side-wall swap that 1.7.10 changed and that disagrees with the
# portal's wallPanelRun() in two places; 96192 E exercises the renamed EFP;
# 102186 E is the largest booth in the catalogue.
REAL_SET = ['MDL 6060 S', 'MDL 6060 E', 'MDL 96192 E', 'MDL 102186 E']

VERDICTS = ('clean', 'flagged', 'missing', 'raised', 'harness')


# ------------------------------------------------------------------ keys ---

def booth_keys(path=DATA_RB):
    """The 50 keys, read from wr-booth-data.rb AT RUNTIME.

    Hardcoding the list would let this harness and the generator drift apart
    silently, and a booth that quietly stopped being in the data file would
    stop being tested without anything saying so.
    """
    src = open(path, encoding='utf-8').read()
    keys = re.findall(r"^    '(MDL [^']+)'\s*=>", src, re.M)
    if not keys:
        raise SystemExit('NO BOOTH KEYS FOUND in %s -- the data file format '
                         'changed, or the file is not the generated one. This '
                         'refuses rather than testing an empty set.' % path)
    dupes = [k for k in set(keys) if keys.count(k) > 1]
    if dupes:
        raise SystemExit('DUPLICATE KEYS in %s: %s' % (path, ', '.join(sorted(dupes))))
    return keys


def slug(key):
    return key.replace(' ', '-')


# ------------------------------------------------------------- the job -----
#
# One key, one clean model, one build. __ARGS__ is replaced with a JSON literal
# and parsed on the Ruby side, so nothing about a key or a path is ever
# interpolated into Ruby source -- a booth label carrying a quote or a backslash
# would otherwise be a syntax error in the job rather than a value in it.

JOB = r'''
require 'json'
args = JSON.parse(<<'WR_ARGS_EOF'
__ARGS__
WR_ARGS_EOF
)
key = args['key']

load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')

m = WRB.model
if !m.path.to_s.empty?
  raise WhisperRoom::Bridge::Forbidden,
        "the booth-matrix harness will not build into the saved model " \
        "#{m.path}. Open an Untitled scratch model first; this harness wipes " \
        "the model between keys and refuses to do that to a drawing."
end

# THE CLEAN-MODEL STEP, AND ITS PROOF. scratch! clears the entities, commits,
# and purges definitions and materials, then censuses what is left. No dialog
# can come out of any of it -- which is why file_new is not used here.
#
# THREE INDEPENDENT READS, NOT ONE ECHO. The lighting lane's 1.9.1 headline
# finding was a read-back taken microseconds after a write, against the same
# in-memory object, that reported success while the value had in fact been
# discarded. A check that cannot fail is not a check. So the wipe is verified by
# three reads that share no code path and no cached handle:
#
#   1. the census scratch! returns, taken inside it;
#   2. WRB.census called again afterwards, walking model.entities a second time;
#   3. Sketchup.active_model.entities.length -- re-fetching the model from the
#      application instead of reusing `m`, and asking the collection for its own
#      length instead of counting it by iteration.
#
# All three must be zero AND agree. A disagreement is itself a failure: it means
# the collection answers differently to different callers, which would make
# every bound in every manifest below it untrustworthy.
#
# The definition count is recorded either side of the purge for the same reason.
# A purge that silently did nothing would otherwise be invisible, and a warm
# definition cache is exactly the carryover this harness exists to rule out.
before_defs = m.definitions.length
pre = WRB.scratch!
recount = WRB.census
direct = Sketchup.active_model.entities.length
after_defs = Sketchup.active_model.definitions.length
if pre['total'].to_i != 0 || recount['total'].to_i != 0 || direct != 0
  raise "CLEAN-MODEL CHECK FAILED for #{key}: entities survived WRB.scratch! " \
        "(scratch! census #{pre['total']}, re-census #{recount['total']}, " \
        "direct model read #{direct}). Every manifest after this one would " \
        "inherit them, so this refuses to build rather than write a corrupt " \
        "baseline. Census: #{pre.inspect}"
end
if pre['total'].to_i != direct || recount['total'].to_i != direct
  raise "CLEAN-MODEL CHECK INCONSISTENT for #{key}: three reads of the same " \
        "supposedly-empty model disagree (#{pre['total']} / " \
        "#{recount['total']} / #{direct}). Refusing to build on a model that " \
        "answers differently to different callers."
end
wipe = { 'scratch_census' => pre['total'].to_i,
         're_census' => recount['total'].to_i, 'direct_read' => direct,
         'defs_before' => before_defs, 'defs_after' => after_defs }

# Once per SketchUp session. Re-loading per key would work but would reprint
# Ruby's constant-redefinition warnings 50 times over.
WRB.tool('build-booth-components') unless defined?(WR_BuildBoothComponents)

cfg = { 'dir' => args['dir'], 'hx' => args['hx'] ? true : false,
        'dry' => args['dry'] ? true : false }
cfg['overlay'] = args['overlay'] if args['overlay']
assign = (WR_BuildBoothComponents::ASSIGN[key] || {})

dialog = nil
err = nil
t0 = Time.now
begin
  WR_BuildBoothComponents.build_booth(key, assign, cfg)
rescue WhisperRoom::Bridge::ModalBlocked => e
  # EXPECTED on every dry run and on the missing-parts path: build_booth ends
  # both in a UI.messagebox, which the bridge turns into this. The console
  # report is already complete by the time it fires, so nothing is lost. Kept
  # strictly apart from a real exception below.
  dialog = e.message
rescue Exception => e
  err = { 'class' => e.class.name, 'message' => e.message,
          'backtrace' => e.backtrace.to_a.first(25) }
end
elapsed = (Time.now - t0).round(3)

post = WRB.census
top  = WRB.top_names

# The whole-booth instance census, re-measured off the model. Additional to the
# wr-deck.rb landed-bounds print in stdout, never a replacement for it.
parts = []
bbox = nil
booth = m.entities.grep(Sketchup::Group).find { |g| g.name.to_s.start_with?(key) }
if booth
  b = booth.bounds
  bbox = { 'min' => [b.min.x.to_f.round(4), b.min.y.to_f.round(4), b.min.z.to_f.round(4)],
           'max' => [b.max.x.to_f.round(4), b.max.y.to_f.round(4), b.max.z.to_f.round(4)] }
  booth.entities.grep(Sketchup::ComponentInstance).each do |i|
    ib = i.bounds
    parts << { 'name' => i.name.to_s,
               'def' => (i.definition.name.to_s rescue ''),
               'tag' => (i.layer.name.to_s rescue ''),
               'min' => [ib.min.x.to_f.round(4), ib.min.y.to_f.round(4), ib.min.z.to_f.round(4)],
               'max' => [ib.max.x.to_f.round(4), ib.max.y.to_f.round(4), ib.max.z.to_f.round(4)] }
  end
  # Sorted so two runs of the same key diff cleanly. SketchUp's entity order is
  # not a contract and has changed between versions.
  parts.sort_by! { |p| [p['name'], p['min'][0], p['min'][1], p['min'][2]] }
end

{ 'key' => key, 'dry' => cfg['dry'], 'hx' => cfg['hx'], 'dir' => cfg['dir'],
  'overlay' => cfg['overlay'], 'elapsed_s' => elapsed,
  'pre' => pre, 'wipe' => wipe, 'post' => post, 'top' => top,
  'dialog' => dialog, 'error' => err,
  'booth_bounds' => bbox, 'part_count' => parts.length, 'parts' => parts }
'''


def job_source(key, dry, cfg_dir, hx, overlay):
    args = {'key': key, 'dry': bool(dry), 'hx': bool(hx), 'dir': cfg_dir,
            'overlay': overlay or None}
    blob = json.dumps(args, ensure_ascii=True)
    if 'WR_ARGS_EOF' in blob:
        raise SystemExit('the job argument blob contains the heredoc terminator')
    return JOB.replace('__ARGS__', blob)


# ------------------------------------------------------- reading stdout ----
#
# Every pattern below matches a print that already exists in the tools. The line
# numbers are where they were written as of plugin 1.9.x; the patterns are keyed
# on the text, not the line, so a moved print still parses.

# wr-deck.rb WR_Deck.build (~line 1130): the floor/ceiling landed bounds.
#     STD7224FL SIDE R          flipped           contact  0.0000  ->  ...
RE_DECK = re.compile(
    r'^\s{4}(?P<file>\S.*?)\s{2,}(?P<flip>flipped)?\s*(?P<turn>turned)?\s*'
    r'contact\s+(?P<contact>-?[\d.]+)\s+->\s+'
    r'(?P<x0>-?[\d.]+)\s+(?P<y0>-?[\d.]+)\s+(?P<z0>-?[\d.]+)\s+to\s+'
    r'(?P<x1>-?[\d.]+)\s+(?P<y1>-?[\d.]+)\s+(?P<z1>-?[\d.]+)\s+'
    r'(?P<edge>edge .*)$')

# wr-deck.rb WR_Deck.seals (~line 1561): the seam-seal landed bounds.
RE_SEAL = re.compile(
    r'^\s{4}(?P<file>\S.*?)\s+joint\s+(?P<joint>-?[\d.]+)\s+datum\s+(?P<datum>-?[\d.]+)'
    r'\s+->\s+(?P<x0>-?[\d.]+)\s+(?P<y0>-?[\d.]+)\s+(?P<z0>-?[\d.]+)\s+to\s+'
    r'(?P<x1>-?[\d.]+)\s+(?P<y1>-?[\d.]+)\s+(?P<z1>-?[\d.]+)$')

RE_DRY_N = re.compile(r'DRY RUN.*?(\d+) parts would be placed')
RE_PLACED = re.compile(r'placed (\d+) component instances')
RE_MISSING_HDR = re.compile(r'\*\*\* (\d+) part\(s\) could not be resolved')
RE_FLAG_HDR = re.compile(r'\*\*\* (\d+) item\(s\) flagged')

# Named refusals and skips, wherever they are printed from. Substring tests, not
# a whitelist of known refusals -- a refusal added later must show up here
# without this file needing an edit.
REFUSAL_MARKS = ('REFUSED BY NAME', 'NOT PLACED', 'NOT built', 'not built:',
                 'SKIPPED', 'NOT BUILT', 'not sourced')


def parse_stdout(text):
    """Pull the manifest structure out of the tools' own console report."""
    lines = text.split('\n')
    out = {'deck': [], 'seals': [], 'missing': [], 'flagged': [],
           'refusals': [], 'deck_notes': [], 'guessed': [],
           'dry_parts': None, 'placed': None, 'reached_end': False}

    mode = None
    for ln in lines:
        m = RE_DECK.match(ln)
        if m:
            g = m.groupdict()
            out['deck'].append({
                'file': g['file'].strip(), 'flipped': bool(g['flip']),
                'turned': bool(g['turn']), 'contact': float(g['contact']),
                'min': [float(g['x0']), float(g['y0']), float(g['z0'])],
                'max': [float(g['x1']), float(g['y1']), float(g['z1'])],
                'edge': g['edge'].strip()})
            continue
        m = RE_SEAL.match(ln)
        if m:
            g = m.groupdict()
            out['seals'].append({
                'file': g['file'].strip(), 'joint': float(g['joint']),
                'datum': float(g['datum']),
                'min': [float(g['x0']), float(g['y0']), float(g['z0'])],
                'max': [float(g['x1']), float(g['y1']), float(g['z1'])]})
            continue

        m = RE_DRY_N.search(ln)
        if m:
            out['dry_parts'] = int(m.group(1))
            out['reached_end'] = True
        m = RE_PLACED.search(ln)
        if m:
            out['placed'] = int(m.group(1))
            out['reached_end'] = True

        if RE_MISSING_HDR.search(ln):
            mode = 'missing'
            continue
        if RE_FLAG_HDR.search(ln):
            mode = 'flagged'
            continue
        if ln.startswith('  deck ') or ln.startswith('  IEP deck '):
            out['deck_notes'].append(ln.strip())
        if ln.strip().startswith('DECK ') or ln.strip().startswith('IEP DECK:'):
            out['deck_notes'].append(ln.strip())
        if any(mk in ln for mk in REFUSAL_MARKS):
            out['refusals'].append(ln.strip())

        if mode and ln.startswith('      ') and ln.strip():
            out[mode].append(ln.strip())
        elif mode and (not ln.strip() or not ln.startswith('    ')):
            mode = None

    # A guessed-slot block, for the record: an unassigned slot filled from kind
    # plus run. Not an error, but it is a decision the tool made rather than one
    # the data stated, so it belongs in a baseline.
    grab = False
    for ln in lines:
        if 'had no explicit assignment and were guessed' in ln:
            grab = True
            continue
        if grab:
            if ln.startswith('      ') and ln.strip():
                out['guessed'].append(ln.strip())
            else:
                grab = False
    return out


def verdict_for(res, parsed):
    """clean / flagged / missing / raised -- from the result, never from a mood."""
    if res.get('error'):
        return 'raised'
    if parsed['missing']:
        return 'missing'
    if not parsed['reached_end']:
        # No end-of-build line and no exception: build_booth returned early for
        # a reason this parser does not know. Reported, not smoothed over.
        return 'flagged'
    if parsed['flagged'] or parsed['refusals']:
        return 'flagged'
    return 'clean'


# ------------------------------------------------------------- running -----

def run_key(br, key, opts):
    """One key. Returns (verdict, record, raw_stdout)."""
    src = job_source(key, opts['dry'], opts['dir'], opts['hx'], opts['overlay'])
    t0 = time.time()
    try:
        r = br.submit(src, timeout=opts['timeout'], version=opts['su'],
                      label='booth-matrix %s %s' % ('dry' if opts['dry'] else 'build', key))
    except br.NotListening as e:
        # A bridge fault is NOT a booth result, and is never written into a
        # manifest as one.
        return 'harness', {'key': key, 'verdict': 'harness',
                           'harness_exit': e.code, 'harness_message': e.message,
                           'wall_s': round(time.time() - t0, 3)}, ''

    stdout = r.get('stdout') or ''
    stderr = r.get('stderr') or ''
    val = r.get('value')

    if r.get('status') != 'ok' or not isinstance(val, dict):
        # The job itself blew up outside build_booth -- the saved-model refusal,
        # a failed clean-model check, a bridge fence. Harness, not booth.
        err = r.get('error') or {}
        return 'harness', {
            'key': key, 'verdict': 'harness',
            'harness_message': '%s: %s' % (err.get('class', r.get('status')),
                                           err.get('message', r.get('value_repr'))),
            'backtrace': (err.get('backtrace') or [])[:12],
            'wall_s': round(time.time() - t0, 3)}, stdout

    parsed = parse_stdout(stdout)
    v = verdict_for(val, parsed)
    rec = dict(val)
    rec['verdict'] = v
    rec['parsed'] = parsed
    rec['stderr'] = stderr
    rec['wall_s'] = round(time.time() - t0, 3)
    rec['bridge_env'] = r.get('env')
    return v, rec, stdout


def write_manifest(outdir, key, rec, stdout):
    os.makedirs(outdir, exist_ok=True)
    base = os.path.join(outdir, slug(key))
    # The .txt is the console report VERBATIM -- the primary diffable artifact,
    # because it is the tools' own words and not this program's paraphrase.
    with open(base + '.txt', 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(stdout)
    with open(base + '.json', 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(rec, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write('\n')
    return base


def run_matrix(keys, opts):
    br = import_module('sketchup-bridge')
    outdir = opts['out']
    os.makedirs(outdir, exist_ok=True)

    buckets = {v: [] for v in VERDICTS}
    index = {'mode': 'dry' if opts['dry'] else 'build',
             'started': time.strftime('%Y-%m-%dT%H:%M:%S'),
             'su': opts['su'], 'dir': opts['dir'], 'hx': opts['hx'],
             'overlay': opts['overlay'], 'keys': len(keys), 'results': {}}

    t0 = time.time()
    for n, key in enumerate(keys, 1):
        v, rec, stdout = run_key(br, key, opts)
        buckets[v].append(key)
        write_manifest(outdir, key, rec, stdout)
        p = rec.get('parsed') or {}
        index['results'][key] = {
            'verdict': v,
            'elapsed_s': rec.get('elapsed_s'),
            'wall_s': rec.get('wall_s'),
            'pre_total': (rec.get('pre') or {}).get('total'),
            'wipe': rec.get('wipe'),
            'post_total': (rec.get('post') or {}).get('total'),
            'dry_parts': p.get('dry_parts'),
            'placed': p.get('placed'),
            'deck_parts': len(p.get('deck', [])),
            'seal_parts': len(p.get('seals', [])),
            'missing': p.get('missing', []),
            'refusals': p.get('refusals', []),
            'flagged': p.get('flagged', []),
            'error': (rec.get('error') or {}).get('class'),
            'harness_message': rec.get('harness_message'),
        }
        if not opts['quiet']:
            extra = ''
            if p.get('dry_parts') is not None:
                extra = '%3d parts' % p['dry_parts']
            elif p.get('placed') is not None:
                extra = '%3d placed, deck %d + seals %d' % (
                    p['placed'], len(p.get('deck', [])), len(p.get('seals', [])))
            print('  %2d/%d  %-16s %-8s %6.1fs  %s'
                  % (n, len(keys), key, v, rec.get('wall_s') or 0.0, extra))
            for line in (p.get('missing', []) + p.get('refusals', []))[:6]:
                print('           ! %s' % line)
            if rec.get('harness_message'):
                print('           HARNESS: %s' % rec['harness_message'])
        if v in ('harness',) and opts['stop_on_harness']:
            print('\nSTOPPING: a harness fault is not a booth result and every '
                  'later key would inherit the same fault.')
            break

    index['finished'] = time.strftime('%Y-%m-%dT%H:%M:%S')
    index['wall_s'] = round(time.time() - t0, 1)
    index['tally'] = {v: buckets[v] for v in VERDICTS}
    with open(os.path.join(outdir, 'index.json'), 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(index, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write('\n')

    print('')
    print('=' * 72)
    print('BOOTH MATRIX -- %s, %d key(s), %.1f s, SketchUp %s'
          % (index['mode'], len(keys), index['wall_s'], opts['su'] or 'default'))
    print('  manifests  %s' % outdir)
    for v in VERDICTS:
        ks = buckets[v]
        print('  %-8s %2d   %s' % (v, len(ks), ', '.join(ks) if ks else '-'))
    print('=' * 72)
    # Non-zero if anything is not clean. A tally with a raise in it is not a
    # pass, whatever the other 49 did.
    return 0 if not (buckets['raised'] or buckets['harness'] or
                     buckets['missing']) else 1


# ------------------------------------------------------------ selftest ----
#
# The parser above reads prints that live in wr-deck.rb. If one of those format
# strings changes, the regex stops matching and this harness would quietly
# record ZERO floor and ceiling parts for every key -- a silent empty manifest,
# which is the worst failure this program could have. So the format strings are
# LIFTED VERBATIM from wr-deck.rb, rendered in SketchUp's own Ruby (via
# rbparse.py, no SketchUp needed), and fed back through the regexes. Editing the
# print in wr-deck.rb makes this fail, which is the point.

DECK_RB = os.path.join(HERE, 'wr-deck.rb')


def lift_format(path, anchor):
    """The `format(...)` string literal containing `anchor`, joined across its
    Ruby line-continuations, returned as a Ruby expression."""
    lines = open(path, encoding='utf-8').read().split('\n')
    start = None
    for n, ln in enumerate(lines):
        if anchor in ln and 'format(' in ln:
            start = n
            break
        if anchor in ln and start is None:
            # the anchor sits on a continuation line; walk back to the format(
            for k in range(n, max(-1, n - 6), -1):
                if 'format(' in lines[k]:
                    start = k
                    break
            if start is not None:
                break
    if start is None:
        raise SystemExit('SELFTEST CANNOT FIND the format( carrying %r in %s. '
                         'The print this parser depends on has moved or been '
                         'rewritten -- fix the parser before trusting a '
                         'manifest.' % (anchor, path))
    body = lines[start].split('format(', 1)[1]
    parts = []
    n = start
    while True:
        stripped = body.strip()
        if stripped.endswith('\\'):
            parts.append(stripped[:-1].strip())
            n += 1
            body = lines[n]
            continue
        # first argument ends at the comma that closes the literal
        parts.append(stripped)
        break
    joined = ' '.join(parts)
    # keep only the leading string literal(s), up to the comma that starts the
    # argument list
    m = re.match(r"^((?:'(?:[^'\\]|\\.)*'\s*)+)", joined)
    if not m:
        raise SystemExit('SELFTEST could not read the literal at %s:%d -- %r'
                         % (path, start + 1, joined[:120]))
    return m.group(1).strip().rstrip(',')


def cmd_selftest():
    import rbparse
    lib = rbparse.boot()
    rc = 0

    deck_fmt = lift_format(DECK_RB, 'contact %7.4f')
    seal_fmt = lift_format(DECK_RB, 'joint %7.2f')

    prog = (
        "out = []\n"
        "out << format(%s, 'STD7224FL SIDE R', ' flipped', '', 0.0,"
        " 1.0, 2.0, 0.0, 73.0, 49.0, 1.5, format('edge %%.3f', 47.125))\n"
        "out << format(%s, 'STDSS FL5', 36.5, -1.75, 2.0, 35.0, 0.0,"
        " 72.0, 39.0, 1.75)\n"
        "out.join(\"\\n\")\n" % (deck_fmt, seal_fmt))
    rendered = rbparse.rb_eval(lib, prog)
    if rendered.startswith('FAIL'):
        print('  FAIL  rendering the lifted format strings: %s' % rendered)
        return 1

    parsed = parse_stdout(rendered)
    checks = [
        ('deck line parses', len(parsed['deck']) == 1),
        ('deck file', parsed['deck'] and parsed['deck'][0]['file'] == 'STD7224FL SIDE R'),
        ('deck flipped', parsed['deck'] and parsed['deck'][0]['flipped'] is True),
        ('deck turned', parsed['deck'] and parsed['deck'][0]['turned'] is False),
        ('deck min/max', parsed['deck'] and parsed['deck'][0]['min'] == [1.0, 2.0, 0.0]
         and parsed['deck'][0]['max'] == [73.0, 49.0, 1.5]),
        ('deck edge', parsed['deck'] and parsed['deck'][0]['edge'] == 'edge 47.125'),
        ('seal line parses', len(parsed['seals']) == 1),
        ('seal file', parsed['seals'] and parsed['seals'][0]['file'] == 'STDSS FL5'),
        ('seal datum', parsed['seals'] and parsed['seals'][0]['datum'] == -1.75),
        ('seal min/max', parsed['seals'] and parsed['seals'][0]['min'] == [2.0, 35.0, 0.0]
         and parsed['seals'][0]['max'] == [72.0, 39.0, 1.75]),
    ]

    # And the verdict logic, which decides what a key is called.
    fake_clean = parse_stdout('  DRY RUN — nothing built. 24 parts would be placed.')
    fake_miss = parse_stdout('  *** 2 part(s) could not be resolved. Nothing has been built.\n'
                             '      N0  40VNT.skp\n      S1  16PanelSolid.skp\n')
    fake_flag = parse_stdout('  placed 61 component instances.\n'
                             '  *** 1 item(s) flagged - a part that does not measure its\n'
                             '      MDL 6060 S: IEP wall lift 2.25 is IEP_WALL_LIFT_DEFAULT\n')
    fake_ref = parse_stdout('  placed 61 component instances.\n'
                            '      EFP for the 96192 REFUSED BY NAME: EFP96192.skp does not exist\n')
    checks += [
        ('verdict clean', verdict_for({}, fake_clean) == 'clean'),
        ('verdict missing', verdict_for({}, fake_miss) == 'missing'
         and fake_miss['missing'] == ['N0  40VNT.skp', 'S1  16PanelSolid.skp']),
        ('verdict flagged', verdict_for({}, fake_flag) == 'flagged'
         and len(fake_flag['flagged']) == 1),
        ('verdict refusal', verdict_for({}, fake_ref) == 'flagged'
         and len(fake_ref['refusals']) == 1),
        ('verdict raised', verdict_for({'error': {'class': 'ArgumentError'}}, fake_clean) == 'raised'),
        ('dry_parts read', fake_clean['dry_parts'] == 24),
        ('placed read', fake_flag['placed'] == 61),
    ]

    # And that the key reader still finds the whole catalogue.
    ks = booth_keys()
    checks.append(('50 keys from wr-booth-data.rb', len(ks) == 50 and len(set(ks)) == 50))
    checks.append(('25 sizes, S and E', len({k.split()[1] for k in ks}) == 25
                   and all(k.endswith((' S', ' E')) for k in ks)))

    # And that the job source is well-formed Ruby. rbparse's own syntax check,
    # against the same VM SketchUp runs -- so a typo in the job never reaches a
    # live model as a mysterious timeout.
    src = job_source('MDL 6060 S', True, DEFAULT_DIR, False, {'efp': True})
    lit = "begin; RubyVM::InstructionSequence.compile(<<'WR_SRC_EOF'\n%s\nWR_SRC_EOF\n); 'OK'; " \
          "rescue Exception => e; 'FAIL ' + e.message; end" % src
    checks.append(('job Ruby compiles', rbparse.rb_eval(lib, lit) == 'OK'))

    print('rbtest-live-booth selftest -- parser pinned to wr-deck.rb\'s own format strings')
    for name, ok in checks:
        print('  %s  %s' % ('ok  ' if ok else 'FAIL', name))
        if not ok:
            rc = 1
    if rc == 0:
        print('  PASS  (%d checks, no SketchUp needed)' % len(checks))
    return rc


# ---------------------------------------------------------------- diff -----

def cmd_diff(baseline, current):
    """Diff two manifest directories, key by key, on the .txt reports.

    The point of a baseline is that the next run is a diff. This says WHICH
    keys moved and by how many lines; the line-by-line is `diff` or git, on the
    .txt files, which is why they are written verbatim.
    """
    import difflib
    b_keys = {f[:-4] for f in os.listdir(baseline) if f.endswith('.txt')}
    c_keys = {f[:-4] for f in os.listdir(current) if f.endswith('.txt')}
    rc = 0
    only_b, only_c = sorted(b_keys - c_keys), sorted(c_keys - b_keys)
    if only_b:
        print('ONLY IN BASELINE (%d): %s' % (len(only_b), ', '.join(only_b)))
        rc = 1
    if only_c:
        print('ONLY IN CURRENT  (%d): %s' % (len(only_c), ', '.join(only_c)))
        rc = 1
    same, moved = [], []
    for k in sorted(b_keys & c_keys):
        a = open(os.path.join(baseline, k + '.txt'), encoding='utf-8').read().split('\n')
        c = open(os.path.join(current, k + '.txt'), encoding='utf-8').read().split('\n')
        if a == c:
            same.append(k)
            continue
        d = [l for l in difflib.unified_diff(a, c, n=0)
             if l.startswith(('+', '-')) and not l.startswith(('+++', '---'))]
        moved.append((k, len(d)))
    for k, n in moved:
        print('CHANGED  %-16s %d line(s)' % (k, n))
    print('')
    print('%d unchanged, %d changed' % (len(same), len(moved)))
    return 1 if (moved or rc) else 0


# ---------------------------------------------------------------- main -----

def usage(msg=None):
    if msg:
        sys.stderr.write('%s\n\n' % msg)
    sys.stderr.write(__doc__.split('\n\nWHAT THIS IS')[0])
    sys.stderr.write('\n')
    return 2


def main(argv):
    if not argv:
        return usage('no command')
    cmd, rest = argv[0], argv[1:]

    opts = {'out': None, 'su': '2026', 'timeout': 600, 'dir': DEFAULT_DIR,
            'hx': False, 'overlay': None, 'quiet': False, 'dry': True,
            'stop_on_harness': True}
    keys_arg = None
    positional = []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == '--out':
            i += 1
            opts['out'] = rest[i]
        elif a == '--su':
            i += 1
            opts['su'] = rest[i]
        elif a == '--timeout':
            i += 1
            opts['timeout'] = int(rest[i])
        elif a == '--dir':
            i += 1
            opts['dir'] = rest[i]
        elif a == '--keys':
            i += 1
            keys_arg = rest[i]
        elif a == '--overlay':
            i += 1
            # "efp" or "efp,casters_plate" -> {'efp': True, ...}
            opts['overlay'] = {p.strip(): True for p in rest[i].split(',') if p.strip()}
        elif a == '--hx':
            opts['hx'] = True
        elif a == '--quiet':
            opts['quiet'] = True
        elif a == '--keep-going':
            opts['stop_on_harness'] = False
        elif a.startswith('--'):
            return usage('unknown flag %s' % a)
        else:
            positional.append(a)
        i += 1

    if opts['su'] == '2024':
        return usage('--su 2024 is refused by name. The booth-matrix baseline is '
                     'captured on SketchUp 2026, the version this work is drawn '
                     'in; a 2024 baseline would diff spuriously against every '
                     'future 2026 run. (Benton, 30 Aug 2026.)')

    if cmd == 'keys':
        ks = booth_keys()
        for k in ks:
            print(k)
        print('\n%d keys, %d sizes' % (len(ks), len({k.split()[1] for k in ks})))
        return 0

    if cmd == 'selftest':
        return cmd_selftest()

    if cmd == 'diff':
        if len(positional) < 1:
            return usage('diff needs a baseline directory')
        base = positional[0]
        cur = positional[1] if len(positional) > 1 else (opts['out'] or DEFAULT_OUT)
        return cmd_diff(base, cur)

    if cmd not in ('dry', 'build'):
        return usage('unknown command %r -- expected keys, selftest, dry, '
                     'build or diff' % cmd)

    opts['dry'] = (cmd == 'dry')
    all_keys = booth_keys()
    if keys_arg:
        want = [k.strip() for k in keys_arg.split(',') if k.strip()]
        unknown = [k for k in want if k not in all_keys]
        if unknown:
            return usage('not in wr-booth-data.rb: %s' % ', '.join(unknown))
        keys = want
    elif cmd == 'build':
        # NEVER all 50 real builds by default. That is the next phase, once the
        # manifest format is proven; asked for explicitly with --keys.
        keys = REAL_SET
    else:
        keys = all_keys

    if opts['out'] is None:
        opts['out'] = os.path.join(DEFAULT_OUT, 'dry' if opts['dry'] else 'build')

    print('booth matrix -- %s, %d key(s), library %s' % (cmd, len(keys), opts['dir']))
    print('  out %s' % opts['out'])
    return run_matrix(keys, opts)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
