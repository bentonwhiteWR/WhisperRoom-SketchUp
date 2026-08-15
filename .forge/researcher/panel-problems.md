# What makes the panel hard — concrete findings

Sources: `scripts/wr_tools/main.rb` and `scripts/wr_tools/panel.html`, both read in full
(observed). Line numbers are from those files as of 2026-08-15. Nothing was executed —
there is no Ruby outside SketchUp on this machine — so consequences are **derived** from
source unless marked otherwise.

The findings are ordered by how much they cost a new user, not by how hard they are to fix.

---

## 1. Every ability appears twice, under two different names

`panel.html:846-848` draws an ABILITIES group from `DATA.abilities`. `panel.html:838-840`
then draws **all** scripts into their category groups with no exclusion for the ones already
shown above. So each of the five ability scripts occupies two rows, and the two rows carry
**different labels**, because the ability row uses `@ability` and the script row uses
`@title`:

| File | Ability row says | Script row says |
|---|---|---|
| `scripts/dimension-booth.rb` | Dimensioned booth | Dimension WhisperRoom... |
| `scripts/dimension-selection.rb` | Dimensioned selection | Dimension Selection... |
| `scripts/auto-dimension.rb` | Dimensioned | Auto Dimension... |
| `scripts/explode-view.rb` | Exploded | Exploded View... |
| `scripts/proposal-scenes.rb` | Proposal scenes | Proposal Scenes... |

Nothing on screen says these are the same file. A new user reasonably concludes there are
ten tools here, five of which are switches and five of which are buttons, and that
"Dimensioned" and "Auto Dimension..." are different features.

Search makes it worse: `panel.html:835-840` filters abilities and scripts separately, so
typing `dimension` returns six hits for three actual tools.

## 2. Toggling an ability runs the script's dialog first — a real defect

`main.rb:622-648`, `toggle`:

```ruby
load a['file']                     # re-read every time, so edits take effect
opts = values_for(a)
expr = on ? a['on'] : a['off']
result = eval(expr, binding, a['file'])
```

Every ability script ends with a **top-level autorun**, and `main.rb` sets neither of the
two globals that suppress it:

| File | Last line | Guard |
|---|---|---|
| `scripts/explode-view.rb:421` | `WR_ExplodeView.run` | **none** |
| `scripts/proposal-scenes.rb:251` | `WR_ProposalScenes.run` | **none** |
| `scripts/auto-dimension.rb:404` | `WR_AutoDimension.run unless $wr_suppress_autorun` | `$wr_suppress_autorun` |
| `scripts/dimension-selection.rb:225` | `WR_DimensionSelection.run unless $wr_no_autorun` | `$wr_no_autorun` |
| `scripts/dimension-booth.rb:557` | `WR_DimensionBooth.run unless $wr_no_autorun` | `$wr_no_autorun` |

Grepped across the whole folder, `$wr_suppress_autorun` is set only by
`scripts/build-room.rb:327` and `$wr_no_autorun` only by `scripts/booth-from-link.rb:163`.
`main.rb` sets neither (observed — the strings do not appear in the file).

