# HANDOFF — WAJMBAD (wide-access jamb adapter), 2026-09-21 (plugin 1.73.0)

Nothing here has been run in SketchUp. No `ruby.exe`, no SketchUp on this machine. Every
claim is labelled observed / derived / reported / assumed.

## Produced

| file | change |
|---|---|
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb` | `WAJMBAD_COMP` / `_L` / `_R` constants; `WAJMBAD_FLIP_SIDE = nil`; `wajmbad_plan(spec, assign, cfg, shell)`; pass-1 name hook on `p[:k] == 'seal'`; pass-2 flip block after the `IEP_SEAL_YAW` turn; notes carried into `warn`. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr_tools\VERSION` | 1.72.1 → **1.73.0** |
| `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` | 1.73.0 entry |

Untouched: `wr-booth-data.rb`, `booth-from-link.rb`, `wr-deck.rb`, the `WhisperRoomQuote`
repo, the `P:` share.

## Read first

1. The `WAJMBAD_FLIP_SIDE` comment block (beside `IEP_SEAL_YAW`) — what the flip is, what it
   is not, and why the axis is the wall normal.
2. `wajmbad_plan` — the straddle rule and the from-outside L/R rule, with the 102102 E numbers.
3. `.forge/fixer/HANDOFF-part-orientation.md` — the handedness history this deliberately does
   not repeat (no mirror, no per-part exception without a named constant).

## What a build prints (derived from the code, not seen)

- Header, per adapter: `WAJMBAD  S-seal0i -> ENH WAJMBAD  (R of S0i, read from outside) -
  REPLACES the IEP mid-wall seal beside the wide-access door` (`_HX` shown on HX builds).
- Header, per note: `WAJMBAD  <note>` — ambiguity, override, or the companion-panel line.
- Pass 2 row: `S-seal0i ENH WAJMBAD  WAJMBAD R of the door, placed as authored, no flip`.
- End-of-build flagged list: `S-seal0i ENH WAJMBAD: WAJMBAD orientation is NOT FIT-TESTED ...
  WAJMBAD_FLIP_SIDE = nil ...` and every plan note prefixed `WAJMBAD`.

## Assumptions

- **ASSUMED: the WAJMBAD sits where the seal it replaces sat.** It is centred in the seal slot
  like any inner seal, gets `IEP_SEAL_YAW`, and its measured width is reported in the FIT column
  but never moves the wall (a seal takes `IEP_SEAL_W` in `rebalance_walls` regardless).
- **ASSUMED: the standard part's as-authored orientation mates ONE side correctly.** Which one
  is unknown; `nil` flips neither. Derived, not measured: the flip that can move the jamb leg is
  a 180° turn about the wall normal.
- **ASSUMED: the part classifies as a 79.5 in (HX 89.5) wall part.** If `classify` finds no such
  axis the build refuses with "not a wall part" — that is the existing gate doing its job, and it
  means the WAJMBAD needs its own `part_height` rule.
- **DERIVED, checked by hand on 8 cases (offline replay against `wr-booth-data.rb`):** L/R from
  outside = high run end is right on S/E, low end on N/W. Mirror of `wr-overlays`
  `port_run_pos`'s inside-view rule.
- **REPORTED (Benton), not verified in geometry:** substitution not addition; standard unhanded,
  HX handed by holes; WA door only.
- **OBSERVED:** the three `.skp` names on the share; the seal polygon extents in the data
  (S0i 4.25..39.75, S-seal0i 36.875..49.125 on 102102 E).

## Open questions — each one needs a built booth or Benton

1. **Which side flips.** Build an Enhanced booth with a WA door, look at the adapter's jamb leg
   from inside. If it faces away from the door, set `WAJMBAD_FLIP_SIDE` to that side's letter
   (L/R from outside). If it faces the door on the side built, build one with the door on the
   other hand to see the other side.
2. **Does the Z absorb the 2.5 in companion?** Beside a 44.5 in ENH WA door the inner wall
   closes on `ENH 2.5Panel` (booth-from-link). Benton's "the IEP wall would actually be too
   small" reads either way. Today the sliver is still placed and the console says so.
3. **Mid-wall door: which jamb.** Two seals straddle such a door; nothing is placed and the
   build flags it. `cfg['wajmbad'] = '<seal id>'` forces one until the rule is known.
4. **HX L/R.** Chosen by side from outside per Benton's convention. Confirm the R_HX file's holes
   land on the R side of a built HX booth — the file's own handedness has not been opened.
5. **Standalone (non-link) builds cannot pull it.** `ASSIGN` never names a WA door, so only
   `booth-from-link` (whose `component_for` emits `ENH RightWADoor` / `LeftWADoor`) reaches this
   path. That is the existing state of WA doors, not new.
