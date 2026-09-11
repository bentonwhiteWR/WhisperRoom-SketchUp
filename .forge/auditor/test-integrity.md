# Audit — IS THE SAFETY NET REAL?

Auditor, read-only. 10 Sep 2026. Plugin 1.48.1, working tree clean
(`git status` shows only untracked `.forge/` output dirs).

## Outcome

The net is real and it bites. I ran all 21 `scripts/rbtest-*.py`, `rbparse.py`
and `jstest-proposal-dialog.js` — every one green, and the strongest of them
(`rbtest-srgb.py`, `rbtest-autoset.py`, `jstest-proposal-dialog.js`) assert
against exact expected transcripts that an empty or truncated result cannot
satisfy. The verbatim-lift mechanism fails loudly, by design and in fact: every
lifter raises `SystemExit` by name when its anchor moves.

What is weak is not the assertions, it is the **perimeter**. Two thirds of the
`scripts/` Ruby tree — including `wr-deck.rb` (1740 lines), `wr_tools/main.rb`'s
one-click updater, and the `wr-scene-walls` / `wr-scene-annotations` writers
AUTO-SET depends on — has no offline check at all, and nothing in `CLAUDE.md`
or CI requires anyone to run the harnesses that do exist. I found one proven
cross-program state leak in `rbtest-lights.py`, one family of seven harnesses
whose pass gate would accept a run with zero assertions executed, one harness
that transcribes the code under test into Python instead of lifting it, and
several vacuous-on-empty checks in the two live-model scripts.

===DETAIL===

## Method and scope

- **Ran** every harness (`python rbtest*.py`, `python rbparse.py`,
  `node jstest-proposal-dialog.js`, `python rbtest-live-booth.py selftest`).
  All exit 0. `rbparse.py` parses all 75 `.rb` files.
- **Read in full**: `scripts/rbparse.py`, `scripts/rbcheck.py`,
  `scripts/rbtest.py`, `.forge/builder/verify-autoset.rb`,
  `.forge/builder/verify-scene-annotations.rb`.
- **Read the assertion/lift/exit-code machinery** of all 21 `rbtest-*.py` and
  `jstest-proposal-dialog.js`; read the fixtures and expectations of
  `rbtest-autoset`, `rbtest-proposal`, `rbtest-lights`, `rbtest-overlays`,
  `rbtest-srgb`, `rbtest-roofvent`, `rbtest-part-orientation`,
  `rbtest-callout-style`, `rbtest-side-wall-order`, `rbtest-materials-diagnosis`.
- **Ran two mutation experiments of my own** (in-memory only, no file touched)
  — see F1 and F2.
- **NOT covered**: whether the geometry each harness asserts is *correct*
  engineering (I checked whether the checks bite, not whether the numbers are
  the right numbers); the Python-only tools (`gen-booth.py`, `image-qa.py`,
  `eval-floorplan.py`, `takeoff-check.py`, `install-plugin.py`); the `eval/`
  tree; the V-Ray render lane beyond `wr-png-srgb.rb`; every `.rb` under
  `clients/`; `rbtest-live-booth.py`'s `dry`/`build`/`diff` commands (they need
  SketchUp — only its `selftest` is offline).

## Answers to the five questions

1. **Assert or merely execute?** They assert. Every harness wires its verdict
   to `sys.exit`. Three distinct gate styles: exact-transcript equality
   (`rbtest.py`, `rbtest-autoset`, `rbtest-overlays`, `rbtest-panel-prefs`,
   `rbtest-proposal`, `rbtest-lights`), named-check accumulators
   (`rbtest-srgb`, `rbtest-callout-style`, `rbtest-side-wall-order`,
   `rbtest-materials-diagnosis`, `rbtest-part-orientation`), and a
   Ruby-side failure counter (seven files — see F1, the weak one).
   No harness merely executes.

   `rbparse.py`'s `"(Parsing is not working -- run it.)"` (line 172) is not a
   disclaimer about the parser — it is a deliberate refusal to let a clean
   parse be reported as working code. Its whole docstring exists because
   `rbcheck.py`'s "balanced" was once retold as "parses". **I found no caller
   that over-trusts it**: `CLAUDE.md:296-300` states the distinction correctly,
   `rbcheck.py`'s own docstring says "USE rbparse.py INSTEAD", and no
   `rbtest-*.py` treats a parse as a pass. *(observed)*

