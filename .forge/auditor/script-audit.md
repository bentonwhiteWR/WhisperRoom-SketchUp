# Script audit — everything in `scripts/` except build-room and wr_tools

Audited 2026-08-15, before the SketchUp restart. Method: every finding below was traced
by hand in the source (no Ruby interpreter exists outside SketchUp on this machine);
where a claim could be reproduced outside SketchUp it was — the list-scenes JavaScript
was extracted and passed `node --check` (observed), the `arch()` rounding defect was
reproduced in a faithful Python reimplementation (observed), and the dimension-booth
vent arithmetic was re-derived against `wr-booth-data.rb`'s real numbers (derived,
figures match both of Benton's worked examples). Provenance labels on every claim:
**observed / derived / reported / assumed**.

The two defect classes from the build-room rework were chased across every script.
Good news first: **the `esc()`-misses-the-double-quote bug is NOT repeated** — the only
other script that builds HTML from model data is `list-scenes.rb`, and its `esc()`
(scripts/list-scenes.rb:282-285) escapes `& < > "` correctly (observed in source, and
the emitted JS parses clean under node). The dimension-input class survives only in
low-stakes standoff/gap fields — detailed as finding 6.

---

## Finding 1 — auto-dimension erases the booth and selection dimensions it does not own

**Severity: HIGH.  Provenance: derived** (path fully traced; not executed).

`scripts/auto-dimension.rb:287-290`:

```ruby
def self.own_dims(model)
  model.entities.grep(Sketchup::DimensionLinear)
       .select { |d| d.layer && d.layer.name.start_with?(TAG_DIM) }
end
```

`TAG_DIM` is `'WR-Dims'`, and `start_with?('WR-Dims')` also matches **`WR-Dims-Booth`**
(dimension-booth.rb) and **`WR-Dims-Selection`** (dimension-selection.rb) — both tags
added 2026-08-14, after this ownership test was written. The same prefix match is
repeated in the interactive path at `scripts/auto-dimension.rb:342-343`.

Concrete scenario: Benton selects a booth, runs *Dimension the booth* — the catalogue
figures and the model-name label go on `WR-Dims-Booth`. He then toggles *Dimensioned*
(room) ON: `ability_on` calls `clear_dims` (auto-dimension.rb:313) which **silently
erases every booth and selection dimension** before drawing the room chain. The booth's
text label survives (`clear_dims` greps `DimensionLinear` only), so the model is left
with a "MDL 96120 S / 10'7 1/2" x 8'7 1/2"…" label and **no dimensions under it**.
Toggling the room ability OFF does the same. This directly contradicts
dimension-booth.rb's own design ("separate tags on purpose… you may want both",
scripts/dimension-booth.rb:64-67, 96-100) and it is the plate-02 content that goes in
front of customers. It is one Ctrl+Z recoverable, but nothing tells you it happened —
`ability_on` discards `clear_dims`' count.

This is the "broken by recent changes" class: the prefix test was safe when `WR-Dims`
and `WR-Dims-Doors` were the only tags; the two new sibling tags put it out of date.
Note the reverse direction is clean — dimension-booth and dimension-selection both use
exact `==` tag matches plus an ownership attribute (dimension-booth.rb:344-359,
dimension-selection.rb:146-158).

**Fix (described):** in `own_dims` and in the `run` filter, replace the prefix test
with exact membership: `['WR-Dims', 'WR-Dims-Doors'].include?(d.layer.name)` — or
`start_with?` against `'WR-Dims'` only when followed by nothing or `-Doors`.

---

## Finding 2 — the five proposal plates ignore the two new dimension tags

**Severity: MEDIUM-HIGH (customer-facing plates).  Provenance: derived.**

`scripts/proposal-scenes.rb:41`:

```ruby
DIM_TAGS = %w[WR-Dims WR-Dims-Doors].freeze
```

Each plate scene stores tag visibility; `set_dims` (proposal-scenes.rb:87-92) turns
these two ON for `02-dimensioned` and OFF for the other four. **`WR-Dims-Booth` and
`WR-Dims-Selection` are not in the list**, so whatever visibility those tags happen to
have at run time is frozen into **all five** scenes.

Concrete scenario: dimension-booth was toggled ON earlier (its tag visible). Benton
runs *Set up the five proposal plates*: the booth's catalogue dimensions and its model
label now appear on `01-exterior`, `03-side`, `04-ventilation` and `05-plan` — plates
that must be clean — and export-scenes will bake them into the PNGs. Inverted case:
the tag was off, so `02-dimensioned` (the plate whose whole job is the dimensions)
ships without the booth's catalogue figures. Nothing in the console mentions either.

**Fix (described):** handle both new tags explicitly per plate. `WR-Dims-Selection`
should be forced OFF on every plate (it is a bounding-box number and dimension-booth's
own console text says it must not be shown next to catalogue figures). Whether
`WR-Dims-Booth` belongs ON in plate 02 alongside or instead of the room chain is
Benton's call — but it must be set deliberately, not inherited.

