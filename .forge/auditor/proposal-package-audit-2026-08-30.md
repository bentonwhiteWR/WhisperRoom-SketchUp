# Proposal-package audit — 2026-08-30 (plugin 1.9.4)

Auditor pass over `scripts/proposal-package.rb` (2625 lines) and its lanes and gates:
`export-scenes.rb`, `wr-mode.rb`, `wr-materials-swap.rb`, `image-qa.py`,
`rbtest-proposal.py`. Read against `.forge/GOAL.md`, the 28 Aug render-lane audit,
and the three builder handoffs (`HANDOFF-endtoend`, `-pass2`, `-lookdev`) with their
results JSON.

READ-ONLY: no production file was changed. Provenance tagged **observed** (I read or
ran it myself), **derived**, **reported** (from a handoff or Benton), **assumed**.
No SketchUp and no V-Ray on this session — everything live is second-hand.
`python scripts/rbtest-proposal.py` → PASS, 64/64 (**observed**, run today).

---

## STOP — read this before pressing the button

**The render lane cannot start. Not "sometimes"; not "on a cold session". Every batch
with a render row in it is refused, on every press, forever, with a message that names
the wrong cause.**

`start_run` asks `require_render_size!` for permission at **line 774**. That method
reads `@size_source`. `@size_source` is written by `honoured_size`, which is not called
until **line 942** — 168 lines later, inside the same method, past the refusal. On a
fresh load `@size_source` is `nil`, so the gate refuses; because it refuses by
`return`ing out of `start_run` before line 942, `@size_source` is never set, so the next
press refuses identically. It is a closed loop.

**Observed** — I lifted `require_render_size!` verbatim and ran it in the CRuby VM
`rbparse.py` boots out of SketchUp's own DLL, with `@size_source` never assigned:

```
REFUSED -> V-Ray is being asked to render, but its output size could not be read...
```

The message tells Benton to open the V-Ray Asset Editor and confirm the render output
size. Doing that will not help, because nothing reads it before the refusal. This is a
loud failure, not a silent one, and that is the only good thing about it.

It also explains why nobody caught it: `honour_test.rb` (reported, HANDOFF-lookdev)
called `honoured_size` **and then** `require_render_size!`, in that order, by hand. That
is the one order in which the bug is invisible. The button uses the other order.

---

## Benton's question, answered

**No. The proposal package does not work well today, and the render half of it does not
work at all — pressing Export on any batch containing a Render row gets a refusal box
and nothing else.** The image lane is in good shape and is the part that has actually
earned trust; the render lane has been improving fast on genuinely hard problems, but
1.9.4 shipped a launch-path blocker plus four ways to leak or mis-report, and it has
still never been driven once by a human clicking the button.

---

## Ranked findings

Ranked by probability × cost. Silent wrong output outranks loud failure.

### 1 — BLOCKER, certain, loud: the render lane is unreachable from the button
**File:** `scripts/proposal-package.rb:331-338` (definition), **:774** (call),
**:941-942** (the assignment that comes too late).
**Confirmed** — read, plus the method executed offline (above).

**Scenario.** Fresh SketchUp session, load the plugin, mark scene 01 Render, press
Export package. `live.any? render` is true → `require_render_size!` → `@size_source` is
`nil` → `nil.to_s.start_with?('the V-Ray')` is false → refusal string → `UI.messagebox`
→ `return`. No file written, no log line, nothing on the console. Press again: same.
Restart SketchUp: same. There is no input that reaches line 942 with a render row
present.

**Cost.** The entire render lane, which is the whole point of 1.9.4, plus a support
question that sends Benton into the Asset Editor to fix something that is not broken.

**Note on shape.** Image-only batches are unaffected — the gate is inside
`if live.any? { |r| r['mode'] == 'render' }`. So the tool half-works, which is worse
for diagnosis than if it failed outright.

---

