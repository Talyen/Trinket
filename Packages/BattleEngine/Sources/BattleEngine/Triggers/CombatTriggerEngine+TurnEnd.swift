import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func atPlayerEndTurn(in context: inout BattleState) async {
        for (_, runtime) in livingPartyMembers(in: context) {
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers
            let steps: [CombatCheckpoint.Reaction] = [
                { endOfTurnBlockConversion(runtime: runtime, actor: actor, triggers: triggers, in: &$0) },
                { context in
                    guard triggers.endTurnZeroManaCleanse,
                          let current = context.roster.runtime(for: actor),
                          current.maxMana > 0, current.currentMana == 0 else { return }
                    await performRandomCleanses(source: actor, target: actor, count: 1, abilityName: "Arcane Cleansing", in: &context)
                },
                { await hibernationHeal(actor: actor, triggers: triggers, in: &$0) },
                { await campfireComfortHeal(actor: actor, triggers: triggers, in: &$0) },
                { await partyRegenHeal(actor: actor, triggers: triggers, in: &$0) },
                { hoardArmorBlock(actor: actor, triggers: triggers, in: &$0) },
            ]
            for step in steps {
                guard !context.isBattleOver else { return }
                guard context.health(of: actor) > 0 else { break }
                await step(&context)
            }
        }
    }

    private static func endOfTurnBlockConversion(
        runtime: CombatantRuntime,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard triggers.unspentManaConvertsToBlock, runtime.maxMana > 0, runtime.currentMana > 0 else { return }
        let converted = min(runtime.currentMana, 6)
        emitBlock(.unspentManaConvertsToBlock, "Mana Shield", amount: converted, to: actor, source: actor, in: &context)
    }

    private static func hoardArmorBlock(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard triggers.blockPerGoldCollectedEvery > 0, context.gold > 0 else { return }
        let block = min(5, context.gold / triggers.blockPerGoldCollectedEvery)
        guard block > 0 else { return }
        emitBlock(.blockPerGoldCollectedEvery, "Hoard Armor", amount: block, to: actor, source: actor, in: &context)
    }

    private static func hibernationHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.endTurnWithBlockHealFlat > 0,
              DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor)) > 0
        else { return }
        let target = BattleActionContext(actor: actor, in: context).target(.lowestHealthAlly, in: context)
        guard context.roster.health(for: target) < context.roster.maxHealth(for: target) else { return }
        await emitHeal(
            .endTurnWithBlockHealFlat, "Hibernation",
            amount: triggers.endTurnWithBlockHealFlat, to: target, source: actor, in: &context,
        )
    }

    private static func campfireComfortHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.endOfTurnHealLowestAlly > 0,
              context.isPlayerTurn(every: 2, startingAt: 1)
        else { return }
        let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
        guard context.roster.health(for: lowest) < context.roster.maxHealth(for: lowest) else { return }
        await emitHeal(
            .endOfTurnHealLowestAlly, "Campfire Comfort",
            amount: triggers.endOfTurnHealLowestAlly, to: lowest, source: actor, in: &context,
        )
    }

    private static func partyRegenHeal(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.partyRegenPerRound > 0 else { return }

        for (_, member) in livingPartyMembers(in: context) {
            guard !context.isBattleOver, context.health(of: actor) > 0 else { break }
            guard member.currentHealth < member.maxHealth else { continue }
            await emitHeal(
                .partyRegenPerRound, "Regeneration",
                amount: triggers.partyRegenPerRound, to: member.combatant, source: actor, in: &context,
            )
        }
    }
}
