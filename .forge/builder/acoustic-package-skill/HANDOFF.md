# HANDOFF — skill `whisperroom-acoustic-package` (1.77.1, 24 Sep 2026)

## Produced
- `skills/whisperroom-acoustic-package/SKILL.md`: loads the Audimute Acoustic Package into a booth in the
  live model. It covers the counts table, the parts, 10 ordered stages, the layout rules, the verification
  pass, 7 traps and the related tools. It points at `.forge/builder/peoplesspace-ap/` for the worked scripts.
- `scripts/booth-from-link.rb`: the `ac` refusal text and two comments now point at the skill. The old text
  said "Benton's decision, pending". The behaviour is unchanged: `ac` is still refused by name.
- `scripts/wr-accessories.rb`: the header comment was updated to match.
- `CLAUDE.md`: the installed-skills list names the new skill.
- `scripts/wr_tools/VERSION`: 1.77.0 -> 1.77.1.
- `DEVLOG.md`: new top entry.
- The installer was run on the laptop. `~/.claude/skills/whisperroom-acoustic-package/SKILL.md` is
  byte-identical to the repo copy (observed).

## Read-first
- `.forge/builder/peoplesspace-ap/HANDOFF.md`, the source of every fact in the skill.
- `WhisperRoomQuote/lib/ap-packages.js`, `AP_PACKAGES` (read with node; READ-ONLY). The table in the skill
  was copied on 24 Sep. The `cost` column was deliberately left out because it holds internal wholesale
  prices.

## Assumptions
- These facts are reported from the People's Space HANDOFF and were not re-measured:
  - `Audimute1x2`'s geometry starts about 7.9 in up inside its definition.
  - The fabric faces local -y.
  - The 1x2 is 24 wide by 12 tall as authored.
  The bridge was up, but with Benton's Tampa file open. Loading the part definitions there would have
  modified his model, so no probe was run.
- The rule for staging leftovers (on the floor beside the booth, outside the door clearance, named
  `<part> NOT PLACED`) is my generalisation. Benton only said "in and around the booth where applicable",
  and the skill tells the session to ask him about any exterior placement.
- The row heights and the 78.5 in clear height are People's Space numbers (96120 E, raised floor). The skill
  gives them as an example, not as a rule.

## Open-questions
- The skill has not been exercised on a booth. Its first real use is the test: check the gap, clash and
  fabric-direction checks against a fresh booth.
- Should `booth-from-link` eventually stage the AP kit itself? That would mean embedding `AP_PACKAGES` in
  `wr-accessories.rb`. For now the skill does the whole job by hand over the bridge.
- MDL 127 LP: its AP row exists, but whether its panels get placed is Benton's call.
