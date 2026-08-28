import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func afterHolyDamageDealt(
        to enemy: Combatant,
        source: Combatant,
        isAttackHit: Bool = true,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: source.id)
        var events: [ActionEvent] = []

        if profile.triggers.holyDamageBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.holyDamageBlockFlat,
                to: source,
                source: source,
                abilityName: triggerAbilityName("holyDamageBlockFlat", for: source, fallback: "Sanctum", in: context)
            ))
        }

        if profile.triggers.holyDamageCleanseCount > 0 {
            events.append(contentsOf: performRandomCleanses(
                source: source,
                target: source,
                count: profile.triggers.holyDamageCleanseCount,
                abilityName: triggerAbilityName("holyDamageCleanseCount", for: source, fallback: "Absolving", in: context),
                in: &context
            ))
        }

        if profile.triggers.holyDamageHealFlat > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: profile.triggers.holyDamageHealFlat,
                target: source,
                source: source,
                abilityName: triggerAbilityName("holyDamageHealFlat", for: source, fallback: "Beacon", in: context)
            ))
        }

        if profile.triggers.holyDamageHealLowestAllyFlat > 0 {
            let lowest = BattleConditionEvaluator.lowestHealthAlly(in: context)
            let blessingName = triggerAbilityName(
                "holyDamageHealLowestAllyFlat",
                for: source,
                fallback: "Divine Blessing",
                in: context
            )
            events.append(contentsOf: context.healEmitting(
                amount: profile.triggers.holyDamageHealLowestAllyFlat,
                target: lowest,
                source: source,
                abilityName: blessingName
            ))
        }
        if profile.triggers.holyDamageHealHeroFlat > 0, context.roster.hero.isAlive {
            events.append(contentsOf: context.healEmitting(
                amount: profile.triggers.holyDamageHealHeroFlat,
                target: context.roster.hero.combatant,
                source: source,
                abilityName: triggerAbilityName("holyDamageHealHeroFlat", for: source, fallback: "Sun Glyph", in: context)
            ))
        }

        if profile.triggers.onHolyDamageRestoreMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                profile.triggers.onHolyDamageRestoreMana,
                to: source,
                abilityName: triggerAbilityName("onHolyDamageRestoreMana", for: source, fallback: "Radiant Wisdom", in: context)
            ))
        }
        if profile.triggers.holyDamageNextHitBonus > 0 {
            context.roster.mutateRuntime(for: source) {
                $0.pendingNextHitBonus += profile.triggers.holyDamageNextHitBonus
            }
        }
        if profile.triggers.holyDamageNextAttackHolyBonus > 0 {
            context.roster.mutateRuntime(for: source) {
                $0.pendingNextAttackHolyBonus += profile.triggers.holyDamageNextAttackHolyBonus
            }
        }
        if profile.triggers.holyDamageTargetMissNextAttack,
           isAttackHit,
           context.roster.health(for: enemy) > 0 {
            context.prependEffect(.evadeNextHit, to: enemy, remainingTurns: 0)
        }
        if profile.triggers.holyDamageReduceTargetDamage > 0, context.roster.health(for: enemy) > 0 {
            context.appendEffect(
                .damageReductionFlat(profile.triggers.holyDamageReduceTargetDamage, 1),
                to: enemy,
                sourceID: source.id,
                remainingTurns: 1
            )
        }
        if profile.triggers.holyDamagePurgeAll, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: source,
                abilityName: triggerAbilityName("holyDamagePurgeAll", for: source, fallback: "Purifying Light", in: context),
                count: 0,
                purgeAll: true,
                in: &context
            ))
        }
        if profile.triggers.onHolyDamagePartyBlock > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                events.append(contentsOf: context.applyBlock(
                    profile.triggers.onHolyDamagePartyBlock,
                    to: member.combatant,
                    source: source,
                    abilityName: triggerAbilityName("onHolyDamagePartyBlock", for: source, fallback: "Radiant Barrier", in: context)
                ))
            }
        }

        if profile.triggers.holyDamagePurgeCount > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: source,
                abilityName: triggerAbilityName("holyDamagePurgeCount", for: source, fallback: "Nullifying", in: context),
                count: profile.triggers.holyDamagePurgeCount,
                purgeAll: false,
                in: &context
            ))
        }

        if profile.triggers.holyDamagePoisonFlat > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: profile.triggers.holyDamagePoisonFlat,
                    target: enemy,
                    keyword: .poison,
                    sourceActorID: source.id,
                    options: .flatReaction
                )
            ).events)
        }

        return events
    }
}
