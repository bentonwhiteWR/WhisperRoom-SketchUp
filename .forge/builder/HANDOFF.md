# HANDOFF — IEP wall lift 1/16, and the IEP deck tiles (v1.6.22)

Tree left dirty on `main`, uncommitted, as instructed.

## Produced

| Path | What |
|---|---|
| `scripts/build-booth-components.rb` | `IEP_WALL_LIFT` 0.75 -> 0.6875 with both measurements and the open tension in the comment; `iep_deck` rewritten to reuse `WR_Deck.plan`; `flat_placement` now takes a tile rectangle + a half-turn flag; new `tile_rect` and `iep_half_turn?`; the build-report line no longer calls the lift unmeasured; the stale "tiling is a layout question this file has no answer for" comment replaced |
| `scripts/wr-deck.rb` | `ENH_NAME` regex added (and added to the `remove_const` reload list); `catalogue(dir, family = 'STD')`. **`build`, `seals`, `plan`, `tile`, `pick`, `order_cuts` untouched.** |
| `scripts/wr_tools/VERSION` | 1.6.21 -> 1.6.22 |
| `DEVLOG.md` | 2026-08-26 entry at the top |
| `.forge/builder/replay-iep-deck.py` | Python replay of the catalogue + tiling solver against the real folder and the real layouts; 8 assertions, all pass |
| `.forge/builder/library-listing.txt` | The folder listing the verification was done against (370 `.skp`) |

## Read-first
- `scripts/wr-deck.rb` — the comment above `ENH_NAME` says why the anchored digits must not be
  loosened. It is the only thing keeping `STDSS` and the 68 `ENH` wall panels out of the deck pool.
- `scripts/build-booth-components.rb` `IEP_WALL_LIFT` — records BOTH measurements (4872 E 0.75,
  6060 E 0.6875) and the three readings that fit them. Do not resolve it from the code.
- `.forge/builder/replay-iep-deck.py` section 5 — what the harness cannot see.

## Assumptions
1. **The `pick` hand rule (SIDE L low / SIDE R high) transfers to `ENH` parts.** Derived from
   name parity only: the `ENH` files carry the identical `SIDE L` / `SIDE R` suffixes and the
   identical size codes. Nobody has opened an `ENH` deck part.
2. **`bracket_edge` is meaningful on `ENH` deck parts.** The call measures the ENH part itself,
   so nothing is transferred — but if `ENH` trays carry no bracket line it returns nil and the
   positional fallback applies, which is the Standard behaviour for symmetric panels. Unverified.
3. **All tiles of one inner deck share a thickness**, so one z serves the deck. True of one
   sheet cut up; would show as a step in the build if ever false.
4. `IEP_TRAY_DROP` stays 0.75. Benton's "drop 1/16" was about the inner shell (walls); the tray
   is measured against the standard ceiling, not the walls.

## Open questions
1. **Is the 4872 E 1/16 high?** The only way to know is to re-probe it at 0.6875.
2. **Does the inner deck clear the inner walls,** now that the walls dropped 1/16 and the tray
   did not? Nobody has seen the two together on a tiled booth.
3. **Do the tiled inner deck panels need the end-for-end turn?** (assumption 2).
4. `.forge/GOAL.md` line 32–34 still says the IEP deck is refused and its tiling is
   "the only open question with no rule at all". That is now stale — left for the reviewer.
5. The 11.5 and 35.5 room-prouds are still unmeasured (deliberately untouched).
