import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
            abilityName: triggerAbilityName("unspentManaConvertsToBlock", for: actor, fallback: "Mana Shield", in: context)
        )
    }

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
            abilityName: triggerAbilityName("blockPerGoldCollectedEvery", for: actor, fallback: "Hoard Armor", in: context)
        )
    }

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
            abilityName: triggerAbilityName("endTurnWithBlockHealFlat", for: actor, fallback: "Hibernation", in: context)
        )
    }

    private static func playfulEnergyHeal(
        owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.cardsPlayedHealPartyThreshold > 0,
              (context.turnCadence.cardsPlayed[owner] ?? 0) >= triggers.cardsPlayedHealPartyThreshold
        else { return [] }
        var events: [ActionEvent] = []
        for otherOwner in [BattleParticipant.hero, .companion] {
            let member = context.roster[otherOwner]
            guard member.isAlive else { continue }
            events.append(contentsOf: context.healEmitting(
                amount: triggers.cardsPlayedHealPartyAmount,
                target: member.combatant,
                source: actor,
                abilityName: triggerAbilityName("cardsPlayedHealPartyThreshold", for: actor, fallback: "Playful Energy", in: context)
            ))
        }
        return events
    }

    private static func cheerUpHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.endOfTurnHealLowestAlly > 0 else { return [] }
        let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
        return context.healEmitting(
            amount: triggers.endOfTurnHealLowestAlly,
            target: lowest,
            source: actor,
            abilityName: triggerAbilityName("endOfTurnHealLowestAlly", for: actor, fallback: "Cheer Up", in: context)
        )
    }

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
                abilityName: triggerAbilityName("partyRegenPerRound", for: actor, fallback: "Campfire Comfort", in: context)
            ))
        }
        return events
    }
}
