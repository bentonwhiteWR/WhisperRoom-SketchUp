# SPEC — AUTO-SET: one click turns a selected booth into a finished proposal grid

Scoper, 10 Sep 2026. Plugin at 1.47.0. **Spec only — no production Ruby was written and
nothing under `scripts/` was modified.** Provenance is tagged per claim: **observed** = read
in the file named, **derived** = reasoned from something observed, **reported** = someone said
it, **assumed** = neither.

Benton, 10 Sep 2026 (verbatim, `.forge/GOAL.md`): *"I'd like to find a way to 'auto set' the
entire proposal package… select the whisperroom, then it would make scenes and label them
accordingly. This way, it can be clicked a 2nd time on a 2nd booth… a handful of shots, with a
few of them being assigned as 'renders'… would properly go through and 'hide walls' or set it
as 'image' or render. Almost do all of the work, and just have you review it before you
export."*

---

## 0. The one-paragraph version

A new module `WR_AutoSet` (`scripts/wr-autoset.rb`), driven from a new **AUTO-SET FROM A
BOOTH…** popover in the proposal-package window. Pick a booth (viewport selection, or a
dropdown of booths the model already names). It creates five scenes named after that booth,
stamps each page with a booth token so a second booth cannot collide and a re-run cannot
duplicate, marks each row Skip/Image/Render, and writes each scene's WALLS and ANNOTATIONS
answer through the existing per-scene pickers. Benton then reads the grid and exports. The
grid must be *readable* for that to be a review, so the WALLS and ANNOTATIONS columns —
today two stateless buttons (**observed**, `proposal-package.rb:4987-4988`) — gain a
per-row state summary. That column change is part of this work, not a nicety: without it
there is nothing to review.

---

## 1. How a booth is identified and selected

### 1.1 What the model already knows (observed)

| Fact | Where |
|---|---|
| A booth is a **top-level Group** (not a ComponentInstance) named `MDL 96120 E` | `proposal-package.rb:672-683` comment, observed in Entity Info 10 Sep 2026 |
| `booth_name?(nm)` → `nm =~ /\bMDL\b/ \|\| /\b\d{3,6}\s?[SE]\b/` | `proposal-package.rb:667-672` |
| `booth_groups(model)` returns the names of every top-level container passing that test | `proposal-package.rb:3024-3036` |
| `build-booth.rb` sets `booth.name = key`; `build-booth-components.rb:2527` builds a longer name but keeps `MDL` in it | both files |
| Door and vent sides are readable from tags `WR-Booth-Door` / `WR-Booth-Vent` | `build-booth.rb:117-118`, consumed by `proposal-scenes.rb:heading_to` |
| `WR_SceneWalls.keys_for_selection` already resolves a viewport selection through the containment tree by entity id | `wr-scene-walls.rb:293` |

So the identification problem is **already solved twice** in this codebase and AUTO-SET must
reuse both halves rather than invent a third.

### 1.2 The resolver — `WR_AutoSet.resolve_booth(model)`

Answer to "does he click it or pick it from a list": **both, one resolver, selection wins.**

1. **Selection path.** Walk `model.selection`; for each selected entity climb to its top-level
   ancestor container (the `subtree_ids` technique of `wr-scene-walls.rb:276`, run in
   reverse). Collect the distinct top-level containers hit.
   - Exactly one → that is the booth. It does **not** have to pass `booth_name?` — Benton may
     have a hand-named booth — but if it fails the test the popover says so in one line
     (*"'Enclosure A' does not name a booth model; scenes will be named after it anyway"*) and
     proceeds. Refusing here would be the tool second-guessing him.
   - More than one → refuse by name, list what was hit, ask him to select one.
   - Zero (nothing selected, or only loose geometry) → fall through to 2.
2. **List path.** Build the dropdown from every top-level container passing `booth_name?`
   (`booth_groups`, **observed**, already exists). Zero booths named → the dropdown lists
   **every** named top-level container instead, sorted, with a note that none of them names a
   model. This is the case a hand-drawn model lands in and it must not dead-end.
