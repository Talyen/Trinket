import Foundation
import TrinketContent
import TrinketCore

package enum EnemyTraitEngine {
    static func firstAttackBleedBonus(from state: DamageResolutionState, context: inout BattleState) -> [ActionEvent] {
        guard state.options.isAttackHit, !state.options.isRetaliation, !state.options.isPeriodic,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role == .enemy,
              context.roster.health(for: source.combatant) > 0,
              context.roster.health(for: state.combatant) > 0
        else { return [] }
        let triggers = context.modifiers(for: sourceActorID).triggers
        guard triggers.firstAttackBleedBonus > 0,
              let runtime = context.roster.runtime(for: source.combatant),
              !runtime.hasTriggeredFirstHitBonus
        else { return [] }
        context.roster.mutateRuntime(for: source.combatant) { $0.hasTriggeredFirstHitBonus = true }
        var events: [ActionEvent] = []
        let amount = triggers.firstAttackBleedBonus
        events.append(contentsOf: context.resolveDamage(DamageRequest(
            amount: amount,
            target: state.combatant,
            keyword: .bleed,
            sourceActorID: sourceActorID,
            options: .reaction(),
        )).events)
        events.append(contentsOf: DoTApplicator.applyBleed(
            potency: amount,
            to: state.combatant,
            sourceActorID: sourceActorID,
            application: .afterHit,
            in: &context,
        ))
        return events
    }

    static func basicFreezeDamage(from state: DamageResolutionState, context: inout BattleState) -> [ActionEvent] {
        guard state.sourceActorID == context.enemy.id, state.combatant.role != .enemy,
              context.health(of: state.combatant) > 0, context.roster.enemy.isAlive else { return [] }
        let amount = context.enemyModifiers.triggers.basicAttackFreezeBuildup
        let immediateBasic = state.provenance != nil
            && state.provenance == context.resolution.damageProvenance(for: context.enemy.id)
            && context.resolution.actionOutcome?.ability.tier == .basic
        guard amount > 0, state.options.isBasicAttackHit || immediateBasic else { return [] }
        if let actionID = context.resolution.actionID {
            guard context.resolution.claim(
                .heroTalent("basicAttackFreezeBuildup"), actorID: context.enemy.id, cadence: .action(actionID),
            ) else { return [] }
        }
        return context.resolveDamage(DamageRequest(
            amount: amount, target: state.combatant, keyword: .freeze,
            sourceActorID: context.enemy.id, options: .reaction(),
        )).events
    }

    package static func turnFreeze(
        for combatant: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        let interval = profile.triggers.turnFreezeDamageAllEnemiesInterval
        guard profile.triggers.turnFreezeDamageAllEnemies > 0,
              context.roster.health(for: combatant) > 0,
              context.turnCount > 0,
              interval > 0,
              context.turnCount.isMultiple(of: interval)
        else { return [] }

        return turnDamageAllEnemies(
            amount: profile.triggers.turnFreezeDamageAllEnemies,
            keyword: .freeze,
            source: combatant,
            context: &context,
        )
    }

    package static func turnRandomDamageAllEnemies(
        for combatant: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: combatant.id).triggers
        let interval = triggers.turnRandomDamageAllEnemiesInterval
        guard triggers.turnRandomDamageAllEnemiesAmount > 0,
              let first = triggers.turnRandomDamageAllEnemiesKeywordA,
              let second = triggers.turnRandomDamageAllEnemiesKeywordB,
              context.roster.health(for: combatant) > 0,
              context.turnCount > 0,
              interval > 0,
              context.turnCount.isMultiple(of: interval)
        else { return [] }

        let chosen = BattleChance.succeeds(probability: 0.5, using: &context.rng) ? first : second
        return turnDamageAllEnemies(
            amount: triggers.turnRandomDamageAllEnemiesAmount,
            keyword: chosen,
            source: combatant,
            context: &context,
        )
    }

    private static func turnDamageAllEnemies(
        amount: Int,
        keyword: Keyword,
        source: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        let action = BattleActionContext(actor: source, in: context)
        for target in action.opponents(in: context) {
            guard !context.isBattleOver, action.canContinue(in: context) else { break }
            guard context.health(of: target) > 0 else { continue }
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: amount,
                    target: target,
                    keyword: keyword,
                    sourceActorID: source.id,
                    options: .reaction(),
                ),
            )
            events.append(contentsOf: outcome.events)
        }
        return events
    }

    package static func traitAttackerBurn(
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState,
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
            application: .attached,
            in: &context,
        )
    }

    package static func traitThornsDamage(
        damageTaken: Int,
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: defender.id)
        guard profile.triggers.thornsPercent > 0, damageTaken > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return [] }

        let thornsAmount = CombatRounding.scaled(damageTaken, multiplier: profile.triggers.thornsPercent)
        guard thornsAmount > 0 else { return [] }
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: thornsAmount,
                target: attacker,
                keyword: .physical,
                sourceActorID: defender.id,
                options: .reaction(),
            ),
        )
        let events = outcome.events.map { event in
            event.with(
                effectKind: .thornsTriggered,
                actorID: defender.id,
                actorName: defender.name,
                abilityName: profile.triggerAbilityName("thornsPercent", fallback: "Trait"),
            )
        }
        if events.isEmpty, outcome.healthLost > 0 {
            return [context.nextEvent(
                kind: .effect,
                effectKind: .thornsTriggered,
                actorName: defender.name,
                abilityName: profile.triggerAbilityName("thornsPercent", fallback: "Trait"),
                target: attacker,
                amount: outcome.healthLost,
                keyword: .physical,
            )]
        }
        return events
    }
}
