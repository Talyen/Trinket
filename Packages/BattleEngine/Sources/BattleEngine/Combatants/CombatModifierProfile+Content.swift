import TrinketContent

public extension AffixModifier {
    func apply(to profile: inout CombatModifierProfile) {
        profile.merge(self)
    }
}

public extension CombatTraitTriggers {
    func apply(to profile: inout CombatModifierProfile) {
        profile.triggers.merge(self)
    }

    func apply(to profile: inout CombatModifierProfile, abilityName: String) {
        apply(to: &profile)
        for key in populatedFieldNames {
            profile.setTriggerAbilityName(key, abilityName)
        }
    }
}

public extension CombatantTraitDefinition {
    func apply(to profile: inout CombatModifierProfile) {
        for modifier in modifiers {
            profile.merge(modifier)
        }
        triggers.apply(to: &profile, abilityName: name)
    }
}

public extension CombatantTalentEffect {
    func apply(to profile: inout CombatModifierProfile) {
        profile.merge(modifiers)
        triggers.apply(to: &profile, abilityName: name)
    }
}

public extension CombatantTalentCatalog {
    static func profile(for unlockedNodeIDs: Set<String>) -> CombatModifierProfile {
        var profile = CombatModifierProfile.zero
        for nodeID in unlockedNodeIDs.sorted() {
            signatureTalents[nodeID]?.apply(to: &profile)
        }
        return profile
    }
}
