# GOAL

## Mission
Close the gap between what the **booth builder portal** shows and what **build-a-booth /
booth-from-link** actually draws — foam, duct covers, and the remaining option parts —
and replace the ad-hoc V-Ray render step with a **single proposal-package skill** that has a
real UI.

## Done means
1. **Foam** is placed on the correct walls, portal-accurate:
   - Standard booth -> inside face of the **standard walls**.
   - Enhanced (IEP) booth -> **IEP (inner) walls only**. NOT also on the standard walls.
2. **Duct covers** placed portal-accurate: **bench walls** only; on an Enhanced booth, the
   **IEP walls**.
3. The remaining option parts build: **desks, MJP, elevated floors, caster plate**, plus
   anything else the portal emits that the scripts currently drop on the floor. A part the
   portal can emit and we cannot draw is either built or **named in the report** — never
   silently skipped.
4. **One V-Ray proposal-package skill**, driven from a panel button: lists every scene in the
   model, lets Benton tick which are V-Ray renders vs plain SketchUp exports, choose an output
   folder, define material swaps that apply only to the V-Ray pass, and writes
   `<SceneName>.png` / `<SceneName> render.png` into that folder.
5. **A simple interior-lighting step** so booth-interior renders stop reading as black holes.
   Minimalist. One button, sensible defaults, no lighting-designer UI.

## Now
**Plugin 1.7.8. The proposal-package V-Ray lane is RUNNING LIVE and is the active work.**
Live on UTHealthSciences Audiology (12 scenes, 5 render / 7 image). Image lane is good.
Render lane wrote five EMPTY 640x480 frames (observed) and is now being fixed.

**V-Ray renderer state vocabulary — OBSERVED LIVE 28 Aug 2026, question 2 in
`reference/vray-ruby-api.md` is now ANSWERED:**

| state | `sequence_ended?` | meaning |
|---|---|---|
| `:idleStopped` | true | stopped |
| `:idleInitialized` | true | cold, never started |
| `:preparing` | false | starting (reached ~440 ms after start) |
| `:rendering` | false | running |
| `:idleDone` | true | FINISHED — the only value that means a frame exists |

`IDLE_STATE = /idle/i` in `scripts/proposal-package.rb` matches three of the five and cannot
tell an unstarted renderer from a finished one. A hand render took 5m26s; `renderer.start`
DOES engage (observed 12:03:49).

Two live defects, both in `scripts/proposal-package.rb`:
1. Completion test must be `:idleDone` only, gated on having first SEEN a running state.
2. `model.pages.selected_page =` at line 599 is not settled before `start` — scene
   transitions leave the camera mid-flight, and the VFB renders the wrong view (Benton,
   observed 28 Aug).

Three things are Benton's, and no code should work around any of them:

1. **Author `scripts/vray-seeds/WR Interior Light.skp`** — V-Ray toolbar > Rectangle Light,
   24x48, facing down, drawn at the origin. `wr-drop-lights.rb` refuses by name until it exists.
2. **Rename `EFP96196.skp` -> `EFP96192.skp`** on the P: share. Until then a 96192 elevated
   floor is refused by name.
3. ~~Run `scripts/probe-vray.rb` cold and after a manual render~~ **DONE 28 Aug 2026** —
   the state table above is the result. Still unprobed: `save_vfb_image` arguments, and
   whether `start` engages on a renderer that has never rendered in the session.

Still to author (no `.skp` exists): EFP perimeter strips, bass traps, Audimute panels,
studio-light fixture. (The researcher also listed an "IEP floor pad"; the `ENH ...FL` mats
exist and the IEP deck already places them, so that row looks stale.)

**First live tests, in priority order:** build a **7272 E** and an **HX** booth and read the
landed-bounds print from every overlay; then the proposal-package acceptance checklist at the
end of `.forge/scoper/vray-proposal-package-spec.md`.

**Open work, named rather than half-built:**
- **Caster plate (`cs`) is NOT built** and refuses by name. The plate set tiles one-for-one
  with the floor deck and lifts the booth exactly 5" with the floor 0.739" into the tray
  (observed), but there is no portal-sourced plate-bottom figure and it is a vertical-datum
  change to the whole build. Step (`sp`) is refused with it.
- **Desk/MJP on Enhanced** are built on the **IEP room face** — the portal contradicts itself
  (top-down says IEP face, iso says standard face). Built the way the evidence leans; one
  constant to flip.
- Which authored face of Foam / Duct Cover / desk / MJP points roomward is **assumed** —
  one `FACE_ROOM` constant per family.
- `build-booth.rb` (the slab plan tool) has no foam/duct parity. Deliberate.


## Rules that still bind this work
- **Never invent a placement number.** Portal or measured geometry, or it does not ship.
- **No silent fallback.** A part we cannot resolve aborts or warns **by name**.
- **No regression on the Standard path**, and none on the Enhanced work closed at 1.6.32.
- `WhisperRoomQuote` and the `P:` share are **read only**. No prices in any artifact.
- Authoring new `.skp` components is Benton's job — report what is missing, do not fake it.
- Plugin edits land under `scripts/wr_tools/`; bump `VERSION`; a restart is required to reload.

## Out of scope
- Re-opening the Enhanced IEP shell mission (parked, see `.forge/GOAL-prev-iep-mission.md`).
- Roof-mounted vent. Authoring `.skp` components.

## History
2026-08-27 — Enhanced/IEP two-shell mission parked at plugin 1.6.32 with three items still
unmeasured (6060 E wall lift, inner-window end, perimeter-seating fix on the inner deck).
Full text preserved at `.forge/GOAL-prev-iep-mission.md`.
