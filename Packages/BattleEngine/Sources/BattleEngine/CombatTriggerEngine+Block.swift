import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events = applyBlockThorns(amount: amount, triggers: triggers, actor: actor, in: &context)
        applyVitalArmor(amount: amount, triggers: triggers, actor: actor, in: &context)
        events.append(contentsOf: shareCompanionBlockToHero(
            amount: amount,
            triggers: triggers,
            actor: actor,
            in: &context
        ))
        return events
    }

    private static func applyBlockThorns(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let gained = CombatRounding.scaled(amount, multiplier: triggers.blockGainThornsPercent)
        guard gained > 0 else { return [] }
        var effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        effects.removeAll {
            if case .thorns = $0.effect {
                return true
            }
            return false
        }
        let total = existing + gained
        effects.append(ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .thorns(total),
            remainingTurns: 0,
            sourceActorID: actor.id
        ))
        context.roster.setActiveEffects(effects, for: actor)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                "blockGainThornsPercent",
                for: actor,
                fallback: "Thorns",
                in: context
            ),
            target: actor,
            amount: total,
            keyword: .physical
        )]
    }

    private static func applyVitalArmor(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState
    ) {
        guard triggers.blockGainedMaxHealthEvery > 0 else { return }
        context.roster.mutateRuntime(for: actor) { runtime in
            let prevBlock = runtime.totalBlockGainedThisCombat
            let newBlock = prevBlock + amount
            runtime.totalBlockGainedThisCombat = newBlock
            let prevBonus = prevBlock / triggers.blockGainedMaxHealthEvery
            let newBonus = min(10, newBlock / triggers.blockGainedMaxHealthEvery)
            let gainedHealth = newBonus - min(10, prevBonus)
            if gainedHealth > 0 {
                runtime.talentMaxHealthBonus += gainedHealth
                runtime.currentHealth = min(runtime.maxHealth, runtime.currentHealth + gainedHealth)
            }
        }
    }

    private static func shareCompanionBlockToHero(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard actor.role == .companion,
              triggers.companionBlockSharesToHeroPercent > 0,
              context.roster.hero.isAlive
        else { return [] }
        let share = CombatRounding.scaled(
            amount,
            multiplier: min(1, max(0, triggers.companionBlockSharesToHeroPercent))
        )
        guard share > 0 else { return [] }
        return context.applyBlock(
            share,
            to: context.roster.hero.combatant,
            source: actor,
            abilityName: triggerAbilityName(
                "companionBlockSharesToHeroPercent",
                for: actor,
                fallback: "Shield Bond",
                in: context
            ),
            applyOutgoingAdjustment: false
        )
    }

    /// Retribution triggers when a combatant's Block pool is broken by an attack (Saintfall).
    static func saintfallAfterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        power: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard power > 0,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID),
              attacker.isAlive,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredBlockBreakThisTurn
        else { return [] }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredBlockBreakThisTurn = true }

        var events: [ActionEvent] = []
        for keyword in [Keyword.holy, .stun] where context.roster.health(for: attacker.combatant) > 0 {
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: power,
                    target: attacker.combatant,
                    keyword: keyword,
                    sourceActorID: target.id,
                    options: .flatControlReaction
                )
            )
            events.append(contentsOf: outcome.events)
            if keyword == .holy, outcome.healthLost > 0 {
                events.append(contentsOf: afterHolyDamageDealt(
                    to: attacker.combatant,
                    source: target,
                    isAttackHit: false,
                    in: &context
                ))
            }
        }
        events.append(contentsOf: context.healEmitting(
            amount: power,
            target: target,
            source: target,
            abilityName: triggerAbilityName(
                "blockBrokenSaintfallPower",
                for: target,
                fallback: "Saintfall",
                in: context
            )
        ))
        return events
    }
}
