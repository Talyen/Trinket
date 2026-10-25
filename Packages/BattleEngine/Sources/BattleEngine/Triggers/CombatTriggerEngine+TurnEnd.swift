import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func atPlayerEndTurn(in context: inout BattleState) async {
        for owner in BattleParticipant.party {
            guard !context.isBattleOver else { return }
            let actor = context.roster[owner].combatant
            guard context.roster[owner].isAlive else { continue }
            let triggers = context.modifiers(for: actor.id).triggers
            let mana = context.roster[owner].currentMana
            if triggers.unspentManaConvertsToBlock, context.roster[owner].maxMana > 0, mana > 0 {
                emitBlock(.unspentManaConvertsToBlock, "Mana Shield", amount: min(mana, 6), to: actor, source: actor, in: &context)
            }
            if triggers.endTurnZeroManaCleanse, context.roster[owner].maxMana > 0, context.roster[owner].currentMana == 0 {
                await performRandomCleanses(source: actor, target: actor, count: 1, abilityName: "Arcane Cleansing", in: &context)
            }
            guard !context.isBattleOver, context.roster[owner].isAlive else { continue }
            await hibernationHeal(actor: actor, triggers: triggers, in: &context)
            guard !context.isBattleOver, context.roster[owner].isAlive else { continue }
            await campfireComfortHeal(actor: actor, triggers: triggers, in: &context)
            guard !context.isBattleOver, context.roster[owner].isAlive else { continue }
            await partyRegenHeal(actor: actor, triggers: triggers, in: &context)
            guard !context.isBattleOver, context.roster[owner].isAlive else { continue }
            hoardArmorBlock(actor: actor, triggers: triggers, in: &context)
        }
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
        let lowest = BattleActionContext(actor: actor, in: context).target(.lowestHealthAlly, in: context)
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
