# WhisperRoom panel redesign — spec

Scoper output, 2026-08-15. Mockup: `.forge/scoper/panel-redesign.mockup.html` (open in any
browser; both frames are interactive). This spec is written so a Builder can implement it
against `scripts/wr_tools/panel.html` and `scripts/wr_tools/main.rb` without asking me
anything.

Provenance: everything said here about current behaviour is **observed** — I read
`panel.html` (all 1003 lines) and `main.rb` (all 942 lines) and grepped every `@`-header in
`scripts/*.rb`. Claims about external design references are **reported** from the cited
sources plus working knowledge of the named tools.

---

## Goal

Redesign the docked panel so a new user can tell, without being taught: what each tool
does (icons that depict the work), which tools run once versus which stay on in the model
(actions vs abilities), what the plugin has already done to the open model (state strip),
and what the trailing "…" convention means (a visible dialog glyph and an in-panel pre-run
sheet). The concept — one searchable list, a pasted-link command, a toolbar mirror —
survives; the presentation is replaced, and the generic 46-icon library is replaced by a
purpose-built WhisperRoom icon system.

## Research — what was looked at, and what applies at 340 px

Reported sources: [KiCad icon design guidelines](https://dev-docs.kicad.org/en/rules-guidelines/icon-design/index.html)
(fixed grid, stroke discipline, sizes divisible by four for a dense engineering tool),
[Adobe Design — how to design effective icons](https://adobe.design/stories/leading-design/how-to-design-effective-icons-part-2)
(stroke alignment, live area), [Eleken](https://www.eleken.co/blog-posts/toggle-ux) and
[Setproduct](https://www.setproduct.com/blog/toggle-switch-ui-design) on toggle UX
(ON must differ strongly from OFF; never use a toggle for a destructive action —
which validates the ability model here, since off *undoes* rather than destroys), and
[Adobe XD plugin design docs](https://adobexdplatform.com/plugin-docs/design/) on panel
plugins. Working knowledge applied: VS Code's sidebar (single search over a tree, sticky
section headers, counts in headers), Figma's plugin panels (system fonts, 8 px rhythm,
one accent), Blender's N-panel (collapsible categories that remember state).

What does **not** transfer at 340 px: card grids, two-column layouts, icon-only toolbars
for primary actions (labels are the navigation), and hover-revealed primary affordances
(kept only for secondary ones: star, RUN hint).

## Art direction (committed)

**The shop drawing.** The panel borrows the language of the drawings the plugin produces:
hairline rules, drafting tick marks, warm-grey surfaces, one accent — dimension-tag orange
`#ee6216` (dark theme lifts it to `#f47b35` for contrast). System type only (Segoe UI
stack), tabular numerals for counts. The governing rule: **orange is a verb** — it appears
only on things that act on or exist in the model (active toggles, the state strip, RUN,
the icon's subject element), never as decoration.

Rejected: dark-only "pro DCC" styling (SketchUp ships light; dark is offered, not
imposed); card-based layouts (wrong shape for 340 px); a second accent (green for ON is
removed — one accent, one meaning).

## The design, piece by piece (matches the mockup)

1. **Command bar** (kept): single search over everything; pasted booth-builder link
   becomes a "Build this booth design" action (kept verbatim from current
   `boothLink()` / `buildlink` mechanism — observed, it is good).
2. **State strip** (new): under search, `IN THIS MODEL` followed by one orange chip per
   ability currently on. Click a chip → scroll to that ability row. Empty state: quiet
   "nothing drawn by the panel". Data already exists: `on_now` per ability in the payload.
3. **Ability rows** (redesigned): **one row per script** — a script that declares
   `@on`/`@off` carries its switch on its own row inside its task category, ending the
   current duplicate script-row/ability-row split (adopted from the Researcher's
   structural proposal in `.forge/researcher/proposed-structure.md`). Row = icon well,
   title, blurb, ON/OFF stamp, gear (if `@setting`s), switch. On-state shows a 3 px
   orange left rail, orange icon well, orange switch. Gear expands inline settings
   exactly as today (`@setting` grammar unchanged). Ability rows have **no RUN
   affordance**: the switch is the action, which also side-steps the autorun defect
   (below).
4. **Action rows** (redesigned): icon well, title, one-line blurb. Trailing `…` in
   `@title` is stripped for display and rendered as a small window glyph; hover swaps it
   for `RUN ▸`. The per-row "ago" timestamp and filename move into the row tooltip
   (`title` attribute); the NEW pill (fresh < 24 h) stays. Sorting becomes stable
   (category order, then alphabetical) instead of newest-first — predictability beats
   recency for a new user; recency is the NEW pill's job.
5. **Categories**: the Researcher's pipeline tree, **adopted as-is** in the mockup —
   Draw the room / Build the booth / Add dimensions / Scenes and images / Component art
   (web catalog) / Tidy up the model — in fixed order (the build-booth ladder must not be
   re-sorted), collapsible, with counts; collapse state persisted in a pref. Titles use
   the Researcher's 14 proposed `@title` renames. Eight dev/one-off scripts move behind a
   footer switch ("Show developer & workshop tools", off by default) into two collapsed
   shelves — `Developer probes` and `Workshop (3D printing)` — declared per script by a
   new optional `# @shelf dev|workshop` header (the Researcher's mechanism; parse beside
   `@cat`). **Search always finds shelved scripts**, shown with a `DEV` badge, even with
   the switch off. A `Pinned` group at top lists starred tools as normal runnable rows.
   (Note: `main.rb`'s comment history shows runnable favourite *pills* were removed
   because they could disagree with the toolbar mirror — observed. A Pinned group of
   canonical rows does not have that failure: it shows the tools themselves, not toolbar
   faces.)
6. **Rename and star** (kept): pencil→rename rewrites `@title` only (filename untouched —
   observed rationale in `main.rb` `rename`, keep it verbatim); star = first free toolbar
   slot (observed `toggle_pin`).
7. **Toolbar mirror** (kept, restyled, moved): now the last section, collapsible, with
   the pending state as an amber dashed tile + corner dot + one amber note line
   ("Slot 4 changed — SketchUp repaints toolbar icons at next launch. It already runs the
   new tool."). All of `bound` vs `slots` honesty in `main.rb` is kept as-is; only the
   clothes change. Slot editor becomes a bottom sheet; the icon picker offers the **new
   WR icon set** instead of the 46 generic icons.
8. **Pre-run sheet** (new, optional per tool): an action script that declares
   `@setting` lines gets an in-panel bottom sheet (fields + Cancel/Run) instead of going
   straight to `load`. See grammar note below — this is the one header-grammar change.
9. **Bundled-copy notice, error notes** (kept): same behaviour, restyled to the token
   sheet.

## Icon system (deliverable, authored in the mockup)

Geometry: 24-unit grid, 20-unit live area (2-unit padding), 1.8 centred stroke, round
caps/joins. Two inks: `currentColor` graphite for context; `#ee6216` for **exactly one
element — the thing the tool creates or changes**. House motifs that make an icon a
WhisperRoom icon: the **booth** (solid rect + door return), the **room** (open rect + door
swing arc), the **dimension string** (line with oblique drafting ticks, never arrowheads —
matching Benton's drawing convention). Rule of failure: an icon with no motif and no
orange subject (bare gear/star/wand) is rejected.

18 icons are authored as inline SVG symbols in the mockup, covering the hard cases:
Build Booth (real components) / Build Booth / Build Booth from Link (three build variants
distinguishable at 20 px: arriving panel vs plus vs chain link), Dimension WhisperRoom vs
Dimension Selection (solid booth + door vs dashed selection box — the 20 px pair test is
rendered in the mockup), Build Room, Auto Dimension, Exploded View, Elevation Export,
Orbit Export, Export Scenes, Export This View, Merge Materials, Merge Scenes, Probe,
Find and Replace Names, Proposal Scenes, Save Scene Components, Reference geometry.
Builder extracts each `<symbol>` to `scripts/wr_tools/wr-ico-<id>.svg` files (SketchUp
toolbar needs standalone SVGs; the panel can keep the inline sprite).

Still needed from a Graphics Designer or a second pass: distinct icons for
Export Component Art / Angled Component Art / List Scenes / Probe Face Levels /
Pendant Curing Jig / Tube Drying Stand (the mockup reuses neighbours for these — an icon
serving two tools fails the system's own test and must not ship that way).

## Header-grammar changes (the ~40-file question)

- **Required: none for the panel to render.** `@title`, `@cat`, `@ability*`, `@setting`,
  `@on/@off` all keep their current syntax. The redesign renders fully with zero edits to
  the 40 scripts.
- **Recommended (small, per-script `@title`/`@cat` line edits, not grammar changes)**:
  the Researcher's 14 renames and the `@shelf` lines on the 8 hidden scripts — about 22
  one-line header edits total, all label-only, filenames untouched.
- **Prerequisite fix before ability rows ship**: the autorun defect
  (`.forge/researcher/panel-problems.md` finding 2 — reported, not runtime-verified):
  `main.rb`'s `toggle` loads ability scripts without setting either suppression global
  (`$wr_no_autorun` / `$wr_suppress_autorun`), so flipping a switch also runs the
  script's normal entry point, dialog and all. Fix in `main.rb#toggle` (set the guard
  around `load`) and reconcile the two guard names across the five ability scripts.
- **Optional, additive: `# @icon <id>`** — one line, only on scripts that want a specific
  WR icon. Fallback chain: `@icon` → a shipped filename→icon map
  (`scripts/wr_tools/icon-map.json`, one new file, covers every current script) →
  a neutral booth glyph. So the full icon rollout costs one JSON file, not 40 edits.
- **Optional, additive: `@setting` on action scripts** enables the pre-run sheet (step 8).
  Grammar identical to ability `@setting`; the script reads values the same way abilities
  do (prefs under `set_<name>_<key>`). Adopt per script, over time; a script without
  settings behaves exactly as today. **Cost worth naming to Benton**: converting an
  existing script's own `UI.inputbox` to panel settings is a per-script code change —
  do it opportunistically, not as a big-bang.

## Steps (ordered, for the Builder)

1. **Tokens + skeleton** — `scripts/wr_tools/panel.html`: replace the stylesheet with the
   mockup's panel token sheet (light + dark via `prefers-color-scheme`; the frame-scoped
   `--p-*` variables become `:root` tokens). Keep every existing callback name
   (`ready/run/pin/rename/setslot/buildlink/ability/setting/rescan/folder/console`) —
   `main.rb` is untouched by this step.
2. **Icons** — extract the 18 symbols from the mockup into
   `scripts/wr_tools/wr-ico-*.svg`; add `scripts/wr_tools/icon-map.json`
   (filename → icon id, every current script); author the ~6 missing icons.
3. **Payload additions** — `scripts/wr_tools/main.rb`: add `icon` per script to `scan`
   (resolve `@icon` header, else map, else default); keep `ago`/`name` in the payload for
   tooltips. Parse `@icon` in `meta_of` (additive regex, same header block).
4. **List redesign** — `panel.html`: new row renderers (action row, ability row), state
   strip, category collapse with persisted state (new pref via a new `collapse` callback
   in `main.rb`, or reuse `setting`), Pinned group, stable sort. Remove per-row ago/file
   text; keep them in `title` tooltips.
5. **Toolbar section** — move slots to bottom section; restyle pending state (amber);
   slot editor as a bottom sheet offering the WR icon set. `main.rb` `face_path`
   fallback chain unchanged; the icon library glob picks up `wr-ico-*.svg`
   (adjust the `ico-*` glob to include the new prefix, keep old ids working for saved
   prefs).
6. **Pre-run sheet** — `main.rb`: allow `@setting` on non-ability scripts (currently
   settings only survive when an ability block validates — observed at
   `meta_of`'s final `abil = nil unless …` line, so this is a small parser change plus a
   `settings` key on plain scripts in the payload). `panel.html`: sheet UI; `run`
   callback unchanged (scripts read prefs). Pilot on one script (suggest
   `orbit-export.rb`), convert others opportunistically.
7. **Retire the generic library** — once every script resolves a WR icon, delete unused
   `ico-*.svg` + `ico-labels.txt` entries (keep any id still referenced by saved slot
   prefs, or migrate prefs).

## Acceptance criteria

- Panel at 330 px and at 640 px wide: no horizontal scroll, no truncated controls; blurbs
  ellipsize (verify by resizing the docked dialog; `min_width` is 330 — observed in
  `panel.html`… `main.rb` `UI::HtmlDialog` options).
- Light and dark: every colour comes from the token sheet; toggling OS theme flips the
  panel with no unreadable element (spot-check state strip, pending slot note, sheet).
- An ability turned on shows all four signals (rail, ON stamp, switch, chip) and turning
  it off removes all four; the chip count matches `on_now` truth from Ruby after a
  `push` (the optimistic flip is corrected by render — keep that mechanism).
- Every visible tool row shows an icon; no two tools share an icon; the
  Dimension WhisperRoom / Dimension Selection pair is distinguishable at 20 px.
- A script with trailing `…` shows the dialog glyph; one without does not.
- Pending toolbar slot shows dashed amber tile + note; after restart it clears (manual
  check across a SketchUp restart).
- All existing behaviours still work: search, link paste → `booth-from-link.rb`, run,
  star/pin, rename (filename untouched on disk), ability settings persistence, bundled
  notice, broken-script error note. No callback renamed.
- Zero edits required to any script in `scripts/` for the panel to render fully.
- With the footer switch off, the eight shelved scripts are absent from the list; typing
  `probe` surfaces them with a `DEV` badge; the switch reveals both shelves and its state
  survives a panel reopen.
- Flipping any ability switch does **not** open that script's run dialog (autorun guard
  fix verified in SketchUp for all five ability scripts).

## Risks / out of scope

- **Out of scope**: rewriting scripts' own `UI.inputbox` dialogs (pre-run sheet is
  opt-in, per script, later); booth geometry and builder scripts; the `WhisperRoomQuote`
  repo; prices anywhere.
- **Risk — icon glob/prefs**: saved `slot_icons` prefs reference old `ico-*` ids; step 5
  must keep those resolving or migrate them, else slots regress to numbered faces.
- **Risk — settings parser change** (step 6) touches `meta_of`, which every panel render
  runs; a regression breaks the whole list. It is last and independent for that reason.
- **Assumed**: SketchUp's embedded Chromium honours `prefers-color-scheme` from the OS.
  I did not verify this on a machine; if it does not, ship a manual theme pref (one
  toggle, same tokens). Verify early in step 1.
- **Researcher inputs adopted**: `.forge/researcher/proposed-structure.md` landed
  mid-work; its category tree, renames, one-row-per-script structure, and hidden-shelf
  mechanism are folded into the mockup and this spec. Its icon briefs are more specific
  than several of my authored icons (e.g. five-plate fan for proposal scenes, name badge
  on dimension-the-booth, checkerboard for flat art) — treat those briefs as the target
  for the second icon pass.

## Approval gate

I have no user channel. **Nothing here is user-approved.** The gate is: Benton opens the
mockup (or the published artifact), reacts, and the surviving direction becomes binding.
Open forks for him: (a) accept the Researcher's 14 renames (they change the `@title`
lines Benton reads every day); (b) keep newest-first sorting or accept the fixed
pipeline order (as mocked); (c) retire `booth-4260-s.rb` / `booth-96168-s.rb` and move
`csusb-rooms.rb` to `clients/`, per the Researcher's disposition table.
