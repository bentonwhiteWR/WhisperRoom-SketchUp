# HANDOFF — Researcher → Scoper / Builder

## Produced

- `.forge/researcher/script-inventory.md` — all 42 files in `scripts/`: current headers,
  what each actually does, audience (DAILY / OCCASIONAL / DEV-ONLY / LIBRARY / ONE-OFF),
  ability-vs-action, what it operates on, current icon. Includes the `SKIP` audit and the
  Python tools the panel cannot see.
- `.forge/researcher/panel-problems.md` — 11 concrete problems with `main.rb` and
  `panel.html`, each cited to a line, plus the two suspected overlaps checked in detail.
- `.forge/researcher/proposed-structure.md` — the six-category tree, the eight scripts to
  hide and how they stay reachable, 14 proposed renames, 2 retirements, and one icon brief
  per visible script.
- `.forge/researcher/HANDOFF.md` — this file.

Nothing outside `.forge/researcher/` was created or modified.

## Read first

1. `.forge/researcher/panel-problems.md` **finding 2** — toggling any ability also runs the
   script's normal entry point, dialog and all. It is a defect, not a design choice, and it
   gates any redesign that puts a run affordance and a switch on the same row.
2. `.forge/researcher/proposed-structure.md` — the tree and the icon briefs are what the
   Scoper's mockup and icon set should be built against.
3. `scripts/wr_tools/main.rb:97-184` — `meta_of` and `cat_of`. Every proposal that adds a
   header directive (`@icon`, `@shelf`) lands here.
4. `scripts/make-icons.py` — where a new icon set is authored. One table, one generator; the
   plugin globs `ico-*.svg`, so adding icons needs no plugin edit.
5. `.forge/GOAL.md` — reconfirmed. This work is design and spec only; `main.rb` and
   `panel.html` are explicitly out of scope for rewriting this round, and nothing here
   rewrites them.

## Assumptions

- **assumed** — Audience labels (DAILY / OCCASIONAL) are inferred from what each script is
  for plus the pipeline in `CLAUDE.md` and `README.md`. Benton's actual click frequency was
  not measured and no usage data exists. The DEV-ONLY, LIBRARY and ONE-OFF labels are much
  firmer: those come from the scripts' own headers.
- **assumed** — `diag-favourites.rb` is dead. The preferences bug it diagnoses is documented
  as understood and fixed at `main.rb:206-224`, but Benton may still want it.
- **assumed** — `pendant-jig.rb` and `tube-drying-stand.rb` will be run again, so they are
  proposed as hidden-but-reachable rather than retired.
- **derived, not observed** — every behavioural claim about running code. There is no Ruby
  interpreter on this machine outside SketchUp (`CLAUDE.md`), so nothing was executed.

## Open questions

1. **Confirm the autorun defect in SketchUp** before building on it. Open the panel, flip
   the "Exploded" switch, and see whether the explode dialog appears. If it does, the finding
   holds and the fix is `$wr_no_autorun = true` around `main.rb:635` plus reconciling the
   two guard-global names (`$wr_no_autorun` vs `$wr_suppress_autorun`).
2. **Is `diag-favourites.rb` retired?** Benton's call.
3. **Should `csusb-rooms.rb` move to `clients/csusb/`** or stay in `scripts/` hidden?
4. **Are `booth-4260-s.rb` and `booth-96168-s.rb` safe to delete?** Both look fully
   superseded by `build-booth.rb`, but I did not verify that `build-booth.rb`'s dropdown
   actually offers MDL 4260 S and MDL 96168 S — check `wr-booth-data.rb` covers both before
   deleting.
5. **Does the ability/action merge into one row survive Benton's habits?** He may value the
   ABILITIES group as a "what is currently switched on in this model" status panel, which a
   merged list loses. Worth asking before the mockup commits to it.
6. **Should the Python tools get a listing in the panel** — read-only, "run these in a
   shell" — or stay out entirely? They are currently invisible while the README tells the
   user to run three of them.
