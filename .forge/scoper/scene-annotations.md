# Scoping — per-scene ANNOTATIONS in the proposal package (rev 2, hybrid)

2026-09-09, Scoper (Fable). Rev 1 recommended tags only; **rev 2 follows the live probe**:
both mechanisms are proven, one FAIL reshapes the design. Mockup:
`.forge/scoper/scene-annotations.mockup.html` (Artifact link in HANDOFF.md). Probe:
`.forge/scoper/probe-scene-annotations.rb`.

Provenance words: **observed** = read in this repo's code, a DEVLOG live entry, or the probe
output below; **derived** = follows from observed facts; **reported** = SketchUp docs /
product behaviour not exercised here; **assumed** = a guess, named as one.

---

## The problem in one sentence

Benton loads some scenes with a lot of text and dimensions that must not appear on other
scenes, and wants to choose that per scene — smoothly, on a model he has not pre-sorted —
from the same place he already chooses which walls a scene hides.

## Goal

An **ANNOTATIONS** column beside WALLS in `scripts/proposal-package.rb`. Each row opens a
picker for that scene listing every annotation the model has — as **sets** (tags) and as
**single items** — in one list with one rule: *ticked = hidden when this scene exports*.
The choice is saved into the scene itself, so both export lanes honour it with no exporter
change, and `manifest.json` records both kinds of hide as BY DESIGN, the way
`groups_hidden` does for walls.

---

## The evidence (observed, SketchUp 26.2.243, 9 Sep 2026, Untitled model)

Console output of `.forge/scoper/probe-scene-annotations.rb`, verbatim. **The Builder pastes
this block into the DEVLOG entry for the build.**

```
probe-scene-annotations — SketchUp 26.2.243, mask=384 (HIDDEN_OBJECTS=256, HIDDEN_GEOMETRY=128, LAYER_VISIBILITY=32)
TAG PATH (recommended mechanism)
  PASS tag.page_layers_lists_hidden_tag — A hides ["WR-Notes-Probe"], B hides []
  PASS tag.roundtrip_B_A_B — B=true A=false B=true (expect true/false/true)
  PASS tag.entities_follow_tag
  FAIL tag.untagged_can_hide — Untagged visible? after hide = true
PER-ENTITY PATH (walls mechanism, page.update(384))
  PASS entity.screen_text — B hidden?=false A hidden?=true (expect false/true)
  PASS entity.leader_text — B hidden?=false A hidden?=true (expect false/true)
  PASS entity.linear_dim — B hidden?=false A hidden?=true (expect false/true)
  PASS entity.3d_text_group — B hidden?=false A hidden?=true (expect false/true)
  PASS entity.update_mask_leaves_camera — camera identical before and after
```

What each line settles:

| check | meaning for the design |
|---|---|
| `tag.*` PASS | A scene saves and re-asserts per-tag visibility; `Page#set_visibility` + `Page#layers` are the read/write pair. **Sets work.** |
| `entity.*` PASS | A scene saves per-entity hidden state for screen text, leader text, linear dimensions and 3D-text groups, through the walls' exact call `page.update(384)`. **Click-to-hide works, no setup.** |
| `entity.update_mask_leaves_camera` PASS | Mask 384 never touches the saved camera — the walls guarantee holds for annotations. |
| **`tag.untagged_can_hide` FAIL** | **SketchUp will not hide Untagged.** Anything on Untagged is unreachable by the tag mechanism, full stop. |

### Why the FAIL is load-bearing, said plainly

Benton's text today is very likely mostly **Untagged** (assumed — hand-placed text lands on
the active tag, normally Untagged; only the WR tools write to `WR-Dims*` / `WR-Notes`). So:

1. **A tag-only picker could not have hidden most of his existing text.** It would have
   listed sets that were empty and left his real callouts untouched. The per-entity path
   is what makes the feature work on a model nobody pre-sorted.
