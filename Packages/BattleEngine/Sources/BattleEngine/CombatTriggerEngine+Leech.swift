import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterLeech(
        by actor: Combatant,
        target: Combatant?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        if triggers.leechRestoreManaFlat > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                context.paced(triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor,
                abilityName: triggerAbilityName("leechRestoreManaFlat", for: actor, fallback: "Siphoning", in: context),
            ))
        }

        if triggers.leechGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.leechGoldFlat,
                to: actor,
                abilityName: triggerAbilityName("leechGoldFlat", for: actor, fallback: "Blood Price", in: context),
            ))
        }

        guard let target, target.role == .enemy, context.roster.health(for: target) > 0 else { return events }
        if triggers.onLeechApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.onLeechApplyPoison,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
            ))
        }
        if triggers.onLeechApplyBleed > 0 {
            events.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.onLeechApplyBleed,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
        }
        if triggers.onLeechReduceEnemyStrength > 0 {
            context.appendEffect(
                .damageReductionFlat(
                    triggers.onLeechReduceEnemyStrength,
                    triggers.onLeechReduceEnemyStrengthTurns,
                ),
                to: target,
                sourceID: actor.id,
                remainingTurns: triggers.onLeechReduceEnemyStrengthTurns,
            )
        }

        return events
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        HealingEngine.shareHeroLeechWithCompanion(restored: restored, in: &context)
    }
}
