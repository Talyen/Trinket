---
type: execution-plan
status: complete
created: 2026-08-27
updated: 2026-08-27
expires: 2026-09-10
---

# BattleAndToolingSimplification

## Objective

Make healing and automatic combat behavior correct and easier to reason about, then remove two sources of noisy or misleading developer feedback: obsolete Swift Testing syntax and fragile static-analysis log selection.

## Plan

- [x] Record the baseline and relevant constraints.
- [x] Consolidate Leech into the canonical healing path, apply healing reduction once, and transfer only true Blood Link overflow to a living Companion.
- [x] Replace auto-battle polling with state-driven single-step work and revalidate state after tap-lift presentation.
- [x] Migrate obsolete `try #expect` syntax and add a repository ratchet.
- [x] Make SwiftLint analysis select one current app build log, fail clearly when absent, and cover the script behavior.
- [x] Add or extend only consequential coverage for each changed semantic owner.
- [x] Run focused checks and final path-scoped verification.
- [x] Mark the work complete, move this file to `Docs/Plans/Archived/`, and report verification.

## Notes

Blood Link’s approved behavior is: heal the hero first, transfer only actual Leech overflow to a living Companion, and discard any remainder the Companion cannot receive. Durable testing and script policy live in their canonical documentation owners.
