import Foundation
import TrinketContent
import TrinketCore

extension BattleCardCombatEngine {
    /// True when a party-owned card presents a real outcome choice: two or
    /// more branches whose effective outcomes still differ under current battle
    /// conditions. Conditional riders that make every branch equivalent (e.g.
    /// Bounty Shot while the enemy is Marked) collapse into a normal play.
    public static func requiresBranchChoice(
        ability: Ability,
        actor: Combatant,
        in context: BattleState
    ) -> Bool {
        guard actor.role != .enemy,
              let branches = ability.outcomeBranches, branches.count > 1
        else { return false }
        let signatures = branches.map { effectiveOutcomeSignature($0, actor: actor, in: context) }
        return Set(signatures).count > 1
    }

    private static func effectiveOutcomeSignature(
        _ branch: AbilityOutcomeBranch,
        actor: Combatant,
        in context: BattleState
    ) -> String {
        var tokens: [String] = []
        for component in branch.damageComponents {
            let met = isConditionMet(component.condition, actor: actor, in: context)
            let amount = component.amount + (met ? component.bonusAmount : 0)
            guard amount > 0 else { continue }
            tokens.append("d|\(component.target)|\(component.keyword)|\(amount)")
        }
        for effect in branch.targetedEffects
            where isConditionMet(effect.condition, actor: actor, in: context) {
            tokens.append("e|\(effect.target)|\(effect.effect)")
        }
        return tokens.sorted().joined(separator: ";")
    }

    private static func isConditionMet(
        _ condition: DamageCondition?,
        actor: Combatant,
        in context: BattleState
    ) -> Bool {
        guard let condition else { return true }
        return BattleConditionEvaluator.isMet(
            condition,
            actor: actor,
            enemy: context.enemy,
            hero: context.roster.hero.combatant,
            companion: context.roster.companion.combatant,
            context: context
        )
    }
}
