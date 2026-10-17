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
    ) {
        guard amount > 0, context.roster.health(for: target) > 0, context.roster.health(for: actor) > 0,
              !context.modifiers(for: target.id).triggers.sealedSarcophagus else { return }
        let block = blockPoints(in: context.roster.activeEffects(for: target))
        let stolen = min(block, amount)
        guard stolen > 0 else { return }
        strip(stolen, from: target, source: .init(actor), abilityName: abilityName, in: &context)
        context.applyBlockGain(stolen, to: actor, source: actor, abilityName: abilityName, amountBasis: .resolved)
    }

    package static func strip(
        _ amount: Int,
        from target: Combatant,
        source: CombatEventSource,
        abilityName: String,
        in context: inout BattleState,
    ) {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        let removed = min(current, max(0, amount))
        guard removed > 0 else { return }
        set(current - removed, on: target, in: &context)
        context.nextEvent(
            kind: .effect(.blockStripped), source: source, abilityName: abilityName,
            target: target, amount: removed, keyword: .block,
        )
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
        guard amount > 0 else { return nil }
        var remaining = amount
        var keyword: Keyword?
        var updated: [ActiveEffect] = []
        for active in effects {
            guard remaining > 0, case let .shield(shieldKeyword, buffer) = active.effect, buffer > 0 else {
                updated.append(active)
                continue
            }
            if keyword == nil {
                keyword = shieldKeyword
            }
            let removed = min(remaining, buffer)
            remaining -= removed
            if buffer > removed {
                var retained = active
                retained.effect = .shield(shieldKeyword, buffer - removed)
                updated.append(retained)
            }
        }
        guard let keyword else { return nil }
        let broken = !updated.contains {
            if case let .shield(_, buffer) = $0.effect {
                return buffer > 0
            }
            return false
        }
        return ShieldPoolReduction(effects: updated, keyword: keyword, absorbed: amount - remaining, broken: broken)
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
        guard context.roster.participant(for: target) != nil,
              !CombatTriggerEngine.preventsPurgedEffect(.shield(keyword, amount), on: target, in: context) else { return 0 }
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        let adjustedAmount: Int = if applyFightPacing, target.role == .enemy, context.roster.hero.isAlive,
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
        context.insertEffect(
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
        guard context.roster.participant(for: target) != nil else { return }
        // Replacing a retained pool is not a new gain, so buff prevention cannot erase it.
        let effectID = amount > 0 ? context.consumeNextEffectID() : nil
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.removeEffects { $0.effect.kind == .shield }
            if let effectID {
                runtime.activeEffects.append(ActiveEffect(
                    id: effectID, effect: .shield(.block, amount),
                    remainingTurns: 0, sourceActorID: target.id,
                ))
            }
        }
    }

    package static func decayBlock(
        on target: Combatant,
        in context: inout BattleState,
    ) async {
        let current = blockPoints(in: context.roster.activeEffects(for: target))
        guard current > 0 else { return }
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
        guard retained > 0 else { return }

        if triggers.retainedBlockThornsFlat > 0 {
            await CombatTriggerEngine.heroTalentThorns(
                to: target, source: target, amount: triggers.retainedBlockThornsFlat,
                name: context.modifiers(for: target.id).triggerAbilityName(
                    .retainedBlockThornsFlat, fallback: "Ironbriar",
                ),
                in: &context,
            )
        }
        if triggers.retainedBlockGainThornsPercent > 0 {
            CombatTriggerEngine.applyBlockThorns(
                amount: retained,
                triggers: triggers,
                actor: target,
                abilityKey: .retainedBlockGainThornsPercent,
                in: &context,
            )
        }
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