Derived consequence: flipping any ability switch **runs the script's normal entry point
first, dialog and all, and then does the ability work a second time**. For
`scripts/explode-view.rb` that means a modal appears — which its own header at lines 273-275
says the ability path exists specifically to prevent ("The panel toggles this dozens of
times in a session, so the ability path must never put a modal in the way"). For
`scripts/dimension-booth.rb:543-552` `run` opens `ask` and then calls `ability_on(cfg)`, so
the toggle draws with the dialog's settings and then again with the stored ones.

This is the single highest-value fix in the panel and it is four characters of Ruby
(`$wr_no_autorun = true` around the `load`) plus reconciling the two guard names. **Not
verified at runtime** — flag it for the Builder to confirm in SketchUp before and after.

## 3. The four categories are not true statements

Current tree, as `panel.html:533` orders it:

- **Build a booth** (3) — honest.
- **Room tools** (6) — holds three things that are not room tools:
  `scripts/dimension-booth.rb` (a booth), `scripts/explode-view.rb` (any assembly, for the
  assembly manual), `scripts/proposal-scenes.rb` (a scene/export step).
- **Model tools** (7) — holds two developer probes (`scripts/probe-components.rb`,
  `scripts/probe-levels.rb`) sitting next to four real editing tools, with nothing marking
  the difference. `probe-components.rb`'s own header warns "RUN IT ON AN EMPTY MODEL — it
  loads ~180 definitions into whatever model is open" and cannot fully purge them back out.
  That warning is inside the file. The panel row looks exactly like Build Room.
- **Export art** (6) — two unrelated pipelines under one heading. `export-scenes.rb` and
  `export-this-view.rb` feed the **client proposal**; `angled-component-art.rb`,
  `export-component-art.rb`, `elevation-export.rb` and `orbit-export.rb` feed the **web
  catalog and the assembly manual**, a different product with a different audience.
- **More scripts** (6, from having no `@cat`) — one retired generated pair
  (`booth-4260-s.rb`, `booth-96168-s.rb`), one delivered customer job (`csusb-rooms.rb`),
  one diagnostic (`diag-favourites.rb`) and two 3D-printing scripts (`pendant-jig.rb`,
  `tube-drying-stand.rb`). Four unrelated kinds under one heading whose name promises
  nothing.

`main.rb:169-184` describes "More scripts" as "exactly where a run-once script belongs".
That is true of `csusb-rooms.rb` and false of `pendant-jig.rb`, which Benton will run again.

## 4. Two scripts have no header at all, so the panel invents their names

`main.rb:153-155` falls back to prettifying the filename. `scripts/csusb-rooms.rb` shows as
**"Csusb Rooms"** and `scripts/diag-favourites.rb` as **"Diag Favourites"**, both with no
blurb, both in "More scripts". Neither name means anything to someone who has not read the
file.

## 5. Nothing separates a daily tool from a probe

There is no directive for it. `meta_of` (`main.rb:97-151`) understands `@title`,
`@ability`, `@ability-blurb`, `@setting`, `@on`, `@off`, and `cat_of` understands `@cat`.
There is no `@hidden`, no `@shelf`, no `@icon`, no danger flag. So a script cannot declare
that it is developer-only, and the panel has no way to demote it. `SKIP` (`main.rb:61-62`)
is all-or-nothing: in it a file is invisible, out of it a file is a first-class tool.

## 6. The list order changes every time a file is touched

`main.rb:201` sorts the whole scan by `-stamp` (file mtime), and the panel preserves that
order inside each category group (`panel.html:855-877`). Editing any script re-orders the
category it sits in. Re-running `install-plugin.py` re-copies every file and can re-order
everything at once.

Related: `main.rb:66` gives a **NEW** pill to anything modified in the last 24 hours. On a
day when several scripts were touched — 2026-08-14 touched 15 of the 28 (observed from
`ls -l`) — the pill marks half the folder and stops carrying information.

## 7. There are no icons in the list, and the icon library cannot say what a script does

Two separate problems wearing one complaint:

- **The script list is icon-free.** `scriptRow` (`panel.html:770-787`) renders a title, a
  blurb, an "ago" stamp, a filename, a pencil and a star. No image element. Icons live only
  on the eight toolbar slots (`panel.html:629-661`) and in the slot editor's picker grid
  (`panel.html:701-717`).
- **The library is generic by construction.** `wr_tools/ico-labels.txt` lists 49 icons and
  they are nouns, not jobs: Ruler, Dimension string, Floor plan, Room outline, Grid, Camera,
  Image, Export files, Folder, Gear, Search / probe, Star, Pin. There is no icon that says
  "dimension the booth from the catalogue" as against "measure the selected box", because
  the library was never per-script — it is a palette the user assigns by hand.
- **No script can declare its own icon.** There is no `@icon` directive. The only mapping
  is `FAV_ICONS` (`main.rb:294-300`), which covers 5 of 28 files and whose own comment says
  "Not a registry". Everything else falls back to `icon-fav<n>.svg`, a numbered star.

The one icon that actively lies: a **numbered star** means "this slot has no icon chosen",
but `ico-star.svg` and `ico-pin.svg` are also pickable faces in the library, so a
deliberately-starred slot and an unconfigured slot look the same.

Where a redesign lands: `scripts/make-icons.py` generates the whole `ico-*.svg` set from one
table, and `main.rb:418-425` globs `ico-*.svg`, so adding icons needs no plugin edit.
Getting a per-script icon into the **list** does need a new directive plus a change to
`scriptRow`.

## 8. The first thing a new user meets is plugin plumbing

Above the tool list sits the SKETCHUP TOOLBAR row: eight tiles, a modal editor with a
grouped script dropdown and a ~50-tile icon grid, a dashed-border "pending" state with an
orange dot, and an explanatory sentence about SketchUp being unable to repaint a toolbar
button until the next launch (`panel.html:136-187`, `502-522`; the reasoning is at
`main.rb:264-300`). All of that is correct and hard-won. None of it is work. It occupies
roughly the top third of a 430×640 dialog before the user reaches a single tool.

## 9. Renaming a tool edits source code on disk

The pencil (`panel.html:780-781`) calls `main.rb:668 rename`, which rewrites the `@title`
line inside the `.rb` file. It is documented in the modal's hint and the reasoning
(`main.rb:650-666`) is sound — the filename must not move because scripts load each other by
filename. But it means a UI affordance that looks like "set a label" is a commit-worthy
change to a version-controlled source file, and it silently rewrites CRLF-aware.

## 10. The Plugins menu is a stale, flat duplicate

`main.rb:889` adds one menu item per script at load time, in mtime order, with no
categories, and SketchUp cannot rebuild a menu (`main.rb:3-13`). A user who finds the menu
first meets a different list from the panel's, frozen at whatever existed when SketchUp
launched.

## 11. The Python tools have no route in at all

`main.rb:73` globs `.rb` only. `README.md` tells the user to run
`python scripts/install-plugin.py`, `python scripts/rbcheck.py` and
`python scripts/gen-booth-models.py`, and the panel does not mention that these exist or
that a shell is where they live. The "Open the scripts folder" button is the only bridge and
it does not say so.

---

## The two suspected overlaps, checked

### `auto-dimension.rb` vs `dimension-selection.rb` vs `dimension-booth.rb`

**They do not overlap functionally. They overlap entirely in naming and presentation.**
Each answers a different question, each header argues explicitly why it is not the other,
and each writes to its own tag:

| Script | Question it answers | What it reads | Tag |
|---|---|---|---|
| `scripts/auto-dimension.rb` | how is this room laid out | largest horizontal face in the **model** — ignores selection | `WR-Dims`, `WR-Dims-Doors` |
| `scripts/dimension-selection.rb` | how big is this object | the selection's **world bounding box** | `WR-Dims-Selection` |
| `scripts/dimension-booth.rb` | how big is this booth on a drawing | identifies **which model** it is, then reads `wr-booth-data.rb` + a vent rule | `WR-Dims-Booth` |

The distinction is load-bearing, not academic. `dimension-selection.rb:14-19` records a
selected booth coming back reading 30 feet, because `auto-dimension.rb` had dimensioned the
room around it. `dimension-booth.rb:20-27` records a 96120 measuring
10'8 7/16" × 9'11 1/2" from its bounding box against a catalogue 10'7 1/2" × 8'7 1/2",
because the box holds the open door leaf, a VSS stack, a condensate pan and any ramp — and
that number would have gone in front of a customer. `dimension-booth.rb:517-524` goes as far
as detecting `WR-Dims-Selection` dimensions in the same model and telling you to switch that
ability off before anyone reads the drawing.

**Do not merge these.** Merging would recreate exactly the failure each was written to
prevent. What is actually wrong is that all three titles start with "Dimension", all three
ability labels start with "Dimensioned", all three sit in one category, and **no row says
what the tool points at**. The fix is naming and one line of blurb each, not code.

### `build-booth.rb` vs `build-booth-components.rb` vs `booth-from-link.rb` vs the two `booth-*-s.rb`

This is a genuine ladder presented as five peers.

```
booth-from-link.rb          the customer's own design, from their share link
   └─ loads ─> build-booth-components.rb   real .skp parts: doors swing, glass, ducts
                  └─ layout from ─> wr-booth-data.rb
build-booth.rb              same layout data, extruded slabs. Plan check only.
booth-4260-s.rb             one hard-coded booth. Generated. Superseded.
booth-96168-s.rb            one hard-coded booth. Generated. Superseded.
```

- `booth-from-link.rb:29-46` loads `build-booth-components.rb` and sets
  `$wr_no_autorun` around it (line 163) — so it is a wrapper, not a rival.
- `build-booth-components.rb`'s header states plainly why it exists: `build-booth.rb`
  "draws each panel as a rectangle and push-pulls it into a featureless slab. That is fine
  for a plan check and useless for a render: a door frame is a grey box with no door in it."
  So `build-booth.rb` is not dead — it is the fast, low-detail option — but it is the
  **least** capable of the three and carries the **most** inviting name, "Build Booth...".
- `booth-4260-s.rb` and `booth-96168-s.rb` are two survivors of a retired scheme.
  `build-booth.rb`'s own header: "This replaces the one-script-per-booth arrangement — new
  booths appear in the list as soon as the data file is regenerated, with no new script and
  no SketchUp restart." Both are generated by `gen-booth.py`, both build exactly one model,
  both build immediately on load with no dialog, and both title themselves "Build Booth MDL
  ... " so they sit in the panel looking like 2 of 25 booths inexplicably given their own
  buttons. **Retire them** (recoverable from git).

So: four "Build Booth" rows, in mtime order, with no indication of which is the right one to
click. That is the real problem, and it is fixed by renaming so the ladder is legible plus
retiring two files — not by merging anything.
