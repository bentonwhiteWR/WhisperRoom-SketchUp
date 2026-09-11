# Leak-risk audit — what reaches a customer that should not

Read-only. Plugin 1.48.0/1.48.1, audited 10 Sep 2026. Nothing was changed
outside this file.

**Dimension:** every remaining route by which construction annotation,
internal notes, house-default disclaimers, placeholder strings, invented
geometry or wrong dimensions can land in an exported image, a proposal PDF,
or a file sent to a client.

**Bottom line.** The per-scene ANNOTATIONS picker is now the only authority,
and on the scenes AUTO-SET writes it holds. The exposure is everywhere the
picker is NOT the authority: a second client-export lane that never consults
it (`wr-pack-export.rb`), four shipped room scripts that put
"HOUSE DEFAULT / not measured" text on tags outside the `WR-Dims*/WR-Notes*`
family so no sweep, mode or preflight can see them, a review column that
goes orange for a harmless Untagged callout but stays grey for the literal
D5 tag, and a review column that silently and permanently degrades to a
false "all hidden" on a slow model.

Claim tags: **observed** = read in the code at the cited line;
**derived** = follows from observed code plus a documented API behaviour the
repo itself states; **reported** = the repo's own DEVLOG/comments assert it;
**assumed** = my inference, flagged as such.

Findings about the zero-scene open path are noted where relevant — that work
appears already landed at 1.48.1 (`open_decision`, `proposal-package.rb:3691`).

---

## R1 — The review column does not flag the D5 tag. Only loose callouts go orange.

**Risk: high. Silent, irreversible (the image is already sent).**

`scripts/wr-autoset.rb:1045-1066` (`annot_cell`) is the cell Benton reads
before he presses Export. `warn` is set from **one** input:

```ruby
warn = false
unless loose_shown.nil?
  n = loose_shown.size
  if n > 0
    warn  = true
    ...
```

