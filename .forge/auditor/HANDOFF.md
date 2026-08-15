# Auditor handoff — script audit before the SketchUp restart

## Produced

- `.forge/auditor/script-audit.md` — 7 ranked findings plus a clean-list. Scope was
  every script except build-room.* and wr_tools/ (another auditor holds those).

## Read-first

1. Finding 1 in the audit: `scripts/auto-dimension.rb:287-290` and `:342-343` —
   `start_with?('WR-Dims')` erases `WR-Dims-Booth` / `WR-Dims-Selection` dimensions.
   Fix is a two-line exact-match change; it is the one thing worth doing before the
   restart demo.
2. Finding 2: `scripts/proposal-scenes.rb:41` — `DIM_TAGS` predates the two new
   dimension tags; the five plates freeze stale visibility for them. Needs Benton's
   call on whether `WR-Dims-Booth` belongs ON in plate 02.
3. The clean-list at the bottom of the audit — undo-wrapping, overwrite guards and
   the dimension-booth arithmetic were all checked and are sound; don't re-audit them.

## Assumptions

- Nothing was executed in SketchUp (no Ruby outside it on this machine). All findings
  are derived from traced source except the two marked observed (node --check of the
  list-scenes JS; Python repro of the arch() rounding).
- merge-scenes pass 1 assumes `selected_page=` applies tag visibility synchronously —
  standard API behaviour, unverified here.

## Open-questions

- Plate 02: room chain (`WR-Dims`), booth catalogue dims (`WR-Dims-Booth`), or both?
  Benton's call; either way proposal-scenes must set the tag deliberately.
- Should the `to_f` gap/standoff fields get the parseLen treatment from build-room?
  All current instances are cosmetic, so this is a consistency choice, not a bug fix.
