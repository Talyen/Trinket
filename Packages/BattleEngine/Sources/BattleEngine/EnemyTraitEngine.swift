import Foundation
import TrinketContent
import TrinketCore

/// Passive enemy trait hooks that run during battle ticks and damage resolution.
package enum EnemyTraitEngine {
    package static func turnFreeze(
        for combatant: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.turnFreezeDamageAllEnemies > 0,
              context.roster.health(for: combatant) > 0
        else { return [] }

        var events: [ActionEvent] = []
        let party = [context.roster.hero, context.roster.companion]
        for targetRuntime in party where targetRuntime.isAlive {
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: profile.triggers.turnFreezeDamageAllEnemies,
                    target: targetRuntime.combatant,
                    keyword: .freeze,
                    sourceActorID: combatant.id,
                    options: DamageOptions(
                        applyStatBonus: false,
                        applyItemBonus: false,
                        applyDodge: false,
                        isRetaliation: true,
                        applyControlMeter: true
                    )
                )
            )
            events.append(contentsOf: outcome.events)
        }
        return events
    }

    package static func traitAttackerBurn(
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: defender.id)
        guard profile.triggers.onHitAttackerBurn > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return [] }

        return DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: profile.triggers.onHitAttackerBurn,
            to: attacker,
            sourceActorID: defender.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
            in: &context
        )
    }

    package static func traitThornsDamage(
        damageTaken: Int,
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: defender.id)
        guard profile.triggers.thornsPercent > 0, damageTaken > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return [] }

        let thornsAmount = max(1, CombatRounding.scaled(damageTaken, multiplier: profile.triggers.thornsPercent))
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: thornsAmount,
                target: attacker,
                keyword: .physical,
                sourceActorID: defender.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        )
        let events = outcome.events.map { event in
            event.with(
                effectKind: .thornsTriggered,
                actorID: defender.id,
                actorName: defender.name,
                abilityName: CombatTriggerEngine.traitName(for: defender, in: context)
            )
        }
        if events.isEmpty, outcome.healthLost > 0 {
            return [context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: defender.name,
                abilityName: CombatTriggerEngine.traitName(for: defender, in: context),
                target: attacker,
                amount: outcome.healthLost,
                keyword: .physical
            )]
        }
        return events
    }
}