### 2 — HIGH, silent, leaked mutation: a failed annotation hide leaves tags hidden forever, and says the opposite
**File:** `proposal-package.rb:1215-1240` (`annot_push`), **:1242-1251** (`annot_pop`).
**Confirmed** in code.

`annot_push` hides tags one at a time in a loop and assigns `@annot_saved = saved`
**after** the loop. Its `rescue` sets `@annot_saved = nil`. So a raise partway through
the loop leaves N tags already hidden with **no record of what they were**, and
`annot_pop`'s first line is `return if @annot_saved.nil?` — it no-ops. `finish`'s pop at
:1825 is guarded by `if @annot_saved` and no-ops too.

**Scenario.** A model where one of `WR_Mode::ANNOT_TAGS` is a locked or deleted-mid-run
layer, or `l.visible = false` raises for any reason, on the third of five tags. Result:
`WR-Dims` and `WR-Dims-Doors` are switched off in Benton's model and stay off after the
batch ends, through the save, into the next session. Nothing restores them and nothing
says they are off.

**Worse:** the message it logs is *"construction annotation may be visible in this
image. Check before sending."* — the exact opposite of what happened. Whoever reads that
log will inspect the image (which is fine) and never look at the model (which is not).

**Class check, as asked.** This is the same shape as the `restore!`-lied-about-restoring
defect the lookdev author flagged: state captured and state mutated are not the same
transaction. `apply_exposure` (:1650-1655) and the `@vray_saved` capture-once discipline
get this right; `annot_push` does not.

---

### 3 — HIGH, silent-at-the-top: a lost row still reports "0 FAILED" and "Done. Model restored."
**File:** `proposal-package.rb:1904` (only `lines.first` reaches the dialog),
**:1907-1914** (the dialog verdict), **:1958** (the headline), **:1973-1980**
(the reconciliation, which is correct).
**Confirmed** in code.

D8's reconciliation genuinely works and genuinely names a vanished row. But:

- the **headline** at :1958 counts `fails` from `@results` only, so a row that produced
  no result at all does not increment it — the top line still reads `0 FAILED`;
- the **dialog** only ever receives `lines.first` (:1904), i.e. the headline. The
  `*** N PLANNED ROW(S) PRODUCED NO RESULT AT ALL` block never reaches the run window;
- the dialog's closing verdict (:1908-1914) is chosen from `fails`, so it says
  **"Done. Model restored."** on a batch that lost a row.

**Scenario.** Five rows planned, an exception inside the poll loop kills the batch after
three. Console and the summary messagebox tell the truth. The window Benton was watching
says `PROPOSAL PACKAGE — 3 exported, 0 skipped, 0 FAILED` and `Done. Model restored.`
He closes it, opens the folder, and the pack is short one render.

That is 1.9.2's D1 failure signature reproduced by a different mechanism. The
re-entrancy cause is fixed; the *reporting* that made it invisible is only half fixed.

---

### 4 — HIGH, silent: dialog callbacks are still unguarded, and the message loop is now known to pump
**File:** `proposal-package.rb:2148` (`setfill`), **:2160** (`activate`), :2123 (`mark`),
:2134 (`bulk`); JS handlers at the `drawMats` select and the `data-go` button.
**Confirmed unfixed** — this is the 28 Aug audit's F5, untouched.

Four Ruby callbacks mutate model state and **none of them checks `@running`**. On the JS
side, `mark` and `bulk` check a `running` flag; the `setfill` select handler and the
`activate` arrow check nothing at all.

Two things make this materially worse than it was on 28 Aug:

- `VRay::Command.render_production` **pumps the Windows message loop** — that is
  **observed**, it is the documented mechanism of the D1 nested-tick bug. So callbacks
  dispatched from that same loop during a 6-minute render are not speculative any more.
  (That CEF action callbacks ride the same pump as SketchUp timers is **derived**, not
  observed.)