3. The popover always shows the resolved booth's name, its bounds size in feet-inches, and
   whether `WR-Booth-Door` / `WR-Booth-Vent` were found under it — the three facts that decide
   whether the cameras will be aimed right. If the door tag is missing, that is stated in
   **orange, before Apply**, because `proposal-scenes.rb:253` already falls back to `-90°` and
   silently produces a hero shot of the back of the booth (**observed** in its own report text).

### 1.3 What names the scene set — the booth token

Scene name: **`<Booth name> <NN>-<plate>`** → `MDL 96120 E 01-exterior`.

- Booth-first, because with two booths in a pack the booth is the disambiguator and SketchUp's
  scene tabs truncate from the right (**derived**).
- Ordering is not carried by the name. `plan_names` prefixes the file with the scene's **table
  position**, zero-padded (`scene_prefix`, `proposal-package.rb:546`, **observed**), so
  `01_MDL 96120 E 01-exterior.png` comes out already ordered for the proposal. Nothing about
  the naming needs to fight for sort order.
- **Two identical booths** (`MDL 4872 E` twice) is the collision case a name cannot survive.
  So the *name* is cosmetic and the *identity* is a stored token:

  > **`WR_AutoSet` attribute dictionary on the booth Group, key `token`.** Value:
  > `sanitize(booth.name)` plus `-2`, `-3`… if that token is already claimed by another booth
  > in this model. Written once, on first Apply, and read on every later run.

  Where two booths share a name, the second one's scenes read `MDL 4872 E (2) 01-exterior`.
  The token is what re-runs match on; the display name is what Benton reads. **Entity id is
  deliberately not the token** — it is not stable across a save/reopen in every case and it is
  unreadable in a scene tab (**assumed** for the stability half; the readability half is
  **derived**).
- He never types anything. A "rename this set" field is **out of scope** for v1 (§9).

---

## 2. Which shots, and which are renders

### 2.1 What a proposal actually consumes (observed — this is the strongest evidence in the spec)

Read from `proposals/examples/example-client/proposal-v2.json` and
`proposals/examples/peoplesspace/proposal-v2.json`:

**example-client — a genuine TWO-BOOTH pack.** Cover card reads *"10 renderings / 5 views per
booth"*; sections carry `boothOf: "1 of 2"` and `"2 of 2"`. Per booth:

