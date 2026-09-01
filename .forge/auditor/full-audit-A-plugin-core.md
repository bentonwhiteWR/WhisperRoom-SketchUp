# Full audit A — plugin core and distribution (1 Sep 2026, plugin 1.19.2, commit 14197b9)

Auditor A, read-only. Lane: `scripts/wr_tools.rb`, `scripts/wr_tools/main.rb`,
`scripts/wr_tools/panel.html`, `scripts/wr_tools/wr_bridge.rb`, `defaults.json`,
`icon-map.json`, `VERSION`, `scripts/install-plugin.py`, `scripts/sketchup-bridge.py`,
`scripts/wr-bridge-lib.rb`, `scripts/wr-folder.rb`, `scripts/diag-favourites.rb`,
`scripts/backup-sketchup-settings.py`. All read in full.

Provenance words: **observed** (ran it / read it on disk), **derived** (traced through
code, not executed), **reported** (a doc or log said so), **assumed** (needed, not checked).
No SketchUp, V-Ray or `ruby.exe` on this machine; where pure Ruby could be executed it was,
through `scripts/rbparse.py`'s `rb_eval` on SketchUp's own `x64-ucrt-ruby320.dll`.

Harness result recorded: `python scripts/rbparse.py` → **66 file(s) parse, all `ok`** (observed).
`node --check` on the single `<script>` block in `panel.html` (36,660 bytes, html-line 790) →
exit 0; no unbalanced string literal on any line; ES5 only (observed).

---

## The headline question: why this machine sat at 1.12.9 while the repo reached 1.19.2

The mechanism is not broken in the way the question implies — nothing in it was ever going
to fire on 1 Sep, and the day before it fired exactly once and did its job. The evidence:

| When | Fact | Provenance |
|---|---|---|
| 31 Aug 21:00:08 | SketchUp 2026 starts a session with **plugin 1.12.6** in memory (`bridge.log`: "listener started (SketchUp 2026, plugin 1.12.6)"). | observed |
| 31 Aug 21:17:16 | 1.12.9 committed and pushed **from this machine** (reflog). | observed |
| 31 Aug 21:30:51 | **Update now was clicked.** `%TEMP%\wr_update.bat` / `wr_update.log` written; the log reads `Already up to date.` then `installed -> SketchUp 2024 / SketchUp 2026, 61 scripts bundled`. The installer therefore wrote **1.12.9** — the checkout's version at that instant. | observed |
| 31 Aug 21:36 → 1 Sep 00:17 | 1.12.10, 1.12.11, 1.13.0, 1.14.0 committed and pushed **from this machine** (reflog). Nobody ran the installer again. | observed |
| 31 Aug 21:30 → 1 Sep 00:26 | **SketchUp was never restarted** after the update: no later "listener started" line; the bridge heartbeat `alive` was last written 00:26:12; `SharedPreferences.json` rewritten 00:20. The panel in memory stayed 1.12.6; the disk copy was 1.12.9. | observed |
| 1 Sep 08:59 → 15:47 | Fourteen versions (1.14.1 → 1.19.2) pushed from the **other** machine. SketchUp 2026 was **closed all day here** — the bridge's `enabled` marker has existed since 31 Aug 18:26, so a running SketchUp would have refreshed `alive` four times a second; it stayed at 00:26. No checkout pull until 18:24:08 (`pull --ff-only`, reflog). | observed |
| 1 Sep 18:24–18:30 | Orchestrator pulls to 14197b9, sees installed 1.12.9, runs the installer by hand. | reported (GOAL) |

So the direct cause is: **the last install on this machine was the 21:30 click, at 1.12.9,
and no install ran afterward.** Four reasons that was allowed to happen, in the order they
contributed:

