# Builder HANDOFF — whisperroom-takeoff skill + skill distribution (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md`: this is Done-means 5 territory
(written protocol) plus the distribution gap Benton raised directly ("we need
to make sure this skill is shareable so we can get to other computers and
Gabe"). Prior slice's handoff preserved at
`.forge/builder/HANDOFF-eval-adversarial.md`. Plugin at **1.12.7**.

## Produced

| file | what |
|---|---|
| `skills/whisperroom-takeoff/SKILL.md` | New skill: floor plan -> takeoff.json -> checker -> review sheet -> build, short form. Two-paths rule (transcribe stated measurements vs pixel-scale estimation — opposite failure modes), chains-carry-parts with the 31 Aug example, never-invent, patch loop, machine facts. Names the checker's real limit: a lone wrong number with no chain validates clean (synthetic-clearwidth-trap). |
| `scripts/install-plugin.py` | Now installs repo `skills/` into `~/.claude/skills/` with the same manifest discipline as the bundled scripts (`.installed-by-wr.txt` in the dest; only manifest-listed skills ever removed; foreign skills kept and reported). Destination via `expanduser('~')` — no hardcoded laptop/desktop path. |
| `CLAUDE.md` | Hand-copy-the-skill instruction replaced by the installer; skills distribution documented under Working conventions; scale-estimation section now routes stated-measurement plans to the take-off pipeline. |
| `scripts/wr_tools/VERSION` | 1.12.6 -> **1.12.7** |
| `DEVLOG.md` | 1.12.7 entry |

## Read-first

1. `skills/whisperroom-takeoff/SKILL.md` — the skill itself.
2. `scripts/install-plugin.py` header — why skills are bundled now.
3. `reference/takeoff-format.md` — still the normative schema; the skill
   points at it, does not duplicate it.

## Assumptions

- **observed:** before this change `~/.claude/skills/` on this machine held
  only `launch` — the documented hand-copy of whisperroom-proposal had never
  happened. After `python scripts/install-plugin.py`: both skills present,
  manifest written, `launch` untouched (mtime unchanged), and both skills
  registered in the live session's skill list.
- **observed:** install logic proven first against a temp destination:
  idempotent re-run, stale (manifest-listed, repo-dropped) skill removed,
  foreign skill and its content preserved.
- **assumed:** Gabe's machine resolves `~` to his own profile via
  USERPROFILE — standard Windows; not verified on his machine. Next
  Update-now there will settle it.
- **reported:** the Update-now button runs git pull + install-plugin.py
  (CLAUDE.md); I did not exercise the button itself.

## Open-questions

1. Verify on Gabe's machine after his next Update-now that
   `~/.claude/skills/whisperroom-takeoff/` appeared.
2. The concurrent blind-trial Builder owns `eval/` and may hand off after
   me — its HANDOFF should preserve this one by name, per convention.
