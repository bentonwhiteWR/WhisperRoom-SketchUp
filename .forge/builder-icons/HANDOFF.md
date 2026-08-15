# Builder B (icons) — handoff

Spec step 2 of `.forge/scoper/panel-redesign.md`. Icon assets only; `panel.html` and
`main.rb` belong to Builder A and were read but never edited.

## Produced

In `scripts/wr_tools/`:

- `wr-ico-<id>.svg` × 29 — standalone, for SketchUp toolbar slots. `viewBox="0 0 24 24"`,
  explicit `width`/`height`, graphite resolved to **`#20262a`**.
- `wr-icons.svg` — the sprite. One `<svg>` of 29 `<symbol id="wr-<id>">`, graphite left as
  `currentColor` so a panel row can tint it (orange well on an active ability). Ready to
  inline verbatim.
- `icon-map.json` — flat `{"<script>.rb": "<icon-id>"}`, all 33 `.rb` files in `scripts/`.

In `.forge/builder-icons/`:

- `contact-sheet.html` — every icon at 40 px and 20 px, grouped by category, labelled with
  id / tool / provenance, with the dimension trio side by side and a full light-and-dark
  20 px strip. Self-contained, no external requests.
- `gen-icons.py` — the single source of truth that emits all of the above plus the contact
  sheet, and runs the verification pass. Edit an icon here and regenerate; hand-editing one
  of the four outputs will make them drift.

## Read-first (the naming rule Builder A needs)

One id, three spellings, no exceptions:

| thing | form | example |
|---|---|---|
| value in `icon-map.json` | `<id>` | `dim-booth` |
| symbol in the sprite | `wr-<id>` | `<use href="#wr-dim-booth">` |
| standalone file | `wr-ico-<id>.svg` | `scripts/wr_tools/wr-ico-dim-booth.svg` |

`main.rb`'s icon-library glob in step 5 must therefore accept `wr-ico-*` **and** keep the
old `ico-*` ids resolving — saved `slot_icons` prefs still reference them (spec risk note).

## Assumptions

- **Graphite `#20262a`** for the standalone copies = the panel's own light-theme `--p-ink`,
  so a toolbar icon and its panel twin are the same drawing in the same ink. Assumed: the
  SketchUp toolbar strip is light on Windows. On a dark toolbar chrome these would be
  low-contrast; the fix is a one-line change in `gen-icons.py` and a regenerate.
- The `<id>` scheme above is mine — the spec fixed the filenames, not the ids. Stable and
  lowercase-hyphenated as instructed, but Builder A has to agree to it.
- The five `SKIP` libraries (`wr-booth-data.rb`, `wr-deck.rb`, `wr-folder.rb`,
  `wr-shading.rb`, `wr_tools.rb`) are in the map only so it is total. They never render a
  row, so they are excluded from the no-two-tools-share-an-icon check.
