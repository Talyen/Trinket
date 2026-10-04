import TrinketContent
import TrinketCore

extension ControlMeterEngine {
    static func adjustedCharge(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Int {
        var adjustedAmount = amount
        if keyword == .freeze, combatant.role == .enemy, let sourceActorID {
            let multiplier = context.modifiers(for: sourceActorID).triggers.freezeBuildupMultiplier
            if multiplier > 1 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: multiplier)
            }
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID,
           context.roster.hasAffliction(.poison, on: combatant) {
            let sourceMultiplier = context.modifiers(for: sourceActorID).triggers.poisonedEnemyStunBuildupMultiplier
            let heroMultiplier = context.roster.hero.isAlive
                ? context.heroModifiers.triggers.poisonedEnemyStunBuildupMultiplier : 1
            let multiplier = max(sourceMultiplier, heroMultiplier)
            if multiplier > 1 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: multiplier)
            }
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           source.currentHealth * 2 < source.maxHealth {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount,
                multiplier: context.modifiers(for: sourceActorID).triggers.stunBuildupBelowHalfMultiplier,
            )
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount, multiplier: context.modifiers(for: sourceActorID).triggers.stunBuildupMultiplier,
            )
        }
        if keyword == .freeze, combatant.role == .enemy, let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           context.roster.runtime(for: source.combatant)?.talents.action.empoweredByMana == true {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount,
                multiplier: context.modifiers(for: sourceActorID).triggers.manaEmpowerFreezeBuildupMultiplier,
            )
        }
        if keyword == .stun || keyword == .freeze {
            let targetTriggers = context.modifiers(for: combatant.id).triggers
            let steadfastResistance = targetTriggers.blockedControlBurnResistance > 0
                && DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0
                ? targetTriggers.blockedControlBurnResistance
                : 0
            let lichboneResistance = keyword == .stun ? targetTriggers.afflictionResistance : 0
            let partyResistance: Double = switch combatant.role {
            case .hero, .companion: 0.25
            case .enemy: 0
            }
            let controlResistance = 1 - (1 - partyResistance) * (1 - steadfastResistance) * (1 - lichboneResistance)
            if controlResistance > 0 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: 1 - min(1, controlResistance))
            }
        }
        return adjustedAmount
    }
}
