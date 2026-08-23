import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Party-aura damage from talents that may sit on the other combatant's profile.
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

    /// Enrage / Inspirational Vigor: while the talent owner is below the Health
    /// threshold, party attacks deal bonus damage.
    private static func enrageAuraBonus(in context: BattleState) -> Int {
        var bonus = 0
        for owner in [BattleParticipant.hero, .companion] {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
            let aura = context.modifiers(for: member.id).triggers
            guard aura.partyAllStatsBonusBelowHealthAmount > 0,
                  context.roster.maxHealth(for: member.combatant) > 0
            else { continue }
            let percent = Double(context.roster.health(for: member.combatant))
                / Double(context.roster.maxHealth(for: member.combatant))
            if percent < aura.partyAllStatsBonusBelowHealthThreshold {
                bonus += aura.partyAllStatsBonusBelowHealthAmount
            }
        }
        return bonus
    }

    /// Deadly Dose / Damnation / Intense Heat: living auras add their extra percents.
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