1. **The developer-machine gap (design).** Commits 1.12.10–1.14.0 were made here. On a
   machine with the checkout, `SCRIPTS_DIR` resolves to the repo (`main.rb:41-50`), so the
   developer sees every script edit live and never feels stale — while `wr_tools/` (panel,
   main.rb, defaults.json) is read from the INSTALLED copy and ages silently. The panel has
   no check that would notice: it compares installed VERSION against **GitHub** only
   (`main.rb:267-268`, `410-412`); it never compares against the checkout sitting next to it.
   A zero-network "installed 1.12.9 ≠ checkout 1.14.0 — reinstall" line would have said so
   at 00:17.
2. **Nothing runs while SketchUp is closed (design, documented in CLAUDE.md).** All fourteen
   pushes on 1 Sep happened into a closed SketchUp. The banner cannot do anything there.
3. **The GitHub check runs once per SketchUp process, not once per panel open.** `main.rb:298-300`
   `return if @checked; @checked = true` — the comment at `main.rb:264-266` says "asks once
   per panel open", the code says once per session. `@checked` is set **before** the request
   is made, so a first-open network failure is never retried either. In a long session
   (21:00 → 00:26 here) every push after the first panel open is invisible. Only
   `update_now` resets it (`main.rb:399`).
4. **After a successful update the banner nags against the wrong number.** `version` is
   memoised (`main.rb:271` `@version ||=`), so after `update_now` the next check compares
   GitHub (≥1.12.9) with the in-memory pre-update version (1.12.6) and shows "Update
   available — v1.12.10 (you have v1.12.6)" with a live button, even though the disk copy is
   current and only a restart is pending. Clicking again does no harm (`Already up to date`)
   but the banner teaches the reader to ignore it. Derived; consistent with the single
   `wr_update.log` run and no restart.

Where it can silently do nothing (for the fix list): `check_update`'s `rescue Exception → nil`
at `main.rb:318`, and the `@checked` flag being set before the request. Every failure inside
`update_now` itself is loud (`push_note` + console dump, `main.rb:388-407`), and the batch
file route is proven on this machine (the 21:30 log).

---

## Ranked findings (probability × cost, silent above loud)

### A1 — Update check: once per process, never retried, compared against a memoised version
- **Where:** `scripts/wr_tools/main.rb:264-266` (comment) vs `:298-300` (code); `:271`; `:318`.
- **Trigger:** SketchUp open across a push; or a transient network failure at the first panel open; or any successful Update now.
- **Failure:** silent — no banner for the rest of the session; or a banner that keeps offering an update already installed. This is the mechanism half of the 1.12.9 story above.
- **Provenance:** observed (code and the 31 Aug log/heartbeat timeline); the nag-after-update path is derived.
- **Fix direction:** check on every `ready` and `rescan` with a short throttle (e.g. 5–10 min); set `@checked` only after a 200; read VERSION from disk in `update_ready?` instead of memoising; **and add a local comparison** — when `repo_dir` exists, compare installed VERSION with `<repo>/scripts/wr_tools/VERSION` and say "checkout is newer than the installed plugin — run the installer" with no network at all. That is the check the developer's machine actually needed.

