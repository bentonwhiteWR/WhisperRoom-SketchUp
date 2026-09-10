# HANDOFF — Builder → Benton: create an annotation set from the dialog, 1.20.1

2026-09-10. Follow-up to 1.20.0. Benton: *"We added the dims annotations being
able to be hidden. I'd like for there to be a way to add an annotation set from
here."* Shipped, **unrun in SketchUp** — see Open questions.

## Produced

**Changed — `scripts/wr-scene-annotations.rb` only**
- `WR_SceneAnnotations.create_set(model, user_name)` — new class method,
  directly above the `apply` section and next to `move_selection_to_set`.
  Same `[ok, message]` convention, same `start_operation` /
  `commit_operation` / `abort_operation`-on-exception wrapper. Reads NO
  selection. Names via `WR_ProposalScenes.annot_set_name` (the one existing
  rule); empty/unnormalisable name refused by name; an existing tag is a
  `[true, …]` no-op saying so; otherwise `model.layers.add(name)` and the
  message names the REAL tag, which is usually `WR-Notes-<slug>` and not what
  was typed.
- `newset` action callback in `self.open`, wired exactly like `move`:
  `create_set` → `push_state` → `status`, unconditionally.
- `self.html` — a second full-width block inside the existing `#move` strip:
  label *"Create an empty set — no selection needed"*, the `WR-Notes-` prefix
  hint, `#cnew` (always visible, via the strip's existing `input.show` rule)
  and a `CREATE SET` button `#cgo`. Enter in the field clicks the button.
  One new CSS rule, `#move .lbl.two { margin-top: 10px; }` — spacing only, no
  new colour value.

**Changed — housekeeping**
- `scripts/wr_tools/VERSION` → **1.20.1**. Patch, not minor: this is one
  additive control inside an existing tool, no new tool, no change to the
  hide/show mechanism or to anything `proposal-package.rb` calls.
- `DEVLOG.md` — entry for 1.20.1 at the top.

## Read first
- `scripts/wr-scene-annotations.rb` header (lines 1–56) — why the tool is a
  hybrid, and why sets must stay inside the `WR-Dims*` / `WR-Notes*` family.
- `WR_ProposalScenes.annot_set_name` in `scripts/proposal-scenes.rb` (~line 92)
  — the single naming rule. Do not add a second one.

## Assumptions
- **assumed**: a freshly `model.layers.add`-ed tag is `visible?` → true, so
  `inventory` reports `hidden: false` and the row lands unticked. Derived from
  the code path, not observed in SketchUp.
- **derived**: the new set appears as a row on the next `push_state` because
  `inventory` builds a set row for every family tag present in
  `model.layers`, members or not (read at lines 219–251).
- **observed**: `python scripts/rbparse.py` → 68/68 files parse. That is a
  CRuby 3.2 syntax check and nothing more; it proves no behaviour.

## Open questions
- **Not run in SketchUp.** No `ruby.exe` here and no bridge to the SketchUp
  window. To verify, in Extensions → Developer → Ruby Console:
  `load "<repo>/scripts/wr-scene-annotations.rb"`, then
  1. type `Plan` in **Create an empty set** → **CREATE SET**. Expect status
     `Created WR-Notes-Plan — empty for now…`, a `WR-Notes-Plan` row under
     **Annotation sets** reading `empty`, unticked, and present in the move
     dropdown.
  2. **CREATE SET** on the same name again → "already exists … nothing was
     changed", list unchanged.
  3. Empty field → **CREATE SET** → "Type a name for the set first."
  4. Regression: the old **New set… + MOVE SELECTION INTO SET** path still
     moves a selection and still refuses an empty one.
- Should a just-created set be pre-selected in the move dropdown? Left alone
  deliberately — `push_state` rebuilds the strip, and guessing the next action
  was not part of the ask.

## Also in this session — clickable scene name, 1.20.2

`scripts/proposal-package.rb`. Benton: *"on the left side where it shows the
scene names, if I click the name, have it go to that scene in SketchUp."*
Wiring only — no new callback, no new mechanism.

- The scene-name cell is now
  `<td class='sc' data-go='<n>' title='Go to this scene in SketchUp'>` around
  the unchanged `hl(r.scene,hi)`, so the existing
  `querySelectorAll("[data-go]")` loop wires it alongside the row's `→`
  button. Ruby's `activate` callback is untouched.
- CSS: `td.sc { cursor:pointer }` + `td.sc:hover { color:var(--accent);
  text-decoration:underline }`. `--accent` is the variable `.go button:hover`
  already uses; no new colour.

**The two things I was told to check rather than assume — both checked
(observed, by reading the code):**
1. **Inert during an export.** `activate` begins `next if busy?(d, 'activate')`
   (~line 3136) and `busy?` (line 2931) returns true whenever `@running`,
   logging the reason into the window. The name cell calls the same callback,
   so it inherits that guard exactly. The JS-side `if(running) return;` used
   by the mode/walls/notes handlers is intentionally not copied: the Ruby
   guard explains itself in the log.
2. **The name cell had no other job.** It was a bare `<td>` holding only the
   highlighted name. There is no `<tr>`-level click handler anywhere in the
   dialog, and no drag, selection or inline editing on that column. Nothing
   was clobbered, and row behaviour is unchanged.

**No double fire**: the `→` button is inside the ROW but not inside the name
CELL, so one click hits one handler; its existing `stopPropagation()` is left
as it was.

`scripts/wr_tools/VERSION` → **1.20.2** (patch: markup + CSS wiring inside an
existing dialog).

**UNRUN IN SKETCHUP.** `python scripts/rbparse.py` → 68/68 parse, syntax only.
To verify: open **Proposal package**, hover a scene name (should turn orange
and underline), click it (SketchUp should jump to that scene, same as the row's
`→`). Then start an export and click a name mid-run: nothing should move and
the log should say the click was ignored because a batch is running.

## Also in this session — hide whole OBJECTS per scene, 1.21.0

The headline is a **bug**, not a feature request. Benton selected the booth,
pressed **USE MY SELECTION** in the proposal package's walls popover, and got
*"Nothing in your selection matched a named wall."*

### The shared-vs-duplicated question, answered

**Shared module, reduced surface.** `scripts/proposal-package.rb` (3154-3220)
calls `WR_SceneWalls.inventory`, `.apply`, `.keys_for_selection` and `.reveal`
directly — the Ruby engine is genuinely shared, not copied. What is duplicated
is only the **HTML/JS** (the popover has its own `wallsShow` markup, distinct
from the standalone dialog's two-column chips). And **`apply_selection` was
never wired into the popover at all**, which is the whole bug: the standalone
dialog's *Hide selection in this scene* buttons had no counterpart there.

### A scope correction, stated plainly

I was briefed that Benton had chosen **component instances only**. That was
wrong and I was told so before writing any code against it — **nothing had to
be undone**, I was still reading when the correction arrived. Entity Info shows
the booth as `Group (1 in model)` / Instance `MDL 96120 E (components)`, so an
instances-only filter would have listed nothing useful and missed the exact
object in question. Verified in the code myself: `inventory` walks
`model.entities.grep(Sketchup::Group)` as roots and `each_piece` matches
`PIECE_RE` group names — top-level ComponentInstances were never looked at at
all. The shipped filter is type-agnostic: **a top-level container, Group or
ComponentInstance, that is not already a wall row.**

## Produced

**`scripts/wr-scene-walls.rb`** (the shared engine + standalone dialog)
- `scan(model)` → `{ :walls, :objects }`, one `@units` index. `inventory`
  now just `scan(model)[:walls]` — contract unchanged for existing callers.
- `wall_units` (the old inventory body) now records `@wall_rooms`.
- `object_units`, `object_name`, `object_unit`, `unit_label`, `object_json`.
- `reveal` describes a row through `unit_label`, so walls and objects read the
  same in both windows.
- `state_json` gains `objects`.
- Dialog: an **Objects** tick-list under the two wall columns, with copy
  counts, a mixed-state note, SHOW ME, all/none links, and a new `reveal`
  action callback (the standalone dialog never had one).

**`scripts/proposal-package.rb`** (the popover)
- `self.walls_payload(model, n, pg)` — one shape, used by all three callbacks
  that redraw the popover, so they cannot drift.
- **`wallssel`** callback + **HIDE SELECTED** / **SHOW SELECTED** buttons,
  calling the module's existing `apply_selection`. Writes into the scene
  immediately, matching the standalone dialog.
- `wallsShow` renders an **Objects** section; the no-named-walls early return
  no longer swallows the body.
- USE MY SELECTION's failure message now points at HIDE SELECTED instead of
  only telling him to run *Name walls*.

**Housekeeping**: `scripts/wr_tools/VERSION` → **1.21.0** (a feature in two
dialogs plus a new module API), `DEVLOG.md` entry.

## Read first
- `scripts/wr-scene-walls.rb` — the `objects` comment block above
  `object_name`: why top-level-only is a correctness rule, and why the booth
  is a Group.
- `scripts/proposal-package.rb` — the comment above `wallssel`, which records
  the bug.

## Assumptions
- **observed** (by reading): the popover shares the module and lacked
  `apply_selection`; `inventory`'s roots are top-level Groups only.
- **derived**: `apply`, `keys_for_selection` and `reveal` absorb object units
  with no new code, because all three work through `unit[:pieces]` and
  `@units` — no second save mechanism was added.
- **assumed**: `Sketchup::Group#name` returns the Instance name Entity Info
  shows (so the booth row reads `MDL 96120 E (components)`). Not observed in
  SketchUp. If it comes back blank, the row falls back to the definition name
  and then to `unnamed group #<id>` — it degrades, it does not break.
- **assumed**: a top-level container nested-in-a-definition hazard is real
  (hiding a nested instance affects every placement). Reasoned from how
  definitions work, not probed.

## Open questions
- **UNRUN IN SKETCHUP.** `python scripts/rbparse.py` → 68/68 parse. Syntax
  only. To verify, in the proposal package: **Hide walls** on a scene → an
  **Objects** section should list the booth as `MDL 96120 E (components)`;
  tick it, **APPLY TO THIS SCENE**, confirm it vanishes on that scene and
  returns on the next. Select the booth in the viewport → **USE MY SELECTION**
  should tick its row rather than turn red. **HIDE SELECTED** should hide it
  immediately. **SHOW ME** should select it in the model. Repeat in the
  standalone *Hide walls per scene* dialog.
- Nested containers are deliberately unlisted. If Benton wants a booth that
  lives inside a room group to appear as a row, that is a follow-up and needs
  a decision about the shared-definition hazard first.
- **All three of this session's changes (1.20.1, 1.20.2, 1.21.0) are
  unverified by Benton.**
