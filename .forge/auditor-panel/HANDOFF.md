# Auditor (panel integration) handoff

## Produced
- `.forge/auditor-panel/panel-audit.md` — full findings, ranked; coverage list at the end.

## Read-first
1. `panel-audit.md` findings 1 and 2 — the only two fixes worth making (finding 1 in
   `scripts/wr_tools/main.rb:876-877`, finding 2 is deleting the dots from
   `scripts/pendant-jig.rb:1` and `scripts/tube-drying-stand.rb:1`).
2. The engine section — SketchUp 2024 = Chromium/CEF 88, and every JS/CSS feature in
   `panel.html` clears it; the tightest is `inset` (needs 87).

## Assumptions
- CEF 88 for SketchUp 2024 is derived from the official release notes' upgrade list
  (2021.1 → 88, next 2025.0 → 128); one unsourced search digest claimed 112. Either
  version passes the feature check, so the conclusion does not hinge on it.
- `prefers-color-scheme` propagation into the HtmlDialog remains unverified anywhere;
  the failure mode is a light panel (benign), and the `data-theme` escape hatch exists.
- Nothing was executed in Ruby; all `main.rb` behaviour is traced, not run.

## Open-questions
- Runtime-only acceptance criteria (switch flip opens no dialog, 330 px layout, toolbar
  repaint after launch, dark theme) still need the restart to confirm.
- Whether finding 1 (rename drops the "...") should be fixed before or after tonight's
  restart — it only bites when a rename is performed.