| slot | `view` in the JSON | filename stem |
|---|---|---|
| 1 | Main Render *(booth 1's is the cover hero)* | `main-render` |
| 2 | Dimensioned View | `dimensioned` |
| 3 | Front Elevation | `front` |
| 4 | Rear View & Ventilation | `rear` |
| 5 | Top-Down Floor Plan | `top-down` |

**peoplesspace — one booth, twelve plates**, and only three carry the word *render* in their
filename: `01-overview-render`, `07-front-render-left-door`, `09-front-render-right-door`.
Every dimensioned plate, the plan, and the four detail shots do not.

### 2.2 The plate set

Five on by default; the sixth is a tick.

| # | plate id | proposal slot it fills | camera | default mode |
|---|---|---|---|---|
| 1 | `01-exterior` | Main Render / cover hero | 3/4 from the door side, **perspective**, el 12° | **RENDER** |
| 2 | `02-dimensioned` | Dimensioned View | same 3/4, parallel, el 20° | IMAGE |
| 3 | `03-front` | Front Elevation | **front** elevation, parallel, el 0° | **RENDER** |
| 4 | `04-ventilation` | Rear View & Ventilation | vent side +25°, parallel, el 14° | IMAGE |
| 5 | `05-plan` | Top-Down Floor Plan | plan, el 89° | IMAGE |
| 6 | `06-interior` *(off by default)* | — (peoplesspace-style extra) | inside, perspective | IMAGE |

**Change from today, and it is a real one:** `proposal-scenes.rb` plate 3 is `03-side`, an
elevation at `az +90°` — a **side** elevation (**observed**, `PLATES`). Both example packs ask
for a **Front Elevation** with the door open. Auto-set aims plate 3 at the door side (`az` from
`WR-Booth-Door`, el 0°). Anyone who wants the side keeps nudging and re-saving as they do
today. *This mismatch has been shipping since the plates were frozen and is worth Benton
seeing.* (**derived** from the two JSONs vs. the PLATES array.)

`06-interior` is named so it matches `INTERIOR_RE = /interior|inside|in-booth|booth\s+in/i`
(`proposal-package.rb:199`, **observed**) — which is what already selects the interior exposure
value for a render row. Naming it anything else would silently mis-expose it.

### 2.3 Renders — a knob, not a constant

`RENDERS_PER_BOOTH`, default **2**, range 0–6, a number field in the popover. Renders are
assigned down a fixed priority ladder and everything below the line is IMAGE:

> `01-exterior` → `03-front` → `04-ventilation` → `06-interior` → `02-dimensioned` → `05-plan`

Rationale, and the honest confidence on each step:
- Exterior hero first: it is the cover in both packs (**observed**).
- Front second: peoplesspace renders its two front options (**observed**).
- **Dimensioned and plan are last on purpose.** A plate whose job is to carry a dimension
  string does not need photoreal materials, and the render lane is the expensive one — one
  V-Ray row is minutes, one image row is a `write_image` call (**derived** from the batch's two
  lanes, `proposal-package.rb:1453`+).
- **Default 2 is the number I am least sure of.** example-client is 1 render per booth,
  peoplesspace is 3 of 12. Benton said *"a few"*, which is >1. So: default 2, and the number is
  the first control in the artifact. **reported/derived — flagged for his answer (Q1).**

---

## 3. Walls and annotations per plate — the highest-risk section

> **Say this out loud before building anything else in this spec.** Client-safe annotation mode
> was removed at 1.47.0 (**observed**, DEVLOG top entry). The per-scene ANNOTATIONS picker is
> now the *only* authority on what a customer image shows. There is no second net. An auto-set
> that writes the wrong annotation answer sends the wrong thing to a real customer under
> WhisperRoom's name — the exact shape of defect D5, where the PeoplesSpace plan went out
> carrying `Ceiling 8'-0" - HOUSE DEFAULT` (**observed**, DEVLOG). Everything below is written
> to fail *toward hiding*.

### 3.1 The annotation rule — an allowlist, never a denylist

> **THE RULE. An auto-set plate SHOWS only the annotation sets it names by hand. Every other
> family tag, and every single loose callout in the model, is hidden.**

Loose callouts are hand-placed `Sketchup::Text` that lands on **Untagged**, and SketchUp
refuses to hide the Untagged tag at all (**observed** — `tag.untagged_can_hide` FAILED live,
`wr-scene-annotations.rb:35-42`), which is exactly why the picker lists them individually. Their
content is unknown to any tool. An allowlist is the only policy under which unknown text cannot
reach a customer.

Per plate, in the picker's own polarity (**ticked = hidden**):

| plate | SHOWN (everything else ticked/hidden) | why |
|---|---|---|
| `01-exterior` | *nothing* | Hero. Clean or it isn't a hero. |
| `02-dimensioned` | `WR-Dims`, `WR-Dims-Doors` | Exactly `SHOWN_ON_DIMENSIONED` (`proposal-scenes.rb:118`, **observed**) — the existing, reviewed answer. Not re-litigated here. |
| `03-front` | *nothing* | Elevation reads as a product shot. |
| `04-ventilation` | `WR-Notes-Vent` **only if that tag exists in the model** | Opt-in by existence. A shop that has never made that set gets a clean plate. |
| `05-plan` | `WR-Dims`, `WR-Dims-Doors`, plus `WR-Notes-Plan` if it exists | The plan's whole job is the footprint and the door swing. |
| `06-interior` | *nothing* | |

**Never shown by auto-set, on any plate, ever:**
- `WR-Notes` — the house-default ceiling banner. This is the literal D5 string.
- `WR-Dims-Booth`, `WR-Dims-Selection` — working dimensions; a booth carrying both shows two
  different footprints with nothing on the page saying which is which
  (`proposal-scenes.rb:120-129`, **observed** — that reasoning is lifted, not invented).
- Every loose/Untagged callout.

Family membership is matched **live** against the model's own tags via
`WR_ProposalScenes.annot_tags(model)` and `ANNOT_RE = /\AWR-(Dims|Notes)(\z|-)/`
(**observed**), never against the frozen five — so a set Benton makes this afternoon is hidden
by tonight's auto-set instead of being invisible to it.

Written through **`WR_SceneAnnotations.apply(model, picks)`** with the target page selected
(`wr-scene-annotations.rb:499`), one page at a time inside one `start_operation`. Not
`apply_all` — that writes *the same* picks into every scene (**observed**,
`wr-scene-walls.rb:418` comment) and these picks differ per plate.

### 3.2 The wall rule — computed from the camera, not a frozen table

A static per-plate wall preset cannot work, and this is the second thing to say out loud: which
wall blocks a shot depends on where the booth sits in the room. `wr-scene-walls.rb` already
gives every wall unit a `:side` compass hint *relative to its own room* and warns that it is a
**hint** (**observed**, `side_of`, line 109, including the bug it already fixed about
room-local vs model space).

> **THE RULE.** For a plate whose camera eye is at `E` and whose target is the booth centre
> `C`: hide wall unit `W` when `((centre(W) − C).normalize) · ((E − C).normalize) > cos 60°`.
> That is: hide the walls standing between the camera and the booth. Show every other wall.

Per plate:

| plate | walls | note |
|---|---|---|
| `01-exterior`, `02-dimensioned` | camera-cone rule from the door-side 3/4 eye | usually the two walls of the near corner — which is what Benton does by hand today with `wr-lower-walls.rb` (**observed**, its header: *"I usually find the corner where the WhisperRoom is and lower those two adjacent walls"*) |
| `03-front` | camera-cone rule from the front eye | typically one wall |
| `04-ventilation` | camera-cone rule from the vent-side eye | |
| `05-plan` | **hide nothing** | Walls do not occlude from directly above, and the plan's job is to show the booth *in the room*. **derived** — a ceiling would occlude, but a ceiling is not a wall unit and `build-room.rb` builds none. |
| `06-interior` | hide nothing | The occluders here are the *booth's own* panels, which are not wall units. Stated in the log rather than silently doing nothing. |

Constraints on the rule:
- **Objects are never auto-hidden.** `WR_SceneWalls` also inventories top-level objects
  (`object_units`, **observed**) — that includes the booths themselves and every piece of
  furniture. Auto-set writes wall units only, and the popover says so.
- **Any wall the rule hides is logged with its room, its number, its compass hint and its dot
  product**, so a wrong call is readable rather than mysterious.
- Written through **`WR_SceneWalls.apply(model, picks)`** with the page selected
  (`wr-scene-walls.rb:341`). The picks hash must name **every** wall unit, `true` or `false` —
  never a partial hash — so a wall hidden on the previous plate cannot ride along into this one.
  This is the same discipline `set_dims` uses for tags (`proposal-scenes.rb:167-172`,
  **observed**).
- `page.use_hidden_objects` is forced on by `write_scene` already (**observed**); the popover
  still surfaces `pages_not_saving_hidden` by name afterwards.

### 3.3 Sun

Out of scope for v1, deliberately, with a one-line reason on screen: `wr-scene-sun.rb` has a
per-scene answer and an `apply_all`, but nothing in either example pack tells us what a
proposal's sun *should* be, and the shading contract already normalises plain image exports
(`proposal-package.rb:2084` `unit_shade_push`, **observed**). Guessing here buys nothing and
can dull a hero. **Open question Q4.**

---

## 4. Where it lives

### 4.1 Decision: a button in the proposal package, and the standalone tool stays

**A popover in `proposal-package.rb`**, opened from a new bar directly above the existing
`SHOWN →` bulk bar:

```
┌──────────────────────────────────────────────────────────────────────┐
│ AUTO-SET   [ Set up a booth… ]   MDL 96120 E · 5 scenes · 2 render     │
└──────────────────────────────────────────────────────────────────────┘
│ SHOWN →   [Render] [Image] [Skip]                  3 image · 2 render  │
```

Justification against how he actually works:
- The thing being pre-filled **is this grid**. A tool that fills a grid in another window makes
  him alt-tab to check its work, which is the review step he asked for.
- The window already loads `wr-scene-walls.rb` and `wr-scene-annotations.rb` and already owns
  the Skip/Image/Render marks (`mode_of`/`set_mode` on the Page, **observed**). Every API
  auto-set needs is in scope at that point with no new load.
- The popover pattern is proven three times over in this file — `wallsopen` / `annotsopen` /
  `sunopen` with `#wwrap`/`#wcard` markup and a `preview_*` cycle (**observed**). A fourth
  follows it exactly; nothing new is invented in the UI layer.
- Benton is a singleton-window person now (1.47.0-era change: *"If i re-click the proposal
  package right now, it opens it again… Id like for that to just act as a refresh"*,
  **observed** in `proposal-package.rb`). Adding a second window would walk that back.

### 4.2 What happens to `scripts/proposal-scenes.rb`

**Kept. Not replaced, not deleted.** Three reasons, all observed:

1. It is a **panel ability** with `@on`/`@off` (`ability_on` / `ability_off`). Deleting it
   breaks the OFF toggle for every model that already carries its five globally-named scenes.
2. It **owns the tag family** — `DIM_TAGS`, `NOTE_TAGS`, `ANNOT_TAGS`, `ANNOT_RE`,
   `annot_tags`, `annot_set_name`, `SHOWN_ON_DIMENSIONED` — and seven call sites plus two test
   harnesses name it (**observed**, DEVLOG 1.47.0 "What stayed, deliberately"). It is a library
   as much as a tool.
3. Its camera math (`aim`, `heading_to`, `subject_bounds`) is exactly what auto-set needs.

Changes to it are **two lines and no behaviour**: `@title` gains "(legacy — fixed five, no
booth)" and `report` gains one line pointing at AUTO-SET. New module `WR_AutoSet` lives in
`scripts/wr-autoset.rb` and `load`s `proposal-scenes.rb` as a library with the
`$wr_no_autorun` **local**-flag idiom (`wr-scene-annotations.rb:62-69`, **observed** — the
global form is the 2026-08-27 dead-button bug and must not be copied).

