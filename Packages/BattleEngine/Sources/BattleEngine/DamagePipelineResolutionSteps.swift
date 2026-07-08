import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Resolution steps

    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
                : 0
            state.itemBonus = state.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if state.qualifiesForAmbush,
               let runtime = context.roster.runtime(for: actor.combatant),
               !runtime.hasTriggeredAmbush {
                let ambushBonus = context.modifiers(for: sourceActorID).ambushBonusDamage
                if ambushBonus > 0 {
                    state.itemBonus += ambushBonus
                    context.roster.mutateRuntime(for: actor.combatant) { $0.hasTriggeredAmbush = true }
                }
            }
            if state.applyItemBonus {
                state.itemBonus += CombatReactionEngine.affixDamageBonus(for: state, in: &context)
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }

    static func applyHexmark(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        CombatReactionEngine.applyHexmarkIfNeeded(to: &state, in: &context)
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleEngineContext
    ) -> Int {
        var bonus = context.modifiers(for: sourceActorID).damageDealtBonus(for: keyword)
        if sourceActorID == context.roster.pet.id {
            bonus += context.heroModifiers.petDamageDealtBonus
        }
        return bonus
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.sourceActorID != nil else { return }
        let effects = state.activeEffects
        guard effects.contains(where: { if case .marked = $0.effect { return true }; return false }) else {
            return
        }

        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.markedBonusApplied = true
    }

    static func applyMitigation(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        var armorPct = effects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        armorPct += profile.passiveArmorPercent
        if let runtime = context.roster.runtime(for: state.combatant),
           runtime.mitigationShredUntilTick > context.tickCount {
            armorPct *= runtime.mitigationShredMultiplier
        }
        if profile.armorEffectivenessPenaltyPercent > 0 {
            armorPct *= max(0, 1 - profile.armorEffectivenessPenaltyPercent)
        }
        let toughnessPct = state.combatant.primaryStats.toughnessMitigationPct
        let combinedPct = max(0, min(1, armorPct + toughnessPct))
        if combinedPct > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - combinedPct)))
        }
    }

    static func applyItemReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let profile = context.modifiers(for: state.combatant.id)
        let reduction = profile.damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 + vulnerability)))
        }
        // Provisional until CriticalMultiply finalizes post-mitigation damage.
        state.buildupDamage = state.remaining
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        _ = context
        guard state.isCritical, state.remaining > 0 else {
            state.buildupDamage = state.remaining
            return
        }
        state.remaining *= 2
        state.dealt = state.remaining
        state.buildupDamage = state.remaining
    }

    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in effects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(state.remaining, buffer)
                state.remaining -= absorbed
                if absorbed > 0 {
                    state.damageEvents.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: state.combatant,
                        amount: absorbed,
                        keyword: keyword,
                        appliedEffectSummaries: [],
                        milestone: nil
                    ))
                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    effects[index] = ActiveEffect(
                        id: ae.id,
                        effect: newEffect,
                        remainingTicks: ae.remainingTicks,
                        sourceActorID: ae.sourceActorID
                    )
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            effects.remove(at: index)
        }
        state.activeEffects = effects
        if !shieldIndexes.isEmpty {
            context.roster.setActiveEffects(effects, for: state.combatant)
            state.damageEvents.append(contentsOf: CombatReactionEngine.afterBlockBroken(
                on: state.combatant,
                in: &context
            ))
            state.activeEffects = context.roster.activeEffects(for: state.combatant)
        }
    }

    static func applyTakeDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
        if lost > 0 {
            state.damageEvents.append(contentsOf: CombatReactionEngine.afterHealthDropped(
                target: state.combatant,
                in: &context
            ))
        }
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.markedBonusApplied, state.healthLost > 0 else { return }

        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        effects.remove(at: index)
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical
        ))
    }

    static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }
}