- the JS `running` flag is set by `runStarted()`, whose failure is rescued and ignored
  (:982-986) — and it **has been observed to fail**. When it does, every button in the
  window stays live for the whole batch with only the Ruby side, which has no guard.

**Scenario A (silent, worst).** Benton changes the Floor slot dropdown while row 02
renders. Slot fills are read live from the model dictionary, so `finish`'s
`WR_Mode.to_mode(model, 'draft')` → `WR_MaterialsSwap.to_draft` looks for surfaces by
the *new* fill name, finds none, and every floor face stays on the render material. The
`:left` report only names surfaces found on a configured fill, so nothing is said. The
model is left painted for render and the batch reports clean.

**Scenario B.** Benton clicks a row's go-arrow inside the ~0.4 s window while
`render_production` is exporting. The camera assert has already passed. The row renders
the wrong view — the exact 28 Aug bug, resurrected through the one door left open.

---

### 5 — MED-HIGH: `finish` still has one unguarded `UI.messagebox`, and it is the one that fires on a bad day
**File:** `proposal-package.rb:1890`.
**Confirmed** in code.

P2-2 guarded the *closing* box (:1938-1943) and moved `@running = false` above it. Good.
But the restore-failure box at :1890 — the one that runs only when something has
*already* gone wrong — is bare. Under a caller whose `UI.messagebox` raises (the bridge
muzzles modals; **reported**, and observed to have caused exactly this once), or any
other modal failure, it raises out of `finish`, into `step_body`'s rescue (:1156), which
calls `finish` a second time: mode restore runs twice, and `@running` never comes down
because line 1935 is never reached.

`finish` has no re-entrancy guard of its own, so nothing structural prevents this.

**Cost:** a completed batch that claims to be running, needing the stale-reset path —
which is itself finding 6.

---

### 6 — MED, silent mutation: `reset_stale_batch` restores a model it never touched, from a previous run's snapshot
**File:** `proposal-package.rb:2025-2040`, consuming `@saved_mode` / `@prev_page` /
`@prev_cam` set at :948-951 and never cleared.
**Confirmed** in code. Introduced by the F3 fix.

`reset_stale_batch` calls `finish` without re-capturing state. `finish` then computes
`mode_restore_target(@saved_mode)`; when `@saved_mode` is `nil` (flag latched before
line 948, e.g. by a raise between :907 and :991 — a documented hazard) or is a stale
value from a previous batch, the target resolves to `'draft'` and `@mode_now != target`
is true, so **`WR_Mode.to_mode(model, 'draft')` runs a full materials swap and tag flip
on a model this batch never touched.** `@prev_page` and `@prev_cam` are likewise stale,
so the model also jumps to a scene and camera from an earlier session.

**Scenario.** Benton presses the button, sees "a batch is already running", answers Yes
to clear it. His current model silently swaps to drafting materials, flips the dimension
tags, and jumps to whatever scene was selected when a run three hours ago started. Only
the mode change is announced, and only on the Ruby console.

---

### 7 — MED: `warn_output_size` states, on every render batch, a size the batch will not use and a write it will not make
**File:** `proposal-package.rb:1412-1431`, called at **:988**.
**Confirmed** in code.

It was written for 1.9.3, when the tool wrote `/SettingsOutput`. It was not updated for
1.9.4. It computes `package_size(@cfg['width'])` — the **4:3 fallback shape**, from the
already-honoured width — and logs:

> `RENDER SIZE: V-Ray is at 1600x900; this batch will set it to 1600x1200 - the same
> size the image rows use, and it is put back at the end of the batch.`

Every clause after the semicolon is false. The batch sets nothing, does not use
1600×1200, and puts nothing back. **Derived** arithmetic: `package_size('1600')` →
`[1600, 1200]`; the value passed in is `out_w`, i.e. 1600, not the typed field.

