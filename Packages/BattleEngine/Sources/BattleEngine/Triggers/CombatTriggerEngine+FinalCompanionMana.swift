import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterFinalCompanionManaSpend(
        actor: Combatant,
        amountSpent: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amountSpent > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.selfManaSpendNextAttackBonus > 0 {
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextManaSpendAttackBonus = max(
                    $0.talents.pending.nextManaSpendAttackBonus,
                    triggers.selfManaSpendNextAttackBonus,
                )
                $0.talents.pending.nextManaSpendAttackPreparedCardSerial = serial
                $0.talents.pending.nextManaSpendAttackPreparedActionID = actionID
            }
        }
        guard triggers.firstManaSpendRefundPerTurn > 0,
              context.claimHeroTalent("Aetherial Surge", actorID: actor.id) else { return [] }
        return context.restoreManaEmitting(
            triggers.firstManaSpendRefundPerTurn,
            to: actor,
            abilityName: "Aetherial Surge",
        )
    }

    static func drawOnFinalCompanionManaRestoration(
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let chance = context.modifiers(for: actor.id).triggers.manaRestorationDrawChancePercent
        guard chance > 0, context.claimTalentAbility("Prismatic Spark", actorID: actor.id),
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return [] }
        return drawCards(1, for: owner, actor: actor, abilityName: "Prismatic Spark", in: &context)
    }
}