2. **The UI must never offer a tag-hide on Untagged.** There is no "Untagged" set row.
   Untagged items are listed *individually* under **NOT IN A SET — tick one by one**, with
   *all · none* links so a batch is still one click, and a MOVE INTO A SET flow for anyone
   who wants a reusable set. A tag-hide that silently does nothing is the one outcome
   this spec forbids.
3. **Client-safe has the same hole today** (derived: `annot_push` at
   `scripts/proposal-package.rb` 1422–1470 hides *tags* only; Untagged cannot be hidden →
   an Untagged callout goes out on a client-safe image). Step 7 closes it with the
   per-entity path. If it is deferred, the dropdown's helper text must say so.

---

## Approach — one list, one rule

The picker is **one unified list** rather than two panels, because Benton's question was
about smoothness and two mechanisms the operator has to choose between is the opposite of
smooth. The operator ticks rows; the tool decides which mechanism each row needs:

| row kind | what it is | ticked = | mechanism on Apply |
|---|---|---|---|
| **Set** | a tag in the `WR-Dims*` / `WR-Notes*` family | the whole set hidden in this scene | `layer.visible = false` + `page.set_visibility(layer, false)` |
| **Item** (member of a set, behind the set's expand arrow) | one text / dimension / 3D label on that tag | this item hidden here even when its set shows | `entity.hidden = true` + `page.update(384)` |
| **Item** (not in a set) | one text / dimension / 3D label on Untagged or a non-family tag | this item hidden in this scene | same as above |

Rules that keep it one thing:
- **Polarity = walls.** Ticked = hidden when this scene exports. Untick = shown again.
  Every row is sent on Apply, not only touched ones (walls rule), so unticking reliably
  shows.
- **A ticked set greys out its member rows** ("hidden with the set") — the member flag is
  kept, not cleared, so unticking the set brings back exactly the members that were
  showing before.
- **Row label = the entity's own text**, truncated at ~40 chars, with a kind glyph (text /
  dim / 3D) and, for non-family tags, the tag name in muted type. Dimensions show their
  rendered string (`Dimension#text` returns the rendered value — observed, DEVLOG 1.10.8).
- **Group headers carry `all · none`**, so "hide every loose callout on this scene" is
  header → all → Apply. That is the click-to-hide batch with zero setup.
- **USE MY SELECTION** ticks the rows for whatever annotations are selected in the model
  (adds, never unticks) and, when every selected item belongs to one set, says so: *"3 of
  WR-Notes-Plan's 22 items ticked — tick the set to hide all of them."*
- **SHOW ME** on a set selects and zooms everything on the tag; on an item, that entity.
- **MOVE SELECTION INTO A SET** stays, marked *optional, for every scene*: it re-tags
  selected annotations into an existing or new family tag. It is for reuse across many
  scenes and for client-safe coverage; nobody needs it to hide something once.

### Why sets still exist (and stay in the family)

Hiding 300 texts with one flag, reusing that across a dozen scenes, and being covered by
client-safe are all things a tag does that per-entity flags do not. The family rule from
rev 1 stands: `ANNOT_TAGS` is a frozen five-name list consumed in seven places
(`proposal-package.rb` ×5, `wr-mode.rb` ×3, `wr-preflight.rb` ×1). A set outside the
family would leak past client-safe (defect D5 again), so new sets are named
`WR-Notes-<name>` and every consumer matches the family live (Steps 1–2).

### Save mechanics (per Apply, one operation)

```
sets:   layer.visible = !hide;  page.set_visibility(layer, !hide)
items:  entity.hidden = hide
then:   page.use_hidden_layers = true, page.use_hidden_objects = true  (if off — walls' fix)
        page.update(WR_SceneWalls.update_mask)      # 384 — observed camera-safe
```
`set_visibility` writes the tag half without a page update; `page.update(384)` writes the
entity half and, like walls, also re-saves whatever wall flags the scene already asserted
when it was selected on open — no new hazard (derived).

### The ANNOTATION dropdown

Draft mode already means "each scene shows what it saved" (observed: `unit_image` hides
only `LIGHT_TAGS` unless client-safe). Relabel, no behaviour change, stored value stays
`draft`:
- `client` → **Client-safe — hide every annotation for the whole run**
- `draft`  → **Per scene — each scene shows what its picker left showing**

