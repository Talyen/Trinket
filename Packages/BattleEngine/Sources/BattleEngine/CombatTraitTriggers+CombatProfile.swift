import Foundation
import TrinketContent

public extension CombatTraitTriggers {
    public func apply(to profile: inout CombatModifierProfile) {
        profile.cleanseBonusHeal += cleanseBonusHeal
        profile.gainGoldBonusHealSelf += gainGoldBonusHealSelf
        profile.restoreHealthAlsoHealHero += restoreHealthAlsoHealHero
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