This is not cosmetic. 1.9.4's entire claim is *"the settings are yours and the log says
what was used."* The first render-lane line in that log contradicts it, and it is
louder (`'dim'` header, definite verb) than the correct line that follows from
`unit_vray_audit`. A wrong audit trail is worse than none.

---

### 8 — MED, unfixed since 28 Aug: `WR_Mode` nests `start_operation` inside `start_operation`
**File:** `wr-mode.rb:272` opens an operation; `wr-materials-swap.rb:178` / `:216` open
and **commit** their own inside it.
**Confirmed unchanged** — this is F6, untouched by 1.9.2/1.9.3/1.9.4.

SketchUp operations do not nest; a new one implicitly closes the open one (**reported**,
long-standing API behaviour, not verified here). If that holds: the advertised "one
Ctrl+Z undoes the whole flip" is false, and a raise after the swap leaves
`abort_operation` with the wrong thing open — materials swapped, tags not — which is
precisely the state `wr-mode.rb` exists to prevent. Masked inside a batch by `finish`'s
mode restore; bare on a standalone Toggle press.

`to_mode` also rescues only `StandardError` (:304-307), so a non-StandardError leaves
the operation open outright.

---

### 9 — MED: nothing in the product path ever looks at a pixel
**Confirmed** by grep: `scripts/image-qa.py` is referenced only by
`scripts/lookdev-drive.py` and `scripts/lookdev-matrix.rb`. `proposal-package.rb`
does not call it, mention it, or import it.

Pass 2's "all five images pass the new automated image gate" is true and was a real
check — but it was run **beside** the package by the builder, not by it. A pack produced
by the button today ships whatever came out of the VFB, blown or black, with no gate.
The 28 Aug empty-frame batch would still pass every check the tool itself performs
(the latch stops *that* specific failure, but not a legitimately-rendered black frame).

---

### 10 — LOW-MED: sidecars are named, not managed
**File:** `proposal-package.rb:1732-1738` (`sidecars`), :1771-1781 (the report).
**Confirmed** in code; the sidecar behaviour itself is **reported** from pass 2.

With the denoiser off — Benton's own setting, and 1.9.4 no longer switches it on — there
are no sidecars today, so this is dormant. Switch the denoiser on in the Asset Editor
and `<name>.denoiser.png` / `<name>.effectsResult.png` land beside every render, outside
the collision map and outside the Ask/Overwrite/Skip policy. `sidecars()` globs
**after** the save, so a *stale* sidecar from a previous run is reported as if this run
produced it. And the saved frame remains the RGB channel, ~7% noisier than the denoised
sidecar (**reported**, measured pass 2) — i.e. with the denoiser on, the tool saves the
worse of the two files it just made.

---

### 11 — LOW: `@prev_cam = camera.clone` may alias the live camera
**File:** `proposal-package.rb:951`. **Unchanged since 28 Aug; still unverified either
way** (F8). If `clone` copies the wrapper and not the C++ camera, `finish`'s camera
restore is a no-op and pre-batch viewport drift is lost. Small blast radius —
`selected_page` is restored first — but it is a one-line console check nobody has run.

---