### A2 — The bundled copy cannot run the room tools: only `.rb` is bundled, `build-room.html` is not
- **Where:** `scripts/install-plugin.py:106-111` (`.rb` only); `scripts/build-room.rb:503-505` (looks for `build-room.html` beside `__FILE__`); `scripts/build-takeoff.rb:72` loads build-room.
- **Trigger:** any machine with no git checkout (the case the installer's own docstring exists for, lines 10-25 and `main.rb:30-38`). "Draw floor plan..." and "Build from take-off..." both stop with "build-room.html is missing".
- **Failure:** loud at click time, silent at install time — the installer reports "61 scripts bundled" and the plugin says "self-contained".
- **Provenance:** observed — the installed `wr_tools/scripts/` on this machine holds zero non-`.rb` files; the two Ruby lines were read.
- **Fix direction:** bundle the sidecars a script needs (`build-room.html`; audit for others such as `takeoff-vectors.html/json` if any script reads them next to itself), or have `copy_scripts` copy `*.html`/`*.json` alongside `.rb` and record them in the manifest.
- **Note:** CLAUDE.md says Gabe works from a clone, so today this may bite nobody; it is ranked here because the installer promises it and the failure looks like a broken script.

### A3 — SAVE AS SHOP DEFAULT never ships per-script settings: the loop reads keys `scan` does not emit
- **Where:** `scripts/wr_tools/main.rb:646-654` iterates `scan` and reads `sc['settings']` and `sc['id']`; `scan` (`:459-483`) emits `name`, `ability` (settings are at `sc['ability']['settings']`) and no `id`. The shape with `id`/`settings` is `abilities` (`:1052-1068`).
- **Trigger:** every click of the footer button.
- **Failure:** silent — `sc['settings']` is always nil, so no `set_<script>_<key>` ever lands in `defaults.json`; the button's tooltip (`panel.html:745`) and the code comment promise otherwise. The shipped `defaults.json` holds only `slots`, `slot_icons`, `pinned` (observed), consistent.
- **Provenance:** observed in source.
- **Fix direction:** iterate `abilities` (or `scan` with `sc['ability']['settings']` and `sc['name']`).

### A4 — Shop default pre-empts the `pinned → slots` migration
- **Where:** `scripts/wr_tools/main.rb:770-777`: `raw = read_list('slots'); if raw.empty? → migrate from 'pinned'`. Since 1.16.1 `read_list('slots')` returns Benton's shop default when the user never set `slots`, so `raw.empty?` is false and the user's own pre-12-Aug `pinned` favourites are never migrated.
- **Trigger:** a machine whose `WR_Tools` prefs predate the slot editor (12 Aug) and were never re-saved.
- **Failure:** silent — the user's toolbar shows Benton's bar, not theirs; their `pinned` list is then overwritten by the first `write_slots`.
- **Provenance:** derived. Probability low today (both known machines have `slots`), but it is exactly the "an update overwrote my layout" case the docs say cannot happen.
- **Fix direction:** read the raw registry value for `slots` (UNSET-aware) before consulting the shop default; migrate `pinned` first, shop default last.

### A5 — The whole shop-defaults feature rests on one unverified API behaviour
- **Where:** `scripts/wr_tools/main.rb:618-624`: `UNSET = " wr-unset"` is passed as the *default* to `Sketchup.read_default`.
- **Trigger:** the first read of any key on a machine that has never set it.
- **Failure:** if SketchUp's `read_default` cannot carry a NUL in the default (it evals the *stored* string; the default's handling is undocumented), it raises, the `rescue Exception` at `:625-631` **writes the code fallback into the registry**, and from then on every key reads as "set" — the shop default is masked on every machine, silently, forever. If it works, the design is sound.
- **Provenance:** assumed. I found no record that 1.16.1/1.19.1 was verified on a machine with empty prefs.
- **Fix direction / test:** in the Ruby Console on any machine, `Sketchup.read_default('WR_Tools', 'zz_never_set', " wr-unset")` must return the sentinel unchanged and raise nothing; then `Sketchup.read_default('WR_Tools','slots', " wr-unset")` on Gabe's machine must not equal `''`. If the NUL is a problem, any improbable printable sentinel works.

### A6 — The panel's paste-a-link affordance does not recognise the `#3=` link format
- **Where:** `scripts/wr_tools/panel.html:888` matches only `booth-builder?d=` and `#d=`; `scripts/booth-from-link.rb:13-26, 209+` reads `#3=` since 1.18.0.
- **Trigger:** paste a `#3=` share link into the search box.
- **Failure:** treated as a search term → "Nothing matches"; Enter does nothing. The row still works through its own dialog, so the cost is confusion, not a wrong booth.
- **Provenance:** derived from both files.
- **Fix direction:** add `#3=[A-Za-z0-9_-]{10,}` to `boothLink()`, or have main.rb ship the regex so the two files cannot drift again.

