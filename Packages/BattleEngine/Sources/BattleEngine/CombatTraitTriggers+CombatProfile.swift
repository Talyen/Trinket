import Foundation
import TrinketContent

public extension CombatTraitTriggers {
    public func apply(to profile: inout CombatModifierProfile) {
        profile.cleanseBonusHeal += cleanseBonusHeal
        profile.gainGoldBonusHealSelf += gainGoldBonusHealSelf
        profile.restoreHealthAlsoHealHero += restoreHealthAlsoHealHero
        profile.controlResistancePercent += controlResistancePercent
        profile.dodgeChanceBonus += dodgeChanceBonus
        profile.physicalDodgeChanceBonus += physicalDodgeChanceBonus
        profile.ambushBonusDamage += ambushBonusDamage
        profile.regenerationAmount += regenerationAmount
        profile.regenerationIntervalTicks = max(profile.regenerationIntervalTicks, regenerationIntervalTicks)
        profile.passiveArmorPercent += passiveArmorPercent
        profile.thornsPercent += thornsPercent
        profile.cannotBeHealed = profile.cannotBeHealed || cannotBeHealed
        profile.burnDecaySlowPercent += burnDecaySlowPercent
        if profile.shieldErosionKeyword == nil { profile.shieldErosionKeyword = shieldErosionKeyword }
        profile.shieldErosionTicks += shieldErosionTicks
        if profile.mitigationShredKeyword == nil { profile.mitigationShredKeyword = mitigationShredKeyword }
        profile.mitigationShredMultiplier = max(profile.mitigationShredMultiplier, mitigationShredMultiplier)
        profile.mitigationShredDurationTicks = max(
            profile.mitigationShredDurationTicks,
            mitigationShredDurationTicks
        )
        profile.freezeControlVulnerabilityPercent += freezeControlVulnerabilityPercent
        profile.armorEffectivenessPenaltyPercent += armorEffectivenessPenaltyPercent
        profile.graspingVinesHealBonus += graspingVinesHealBonus
        profile.leechHealingMultiplier *= leechHealingMultiplier
        profile.hemorrhageBleedBonus += hemorrhageBleedBonus
    }
}

public extension CombatantTraitDefinition {
    public func apply(to profile: inout CombatModifierProfile) {
        for modifier in modifiers {
            profile.merge(modifier)
        }
        triggers.apply(to: &profile)
    }
}
