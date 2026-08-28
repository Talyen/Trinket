import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func partyAuraDamageBonus(
        for state: DamageResolutionState,
        source: CombatantRuntime,
        damageKeyword: Keyword,
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState
    ) -> Int {
        var bonus = 0
        bonus += enrageAuraBonus(in: context)
        let living = livingAllyModifiers(in: context)
        if source.role == .companion {
            if targetIsPoisoned {
                bonus += living.reduce(0) { $0 + $1.triggers.companionDamageVsPoisonedBonus }
            }
            if targetIsBurning {
                bonus += living.reduce(0) { $0 + $1.triggers.companionDamageVsBurningBonus }
            }
        }
        if source.role != .enemy, damageKeyword == .physical {
            for profile in living {
                let triggers = profile.triggers
                if triggers.partyPhysicalDamageBonusFirstTurns > 0,
                   context.turnCount < triggers.partyPhysicalDamageBonusFirstTurnCount {
                    bonus += triggers.partyPhysicalDamageBonusFirstTurns
                }
            }
        }
        if source.role != .enemy, context.roster.companion.isAlive,
           context.roster.maxHealth(for: context.roster.companion.combatant) > 0,
           context.roster.health(for: context.roster.companion.combatant) == context.roster
           .maxHealth(for: context.roster.companion.combatant) {
            bonus += living.reduce(0) { $0 + $1.triggers.partyDamageBonusWhileCompanionFullHealth }
            if damageKeyword == .holy {
                bonus += living.reduce(0) { $0 + $1.triggers.partyHolyDamageBonusWhileCompanionFullHealth }
            }
        }
        if state.options.isBasicAttackHit, source.role != .enemy, damageKeyword == .holy {
            bonus += living.reduce(0) { $0 + $1.triggers.partyBasicAttackHolyBonus }
        }
        return bonus
    }

    private static func enrageAuraBonus(in context: BattleState) -> Int {
        var bonus = 0
        if context.roster.hero.isAlive {
            let aura = context.heroModifiers.triggers
            if aura.partyAllStatsBonusBelowHealthAmount > 0,
               context.roster.maxHealth(for: context.roster.hero.combatant) > 0 {
                let percent = Double(context.roster.health(for: context.roster.hero.combatant))
                    / Double(context.roster.maxHealth(for: context.roster.hero.combatant))
                if percent < aura.partyAllStatsBonusBelowHealthThreshold {
                    bonus += aura.partyAllStatsBonusBelowHealthAmount
                }
            }
        }
        if context.roster.companion.isAlive {
            let aura = context.companionModifiers.triggers
            if aura.partyAllStatsBonusBelowHealthAmount > 0,
               context.roster.maxHealth(for: context.roster.companion.combatant) > 0 {
                let percent = Double(context.roster.health(for: context.roster.companion.combatant))
                    / Double(context.roster.maxHealth(for: context.roster.companion.combatant))
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
        in context: BattleState
    ) -> Double {
        partyAfflictedDamageAuras(
            targetIsPoisoned: targetIsPoisoned,
            targetIsBurning: targetIsBurning,
            in: context
        ).multiplier
    }

    static func partyAfflictedDamageAuras(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState
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
                    names: &names
                )
            }
            if targetIsBurning {
                accumulateAfflictedAura(
                    multiplier: profile.triggers.damageVsBurningMultiplier,
                    key: "damageVsBurningMultiplier",
                    profile: profile,
                    excess: &excess,
                    names: &names
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
        names: inout [String]
    ) {
        guard multiplier > 1 else { return }
        excess += multiplier - 1
        let name = profile.triggerAbilityName(key, fallback: "")
        if !name.isEmpty {
            names.append(name)
        }
    }
}