---

## Steps (ordered; each independently checkable)

**1. `scripts/proposal-scenes.rb` — the family becomes live.** Below `ANNOT_TAGS` (line 64):
`ANNOT_RE = /\AWR-(Dims|Notes)(\z|-)/`; `annot_tags(model)` → `(ANNOT_TAGS +
model.layers.map(&:name).grep(ANNOT_RE)).uniq` rescued to `ANNOT_TAGS`; `annot_set_name(user)`
→ verbatim if it already matches, else `"WR-Notes-#{slug}"`, nil if empty. Keep `ANNOT_TAGS`
(mocked at `rbtest-proposal.py` 259, `rbtest-lights.py` 801–806).

**2. Every consumer reads the live family.** `scripts/proposal-package.rb` 1440, 1462, 1662,
2359, 3285; `scripts/wr-mode.rb` 178 (`snapshot`) and in `to_mode` ~312 fill family tags
missing from `target_snap['dims']` with the mode polarity; `scripts/wr-preflight.rb` 50
(grep-located, not opened — Builder reads it).

**3. New `scripts/wr-scene-annotations.rb`** — `module WR_SceneAnnotations`, house header
(`# @title Hide notes & dimensions per scene...`, `# @cat Scenes and images`, `# @rank 5`),
mechanism comment citing the probe. API, mirroring `WR_SceneWalls`:
- `KINDS`: `Sketchup::Text`, `DimensionLinear`, `DimensionRadial`, and `Group` whose name
  starts `label: ` (3D text). `DEPTH = 2`.
- `inventory(model)` → `{ sets: [{key:'t:WR-Notes-Plan', name, counts:{text,dims,labels},
  hidden:bool, members:[item…]}], loose: [item…] }` where item = `{key:'e:<entityID>',
  kind, text, tag, hidden: entity.hidden?}`. Fills `@units`. Loose = Untagged + non-family
  tags, ordered Untagged first. Sets listed even when empty.
- `keys_for_selection(model)` → item keys of selected annotation entities (+ the set key
  hint when they all share one family tag).
- `reveal(model, key)`, `move_selection_to_set(model, name)` (refuses non-annotations by
  name), `apply(model, picks)` per the save mechanics, `apply_selection(model, hide)`
  (the standalone tool's immediate buttons — walls' `apply_selection` filters to
  groups/instances; this one accepts `KINDS`; **do not edit wr-scene-walls.rb**),
  `pages_not_saving(model)` → names with `use_hidden_layers?` or `use_hidden_objects?` off,
  `fix_pages(model)`.
- Standalone `UI::HtmlDialog` mirroring wr-scene-walls' (Shown / Hidden columns, frame-change
  observer, `$wr_no_autorun` guard, autorun line). Panel icon: `scripts/wr_tools/icon-map.json`
  entry + SVG beside `wr-ico-scene-walls.svg` (not opened — follow that precedent).

**4. `scripts/proposal-package.rb` — the column and the modal.**
- line 106: `load … 'wr-scene-annotations.rb'` under the same guard.
- 3231 `<th>`: add `<th>ANNOTATIONS</th>` after WALLS; 3397 row: second `.wbtn`
  `data-annots='n'` reading **Hide notes**.
- Callbacks after `wallsclose` (2985), all behind `busy?`: `annotsopen` (select the scene,
  reuse `@walls_return`, push `annotsShow({n, scene, sets, loose, warn})`), `annotsapply`
  (`{n, picks:{key:bool}}`), `annotspick`, `annotsreveal`, `annotsmove` (`{name}`),
  `annotsclose`.
- Markup `#awrap/#acard/#atitle/#abody/#amsg/#afoot` reusing the `w*` classes; group
  headers with `all · none`; set rows with an expand toggle revealing member rows
  (indented, disabled while the set is ticked); the `.amove` row; footer USE MY SELECTION /
  APPLY TO THIS SCENE / CANCEL. JS mirrors `walls*` as `annots*`.
