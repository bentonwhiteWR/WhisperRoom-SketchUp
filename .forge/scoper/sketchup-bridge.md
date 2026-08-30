# SketchUp bridge — build contract

Scoper, 2026-08-30. Target: `.forge/GOAL.md` Mission and its five Done-means.
Plugin at 1.8.0; this ships as **1.9.0**.

---

## Goal

A resident Ruby listener inside SketchUp plus a Python client outside it, so an agent can
submit a Ruby job, have it run in the live application, and read back **stdout, the return
value, and any exception with backtrace** — turning the pending hand-walked checklists into
automated assertions. `scripts/rbtest-*.py` covers the pure half of the Ruby logic outside
SketchUp; this is the impure complement, the half that needs a live model and a loaded plugin.

---

## Approach

File-drop protocol over a directory pair. No sockets, no HTTP, no threads: SketchUp's Ruby is
single-threaded and its only safe scheduler is `UI.start_timer`, which is already this
codebase's polling idiom (`scripts/proposal-package.rb:584`, observed). The listener is a timer
that claims one job per tick, evaluates it, and writes one result file.

Three properties drive every decision below:

1. **A half-written result must be unreadable, not misread.** Rename-into-place plus a
   `"complete": true` terminal key plus client re-read on a parse failure.
2. **A blocked job must never read as a pass.** A modal freezes the timer; the client detects
   this from a `.running` marker plus a stale heartbeat and fails by name, and the listener
   pre-emptively makes `UI.messagebox` and friends *raise* inside a job instead of opening.
3. **Nothing the bridge does can damage real work.** Fences on the model, on save, and on the
   write paths — checked before the job runs and enforced during it.

### Files

| Path | What |
|---|---|
| `scripts/wr_tools/wr_bridge.rb` | the listener (new, installed with the plugin) |
| `scripts/wr_tools/main.rb` | one guarded `load` of the bridge + two menu items (edit) |
| `scripts/wr_tools/VERSION` | `1.8.0` -> `1.9.0` (edit) |
| `scripts/wr-bridge-lib.rb` | job-side helpers, resolved LIVE from the repo (new) |
| `scripts/sketchup-bridge.py` | the client: CLI + importable `submit()` (new) |
| `scripts/install-plugin.py` | **no change needed** — verify, do not edit |
| `DEVLOG.md` | entry at the end of the work |

`install-plugin.py` copies every file in `scripts/wr_tools/` (observed, read its `main()`), so
`wr_bridge.rb` installs itself with no installer edit. Confirm that in the Builder's first run
rather than trusting this line.

### Where the repo-live loading rule lands (the "decide and state" question)

`wr_tools/` is read from the **installed** plugin folder, so **every edit to `wr_bridge.rb`
costs `install-plugin.py` plus a SketchUp restart** (CLAUDE.md, observed). That is the reason the
listener must stay small. Anything expected to churn — assertion helpers, viewport-capture
wrappers, scratch-model builders — goes in `scripts/wr-bridge-lib.rb`, which sits in
`SCRIPTS_DIR` and is therefore read live from the repo checkout (`main.rb` `CANDIDATES`,
observed). Jobs `load` it by path from `WhisperRoom::Tools::SCRIPTS_DIR`. Net effect: iterating
on test logic needs no reinstall; iterating on the protocol does.

### Bridge root

    %LOCALAPPDATA%\WhisperRoom\bridge\<SketchUp 2024|SketchUp 2026>\
        enabled          marker file — no marker, no polling
        alive            heartbeat, mtime touched each poll tick
        in/              <id>.job.json          (client writes)
        run/             <id>.job.json, <id>.job.rb, <id>.running   (listener owns)
        out/             <id>.result.json       (listener writes, client reads)
        art/             default sink for job-written PNGs
        bridge.log       one line per job, append-only

Override with `WR_BRIDGE_DIR` (both sides read it). **`%LOCALAPPDATA%`, not `%APPDATA%`, and
never anywhere under OneDrive** — a synced folder introduces a second writer and a replication
delay into exactly the read the whole protocol depends on. **Per-version subdirectory** because
2024 and 2026 are both installed (observed) and both would otherwise poll the same inbox and
race for the same job.

---

## Protocol

### Job file

