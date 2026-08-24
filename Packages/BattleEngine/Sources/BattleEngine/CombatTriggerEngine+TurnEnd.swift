import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// End-of-turn talent resolution (Mana Shield, Hibernation, Playful Energy, Cheer Up).
    static func atPlayerEndTurn(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers

            events.append(contentsOf: endOfTurnBlockConversion(runtime: runtime, actor: actor, in: &context))
            events.append(contentsOf: endOfTurnHealing(owner: owner, actor: actor, triggers: triggers, in: &context))
            events.append(contentsOf: hoardArmorBlock(actor: actor, triggers: triggers, in: &context))
        }
        return events
    }

    /// Mana Shield: convert unspent Mana into Block at end of turn.
    private static func endOfTurnBlockConversion(
        runtime: CombatantRuntime,
        actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        guard triggers.unspentManaConvertsToBlock, runtime.maxMana > 0, runtime.currentMana > 0 else { return [] }
        let converted = runtime.currentMana
        return context.applyBlock(
            converted,
            to: actor,
            source: actor,
            abilityName: "Mana Shield"
        )
    }

    /// Hoard Armor: 1 Block per N Gold carried at end of turn, capped at 5.
    private static func hoardArmorBlock(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.blockPerGoldCollectedEvery > 0, context.gold > 0 else { return [] }
        let block = min(5, context.gold / triggers.blockPerGoldCollectedEvery)
        guard block > 0 else { return [] }
        return context.applyBlock(
            block,
            to: actor,
            source: actor,
            abilityName: "Hoard Armor"
        )
    }

    /// End-of-turn healing talents: Hibernation, Playful Energy, Cheer Up, Campfire Comfort.
    private static func endOfTurnHealing(
        owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        events.append(contentsOf: hibernationHeal(actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: playfulEnergyHeal(owner: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: cheerUpHeal(actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: campfireComfortHeal(actor: actor, triggers: triggers, in: &context))
        return events
    }

    /// Hibernation: restore Health when ending the turn with Block.
    private static func hibernationHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.endTurnWithBlockHealFlat > 0,
              DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor)) > 0
        else { return [] }
        return context.healEmitting(
            amount: triggers.endTurnWithBlockHealFlat,
            target: actor,
            source: actor,
            abilityName: "Hibernation"
        )
    }

    /// Playful Energy: heal both allies after enough cards were played this turn.
    private static func playfulEnergyHeal(
        owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.cardsPlayedHealPartyThreshold > 0,
              (context.cardsPlayedThisTurn[owner] ?? 0) >= triggers.cardsPlayedHealPartyThreshold
        else { return [] }
        var events: [ActionEvent] = []
        for otherOwner in [BattleParticipant.hero, .companion] {
            let member = context.roster[otherOwner]
            guard member.isAlive else { continue }
            events.append(contentsOf: context.healEmitting(
                amount: triggers.cardsPlayedHealPartyAmount,
                target: member.combatant,
                source: actor,
                abilityName: "Playful Energy"
            ))
        }
        return events
    }

    /// Cheer Up: restore Health to the lowest-Health ally.
    private static func cheerUpHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.endOfTurnHealLowestAlly > 0 else { return [] }
        let lowest = BattleConditionEvaluator.lowestHealthAlly(
            hero: context.roster.hero.combatant,
            companion: context.roster.companion.combatant,
            context: context
        )
        return context.healEmitting(
            amount: triggers.endOfTurnHealLowestAlly,
            target: lowest,
            source: actor,
            abilityName: "Cheer Up"
        )
    }

    /// Campfire Comfort: restore Health to both allies at the end of each round.
    private static func campfireComfortHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.partyRegenPerRound > 0 else { return [] }
        var events: [ActionEvent] = []
        for memberOwner in [BattleParticipant.hero, .companion] {
            let member = context.roster[memberOwner]
            guard member.isAlive else { continue }
            events.append(contentsOf: context.healEmitting(
                amount: triggers.partyRegenPerRound,
                target: member.combatant,
                source: actor,
                abilityName: "Campfire Comfort"
            ))
        }
        return events
    }
}