### A7 — `update_now` runs a bare `git pull` on the checkout the panel reads live
- **Where:** `scripts/wr_tools/main.rb:378`.
- **Trigger:** on the committing machine, local commits that diverge from `origin/main`.
- **Failure:** a merge into the working tree; on conflict, markers land in `.rb` files that every tool then `load`s → SyntaxError boxes on every button with no pointer to the cause. A dirty tracked file (e.g. `defaults.json` just written by SAVE AS SHOP DEFAULT and also changed upstream) aborts loudly ("Update did not complete: Aborting") — that half is fine.
- **Provenance:** derived. The 31 Aug run was a fast-forward and clean.
- **Fix direction:** `git pull --ff-only`, and on failure print the git line verbatim in the note.

### A8 — `installed_versions()` misses SketchUp 2026's nested layout
- **Where:** `scripts/install-plugin.py:62-69` checks `Program Files\SketchUp\<v>\SketchUp.exe` only; 2026 lives at `SketchUp 2026\SketchUp\SketchUp.exe` (observed on this machine; `sketchup-bridge.py:106-127` already handles both).
- **Trigger:** only when no `%APPDATA%\SketchUp\*\SketchUp\Plugins` profile exists yet (fresh machine, or 2026 installed but never launched).
- **Failure:** 2026 gets no plugin; with only 2026 installed, `sys.exit('No SketchUp found…')`. On this machine both profiles exist, so "SketchUp 2024" and "SketchUp 2026" came from APPDATA and were correct.
- **Provenance:** observed layout, derived consequence.
- **Fix direction:** copy the two-layout check from `sketchup-bridge.py`.

### A9 — Skills install: correct manifest discipline, one merge gap
- **Where:** `scripts/install-plugin.py:137-186`.
- Can it delete a skill it did not install? **No** — only names in `~/.claude/skills/.installed-by-wr.txt` are removed (observed: `launch` is reported KEPT). Edge: a user-made skill with the same name as a repo skill is overwritten and claimed by the manifest, then removed if the repo drops it (derived, improbable).
- Can a rename leave a stale copy? A renamed **skill directory** is cleaned correctly (old name is in the manifest). A renamed or deleted **file inside** a skill is not: `copytree(dirs_exist_ok=True)` merges and never deletes, so `~/.claude/skills/<name>/` accumulates stale files. Today both installed skills match the repo exactly with no extras (`diff -rq`, observed).
- **Fix direction:** `rmtree` then `copytree` for skills the manifest says are ours, or diff the file lists.

### A10 — The bridge: file-drop transport, client-side timeouts, and the Untitled rule lives only in some jobs
- **Transport (observed):** no socket. `%LOCALAPPDATA%\WhisperRoom\bridge\SketchUp <year>\{in,run,out,art}` with `UI.start_timer(0.25)` polling; jobs claimed by rename, results written `.tmp` → rename with `complete` as the last key; the Python side re-reads a corrupt result five times and never returns one without `complete`.
- **Stuck job (observed in code):** the listener cannot cancel anything (single-threaded); the Python side times out and `diagnose()` separates modal (heartbeat fresh, exit 4) from long job (heartbeat stale, exit 5) using the measured `MODAL_KEEPS_TIMERS = True`. A crash leaves `.running`, swept at the next start.
- **Non-Untitled model:** the bridge **explicitly allows named models** (`wr_bridge.rb:587-592`, Benton 30 Aug) and enforces only writes (no `save` without a path ever; deny list for ProposalFiles / `P:` / WhisperRoomQuote; `write_roots` allow-list). The Untitled guard is therefore the **job's** responsibility. It is present in `eval-floorplan.py` (line 136-143), `rbtest-live-booth.py:176-179` and `WRB.scratch!` (`wr-bridge-lib.rb:134-140`); it is **absent** from `WRB.tool()`, which `load`s any tool with the autorun globals set — and `build-booth.rb`, `csusb-rooms.rb`, `booth-4260-s.rb`, `booth-96168-s.rb`, `uthsc-audiology-rooms.rb` carry no guard (header scan, observed), so loading them through a job builds geometry into whatever model is open, named or not. Derived; the bridge does not enforce the house rule, it asks.
- **Drift from its own "off by default":** the `enabled` marker has been present since 31 Aug 18:26 (observed), so the listener now auto-starts every SketchUp 2026 launch on the daily driver and will `eval` any `.job.json` any same-user process drops. The header calls this a guardrail, not a sandbox — correct — but the design intent was "exists only when somebody asked". `run/` holds 3,953 files and `out/` 1,971 (observed); nothing cleans them.
- **Fix direction:** an optional pre-flight in `run_job` (`job['require_untitled']`, default true for anything that loads a builder) that refuses by name when `model.path` is non-empty; `WRB.tool` to refuse loading a guard-less script unless `deaf` is explicitly false; a sweep of `run/`/`out/` older than N days; and either remove the marker after test sessions or show a "BRIDGE LISTENING" line in the panel.