Client writes `in/<id>.job.tmp`, then `File.rename`s it to `in/<id>.job.json` — so the listener
can never glob a half-written job. `id` is `YYYYMMDD-HHMMSS-<pid>-<nn>`, e.g.
`20260830-142233-11824-01`. UTF-8, no BOM.

```json
{
  "id": "20260830-142233-11824-01",
  "created": "2026-08-30T14:22:33-04:00",
  "label": "read model state",
  "ruby": "m = Sketchup.active_model\nputs m.title\n{ 'ents' => m.entities.length }\n",
  "timeout_s": 60,
  "suppress_autorun": true,
  "modal": "raise",
  "allow_named_model": false,
  "write_roots": []
}
```

- `ruby` — the source. Mutually exclusive with `file`, an absolute path to a `.rb` the client
  reads and inlines (the wire format always carries the source, so a result is reproducible
  from the job file alone).
- `timeout_s` — advisory to the listener, enforced by the client. Default 60.
- `suppress_autorun` — default `true`; see Dialog suppression.
- `modal` — `"raise"` (default) or `"allow"`. `"allow"` is the escape hatch for a human sitting
  in front of SketchUp; the client refuses to pair it with a short timeout.
- `allow_named_model` — default `false`; see Safety fences.
- `write_roots` — extra absolute directories this job may write to, added to the allow-list.

### Result file

Listener writes `out/<id>.result.tmp`, then `File.rename`s it onto `out/<id>.result.json`.
Rename-over-existing inside one directory is atomic to a reader and **works from Ruby on NTFS**
(observed — probed against SketchUp 2024's own `x64-ucrt-ruby320.dll`).

```json
{
  "id": "20260830-142233-11824-01",
  "status": "ok",
  "started": "2026-08-30T14:22:33.412-04:00",
  "finished": "2026-08-30T14:22:33.907-04:00",
  "elapsed_s": 0.495,
  "stdout": "Untitled\n",
  "stderr": "",
  "value": { "ents": 148 },
  "value_class": "Hash",
  "value_repr": "{\"ents\"=>148}",
  "error": null,
  "artifacts": [],
  "model": { "title": "Untitled", "path": "", "guid": "…" },
  "env": { "sketchup": "24.0.553", "ruby": "3.2.2", "plugin": "1.9.0", "os": "win64" },
  "complete": true
}
```

`status` is one of:

| status | means | client exit |
|---|---|---|
| `ok` | ran to completion, no exception | 0 |
| `error` | the job raised — the `error` object is populated | 1 |
| `refused` | a safety fence stopped it *before* any job code ran | 6 |

**`complete` is the last key written and the client requires it.** A truncated file fails JSON
parse; a JSON-valid file missing `complete` is treated as corrupt, never as a result.

### Error object

```json
"error": {
  "class": "ArgumentError",
  "message": "no booth named 4260",
  "backtrace": ["…/run/20260830-142233-11824-01.job.rb:12:in `block in <main>'", "…"],
  "cause": { "class": "TypeError", "message": "…" }
}
```

**A raise is unmistakable from a `nil` return.** A nil return is `status:"ok"`, `value:null`,
`value_class:"NilClass"`, `error:null`. A raise is `status:"error"` with a non-null `error`.
The client asserts on `status`, never on `value`.

`rescue Exception`, **not** `StandardError` — a `SyntaxError` in a job, or in a script the job
`load`s, descends from `ScriptError` and would otherwise sail past into SketchUp, which swallows
it and produces a job that hangs to the timeout for no visible reason. `main.rb` already carries
this lesson in full at its `toggle` method (observed, around line 1063).

### Value serialisation

Encoding the return value must never be able to raise, because that would turn a passing job
into a corrupt result. Rules:

- JSON-native values (nil/true/false/Numeric/String/Array/Hash of the same, depth 6 or less) go
  into `value` verbatim.
- Anything else: `value` is `null`, and `value_repr` carries `inspect` truncated to 8 KB.
- `value_class` is always `value.class.name` — the honest label in both cases.
- **Scrub every string** with `encode('UTF-8', invalid: :replace, undef: :replace)` before it
  goes near `to_json`. SketchUp on Windows hands back model titles and file paths that are not
  valid UTF-8, and `to_json` raises on those.
- The whole serialise-and-write step is itself wrapped: if it fails, write a minimal
  `status:"error"` result naming the serialisation failure. There is always a result file.

### Output capture

`$stdout` is swapped for a **tee** object for the dynamic extent of the job and restored in
`ensure`. A plain duck-typed object with a `write` method **does capture `Kernel#puts`** in
SketchUp's own CRuby 3.2 — observed, probed against `x64-ucrt-ruby320.dll`: `puts "duck-line"`
landed in the object's buffer. Implement `write`, `<<`, `print`, `printf`, `flush`, `sync`,
`sync=`, `tty?`/`isatty` (false), and `method_missing` forwarding to the wrapped console, so a
call like `$stdout.clear` still reaches `Sketchup::Console`. Do the same for `$stderr` (`warn`
goes there) into the separate `stderr` field. Cap each at 256 KB, keeping the head and appending
`\n[...truncated N bytes]`.