`shown` — the family tags the scene leaves visible — never sets `warn`.
A scene whose saved state shows `WR-Notes` renders as grey `"1 shown"`,
styled identically to `"dims + doors"`, which is the *wanted* state of plate
02. (observed: `annot_cell`; `.cst.warn` styling at
`scripts/proposal-package.rb:4741`; the comment at
`scripts/proposal-package.rb:5247-5249` states orange exists for "the D5
class of defect".)

AUTO-SET owns a `NEVER_SHOWN` list — `WR-Notes`, `WR-Dims-Booth`,
`WR-Dims-Selection` (`scripts/wr-autoset.rb:151`) — but it is consumed only
by the **writer** (`effective_shown`, line 162). The **reviewer** never reads
it. (observed)

Failure scenario: a scene AUTO-SET did not write — hand-made scene tab, a
model from before 1.20.0, a scene imported via `merge-scenes.rb` (see R9) —
saved while the model sat in draft mode, so `WR-Notes` is visible on it.
Mark it Image. The grid says `"1 shown"` in grey. `start_run` logs nothing
about it (observed: `scripts/proposal-package.rb:1494-1841` contains no
per-scene annotation log line). `unit_image` hides only `WR_Mode::LIGHT_TAGS`
(`scripts/proposal-package.rb:2260`). The banner
`Ceiling 8'-0" - HOUSE DEFAULT, not measured. Confirm before quoting.`
is in the PNG. The only record is `annotation_tags_shown` in `manifest.json`,
written in `finish` **after** the file exists
(`scripts/proposal-package.rb:3112-3170`). (derived)

Cheapest fix: `annot_cell` should set `warn` when
`shown & WR_AutoSet::NEVER_SHOWN` is non-empty, and `start_run` should log
one `'bad'` line per live row whose page shows a NEVER_SHOWN tag.

---

## R2 — The review column self-disables permanently and then asserts a false "all hidden".

**Risk: high. Silent, and the stated remedy does not work.**

`scripts/wr-autoset.rb:988-1035`. The deep pass is timed; over
`DEEP_BUDGET = 2.5` s it does `self.deep = false` (line 1029) and sets
`_slow`. On the next call `deep?` returns false, `row_states` returns after
the shallow pass, and every cell is built with `loose_shown = nil`.

`annot_cell` with `loose_shown == nil` returns
`label => 'all hidden'`, `warn => false`,
`tip => 'No annotation set is shown on this scene.'` (observed, lines
1053-1065). That is a positive claim of cleanliness made from a read that
did not look.

Two compounding problems:

1. **Nothing ever sets `@deep` back to true.** `grep -rn '\.deep\b|@deep'
   scripts/*.rb` returns only `deep?`, `deep=`, and the single
   `self.deep = false`. (observed) Yet the log line the operator is given
   says *"Hit Rescan to try again"*
   (`scripts/proposal-package.rb:1039-1041`). Rescan calls `row_states`,
   `deep?` is still false, and the columns stay blind for the rest of the
   SketchUp session. The remediation instruction is false.
2. **The only surviving signal is a hint-bar sentence.**
   `scripts/proposal-package.rb:5397-5398` swaps the header text to
   "WALLS/ANNOTATIONS show tag state only". The cells themselves keep saying
   "all hidden" in the normal colour. (observed)

Failure scenario: a room model with many scenes and many wall units — the
deep pass selects every page in turn (line 1013) — trips 2.5 s once. From
then on every plate in that session reads "all hidden" regardless of what is
actually showing, and the one thing the column exists to catch is the one
thing it can no longer see. (derived)

---

## R3 — Four shipped room scripts write "not measured" disclaimers onto tags outside the annotation family. This is D5's exact mechanism.

**Risk: high. Recurrence of the named defect, by the same route.**

`ANNOT_RE = /\AWR-(Dims|Notes)(\z|-)/` (`scripts/proposal-scenes.rb:82`).
These tags do not match it (observed, tag names read at the cited lines):

| Script | Tag | Text it carries |
|---|---|---|
| `scripts/csusb-106.rb:389` | `WR-106-Notes` | line 418-421: `"Ceiling drawn at 8'-0\" HOUSE DEFAULT — NOT MEASURED. Get a tape on it before quoting a booth."` |
| `scripts/csusb-106.rb:388` (via `t_dim`) | `WR-106-Dims` | every room dimension |
| `scripts/dowaly-kuwait-tv.rb:178` | `WR-KTV-Notes` | line 247-251: `"Room figures are the CLIENT'S OWN and he calls them approximate. Nothing measured on site."` |
| `scripts/fvrl-podcast-alcove.rb:173` | `WR-FVRL-Notes` | line 248-254: `"ALCOVE WIDTH IS NOT A MEASURED DIMENSION. It has never been supplied."` |
| `scripts/smith-studio.rb:449` | `WR-Studio-Notes` | line 470-476: `"from a HAND SKETCH, nothing measured with a tape… measure before quoting Enhanced."` |
| `scripts/smith-studio.rb:448` | `WR-Studio-UNRESOLVED` | red ghost door marking an alternative entry position |

Because none matches `ANNOT_RE`:

- `WR_ProposalScenes.annot_tags` (`proposal-scenes.rb:87`) never returns them,
  so `WR_Mode` render mode never hides them
  (`scripts/wr-mode.rb:100-113`, `to_mode`'s backfill at 297-300 fills only
  `annot_tags`). (derived)
- `WR_Preflight.check_dims` greps `/\AWR-Dims/` over `annot_tags`
  (`scripts/wr-preflight.rb:56`) — `WR-106-Dims` fails both the grep and the
  family, so a CSUSB 106 model passes the dimension row with every dimension
  on. (derived)
- The manifest's `annotation_tags_shown` / `annotation_tags_hidden` are
  computed against `present = annot_tags(model)`
  (`scripts/proposal-package.rb:3123`), so they never name these tags either.
  The record that would let anyone catch it afterwards is also blind. (derived)

They *are* reachable by the per-scene picker — `inventory` files any
non-family-tagged annotation into `loose` (`wr-scene-annotations.rb:262-270`,
observed) — so AUTO-SET's "hide every loose callout" rule does cover them on
scenes it writes. But that is one net, per scene, and it does not exist on
the mode-driven lane (R4).

Every one of these scripts is one click in the panel: `wr_tools/main.rb:63-66`
`SKIP` lists eleven libraries; everything else in `scripts/` becomes a panel
entry (observed, `script_files` at line 91-97).

Note the smallest fix that closes the class: route these through
`WR_ProposalScenes.annot_set_name` (`proposal-scenes.rb:98`), which already
forces any name into the family. Nothing in the repo currently forces tag
creation through it outside the picker.

---

## R4 — `wr-pack-export.rb` is a client-pack lane that never consults the ANNOTATIONS picker, and puts the model in DRAFT to shoot plate 02.

**Risk: high. Whole lane, no gate at all.**

`scripts/wr-pack-export.rb` — header `# @title Export the client pack...`,
`@rank 5`, live in the panel. Flow per plate (observed, lines 199-233):

```ruby
model.pages.selected_page = page
mode_result = p['mode'] == 'draft' ? WR_Mode.to_draft(model) : WR_Mode.to_render(model)
...
cfg  = { 'dir' => stage, 'width' => '2400', 'bg' => 'Transparent', 'over' => 'Yes' }
x = WR_ExportScenes.export_pages(model, plan, cfg)
```

Three facts together:

1. `cfg` carries **no `hide_tags`** key. `export_pages` therefore hides
   nothing of its own (`scripts/export-scenes.rb:243`, observed).
2. `02-dimensioned` is shot in **draft** mode, and draft's policy is
   `ANNOT_TAGS` all **visible** at model level
   (`scripts/wr-mode.rb:136-140` `DEFAULT['draft']['dims']`, observed). That
   includes `WR-Notes` — the literal D5 tag
   (`scripts/wr-mode.rb:103-109`, observed).
3. `to_draft` does **not** stamp annotation tags into pages; only
   `LIGHT_TAGS` are stamped (`wr-mode.rb:322-327`, `stamp_light_pages`,
   observed, and the comment at 318-321 says so explicitly).

So whether the banner reaches the PNG depends entirely on whether that page
happens to have `use_hidden_layers?` true *and* saved `WR-Notes` hidden. If
it does not, the model's live draft state governs and the banner exports.
(derived — the page-restores-its-own-tag-visibility behaviour is stated as
observed by the repo at `export-scenes.rb:230-240`.)

There is also no preflight call anywhere in this file (observed: no
`WR_Preflight` reference), so unlike `proposal-package.rb` it has no
Continue/Cancel modal either. The output is then flattened and trimmed
straight into the client folder (lines 217-223).

This lane predates the picker and was never retro-fitted. It should either
hide the family itself, or refuse to run on a page whose ANNOTATIONS answer
was never written (the AUTO-SET stamp at `wr-autoset.rb:DICT` makes that
testable).

---

## R5 — No export path gates on a scene that does not save hidden tags or objects, and the image lane runs in DRAFT.

**Risk: high. Silent; the tool already knows the condition exists.**

`scripts/proposal-package.rb:696-722` already names this case in two places:

```ruby
unless use_hidden
  return [nil, 'unreadable: the scene does not store tag visibility ' \
               '(use_hidden_layers off) - the model\'s live state governed']
```

That string only ever appears in `manifest.json`, written in `finish`
(line 3112) — after the PNGs are on disk. (observed)

`start_run` (lines 1494-1841) builds `units` as
`[:mode, 'draft'] … [:image, p] …` (lines 1692-1699, observed). Draft shows
every annotation tag. On a scene with `use_hidden_layers` off the page switch
inside `export_pages` restores no tag state, so the live draft state is what
`write_image` sees. Per-entity hides (loose callouts, AUTO-SET's whole
Untagged sweep) ride on `use_hidden_objects` and fail the same way. (derived)

The detection already exists and is already wired to three other surfaces —
`WR_SceneAnnotations.pages_not_saving` / `fix_pages`
(`wr-scene-annotations.rb:105`, `:156`), the picker's `warn` flag
(`proposal-package.rb:4374`), and AUTO-SET's `offpages`
(`wr-autoset.rb:632-633`). It is **not** wired into `start_run`. A one-line
check against the live rows, refusing or warning before the first write,
would close this with code that is already written and tested.

---

## R6 — The one preflight row that could catch an annotation leak excludes the D5 tag, on the authority of a pass that was deleted.

**Risk: medium-high. A stale guarantee presented as a live one.**

`scripts/wr-preflight.rb:50-56`:

```ruby
# This check is about DIMENSIONS specifically (that is what it reports and
# what its name says), so WR-Notes* sets are deliberately not folded in —
# the client-safe pass in proposal-package.rb is what covers those.
dims = WR_ProposalScenes.annot_tags(model).grep(/\AWR-Dims/)
```

The client-safe pass was removed at 1.47.0. `DEVLOG.md:284` lists
`scripts/wr-preflight.rb:55` under "Leftover references, not edited" — so the
stale comment was known, but the *coverage gap it describes* was never
reassigned to anything. Nothing in the checklist looks at `WR-Notes` now.
(observed)

Compounding: `proposal-package.rb:1583-1592` removes even the `dims` row from
the blocking set before the Continue/Cancel modal — deliberate and requested
(Benton, 10 Sep), but it means the checklist contributes nothing at all to
annotation safety on the export path. (observed)

---

## R7 — The prompt handed to the PDF-building agent tells it to transcribe whatever is on the plate, and drops the manifest's own annotation record.

**Risk: medium-high. This is the step that turns a leaked pixel into a leaked sentence in the PDF.**

`scripts/proposal-package.rb:826-829` (observed):

```
'PER SCENE - each plate shows what its own scene left visible. ' \
'Transcribe callouts exactly as drawn and only where legible.'
```

The per-row lines built at 803-820 carry file, scene, lane, size, status,
two-point state and `groups_hidden` — but **not** `annotation_tags_shown` or
`annotation_tags_hidden`, which `manifest_rows` does write
(`proposal-package.rb:756-757`, observed). So the agent is told to transcribe
and is not told which annotation sets are on the plate, nor that a
`WR-Notes`-class set is one it must query rather than quote.

Failure scenario: R1/R4/R5 puts the house-default banner on plate 02. The
agent reads `claude-prompt.txt`, follows "transcribe callouts exactly as
drawn", and the disclaimer becomes a caption in the client PDF. (derived)

Add `annotation_tags_shown` to the per-row line, and a hard rule that a plate
showing any `WR-Notes*` set is raised with Benton before captioning — the
prompt already carries a "raise each of these with Benton" block (line 862)
that this belongs in.

---

## R8 — Scope blind spots: three walks with three different, non-overlapping definitions of "a callout".

**Risk: medium. Each is documented in its own file; nothing reconciles them, and the grid cell's "all hidden" inherits all three limits without saying so.**

1. **`WR_SceneAnnotations::DEPTH = 2`** (`wr-scene-annotations.rb:75`).
   `each_annotation` stops at two containers (lines 221-241, observed).
   Anything deeper is invisible to the picker, to AUTO-SET's
   `annot_picks` loose sweep (`wr-autoset.rb:185`) and to
   `collect_hidden_annotations` (`proposal-package.rb:3071`). The picker's own
   footer says so (`proposal-package.rb:5800`); `annot_cell`'s "all hidden"
   does not. `peoplesspace-alcove.rb` labels sit at exactly depth 2
   (`build_option` → `g` → `label(g,…)` from
   `model.entities.add_group` at line 820) — one container from invisible.
   (derived)

2. **`collect_annotations` walks `model.entities` top level only**
   (`proposal-package.rb:2975-3013`, observed; declared honestly via
   `annotation_scope` at line 3154). Consequence: every note the client room
   scripts write **inside their room group** — `csusb-106.rb:418`,
   `smith-studio.rb:470`, `csusb-rooms.rb:424` and `:457` — is absent from
   `manifest.json`'s `annotations` array. So a leaked banner is missing from
   the after-the-fact record too. (derived)

3. **`LABEL_RE = /\Alabel:\s*/`** (`wr-scene-annotations.rb:74`) is what makes
   a 3D-text group an annotation. `build-booth-components.rb:2246` names its
   group `"MISSING label  #{part[:id]}"` — leading token is `MISSING`, so the
   regex does not match. `kind_of` returns nil, and the text
   `"MISSING <part>.skp"` (line 2248) is invisible to the picker, to AUTO-SET
   and to `collect_hidden_annotations`. (observed)
   It is *deliberately* visible as a warning and `WR_Preflight.check_complete`
   does gate the export with a Yes/No modal
   (`wr-preflight.rb:203-220` → `proposal-package.rb:1594-1603`), which is the
   right behaviour. But the justification comment at
   `build-booth-components.rb:2199-2203` — *"the proposal package's
   client-safe pass hides that family by name… a warning that vanishes
   exactly when the client images are made is no warning"* — reasons about a
   pass that no longer exists, and the operator has no per-scene way to
   suppress it even when he wants one.

---

## R9 — Scene import manufactures the unsafe-scene condition.

**Risk: medium.**

`scripts/merge-scenes.rb:229` (observed):

```ruby
pg.use_hidden_layers = s['use_tags'].nil? ? true : s['use_tags']
```

The import restores the *flag* from the file but never restores the source
scene's per-page hidden tags (`hidden_tags` is captured at line 124 and never
read back on import), and never touches `use_hidden_objects` at all. So an
imported scene snapshots whatever the importing model is showing at that
instant — which, if the operator is in draft, is every annotation tag on. The
scene then lands in the proposal grid as an ordinary row. Feeds R1 and R5.
(derived)

