# HANDOFF — 2026-08-25, end of day

## Read this first

**The Enhanced 4872 is complete** — both shells, both decks, door — every part placed from a
measured number, verified against Benton's hand-corrected full-booth probe to 0.0001. Plugin
**1.6.18**. The full story is the 2026-08-25 block of `DEVLOG.md`; the durable lessons are
the two-shell model, the 6.5 inner run rule, and *measure with `probe-placement.rb`, never
infer from a screenshot*.

## Next: MDL 6060 E — "still pretty botched"

1. `git pull`. Rescan the panel. No reinstall needed — `wr_tools/` is unchanged.
2. **Build a booth from real parts → MDL 6060 E → Shell: Inner (IEP) only.** Read the warning
   block; it names the two panel widths (11.5, 35.5) whose room-proud is a default.
3. Correct the inner shell by hand, select it, run **Probe placement of what's selected**.
   The TSV lands at `P:/Sketchup/NewMasterComponentList/_placement-probe.tsv`.
4. Hand over the probe plus "X needs to go Y" for anything the probe cannot express.
5. The 6060's IEP deck is refused by name — `ENH 6060FL/CL` do not exist; the library has
   6042 + 6018 SIDE L/R pieces. Benton needs to say how those lay out. That is the only part
   of the 6060 with no rule at all.

What is different from the 4872, and therefore where to expect trouble: split runs on ALL
four walls (seals at E/W yaws never exercised), the untested `ASSIGN['MDL 6060 E']` E/W
reversal, and `ENH 11.5PanelSolid` being one of the four thin-box parts.

## Everything is on GitHub

`main`, clean tree. Tool scripts are read live from the repo.
