# HANDOFF — proposal-package blockers, 1.9.6 (30 Aug 2026)

Fixer pass against `.forge/auditor/proposal-package-audit-2026-08-30.md`.
Changed: `scripts/proposal-package.rb`, `scripts/rbtest-proposal.py`,
`scripts/wr_tools/VERSION` (1.9.4 -> **1.9.6**; 1.9.5 was claimed by the lighting lane),
`DEVLOG.md`.

**No SketchUp and no V-Ray were touched.** The lighting sweep held SketchUp 2026 for the whole
of this session; no bridge job was sent, and `scripts/wr-drop-lights.rb`,
`scripts/rbtest-live-booth.py` and `.forge/builder/booth-matrix/` were not read or written.

Provenance: **observed** = I ran it here; **derived** = read off the code; **reported** = from
a handoff or the audit.

---

## The five, and what proves each

| # | Defect | Fix | Proof |
|---|---|---|---|
| 1 | **BLOCKER** — `require_render_size!` (:331) judged `@size_source` at :774; `honoured_size` set it at :942, past the gate's own `return`. Every render batch refused on every press, permanently. | New `render_size_gate(width_field, has_render_row)` — READ then JUDGE, one method. `start_run` calls it where the gate was; the :942 read is gone. | **Offline, observed.** `gate1`–`gate4` in the suite. Mutation-checked: swap the two lines back and `gate1`, `gate2` FAIL. |
| 2 | `annot_push` (:1235) assigned `@annot_saved` **after** the hide loop and nil'd it on rescue — a partial failure left tags hidden with no record, and logged the opposite of what happened. | Hash published to `@annot_saved` **before** the first flip, filled in place, each entry written before its tag is touched. Rescue message now names both halves: N recorded and restorable, M never reached and still visible. | **Offline, observed.** `annot1`–`annot4` on a fake model whose third layer raises. Mutation-checked: move the assignment back and `annot1`, `annot3`, `annot4` FAIL. |
| 3 | A lost row still reported `0 FAILED` and `Done. Model restored.` — headline counted `@results` only, and only `lines.first` reached the dialog. | New pure `lost_rows(plan_files, result_files)`, read by **both** the headline and the closing verdict. The **whole** summary now goes to the run window. Verdict says the pack is INCOMPLETE. `@plan_files` cleared at the end of `finish`. | **Offline, observed.** `sum1`–`sum3`, `lost1`–`lost3`. Mutation-checked: headline counting `@results` only makes `sum1` FAIL. |
| 4 | F5 — `mark`, `bulk`, `setfill`, `activate` had no `@running` guard in Ruby. | `next if busy?(d, '<name>')` on all four; `busy?` refuses out loud on the console and in the run log. | **Offline, observed** for the predicate (`busy1`–`busy3`, mutation-checked). The *placement* of the four guards is verified by reading only — **derived**, not executed. |
| 5 | The bare `UI.messagebox` at :1890 (the restore-failure box), which made `finish` run twice and latch `@running`. | Wrapped in `begin/rescue Exception`, and `finish` given a re-entrancy guard (`@finishing`, cleared in an `ensure` only by the call that set it). | **Derived.** Code-read only; the raising-messagebox path is not reachable offline. |

`python scripts/rbparse.py` → 59 files parse (**observed**).
`python scripts/rbtest-proposal.py` → **81/81 PASS** (**observed**), up from 64.

---

## The sixth defect — verified, real, NOT fixed

**`reset_stale_batch` can flip a model it never touched. Confirmed.**

`@saved_mode`, `@prev_page` and `@prev_cam` are assigned **only** at `proposal-package.rb`
:992-995, inside `start_run`, and are **never cleared anywhere in the file** (grep: those are
the only assignments). `reset_stale_batch` (:~2100) calls `finish` without re-capturing, and
`finish` computes `mode_restore_target(@saved_mode)`. So:

