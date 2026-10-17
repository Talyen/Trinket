import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func partyAuraDamageBonus(
        for state: DamageResolutionState,
        source: CombatantRuntime,
        damageKeyword: Keyword,
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState,
    ) -> Int {
        var bonus = 0
        if source.role != .enemy, state.options.isAttackHit {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, enrageAuraBonus(in: context))
        }
        let companion = context.roster.companion.combatant
        let companionFullHealth = source.role != .enemy && context.roster.companion.isAlive
            && context.roster.maxHealth(for: companion) > 0
            && context.roster.health(for: companion) == context.roster.maxHealth(for: companion)
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(
            for: damageKeyword,
            triggers: context.modifiers(for: source.id).triggers,
        )
        forEachLivingAllyModifier(in: context) { profile in
            let triggers = profile.triggers
            if source.role == .companion {
                if targetIsPoisoned {
                    bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.companionDamageVsPoisonedBonus)
                }
                if targetIsBurning {
                    bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.companionDamageVsBurningBonus)
                }
            }
            if source.role != .enemy, damageKeyword == .physical || sharedKeyword == .physical,
               triggers.partyPhysicalDamageBonusFirstTurns > 0,
               context.turnCount < triggers.partyPhysicalDamageBonusFirstTurnCount {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.partyPhysicalDamageBonusFirstTurns)
            }
            if companionFullHealth {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.partyDamageBonusWhileCompanionFullHealth)
                if damageKeyword == .holy {
                    bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.partyHolyDamageBonusWhileCompanionFullHealth)
                }
            }
            if state.options.isBasicAttackHit, source.role != .enemy, damageKeyword == .holy {
                bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.partyBasicAttackHolyBonus)
            }
        }
        return bonus
    }

    private static func enrageAuraBonus(in context: BattleState) -> Int {
        var bonus = 0
        for (combatant, profile) in livingAllies(in: context) {
            let aura = profile.triggers
            if aura.partyAllStatsBonusBelowHealthAmount > 0,
               context.roster.maxHealth(for: combatant) > 0 {
                let percent = Double(context.roster.health(for: combatant))
                    / Double(context.roster.maxHealth(for: combatant))
                if percent < aura.partyAllStatsBonusBelowHealthThreshold {
                    bonus = SaturatedArithmetic.saturatingAdd(bonus, aura.partyAllStatsBonusBelowHealthAmount)
                }
            }
        }
        return bonus
    }

    static func partyAfflictedDamageMultiplier(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState,
    ) -> Double {
        var excess = 0.0
        forEachAfflictedAura(targetIsPoisoned: targetIsPoisoned, targetIsBurning: targetIsBurning, in: context) { multiplier, _, _ in
            excess += multiplier - 1
        }
        return 1 + excess
    }

    static func partyAfflictedDamageNames(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState,
    ) -> [String] {
        var names: [String] = []
        forEachAfflictedAura(targetIsPoisoned: targetIsPoisoned, targetIsBurning: targetIsBurning, in: context) { _, key, profile in
            let name = profile.triggerAbilityName(key, fallback: "")
            if !name.isEmpty {
                names.append(name)
            }
        }
        return names
    }

    private static func forEachAfflictedAura(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState,
        apply: (Double, CombatTriggerField, CombatModifierProfile) -> Void,
    ) {
        forEachLivingAllyModifier(in: context) { profile in
            if targetIsPoisoned, profile.triggers.damageVsPoisonedMultiplier > 1 {
                apply(profile.triggers.damageVsPoisonedMultiplier, .damageVsPoisonedMultiplier, profile)
            }
            if targetIsBurning, profile.triggers.damageVsBurningMultiplier > 1 {
                apply(profile.triggers.damageVsBurningMultiplier, .damageVsBurningMultiplier, profile)
            }
        }
    }
}