- `wr-ghost` (the mockup's "Reference geometry" ability) maps to no script. There are five
  real ability scripts and none of them is a ghost/reference toggle, so it is carried as a
  reserve rather than deleted.

## Open questions

1. **Legibility is unverified.** No SVG renderer here. Every geometric claim below is
   parsed, not seen. The contact sheet is the instrument — someone has to open it.
2. **The dimension pair.** `wr-dim-booth` vs `wr-dim-selection` were rebuilt to separate
   further than the mockup did (see below). Needs the human 20 px check before it ships.
3. **`booth-preset-small` / `booth-preset-large`** share a grey dashed envelope and differ
   only in the orange booth's silhouette. That is the weakest distinct pair in the set.
   Both are shelved archive tools and `GOAL.md` says do not retire them, so they needed
   icons; if they are ever retired these two go with them.
4. **`diag-favourites.rb`** may be dead code (Researcher flagged it as a question for
   Benton). It has an icon; if the script goes, drop `wr-diag-favourites` too.

---

## What was extracted vs authored

**Extracted verbatim from `.forge/scoper/panel-redesign.mockup.html` (14).** Geometry
copied path-for-path; `<circle>` rewritten as the equivalent arc path so every icon is a
uniform list of `<path>`s.

`room-takeoff`, `booth-link`, `booth-parts`, `booth-blockout`*, `scenes-export`,
`view-export`, `art-elevations`, `art-orbit`, `explode`, `scene-parts`, `names-replace`,
`materials-merge`, `probe-components`, `ghost`.

\* `booth-blockout`'s orange plus reached x = 22.2 in the mockup, breaking the 2-unit
padding. Nudged 0.4 left; nothing else changed.

**Revised against the Researcher's briefs (5).** The spec says those briefs are the target
where they are more specific than the mockup.

| id | change | why |
|---|---|---|
| `dim-room` | now carries **two** rows — a three-segment chain and an overall string below it | brief 5: the two rows are the tool's whole signature |
| `dim-booth` | added the **name badge** clipped to the booth | brief 6: the number came from the catalogue, by identifying the model |
| `dim-selection` | dashed **marquee around an irregular blob**, orange string now an L-corner over two axes | brief 7, and the 20 px pair test |
| `scenes-proposal` | **five** plates fanned, front one carrying a booth in a room | brief 8: the count is the meaning |
| `scenes-import` | two overlapping file cards with orange **scene tabs** riding on the larger | brief 20, and it shared a grey base with `scenes-export` |

**Newly authored (10).** Six were named in the spec; four more were missing once the map
had to cover every script.

| id | tool | mark |
|---|---|---|
| `scenes-list` | `list-scenes.rb` | ticked rows with an orange bracket pulling them into a range (brief 9) |
| `art-angled` | `angled-component-art.rb` | orange Iso30 panel with ghosts of itself behind (brief 12) |
| `art-flat` | `export-component-art.rb` | flat-on panel over a checkerboard alpha field (brief 13) |
| `probe-levels` | `probe-levels.rb` | panel with face levels, orange readout pointer at one |
| `diag-favourites` | `diag-favourites.rb` | toolbar slot strip, one slot orange with a check |
| `rooms-csusb` | `csusb-rooms.rb` | two rooms plus an orange job-name card |
| `booth-preset-small` | `booth-4260-s.rb` | fixed envelope, small orange booth |
| `booth-preset-large` | `booth-96168-s.rb` | fixed envelope, large orange booth |
| `jig-pendant` | `pendant-jig.rb` | print bed, orange arch on a brim (brief: workshop shelf) |
| `jig-tube-stand` | `tube-drying-stand.rb` | print bed, orange three-post rack |

The last four were not in the spec's list of six because the spec only counted the tools
the mockup showed. `csusb-rooms.rb`, `diag-favourites.rb` and the two `booth-*-s.rb`
presets are shelved rather than deleted per `GOAL.md`, so they still need distinct icons.

## Briefs deliberately not followed

- **`room-takeoff`** (brief 1: four unequal wall runs, final run dashed and not closed).
  The spec names "open rect + door swing arc" as a *house motif* — one of the three marks
  that make an icon a WhisperRoom icon. The motif wins over the brief; a not-quite-closing
  dashed run also reads as noise at 20 px. Kept the mockup's drawing.
- **`art-angled`** carries two ghosts, not the brief's three. Three plus the subject is
  four overlapping parallelograms inside 20 units.
- **`scene-parts`** kept the mockup's corner-brackets-plus-cube rather than brief 16's
  scene-tab-into-file-card, because the four exporters it sits beside already use the
  frame-and-arrow language and the cube is the clearest "geometry, not a picture" mark.

## Collision audit

Every one of the 28 runnable scripts resolves to a different icon — checked mechanically,
not by eye (`gen-icons.py` fails the build on a repeat). The two pairs that are *meant* to
look related, and why that is not a collision:

- **`scenes-export` / `view-export`** — two frames vs one frame, same orange arrow. Brief
  11 asks for exactly this: "the deliberate singular of #10, same arrow, same weight, one
  frame". Plural against singular is the message.
- **`dim-room` / `dim-booth` / `dim-selection`** — all three carry the house dimension
  string, because all three dimension something. They separate on subject and on how many
  strings: open room plan + two rows; solid booth with door return and name badge + one
  row; dashed marquee round a shapeless blob + an L over two axes.

Fixed on the way through, where the mockup had genuine one-icon-two-tools failures:
`i-scenes` served both `list-scenes.rb` and `export-scenes.rb`; `i-scenecomp` served four
tools; `i-probe` served three.

## Verified (observed, by parse — never by rendering)

- All 30 SVG files parse as well-formed XML (`xml.etree.ElementTree`).
- Every `viewBox` is `0 0 24 24`; every standalone file carries one.
- Every stroke width is 1.8, or 1.4 / 1.2 for the deliberately recessive context marks
  (extension lines, ghosts, level rules) — the same hairline convention the mockup used.
- Exactly one `stroke="#ee6216"` group per icon: 1 per standalone file, 29 in the sprite.
- Every path traced to absolute coordinates: all geometry sits inside the 2..22 live area.
  Caveat: arc and curve segments are bounded by their endpoints and control points, so a
  bulge past an endpoint is not caught. The circles and arcs in this set are well inside.
- All 33 `.rb` files in `scripts/` appear in `icon-map.json`; every id in the map exists as
  a `<symbol>` in `wr-icons.svg`; no id maps to two runnable scripts.

**Not verified:** that any of this reads clearly at 20 px, or at all. Nothing was rendered.
