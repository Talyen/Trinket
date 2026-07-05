import Foundation
import TrinketCore
import TrinketContent

/// Passive enemy trait hooks that run during battle ticks and damage resolution.
package enum EnemyTraitEngine {
    package static func tickRegeneration(
        for combatant: Combatant,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.regenerationAmount > 0,
              profile.regenerationIntervalTicks > 0,
              context.tickCount.isMultiple(of: profile.regenerationIntervalTicks),
              context.health(of: combatant) > 0
        else { return [] }

        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.regenerationAmount,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: traitName(for: combatant),
                    keyword: .health,
                    displayAmount: profile.regenerationAmount
                )
            ),
            in: &context
        )
        return outcome.events
    }

    package static func applyShieldErosion(
        keyword: Keyword,
        to combatant: Combatant,
        context: inout BattleEngineContext
    ) {
        let profile = context.modifiers(for: combatant.id)
        guard profile.shieldErosionTicks > 0,
              profile.shieldErosionKeyword == keyword
        else { return }

        var effects = context.activeEffects(for: combatant)
        var didErode = false
        for index in effects.indices {
            guard case let .shield(shieldKeyword, buffer, _) = effects[index].effect else { continue }
            let remaining = max(0, effects[index].remainingTicks - profile.shieldErosionTicks)
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(shieldKeyword, buffer, effects[index].effect.durationTicks),
                remainingTicks: remaining,
                sourceActorID: effects[index].sourceActorID
            )
            didErode = true
        }
        guard didErode else { return }
        effects.removeAll { active in
            if case .shield = active.effect { return active.remainingTicks <= 0 }
            return false
        }
        context.setActiveEffects(effects, for: combatant)
    }

    package static func applyMitigationShred(
        keyword: Keyword,
        to combatant: Combatant,
        context: inout BattleEngineContext
    ) {
        let profile = context.modifiers(for: combatant.id)
        guard profile.mitigationShredDurationTicks > 0,
              profile.mitigationShredMultiplier > 0,
              profile.mitigationShredKeyword == keyword,
              var runtime = context.roster.runtime(for: combatant)
        else { return }

        runtime.mitigationShredUntilTick = context.tickCount + profile.mitigationShredDurationTicks
        runtime.mitigationShredMultiplier = profile.mitigationShredMultiplier
        context.updateRuntime(runtime)
    }

    package static func traitThornsDamage(
        damageTaken: Int,
        defender: Combatant,
        attackerID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: defender.id)
        guard profile.thornsPercent > 0, damageTaken > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return [] }

        let thornsAmount = max(1, Int(ceil(Double(damageTaken) * profile.thornsPercent)))
        let events = context.resolveDamage(
            DamageRequest(
                amount: thornsAmount,
                target: attacker,
                keyword: .physical,
                sourceActorID: defender.id,
                options: DamageOptions(isRetaliation: true)
            )
        ).events
        return events.map { event in
            ActionEvent(
                id: event.id,
                kind: event.kind,
                effectKind: .thornsTriggered,
                actorName: defender.name,
                abilityName: traitName(for: defender),
                targetID: event.targetID,
                targetName: event.targetName,
                amount: event.amount,
                keyword: event.keyword,
                appliedEffectSummaries: event.appliedEffectSummaries,
                milestone: event.milestone
            )
        }
    }

    package static func bonusHealAmount(
        ability: Ability,
        sourceID: String,
        in context: BattleEngineContext
    ) -> Int {
        guard ability.id == "grasping-vines" else { return 0 }
        return context.modifiers(for: sourceID).graspingVinesHealBonus
    }

    package static func bonusBleedPotency(
        ability: Ability,
        sourceID: String,
        in context: BattleEngineContext
    ) -> Int {
        guard ability.id == "hemorrhage" else { return 0 }
        return context.modifiers(for: sourceID).hemorrhageBleedBonus
    }

    private static func traitName(for combatant: Combatant) -> String {
        GameContent.positiveTrait(forCombatantID: combatant.id)?.name
            ?? GameContent.trait(forCombatantID: combatant.id)?.name
            ?? "Trait"
    }
}

private extension GameContent {
    static func positiveTrait(forCombatantID combatantID: String) -> CombatantTraitDefinition? {
        guard let enemy = enemies.first(where: { $0.id == combatantID }) else { return nil }
        return positiveTrait(for: enemy)
    }
}
