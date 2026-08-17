# GOAL

## Mission
Add ceiling seam seals to the deck build. A ceiling seam seal lands directly in the joint
between two ceiling panels and registers into a slot in them. Today `wr-deck.rb` places the
CL and FL panels and nothing else — the joint is left bare.

## Done means
- A spec that states, from measured geometry rather than inference, where a ceiling seam seal
  sits in the joint, how it registers into the slot, which seal part a given booth takes, and
  how it is oriented. Guessing any of those is what the placement code's own history warns
  against.
- The seal-selection rule is general, driven by the booth's cross dimension and the seal
  library, not a per-model table.
- A first build on the **MDL 7272 S**, chosen because it tiles 48 + 24 so its ceiling joint is
  off-centre at 48" from the low end. A placement bug that defaults to the midpoint is visible
  there and invisible on the 7296, whose joint is the midpoint.
- The 7296 and 6084 named as the second and third tests, since both tile evenly.
- No regression: every deck panel that places correctly today still does. Seals are additive.

## Now
One Scoper. It cannot open the binary `.skp` files — there is no Ruby outside SketchUp on
this machine — so its first deliverable is a probe Benton runs in SketchUp to return the slot
and seal geometry, and the spec is written against what comes back. Marking an unmeasured
number as measured is the failure mode to avoid.

Established already (observed 2026-08-17): ceiling seals in the library are `STDSS CL5`,
`STDSS CL6`, `STDSS CL7`, `STDSS CL8` and `STDSS 8.5CL`. The deck catalogue's `NAME` regex
requires `STD` + digits, so `STDSS …` never enters the parts pool — seals need their own
selection and placement path, unlike the 7248 SIDE R parts which the existing glob picked up
for free.

## Out of scope
- Floor seam seals. `STDSS FL5` and `STDSS FL8.5` are missing from the library and whether
  floors need seals at those widths is an open question — do not fold it into this.
- Wall seam seals (`MidWallSeamSeal`, `CornerSeamSeal`). Those belong to
  `build-booth-components.rb`, which is not in scope.
- Changing how CL and FL panels are picked or oriented. That path is confirmed working as of
  today and is not to be touched.
- The `WhisperRoomQuote` repo — read only, never write.
- Prices. Nothing from `models.json` goes into any artifact.

## History
2026-08-17 — `STD7248CL SIDE R` and `STD7248FL SIDE R` did not exist in the library, so the
7296 fell back to two left-hand panels. Benton authored both; `wr-deck.rb` picked them up with
no code change, verified by replaying its `catalogue` and `pick` logic against the real
folder. Earlier the same day, `STD7224CL/FL SIDE R` came out flipped — root cause was the
master files saved out of alignment, not the script. Benton re-saved both; confirmed correct.

2026-08-16 — `auto-dimension.rb` container-transform fix shipped (`e90321d`). Still unrun in
SketchUp; two open questions in `.forge/fixer/root-cause-transform.md`.
