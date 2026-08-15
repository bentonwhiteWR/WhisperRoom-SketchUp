# Fixer handoff — scene-range parser, audit finding 4

A second fixer worked in this folder earlier; `.forge/fixer/HANDOFF.md` is theirs
(WR-Dims tag ownership, proposal plate tags, rename dots) and is untouched here.

## Produced
- `scripts/export-scenes.rb` (lines 103-129), `scripts/save-scene-components.rb`
  (155-181), `scripts/angled-component-art.rb` (307-333),
  `scripts/elevation-export.rb` (188-214) — the range branch of `select_pages`
  now clamps to `1..pages.size` before indexing, so no user input can reach a
  negative array index, and the part of the range that fell outside the list is
  pushed onto the existing `misses` array instead of being dropped.
- `scripts/export-component-art.rb` (176-196) — same fix, written to that file's
  different parser shape: it uses an if/elsif statement with per-branch `misses`
  pushes rather than the `hit = if ...` expression the other four use.
- `.forge/fixer/repro-scene-range-zero.py` — runnable proof. Old and new parsers
  side by side over twelve tokens; asserts and exits non-zero on failure.

## Read-first
- `.forge/auditor/script-audit.md`, finding 4 — the defect this fixes. Its
  suggested fix (`a = 1 if a < 1`) stops the wrap but keeps the silent drop; the
  fix applied here also reports the out-of-range part.
- `.forge/fixer/repro-scene-range-zero.py` — re-run it before touching any of the
  five parsers again.

## Assumptions
- No Ruby interpreter exists outside SketchUp on this machine, so **none of these
  five scripts has been run**. The fix was proved in a Python reimplementation
  that relies on Python and Ruby agreeing that `list[-1]` is the last element,
  which they do. `scripts/rbcheck.py` passes on all five, but it is a bracket and
  `end` balance check, not a Ruby parser, so it proves very little.
- The wording of the new miss entries ("nothing matched 0-0", "nothing matched
  9-999") reuses each file's existing `note += "  — nothing matched ..."` line
  rather than adding a second channel. Reads correctly, but nobody has seen it in
  the real Ruby Console yet.

## Open questions
- The audit's side nit on `scripts/angled-component-art.rb:336` is still open:
  that file dedupes picked scenes by name (`picked.uniq { |p| p.name }`) where
  the other four dedupe by object, so two identically named scenes collapse to
  one there only. Left alone — it is a separate defect and was not in scope.
- No `DEVLOG.md` entry: other agents are editing the tree concurrently and this
  assignment scoped the fixer to five files.