---

## R10 — Invented geometry and query markers ride into client renders on tags no automated check knows about.

**Risk: medium-low. Declared in the scripts, guarded by nothing.**

`scripts/peoplesspace-alcove.rb:764` creates `WR-Context-INVENTED` — an
elevator recess, a storefront, a room behind glass, a floor carrying on east,
none of it measured (lines 460-540, observed). `scene()` sets
`tags[:ctx].visible = true` for `01-exterior`, `03-side` and `04-ventilation`
(lines 698-701, 731-736, observed); only the dimensioned and plan plates drop
it. That is a deliberate, documented choice — a hero render is supposed to
read as a real place — but it means fabricated architecture is in a client
hero plate on a tag that no mode, preflight, picker or manifest field
mentions. Nothing would catch it if the intent were ever forgotten.

Same class: `WR-Studio-UNRESOLVED` (`smith-studio.rb:448`), a red ghost door
showing an *alternative* entry position; `WR-FVRL-LIMIT`
(`fvrl-podcast-alcove.rb:172`); the `"BOOTH PLACEHOLDER"` 3D label
(`peoplesspace-alcove.rb:603`, on `WR-Notes`, so this one is covered).

Because these are geometry rather than annotation, no annotation tool can see
them by construction. If a rule is wanted, it has to be a tag-name rule —
e.g. preflight failing on any visible tag matching
`/INVENTED|UNRESOLVED|LIMIT|Missing/`.

