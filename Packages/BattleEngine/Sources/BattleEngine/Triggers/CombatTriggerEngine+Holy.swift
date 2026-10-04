import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
        events.append(contentsOf: reviveCompanionIfNeeded(to: enemy, source: source, in: &context))

        if profile.triggers.holyDamageBlockFlat > 0, context.health(of: source) > 0 {
            events.append(contentsOf: emitBlock(
                "holyDamageBlockFlat", "Sanctum",
                amount: profile.triggers.holyDamageBlockFlat, to: source, source: source, in: &context,
            ))
        }
        if attackHit, sourceHadNoBlock, profile.triggers.holyAttackBlockIfNone > 0, context.health(of: source) > 0 {
            events.append(contentsOf: emitBlock(
                "holyAttackBlockIfNone", "Hallowguard",
                amount: profile.triggers.holyAttackBlockIfNone, to: source, source: source, in: &context,
            ))
        }

        if profile.triggers.holyDamageCleanseCount > 0, context.health(of: source) > 0 {
            events.append(contentsOf: performRandomCleanses(
                source: source,
                target: source,
                count: profile.triggers.holyDamageCleanseCount,
                abilityName: triggerAbilityName("holyDamageCleanseCount", for: source, fallback: "Absolving", in: context),
                in: &context,
            ))
        }

        if profile.triggers.holyDamageHealFlat > 0, context.health(of: source) > 0 {
            let target = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
            events.append(contentsOf: emitHeal(
                "holyDamageHealFlat", "Beacon",
                amount: profile.triggers.holyDamageHealFlat, to: target, source: source, in: &context,
            ))
        }

        if profile.triggers.holyDamageHealLowestAllyFlat > 0, context.health(of: source) > 0 {
            let lowest = BattleActionContext(actor: source, selectedTarget: enemy).target(.lowestHealthAlly, in: context)
            events.append(contentsOf: emitHeal(
                "holyDamageHealLowestAllyFlat", "Divine Blessing",
                amount: profile.triggers.holyDamageHealLowestAllyFlat, to: lowest, source: source, in: &context,
            ))
        }
        if profile.triggers.holyDamageHealHeroFlat > 0, context.health(of: source) > 0, context.roster.hero.isAlive {
            events.append(contentsOf: emitHeal(
                "holyDamageHealHeroFlat", "Sun Glyph",
                amount: profile.triggers.holyDamageHealHeroFlat,
                to: context.roster.hero.combatant, source: source, in: &context,
            ))
        }

        if profile.triggers.onHolyDamageRestoreMana > 0, context.health(of: source) > 0 {
            events.append(contentsOf: emitMana(
                "onHolyDamageRestoreMana", "Radiant Wisdom",
                amount: profile.triggers.onHolyDamageRestoreMana, to: source, in: &context,
            ))
        }
        if context.health(of: source) > 0,
           profile.triggers.holyDamageNextHitBonus > 0 || profile.triggers.holyDamageNextAttackHolyBonus > 0 {
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
        if profile.triggers.onHolyDamagePartyBlock > 0, context.health(of: source) > 0 {
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

    private static func reviveCompanionIfNeeded(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard enemy.role == .enemy, context.health(of: source) > 0, !context.roster.companion.isAlive,
              context.modifiers(for: source.id).triggers.holyDamageReviveCompanionChancePercent > 0
        else { return [] }
        let canRoll = !context.hasHeroCard(for: source.id)
            || context.claimHeroCardBonus("Divine Blessing", actorID: source.id)
        guard canRoll, BattleChance.succeeds(
            probability: context.modifiers(for: source.id).triggers.holyDamageReviveCompanionChancePercent,
            using: &context.rng,
        ) else { return [] }
        return context.reviveEmitting(
            context.roster.companion.combatant,
            health: 1,
            source: source,
            abilityName: "Divine Blessing",
        )
    }
}
