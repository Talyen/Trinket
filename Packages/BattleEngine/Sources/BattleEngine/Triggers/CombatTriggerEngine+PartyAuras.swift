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
            bonus += enrageAuraBonus(in: context)
        }
        let living = livingAllyModifiers(in: context)
        let companion = context.roster.companion.combatant
        let companionFullHealth = source.role != .enemy && context.roster.companion.isAlive
            && context.roster.maxHealth(for: companion) > 0
            && context.roster.health(for: companion) == context.roster.maxHealth(for: companion)
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(
            for: damageKeyword,
            triggers: context.modifiers(for: source.id).triggers,
        )
        for profile in living {
            let triggers = profile.triggers
            if source.role == .companion {
                if targetIsPoisoned {
                    bonus += triggers.companionDamageVsPoisonedBonus
                }
                if targetIsBurning {
                    bonus += triggers.companionDamageVsBurningBonus
                }
            }
            if source.role != .enemy, damageKeyword == .physical || sharedKeyword == .physical,
               triggers.partyPhysicalDamageBonusFirstTurns > 0,
               context.turnCount < triggers.partyPhysicalDamageBonusFirstTurnCount {
                bonus += triggers.partyPhysicalDamageBonusFirstTurns
            }
            if companionFullHealth {
                bonus += triggers.partyDamageBonusWhileCompanionFullHealth
                if damageKeyword == .holy {
                    bonus += triggers.partyHolyDamageBonusWhileCompanionFullHealth
                }
            }
            if state.options.isBasicAttackHit, source.role != .enemy, damageKeyword == .holy {
                bonus += triggers.partyBasicAttackHolyBonus
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
                    bonus += aura.partyAllStatsBonusBelowHealthAmount
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
        partyAfflictedDamageAuras(
            targetIsPoisoned: targetIsPoisoned,
            targetIsBurning: targetIsBurning,
            in: context,
        ).multiplier
    }

    static func partyAfflictedDamageAuras(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState,
    ) -> (multiplier: Double, abilityNames: [String]) {
        var excess = 0.0
        var names: [String] = []
        for profile in livingAllyModifiers(in: context) {
            if targetIsPoisoned {
                accumulateAfflictedAura(
                    multiplier: profile.triggers.damageVsPoisonedMultiplier,
                    key: "damageVsPoisonedMultiplier",
                    profile: profile,
                    excess: &excess,
                    names: &names,
                )
            }
            if targetIsBurning {
                accumulateAfflictedAura(
                    multiplier: profile.triggers.damageVsBurningMultiplier,
                    key: "damageVsBurningMultiplier",
                    profile: profile,
                    excess: &excess,
                    names: &names,
                )
            }
        }
        return (1 + excess, names)
    }

    private static func accumulateAfflictedAura(
        multiplier: Double,
        key: String,
        profile: CombatModifierProfile,
        excess: inout Double,
        names: inout [String],
    ) {
        guard multiplier > 1 else { return }
        excess += multiplier - 1
        let name = profile.triggerAbilityName(key, fallback: "")
        if !name.isEmpty {
            names.append(name)
        }
    }
}
