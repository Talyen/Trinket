# PURPOSE — ios-simulator

## Why this skill exists
Simulator misuse (`booted` alias, `shutdown all`, killing foreign Xcode/Simulator processes, colliding slots) flakes local verification and interrupts human sessions.

## Knowledge that motivated it
- `Docs/Platform/SimulatorOperations.md` — isolation rules and `run-env.sh` lease pool
- `Docs/AgentContext/ci-diagnostics.md` — never kill foreign processes

## When introduced
2026-08-28 — trimmed from 164-line command catalog to isolation-focused guidance; full `simctl` reference stays in `SimulatorOperations.md`.
