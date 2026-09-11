# Audit — THE PLUMBING (loading, updating, persistence, failure recovery)

Read-only. Nothing was changed. WhisperRoom-SketchUp at `main` = `3a15d3c`, working tree
clean except untracked `.forge/` material. `scripts/wr_tools/VERSION` reads **1.48.1** (the
brief said 1.48.0; 1.48.1 is committed and pushed, so the banner is honest right now).

**Files opened in full or in the relevant part:** `scripts/wr_tools/main.rb` (all 1937
lines), `scripts/install-plugin.py` (all), `scripts/wr_tools.rb` (all),
`scripts/wr_tools/wr_bridge.rb` (structure + the modal/writer patching and job lifecycle),
`scripts/wr_tools/panel.html` (icon resolution, update banner, update button),
`scripts/wr_tools/icon-map.json`, `defaults.json`, `wr-icons.svg`, `VERSION`, every
`$wr_no_autorun` / `$wr_suppress_autorun` site across `scripts/*.rb`, and `DEVLOG.md`
grepped for dead button / autorun / update / registry / stale.

**Headline.** The update path's central claim — *"a failed pull changes nothing, and the
installer is a script that has been run a hundred times"* (`main.rb:337-339`) — is not true
in two of its three legs: a conflicted merge does write the working tree that the tools are
loaded from, and the installer has no transaction, so a copy that dies halfway leaves a
`wr_tools/` folder that is part-new and part-old with a **VERSION file that may already say
the new number**. Both failures are silent and both damage the panel that would be used to
fix them. Second: `update_now` decides success by grepping the log for `installed ->` and
never looks at the exit code it already has, so a machine with two SketchUps where the
second install fails is told "Updated."

---

## Ranked findings

Risk = probability × cost, silent/unrecoverable weighted above loud.

### 1. A partial install leaves a half-updated plugin, and VERSION travels in the same unordered copy loop — HIGH

`scripts/install-plugin.py:209-216`:

```python
shutil.copy2(os.path.join(SRC, 'wr_tools.rb'), plugins)
dst = os.path.join(plugins, 'wr_tools')
os.makedirs(dst, exist_ok=True)
for f in os.listdir(os.path.join(SRC, 'wr_tools')):
    src_f = os.path.join(SRC, 'wr_tools', f)
    if os.path.isfile(src_f):
        shutil.copy2(src_f, dst)
```

**observed.** There is no staging directory, no temp-then-rename, no `try`, and no ordering.
`os.listdir` order is filesystem order, so `VERSION` (and `defaults.json`, and `panel.html`)
can be written *before* `main.rb`. Any `PermissionError` / `OSError` partway through — a
OneDrive sync lock, an antivirus hold, a full disk, the user closing the console — raises out
of `main()` and stops the run.

**Failure scenario.** Update now on Gabe's machine. `VERSION` and `panel.html` copy; the copy
of `main.rb` fails. Next SketchUp start: the panel runs **old** `main.rb` against a **new**
`panel.html`, so any callback the new page names and the old Ruby does not register is a
button that does nothing — and `version` now reads the new number, so `update_ready?` is
false and the banner says he is current. He is running code that is neither release.

**Why it matters more than an ordinary install failure.** `main.rb:334-343` explicitly
rejects the download-and-overwrite design because "a half-finished download leaves the plugin
broken and the panel you would fix it with is the thing that broke". The installer reproduces
exactly that shape; the reasoning was applied to the download step and not to the copy step.

**Fix direction (not applied):** copy `wr_tools/` into `wr_tools.new/` and swap, or copy
`VERSION` **last** and wrap the loop so a failure prints which files did and did not land.

### 2. `update_now` reports success from a substring and ignores the exit code it already has — HIGH

`main.rb:383-408`:

```ruby
system('"' + bat + '"')
...
if out =~ /installed ->/
  push_note('Updated. RESTART SKETCHUP for it to take effect.')
```

**observed.** `system`'s boolean return is discarded. `installed -> ` is printed by
`install-plugin.py:217` **once per SketchUp version found** (`main()` loops over
`%APPDATA%\SketchUp\*`). On a machine with SketchUp 2024 *and* 2026, if the first target
installs and the second raises, the log holds one `installed ->` line and a Python traceback
— and the panel says **"Updated. RESTART SKETCHUP"**. Same for finding #1: one successful
target plus a crash reads as success.