### 4.3 The grid must become readable — required, not optional

Today: `<td><button class='wbtn' data-walls>Hide walls</button></td>` and the same for notes
(**observed**, `proposal-package.rb:4987-4988`). Neither cell shows any state. After auto-set
writes 10 scenes' worth of answers, there is nothing on screen to review.

So `state(model)` gains two per-row fields and `draw()` renders them beside the button:

| cell | shows |
|---|---|
| WALLS | `all shown` · `2 hidden` (hover: the wall names) · `— no walls` |
| ANNOTATIONS | `all hidden` · `dims + doors` · `3 shown` (hover: tag names + loose count) · in **orange** when any loose/Untagged callout is shown |

The orange is the one new signal and it earns its place: a shown loose callout is the D5 class
of defect and is the single thing a reviewer must not miss. Computed from the page's own saved
state (`page.layers` for tags — `page_hidden_tags`, **observed** — and the units' `hidden?`
after selecting the page), not from what auto-set *intended* to write. The column must be able
to disagree with auto-set; that is what makes it a review.

**Cost note, honest:** reading true per-row state means selecting each page in turn, which is
what `apply_all` already does (**observed**). On a 13-scene model that is 13 page selections on
Rescan. If that is visibly slow, the fallback is to compute it only for stamped pages and show
`—` elsewhere. **assumed** — unmeasured, and the builder should measure before optimising.