- 3277–3285: dropdown relabel + live-family helper text.

**5. Manifest — both kinds of hide are BY DESIGN.** `scripts/proposal-package.rb`:
- Pure `hidden_annot_tags(hidden, use_hidden, present, client_safe)` beside
  `shown_annot_tags` (529): client-safe → `[present, note]`; `use_hidden` false → `[nil,
  note]`; `hidden` nil → `[nil, note]`; else `[present & hidden, nil]`.
- Impure `collect_hidden_annotations(model)` beside `collect_hidden_groups` (2320): walk
  `model.entities` to `DEPTH`, emit `{'kind','tag','text'}` for every `KINDS` entity with
  `hidden?` true; rescued to nil. Called at both sites `collect_hidden_groups` is called
  (1674 image lane, 1772 render lane), stored as `p[:annotations_hidden]`, carried on the
  result row and through `manifest_rows` (547) as `row['annotations_hidden']`.
- `manifest_rows`: `row['annotation_tags_hidden'] = p[:hid]`, `row['annotation_hidden_note']`
  when present.
- `MANIFEST_NOTES` (479), two entries: *"annotation_tags_hidden: annotation sets (tags) the
  scene's SAVED state hides — a callout missing from the image is missing BY DESIGN
  (per-scene annotation hiding, wr-scene-annotations.rb). null = unreadable, never means
  nothing was hidden; [] means that."* and *"annotations_hidden: single callouts (kind,
  tag, text) hidden in the model when this row exported — the same BY DESIGN reading,
  for items hidden one by one. A 3D-text label also appears in groups_hidden as
  'label: …'. A callout is absent from the image if it is in annotations_hidden OR its
  tag is in annotation_tags_hidden. null = not recorded; [] = nothing hidden singly."*
- `collect_annotations` (2247): add `when Sketchup::Group` → `label: ` prefix → kind
  `3d_text`. `MANIFEST_FORMAT` stays 1 (additive), said in the DEVLOG.

**6. `scripts/rbtest-proposal.py`.** Lift `hidden_annot_tags` (st5–st8), `mr6`
(`annotation_tags_hidden` rides the row), `mr7` (`annotations_hidden` rides the row,
nil when the result lacks it). Shim `WR_ProposalScenes.annot_tags` where `annot_push` is
lifted. Mutation-check each. `python scripts/rbparse.py` clean.

**7. Client-safe closes the Untagged hole (recommended in this build; Q-CS in the mockup).**
`annot_push` (1422): after hiding the family tags, also hide every loose `KINDS` entity on
a non-family tag (`entity.hidden = true`), recording `{entityID → was_hidden}` into
`@annot_saved_entities` **before** the first flip (D10 discipline, 1.9.6); `annot_pop`
restores them. The log line names the count. `annotations_hidden_in_images` then means
what it says. **If deferred:** the dropdown helper text reads *"Client-safe hides the
WR-Dims / WR-Notes sets only — text on Untagged still exports. Hide it per scene."*

**8. Ship.** `scripts/wr_tools/VERSION` 1.19.16 → 1.20.0 (new tool script), DEVLOG entry
with the probe block above verbatim, commit + push.

**9. Live verification** — the acceptance list below, on a scratch model: `proposal-scenes.rb`
plates + `build-room.rb` room + six hand-placed Untagged texts + two hand dimensions.

---

## Acceptance criteria

1. **Row → Hide notes** opens the modal titled *Notes & dimensions hidden in "<scene>"*, the
   viewport switches to that scene; CANCEL returns to the scene Benton was on.
2. **Loose item, per entity:** tick one Untagged text, APPLY → it disappears; another scene
   tab → it is back; first tab → gone. Same for a dimension and a `label:` group.
3. **Batch of loose items:** NOT IN A SET → *all* → APPLY hides every one; *none* → APPLY
   shows every one. Nothing else in the model changed (walls' flags unchanged — compare
   `collect_hidden_groups` before/after).
4. **Set, per tag:** tick `WR-Dims-Booth`, APPLY → gone on this scene only; SketchUp's Tags
   panel agrees; other scenes unchanged.
