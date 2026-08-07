import Foundation
import TrinketContent

public extension CombatTraitTriggers {
    func apply(to profile: inout CombatModifierProfile) {
        profile.triggers.merge(self)
    }
}

public extension CombatantTraitDefinition {
    func apply(to profile: inout CombatModifierProfile) {
        for modifier in modifiers {
            profile.merge(modifier)
        }
        triggers.apply(to: &profile)
    }
}