2. **Is the verbatim lift sound?** Yes, in the important direction: it fails
   loudly. `rbtest.py:56-74` `method_source` finds `^  def self\.<name>\b` and
   closes at the first line that is *exactly* `  end`; both misses raise
   `SystemExit` with the file and method named. Every other harness copies that
   shape (`rbtest-lights.py:326-413`, `rbtest-overlays.py:54-102`,
   `rbtest-panel-prefs.py:45-67`, `rbtest-boothdims.py:460`,
   `rbtest-live-booth.py:592`, `rbtest-side-wall-order.py:281-300`). A
   truncated or mis-anchored lift produces Ruby that does not compile, and
   `rbparse.rb_eval` (`rbparse.py:128-136`) turns that into a `RuntimeError`
   carrying the real Ruby exception class, message and first backtrace frame.
   **No lifter returns an empty string on a miss** — the only two
   `return ''`/`return None` sites I found (`rbtest-srgb.py:402`,
   `rbtest-part-orientation.py:89`) are output parsers and domain helpers, not
   lifters. See F3 for the one harness that does not lift at all.

3. **What is not covered?** See the coverage map below. Headline: `wr-deck.rb`,
   `angled-component-art.rb`, `wr_tools/wr_bridge.rb`, `wr-sun-aim.rb`,
   `explode-view.rb` and all 40-odd one-off client scripts have zero lifted
   methods.

4. **Do the mutation checks hold up?** Mostly yes, and better than documented —
   I emptied `wr-roof-vent.rb`'s `FLUSH_RIGHT_MODELS` (a plausible product
   edit that deletes 32 of that harness's checks) and `rbtest-roofvent.py`
   still went red with 8 failures from *other* checks. But the gate that let me
   try is itself the problem (F1), and there are real vacuous-on-empty
   assertions (F5, F6).

5. **Could a test pass while the product is broken / fail while it is fine?**
   F1 (structural), F2 (proven leak), F4 (loose source-greps), F5/F6 (vacuous
   passes). One fail-while-fine: F7.

---

## Ranked findings

### F1 — HIGH. Seven harnesses pass a run in which **zero assertions executed**

`rbtest-roofvent.py:368`, `rbtest-boothdims.py:472`, `rbtest-takeoff.py:159`,
`rbtest-wall-part.py:167`, `rbtest-doorswing.py:274`,
`rbtest-boothlink-cbl.py:241`, `rbtest-boothlink-v3.py:396` all gate on:

```python
return 0 if got.rstrip().endswith('0 failure(s)') else 1
```

Zero failures out of zero checks reads identically to zero failures out of 96.
None of these seven asserts a **minimum check count**.

*Observed, run.* I replaced the body of the Ruby-side `check` in
`rbtest-roofvent.py` (`$results << [...]` at line 87) with a comment, in memory
only, and re-ran `main()`:

```
=== running with a no-op check() ===

0 failure(s)
EXIT CODE: 0
```

96 assertions silently gone, exit 0, and the only visible signal is that the
transcript is blank — invisible to any automated caller.

How this reaches production for real: these harnesses drive real loops over
real product data (`rbtest-roofvent.py:286` iterates
`RV::FLUSH_RIGHT_MODELS`, `:121/:124` iterate model-name lists,
`rbtest-side-wall-order.py` loops all 50 booth keys). Shrink the data the loop
walks and the checks inside it evaporate. I tested the specific case —
`FLUSH_RIGHT_MODELS = %w[]` — and it was caught by collateral checks, so this
is a **structural hazard I could not yet turn into a live blind spot**
*(derived)*. Contrast the transcript-equality harnesses, which are immune:
`rbtest-autoset.py:430-439` compares against a `' | '.join` of 63 named checks
and prints `expected %d checks, got %d`.

Cheapest fix: each of the seven emits its check count and the Python side
asserts a floor.

### F2 — HIGH. `rbtest-lights.py` runs two programs in one VM, and the second silently inherits the first's stubs

`rbtest-lights.py` boots one VM (`main()`, `lib = rbparse.boot()`) and evals
`FIXTURE` (line 415) then `MODE_FIXTURE` (line 1048) against it. **Both define
a top-level `class FakeModel`.** Ruby reopens a class rather than replacing it,
so `MODE_FIXTURE`'s `FakeModel` keeps `get_attribute` and `set_attribute` from
`FIXTURE` — methods it never declares and never intended to have.

