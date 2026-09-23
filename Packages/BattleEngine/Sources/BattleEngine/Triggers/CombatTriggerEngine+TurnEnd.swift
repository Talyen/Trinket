import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func atPlayerEndTurn(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for (_, runtime) in livingPartyMembers(in: context) {
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers

            events.append(contentsOf: endOfTurnBlockConversion(runtime: runtime, actor: actor, triggers: triggers, in: &context))
            if triggers.endTurnZeroManaCleanse, runtime.maxMana > 0, runtime.currentMana == 0 {
                events.append(contentsOf: performRandomCleanses(
                    source: actor, target: actor, count: 1,
                    abilityName: "Arcane Cleansing", in: &context,
                ))
            }
            events.append(contentsOf: endOfTurnHealing(actor: actor, triggers: triggers, in: &context))
            events.append(contentsOf: hoardArmorBlock(actor: actor, triggers: triggers, in: &context))
        }
        return events
    }

    private static func endOfTurnBlockConversion(
        runtime: CombatantRuntime,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard triggers.unspentManaConvertsToBlock, runtime.maxMana > 0, runtime.currentMana > 0 else { return [] }
        let converted = runtime.currentMana
        return emitBlock(
            "unspentManaConvertsToBlock", "Mana Shield",
            amount: converted, to: actor, source: actor, in: &context,
        )
    }

    private static func hoardArmorBlock(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard triggers.blockPerGoldCollectedEvery > 0, context.gold > 0 else { return [] }
        let block = min(5, context.gold / triggers.blockPerGoldCollectedEvery)
        guard block > 0 else { return [] }
        return emitBlock(
            "blockPerGoldCollectedEvery", "Hoard Armor",
            amount: block, to: actor, source: actor, in: &context,
        )
    }

    private static func endOfTurnHealing(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        events.append(contentsOf: hibernationHeal(actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: cheerUpHeal(actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: campfireComfortHeal(actor: actor, triggers: triggers, in: &context))
        return events
    }

    private static func hibernationHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard triggers.endTurnWithBlockHealFlat > 0,
              context.roster.health(for: actor) < context.roster.maxHealth(for: actor),
              DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor)) > 0
        else { return [] }
        return emitHeal(
            "endTurnWithBlockHealFlat", "Hibernation",
            amount: triggers.endTurnWithBlockHealFlat, to: actor, source: actor, in: &context,
        )
    }

    private static func cheerUpHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard triggers.endOfTurnHealLowestAlly > 0 else { return [] }
        let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
        guard context.roster.health(for: lowest) < context.roster.maxHealth(for: lowest) else { return [] }
        return emitHeal(
            "endOfTurnHealLowestAlly", "Cheer Up",
            amount: triggers.endOfTurnHealLowestAlly, to: lowest, source: actor, in: &context,
        )
    }

    private static func campfireComfortHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard triggers.partyRegenPerRound > 0 else { return [] }
        var events: [ActionEvent] = []
        for (_, member) in livingPartyMembers(in: context) {
            guard member.currentHealth < member.maxHealth else { continue }
            events.append(contentsOf: emitHeal(
                "partyRegenPerRound", "Campfire Comfort",
                amount: triggers.partyRegenPerRound, to: member.combatant, source: actor, in: &context,
            ))
        }
        return events
    }
}
