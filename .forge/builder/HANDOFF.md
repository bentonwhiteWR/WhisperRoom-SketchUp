# HANDOFF — `IEP_WALL_LIFT` becomes per-booth (v1.6.28)

**UNRUN IN SKETCHUP.** There is no Ruby on this machine outside SketchUp, so no line of this
has been executed against real geometry. Everything below that is evidence is named as such.

## Produced

| file | what changed |
|---|---|
| `scripts/build-booth-components.rb` | `IEP_WALL_LIFT` is now a frozen per-booth hash + `IEP_WALL_LIFT_DEFAULT = 0.7500`; new `iep_wall_lift(key)` / `iep_wall_lift_measured?(key)`; `part_top_z(part, hx, lift)` takes the lift as a required third argument; `build_booth` resolves it once from `key`; the build-report line and the warning block both name the figure and whether it was measured. |
| `scripts/build-booth.rb` | **comment only.** `IEP_LIFT = 0.3125` is unchanged; its "kept in step with IEP_WALL_LIFT" note was a lie once the other file grew a table, so the note now says it is in step with nothing. |
| `scripts/wr_tools/VERSION` | 1.6.27 → 1.6.28 |
| `DEVLOG.md` | new top entry under 2026-08-26 |
| `.forge/builder/replay-iep-wall-lift.py` | **new**, 105 checks. Parses the table out of the real `.rb` rather than restating it. |

Nothing is committed. The tree is dirty on purpose.

## The table, and where each row came from

```
MDL 4872 E    0.7500   Benton's eye 2026-08-25, then a probe of his corrected
                       full booth agreeing to 0.0001 (v1.6.17). PROBE-BACKED.
MDL 6060 E    0.6875   Benton's eye 2026-08-26. No probe.
MDL 102144 E  0.7500   Benton 2026-08-26, built at 0.6875, "1/16 too low". No probe.
              -------
default       0.7500   two of three, and one of those two is the probed one.
```

**No rule was derived from three points.** Benton's own scope sentence is *"Im not sure about
any others."* The other 22 Enhanced layouts take the default and the build names the booth by
key in its warning block when it does — the `IEP_ROOM_PROUD` idiom, copied on purpose.

## Read-first, if you pick this up

1. The `IEP_WALL_LIFT` comment block in `scripts/build-booth-components.rb` (~line 90–160). It
   carries all three quotes and why 0.7500 is the default rather than a law.
2. `IEP_VENT_YAW`'s comment in the same file. **A Ruby module keeps its constants until
   SketchUp restarts.** Before any report of "the shell is 1/16 off" becomes a fourth row here,
   establish that SketchUp was restarted after the figure it was built at shipped. A constant
   was moved on exactly that false premise earlier today and had to be reverted.
3. `.forge/GOAL.md` — its "THE ONE OPEN QUESTION: is the wall lift global or per-booth?" section
   is now **stale**. It says "No per-booth table was invented. One constant, one word to
   revert." That is no longer true. I did not edit GOAL.md; it is Benton's file.

## Why the lift is an argument and not module state

`part_top_z` did not know which booth it was building. Two shapes were available: pass the key
and look it up per part, or resolve the number once and pass it. I passed the **number**,
resolved once in `build_booth` from the layout key it is already handed, because the warning
about an unmeasured booth then fires once per build rather than once per inner part, and the
lookup does not run 40 times for an answer that cannot change mid-build.

The third argument is **required**, no default. A module-level "current booth" would be
inherited by the next build in the same SketchUp session — this process is long-lived and the
module outlives a build. A required argument cannot go stale. There is exactly one call site
(`nominal = part_top_z(p, cfg['hx'], lift)`), asserted by the harness.

## Assumptions — flagged, not hidden

- **`assumed`** — 0.7500 is right for the 22 booths nobody has looked at. This is the whole
  residual risk of the change and it is why the build warns by name.
- **`reported`** — the 6060 E and 102144 E figures are Benton's eye on a built shell. Only the
  4872 E has a probe behind it, and that probe measured his *corrected* model, so it proves the
  code matches his hand placement, not that his hand placement was right.
- **`derived`** — 102144 E = 0.6875 built + 1/16 reported low = 0.7500.
- **`observed`** — all 25 `E` layouts exist in `wr-booth-data.rb`; the harness enumerates them
  off the real file, not a list I typed.

## Open questions

1. **Which booth falsifies the default?** Any Enhanced booth other than those three. A fourth
   reading of **0.6875** would say the 4872 E's probe measured a hand placement that was itself
   1/16 out, and the default belongs at 0.6875. A fourth reading of 0.7500 leaves the 6060 E as
   the lone outlier and worth re-checking on a restarted SketchUp.
2. **Is the 6060 E's 0.6875 real, or is it the v1.6.21 restart problem again?** It has never
   been probed and it is the only row that disagrees with the default.
3. `build-booth.rb`'s `IEP_LIFT = 0.3125` has never been re-measured for the path that uses it.
   Out of scope here; flagged in its comment.
4. Room-proud for the **11.5** and **35.5** widths is still unmeasured and still warns by name
   (unchanged, pre-existing).

## Verification actually performed

- `python scripts/rbparse.py` → **52 files parse**, real CRuby 3.2 DLL. (`rbcheck.py` was not
  used and is not evidence.)
- `python .forge/builder/replay-iep-deck.py` → **ALL CHECKS PASS** (31 assertions), observed
  once early in the session. It was re-run at the end and reported *"cannot reach
  P:\Sketchup\NewMasterComponentList"* — **the mapped network drive dropped mid-session, it is
  not a regression.** That harness reads only `wr-deck.rb` and `wr-booth-data.rb`, neither of
  which this change touches. Re-run it once P: is back.
- `python .forge/builder/replay-iep-wall-lift.py` → **ALL 105 CHECKS PASS**.
- Not verified: anything requiring SketchUp. No booth was built.

## What Benton should build to confirm

1. `git pull`, `install-plugin.py`, **restart SketchUp** — VERSION lives under `wr_tools/`, so a
   rescan is not enough, and the restart is what makes the next report evidence.
2. Build **MDL 4872 E, Shell = Both**. The console should read
   `underside lifted 0.75" - MEASURED ON THIS BOOTH`. Confirm the inner shell still looks right —
   this is the regression check on the booth that was already closed.
3. Build any booth **not** in the table — **MDL 9696 E** or **MDL 7272 E** is a good pick, mid
   size, nothing unusual. The console should read `underside lifted 0.75" - DEFAULT - NOT
   MEASURED ON THIS BOOTH` and the warning block at the end should name the booth by key. Look
   at the inner shell and say the number. **That is the reading that falsifies or confirms the
   0.7500 default**, and it is the one measurement this change is asking for.