**Related, same block — the error text points the wrong way.** `out.to_s.lines.last` is used
as the reason. If `git pull` succeeds and `python` is missing or is the Windows Store stub
(exit 9009, no stdout), the last log line is git's, so the user is shown
`Update did not complete: Already up to date.` — git's success line presented as the failure
cause. **derived** from the code path; not reproduced live. The codebase's own standard is
that an error says what was and was not done; here the pull succeeded (and, on a repo
machine, the *tool scripts are already live from the checkout*) while `wr_tools/` was not
reinstalled. Nothing says that split happened.

### 3. "A failed pull changes nothing" is false for a conflicted merge, and scripts load live from that tree — HIGH

`main.rb:337-339` (the comment), `main.rb:379-380` (`git pull > log`, `if errorlevel 1 exit /b 1`).

**derived, from git's documented behaviour + the code.** Three failure modes behave
differently and the code treats them as one:

- Dirty tree with conflicting local edits → merge refuses before touching anything. Claim
  holds. ✔
- Clean tree, divergent local commits, **merge conflicts** → git writes conflict markers into
  the working files and leaves `MERGE_HEAD`. Exit 1, so the installer is correctly skipped —
  but on Benton's and Gabe's machines `SCRIPTS_DIR` **is that checkout** (`main.rb:41-50`), so
  every conflicted `.rb` now raises `SyntaxError` on click. The panel's own run path handles
  that loudly (`run`, `main.rb:~1525`, rescues `Exception` and boxes it), which is good — but
  the repo is now mid-merge and **there is no control in the panel that can get out of it**.
  Recovery requires a terminal, which is the thing Update now exists to avoid. ✘
- No network / expired credentials → `git pull` can block. `system` is synchronous on
  SketchUp's single UI thread, there is no timeout, and the batch sets neither
  `GIT_TERMINAL_PROMPT=0` nor `--ff-only`. A Git Credential Manager window can open *behind*
  SketchUp; the user sees a frozen application. **derived** — not reproduced.

**Fix direction:** `git pull --ff-only` (a fast-forward cannot conflict and cannot open an
editor), `set GIT_TERMINAL_PROMPT=0`, and a distinct message for "your checkout has local
commits — pull it by hand".

### 4. One non-UTF-8 byte in any script header blanks the whole panel, silently — MEDIUM-HIGH

`main.rb` `payload` → `push`:

```ruby
def self.push
  return unless @dlg
  @dlg.execute_script("WR.render(#{payload.to_json})")
rescue StandardError
  nil
end
```

**observed.** `payload` carries `scan` (titles and blurbs read verbatim out of every `.rb`
header by `meta_of`) and `sprite` (the whole of `wr-icons.svg`). `to_json` raises
`JSON::GeneratorError` on a string that is not valid UTF-8. `push` rescues `StandardError`
and returns `nil` — **no message box, no console line, no partial render**. The panel opens
and stays empty, which presents identically to "the panel is dead".