**Tee, do not replace.** Everything still reaches the Ruby Console, so a human watching gets the
normal picture and — this is the point — if some output source turns out to bypass `$stdout`
inside SketchUp, the consequence is an unrecorded line, not a lost one.

**Unverified, and the Builder must verify it live:** whether SketchUp's native/API-side console
writes honour the `$stdout` swap at all. Only Ruby-level `puts` was provable outside SketchUp.
Acceptance criterion A4 exists to settle it; if native output turns out to bypass the tee, say
so in `DEVLOG.md` and in the client's usage text rather than papering over it.

### Job execution

Listener, per tick, `@busy`-guarded the way `proposal-package.rb`'s `step` guards `@in_step`
(observed):

1. `Dir.glob(in/*.job.json)`, oldest by mtime, **one per tick**.
2. `File.rename` it into `run/` — claiming by rename means a second listener (the other SketchUp
   version, a stale session) loses the race rather than double-executing.
3. Parse. Unparseable job -> `status:"refused"`, reason `bad-job-json`.
4. Run the safety pre-flight (below). Fail -> `status:"refused"` with the fence named.
5. Write `run/<id>.job.rb` — the literal source, on disk, at the path backtraces will name.
6. Write `run/<id>.running` (id, label, started timestamp).
7. Swap `$stdout`/`$stderr`, set the autorun globals, install the modal and save patches.
8. `eval(src, TOPLEVEL_BINDING, job_rb_path, 1)`.
9. `ensure`: restore everything, delete `.running`, write the result.

**`eval`, not `load`**, and this deviates from the Done-means wording deliberately: `load`
returns `true` and discards the job's value, which is one of the three things the bridge exists
to return. `eval` with an explicit filename gives the same file-and-line backtraces (`file:line`
appeared correctly in the probe), and the `.rb` still exists on disk at exactly that path, so a
backtrace line is still an openable file. `TOPLEVEL_BINDING` so a job behaves like Ruby Console
input — which is the thing these tests stand in for. Consequence to document for job authors:
**jobs share top-level state across a SketchUp session.** Write jobs idempotent; a job that
defines a constant twice will warn.

### Heartbeat

Every tick, before anything else, touch `alive` (write the current timestamp). The heartbeat is
what separates "SketchUp is not there" from "SketchUp is wedged", and it must be the first thing
the tick does, so it is never skipped by a job's own failure.

Poll interval **0.25 s, repeating** (`UI.start_timer(0.25, true)`). A `Dir.glob` on a small
directory four times a second is not a measurable cost, and latency stays under a quarter second.

---

## Timeouts and the modal hazard

**The listener cannot time a job out.** Single-threaded, no preemption: once `eval` is running,
nothing else in SketchUp runs, including the timer. All timeout enforcement is the client's.

The client polls `out/<id>.result.json` every 0.1 s until `timeout_s`, then diagnoses from three
observable facts — is there a result, is `run/<id>.running` present, is `alive` fresh (mtime
within 3 s):

| running | alive | verdict | exit |
|---|---|---|---|
| absent | stale/absent | **SketchUp is not listening** — not running, bridge not enabled, or the wrong version/bridge dir. Names the exact directory it watched and the enable command. | 3 |
| absent | fresh | job never claimed — listener alive but the inbox was not read. Report as a bridge fault, naming the job file's path. | 3 |
| present | **stale** | **job started and SketchUp stopped responding.** The message names the likely cause: a modal dialog or file picker is open and waiting for a click — a `UI.messagebox` this bridge could not intercept — or a long native operation. Names the job label and the `.running` file. | 4 |
| present | fresh | job still running past its timeout. Suggests a longer `--timeout`. | 5 |

