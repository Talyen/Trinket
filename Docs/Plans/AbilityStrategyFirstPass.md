---
type: execution-plan
status: blocked
reason: Computer Use returns timeoutReached after host reboot; interactive visual inspection remains unavailable.
created: 2026-09-20
updated: 2026-09-20
expires: 2026-10-04
---

# AbilityStrategyFirstPass

## Objective

Implement the six approved ability revisions and icon-and-number combat feedback
without interrupting card play. Preserve unrelated in-flight work.

## Approved implementation

Six cards only: Shield Bash (2 Stun, spend 2 Block for 5), Ice Shot (2 Freeze or 5 Physical against Frozen, preserve Freeze), Sniff Out (partner next attack +3 Physical with caster fallback), Maul (3 Bleed or 3 Stun against Block), Stab (2 Physical, guaranteed critical at full enemy Health), Sunder (halve Block before 4 Physical).

Ordered operations and deterministic prepared outcomes share assessment rules. Floating results use icons/numbers; show Sniff Out and Leech preparations; preserve overhealing; zero fallback only for completely silent successful actions. No later rejected proposals.

## Verification and remaining work

- Implemented all six approved revisions, ordered operations, recipient-bound
  Sniff Out preparation, and icon/number feedback. Shared immutable definitions
  fix the reproducible nested-cast stack overflow. Block reservations prevent
  Shield Bash from spending Block already consumed by an interception.
- Final isolated handoff passed with `--final --keep-plan`: generation and
  idempotence, style, documentation, app compilation, boundaries, release-note
  validation, and artwork budgets.
- Package tests: BattleEngine 681, BattleFeature 169, Content 247, Core 99 passed
  (1,196 total; no failures or skips). Reports are under
  `.DerivedData/runs/agent-1/TestResults`, package run prefix `20260920T033540Z`.
- BattleFlowUITests: 2 passed, including tap/drag/inspect/cancellation/autoplay
  and retreat, run `ui-20260920T033404Z-17962-10290`.
- App build and managed install/launch succeeded on Trinket Agent 1, iOS 27.0.
  Inspection lease was released with `stop` and its process exited.
- **Remaining:** inspect the new floating feedback and rapid card play in both
  presentation modes through Computer Use. The tool returned server error -10005
  `timeoutReached` three times after the host reboot, including a kernel reset.
  No interactive visual verification is claimed. Archive this plan after that
  check; no additional implementation or product decision is pending.

## Scoped handoff command

```bash
./Scripts/handoff.sh --isolate --final --keep-plan --paths \
  Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift \
  Packages/TrinketCore/Sources/TrinketCore/EffectPresentation.swift \
  Packages/TrinketCore/Sources/TrinketCore/DamageCondition.swift \
  Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackPresenter.swift \
  Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackEffectPresentation.swift \
  Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackChipLabel.swift \
  Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackChipPresentation.swift \
  Packages/BattleEngine/Sources/BattleEngine/EffectHandlers/BuffHandlers.swift \
  Packages/BattleEngine/Sources/BattleEngine/Turns/BattleTurnEngine.swift \
  Packages/BattleEngine/Sources/BattleEngine/Turns/BattleTurnEngine+TalentPreparation.swift \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityOperation.swift \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityDescriptionFormatter.swift \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/Ability.swift \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityValidator.swift \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift \
  Packages/TrinketCore/Tests/TrinketCoreTests/CoreValueTypesTests.swift \
  Packages/BattleEngine/Sources/BattleEngine/Cards/BattleCardAssessment.swift \
  Packages/BattleEngine/Sources/BattleEngine/Cards/BattleCardAssessment+Resources.swift \
  Packages/BattleEngine/Sources/BattleEngine/Cards/BattleCardCombatEngine+CardResolution.swift \
  Packages/BattleEngine/Sources/BattleEngine/ResolvedActionFacts.swift \
  Packages/BattleEngine/Sources/BattleEngine/CombatResolution.swift \
  Packages/BattleEngine/Sources/BattleEngine/BattleActionEvent.swift \
  Packages/BattleEngine/Sources/BattleEngine/BattleAbilityRules.swift \
  Packages/BattleEngine/Sources/BattleEngine/BattleConditionEvaluator.swift \
  Packages/BattleEngine/Sources/BattleEngine/State/BattleState+EffectSummaries.swift \
  Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/CombatFeedbackEffectPresentationTests.swift \
  Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/AbilityStrategyFeedbackTests.swift \
  Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/CombatFeedbackPresenterTests.swift \
  Packages/BattleEngine/Tests/BattleEngineTests/AbilityEffectIntegrationTests.swift \
  Packages/BattleEngine/Tests/BattleEngineTests/KeywordCohesionMechanicsTests.swift \
  Packages/BattleEngine/Tests/BattleEngineTests/Cards/AbilityStrategyTests.swift \
  Docs/AgentContext/battle-actions.md \
  Docs/AgentContext/battle-presentation.md \
  Docs/Plans/AbilityStrategyFirstPass.md \
  Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv \
  Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityStorage.swift \
  Packages/BattleEngine/Tests/BattleEngineTests/ControlMeterIntegrationTests.swift
```