---

## Lower-severity notes

- **Overridden dimension text is never compared to the measured span.**
  `collect_annotations` writes both `text` and `measured`
  (`proposal-package.rb:2980-2994`) and `dim_display` returns the raw text
  verbatim when there is no `<>` (line 683-690). A dimension whose string was
  hand-typed and has since gone stale exports the stale number, and nothing
  flags `text != measured` in the manifest or the prompt. (observed / the
  wrongness scenario is derived)
- **`export-this-view.rb`** writes the live viewport to a PNG in the same
  folder as a batch, with no mode handling, no annotation handling and no
  preflight (observed: no `WR_Mode`/`WR_Preflight`/annotation reference in the
  file). It is WYSIWYG by design, but it is a zero-guard route into a client
  folder.
- **`shown_loose` fails toward clean on an exception.**
  `wr-autoset.rb:1022`: `loose.reject { |it| ((it[:ent].valid? && it[:ent].hidden?) rescue true) }`
  — a raise inside the block is rescued to `true`, i.e. "treat as hidden".
  An invalid entity correctly counts as shown; a raising one does not.
  (observed)

---

## What this audit did NOT cover

- **No SketchUp run.** Nothing here was executed. Every behavioural claim
  about SketchUp's own API (page restores its saved tag visibility on
  activation; `use_hidden_layers` off means the live state governs;
  `Page#layers` returns the hidden layers) is taken from the repo's own
  observed-and-dated assertions, not re-verified.