- `@saved_mode` nil (the flag latched before :992) → target resolves to `'draft'`, `@mode_now`
  is nil ≠ `'draft'`, and **`WR_Mode.to_mode(model, 'draft')` runs a full materials swap and
  tag flip on a model this batch never touched**;
- `@saved_mode` stale from a previous batch → same, to the previous batch's mode;
- `@prev_page` / `@prev_cam` stale → the model also jumps to a scene and camera from an
  earlier session.

Benton's visible experience: press the button, see *"a batch is already running"*, answer
**Yes** to clear it, and his current model silently changes materials, flips the dimension
tags, and jumps to a scene from hours ago. Only the mode change is announced, and only on the
Ruby console. **Same silent-mutation family as findings 2 and 4 — I would rank it with them,
not below them.**

Left alone deliberately: the honest fix is a `@state_captured` flag distinguishing "this batch
captured state" from "nothing was ever captured", because `finish`'s nil→`'draft'` fallback is
load-bearing for the F3 fix and must not simply be removed. That is a design change, not a
one-liner, and the brief said verify and report. **It should be the next thing fixed.**

---

## `scripts/image-qa.py` — a separate job, and I did not touch it

Confirmed by grep: `image-qa.py` is referenced by `scripts/lookdev-drive.py` and
`scripts/lookdev-matrix.rb` only. `proposal-package.rb` does not call, mention or import it.
Pass 2's "all five images pass the gate" was run **beside** the package, not by it.

Wiring it in is **not** this job. It needs decisions nobody has made: what a failing image does
to a row (fail it? warn? refuse the pack?), whether a Python subprocess may run inside a
SketchUp timer tick at all, and what the thresholds are for a legitimately dark interior. It is
a real gap — a pack built today ships whatever came out of the VFB, blown or black — but it is
a feature with a spec, not a defect fix. **Recommend a separate pass with its own brief.**

---

## What is proven, and what is not — plainly

**Proven, offline only (every fix on this page).** The suite runs the real methods in the
barebones CRuby VM `rbparse.py` boots out of SketchUp's DLL. That VM is not SketchUp: it has no
model, no V-Ray, no dialog, and — found today — **no `Object#class`** (`1.class` raises
`NoMethodError`), which is why lifted rescue paths need `FakeError`. Reopening `StandardError`
to add the method breaks `raise` in that VM; don't.

**Not proven by anything here:**

- the real `UI::HtmlDialog` path, end to end. Unchanged from the audit.
- the four `busy?` guards firing on a live callback dispatched mid-render.
- the restore-failure messagebox path (finding 5) — it only runs when a restore has already
  failed, which has not happened here.
- that the render lane now actually **starts**. The gate no longer refuses a readable size in
  the VM; whether V-Ray answers `/SettingsOutput` on Benton's machine at the moment the button
  is pressed is still **reported**, from earlier handoffs.

**The step that settles it has still never happened: one batch, driven by Benton through the
real Export button, on a scratch model that has never been mode-toggled** — two render rows and
two image rows — with the model inspected afterwards for mode, materials and tag visibility,
and the four files opened and looked at. Until that runs, 1.9.6 is a set of code-read fixes
with an offline suite behind them, and nothing more.

## What I did not do

- Did not fix finding 6 (`reset_stale_batch`), 7 (`warn_output_size`'s false log line), 8
  (nested `start_operation`), 9 (`image-qa.py`), 10 (sidecars), 11 (`camera.clone`), 12 (the
  three stale comments) or 13 (the unclamped honoured width). Findings 7 and 12 are cheap and
  are the audit's own "fix next"; 6 is the one I would do first.
- Did not extend coverage to `step`/`step_body`, `finish`'s restore order, or
  `plan_names`/`uniquify`/`sanitize`. `plan_names` is pure and trivial to test and is still the
  largest cheap gap in the suite.
- Did not run anything in SketchUp, and did not go near the lighting lane's files.
