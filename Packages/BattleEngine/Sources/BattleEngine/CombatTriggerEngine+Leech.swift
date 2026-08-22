import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    // swiftlint:disable:next function_body_length
    static func afterLeech(
        by actor: Combatant,
        target: Combatant?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        if triggers.leechRestoreManaFlat > 0 {
            let restored = context.restoreMana(
                context.paced(triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor
            )
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: affixName(.siphoning),
                    target: actor,
                    amount: restored,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        if triggers.leechGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.leechGoldFlat,
                to: actor,
                abilityName: affixName(.bloodPrice)
            ))
        }

        // Combatant Talent System — on-Leech reactions against the target.
        guard let target, target.role == .enemy, context.roster.health(for: target) > 0 else { return events }
        // Toxic Touch / Necrotic Bleed: Leech applies Poison / Bleed.
        if triggers.onLeechApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.onLeechApplyPoison,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        if triggers.onLeechApplyBleed > 0 {
            events.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.onLeechApplyBleed,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context
            ))
        }
        // Weaken Soul: Leech reduces the target's Strength for 2 turns.
        if triggers.onLeechReduceEnemyStrength > 0 {
            context.appendEffect(
                .strengthReduction(
                    triggers.onLeechReduceEnemyStrength,
                    triggers.onLeechReduceEnemyStrengthTurns
                ),
                to: target,
                sourceID: actor.id,
                remainingTurns: triggers.onLeechReduceEnemyStrengthTurns
            )
        }

        return events
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = min(max(context.heroModifiers.triggers.companionLeechSharePercent, 0), 1)
        guard restored > 0,
              percent > 0,
              context.roster.companion.isAlive
        else { return [] }
        let share = max(1, CombatRounding.scaled(restored, multiplier: percent))
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: share,
                target: context.roster.companion.combatant,
                sourceActorID: context.roster.hero.id,
                logAs: .instantHeal(
                    actorName: context.roster.hero.name,
                    abilityName: affixName(.symbiosis),
                    keyword: .health
                )
            ),
            in: &context
        ).events
    }
}
