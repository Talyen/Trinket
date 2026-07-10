import Foundation
import TrinketContent
import TrinketCore

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
              context.roster.health(for: combatant) > 0
        else { return [] }

        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.regenerationAmount,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: traitName(for: combatant, in: context),
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

        var effects = context.roster.activeEffects(for: combatant)
        var didErode = false
        for index in effects.indices {
            guard case let .shield(shieldKeyword, buffer) = effects[index].effect else { continue }
            let eroded = max(0, buffer - profile.shieldErosionTicks)
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(shieldKeyword, eroded),
                remainingTicks: 0,
                sourceActorID: effects[index].sourceActorID
            )
            didErode = true
        }
        guard didErode else { return }
        effects.removeAll { active in
            if case let .shield(_, buffer) = active.effect { return buffer <= 0 }
            return false
        }
        context.roster.setActiveEffects(effects, for: combatant)
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
        context.roster.update(runtime)
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
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: thornsAmount,
                target: attacker,
                keyword: .physical,
                sourceActorID: defender.id,
                options: DamageOptions(applyDodge: false, isRetaliation: true)
            )
        )
        let events = outcome.events.map { event in
            ActionEvent(
                id: event.id,
                kind: event.kind,
                effectKind: .thornsTriggered,
                actorID: defender.id,
                actorName: defender.name,
                abilityID: event.abilityID,
                abilityName: traitName(for: defender, in: context),
                abilityTier: event.abilityTier,
                targetID: event.targetID,
                targetName: event.targetName,
                amount: event.amount,
                keyword: event.keyword,
                appliedEffectSummaries: event.appliedEffectSummaries,
                milestone: event.milestone
            )
        }
        if events.isEmpty, outcome.healthLost > 0 {
            return [context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: defender.name,
                abilityName: traitName(for: defender, in: context),
                target: attacker,
                amount: outcome.healthLost,
                keyword: .physical
            )]
        }
        return events
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

    private static func traitName(for combatant: Combatant, in context: BattleEngineContext) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? "Trait"
    }
}
