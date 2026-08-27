# GOAL

## Mission
Make the booth-building scripts build **Enhanced (IEP)** booths correctly — a Standard outer
shell plus an inner shell placed inside it — model by model, each one closed by a measured
probe rather than a screenshot.

## Done means
- `booth-from-link.rb` builds an Enhanced booth from a real Enhanced share link, verified by
  diffing the script's RAW PACK / placement printout against the portal's "YOUR BOOTH" panel.
- **No silent Standard fallback.** A missing or unrecognised `ENH` part aborts by name.
  `ENH_MISSING_ABORTS = true` stays.
- Every part placed from a **measured** number. `probe-placement.rb` is the instrument;
  a screenshot is not evidence.
- No regression on the Standard path.

## Now
**Plugin 1.6.32 is shipped, pushed, and confirmed good in a built model.** Both probes are done,
so nothing is blocked on data any more. Start on the next machine with `git pull` ->
`python scripts/install-plugin.py` -> **RESTART SketchUp** (VERSION lives under `wr_tools/`; a
rescan will not reload a module's constants).

The next session picks up **the three unmeasured things, in this order**:

1. **`MDL 6060 E`, Shell = Both — the wall-lift reading.** The `IEP_WALL_LIFT` default of
   **0.7500 is still a guess covering 22 layouts**, and the 6060 E's **0.6875** is Benton's eye
   only, never probed. Probe the inner deck and hand back the TSV. A fourth reading of 0.6875
   moves the default there; 0.7500 leaves the 6060 E the lone outlier. This same build also
   closes the inner deck's end-for-end turn question, which no harness can answer. Expect ~1/8"
   on `N0i`/`E1i` — the room-proud figures for the **11.5** and **35.5** widths are still
   unmeasured, fall through to `IEP_ROOM_PROUD_DEFAULT`, and the build warns by name. Expected,
   not a defect.
2. **A booth carrying an INNER WINDOW — which end does it sit at?** Every `ENH ...WDO` panel is
   **predicted** end for end and was deliberately left unchanged: no in-model evidence exists and
   guessing there is the mistake 1.6.21 made. `guess_component` has no WDO branch, so it needs an
   explicit assignment (e.g. `'W1i' => 'ENH 41.5Panel3236WDO'`) or a portal link that carries
   one. The wider question is still open and may have no code answer at all: **is the window's end
   fixed by the model, or does the assembler put it where the customer asks?**
3. **Decide whether the 1.6.31 perimeter-seating fix should reach the ENHANCED inner deck.**
   It does not today — `build-booth-components.rb` runs its own placement loop and never calls
   `WR_Deck.build`. `ENH 8418 FL` measures 17.9375 against a nominal 18, so an inner floor ending
   on it carries the same gap the Standard floor had. The 84126 E confirmation makes this
   decidable now.

**Two defective component files are Benton's to author, and the code must not work around them:**
`RightSideVent_CP_HX.skp` (HX rework never applied — identical to its non-HX twin, 1 entity where
the correct mirror has 3) and `STD7224FL SIDE R.skp` (measures 37.9375 on a name saying 24, which
makes `MDL 7272 S`'s floor ~14 in wrong at the high end). Ignore that error when checking a 7272 S.

## Settled — do not re-derive
Full reasoning is in `DEVLOG.md` under `SESSION CLOSE - plugin 1.6.32` and the named write-ups.

- Two-shell model; inner run rule 6.5; `IEP_TRAY_DROP = 0.75`; `IEP_DOOR_IN = 0.5`;
  room-proud per family/width in `IEP_ROOM_PROUD`; `SEAL_FL_DATUM_LIFT = -1.1250` (measured).
- Deck contact is the true face, not its 1/64 bucket. The lip is **Enhanced-only**. Deck seam
  seals are **Standard-only**. The `ENH` deck library is **complete — nothing needs authoring**.
- Rebalance an `ENH` wall from its **module width off the name**, never its bounding box.
- **Deck tile stations are NOMINAL; seating is MEASURED**, and the last tile of a multi-tile run
  seats against the far perimeter (1.6.31).
- **Tray orientation is measured per part** — four `ENH` ceiling parts are authored upside down
  (1.6.30). **Standard ceilings split into two authoring conventions** — 17 are pre-inverted and
  carry their bracket line at the opposite end from their floor twin (1.6.31).
  `.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md`.
- **The inner vent's half turn is measured per part; `IEP_VENT_YAW` is gone** (1.6.32). The turn
  is a **per-family authoring convention and MUST NOT be generalised** — the inner DOOR family is
  all Y-running and wants the opposite. `.forge/fixer/ROOTCAUSE-iep-vent-yaw-2026-08-26.md`.
- **There is no name-level width-axis rule.** Best case 174/194 wall parts; placement must read
  measured geometry. `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`.
- **A Ruby module keeps its constants until restart** — but that is a reason to *qualify* a
  report, never to *dismiss* one. Using it to dismiss the 96144 E report was the session's
  biggest error. Never generalise a convention from a sample: the `_HX` axis "convention" came
  from four pairs, and across all 99 the axis flips both ways with 56 not flipping at all.
- Not to be authored: ramp doors on Enhanced, the 2.5" panel, vent option variants, side vents.

## Out of scope
- Furniture, accessories, roof-mounted vent. Component art / image exports.
- Authoring new `.skp` components — I report what is missing; Benton authors it.
- `WhisperRoomQuote` repo and the `P:` share: **read only**. No prices in any artifact.
- Changing how Standard booths resolve or place. The 2026-08-26 exception for two named
  defects was spent in 1.6.31 and is closed; it was never a general licence.

## History
2026-08-26 — **Session closed at 1.6.32, and three fixes were confirmed in a built model** — the
first such confirmation the mission has had. `MDL 84126 E` closed 1.6.31's two Standard-deck
defects and 1.6.30's tray orientation; a rebuild closed 1.6.32's vent yaw. Everything else that
shipped that day was verified by offline harness and parse only.
2026-08-26 — Both owed probes finally ran against a reachable `P:`: all 370 parts, and
`probe-levels.rb` with a blank filter, giving `_face-levels.tsv` its first 1,761 `ENH` rows.
2026-08-25 — **MDL 4872 E complete.** Both shells, both decks, door; every part from a measured
number, agreeing with a corrected full-booth probe to 0.0001.
2026-08-25 — Bulk scene naming and the list-scenes search fix (v1.6.20), both **unrun in
SketchUp**. Separate from this mission.
2026-08-24 — `ENH` component library verified clean: 112/112 single-shell, 0 failed. Ceiling
seam seals done.
