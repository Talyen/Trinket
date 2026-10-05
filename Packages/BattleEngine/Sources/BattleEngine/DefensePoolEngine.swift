import Foundation
import TrinketContent
import TrinketCore

package enum DefensePoolEngine {
    static func steal(
        _ amount: Int,
        from target: Combatant,
        to actor: Combatant,
        abilityName: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0, context.roster.health(for: actor) > 0,
              !context.modifiers(for: target.id).triggers.sealedSarcophagus else { return [] }
        let block = blockPoints(in: context.roster.activeEffects(for: target))
        let stolen = min(block, amount)
        guard stolen > 0 else { return [] }
        set(block - stolen, on: target, in: &context)
        return context.applyBlock(stolen, to: actor, source: actor, abilityName: abilityName, amountBasis: .resolved)
    }

    package static func blockPoints(in effects: [ActiveEffect]) -> Int {
        effects.reduce(0) { sum, active in
            if case let .shield(_, buffer) = active.effect {
                return SaturatedArithmetic.saturatingAdd(sum, buffer)
            }
            return sum
        }
    }

    package struct ShieldPoolReduction {
        package let effects: [ActiveEffect]
        package let keyword: Keyword
        package let absorbed: Int
        package let broken: Bool
    }

    package static func reduce(
        _ amount: Int,
        in effects: [ActiveEffect],
    ) -> ShieldPoolReduction? {
        guard amount > 0,
              let index = effects.firstIndex(where: {
                  if case .shield = $0.effect {
                      return true
                  }
                  return false
              }),
              case let .shield(keyword, buffer) = effects[index].effect,
              buffer > 0
        else { return nil }
        let absorbed = min(amount, buffer)
        var updated = effects
        var broken = false
        if buffer - absorbed <= 0 {
            updated.remove(at: index)
            broken = true
        } else {
            updated[index] = ActiveEffect(
                id: updated[index].id,
                effect: .shield(keyword, buffer - absorbed),
                remainingTurns: 0,
                sourceActorID: updated[index].sourceActorID,
            )
        }
        return ShieldPoolReduction(effects: updated, keyword: keyword, absorbed: absorbed, broken: broken)
    }

    @discardableResult
    package static func add(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword = .block,
        sourceActorID: String? = nil,
        applyFightPacing: Bool = true,
        in context: inout BattleState,
    ) -> Int {
        guard !CombatTriggerEngine.preventsPurgedEffect(.shield(keyword, amount), on: target, in: context) else { return 0 }
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        let adjustedAmount: Int = if target.role == .enemy, context.roster.hero.isAlive,
                                     context.roster.hasAffliction(.burn, on: target) {
            CombatRounding.scaled(
                pacedAmount,
                multiplier: context.heroModifiers.triggers.burningEnemyBlockGainMultiplier,
            )
        } else {
            pacedAmount
        }
        let gainAmount = CombatGain.amount(
            adjustedAmount, current: blockPoints(in: context.roster.activeEffects(for: target)), cap: Int.max,
        )
        guard gainAmount > 0 else { return 0 }
        var updatedExisting = false
        context.roster.mutateRuntime(for: target) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: { $0.effect.kind == .shield }),
                  case let .shield(existingKeyword, existingBuffer) = runtime.activeEffects[index].effect
            else { return }
            let existing = runtime.activeEffects[index]
            runtime.activeEffects[index] = ActiveEffect(
                id: existing.id,
                effect: .shield(existingKeyword, existingBuffer + gainAmount),
                remainingTurns: 0,
                sourceActorID: existing.sourceActorID,
            )
            updatedExisting = true
        }
        if updatedExisting {
            return gainAmount
        }
        context.appendEffect(
            .shield(keyword, gainAmount),
            to: target,
            sourceID: sourceActorID ?? target.id,
            remainingTurns: 0,
        )
        return gainAmount
    }

    package static func set(
        _ amount: Int,
        on target: Combatant,
        in context: inout BattleState,
    ) {
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.removeEffects {
                if case .shield = $0.effect {
                    return true
                }
                return false
            }
        }
        if amount > 0 {
            context.appendEffect(
                .shield(.block, amount),
                to: target,
                sourceID: target.id,
                remainingTurns: 0,
            )
        }
    }

    @discardableResult
    package static func decayBlock(
        on target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return [] }
        let triggers = context.modifiers(for: target.id).triggers
        let retained: Int = if triggers.retainAllBlockBetweenTurns
            || triggers.retainAllBlockDuringDeathsDoor && context.roster.isDeathsDoorActive(for: target) {
            current
        } else if triggers.blockRetainsThreeQuarters {
            current / 4 * 3 + current % 4 * 3 / 4
        } else if triggers.blockRetainsHalf {
            min(30, current / 2)
        } else {
            current / 2
        }
        if retained != current {
            set(retained, on: target, in: &context)
        }
        guard retained > 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.retainedBlockThornsFlat > 0 {
            await events.append(contentsOf: CombatTriggerEngine.heroTalentThorns(
                to: target, source: target, amount: triggers.retainedBlockThornsFlat,
                name: context.modifiers(for: target.id).triggerAbilityName(
                    "retainedBlockThornsFlat", fallback: "Ironbriar",
                ),
                in: &context,
            ))
        }
        if triggers.retainedBlockGainThornsPercent > 0 {
            events.append(contentsOf: CombatTriggerEngine.applyBlockThorns(
                amount: retained,
                triggers: triggers,
                actor: target,
                abilityKey: "retainedBlockGainThornsPercent",
                in: &context,
            ))
        }
        return events
    }

    package static func halveBlock(
        on target: Combatant,
        in context: inout BattleState,
    ) -> Bool {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return false }
        set(current / 2, on: target, in: &context)
        return true
    }

    static func shouldIgnoreDodge(
        keyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let keyword, keyword == .holy, let sourceActorID else { return false }
        let srcTriggers = context.modifiers(for: sourceActorID).triggers
        if srcTriggers.holyIgnoresBlockAndDodge {
            return true
        }
        return false
    }
}