### A11 — Cosmetic / quality (low, listed once each)
- `icon-map.json` still maps five SKIP libraries (`wr-booth-data`, `wr-deck`, `wr-folder`, `wr-shading`, `wr_tools`) — dead entries (observed).
- **24 of 56 panel scripts draw `wr-default`** — every "V-Ray renders" tool, every client one-off, five probes, `build-takeoff.rb`, `reorient-model.rb`, `prefix-scenes.rb` — no `@icon`, no map entry (observed via script over the sprite's 29 symbols). The panel-audit's "no script falls to wr-default" no longer holds.
- `"V-Ray renders"` is not in `panel.html` `ORDER` (`:805-807`), so its 13 tools sort after "Tidy up the model" rather than after "Scenes and images" (observed).
- `panel.html:1388-1392` says off-tab search hits are labelled; no label is drawn (observed).
- `faces` and `recent` payload keys still unread by the panel (observed, grep).
- `hl()` (`panel.html:857-863`) highlights on the escaped string, so a term overlapping an entity (`amp`) splits it — view-only.
- `refresh_fav_labels` (`main.rb:986-1007`) calls `favourite_at` 18 times, each a full `scan` (61 files × 4 header passes) — ~4,400 file reads per star click or rename. Cache one `scan` per call.
- `note()` classifies a message as bad on `/no /` (`panel.html:1650`); "No git checkout" is intended, but any future note containing "no " goes red.
- `install-plugin.py:52` `SKIP_COPY` is vestigial (only `.rb` is copied anyway).
- `backup-sketchup-settings.py:166-171` `restore()` iterates `Preferences.dat` as if it were a version folder and prints "no such SketchUp on this machine" for it.
- `wr_tools.rb:3-6` install note names 2024 only.
- `main.rb:1078-1083` `set_state` writes an attribute dictionary onto whatever model is active, including a named client drawing, outside any operation — makes the file dirty for an ability flip. Not a rule breach (metadata, undoable) but worth knowing.

---

## Prior audit findings re-checked (this lane only)

| Earlier finding | Status | Evidence |
|---|---|---|
| panel-audit #1 — `rename` strips the "…" from every dialog script | **FIXED** | `main.rb:1241-1244` reads `meta_of(path)[4]`; **observed** via `rb_eval`: `# @title Pendant Curing Jig...` renamed to `New Name` → file line 1 is `# @title New Name...\r\n` (CRLF preserved), `dialog=true` after; a plain title gains no dots. |
| panel-audit #2 — `pendant-jig.rb`, `tube-drying-stand.rb` wear the dialog dots with no dialog | **STILL OPEN** | `head -1` of both still ends in `...` (observed). |
| panel-audit #3 — `icon-map.json` maps the SKIP libraries | **STILL OPEN** | five entries (observed). |
| panel-audit #4 — `faces` payload key never read | **STILL OPEN** | grep finds no `DATA.faces` (observed). |
| panel-audit "no script falls to wr-default" | **REGRESSED** | 24 do (observed; A11). |
| panel-audit "SKIP list is the five libraries" | superseded, **clean** | SKIP is now nine; every file with no `@title` is in it (header scan, observed). |
| panel-audit "13 callbacks match both ways" | **clean, grown** | now 15 (`update`, `shopdefaults` added); every `sketchup.*` call in the JS has a registered callback (observed). |
| script-audit "prefs discipline: rescue Exception, quotes stripped" | **clean** | `read_pref`/`write_pref` `main.rb:620-679`, `wr-folder.rb:64-79` (observed). |
| Fixer 15 Aug "run/toggle rescue Exception, fail by name" | **clean** | `main.rb:1291-1313`, `:1168-1206` — console line, backtrace, message box, SyntaxError hint (observed). |

---

## What is solid (verified and found clean)

- **Parsing:** all 66 `.rb` files parse under SketchUp's own Ruby (observed).
- **panel.html JavaScript:** one block, `node --check` clean, no unbalanced quote on any line (the 1.14.2 class), no ES2015+ syntax (no arrows, templates, `const`/`let`, optional chaining), so CEF 88 is safe (observed). Every `innerHTML` sink is built from `esc()`-wrapped model strings; `esc()` covers `& < > "` and **every attribute in the file is double-quoted**, so the missing `'` does not matter (observed by reading each sink). `meta_of` passes a title containing `'`, `"`, `<`, `&` through unchanged for `esc()` to handle (observed via `rb_eval`).
- **Script loading (Q6):** a script is a panel row if it is a `.rb` in `SCRIPTS_DIR` not in `SKIP`; `@title` (dots stripped, flag kept), `@tab client` (typo → tools), `@cat`, `@shelf`, `@icon`, `@rank` (non-integer → nil, observed), `@ability`/`@setting`/`@on`/`@off` parsed from the first 61 lines. A raising script **fails by name**: console line + backtrace + message box, with a SyntaxError hint; `load_quietly` sets and restores both autorun globals. All scripts that other scripts `load` and that autorun carry a guard; the guard-less load targets are pure libraries (`wr-deck`, `wr-folder`, `wr-overlays`, `wr-png-srgb`, `wr-roof-vent`, `wr-shading`) (observed).
- **Version compare:** `newer?` orders 1.10.0 > 1.9.0, 1.19.2 > 1.12.9, equal → false, junk → false (observed via `rb_eval`).
- **Update button plumbing:** the batch-file route works on this machine — proven by the 31 Aug 21:30 log; every failure inside it is reported to the panel and console.
- **Shop defaults read path:** per key, the user's value wins whenever `read_default` returns anything but the sentinel; an empty string counts as set; the file is read from the installed copy and written to the repo copy, and the message tells you to commit (observed; subject to A5).
- **Installer:** installed `wr_tools/` is byte-identical to the repo for both versions; both skills identical with no stray files; `.installed-by-wr.txt` manifests present; foreign skill `launch` kept (observed).
- **Bridge safety properties:** atomic result write with terminal `complete`; refusals before any job code runs; modal patch with the alias-once guard; `save`/`save_copy` without a path always raise; deny list beats `write_roots`; heartbeat written before anything else each tick; `@busy` guard against re-entrant ticks during a modal (all observed in code).
- **`sketchup-settings/` in the public repo:** the committed `SharedPreferences.json` files carry no license, serial, e-mail or token strings — only stock component paths and 3D Warehouse collection URLs; `login_session.dat` is excluded (observed).
- **`wr-folder.rb`, `diag-favourites.rb`:** nothing to report; the diagnostic's session-long `toggle_pin` tracer is documented and dev-shelved.

## Coverage limits
Nothing here was executed inside SketchUp. `Sketchup.read_default` semantics (A5), the HtmlDialog repaint during `system()`, and the bridge's live behaviour are taken from code and the logs on disk. `backup-sketchup-settings.py` and `diag-favourites.rb` were read for correctness only, not run.