None of these is exit 0 and none of them prints a result. A timed-out job is abandoned, not
cancelled: if it finishes later it writes its result harmlessly, and the next run has a new id,
so a late result can never be mistaken for a new one.

### Making the modal not happen in the first place

For the job's dynamic extent, with `modal:"raise"` (the default), redefine on the `UI` module:
`messagebox`, `inputbox`, `openpanel`, `savepanel`, `select_directory` — each raising
`WhisperRoom::Bridge::ModalBlocked` carrying the call's own arguments in the message
(`ModalBlocked: UI.messagebox("Overwrite this scene?")`). Restore the originals in `ensure`,
capturing them as `method(:messagebox)` and so on before patching.

This converts the worst failure mode — a frozen SketchUp needing a human — into an ordinary
`status:"error"` with a backtrace naming the line that tried to prompt. The stale-heartbeat path
above stays as the net for what this cannot reach: `UI::HtmlDialog#show_modal`, V-Ray's own
dialogs, and native modals.

### Dialog suppression

Set **both** `$wr_no_autorun` and `$wr_suppress_autorun` to `true` around the job and restore
the previous values in `ensure`, exactly as `main.rb`'s `load_quietly` does and for the reason
its comment gives — the scripts disagree about the spelling, and leaving them set silences the
autorun for the next script the human runs, which looks exactly like a dead button (observed,
`scripts/wr_tools/main.rb` lines 1030-1053). A job with `suppress_autorun: false` skips this,
which is how a job deliberately exercises a script's normal entry point.

---

## Safety fences

Mechanisms, in this order, all before any job code runs except where noted.

1. **Scratch models only.** Refuse (`status:"refused"`, reason `named-model`) unless
   `Sketchup.active_model.path` is empty (an unsaved Untitled model) or sits under the bridge
   root or `%TEMP%`. A job may opt out with `allow_named_model: true`; the client requires an
   explicit `--allow-named-model` to send that, and the refusal message says so.
2. **Never save over an open model.** For the job's extent, patch `Sketchup::Model#save`,
   `#save_copy` and `#save_thumbnail` to run the path check below; `save` with no argument (save
   in place) always raises `WhisperRoom::Bridge::Forbidden`. Restore in `ensure`.