*Observed, run.* I replayed both programs on one VM and probed:

```
FakeModel in program 2 still answers: ["get_attribute", "set_attribute"]
  ; get_attribute('d','current') => nil
```

Why this matters more than it looks: this harness's correctness **depends on
missing stubs raising.** `rbtest-lights.py:417-419` says so out loud —

> "No `Sketchup::Color` stub on purpose: `tag()` guards the color write with a
> rescue, and the stub-less `NameError` proves that guard holds."

For everything in `MODE_FIXTURE` that principle is broken: an unstubbed model
call that `FIXTURE` happened to stub answers quietly instead of raising.
`wr-mode.rb`'s `snapshot`/`apply_snapshot` do not currently call
`get_attribute` (they use `model.shadow_info`, `rendering_options`, `layers`,
`styles` — `wr-mode.rb:175-182`, `:254-275`), so **today the leak is latent,
not live** *(observed)*. `FakeTag` and `FakeLayers` leak the same way.

Fix: name the two classes apart (`FakeModelLights` / `FakeModelMode`), or boot
a second VM. `rbtest-overlays.py:369` already has a hand-written
`lift_leak_check()` for a *different* kind of leak — the awareness exists, it
just has not been pointed at this one.

### F3 — MEDIUM-HIGH. `rbtest-part-orientation.py` transcribes the code under test into Python instead of lifting it

This is the one harness that breaks the project's own rule. It reimplements, in
Python: `wr-deck.rb`'s `bracket_edge` and `build()`'s `t[:edge]`/`half`
(`rbtest-part-orientation.py:86-119`), `wr-overlays.rb`'s `axes_for` and
`wall_transform`, and `build-booth-components.rb`'s `rotation`
(`:391-430`). The file is honest about it — "each rule is TRANSCRIBED from the
file under test ... so a divergence between the two is a real risk and is
stated in the report rather than hidden" (`:6-9`) — and it does read the three
decisive *constants* out of `wr-overlays.rb` source (`:437-452`), so a
`MJP_SPIN180` or `FACE_ROOM[:mjp]` flip goes red.

I diffed the transcriptions against the Ruby and **they currently agree**
*(observed)*: Ruby `[0,1,2].permutation.each` (`wr-overlays.rb:498`) yields the
same lexicographic order as Python `itertools.permutations`; the scoring, the
`best.nil? || err < best[:err]` tie-keep-first, the `nrm` sign, the spin and the
`z_top` seating all match `wr-overlays.rb:496-504` and `:607-644`.

But `MJP_W = 8.39`, `MJP_T = 3.01` and `MJP_TOP_Z = 27.25 + 3.64/2.0` are
**hardcoded in Python** (`:373-375`) against `wr-overlays.rb:172-175`. Change
`MJP_BOX_H` in the Ruby and the harness keeps passing on the old number. And
`build-booth-components.rb`'s real `rotation` is lifted by **no** harness
anywhere — the only thing testing it is this Python copy. *(observed —
`rotation` does not appear in any `rbtest-*.py` lift list.)*

Fix: `rotation`, `axes_for` and `wall_transform` are all module-level
`def self.` methods; they can be lifted the way everything else is. Where a
constant must stay in Python, read it with `const_line` as the same file
already does for `MJP_SPIN180`.

### F4 — MEDIUM. The 1.48.1 zero-scene protection rests on three substring greps that several real regressions would walk straight past

`proposal-package.rb:3691-3693`:

```ruby
def self.open_decision(model_present, _page_count)
  model_present ? :open : :refuse
end
```

