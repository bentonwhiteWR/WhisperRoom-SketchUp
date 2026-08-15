# Proposed structure and icon briefs

A proposal. Nothing here has been applied — this role is read-only, and every file outside
`.forge/researcher/` is untouched.

The organising principle is **the order Benton's day happens in**, not what the code
touches. A new user should be able to read the category names top to bottom and see the
pipeline `CLAUDE.md` describes: floor plan → room → booth → dimensions → scenes → images.

---

## The category tree

Six visible categories, 20 visible scripts. Eight scripts move off the default panel.

### 1. Draw the room
> The client's space, built from a take-off.

| Script | Proposed title |
|---|---|
| `scripts/build-room.rb` | Build a room from a take-off |

One entry, deliberately. It is the front door and it should not have to compete.

### 2. Build the booth
> Put a WhisperRoom in it. Three ways in, best first.

| Script | Proposed title | Why this rung |
|---|---|---|
| `scripts/booth-from-link.rb` | Build the customer's booth (share link) | Their exact configuration. The right answer on a real job. |
| `scripts/build-booth-components.rb` | Build a booth from real parts | Doors swing, glass, ducts. For renders. |
| `scripts/build-booth.rb` | Block-out booth (plain boxes, fast) | Plan check only. The name should say so. |

The category order must be fixed and must read as a ladder — this is the one place where
alphabetical or mtime ordering actively misleads.

### 3. Add dimensions
> Three tools, three different subjects. Keeping them adjacent is the fix, not the problem.

| Script | Proposed title | Points at |
|---|---|---|
| `scripts/auto-dimension.rb` | Dimension the room | the largest floor face in the model |
| `scripts/dimension-booth.rb` | Dimension the booth (catalogue figures) | the selected booth, identified by name |
| `scripts/dimension-selection.rb` | Measure whatever is selected | the selection's bounding box |

Every row needs a blurb naming its subject in the first four words. Today all three titles
begin "Dimension" and nothing says what they read. See `panel-problems.md` for why merging
them would be a mistake.

### 4. Scenes and images
> The proposal pipeline: set the plates up, then write the PNGs.

| Script | Proposed title |
|---|---|
| `scripts/proposal-scenes.rb` | Set up the five proposal plates |
| `scripts/list-scenes.rb` | List and number the scenes |
| `scripts/export-scenes.rb` | Export the proposal plates |
| `scripts/export-this-view.rb` | Export just this view |

### 5. Component art for the web catalog
> A different product from the proposal. Same model, different audience.

| Script | Proposed title |
|---|---|
| `scripts/angled-component-art.rb` | Component art — Iso30 angles |
| `scripts/export-component-art.rb` | Component art — flat views |
| `scripts/elevation-export.rb` | Component art — six elevations |
| `scripts/orbit-export.rb` | Orbit a part for the assembly manual |
| `scripts/explode-view.rb` | Explode an assembly |
| `scripts/save-scene-components.rb` | Save each scene's part as a .skp |

Naming the three art exporters as one family with a suffix is the point: their headers say
they must share a shading contract (`scripts/wr-shading.rb`) or the sets do not sit together
in the booth builder, so they should read as siblings on screen too.

### 6. Tidy up the model
> The three tools that change names and materials rather than geometry.

| Script | Proposed title |
|---|---|
| `scripts/find-replace-names.rb` | Find and replace names |
| `scripts/merge-materials.rb` | Merge two materials into one |
| `scripts/merge-scenes.rb` | Import a .skp and keep its scenes |

---

## Hidden from the default panel (8 scripts)

| Script | Why hidden | Disposition |
|---|---|---|
| `scripts/probe-components.rb` | DEV. Measures the component library; loads ~180 definitions into the open model and warns to use a scratch file. | Keep, hide |
| `scripts/probe-levels.rb` | DEV. Measures panel face heights for `wr-deck.rb`. Same model-pollution warning. | Keep, hide |
| `scripts/diag-favourites.rb` | DEV. Diagnostic for a preferences bug that `main.rb:206-224` documents as understood and fixed. | Hide; **ask Benton whether it is now dead** |
| `scripts/csusb-rooms.rb` | ONE-OFF. Two rooms for one delivered customer job. | Hide; propose moving to `clients/csusb/` |
| `scripts/booth-4260-s.rb` | Superseded generated builder, 1 of a retired 25. | Hide, then **retire** |
| `scripts/booth-96168-s.rb` | Superseded generated builder. | Hide, then **retire** |
| `scripts/pendant-jig.rb` | 3D-print side project. Nothing to do with booths. | Hide behind a Workshop shelf |
| `scripts/tube-drying-stand.rb` | 3D-print side project. | Hide behind a Workshop shelf |

