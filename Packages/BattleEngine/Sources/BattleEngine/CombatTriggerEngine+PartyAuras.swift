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
        if source.role == .companion {
            if targetIsPoisoned {
                bonus += context.heroModifiers.triggers.companionDamageVsPoisonedBonus
                bonus += context.companionModifiers.triggers.companionDamageVsPoisonedBonus
            }
            if targetIsBurning {
                bonus += context.heroModifiers.triggers.companionDamageVsBurningBonus
                bonus += context.companionModifiers.triggers.companionDamageVsBurningBonus
            }
        }
        if source.role != .enemy, damageKeyword == .physical {
            let heroTriggers = context.heroModifiers.triggers
            if heroTriggers.partyPhysicalDamageBonusFirstTurns > 0,
               context.turnCount < heroTriggers.partyPhysicalDamageBonusFirstTurnCount {
                bonus += heroTriggers.partyPhysicalDamageBonusFirstTurns
            }
            let compTriggers = context.companionModifiers.triggers
            if compTriggers.partyPhysicalDamageBonusFirstTurns > 0,
               context.turnCount < compTriggers.partyPhysicalDamageBonusFirstTurnCount {
                bonus += compTriggers.partyPhysicalDamageBonusFirstTurns
            }
        }
        if source.role != .enemy, context.roster.companion.isAlive,
           context.roster.maxHealth(for: context.roster.companion.combatant) > 0,
           context.roster.health(for: context.roster.companion.combatant) == context.roster
           .maxHealth(for: context.roster.companion.combatant) {
            bonus += context.heroModifiers.triggers.partyDamageBonusWhileCompanionFullHealth
            bonus += context.companionModifiers.triggers.partyDamageBonusWhileCompanionFullHealth
            if damageKeyword == .holy {
                bonus += context.heroModifiers.triggers.partyHolyDamageBonusWhileCompanionFullHealth
                bonus += context.companionModifiers.triggers.partyHolyDamageBonusWhileCompanionFullHealth
            }
        }
        if state.isBasicAttackHit, source.role != .enemy, damageKeyword == .holy {
            bonus += context.heroModifiers.triggers.partyBasicAttackHolyBonus
            bonus += context.companionModifiers.triggers.partyBasicAttackHolyBonus
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

    /// Deadly Dose / Damnation / Intense Heat: party-wide, strongest aura wins.
    static func partyAfflictedDamageMultiplier(
        targetIsPoisoned: Bool,
        targetIsBurning: Bool,
        in context: BattleState
    ) -> Double {
        var multiplier = 1.0
        if targetIsPoisoned {
            multiplier *= max(
                context.heroModifiers.triggers.damageVsPoisonedMultiplier,
                context.companionModifiers.triggers.damageVsPoisonedMultiplier
            )
        }
        if targetIsBurning {
            multiplier *= max(
                context.heroModifiers.triggers.damageVsBurningMultiplier,
                context.companionModifiers.triggers.damageVsBurningMultiplier
            )
        }
        return multiplier
    }
}
