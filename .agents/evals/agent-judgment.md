# Agent judgment scenario review

September 13, 2026. Baseline `ec07543f7997e0e1201a1e20c2272f2af3169074` was a clean checkout.
This is a same-session source and routing comparison, not an autonomous Astra
implementation trial. Product code is identical on both sides; only guidance,
enforcement, and their regression fixtures change. No task-success, elapsed-time,
or total-token improvement is measured. Existing Battle-effect and Shop criteria
were reviewed without building disposable game features.

## Routing comparison

The same five explicit paths were passed to `agent-context.sh --agent` and
`handoff.sh --isolate --dry-run` before and after. Every handoff command sequence
was identical, and every previously listed root/local guide and context card
remains discoverable. The router separates ownership constraints from detailed
behavior references; it does not silently narrow verification.

Counts below are Unicode characters. Available guidance counts deduplicate root,
nested guides, and listed context cards, excluding optional skills/knowledge and
implementation reads. They measure available references, not actual task reading.

| Route | Briefing before → after | Available guidance before → after |
|---|---:|---:|
| Battle effect | 681 → 824 | 11,964 → 12,351 |
| Shop price | 577 → 650 | 9,940 → 10,334 |
| Shared BattleState | 826 → 969 | 19,138 → 19,525 |
| Shared save store | 823 → 966 | 22,770 → 23,208 |
| Documentation tooling | 411 → 484 | 7,872 → 8,266 |

The paths are the existing `TimedDebuffHandlers.swift`, `ShopEncounterView.swift`,
`State/BattleState.swift`, Persistence's `PlayerSaveStore.swift`, and
`Scripts/check-docs.py`. Resolve their owner with the router for current runs.
The larger briefing makes the reading choice explicit; no size decrease or
percentage saving is claimed. Historical full-card counts are not comparable to
future actual section reads without recording those reads.

## Scenario comparisons

| Request or condition | Earlier constraint | Revised decision and retained protection |
|---|---|---|
| [Battle effect](eval-01-battle-effect.md) | Routed damage rules and registry parity; explanatory code rationale forbidden | Same effect owner, deterministic dispatch/expiry evidence, narrow visibility, and verification. A non-obvious expiry rationale may live beside the code; an ordinary comment does not trigger the directive skill. |
| [Shop price](eval-02-shop-flow.md) | Semantic design roles and visual evidence for both affordability states | Same design roles, purchase rules, identifiers, visual states, and routed checks. No extra test or broad screen review follows from a color-only change. |
| A compiler report correctly says build-failure but omits the preceding diagnostic | Raw logs require unknown classification or reporter escalation | Search the retained invocation log for the missing diagnostic, read bounded context, and test the hypothesis. Classification alone does not authorize a fix or establish its cause. |
| Retiring combat feedback jumps when interrupted | Blanket layout/recipe exclusion can reject a deterministic regression | Compare state immediately before and after interruption and verify expiration through the existing owner. Test the continuity contract rather than copied style values; visual feel still requires observation. |
| A shared navigation fix affects two distinct UI journeys | At most one exhaustive class, plus local guides implying package tests before handoff | Run the two relevant journeys and one routed handoff. Preserve lease isolation and full-suite restrictions; a passing package check is not interaction evidence. |
| A future save-recovery edit encounters the old startup proposal | Blocked plan proposes unavailable play and cites obsolete deletion behavior | Follow the current recovery contract. Preserve files, durable acceptance, reset/account isolation, and silent retry; closure of the old proposal is not new runtime validation. |

## Executable comparison

Using the same pinned SwiftLint binary and identical temporary Swift fixtures
against the baseline and revised configurations: ordinary rationale failed before
and passed after; a suppression without a reason failed both; a necessary scoped
suppression with a reason passed both. No product Swift changed.

## Executable acceptance

- Ordinary rationale passes the remaining invariant check; missing SwiftLint
  suppression reasons and undocumented concurrency escapes still fail.
- Directive annotations still select the directive skill; ordinary line, block,
  and documentation comments do not.
- Existing reference-routing checks preserve cross-concern discovery and the
  separation of ownership guidance from behavior references.
- Documentation containing formerly blacklisted phrases passes; broken links,
  invalid plan metadata, and missing UI registration continue to fail in the same
  fixture. Review remains responsible for semantic contradictions.

For an autonomous trial, use the controlled comparison in [README.md](README.md).
The reasoning above predicts the permitted decisions; it does not report actions
or runtime observations by independent evaluators.