The page-count argument is **discarded**. So the five `open1-5` pure checks in
`rbtest-proposal.py` prove only that a method which ignores its argument
ignores its argument. The harness knows this and says so
(`rbtest-proposal.py:1242-1244`: "the open1-5 cases above prove open_decision
ignores the page count; these two prove nothing has quietly re-added a count
test"). The actual protection is `rbtest-proposal.py:1246-1257`, three
substring tests against the text of `run()`:

```python
if 'pages.count.zero?' in run_src or 'pages.empty?' in run_src: ...
if 'five proposal plates' in src: ...
if 'This model has no scenes' in run_src: ...
```

Every one of `if pages.count == 0`, `pages.length.zero?`, `pages.to_a.empty?`,
`unless pages.count > 0`, `if model.pages.size < 1` reintroduces the exact bug
Benton hit within minutes of 1.48.0 and **passes all three greps**. The
wording tests are worse: any rephrasing of the refusal box passes.
*(derived — I did not paste a mutant into `proposal-package.rb`, because this
file is being edited by another agent; see "In flight" below.)*

`rbtest-autoset.py:456-467` uses the same technique for the annotation
allowlist (`SHOWN_BY_PLATE` present, `NEVER_SHOWN` present, no
`HIDDEN_BY_PLATE`) and is the better-designed instance of it: it asserts on
*presence* of the right shape rather than absence of one spelling, so it is
much harder to evade. F4 is about the absence-of-a-spelling half.

The real end-to-end proof of the open gate is
`.forge/builder/verify-autoset.rb:200-207` (Section 0), which calls the live
`WR_ProposalPackage.run` on a zero-page model. That is sound — but it only
runs when a human is sitting in an Untitled model with no scenes, and prints
`SKIP` otherwise (`:328`).

### F5 — MEDIUM. Vacuous-on-empty assertions in `.forge/builder/verify-autoset.rb`

These pass when the thing they inspect is empty or errors, which is the
"passes forever" class:

- **`:403` `walls.objects_never_auto_hidden` is fail-open on error.**
  `hidden?` (`:66-70`) returns `nil` when `e.hidden?` raises, so
  `!hidden?(b1) && !hidden?(b2)` is `true` on a raise. An exception inside the
  check makes the check PASS. The same helper is used fail-*closed* two
  sections earlier (`:389`, `loose_ents.all? { |e| hidden?(e) }` — `nil` there
  correctly flags the plate), so the polarity is inconsistent within one file.
  Compare against `verify-scene-annotations.rb:215` `hidden?(wall) == false`,
  which is explicit and safe. **This is the finding I would fix first in this
  file.** *(observed)*
- **`:252` `empty.autoset_payload_builds`** asserts
  `ap['plan'] && ap['plan']['rows']`. In Ruby `[]` is truthy, so a payload
  whose `rows` came back empty passes. Should be `.is_a?(Array)` plus a length
  or content claim. *(observed)*
- **`:354` `create.stamp_carries_the_centre`** is `set1.all? { ... }`;
  `[].all?` is `true`, so an empty page set passes. Mitigated by
  `create.five_pages` at `:346` failing in the same run — but the check itself
  reports PASS, which is what a human skims. Same shape at
  `verify-scene-annotations.rb:211,217` (`inv6[:loose].all?`).
- **`:474` `say('rows.cost_measured', true, ...)` passes unconditionally.** It
  is a measurement dressed as a check: it computes the deep-read time, prints
  `OVER BUDGET, deep read switches off` when `ms > DEEP_BUDGET`, and **records
  `ok => true` either way**, inflating `ALL N CHECKS PASS`. So the review
  columns can silently switch themselves off and the acceptance run still says
  all clear. Either assert `ms <= DEEP_BUDGET` or print it outside `say`.

### F6 — MEDIUM. Cleanup and state-restore gaps in the two live-model scripts

These run in Benton's SketchUp, so the standard is every failure path.

- **`verify-autoset.rb:480` sets `WR_AutoSet.deep = true` and never restores
  it.** `wr-autoset.rb:978-984` shows `deep` is module state with a lazy
  `true` default, and `:1028` switches it off when a deep read blows
  `DEEP_BUDGET`. The script therefore *re-arms* a setting the product may have
  deliberately disabled on this session, and the `ensure` block (`:518-553`)
  does not put it back. Capture it beside `prev_page`/`prev_tr` and restore it.
  *(observed)*
- **`verify-autoset.rb:260-271`: the real proposal-package window can be left
  open on a failure path.** `WR_ProposalPackage.run` opens a live dialog; it is
  closed at `:266` by `(dlg.close rescue nil)`. If `dialog_alive?` or `say`
  raises between the open and that line, the inner `rescue StandardError`
  (`:268`) records a FAIL and the dialog stays on screen. The outer `ensure`
  closes no dialogs. *(observed)*
- **`verify-autoset.rb:486` `made_pg.concat(pages.to_a)`** puts *every page in
  the model* on the cleanup list. It is saved only by the name/stamp filter at
  `:527-531` (`MINE`, contains `'VERIFY'`, `'Hero for Steve'`, or a
  VERIFY-stamped token), which re-derives ownership anyway. A user scene whose
  name happens to contain `VERIFY` would be erased. Low probability
  (Untitled-only) but the `concat` line earns nothing and should go.
- **`verify-autoset.rb` never forces `ShowTransition = false`.** It captures
  `prev_tr` at `:154` and restores it at `:547` without ever changing it, so
  the restore is a no-op. `verify-scene-annotations.rb:78-79` does force it
  false, and also sets `pg.transition_time = 0` on its own pages (`:106`).
  Today this is harmless — `wr-autoset.rb:742` sets `transition_time = 0` on
  every page it creates, and `:696-697/:870` brackets its own work — so the
  `sel(pg)` reads in Sections 4-5 are instant *(observed)*. But the hand-made
  `mine_pg` (`:333`) gets no such treatment, and the asymmetry between the two
  scripts is a latent timing flake waiting for the first `sel()` on a page
  AUTO-SET did not author.
- **`verify-scene-annotations.rb:270` — seven checks are dead and the total
  silently shrank.** The `clientsafe.*` block is behind
  `if WR_ProposalPackage.respond_to?(:annot_push)`, retired at 1.47.0. It
  prints `SKIP`, which is honest, but `ALL #{@res.size} CHECKS PASS` now
  reports a different N than it did before, so the headline number is not
  comparable run to run and a *further* silent loss of checks would not stand
  out. Either delete the block or pin the expected count.
- Minor: `verify-scene-annotations.rb:107` assigns `made = [...]` only after
  every fixture entity exists, so an exception mid-fixture leaves `made`
  empty. Survivable only because `abort_operation` (`:299`) rolls the open
  operation back. `verify-autoset.rb` uses `made.concat` progressively — the
  better pattern.

### F7 — LOW. Two checks that fail while the product is fine

- **`rbtest-overlays.py:369-398` `lift_leak_check` is brittle both ways.**
  `if n != 2` on `builder.count('booth.transformation')` goes red the moment
  anyone adds a legitimate third mention (a log line, a comment). And it is
  *loose* in the other direction: `'booth.transformation' not in
  builder.split('def self.build_booth')[-1]` takes everything after the last
  occurrence of that string, which is "the rest of the file", not "inside
  `build_booth`". It reads as a containment test and is not one. It happens to
  be correct today only because `build_booth` is the **last** `def self.` in
  `build-booth-components.rb` (line 2289 of 3042) *(observed)* — add any method
  after it and the check stops meaning what it says.
- **`rbtest-srgb.py:489` `'truncated': ''`** reduces to `'refused:' in ln`,
  because `'' in ln` is always true. Deliberate and commented ("any named
  reason; must just refuse"), so: accurate label, zero content.

### F8 — LOW severity, widest blast radius. Nothing requires the harnesses to be run

`CLAUDE.md:296-300` mandates `rbparse.py` before committing any Ruby change and
correctly warns against trusting `rbcheck.py`. It says **nothing about the 21
`rbtest-*.py` harnesses.** There is no `.github/` directory, no CI, and no
single command that runs the suite — I had to invoke all 21 by hand. The
project already knows the cost: `rbparse.py:129-131` records that
"`rbtest-lights.py` sat red for two weeks over an unlifted constant nobody could
see the name of."

A 20-line `scripts/rbtest-all.py` that shells each harness, prints its exit
code, and fails on any non-zero would close this. It is the highest
value-per-line change in this audit.

---

## Coverage map — 75 Ruby files against 21 harnesses

Counted as module-level `def self.` methods in the file vs. methods named in a
lift call by the harness that targets that file. *(observed, scripted)*

| file | lines | methods | lifted | note |
|---|---|---|---|---|
| `scripts/proposal-package.rb` | 6366 | 116 | 30 | `rbtest-proposal.py` + `jstest` |
| `scripts/wr-drop-lights.rb` | 4266 | 128 | 54 | `rbtest-lights.py` — best ratio of the big four |
| `scripts/build-booth-components.rb` | 3042 | 44 | 8 | `rbtest.py`, `rbtest-wall-part.py`, `rbtest-side-wall-order.py` |
| `scripts/wr_tools/main.rb` | 1937 | 92 | 20 | `rbtest-panel-prefs.py` — preference layer only |
| `scripts/wr-deck.rb` | 1740 | 24 | **0** | transcribed in Python (F3) |
| `scripts/angled-component-art.rb` | 1733 | 48 | **0** | — |
| `scripts/wr-overlays.rb` | 1620 | 29 | 19 | `rbtest-overlays.py` — best-covered large file |
| `scripts/dimension-whisperroom.rb` | 1329 | 52 | — | `rbtest-boothdims.py` lifts the marked PURE SECTION, lines 100-553 (~34% of the file); the writer half is untested |
| `scripts/wr-scene-annotations.rb` | 1199 | 39 | ~2 | live script only |
| `scripts/wr-scene-walls.rb` | 1007 | 37 | ~1 | live script only |
| `scripts/wr_tools/wr_bridge.rb` | 814 | 33 | **0** | — |
| `scripts/wr-sun-aim.rb` | 700 | 13 | **0** | — |
| `scripts/explode-view.rb` | 557 | 23 | **0** | — |
| `scripts/wr-png-srgb.rb` | 438 | 20 | n/a | `rbtest-srgb.py` `load`s the **whole file** and runs `encode_file` end to end — the strongest harness in the repo |

### The gaps I would rank by blast radius

1. **`wr_tools/main.rb`'s one-click updater is untested, and one of its two
   pure methods has a documented past bug.** `newer?`
   (`wr_tools/main.rb:279-296`) is 15 lines of pure integer comparison, gates
   the update banner for every user including Gabe, and carries a comment
   about the exact defect it fixes ("`1.10.0` is NEWER than `1.9.0`. String
   compare gets that backwards"). It is **not** in `rbtest-panel-prefs.py`'s
   lift list (verified: that harness covers `blank?`, `inherited_slots`,
   `merge_slots`, `own_icons`, `own_list`, `own_slots`, `pad`, `pinned`,
   `read_list`, `read_pref`, `set_slot`, `shop_list`, `shop_slots`,
   `slot_icons`, `slots`, `toggle_pin`, `unset?`, `write_list`, `write_pref`,
   `write_slots` — no `newer?`). It is the single cheapest high-value test in
   this repo: a 20-line addition to the existing harness. *(observed)*
   `update_now` (`:344-410`) writes and executes a `.bat` built by string
   concatenation from `repo_dir` and is also untested; a `%` or `"` in the
   checkout path would be re-parsed by `cmd`. That is a product observation
   outside my dimension, flagged and not pursued.
2. **`wr-deck.rb` (1740 lines, 24 methods, zero lifted).** The deck pass
   places floors and ceilings on every booth. Its only check is the Python
   transcription in F3.
3. **`wr-scene-walls.rb` and `wr-scene-annotations.rb`** — the two writers
   AUTO-SET calls (`.forge/builder/verify-autoset.rb` header names them
   explicitly as "proves NOTHING about the writer"). Their only evidence is
   `verify-scene-annotations.rb`, which a human must paste into a Ruby Console
   in an Untitled model. `pages_not_saving`, `inventory`, `keys_for_selection`
   and `move_selection_to_set` all have pure-data halves that could be lifted.
4. **`build-booth-components.rb`: `rotation`, `wall_slab`, `classify`,
   `flat_placement`, and the whole `iep_*` family** (`iep_half_turn?`,
   `iep_room_proud`, `iep_upside_down?`, `iep_vent_yaw`, `iep_wall_lift`, …)
   are pure or near-pure and none is lifted. `rbtest.py`'s own `fixture_noise`
   docstring records that a `wall_slab` bbox-noise defect "silently stretched
   both E and W inner walls by an eighth of an inch" — and `wall_slab` itself
   still has no test.
5. **`proposal-package.rb`'s 86 unlifted methods** include `gather`,
   `state`, `row_states`, `mode_of`, `output_size`, `sidecars`, `save_frame`,
   `push_undo`, `collect_annotations`, `collect_hidden_annotations`,
   `page_hidden_tags`. Several are pure or nearly so. Given this is the
   client-facing export path, `output_size`, `sidecars` and `page_hidden_tags`
   are the ones I would lift next.

## What is genuinely good (so it does not get "simplified" away)

- **`rbtest-srgb.py`** `load`s the real `wr-png-srgb.rb` and runs
  `encode_file` end to end on PNG fixtures built in Python, then re-verifies
  every output byte in Python with real `zlib`. Only the three `zlib` seams are
  shimmed, with real stored-block streams. This is the model the rest should
  aim at.
- **`jstest-proposal-dialog.js`** applies the heredoc `\\`→`\` unescape before
  parsing, runs the init path under a fake DOM whose `getElementById` returns
  `null` for ids the HTML lacks, and *names the absent ids* on failure. It
  exists because `node --check` passed while the real window was broken. That
  is a lesson learned the expensive way and encoded.
- **The exact-transcript gate** (`rbtest-autoset.py:430-439` and siblings):
  compares a `' | '.join` of N named checks and reports `expected %d checks,
  got %d`. Immune to F1 by construction.
- **Loud lifters.** Every `SystemExit` message names the file, the symbol and
  what to do. `rbparse.py:128-136` surfaces the real Ruby exception class and
  backtrace frame instead of "the harness raised".
- **`rbcheck.py`'s docstring** tells you not to use it. Rare and correct.

## In flight — do not act on these without checking with the other agent

`scripts/proposal-package.rb` (21:44), `.forge/builder/verify-autoset.rb`
(21:45) and `scripts/jstest-proposal-dialog.js` (21:46) were all modified
within minutes of this audit, and `VERSION` reads 1.48.1. The zero-scene work
is already landed in `verify-autoset.rb` (Section 0, `:200-330`) and in
`jstest-proposal-dialog.js` (the zero-row grid and disabled-Export checks).
`scripts/rbtest-autoset.py` is older (20:20) and its `NAMES` list carries no
zero-scene group — that is presumably the piece still being written.

- **F4 is the finding most likely to be in flight.** If the other agent is
  adding zero-scene coverage to `rbtest-autoset.py`, the right home for a
  stronger open-gate check is there, not in `rbtest-proposal.py`. Do not paste
  mutants into `proposal-package.rb` while it is open elsewhere — I did not.
- **F5's `empty.autoset_payload_builds` (`verify-autoset.rb:252`)** sits inside
  the brand-new Section 0, so that truthiness bug is hours old and cheap to fix
  now.

## Recommended order of work (none of it done — this is a read-only audit)

1. `scripts/rbtest-all.py` — one runner, fails on any non-zero exit (F8).
2. Assert a check-count floor in the seven `0 failure(s)` harnesses (F1).
3. Fix `verify-autoset.rb:403` fail-open `hidden?` polarity, `:474`
   unconditional pass, `:252` truthiness, and restore `WR_AutoSet.deep` in
   `ensure` (F5, F6).
4. Rename `FakeModel` apart in `rbtest-lights.py` (F2).
5. Lift `newer?` into `rbtest-panel-prefs.py` (coverage gap 1).
6. Lift `rotation`, `axes_for`, `wall_transform` and read `MJP_*` from source
   in `rbtest-part-orientation.py` (F3).
7. Replace F4's three substring greps with a positive-shape assertion in
   whichever harness the zero-scene work lands in.

===REPORT===

**Dimension audited:** test integrity — do the harnesses bite?

**Verdict:** The safety net is real, unusually well-documented, and green today
(21/21 harnesses, `rbparse` on all 75 files, `jstest`, `live-booth selftest` —
all exit 0, run by me). The assertions are genuine, the verbatim-lift mechanism
fails loudly and by name, and `rbparse.py`'s "parsing is not working" line is
correctly understood by every caller. The weakness is perimeter, not rigour:
roughly two thirds of the Ruby tree has no offline check, and nothing obliges
anyone to run the checks that exist.

**Findings:** 8 — 2 high, 4 medium, 2 low.
Two proven by my own in-memory mutation runs (F1 zero-assertion pass, F2
`FakeModel` cross-program leak). No file in the repository was modified except
this report.

**Highest single-line risk:** `.forge/builder/verify-autoset.rb:403` —
`walls.objects_never_auto_hidden` passes when `hidden?` raises, because the
helper returns `nil` and `!nil` is `true`. An error in the check makes the check
green, in the one script that is this project's only live end-to-end evidence.

**Cheapest highest-value fix:** `scripts/rbtest-all.py`, ~20 lines, plus a line
in `CLAUDE.md` requiring it alongside `rbparse.py`.

**Not covered:** engineering correctness of the asserted numbers; Python-only
tools; `eval/`; the V-Ray lane beyond `wr-png-srgb.rb`; `clients/*.rb`;
`rbtest-live-booth.py`'s SketchUp-requiring commands. No mutant was written
into any product file — `scripts/proposal-package.rb` is being edited by
another agent, so F4 is argued from reading, tagged *derived*, not from a run.
