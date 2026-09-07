import Foundation
import TrinketContent
import TrinketCore

package enum DeathsDoorEngine {
    package static func applies(to combatant: Combatant) -> Bool {
        combatant.role == .hero || combatant.role == .companion
    }

    package static func isActive(for combatant: Combatant, in context: BattleState) -> Bool {
        context.roster.isDeathsDoorActive(for: combatant)
    }

    package static func hasLethalProtection(
        for combatant: Combatant,
        in context: BattleState,
    ) -> Bool {
        if isActive(for: combatant, in: context) {
            return true
        }
        guard context.roster.hasConsumedDeathsDoor(for: combatant),
              let runtime = context.roster.runtime(for: combatant),
              let expiredAt = runtime.deathsDoorExpiredAtTurn,
              expiredAt == context.turnCount
        else { return false }
        return true
    }

    package static func resolveAfterDamage(
        to combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard applies(to: combatant) else { return [] }

        let health = context.roster.health(for: combatant)
        if health == 0 {
            if combatant.role == .hero,
               let gift = tryPhoenixGift(on: combatant, in: &context) {
                return gift
            }
            if let reviveEvents = tryTraitDeathRevive(on: combatant, in: &context) {
                return reviveEvents
            }
            if !context.roster.hasConsumedDeathsDoor(for: combatant) {
                return trigger(on: combatant, in: &context)
            }
            if hasLethalProtection(for: combatant, in: context) {
                clampToMinimumHP(on: combatant, in: &context)
            }
        }
        if context.roster.health(for: combatant) == 0,
           combatant.id != context.roster.enemy.id,
           context.roster.enemy.isAlive {
            let explosion = context.modifiers(for: combatant.id).triggers.onDeathDealPhysicalDamageAllEnemies
            if explosion > 0 {
                let outcome = context.resolveDamage(
                    DamageRequest(
                        amount: explosion,
                        target: context.roster.enemy.combatant,
                        keyword: .physical,
                        sourceActorID: combatant.id,
                        options: .flatReaction,
                    ),
                )
                return outcome.events
            }
        }
        return []
    }

    private static func tryPhoenixGift(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent]? {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role == .hero,
              context.roster.companion.isAlive,
              companionTriggers.onHeroFatalHealPercentMaxHealth > 0,
              let compRuntime = context.roster.runtime(for: context.roster.companion.combatant),
              !compRuntime.hasTriggeredPhoenixGift
        else { return nil }
        context.roster.mutateRuntime(for: context.roster.companion.combatant) { runtime in
            runtime.hasTriggeredPhoenixGift = true
        }
        let maxHealth = context.roster.maxHealth(for: combatant)
        let heal = max(1, CombatRounding.scaled(maxHealth, multiplier: companionTriggers.onHeroFatalHealPercentMaxHealth))
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: heal,
                target: combatant,
                sourceActorID: context.roster.companion.id,
                logAs: .instantHeal(
                    actorName: context.roster.companion.name,
                    abilityName: "Phoenix Gift",
                    keyword: .health,
                ),
                revivesIfDead: true,
                skipFightPacing: true,
            ),
            in: &context,
        ).events
    }

    private static func tryTraitDeathRevive(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent]? {
        guard let runtime = context.roster.runtime(for: combatant),
              !runtime.hasTriggeredDeathRevive
        else { return nil }

        let triggers = context.modifiers(for: combatant.id).triggers
        let reviveHealth = triggers.onceDeathReviveHealth
        let reviveBlock = triggers.onceDeathReviveBlock
        guard reviveHealth > 0 || reviveBlock > 0 else { return nil }

        let healthToRestore = max(1, reviveHealth)
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasTriggeredDeathRevive = true
            runtime.currentHealth = min(healthToRestore, runtime.maxHealth)
        }

        let abilityName = reviveHealth >= 10 ? "Rebirth" : "Deathrattle"
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .instantHeal,
                actorName: combatant.name,
                abilityName: abilityName,
                target: combatant,
                amount: min(healthToRestore, context.roster.maxHealth(for: combatant)),
                keyword: .health,
            ),
        ]
        if reviveBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                reviveBlock,
                to: combatant,
                source: combatant,
                abilityName: abilityName,
            ))
        }
        if triggers.reviveDealBurnDamage > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.reviveDealBurnDamage,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true,
            ))
        }
        return events
    }

    private static func trigger(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasConsumedDeathsDoor = true
            runtime.currentHealth = 1
        }

        let triggers = context.modifiers(for: combatant.id).triggers
        let duration = BattleTiming.deathsDoorDurationTurns + triggers.deathsDoorDurationBonusTurns
        context.prependEffect(
            .deathsDoor,
            to: combatant,
            remainingTurns: duration,
        )

        if triggers.onSurviveDeathsDoorDamageBonusPercent > 0 {
            context.roster.mutateRuntime(for: combatant) { runtime in
                runtime.talentDamagePercentBonus += triggers.onSurviveDeathsDoorDamageBonusPercent
                runtime.talentDamagePercentUntilTurn = context.turnCount + 3
            }
        }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .deathsDoorTriggered,
            actorName: combatant.name,
            abilityName: Keyword.deathsDoor.rawValue,
            target: combatant,
            amount: 0,
            keyword: .deathsDoor,
        )
        var events = [event]
        let blockAmount = triggers.blockOnDeathsDoor
        if blockAmount > 0 {
            events.append(contentsOf: context.applyBlock(
                blockAmount,
                to: combatant,
                source: combatant,
                abilityName: "Deathgrip",
            ))
        }
        events.append(contentsOf: guardianArchive(on: combatant, in: &context))
        events.append(contentsOf: afterglow(on: combatant, in: &context))
        return events
    }

    private static func guardianArchive(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role != .enemy,
              context.roster.companion.isAlive,
              companionTriggers.onAllyDeathsDoorHealAndCleanse > 0
        else { return [] }
        var events = context.healEmitting(
            amount: companionTriggers.onAllyDeathsDoorHealAndCleanse,
            target: combatant,
            source: context.roster.companion.combatant,
            abilityName: "Guardian Archive",
        )
        var effects = context.roster.activeEffects(for: combatant)
        var removedKeywords: [Keyword] = []
        while let removed = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) {
            removedKeywords.append(removed)
        }
        context.roster.setActiveEffects(effects, for: combatant)
        events.append(contentsOf: removedKeywords.map { keyword in
            context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: context.roster.companion.name,
                abilityName: "Guardian Archive",
                target: combatant,
                amount: 0,
                keyword: keyword,
            )
        })
        return events
    }

    private static func afterglow(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role == .companion, companionTriggers.surviveDeathsDoorPartyHealPercent > 0 else {
            return []
        }
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
            let maxHealth = context.roster.maxHealth(for: member.combatant)
            guard context.roster.health(for: member.combatant) < maxHealth else { continue }
            let heal = max(1, CombatRounding.scaled(maxHealth, multiplier: companionTriggers.surviveDeathsDoorPartyHealPercent))
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: heal,
                    target: member.combatant,
                    sourceActorID: context.roster.companion.id,
                    logAs: .instantHeal(
                        actorName: combatant.name,
                        abilityName: "Afterglow",
                        keyword: .health,
                    ),
                    skipFightPacing: true,
                ),
                in: &context,
            ).events)
        }
        return events
    }

    static func afterDeathsDoorExpired(
        on combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: combatant.id).triggers.deathsDoorExpiredHealFlat
        guard amount > 0,
              context.roster.health(for: combatant) > 0,
              context.claimBattleGuard(.endlessLegion, actorID: combatant.id)
        else { return [] }
        let maxHealth = context.roster.maxHealth(for: combatant)
        let currentHealth = context.roster.health(for: combatant)
        let delta = min(max(currentHealth, amount), maxHealth) - currentHealth
        guard delta > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: delta,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: "Endless Legion",
                    keyword: .health,
                ),
                skipFightPacing: true,
            ),
            in: &context,
        ).events
    }

    private static func clampToMinimumHP(
        on combatant: Combatant,
        in context: inout BattleState,
    ) {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.currentHealth = max(1, runtime.currentHealth)
        }
    }
}
