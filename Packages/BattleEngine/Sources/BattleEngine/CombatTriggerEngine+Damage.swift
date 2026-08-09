import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBleedApplied(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.combatant(for: sourceActorID) != nil else { return [] }
        let profile = context.modifiers(for: sourceActorID)
        var events: [ActionEvent] = []

        if profile.triggers.onBleedApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.triggers.onBleedApplyPoison,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
        }

        if profile.triggers.onBleedDealBurnDamage > 0 {
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: profile.triggers.onBleedDealBurnDamage,
                keyword: .burn,
                target: target,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        return events
    }

    static func afterDecayingDoTApplied(
        keyword: Keyword,
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard keyword == .burn else { return [] }
        let potency = context.modifiers(for: sourceActorID).triggers.onBurnApplyPoison
        guard potency > 0 else { return [] }
        return context.applyDecayingDoT(
            keyword: .poison,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            dealImmediateDamage: true,
            suppressAffixReactions: true
        )
    }

    static func damageBonus(
        for state: DamageResolutionState,
        in context: inout BattleState
    ) -> Int {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 0 }

        let profile = context.modifiers(for: sourceActorID)
        let targetIsFrozen = context.roster.hasControlStatus(for: state.combatant, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: state.combatant, keyword: .stun)
        let targetIsBurning = context.roster.activeEffects(for: state.combatant).contains {
            if case .burn = $0.effect {
                return true
            }
            return false
        }
        var bonus = 0

        if damageKeyword == .freeze, targetIsBurning {
            bonus += profile.triggers.freezeDamageWhileBurningBonus
        }
        // Shatter is an aura from hero gear: the enemy takes extra damage from party hits while Frozen.
        if source.role != .enemy, targetIsFrozen {
            bonus += context.heroModifiers.triggers.damageWhileTargetFrozenBonus
        }
        // Dazed is an aura from hero gear: the enemy takes extra damage from party hits while Stunned.
        if source.role != .enemy, targetIsStunned {
            bonus += context.heroModifiers.triggers.damageWhileTargetStunnedBonus
        }
        if profile.triggers.damageBelowHealthPercentBonus > 0,
           profile.triggers.damageBelowHealthPercentKeyword == nil || profile.triggers.damageBelowHealthPercentKeyword == damageKeyword,
           profile.triggers.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: state.combatant) > 0 {
            let percent = Double(context.roster.health(for: state.combatant)) /
                Double(context.roster.maxHealth(for: state.combatant))
            if percent < profile.triggers.damageBelowHealthPercentThreshold {
                bonus += profile.triggers.damageBelowHealthPercentBonus
            }
        }

        // Direct ability hits only — DoT ticks also run with applyItemBonus and
        // would otherwise spend the dodge bonus on end-of-round status damage.
        if state.qualifiesForAmbush,
           let runtime = context.roster.runtime(for: source.combatant),
           runtime.pendingDamageAfterDodge > 0 {
            bonus += runtime.pendingDamageAfterDodge
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageAfterDodge = 0 }
        }

        return bonus
    }

    static func afterStunDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.stunDamageBlockFlat
        guard amount > 0 else { return [] }
        return context.applyBlock(
            amount,
            to: source,
            source: source,
            abilityName: traitName(for: source, fallback: .oathbound, in: context)
        )
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.burnDamageHealFlat
        guard amount > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: source,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: traitName(for: source, fallback: .bloodfire, in: context),
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        ).events
    }

    static func afterHolyDamageDealt(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: source.id)
        var events: [ActionEvent] = []

        if profile.triggers.holyDamageBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.holyDamageBlockFlat,
                to: source,
                source: source,
                abilityName: affixName(.sanctum)
            ))
        }

        if profile.triggers.holyDamageCleanseCount > 0 {
            var effects = context.roster.activeEffects(for: source)
            for _ in 0 ..< profile.triggers.holyDamageCleanseCount {
                guard let removedKeyword = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) else {
                    break
                }
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cleanseApplied,
                    actorName: source.name,
                    abilityName: affixName(.absolving),
                    target: source,
                    amount: 0,
                    keyword: removedKeyword
                ))
            }
            context.roster.setActiveEffects(effects, for: source)
        }

        if profile.triggers.holyDamageHealFlat > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: profile.triggers.holyDamageHealFlat,
                    target: source,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: affixName(.beacon),
                        keyword: .health,
                        displayAmount: profile.triggers.holyDamageHealFlat
                    )
                ),
                in: &context
            ).events)
        }

        if profile.triggers.holyDamagePurgeCount > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: source,
                abilityName: affixName(.nullifying),
                count: profile.triggers.holyDamagePurgeCount,
                purgeAll: false,
                in: &context
            ))
        }

        return events
    }

    static func afterCriticalHit(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard source.role != .enemy else { return [] }
        let profile = context.modifiers(for: source.id)
        var events = applyPurge(
            to: enemy,
            source: source,
            abilityName: affixName(.unmaking),
            count: profile.triggers.criticalPurgeCount,
            purgeAll: profile.triggers.criticalPurgeAll,
            in: &context
        )

        if profile.triggers.criticalGoldFlat > 0 {
            events.append(context.grantGoldEvent(
                profile.triggers.criticalGoldFlat,
                to: source,
                abilityName: traitName(for: source, fallback: .cutpurse, in: context)
            ))
        }

        return events
    }
}