3. **Path allow/deny.** One `Bridge.check_write(path)`, used by the save patches and by a
   patched `Sketchup::View#write_image`.
   - **DENY, absolutely, no override:** `C:\Users\bento\Desktop\ProposalFiles\`, any `P:\` path,
     and any path under a `WhisperRoomQuote` folder. Case-insensitive, resolved through
     `File.expand_path` first so `..` cannot walk in.
   - **ALLOW:** the bridge root (`art/` by default), `%TEMP%`, and anything in the job's
     `write_roots`.
   - Anything else raises `Forbidden`, naming the path and the rule that stopped it.
4. **Stale-marker sweep at load.** Delete any `run/*.running` left by a previous session. Only
   one listener exists per version, so such a file can only be a crash relic; leaving it would
   make the very next timeout misreport as "wedged".
5. **The honest limit.** This fences the SketchUp APIs a job realistically uses. It does **not**
   fence a bare `File.write`, and it is not a sandbox — jobs are this repo's own code, run at the
   agent's request, and the fence is a guardrail against accident. Say this in `wr_bridge.rb`'s
   header so nobody later mistakes it for a security boundary.

---

## Install and enablement

Opt-in, off by default. A resident poller in Benton's daily-driver SketchUp should exist only
when someone asked for it.

- `main.rb` gains, near the end and **before** `build_ui`, a guarded load:
  `begin; load File.join(File.dirname(__FILE__), 'wr_bridge.rb'); rescue Exception => e; puts "WR BRIDGE failed to load: #{e.class}: #{e.message}"; end`
  — `rescue Exception` for the same reason the rest of this plugin does it: a bridge fault must
  never be able to take the panel down with it.
- On load the bridge checks for the `enabled` marker. **No marker: no timer, no polling, nothing
  resident.** It only adds two items to the WhisperRoom menu, `Bridge: enable` and
  `Bridge: disable`, which create/remove the marker and start/stop the timer immediately — so
  turning it on mid-session costs no restart.
- `python scripts/sketchup-bridge.py enable [--su 2026]` creates the marker from outside. That
  path *does* need a SketchUp restart if SketchUp was already running when the marker appeared,
  because nothing polls for the marker; the client says so in its output rather than leaving the
  user to wonder.
- Install: `python scripts/install-plugin.py`, restart SketchUp. Bump `VERSION` to `1.9.0` — the
  update banner is the only signal Gabe gets that anything changed (CLAUDE.md).
- Version selection: the client defaults to the installed SketchUp whose `alive` is fresh. If
  both 2024 and 2026 are fresh it **refuses and names both**, requiring `--su`. No silent
  fallback (GOAL rule).

---

## Client

`scripts/sketchup-bridge.py`, house style: a module docstring carrying the usage and the why,
`sys.argv` parsing (no argparse — matches `install-plugin.py`, `rbparse.py`,
`fix-angled-alpha.py`).

```
python scripts/sketchup-bridge.py ping                      is anyone listening, and which version
python scripts/sketchup-bridge.py eval "<ruby>"  [--timeout N] [--su 2024|2026]
python scripts/sketchup-bridge.py run  <file.rb> [--timeout N] [--label "..."]
python scripts/sketchup-bridge.py shot <out.png> [--width 1600]
python scripts/sketchup-bridge.py enable | disable [--su ...]
```

Prints the job's stdout as-is, then `-> <value_repr>`; on `status:"error"` prints
`CLASS: message` and the backtrace to stderr. Exit codes: `0` ok, `1` job raised, `2` usage,
`3` not listening, `4` blocked (modal), `5` still running at timeout, `6` refused by a fence,
`7` corrupt result.

It also exports `submit(ruby, timeout=60, **opts) -> dict`, so a future `rbtest-live-*.py` can
assert against results directly. That is the shape the checklists turn into.

**Corrupt-result handling.** If `out/<id>.result.json` exists but does not parse, or parses
without `complete`, wait one poll interval and re-read, up to 5 times, before declaring exit 7.
The rename makes this near-impossible; the retry costs half a second and removes the last way an
antivirus or indexer touching the file could be mistaken for a failed job.

---

## Acceptance criteria

Every one of these is a command the Builder runs against a live SketchUp with a scratch model
open. Paste the real output into `DEVLOG.md`; "reasoned about" is not a pass (Done-means 4).

- **A1 — resident, no per-run restart.** `install-plugin.py`, restart SketchUp once, enable the
  bridge. `sketchup-bridge.py ping` reports the version and a fresh heartbeat. Run three
  different jobs back to back with no restart between them; all three answer.
- **A2 — model state.** `eval "Sketchup.active_model.entities.length"` returns an integer in
  `value`, `status:"ok"`, elapsed under 2 s.
- **A3 — a real WR tool end to end.** A job that `load`s a tool from
  `WhisperRoom::Tools::SCRIPTS_DIR` and drives it to build something (a small room via
  `build-room.rb`'s entry point is the obvious candidate), then returns a count of what it made.
  `status:"ok"`, and the geometry is visible in the viewport.
- **A4 — stdout capture.** A job that `puts` three lines returns all three in `stdout`, in
  order, and the same three lines are also visible in the Ruby Console. This is the criterion
  that settles the one thing this spec could not verify outside SketchUp.

  **SETTLED LIVE 30 Aug 2026: SketchUp's own console output DOES honour the `$stdout` swap.**
  Three `puts` lines came back in `stdout` in order *and* appeared in the Ruby Console, and a
  `warn` went to `stderr` separately. SketchUp's own deprecation warning for
  `Sketchup.send_action` was captured too, so the tee catches API-side Ruby writes and not only
  the job's own. No caveat is needed in `DEVLOG.md` or the client's usage text.
- **A5 — viewport PNG.** A job calling `model.active_view.write_image(<bridge art dir>/x.png)`
  produces a file, lists it in `artifacts`, and the PNG is non-empty. Then the same call
  targeting `C:\Users\bento\Desktop\ProposalFiles\x.png` raises `Forbidden` — `status:"error"`,
  no file created.
- **A6 — the job that raises.** `eval "def a; raise ArgumentError, 'boom'; end; def b; a; end; b"`
  returns `status:"error"`, `error.class == "ArgumentError"`, `error.message == "boom"`, and a
  backtrace with **at least two frames naming the job's `.rb` path with line numbers**. The
  client exits 1.
- **A7 — nil is not an error.** `eval "nil"` returns `status:"ok"`, `value:null`,
  `value_class:"NilClass"`, `error:null`, exit 0. Run A6 and A7 next to each other; the two
  outputs must be impossible to confuse.
- **A8 — the modal.** `eval "UI.messagebox('hi')"` returns `status:"error"` with `ModalBlocked`
  naming the message text — **no dialog appears** and SketchUp does not freeze.
- **A9 — not listening.** With the bridge disabled (or SketchUp closed), any `run`/`eval` exits
  3 within `timeout_s`, with a message naming the directory it watched and how to enable it. It
  must not hang and must not exit 0.
- **A10 — wedged.** With `modal:"allow"`, submit `UI.messagebox('block me')` at a 10 s timeout
  and leave the dialog up. The client must exit **4**, naming the modal as the likely cause.
  Then click the dialog and confirm the late result lands harmlessly and is not picked up by any
  later run.

  **SETTLED LIVE 30 Aug 2026, AND THIS SPEC GUESSED IT BACKWARDS.** `UI.start_timer` *does*
  keep firing while a native modal is up — the heartbeat never aged past 0.08 s across eleven
  seconds with a message box open. The diagnosis table below must therefore be **inverted**
  from what this document proposed: `.running` present **plus a FRESH heartbeat** is the wedge
  (Ruby blocked, message loop alive) and `.running` present **plus a STALE heartbeat** is an
  ordinary long job (the job owns the interpreter, so the timer cannot fire). Both directions
  were run — the modal gave exit 4 at a 0.2 s heartbeat, a 20 s busy loop under a 5 s timeout
  gave exit 5 at a 4.9 s heartbeat. Under this document's original table every job outliving
  3 s would have reported as wedged. The named fallback (the `.running` file's own age) was not
  needed and would not have discriminated anyway.
- **A11 — safety. RESTATED 30 Aug 2026 by Benton's decision 3** (`.forge/GOAL.md`), which drops
  the pre-flight refusal on named models. The original wording — "with a saved model open, a
  job is `refused` with reason `named-model`" — no longer describes wanted behaviour, because
  running a job against a real drawing that is open is now explicitly allowed. What the
  criterion tests instead is that **allowing the read did not weaken any write fence**. With a
  *saved* model open: the job RUNS (`status:"ok"`, its `puts` reaches `stdout`); and each of
  these raises `Forbidden` — `Sketchup.active_model.save` with no path, `save_copy` into
  `ProposalFiles`, `write_image` onto `P:`, and a `..`-walk that resolves back into
  `ProposalFiles`. Saving to `%TEMP%` is permitted and is how the test gets its named model.
  The `refused` status and exit 6 remain reachable, and are covered by the malformed-job path
  (`reason: bad-job-json`, empty `stdout`).
- **A12 — no partial reads.** A job producing about 2 MB of stdout, run 20 times in a loop from
  the client, yields 20 clean results and zero exit-7s.

---

## Risks and out of scope

- **The one real risk is the wedge**, and A10 is the only proof the diagnosis works. If the
  heartbeat turns out to keep ticking during a modal (that is, SketchUp's timers do fire while a
  message box is up — unverified either way), the `present + fresh` row would swallow it. In that
  case add a second signal: the `.running` file's own age against `timeout_s`, and report a wedge
  when running is older than the timeout regardless of the heartbeat. Decide from what A10
  actually shows, not from what this paragraph guesses.
- **`$stdout` capture of native/API console output is unverified** (see A4).
- **Bridge edits cost a reinstall and a restart.** Budget for it; keep churn in
  `scripts/wr-bridge-lib.rb`.
- **Jobs share top-level state** within a SketchUp session. Idempotent jobs only.
- The fence is a guardrail, not a sandbox (Safety fences, item 5).
- Out of scope, per GOAL: driving the V-Ray VFB, the asset editor or any HtmlDialog by simulated
  keystrokes; running V-Ray renders through the bridge; concurrent jobs; any network transport;
  any change to booth geometry, lighting, or the proposal package.
- Ship rule: `python scripts/rbparse.py` clean before committing any Ruby, `VERSION` bumped,
  `DEVLOG.md` updated, committed and pushed (CLAUDE.md).