`wr_bridge.rb:393` already carries this exact lesson ("SketchUp on Windows hands back model
titles and file paths that are not valid UTF-8, and `to_json` raises on those") and scrubs
every string. `main.rb` does not scrub anything — grep for `encode|force_encoding|scrub|
valid_encoding` in `main.rb` returns nothing (**observed**).

**Currently latent:** I decoded every `.rb` under `scripts/` and every text file under
`scripts/wr_tools/` as UTF-8 — all clean today (**observed**). The exposure is the next file
saved by an editor in CP-1252 (a smart quote or an em dash in a comment does it), or dropped
into the folder by a teammate. The panel promises "drop a `.rb` in, hit Rescan" — that is the
path this defect sits on.

**Fix direction:** scrub in `meta_of`/`sprite`, and make `push`'s rescue say something.

### 5. `build_ui` is unguarded at load: one raise and there is no menu, no toolbar and no panel — MEDIUM-HIGH

`main.rb`, last lines:

```ruby
unless file_loaded?(__FILE__)
  build_ui
  file_loaded(__FILE__)
end
```

**observed.** Everything else in this file is defensive — `read_pref`, `own_list`,
`shop_defaults`, `icon_library`, `icon_map`, `meta_of`, `run`, `toggle` all rescue, and the
bridge load twelve lines above is wrapped in `rescue Exception` *with a fallback menu item
that explains itself*. `build_ui` itself is not. If `UI::Toolbar.new`, `UI.menu`, `scan` or
`face_path` raises, the extension dies at load with only an Extension Manager error, and
**every recovery control in this plugin lives inside the thing that failed to build**.

The cheap version of the fix is the bridge's own pattern: wrap `build_ui`, and on failure
still add a single `Plugins > WhisperRoom > Panel` menu item plus a console dump.

**Related, same area (observed):** `scan` (`main.rb:461-483`) calls `File.mtime(path)`
unguarded while `cat_of`/`tab_of`/`shelf_of`/`meta_of` all rescue. A script deleted between
`Dir.entries` and the `mtime` raises `Errno::ENOENT` straight out of `scan` — into `payload`
(blank panel, per #4) or into `build_ui` at load (dead plugin). Narrow race, but the guard
costs one line and every neighbour already has it.

### 6. A failed update check never retries, so the panel can say "current" for a whole session — MEDIUM

`main.rb:299-321`:

```ruby
def self.check_update(&done)
  return if @checked
  @checked = true
  ...
rescue Exception
  nil
end
```

**observed.** `@checked` is set *before* the request, and is never reset on failure — only on
a successful `update_now` (`main.rb:399-400`). Open the panel while the network is down, or
while GitHub is slow enough that the callback never lands, and the update check is dead for
the rest of the SketchUp session. Rescan does not re-arm it; there is no manual "check again".

The visible consequence is a positive signal, not a neutral one: `panel.html:1328-1332`
paints the version pill plain with the tooltip `WhisperRoom Tools v1.48.1`, which reads as
"you are current". This is the "tells the user they are up to date when they are not"
direction, and on Gabe's machine the banner is the *only* notification channel there is.

**Fix:** set `@checked = false` in the failure paths (the non-200 branch, the `rescue`, and
the outer `rescue Exception`), and let Rescan clear it.

### 7. `WR_BoothLink/link` is stored state that outlives the UI that set it — the annot-incident shape — MEDIUM

`main.rb` `buildlink` callback:

```ruby
Sketchup.write_default('WR_BoothLink', 'link', url.to_s.delete('"'))
```

and `booth-from-link.rb:181` seeds its `UI.inputbox` with `read_pref('link')`, `:193` writes
it back on every run. **observed.**

The 1.47.0 entry in `DEVLOG.md` records the same shape costing real output: *"the dropdown
wrote itself to the registry on every export and Benton's machine still held `client` from a
run that morning. The stored value, not the UI default, produced stripped exports."* Here the
stored value is a **customer's quote link**, and there are two writers for one visible
control: the panel's command bar writes the pref *before* the dialog opens, and the dialog
writes it again. Nothing ever clears it. Every later plain launch of the tool — from a
toolbar slot, from the list, from the menu — opens pre-filled with the previous customer's
link. Press OK without reading and you build the wrong booth into a client drawing.

Cost is high (wrong geometry, presented as right) and it is silent; probability is moderate
because the link is on screen. This is the closest match in the plumbing layer to the incident
the brief asked me to look for.

**Other instances of the same shape, lower cost (observed):** ability settings —
`values_for` (`main.rb`, abilities section) reads `read_pref("set_#{id}_#{key}", s['default'])`,
so if a script's `@setting` default is changed in a release, **nobody who has ever touched
that control receives the new default**, ever, and nothing says so. `wr-drop-lights.rb`'s
named presets are documented as behaving this way on purpose (DEVLOG 1.43.1) — the ability
settings are not documented anywhere.

### 8. `read_pref`'s rescue writes the fallback, permanently cutting that key off from `defaults.json` — MEDIUM

`main.rb:646-658`:

```ruby
rescue Exception
  begin
    Sketchup.write_default(PREF_KEY, key, fallback.to_s)
  rescue Exception
    nil
  end
  fallback.to_s
end
```

**observed + derived.** The comment above it (`main.rb:571-573`) sells this as self-healing:
"a default written by an older build heals itself on the next launch instead of erroring
forever." It does heal the `SyntaxError`. But `unset?` only recognises `UNSET` and `RESET`
(`main.rb:641-644`) — an empty string is a *written* key — and most callers pass the default
fallback `''`. So one transient read failure converts "never set, inherit the shop default"
into "set to empty, forever", which is precisely the all-or-nothing fall-through defect
1.46.0 was written to kill. Write `RESET` instead of `fallback` and the heal keeps the
inheritance.

### 9. Three autorun guards restore the literal `false` instead of the saved value — MEDIUM

**observed:**

- `scripts/booth-from-link.rb:1167-1171` — `$wr_no_autorun = true` … `ensure $wr_no_autorun = false`
- `scripts/build-room.rb:447-456` — `$wr_suppress_autorun = true` … `ensure $wr_suppress_autorun = false`
- `scripts/build-takeoff.rb:199-202` — same

Every other site in the repo now uses a **local** (`clear-whisperroom-dimensions.rb:20`,
`rotate-whisperroom-dimensions.rb:33`, `wr-autoset.rb:63`, `wr-preflight.rb:36`,
`wr-mode.rb:84`, `wr-pack-export.rb:59`, `wr-scene-annotations.rb:60`,
`proposal-package.rb:96`, `main.rb#load_quietly`, `wr-bridge-lib.rb:65`) — the lesson from
the 2026-08-27 dead-button bug, written up in `proposal-package.rb:89-95`. These three are
the remainder, and `build-takeoff.rb:69-74` shows the same file getting it right eleven lines
earlier, so this is drift, not a decision.

**Failure direction is the opposite of the dead button and still bad.** These leave the flag
**false**, not true, so the next nested `load` inside an outer guarded block autoruns: a modal
dialog opens in the middle of a batch, or a tool's entry point runs twice with different
settings. Under `wr-bridge-lib.rb`'s `WRB.tool` (which blocks modals) that surfaces as a job
failure naming a dialog nobody opened. **derived** — not reproduced live; I did not run
SketchUp.

`load_quietly` and the bridge's own save/restore were checked site by site and are correct:
both snapshot into locals and restore in `ensure` (`main.rb` abilities section,
`wr_bridge.rb:614-654`). I found no path that leaves `$wr_no_autorun` **true**.

### 10. Preference writes swallow every failure while the panel reports success — MEDIUM-LOW

`main.rb:792-796`: `write_pref` rescues `Exception` and returns `nil`. The `setslot` callback
then announces, unconditionally, `"Slot N set. A new ICON appears when SketchUp next starts;
the button already runs the new script."` (**observed**). Same for `collapse`, `devtools`,
`uipref`, `save_setting` and `remember`. If the write fails, the panel states as fact
something that did not happen, and the slot silently reverts on the next render.

This is the one place in the file that breaks the codebase's own stated standard — every
other operator-facing action (`rename`, `save_shop_defaults`, `reset_to_shop_defaults`,
`toggle_ghost`, `toggle`) returns `[ok, message]` and says which way it went.

### 11. `repo_dir` requires `.git` to be a directory, and the refusal text then gives wrong advice — LOW-MEDIUM

`main.rb:326-330`: `File.directory?(File.join(root, '.git')) ? root : nil`. A worktree, a
submodule, or a checkout where `.git` is a *file* returns nil (**observed**). The panel then
reports `can_update: false` and `update_now` says *"No git checkout found - this is the
bundled copy. Clone the repo and run install-plugin.py to update."*

That sentence is wrong in the case that matters: `SCRIPTS_DIR` resolved to a real checkout
(so the scripts **are** live from it, and `bundled?` is false), and the correct advice is
"pull it by hand" — or, for the other route to this message (a clone at a path not in
`CANDIDATES`, e.g. `D:\repos\...`), "set `WR_SCRIPTS_DIR`". This is the two-machines case:
Gabe reaching this message is told to clone a repo he already has. `File.exist?` instead of
`File.directory?` fixes the worktree half.

### 12. The SKIP list is hand-maintained — correct today, with nothing keeping it so — LOW-MEDIUM

`main.rb:63-66`. I checked it both ways (**observed**):

- Every one of the eleven SKIP entries exists in `scripts/`.
- Every `.rb` in `scripts/` that has **no** `@title` header is in SKIP — the set is exactly
  `wr_tools.rb, wr-booth-data.rb, wr-shading.rb, wr-folder.rb, wr-deck.rb, wr-overlays.rb,
  wr-roof-vent.rb, wr-png-srgb.rb, wr-scene-sun.rb, wr-autoset.rb` plus `wr-bridge-lib.rb`.
- No non-SKIP script lacks a `@title`.

So the list is right, and the 1.48.0 DEVLOG entry shows the convention being followed
consciously. The risk is structural: a new library added without the SKIP edit appears as a
tool row whose click `load`s a file that defines a module and returns — **a button that does
nothing, with no error**, which is the exact presentation the DEVLOG flags as the hardest
thing in this plugin to diagnose. The signal already exists in the files (no `@title`, no
top-level autorun); nothing reads it.

### 13. The "Updating…" note probably never paints — LOW

`update_now` calls `push_note('Updating...')` (`main.rb:351`) and then blocks the same thread
in `system` for the length of a `git pull` plus a full install. `execute_script` hands work to
CEF but the render cannot be observed until Ruby yields. `panel.html:1357-1365` already
disables the button and sets its label to "Updating…" in JS, which *does* paint — so the
symptom is a frozen panel with a disabled button and no further sign of life for as long as
the pull takes. **derived**, not measured. Worth knowing before anyone reports "Update now
hangs".

### 14. Smaller things, verified but low risk

- `icon-map.json` maps `wr-scene-annotations.rb` → `scene-annots`, and `wr-icons.svg` has no
  `wr-scene-annots` symbol (**observed**; the file `wr-ico-scene-annots.svg` does exist, so
  the toolbar face is fine and only the panel row differs). `panel.html:1031-1038` falls back
  to the category glyph, so this is cosmetic — the degradation the sprite comment promises
  actually works.
- `install_skills` uses `shutil.copytree(..., dirs_exist_ok=True)` (`install-plugin.py:190`),
  which never removes a file deleted *inside* a skill. The whole-skill manifest discipline is
  sound; per-file drift inside a skill folder persists on Gabe's machine forever.
- The update batch is written with Ruby's default external encoding and read by `cmd` in the
  OEM codepage (`main.rb:376-382`). Paths with spaces are safe (both are quoted); a path with
  non-ASCII characters — an accented Windows username, a `OneDrive - Company` variant with
  non-ASCII — would `cd` to the wrong place. `%` in a path would also be expanded by `cmd`.
  **derived**, not reproduced; no current machine is exposed.
- `version` is memoised (`@version ||=`, `main.rb:271-273`), so after a successful in-session
  update the banner reappears on the next panel open until restart. Harmless direction — it
  over-warns rather than under-warns — and `push_note` already says to restart.
- `wr_bridge.rb` was checked for the failure this audit was most worried about: a job that
  dies leaving `UI.messagebox` monkeypatched to raise. It is guarded properly — `patch_modals`
  refuses to re-alias over an existing saved name (`:299-305`, with the reasoning in the
  comment at `:290-293`), and `run_job`'s `ensure` unpatches both modals and writers inside
  their own `begin/rescue` (`:652-654`). No finding.

---

## What I did NOT cover

- **`scripts/proposal-package.rb`** — another agent is editing it. I read only its autorun
  preamble (`:74-135`) and its `autorun?` call site (`:6345-6359`), both of which use the
  local-variable idiom correctly. Everything else in that file is unreviewed and possibly
  in flight.
- The ~50 tool scripts' internals. I read only their autorun guard sites and
  `booth-from-link.rb`'s preference handling.
- `panel.html`'s 2016 lines beyond icon resolution, the update banner and the update button —
  the list rendering, search, slot editor and ability cards are unread.
- The bridge's job protocol (claim/heartbeat/result files, stale sweep, `check_write` fence)
  beyond structure. It is off by default and gated on a marker file, so it is not in the daily
  failure path.
- **Nothing was executed.** No SketchUp, no `git pull`, no `install-plugin.py`, no
  `rbparse.py`. Every claim here is from reading code, plus the file-level checks I did run
  (UTF-8 decode of every script, SKIP-vs-`@title` set comparison, icon-map/sprite/defaults
  cross-check, git state). Claims are tagged observed / derived where it matters.
- Recovery *procedure* — I did not test whether a broken plugin can in fact be repaired from
  the Ruby Console alone. Findings #1, #3 and #5 all assume it cannot be repaired from the
  panel, which is what the code shows.