---

## 5. Re-running — idempotency and collision

This is where the design breaks if it is going to. The whole mechanism is one stamp.

### 5.1 The stamp

On Apply, every page auto-set creates gets an attribute dictionary `WR_AutoSet`:

```
token      "MDL 96120 E"        the booth's token (§1.3)
plate      "01-exterior"        the plate id, not the display name
version    1                    stamp format
centre     "123.5,88.0,0.0"     the booth's bounds centre when the scenes were aimed
```

Precedent is exact: `mode_of`/`set_mode` already store the Skip/Image/Render mark on the Page
in an attribute dict, and `reorder_scene` relies on those surviving a move (**observed**,
`proposal-package.rb:274-293`, `934`).

> **THE CONTAINMENT RULE. Auto-set reads, writes, renames and erases only pages carrying a
> `WR_AutoSet` stamp with the token it is working on. A page with no stamp is never touched,
> under any code path, including the remove path.** Benton keeps his own scenes; this is the
> rule that guarantees they survive.

### 5.2 The five cases

| case | detection | behaviour |
|---|---|---|
| **Second booth** (the stated case) | resolved token has no stamped pages | Create. New pages are **appended** after all existing ones, so booth 1's five stay 1–5 and booth 2's become 6–10 — which is exactly the order `example-client`'s pack wants (**observed**). No name can collide: the token is in every name. |
| **Same booth again** | stamped pages found for this token | Popover switches to a three-way choice, defaulting to **Update**: <br>· **Update** — rewrite walls, annotations and mode marks on the existing pages; **do not re-aim cameras** unless the re-aim box is ticked. <br>· **Add a second set** — token gets an ordinal, five new pages. <br>· **Remove this booth's scenes** — erase the stamped pages for this token only. |
| **Booth moved** | stored `centre` differs from live bounds centre by > 1" | Update path pre-ticks **re-aim cameras** and says why in one orange line. The threshold is 1" because that is the wall gap Benton draws to (**derived** from CLAUDE.md's 1" rule); anything smaller is float noise. |
| **Scene edited by hand** (renamed, camera nudged, walls changed) | stamp present, name ≠ expected name | Matched **by stamp, never by name**. The popover lists it as *"renamed by hand: `<current name>` — will be updated, not renamed back."* Auto-set **never renames a page it did not just create**. A nudged camera survives Update by default — the framing is a taste call and `proposal-scenes.rb` says so in its own report (**observed**). |
| **Booth deleted, scenes left** | token's booth group is gone | Popover offers **Remove these orphaned scenes**; it does not do it silently. |

### 5.3 Why cameras are not re-aimed by default

Because the single most valuable thing in an auto-set model is a framing Benton fixed by hand,
and re-aiming is the one operation that destroys it invisibly. Walls and annotations are safe
to rewrite because they are *policy* and auto-set is the policy authority; the camera is
*taste* and it is not. (**derived**, and consistent with `proposal-scenes.rb`'s own stated
position on framing: *"THE EXACT ANGLE IS BENTON'S CALL"*.)

### 5.4 Undo

`page.update` is outside SketchUp's undo stack — Ctrl+Z does not reverse a scene write
(**observed**, `wr-scene-walls.rb:418` comment and DEVLOG 1.25.2: Benton, *"It said I could
ctrl+z and that didnt work"*). Both scene modules already record one step and the window
already offers **UNDO LAST APPLY** (`undo_mod`, `proposal-package.rb:1008`, **observed**).

Auto-set writes many pages, so one module-level step is not enough. It records **its own**
step: the pages it created (to erase) plus, for pages it updated, each page's prior walls and
annotations snapshot — the same `snapshot_keys` shape both modules use — and registers as the
most recent writer so UNDO LAST APPLY reads *"Undo AUTO-SET — MDL 96120 E, 5 scenes"*. One
step, this session, this model, used up when taken. Same contract as the existing undo, no new
promise.

---

## 6. Ordered build steps

Each step is independently verifiable and names files that were opened for this spec.

1. **`scripts/wr-autoset.rb` — module skeleton + booth resolver.** `resolve_booth`,
   `booth_token`, `token_pages`, the stamp read/write. Loads `proposal-scenes.rb` with the
   **local**-flag idiom. *Verify:* `scripts/rbparse.py` clean; a new `rbtest-autoset.py` drives
   `booth_token` collision numbering and stamp round-trip against fixtures (the pattern of
   `rbtest-proposal.py`, **observed**).
2. **Plate table + camera derivation.** `PLATES` (six), `renders_for(n)` ladder, and a pure
   `eye_for(plate, centre, radius, door_az, vent_az)` reusing `WR_ProposalScenes.aim`.
   *Verify:* pure functions under `rbtest-autoset.py`; `renders_for(0..6)` returns the ladder
   prefix; `03-front` az equals the door az.
3. **The annotation policy, as a pure function.** `annot_picks(model, plate)` → the full picks
   hash. *Verify:* fixtures — `WR-Notes` hidden on all six; loose callouts hidden on all six;
   `02-dimensioned` shows exactly `WR-Dims` + `WR-Dims-Doors`; `WR-Notes-Vent` shown on plate 4
   only when present. **These are the tests that matter most in this spec.**
4. **The wall policy, as a pure function.** `wall_picks(units, centre, eye)` → full picks hash,
   every unit keyed. *Verify:* fixtures with synthetic centres — a wall behind the camera is
   shown, a wall in front is hidden, `05-plan` returns all-false.
5. **The writer.** Create/update pages, select each, call `WR_SceneWalls.apply` then
   `WR_SceneAnnotations.apply`, `set_mode`, stamp, restore the starting page. One
   `start_operation`. *Verify:* live in SketchUp — this step cannot be proven offline and must
   not be claimed as proven.
6. **Undo step registration** (§5.4). *Verify:* live; UNDO LAST APPLY names the auto-set.
7. **`proposal-package.rb` — WALLS/ANNOTATIONS state in `state()` and `draw()`** (§4.3).
   *Verify:* `scripts/jstest-proposal-dialog.js` — every literal id the JS reads must exist in
   the HTML (**observed**, that harness caught exactly this class at 1.47.0).
8. **`proposal-package.rb` — the AUTO-SET bar, popover, and `autosetopen` / `autosetapply` /
   `autosetclose` callbacks.** *Verify:* jstest + rbparse; live open.
9. **`scripts/proposal-scenes.rb` — two cosmetic lines** (§4.2). *Verify:* rbparse; its
   existing harness checks still pass.
10. **`scripts/wr_tools/VERSION` 1.47.0 → 1.48.0** (minor: a feature). Required for *any*
    change under `scripts/`, a new file included (**observed**, CLAUDE.md). Then DEVLOG entry,
    commit, push — pushing is not installing, and Gabe needs `git pull` +
    `install-plugin.py` + restart for the `wr_tools/` half.

---

## 7. Acceptance criteria — checks a builder can actually run

**Offline (must all pass before it is called built):**

- [ ] `python scripts/rbparse.py` — clean across every `.rb`. `rbcheck.py` is not evidence.
- [ ] `rbtest-autoset.py` — the pure-function fixtures of steps 1–4, including every annotation
      case in step 3.
- [ ] `rbtest-proposal.py` — still passes unchanged; `state()` gaining two fields breaks nothing.
- [ ] `node scripts/jstest-proposal-dialog.js` — every literal element id resolves.
- [ ] Three mutants killed: (a) drop `WR-Notes` from the never-shown list → an annotation
      fixture FAILS; (b) make `wall_picks` return a partial hash → a wall-leak fixture FAILS;
      (c) match re-run pages by name instead of stamp → the renamed-scene fixture FAILS.

**Live in SketchUp (the only proof that counts for steps 5–8):**

- [ ] Untitled model, one booth: click AUTO-SET → 5 scenes named `MDL … 0n-…`, grid shows
      2 render / 3 image, WALLS and ANNOTATIONS columns non-empty on all five.
- [ ] Click through all five scene tabs: on `01-exterior` no dimension string and no text is
      visible in the viewport; on `02-dimensioned` the **room** dimensions and door dimensions
      are visible and the booth catalogue numbers are not.
- [ ] Second booth, second click: 10 scenes, booth 1's five untouched, no name collision, its
      camera nudges preserved.
- [ ] Same booth, Update: walls/annotations rewritten, a camera nudged beforehand still nudged.
- [ ] Move the booth 3 ft, re-run: re-aim pre-ticked, orange line names the distance.
- [ ] Rename an auto-set scene by hand, re-run: matched, updated, **not renamed back**.
- [ ] A hand-made scene called `My test` exists throughout: never touched, never erased,
      including through Remove.
- [ ] UNDO LAST APPLY after an auto-set puts the model back and names the booth.
- [ ] Export the pack and open every PNG: **no `Ceiling 8'-0" - HOUSE DEFAULT` banner on any
      plate.** This is the D5 regression check and it is non-negotiable.

---

## 8. Edge cases and failure modes

| case | behaviour |
|---|---|
| No booth in the model at all | Refuse by name, list what top-level containers exist, point at `build-booth.rb`. Never create globally-named scenes as a fallback. |
| Booth has no `WR-Booth-Door` tag | Proceed, but say **before Apply** that the door side is assumed `-90°` and the hero may face the back. (`proposal-scenes.rb` already only says this *after*, in the console — **observed**.) |
| Model has no rooms / no named walls | Wall picks are empty; log *"no named walls — run Name walls for the scene picker (`wr-name-walls.rb`) if this room was drawn by hand"* (**observed**, that is the documented fix). Not an error. |
| A scene does not save hidden objects / hidden tags | Both modules already report it; auto-set surfaces the names in **red** and offers the existing FIX SCENES path. Silent here means walls do not come back and images are wrong. |
| A batch is running | The bar is disabled, like every other control (`running` guard in `draw()`, **observed**). |
| Model is not saved | Allowed — auto-set touches scenes, not folders. The FOLDER section already handles the unsaved case (`resolve_dir`, **observed**). |
| Two booths, one nested inside a component | Not a top-level container, so not resolvable, so refused with the reason. Hiding a nested container would be a model-wide change wearing a per-scene costume (**observed**, that exact phrase, `wr-scene-walls.rb:196`). |
| 20+ scenes after four booths | Works; note that `scene_prefix` widens to two digits past nine and therefore **renames files** for previously-exported scenes (**observed**). Say so once in the log. |

---

## 9. Explicitly out of scope for v1

- Building the Ruby. **This spec is the approval gate; nothing ships until Benton approves the
  artifact.**
- Changing what the WALLS or ANNOTATIONS pickers *do*. Auto-set drives them.
- Sun presets (§3.3).
- Renaming a scene set, or a user-typed set name.
- Writing `proposal-v2.json` from the model. Real prize, separate job — the manifest already
  carries most of it (`write_manifest`, **observed**) and `agent_prompt` already reconstructs
  from it.
- Auto-hiding *objects* (furniture, the other booth) — §3.2.
- Any change to `proposal-scenes.rb` behaviour.

---

## 10. Open questions for Benton

| # | question | default if he doesn't answer |
|---|---|---|
| **Q1** | **Renders per booth — 2, or 1, or 3?** Your two example packs disagree (1 and 3). | 2 · exterior + front |
| **Q2** | Plate 3: today's tool makes a **side** elevation; both proposal packs want a **front** elevation with the door open. Switch it? | Switch to front |
| **Q3** | Should `06-interior` be on by default? peoplesspace shipped an interior clear-floor plate. | Off |
| **Q4** | Should auto-set also preset the **sun** per scene? | No (§3.3) |
| **Q5** | With two booths in one room, should each booth's plates hide the *other* booth? | No — both stay visible |

---

## 11. Self-ranking record

Rubric (`rank` skill), six dimensions, 10 each, weakest-link reported — never averaged.

| dimension | what it measured | c1 | c2 | c3 | c4 |
|---|---|---|---|---|---|
| Grounding | every load-bearing claim tied to a file+line actually opened | 6 | 8 | 9 | 9 |
| Ambiguity resolved | no fork left silent; forks that change the work asked | 5 | 7 | 9 | 9 |
| Mechanism correctness | design matches how the API and this codebase really behave | 6 | 8 | 9 | 9 |
| Idempotency / collision | the stated break point is actually engineered | 4 | 7 | 9 | 9 |
| Buildable without follow-up | ordered steps, real paths, runnable acceptance | 5 | 7 | 8 | 9 |
| Risk named as loudly as the win | the 1.47.0 annotation exposure treated as the top risk | 5 | 8 | 9 | 9 |
| **Weakest link** | | **4** | **7** | **8** | **9** |

- **c1 → c2.** c1 asserted a plate set from the existing `PLATES` array. Reading both
  `proposal-v2.json` examples replaced assumption with evidence — and turned up the
  side-vs-front mismatch (Q2) and the fact that example-client is *already* a two-booth pack.
  Idempotency was one paragraph; it became §5's stamp and five cases.
- **c2 → c3.** The wall preset was still a frozen per-plate table, which cannot be right for a
  booth that moves. Replaced with the camera-cone rule derived from `side_of`'s own documented
  limits. The annotation rule was reframed from denylist to **allowlist** after re-reading why
  Untagged cannot be hidden by tag — that reframe is the single largest correctness gain in the
  spec.
- **c3 → c4.** Found that the WALLS/ANNOTATIONS columns render stateless buttons, so "review
  before export" had nothing to review; §4.3 became a required step rather than a nicety, with
  its cost honestly flagged as unmeasured. Added the three mutants and the D5 export check.
- **c4 → c5 gained nothing** — the next pass produced only wording changes, so the loop stopped
  at **9/10, weakest link: buildable-without-follow-up**, which stays at 9 only because Q1 and
  Q2 are genuine product decisions that are Benton's to make, not gaps in the analysis.
