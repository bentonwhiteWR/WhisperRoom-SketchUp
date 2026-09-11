# HANDOFF — AUTO-SET side plate picks its side, a window first (1.57.0)

## Produced

- `scripts/wr-autoset.rb` — `az_for(plate_id, door_az, vent_az, side = 1)` honours a
  +1/-1 sign on `SIDE_PLATE` (`04-side`) only. New pure half: `WINDOW_RE` (`/WDO/i`),
  `SIDE_PLATE`, `SIDE_SKIP_TAGS`, `THIN_MAX`, `part_wall`, `side_normals`, `side_score`,
  `pick_side`, `side_sign`, `side_line`. New live half: `booth_parts`, `side_choice`.
  `tag_anchor` returns the door wall's LOCAL normal as a third element. `aim_plate`
  takes `side`; `apply` decides once per run and passes it to both aim calls;
  `plate_log` prints `side: door +90/-90 (bearing N deg) -- <why>` as the side plate's
  first log line.
- `scripts/rbtest-autoset.py` — 197 -> 217 checks, green (run). `sd1-sd20`. Four mutants
  run: unconditional +90 -> `sd12 sd15`; part count over window -> `sd6`; tie to -90 ->
  `sd4 sd7 sd11 sd18`; pick with no door -> red at `sd16` (a raise in this VM, which has no
  `NilClass#to_f`; real Ruby fails `sd16` by name).
- `.forge/builder/verify-autoset.rb` — UNRUN. Parses. New section 14 (`side.*`, 11 checks)
  and a third fixture booth `MDL 9903 E VERIFY` with a `W0  46Panel3236WDO` box on its
  door -90 face; `make_booth(..., window = true)`.
- `scripts/wr_tools/VERSION` 1.56.0 -> 1.57.0. `DEVLOG.md` entry.

## Read-first

- **Nothing Ruby here has been executed.** `rbparse.py`: 75 scripts + the harness parse.
  `rbtest-autoset.py` runs the pure half for real. `booth_parts` / `side_choice` / the
  `tag_anchor` third element / the log line inside a real `apply` are proven only by
  section 14 of the harness, which Benton runs from **File > New**.
- The rule: (1) more windows wins; (2) else more DISTINCT part names in that wall wins;
  (3) tie -> door +90, today's behaviour. A window on both sides falls to (2) then (3).
- Checks to watch, in order:
  1. `side.no_window_keeps_door_plus_90`, `side.no_window_is_a_tie_and_says_so` — booth 1
     unchanged. If these fail, every pre-1.57 booth moved.
  2. `side.booth_parts_sees_the_window_in_the_minus_x_wall`,
     `side.anchor_carries_the_local_door_normal` — the reading half on real bounds.
  3. `side.window_side_is_chosen`, `side.camera_stands_on_the_window_side` — the pick
     and the SAVED camera agree.
  4. `side.log_names_the_window_and_the_hand`, `side.log_line_sits_under_the_side_plate`,
     `side.same_side_on_a_re_run`.
- On a real generated booth, read the `side:` line in the AUTO-SET log. The
  distinct-part count includes the Enhanced inner shell's panels (`W0i ...`) and any vent
  duct cover on a side wall; both are symmetric in the usual case.

## Assumptions

- A window is a part whose definition or instance name matches `/WDO/i` — the convention
  `wr-overlays.rb#kind_of`, `booth-from-link.rb#summarise_placement` and the builder's
  instance naming (`W0  46Panel3236WDO`) already share. Hand-built booths
  (`booth-4260-s.rb` etc.) place no WDO-named part, so they tie and keep door +90.
- Parts live DIRECTLY in the booth container (depth 0). That is what
  `build-booth-components.rb` produces; a booth wrapped one level deeper reads as having
  no side parts and ties.
- The union box is good enough for the SIGN of a part's offset (as `tag_anchor` already
  assumes) and for the thin-span guard; the wall itself is read off the part's shape.
- `THIN_MAX = 0.34`: panels are 2-5 in thick on booths >= 48 in across; a floor deck's thin
  span is the booth's full width. Nothing sits between.
- The sign is re-derived from the chosen wall's MODEL bearing (`side_sign`) so a mirroring
  booth transformation cannot swap hands. Unobserved — no mirrored booth exists to test.

## Open-questions

1. Should `01-angled` and `03-high` swing to the same hand as the side plate? Left alone
   as instructed; they are three-quarter views, a different job. If Benton wants the set
   to agree on handedness, it is one line in `az_for` (apply `side` to every `:door` plate
   with a non-zero swing) plus `sd13` reversed.
2. A vent wall with no window counts as "more to look at" under rule 2 (vent panel + duct
   cover beat a solid wall), so on an E-vent booth the side plate turns toward the vent
   that `05-ventilation` already shoots. Is that wanted, or should VNT parts be skipped?
3. `ENH ...WDO` inner-shell windows count as windows on their own. They always pair with
   an outer WDO, so the count is 2 vs 0 rather than 1 vs 0 — same answer, but if a future
   booth had an inner-only window it would still be chosen.