### How they stay reachable

Benton clearly still wants the probes when he needs them, so hiding must not mean removing.
Three mechanisms, in order of how much they matter:

1. **Search always finds them, hidden or not.** Typing `probe` surfaces
   `probe-components.rb` with a small `DEV` badge on the row, even with the shelf collapsed.
   This is the important half — he knows their names, and a name he already knows is the
   fastest possible route. It costs one line in `panel.html`'s filter: don't exclude hidden
   scripts when a search term is present.
2. **A "Show developer and workshop tools" switch in the panel footer**, off by default,
   which expands two extra collapsed categories: **Developer probes** and **Workshop
   (3D printing)**. State in preferences, not in the model.
3. **The escape hatches already there** — the Scripts Folder and Ruby Console buttons in the
   top bar (`panel.html:455-460`) — remain the last resort and should stay.

### How a script declares it is hidden

Recommend a **new header directive** rather than a list inside `main.rb`, because that is
the pattern the plugin already commits to for abilities (`main.rb:80-92`: "Declaring it in
the script rather than in a list here means a new ability needs no edit to the plugin, and
the declaration cannot drift away from the code it describes"). Something like:

```
# @shelf dev        # or: workshop, archive
```

parsed alongside `@cat` in `cat_of`. `SKIP` stays exactly as it is for the five true
libraries — it is correct and complete, and it means something different (never loadable as
a command) from "hidden by default".

---

## Renames, merges and retirements

**Rename (14).** All of these are `@title` line changes only; the filenames must not move,
for the reasons at `main.rb:650-666`.

| File | From | To |
|---|---|---|
| `scripts/build-booth.rb` | Build Booth... | Block-out booth (plain boxes, fast) |
| `scripts/build-booth-components.rb` | Build Booth (real components)... | Build a booth from real parts |
| `scripts/booth-from-link.rb` | Build Booth from Link... | Build the customer's booth (share link) |
| `scripts/auto-dimension.rb` | Auto Dimension... | Dimension the room |
| `scripts/dimension-booth.rb` | Dimension WhisperRoom... | Dimension the booth (catalogue figures) |
| `scripts/dimension-selection.rb` | Dimension Selection... | Measure whatever is selected |
| `scripts/build-room.rb` | Build Room... | Build a room from a take-off |
| `scripts/proposal-scenes.rb` | Proposal Scenes... | Set up the five proposal plates |
| `scripts/export-scenes.rb` | Export Scenes... | Export the proposal plates |
| `scripts/export-this-view.rb` | Export This View... | Export just this view |
| `scripts/export-component-art.rb` | Export Component Art... | Component art — flat views |
| `scripts/angled-component-art.rb` | Angled Component Art... | Component art — Iso30 angles |
| `scripts/elevation-export.rb` | Elevation Export... | Component art — six elevations |
| `scripts/merge-scenes.rb` | Merge Scenes... | Import a .skp and keep its scenes |

"Dimension WhisperRoom..." is the worst of them: read cold, it says dimension the company.

**Give a header to the two that have none:** `scripts/csusb-rooms.rb` and
`scripts/diag-favourites.rb` currently show as "Csusb Rooms" and "Diag Favourites" with no
blurb, because `main.rb:153` prettifies the filename when `@title` is absent.

**Merge: none.** Specifically, do not merge the three dimension tools — the evidence for
that is in `panel-problems.md` and it is the kind of merge that puts a wrong number in front
of a customer.

**Retire: two.** `scripts/booth-4260-s.rb` and `scripts/booth-96168-s.rb`, superseded by
`scripts/build-booth.rb` per its own header. Recoverable from git.

**Also fix, and it gates the ability redesign:** the autorun defect in `main.rb:622-648`
(finding 2 in `panel-problems.md`). Any design that makes one row carry both a run button
and a toggle depends on the toggle not popping the run dialog.

**One structural proposal for the ability/action split:** collapse the duplicate rows.
One row per script, carrying the run affordance *and* — where the script declares `@on`/
`@off` — a switch on the same row. That removes five duplicate entries and the two-names
problem in a single change, and it makes the switch read as what it is: a mode of that tool,
not a separate feature.

---

## Icon briefs — one line each, for the 20 visible scripts

For a designer. The rule applied throughout: **the icon must depict what distinguishes this
tool from its neighbour in the same category**, since the neighbours are the things it will
actually be confused with. A ruler for everything that measures is exactly the current
failure.

Production note: the library is generated by `scripts/make-icons.py` into
`scripts/wr_tools/ico-*.svg` — 24×24 viewBox, glyph inside 3..21, stroke not fill, stroke
width 1.8. That file is where a new set lands, and `main.rb:418-425` globs the pattern, so
no plugin edit is needed to add icons. Getting them into the **list** (as opposed to the
toolbar slots) does need a new `@icon` directive and a change to `scriptRow`.

### Draw the room
1. **`scripts/build-room.rb`** — a closed room outline drawn as four unequal wall runs with a
   gap for a door, the final run **dashed and not quite meeting** the first: the take-off
   that has not closed yet, which is what this tool is actually about.

### Build the booth
2. **`scripts/booth-from-link.rb`** — a booth cube whose left edge dissolves into a chain
   link: the design arrives from somewhere else. Not a bare link glyph, and not a bare booth.
3. **`scripts/build-booth-components.rb`** — a booth cube mid-assembly, three wall panels
   sliding into their slots with one still detached and floating clear. Detail and separate
   parts are the distinguishing feature.
4. **`scripts/build-booth.rb`** — the same booth silhouette drawn as **one plain block with a
   dashed outline and no panel lines at all**. It must read as deliberately less detailed
   than #3, because "less detail" is literally the difference between them.

### Add dimensions
5. **`scripts/auto-dimension.rb`** — a room plan carrying **two rows** of dimension: a chain
   of three short segment strings against the wall, and one long overall string outside them.
   The two rows are the tool's whole signature.
6. **`scripts/dimension-booth.rb`** — a booth cube with a single dimension string and a small
   **name badge** clipped to it. The badge says the number came from the catalogue by way of
   identifying the model, not from measuring the geometry.
7. **`scripts/dimension-selection.rb`** — a **dashed selection marquee** around an irregular
   blob, with arrows on three of its edges. The marquee and the fact the subject is
   shapeless say "whatever you picked, however big it is".

### Scenes and images
8. **`scripts/proposal-scenes.rb`** — **five** page thumbnails fanned in a stack, the front
   one showing a booth in a room. The count is the meaning; four or six would be wrong.
9. **`scripts/list-scenes.rb`** — a numbered list with three rows ticked and a bracket beside
   them pulling the ticks into a range. It produces a range string, and no other tool here
   does.
10. **`scripts/export-scenes.rb`** — a stack of several scene tabs with one arrow leaving the
    stack into a folder. Many out, in one go.
11. **`scripts/export-this-view.rb`** — a single viewport frame with one arrow leaving it.
    Drawn as the deliberate singular of #10, same arrow, same weight, one frame.

### Component art for the web catalog
12. **`scripts/angled-component-art.rb`** — one wall panel tilted to a 30° isometric, with
    three faint ghosts of itself behind it at the other camera angles. Four views of one
    part.
13. **`scripts/export-component-art.rb`** — the same panel drawn dead flat-on against a small
    **checkerboard transparency field**. Alpha is what this one has and #12 and #14 do not.
14. **`scripts/elevation-export.rb`** — one part with six small orthographic silhouettes of
    itself arranged around a cross: front, back, left, right, top, bottom. Six, and all
    square-on.
15. **`scripts/orbit-export.rb`** — a part encircled by a camera track, with a camera marker
    at three positions on the ring. Motion around a fixed subject.
16. **`scripts/save-scene-components.rb`** — a scene tab with an arrow into a **file card
    bearing a 3D part**, not an image. The output being geometry rather than a picture is
    the only thing separating it from the four exporters above it.
17. **`scripts/explode-view.rb`** — a booth with its four walls and ceiling pulled straight
    out along their own axes, thin leader lines running back to where each came from. The
    leaders matter: they say it can be put back.

### Tidy up the model
18. **`scripts/find-replace-names.rb`** — one text label above another with an arrow between
    them, and a small "Aa" mark. Text, not geometry.
19. **`scripts/merge-materials.rb`** — two paint swatches, one pouring into the other, the
    emptied one greyed and struck through. One survives; that is the point.
20. **`scripts/merge-scenes.rb`** — two overlapping file cards with a strip of scene tabs
    carried from the smaller across into the larger. The tabs travelling is the feature
    SketchUp itself does not have.

### Hidden shelves, if they get icons at all
- **Developer probes** (`probe-components.rb`, `probe-levels.rb`, `diag-favourites.rb`) —
  one shared shelf mark: a caliper across a part with a readout, distinct from any of the
  dimension icons because it reports a number rather than drawing one.
- **Workshop** (`pendant-jig.rb`, `tube-drying-stand.rb`) — a print bed with a part and a
  brim. Nothing about booths.
