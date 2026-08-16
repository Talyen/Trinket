import Foundation
import TrinketContent
import TrinketCore

/// Passive enemy trait hooks that run during battle ticks and damage resolution.
package enum EnemyTraitEngine {
    package static func turnRegeneration(
        for combatant: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.regenerationAmount > 0,
              profile.triggers.regenerationIntervalTurns > 0,
              context.turnCount.isMultiple(of: profile.triggers.regenerationIntervalTurns),
              context.roster.health(for: combatant) > 0
        else { return [] }

        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.regenerationAmount,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: traitName(for: combatant, in: context),
                    keyword: .health,
                    displayAmount: profile.triggers.regenerationAmount
                )
            ),
            in: &context
        )
        return outcome.events
    }

    package static func turnBlock(
        for combatant: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.blockPerTurn > 0,
              context.roster.health(for: combatant) > 0
        else { return [] }

        let applied = DefensePoolEngine.add(
            profile.triggers.blockPerTurn,
            to: combatant,
            keyword: .block,
            sourceActorID: combatant.id,
            in: &context
        )
        return [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: combatant.name,
            abilityName: traitName(for: combatant, in: context),
            target: combatant,
            amount: applied,
            keyword: .block
        )]
    }

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

    package static func applyShieldErosion(
        keyword: Keyword,
        to combatant: Combatant,
        context: inout BattleState
    ) {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.shieldErosionTicks > 0,
              profile.triggers.shieldErosionKeyword == keyword
        else { return }

        var effects = context.roster.activeEffects(for: combatant)
        var didErode = false
        for index in effects.indices {
            guard case let .shield(shieldKeyword, buffer) = effects[index].effect else { continue }
            let eroded = max(0, buffer - profile.triggers.shieldErosionTicks)
            effects[index] = ActiveEffect(
                id: effects[index].id,
                effect: .shield(shieldKeyword, eroded),
                remainingTurns: 0,
                sourceActorID: effects[index].sourceActorID
            )
            didErode = true
        }
        guard didErode else { return }
        effects.removeAll { active in
            if case let .shield(_, buffer) = active.effect {
                return buffer <= 0
            }
            return false
        }
        context.roster.setActiveEffects(effects, for: combatant)
    }

    package static func applyMitigationShred(
        keyword: Keyword,
        to combatant: Combatant,
        context: inout BattleState
    ) {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.mitigationShredDurationTurns > 0,
              profile.triggers.mitigationShredMultiplier > 0,
              profile.triggers.mitigationShredKeyword == keyword,
              var runtime = context.roster.runtime(for: combatant)
        else { return }

        runtime.mitigationShredUntilTurn = context.turnCount + profile.triggers.mitigationShredDurationTurns
        runtime.mitigationShredMultiplier = profile.triggers.mitigationShredMultiplier
        context.roster.update(runtime)
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
                abilityName: traitName(for: defender, in: context)
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

    package static func bonusBleedPotency(
        ability: Ability,
        sourceID: String,
        in context: BattleState
    ) -> Int {
        guard ability.id == "hemorrhage" else { return 0 }
        return context.modifiers(for: sourceID).triggers.hemorrhageBleedBonus
    }

    private static func traitName(for combatant: Combatant, in context: BattleState) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? "Trait"
    }
}