5. **Member under a shown set:** expand `WR-Notes-Plan`, tick 2 of 22, APPLY → those 2 gone,
   20 remain; tick the set → all 22 gone, the two member ticks still shown greyed; untick the
   set, APPLY → 20 back, the 2 stay hidden.
6. **Untagged is never offered as a set**: no set row for it; its items list individually;
   the header hint says why.
7. **Export (Per scene):** row 1 image lacks exactly what was ticked; `manifest.json` row 1
   has `annotations_hidden` = the ticked items (kind/tag/text), `annotation_tags_hidden` =
   the ticked sets, row 2 `[]`/`[]`.
8. **Export (Client-safe):** no annotation of any kind on any image, including Untagged
   text (Step 7); after `finish` every tag and every entity flag is back as found.
9. **USE MY SELECTION** with one Untagged text ticks its row; with 3 texts from one set,
   ticks the 3 and offers the set; with a wall selected: *nothing in your selection is an
   annotation*.
10. **MOVE SELECTION INTO A SET** with 4 Untagged texts → "New set… Plan" creates
    `WR-Notes-Plan`, moves exactly those 4, refuses a selected wall by name, re-lists.
11. **Mode toggle** (`wr-mode.rb`) after creating a set: render turns it off; scene clicks
    still restore each scene's own tag and entity state.
12. **Scene with `use_hidden_layers` or `use_hidden_objects` off** → banner names it; Apply
    turns both on.
13. **Camera:** the scene's saved camera is byte-identical before and after Apply
    (`cam_tuple` compare), on a scene whose viewport was orbited after opening.
14. `rbtest-proposal.py` 100% green with st5–st8, mr6, mr7; `rbparse.py` clean. Walls
    picker, `groups_hidden`, render-lane row shape unchanged.

## Edge cases and failure modes

- No scenes → walls' "No scene is selected" message. Stale key (entity erased, tag deleted)
  → skipped and counted, "hit Refresh".
- Annotations nested deeper than `DEPTH` are not listed; a set hides them anyway (tag
  visibility is not depth-limited — derived); the header says so.
- A text on a non-family tag (e.g. `WR-Booth`) lists under NOT IN A SET with its tag shown.
- Hundreds of loose items: the list scrolls; `all · none` per header keeps it one click.
  (Performance: `entityID` keys, one walk per open — same cost as `collect_annotations`.)
- V-Ray lane: V-Ray ignores SketchUp Text/Dimensions and renders 3D-text geometry only when
  visible (**reported**, not observed). Fold one render of a scene with a hidden `label:`
  group into the acceptance run.
- Walls + annotations on one scene: `page.update(384)` re-saves both entity families; the
  wall flags it re-saves are the ones the scene asserted on open (derived, same as walls).

## Out of scope

- Section planes per scene (SketchUp saves them natively). Rewriting the walls feature.
  Fixing `Sketchup::Text` size (a Model Info global — DEVLOG 1.19.16).
- Hiding annotations *inside components* deeper than `DEPTH` one by one.

## Decisions still open for Benton (in the mockup's copy-back)

| # | fork | recommendation |
|---|---|---|
| Q1 | separate ANNOTATIONS column vs one HIDE… button with Walls/Notes tabs | separate — "similar to walls" |
| Q3 | new sets named `WR-Notes-<name>` (prefix editable) | keep the family prefix; client-safe depends on it |
| Q4 | Client-safe stays the dropdown default | yes |
| Q6 | wording: column header, row button | ANNOTATIONS / Hide notes |
| Q7 | set members behind an expand arrow vs always listed | behind the arrow — the list stays short |
| Q-CS | close the Untagged client-safe hole in this build | yes |

Settled by the probe or by consistency, no longer asked: polarity (ticked = hidden, walls
rule); single-callout hiding (in scope, proven); Untagged (never a set).

Confidence: **high** on both mechanisms (observed live); **high** that the unified list is
buildable from the walls modal; **medium** on the interaction details until Benton reacts.
