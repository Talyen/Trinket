import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    private static func hallowguardBlock(
        for source: Combatant,
        amount: Int,
        attackHit: Bool,
        sourceHadNoBlock: Bool,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard attackHit, sourceHadNoBlock, amount > 0 else { return [] }
        return emitBlock(
            "holyAttackBlockIfNone", "Hallowguard",
            amount: amount, to: source, source: source, in: &context,
        )
    }

    // swiftlint:disable:next function_body_length - holy triggers share one ordered cadence
    static func afterHolyDamageDealt(
        to enemy: Combatant,
        source: Combatant,
        attackHit: Bool = false,
        sourceHadNoBlock: Bool = false,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: source.id)
        var events: [ActionEvent] = []
        if enemy.role == .enemy, !context.roster.companion.isAlive,
           profile.triggers.holyDamageReviveCompanionChancePercent > 0 {
            let canRoll = !context.hasHeroCard(for: source.id)
                || context.claimHeroCardBonus("Divine Blessing", actorID: source.id)
            if canRoll, BattleChance.succeeds(
                probability: profile.triggers.holyDamageReviveCompanionChancePercent,
                using: &context.rng,
            ) {
                events.append(contentsOf: context.reviveEmitting(
                    context.roster.companion.combatant,
                    health: 1,
                    source: source,
                    abilityName: "Divine Blessing",
                ))
            }
        }

        if profile.triggers.holyDamageBlockFlat > 0 {
            events.append(contentsOf: emitBlock(
                "holyDamageBlockFlat", "Sanctum",
                amount: profile.triggers.holyDamageBlockFlat, to: source, source: source, in: &context,
            ))
        }
        events.append(contentsOf: hallowguardBlock(
            for: source, amount: profile.triggers.holyAttackBlockIfNone,
            attackHit: attackHit, sourceHadNoBlock: sourceHadNoBlock, in: &context,
        ))

        if profile.triggers.holyDamageCleanseCount > 0 {
            events.append(contentsOf: performRandomCleanses(
                source: source,
                target: source,
                count: profile.triggers.holyDamageCleanseCount,
                abilityName: triggerAbilityName("holyDamageCleanseCount", for: source, fallback: "Absolving", in: context),
                in: &context,
            ))
        }

        if profile.triggers.holyDamageHealFlat > 0 {
            let target = BattleTargetResolver.lowestHealthAlly(for: source, in: context)
            events.append(contentsOf: emitHeal(
                "holyDamageHealFlat", "Beacon",
                amount: profile.triggers.holyDamageHealFlat, to: target, source: source, in: &context,
            ))
        }

        if profile.triggers.holyDamageHealLowestAllyFlat > 0 {
            let lowest = BattleTargetResolver.effectTarget(
                .lowestHealthAlly, actor: source, abilityTarget: enemy, in: context,
            )
            events.append(contentsOf: emitHeal(
                "holyDamageHealLowestAllyFlat", "Divine Blessing",
                amount: profile.triggers.holyDamageHealLowestAllyFlat, to: lowest, source: source, in: &context,
            ))
        }
        if profile.triggers.holyDamageHealHeroFlat > 0, context.roster.hero.isAlive {
            events.append(contentsOf: emitHeal(
                "holyDamageHealHeroFlat", "Sun Glyph",
                amount: profile.triggers.holyDamageHealHeroFlat,
                to: context.roster.hero.combatant, source: source, in: &context,
            ))
        }

        if profile.triggers.onHolyDamageRestoreMana > 0 {
            events.append(contentsOf: emitMana(
                "onHolyDamageRestoreMana", "Radiant Wisdom",
                amount: profile.triggers.onHolyDamageRestoreMana, to: source, in: &context,
            ))
        }
        if profile.triggers.holyDamageNextHitBonus > 0 || profile.triggers.holyDamageNextAttackHolyBonus > 0 {
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextHitBonus += profile.triggers.holyDamageNextHitBonus
                $0.talents.pending.nextAttackHolyBonus += profile.triggers.holyDamageNextAttackHolyBonus
            }
        }
        if profile.triggers.holyDamageReduceTargetDamage > 0, context.roster.health(for: enemy) > 0 {
            context.appendEffect(
                .damageReductionFlat(profile.triggers.holyDamageReduceTargetDamage, 1),
                to: enemy,
                sourceID: source.id,
                remainingTurns: 1,
            )
        }
        if profile.triggers.holyDamagePurgeAll, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: source,
                abilityName: triggerAbilityName("holyDamagePurgeAll", for: source, fallback: "Purifying Light", in: context),
                count: 0,
                purgeAll: true,
                in: &context,
            ))
        }
        if profile.triggers.onHolyDamagePartyBlock > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                events.append(contentsOf: emitBlock(
                    "onHolyDamagePartyBlock", "Radiant Barrier",
                    amount: profile.triggers.onHolyDamagePartyBlock,
                    to: member.combatant, source: source, in: &context,
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
                in: &context,
            ))
        }

        if profile.triggers.holyDamagePoisonFlat > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: profile.triggers.holyDamagePoisonFlat,
                    target: enemy,
                    keyword: .poison,
                    sourceActorID: source.id,
                    options: .reaction(),
                ),
            ).events)
        }

        return events
    }
}