---

## Finding 3 — re-exploding an already-exploded assembly compounds the travel distance

**Severity: MEDIUM-LOW.  Provenance: derived.**

`scripts/explode-view.rb:204-230` (`plan_for`). The header (and the comment at
line 208-209: "Centre and size from HOME positions") promise that re-exploding never
compounds. Home *positions* are indeed preserved via the `WR_Explode` attribute — but
the geometry the distances are scaled by is measured from **current** bounds:

```ruby
bb = Geom::BoundingBox.new
parts.each { |e| bb.add(e.bounds) }     # current, possibly exploded, positions
...
plan << { ... :dist => size * spread * reach ... }
```

Concrete scenario: toggle *Exploded* ON, then ON again (or re-run at a new spread
without Reset). The second run measures `size` and each part's `reach` off the exploded
assembly — several times the assembled diagonal — so every part flies several times
further. Each repeat grows the explosion without bound. Reset still works (targets are
`home + dir*dist`), so nothing is lost, but the tool contradicts its own header and a
double-toggle produces a uselessly scattered illustration.

**Fix (described):** build `bb` and `vecs` from the recorded home positions (they are
already in `homes`), not from `e.bounds`.

---

## Finding 4 — a scene range starting at 0 silently includes the LAST scene

**Severity: LOW.  Provenance: derived in the two files read in full; the same verbatim
block confirmed by grep in the other three.**

The shared `select_pages` range parser, e.g. `scripts/export-scenes.rb:103-107`:

```ruby
(a..b).map { |n| pages[n - 1] }.compact
```

The single-number branch guards `n >= 1`; the range branch does not. `pages[0 - 1]` is
Ruby's `pages[-1]` — the last scene. Concrete scenario: typing `0-5` (an easy slip in a
1-based list) exports scenes 1-5 **plus the final scene of the model**, silently. On a
proposal-plate export that is a stray PNG in the client folder.

Present identically in: `scripts/export-scenes.rb:103-107`,
`scripts/save-scene-components.rb:155-159`, `scripts/angled-component-art.rb:307-311`
(all read), `scripts/elevation-export.rb:189-193` and
`scripts/export-component-art.rb:177-181` (grep-confirmed same lines, not read in
full). Fix: clamp `a = 1 if a < 1`.

Side nit while there: `angled-component-art.rb:320` dedupes picked scenes by **name**
(`picked.uniq { |p| p.name }`) where the other four dedupe by object — two identically
named scenes silently collapse to one in that exporter only.

---

## Finding 5 — auto-dimension's console table can print `11'-12"`

**Severity: LOW (console only — the drawn dimension entities are formatted by SketchUp
and are unaffected).  Provenance: observed** (reproduced in a line-faithful Python
reimplementation: `arch(143.96)` → `11'-12"`, `arch(95.98)` → `7'-12"`).

`scripts/auto-dimension.rb:274-281`: when the inch remainder rounds to 12.0 at one
decimal, the feet are not carried, so a wall run of 143.96" prints `11'-12"` instead of
`12'-0"`. Traced rooms produce exactly these near-integer lengths. The run table is
what gets pasted into messages and checked against the drawing, so a `x'-12"` reading
invites a transcription error. Fix: after rounding, if inches == 12, increment feet and
zero the inches. (dimension-booth and dimension-selection use
`Sketchup.format_length` and do not have this problem.)

---

## Finding 6 — the surviving members of the build-room input class: gap/standoff fields parse with `to_f`

**Severity: LOW (all instances are cosmetic offsets, not drawn numbers).
Provenance: derived.**

The class that bit build-room — imperial-typed input silently misread — survives only
in these fields, all parsed with bare `.to_f`:

- `scripts/dimension-booth.rb:399` — `Standoff (in)` (`@setting gap number 24`)
- `scripts/dimension-selection.rb:170` — `Standoff (in)` (`@setting gap number 12`)
- `scripts/merge-scenes.rb:285` — `Gap between the two lots (feet)`
- `scripts/explode-view.rb:341` — `Spread (%)`

Typing `2'` into a standoff field reads as **2 inches**, and any unparseable entry
becomes `0.0`, which the clamp (`gap = 24.0 if gap <= 0 || gap > 240`) silently
replaces with the default rather than complaining. Because every one of these only
positions a dimension line or an imported lot — never a number a customer reads — this
is a surprise, not a wrong figure. Worth fixing only if the shared `parseLen` idea ever
grows a Ruby twin. No `@setting number` field feeds a drawn dimension anywhere
(checked all seven `@setting` declarations).

---

## Finding 7 — list-scenes window: title and JSON are interpolated unescaped

**Severity: LOW.  Provenance: derived; the emitted JS itself verified parseable
(observed, `node --check` exit 0 with a quote-and-angle-bracket scene payload).**

Two small gaps in an otherwise correctly-escaped dialog
(`scripts/list-scenes.rb`):

- Line 237: `<span class="t">#{title}</span>` — the model title goes into markup raw.
  A title containing `&` or `<` mis-renders; no data loss, header text only.