### 12 — LOW: the file now documents behaviour it no longer has
**Confirmed** in code. `QUALITY` (:192-201) is defined, commented at length as the
sampler/denoiser values "now OWNED: written into the V-Ray scene", and **never
referenced anywhere**. The ASPECT block (:119-128) says "the V-Ray SCENE's
`/SettingsOutput` is written to the same numbers (see `apply_output_size`)" — a method
that does not exist. `warn_output_size`'s header (:1400-1411) says `unit_vray_setup now
WRITES /SettingsOutput`; that method was renamed to `unit_vray_audit` and writes nothing.

The next agent to read this file will read three confident, wrong statements about the
one behaviour Benton personally ruled on. That is how the setting-stomping bug comes
back.

---

### 13 — LOW: an honoured width outside 200–6000 splits the two lanes
`export-scenes.rb:205` clamps to 2400; `honoured_size` does not clamp. A V-Ray output
width above 6000 makes the image lane export 2400-wide while the render lane uses
V-Ray's. Named in the row detail (the real width is reported), so loud, not silent.
**Confirmed**, dormant at 1600.

---

## The 28 Aug audit's ten findings — actual disposition

I checked each in the code as it stands rather than taking "fixed" from a handoff.

| # | Was | Now | Closed on |
|---|---|---|---|
| **F1** `:fatalError` reads as RUNNING | HIGH | **Closed in code.** `ERROR_STATE = /error/i` (:582), checked before the idle family in `classify_render` (:631); poll loop fails by name (:1105-1110). Offline cases 15–20. | **Code + unit test only. It has never fired.** No render has reached an error state (reported, endtoend JSON). Correct-looking, unproven. |
| **F2** cold-session no-op `start` | HIGH | **Genuinely closed, and better than the audit guessed.** Root cause was not cold-start: `renderer.start` never exports the model, so it rendered an empty scene. `VRay::Command.render_production` exports first. | **Evidence** — observed 3× each (reported, HANDOFF-endtoend), with byte counts. The strongest close on the list. |
| **F3** mode restore skipped on a never-toggled model | MED-HIGH | **Closed in code** (`mode_restore_target`, :305-307, :1848-1863) and the bug was **observed live** before the fix. | Evidence for the bug, **code only for the fix** — and the fix introduced finding 6. |
| **F4** `save_vfb_image` Boolean ignored | MED | **Closed.** Target deleted first (:1742), Boolean checked (:1755), `:skip_alpha`/`:no_alpha` passed (:1748). Verified live (reported). | **Evidence.** Surfaced the new sidecar problem (finding 10). |
| **F5** dialog callbacks live during the batch | MED | **STILL OPEN. Not touched.** See finding 4 — and now likelier to fire. | — |
| **F6** nested `start_operation` | MED | **STILL OPEN. Not touched.** See finding 8. | — |
| **F7** failure messages omit the raw state | LOW-MED | **Closed.** `@last_state` captured (:1087) and appended to every `fail_render_row` (:1682). `:idleFrameDone` policy deliberately pinned by case 20. | Code + test. Cheap and correct. |
| **F8** `camera.clone` may alias | LOW | **STILL OPEN**, unverified. See finding 11. | — |
| **F9** output size | LOW | **Half closed.** Which `/SettingsOutput` governs is now **observed** (:702-725). The Asset-Editor-1600-vs-2400×1350 mystery is untouched — the Asset Editor was never opened (reported). | Evidence for the half that was answered. |
| **F10** timer/single-exit residuals | INFO | **Half closed.** The closing messagebox is guarded and `@running` comes down first (:1935-1943). The restore-failure messagebox at :1890 is not — finding 5. | Code. The half that was fixed was fixed *because it fired live*; the identical half beside it was left. |

**Summary: 5 genuinely closed (F2, F4, F7, and the fixed halves of F9/F10), 3 still
fully open (F5, F6, F8), 2 closed on reasoning rather than evidence (F1, and the fix
half of F3).**

---

## Is the offline suite constraining the behaviour that matters?

**No. It constrains the pure half, and every defect of the last month has lived in the
other half.**

64 checks, all green (**observed**, run today). All of them hit ten pure functions:
`classify_render`, `read_signal`, `cam_mismatch`, `ev_for`, `shutter_for_ev`,
`ev_of_camera`, `mode_restore_target`, `package_size`, `autorun?`, `launch_decision`,
plus `export-scenes.out_height`. That work is good — the classifier table is genuinely
well covered, the mutation-check notes in the header are real discipline, and cases
15–20 pin states nobody has seen.

**What has no coverage at all:**

- `start_run`'s ordering — the one line of sequencing that decides whether the render
  lane can start. Finding 1 would fall out of a three-line test.
- `step` / `step_body` — the D1 re-entrancy split. The bug that cost a render row is
  guarded by a code comment and nothing else.
- `finish`'s restore order and its two messagebox sites.
- **`plan_names` / `uniquify` / `sanitize`** — the FILE-column contract the file header
  calls central ("the column can never disagree with the disk"). Pure, trivial to test,
  completely untested.
- `summary_lines`' reconciliation (D8) — the lost-row backstop itself.
- `honoured_size`, `require_render_size!`, `overrides_triples`, `annot_push`/`annot_pop`.

The sharpest available evidence for this verdict: **the suite passes 64/64 while the
render lane is unlaunchable.** A green suite is currently compatible with the tool's
headline feature being dead.

There is also a structural limit worth writing down: `EXPECT` is a single hard-coded
string, so adding a check means editing two places, and the suite tests only what
someone chose to lift out into a pure method. Everything that touches `@`-state is,
by construction, out of scope — and `@`-state is where this tool lives.

---

## Unproven rather than working — stated as prominently as the findings

**Nothing in this tool has ever been driven by Benton clicking its button.** Every run
in the record went through `scripts/sketchup-bridge.py` with a stubbed dialog object.
That is not a footnote; it is why finding 1 exists, and it is the single largest gap in
the evidence.

Specifically unproven:

1. **The real `UI::HtmlDialog` path, end to end.** The dialog has *opened* once (27 Aug,
   reported). No batch has been started from its Export button. The
   `runStarted()` / `logLine()` / `setProgress()` / `runFinished()` contract has never
   been exercised against a live CEF window — only against a stub whose
   `execute_script` either worked or raised.
2. **The ANNOTATION dropdown's markup.** Ruby-side `cfg['annot']` is proven live; the
   HTML control that produces it is not (reported, HANDOFF-pass2).
3. **`cfg['overrides']` has no dialog control at all.** The JS `export` payload sends
   `dir`, `width`, `over`, `shade`, `annot` — and nothing else (**observed**). So
   `exposure_override?` is permanently false from the button, and every override path,
   including `apply_exposure` and the `@vray_saved` restore, is dead code from the UI.
   That is the intended default, but it means the *whole override + restore mechanism*
   is unreachable and therefore untested in the shipping path.
4. **The `:failed` / error-state path.** Never fired. Offline only.
5. **`:idleFrameDone`.** Never seen; policy chosen, not observed.
6. **The camera-mismatch refusal.** `cam_mismatch` is unit-tested; the row-refusal
   branch (:1493-1501) has never triggered live.
7. **The V-Ray-absent refusal and the "export image rows only" fork** (:782-800).
8. **The Ask / Skip-existing collision policies** (:834-858). Only Overwrite is in the
   record.
9. **Multi-row render batches since 1.9.4.** Two five-row batches ran under **1.9.3**
   (reported, pass 2). Nothing has run end to end since the 1.9.4 rewrite of the
   V-Ray unit — which is exactly the release that broke the gate.
10. **`WR_Mode` restore on a model with real client history.** Every run has been on a
    scratch `Untitled`.
11. **Whether a scripted render consumes a licence seat**, and the "Incorrect DR
    version" raise. Still open from 28 Aug.
12. **The pack itself.** No proposal package has ever been assembled from this tool's
    output and put in front of a customer.

---

## Readiness

**Would I let this build a pack that goes to a paying customer today? No.**

Not primarily because of the blocker — a loud refusal is survivable and Benton would
ring the bell within a minute. The reason is findings 2, 3 and 4: three live paths on
which the tool can leave the model mutated, or lose a row, or paint the wrong material,
**while the window says "Done. Model restored."** The file's own header says a leaked
mutation is the worst failure it can have and that a vanished row is what it exists to
make impossible. Both are still reachable.

**The shortest list that would change my answer:**

1. Move `honoured_size` above the render gate in `start_run` — or have
   `require_render_size!` compute the size itself. (Finding 1.)
2. Assign `@annot_saved` **before** the hide loop, and have `annot_pop` restore whatever
   is recorded even on a partial failure. (Finding 2.)
3. Count unreconciled planned rows into the headline `FAILED` number, and send the whole
   summary — not `lines.first` — to the dialog log. (Finding 3.)
4. Early-return from `mark` / `bulk` / `setfill` / `activate` when `@running`, in **Ruby**.
   (Finding 4.)
5. Wrap the restore-failure `UI.messagebox` at :1890, and give `finish` a re-entrancy
   guard. (Finding 5.)
6. Then: **one batch, run by Benton, through the real button** — two render rows and two
   image rows, on a scratch model that has never been mode-toggled — with the model
   inspected afterwards for mode, materials and tag visibility, and the four files
   opened and looked at.

Items 1–5 are all small and local. Item 6 is the one that actually matters, and it is
the one that has never been done.

Two things I would fix next but would not block on: finding 7 (the log line that
contradicts the release's own promise) and finding 12 (the three stale comments that
describe the setting-stomping behaviour as current). Both are cheap, and both are how
this class of bug returns.

## What I could not check

- Nothing here was executed in SketchUp or V-Ray. No SketchUp, no V-Ray, no `ruby.exe`
  on this session. Every claim about live behaviour is **reported** from the handoffs.
- Only `require_render_size!` and the 64-check suite were actually run (in the barebones
  CRuby VM out of SketchUp's DLL). Everything else marked **confirmed** means confirmed
  by reading the code, not by running it.
- I did not verify the SketchUp operation-nesting claim behind finding 8; it is
  **reported** API behaviour and would take one Ctrl+Z in a scratch model to settle.
- I did not read `wr-shading.rb`, `wr-preflight.rb`, `wr-folder.rb` or
  `proposal-scenes.rb` beyond the constants the package consumes from them.
- I did not evaluate render *quality* — grain, exposure, the light rig, the
  `_HostMaterial` question. HANDOFF-lookdev owns those and its numbers look sound; they
  are look decisions for Benton, not audit findings.
- I did not attempt the `UI::HtmlDialog` gap myself. It can only be closed by a person
  clicking the button.

===REPORT===
Findings 1–13 above, ranked.

**Answer to Benton: no — and the render lane is currently unlaunchable from the button.**
`require_render_size!` (`proposal-package.rb:774`) reads `@size_source` 168 lines before
`honoured_size` sets it (`:942`), so every batch containing a Render row is refused on
every press, permanently, with a message naming the wrong cause. Executed offline; it is
not a race and not environment-dependent. It survived because the one live test called
those two methods in the opposite order by hand — a stub-versus-button gap, exactly.

Three silent paths outrank it in kind though not in certainty: a failed `annot_push`
leaves annotation tags hidden in the model forever and logs the opposite (`:1235`); a
lost row still yields a `0 FAILED` headline and a `Done. Model restored.` verdict in the
window (`:1904`, `:1958`); and the four dialog callbacks still have no `@running` guard
(`:2148`, `:2160`) now that `render_production` is known to pump the message loop.

Of the 28 Aug audit's ten findings: 5 genuinely closed (F2 and F4 on real evidence),
3 still fully open and untouched (F5, F6, F8), 2 closed on code reading and unit tests
alone (F1 has never fired; F3's fix is unproven and introduced a new stale-restore
mutation in `reset_stale_batch`).

The 64-check offline suite passes today with the render lane dead. It covers ten pure
helpers well and does not touch `start_run` ordering, the `step`/`step_body` guard,
`finish`, or `plan_names`/`uniquify` — the FILE-column contract the file header calls
central. Every defect of the last month has lived in the untested half.

Not ready for a paying customer. Five small local fixes (findings 1–5), then one batch
driven by Benton through the actual button on a never-toggled scratch model, with the
model and the files inspected afterwards. That last step has never happened and is the
only one that settles anything.
