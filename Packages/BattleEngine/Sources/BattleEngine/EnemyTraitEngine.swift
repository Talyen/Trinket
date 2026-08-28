import Foundation
import TrinketContent
import TrinketCore

package enum EnemyTraitEngine {
    package static func turnFreeze(
        for combatant: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.turnFreezeDamageAllEnemies > 0,
              context.roster.health(for: combatant) > 0,
              context.turnCount > 0,
              context.turnCount.isMultiple(of: 2)
        else { return [] }

        return turnDamageAllEnemies(
            amount: profile.triggers.turnFreezeDamageAllEnemies,
            keyword: .freeze,
            source: combatant,
            context: &context
        )
    }

    package static func turnRandomDamageAllEnemies(
        for combatant: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: combatant.id).triggers
        guard triggers.turnRandomDamageAllEnemiesAmount > 0,
              let first = triggers.turnRandomDamageAllEnemiesKeywordA,
              let second = triggers.turnRandomDamageAllEnemiesKeywordB,
              context.roster.health(for: combatant) > 0
        else { return [] }

        let chosen = BattleChance.succeeds(probability: 0.5, using: &context.rng) ? first : second
        return turnDamageAllEnemies(
            amount: triggers.turnRandomDamageAllEnemiesAmount,
            keyword: chosen,
            source: combatant,
            context: &context
        )
    }

    private static func turnDamageAllEnemies(
        amount: Int,
        keyword: Keyword,
        source: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for targetRuntime in [context.roster.hero, context.roster.companion] where targetRuntime.isAlive {
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: amount,
                    target: targetRuntime.combatant,
                    keyword: keyword,
                    sourceActorID: source.id,
                    options: keyword == .stun || keyword == .freeze
                        ? .flatControlReaction
                        : .flatReaction
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
                options: .flatReaction
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