- Line 275: `var ROWS = #{data};` — Ruby's `to_json` does not escape `/`, so a scene
  literally named `</script>` would terminate the script block and blank the window.
  Cosmetic-improbable, but it is the same "model data into markup" seam as the
  build-room bug, so it is recorded.
- `hl()` (lines 286-290) searches the *escaped* string, so searching for text that
  overlaps an entity (`amp`, `quot`) highlights or matches entity innards. View-only.

---

## Notes, not findings

- **dimension-booth heights** (scripts/dimension-booth.rb:86): Standard uses the
  catalogue figure (6'11" = 83.0) while Enhanced uses the *drawn* figure
  (7'-0 5/16" = 84.3125), not the catalogue 7'-1" that CLAUDE.md says to quote for
  fit. DEVLOG 08-14 records this as deliberate, and no Enhanced booth exists in the
  data today (`Auto` can never select it), so it is unreachable — recorded so the
  inconsistency is known if Enhanced data ever lands.
- **booth-from-link.rb:164-168** sets `$wr_no_autorun = false` in its `ensure` rather
  than restoring the previous value. DEVLOG describes this file as save-and-restore;
  it is set-and-clear. Harmless on every current path (the build runs in an async HTTP
  callback after any outer load has finished), but the DEVLOG's description of it is
  wrong.
- **merge-scenes.rb pass 1** reads tag visibility by selecting each page and reading
  the live model state (scripts/merge-scenes.rb:112-131). That SketchUp applies a
  page's tag state synchronously on `selected_page=` is **assumed** — standard API
  behaviour, unverifiable without SketchUp. If it ever lags, exported `hidden_tags`
  would be one scene stale.
- **merge-scenes pass 1 overwrites `<file>-scenes.json`** and **list-scenes overwrites
  `_scene-list.txt`** without asking. Both are regenerable sidecars; recorded only for
  completeness.

## Checked and found clean

- **Undo safety**: every script that mutates the model wraps its work in one
  `start_operation`/`commit_operation` with abort-on-error — verified in
  auto-dimension, dimension-booth, dimension-selection, find-replace-names,
  merge-materials, merge-scenes, save-scene-components (rename batch),
  build-booth, build-booth-components, explode-view. No un-undoable mutation found.
- **Destructive-op guards**: find-replace-names previews by default, refuses on
  collision (the swap case A→B/B→A is correctly allowed — traced), confirms with a
  count. merge-materials defaults to dry run, re-counts after the merge and reports
  survivors instead of trusting its own tally, and captures labels before
  `materials.remove` (the deleted-handle trap is handled and documented).
  save-scene-components: dry-run default, overwrite off by default, duplicate
  filenames suffixed and reported, renames read back after assignment.
- **File overwrites**: export-scenes, export-this-view, export-component-art and
  save-scene-components all gate on an explicit Overwrite=Yes; export-this-view
  deletes first so a file-lock surfaces as a real error.
- **dimension-booth arithmetic**: the vent rule re-derived against
  `wr-booth-data.rb` — 7296 (98×74, N vented) → 8'2" × 6'7½", 96120 (122×98, N+E) →
  10'7½" × 8'7½" — both match Benton's worked examples exactly. `by_deck`'s
  deck→exterior reconstruction (sum of along + 2", cross + 2") re-checked against the
  96120 deck plan (96 across, 48+24+48 along → 98×122). The 10284/84102 ambiguity is
  reported, not guessed. EFS and HX are reported as unmeasured, never quoted.
- **Cross-script naming contracts**: build-booth-components names its group
  `"MDL … S (components)"` and wall instances `"N0  46VNT…"`; wr-deck names deck
  instances after their file (`STD9648FL SIDE`); block-out build-booth names groups
  after the key and parts `"N0  VNT"` — every one matches the regexes
  dimension-booth identifies and reads vents by (`DECK_RE`, `\A([NSEW])\d+\s`,
  `/v(?:e)?nt/i`, which correctly rejects `46NV` blanks).
- **The `esc()` class**: list-scenes is the only other HtmlDialog builder and its
  escaper covers the double quote; its JS passes `node --check` with a payload
  containing inch marks, ampersands and angle brackets.
- **Prefs discipline**: every read_default is wrapped `rescue Exception` with quotes
  stripped on write (the SyntaxError-escapes-StandardError trap), across all files
  checked.

**Coverage limits, stated plainly:** orbit-export.rb, elevation-export.rb,
export-component-art.rb and angled-component-art.rb were read in targeted sections
(range parsing, overwrite guards, rescue discipline), not line-by-line — their
camera/scale math is unaudited. probe-components.rb, probe-levels.rb,
diag-favourites.rb, csusb-rooms.rb, pendant-jig.rb, tube-drying-stand.rb,
booth-4260-s.rb, booth-96168-s.rb (dev-only/one-off/shelved) and the .py shell tools
were skimmed for the two defect classes only. Nothing here was executed in SketchUp.