- **No exported PNG was inspected.** DEVLOG (line ~163) states this gap
  explicitly: the D5 export check — open every exported image and confirm no
  `Ceiling 8'-0" - HOUSE DEFAULT` string reaches one — has still never been
  run. R1, R4 and R5 are the three paths I would aim that check at first.
- **`proposal-package.rb` is under concurrent edit.** Findings touching the
  zero-scene open path are excluded; `open_decision`
  (`proposal-package.rb:3691`) reads as already landed at 1.48.1. R1, R5 and
  R7 cite regions (`start_run`, `agent_prompt`, `annot_cell`) that I did not
  see marked as in flight, but they should be re-checked against the current
  file before anyone acts on them.
- **Not read:** the V-Ray probe scripts, `wr-drop-lights.rb` beyond its tag
  stamping, `wr-deck.rb`, `wr-overlays.rb`, `angled-component-art.rb`,
  `elevation-export.rb`, `orbit-export.rb` and `explode-view.rb` (component-art
  lanes, not client-proposal lanes — they write parts catalogues, and I did
  not verify that assumption), the Python helpers, `proposals/build-v2.js`,
  or the PDF generator itself. A leak that happens *inside* the PDF builder
  rather than upstream of it is out of scope here.
- **No claim is made about which of these has ever actually fired.** Each is a
  reachable path read in the code; none was observed producing a bad file.
