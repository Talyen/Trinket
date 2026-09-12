import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events = applyBlockThorns(amount: amount, triggers: triggers, actor: actor, in: &context)
        applyVitalArmor(amount: amount, triggers: triggers, actor: actor, in: &context)
        events.append(contentsOf: shareCompanionBlockToHero(
            amount: amount,
            triggers: triggers,
            actor: actor,
            in: &context,
        ))
        return events
    }

    static func applyBlockThorns(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        abilityKey: String = "blockGainThornsPercent",
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let percent = abilityKey == "blockGainThornsPercent"
            ? triggers.blockGainThornsPercent
            : triggers.retainedBlockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard gained > 0 else { return [] }
        let effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        let total = existing + gained
        guard context.insertEffect(
            .thorns(total), to: actor, sourceID: actor.id, remainingTurns: 0,
            replacing: { $0.kind == .thorns },
        ) else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                abilityKey,
                for: actor,
                fallback: "Thorns",
                in: context,
            ),
            target: actor,
            amount: total,
            keyword: .thorns,
        )]
    }

    private static func applyVitalArmor(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard triggers.blockGainedMaxHealthEvery > 0 else { return }
        context.roster.mutateRuntime(for: actor) { runtime in
            let prevBlock = runtime.talents.battle.totalBlockGained
            let newBlock = prevBlock + amount
            runtime.talents.battle.totalBlockGained = newBlock
            let prevBonus = prevBlock / triggers.blockGainedMaxHealthEvery
            let newBonus = min(10, newBlock / triggers.blockGainedMaxHealthEvery)
            let gainedHealth = newBonus - min(10, prevBonus)
            if gainedHealth > 0 {
                runtime.talents.battle.maximumHealthBonus += gainedHealth
                runtime.currentHealth = min(runtime.maxHealth, runtime.currentHealth + gainedHealth)
            }
        }
    }

    private static func shareCompanionBlockToHero(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .companion,
              triggers.companionBlockSharesToHeroPercent > 0,
              context.roster.hero.isAlive
        else { return [] }
        let share = CombatRounding.scaled(
            amount,
            multiplier: min(1, max(0, triggers.companionBlockSharesToHeroPercent)),
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
                in: context,
            ),
            amountBasis: .resolved,
        )
    }

    static func saintfallAfterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        power: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard power > 0,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID),
              attacker.isAlive,
              let runtime = context.roster.runtime(for: target),
              !runtime.talents.turn.triggeredBlockBreak
        else { return [] }
        context.roster.mutateRuntime(for: target) { $0.talents.turn.triggeredBlockBreak = true }

        var events: [ActionEvent] = []
        for keyword in [Keyword.holy, .stun] where context.roster.health(for: attacker.combatant) > 0 {
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: power,
                    target: attacker.combatant,
                    keyword: keyword,
                    sourceActorID: target.id,
                    options: .reaction(),
                ),
            )
            events.append(contentsOf: outcome.events)
            if keyword == .holy, outcome.healthLost > 0 {
                events.append(contentsOf: afterHolyDamageDealt(
                    to: attacker.combatant,
                    source: target,
                    in: &context,
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
                in: context,
            ),
        ))
        return events
    }
}
