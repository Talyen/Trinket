import Foundation
import TrinketContent
import TrinketCore

/// Intrinsic battle rule: hero and companion each get one Death's Door proc per battle.
package enum DeathsDoorEngine {
    public static func applies(to combatant: Combatant) -> Bool {
        combatant.role == .hero || combatant.role == .companion
    }

    public static func isActive(for combatant: Combatant, in context: BattleState) -> Bool {
        context.roster.isDeathsDoorActive(for: combatant)
    }

    /// Lethal protection while Death's Door is active, or for the remainder of the tick it expired.
    public static func hasLethalProtection(
        for combatant: Combatant,
        in context: BattleState
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

    public static func resolveAfterDamage(
        to combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard applies(to: combatant) else { return [] }

        let health = context.roster.health(for: combatant)
        if health == 0 {
            // Phoenix Gift: when the Hero takes fatal damage, the Phoenix heals them
            // for a percent of Max Health (preempts Death's Door).
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
            // Tenacious Spirit: survive one additional lethal blow while on Death's Door.
            if context.roster.isDeathsDoorActive(for: combatant),
               context.modifiers(for: combatant.id).triggers.deathsDoorExtraLethalProtection {
                clampToMinimumHP(on: combatant, in: &context)
                return []
            }
            if hasLethalProtection(for: combatant, in: context) {
                clampToMinimumHP(on: combatant, in: &context)
            }
        }
        // Corpse Explosion: on final death, deal Physical damage to the enemy.
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
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: false,
                            applyDodge: false,
                            isRetaliation: true
                        )
                    )
                )
                return outcome.events
            }
        }
        return []
    }

    /// Phoenix Gift: when the Hero takes fatal damage, heal them for a percent of Max Health (once per battle).
    private static func tryPhoenixGift(
        on combatant: Combatant,
        in context: inout BattleState
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
                    displayAmount: heal
                ),
                revivesIfDead: true,
                skipFightPacing: true
            ),
            in: &context
        ).events
    }

    /// Policy C: unused trait death-revive fires before Death's Door and does not consume DD.
    private static func tryTraitDeathRevive(
        on combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent]? {
        guard let runtime = context.roster.runtime(for: combatant),
              !runtime.hasTriggeredDeathRevive
        else { return nil }

        let triggers = context.modifiers(for: combatant.id).triggers
        let reviveHealth = triggers.onceDeathReviveHealth
        let reviveBlock = triggers.onceDeathReviveBlock
        guard reviveHealth > 0 || reviveBlock > 0 else { return nil }

        let healthToRestore = max(1, reviveHealth)
        var revivedHealth = 0
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasTriggeredDeathRevive = true
            runtime.currentHealth = min(healthToRestore, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }

        let abilityName = reviveHealth >= 10 ? "Rebirth" : "Deathrattle"
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .instantHeal,
                actorName: combatant.name,
                abilityName: abilityName,
                target: combatant,
                amount: revivedHealth,
                keyword: .health
            ),
        ]
        if reviveBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                reviveBlock,
                to: combatant,
                source: combatant,
                abilityName: abilityName
            ))
        }
        // Blazing Rebirth: reviving deals Burn damage to the enemy.
        if triggers.reviveDealBurnDamage > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.reviveDealBurnDamage,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
        }
        return events
    }

    private static func trigger(
        on combatant: Combatant,
        in context: inout BattleState
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
            remainingTurns: duration
        )

        // Phoenix Vigor: surviving Death's Door grants +50% damage for 3 turns.
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
            keyword: .deathsDoor
        )
        var events = [event]
        let blockAmount = triggers.blockOnDeathsDoor
        if blockAmount > 0 {
            events.append(contentsOf: context.applyBlock(
                blockAmount,
                to: combatant,
                source: combatant,
                abilityName: "Deathgrip"
            ))
        }
        events.append(contentsOf: guardianArchive(on: combatant, in: &context))
        events.append(contentsOf: afterglow(on: combatant, in: &context))
        return events
    }

    /// Guardian Archive: when an ally hits Death's Door, the Owl heals them and cleanses.
    private static func guardianArchive(
        on combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role == .hero,
              context.roster.companion.isAlive,
              companionTriggers.onAllyDeathsDoorHealAndCleanse > 0
        else { return [] }
        var events = HealingEngine.resolveHeal(
            HealRequest(
                amount: companionTriggers.onAllyDeathsDoorHealAndCleanse,
                target: combatant,
                sourceActorID: context.roster.companion.id,
                logAs: .instantHeal(
                    actorName: context.roster.companion.name,
                    abilityName: "Guardian Archive",
                    keyword: .health,
                    displayAmount: companionTriggers.onAllyDeathsDoorHealAndCleanse
                )
            ),
            in: &context
        ).events
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
                keyword: keyword
            )
        })
        return events
    }

    /// Afterglow: when the Phoenix survives Death's Door, restore 15% of each
    /// ally's Max Health.
    private static func afterglow(
        on combatant: Combatant,
        in context: inout BattleState
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
            let heal = max(1, CombatRounding.scaled(maxHealth, multiplier: companionTriggers.surviveDeathsDoorPartyHealPercent))
            var restored = 0
            context.roster.mutateRuntime(for: member.combatant) { runtime in
                let before = runtime.currentHealth
                runtime.currentHealth = min(runtime.maxHealth, before + heal)
                restored = runtime.currentHealth - before
            }
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: combatant.name,
                    abilityName: "Afterglow",
                    target: member.combatant,
                    amount: restored,
                    keyword: .health
                ))
            }
        }
        return events
    }

    /// Endless Legion: when Death's Door ends, restore Health once.
    static func afterDeathsDoorExpired(
        on combatant: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard let runtime = context.roster.runtime(for: combatant),
              !runtime.hasTriggeredEndlessLegion,
              context.roster.health(for: combatant) > 0
        else { return [] }
        let amount = context.modifiers(for: combatant.id).triggers.onEnemyDefeatReviveSelfHealth
        guard amount > 0 else { return [] }
        context.roster.mutateRuntime(for: combatant) { $0.hasTriggeredEndlessLegion = true }
        var restored = 0
        context.roster.mutateRuntime(for: combatant) { runtime in
            let before = runtime.currentHealth
            runtime.currentHealth = min(max(runtime.currentHealth, amount), runtime.maxHealth)
            restored = runtime.currentHealth - before
        }
        guard restored > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: combatant.name,
            abilityName: "Endless Legion",
            target: combatant,
            amount: restored,
            keyword: .health
        )]
    }

    private static func clampToMinimumHP(
        on combatant: Combatant,
        in context: inout BattleState
    ) {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.currentHealth = max(1, runtime.currentHealth)
        }
    }
}
