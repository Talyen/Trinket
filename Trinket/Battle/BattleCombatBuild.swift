import Foundation

/// Snapshot of hero and pet item-modifier profiles at battle start. Affix
/// lookups during combat read from here instead of scattered modifier fields.
struct BattleCombatBuild: Equatable {
    let heroModifiers: CombatModifierProfile
    let petModifiers: CombatModifierProfile
    let heroID: String
    let petID: String

    init(
        hero: Combatant,
        pet: Combatant,
        heroModifiers: CombatModifierProfile,
        petModifiers: CombatModifierProfile
    ) {
        heroID = hero.id
        petID = pet.id
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
    }

    func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == heroID { return heroModifiers }
        if combatantID == petID { return petModifiers }
        return .zero
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer, durationTicks):
            return .shield(
                keyword,
                buffer + profile.blockGrantedBonus,
                durationTicks + profile.blockDurationBonus
            )
        case let .mitigation(keyword, percent, durationTicks):
            return .mitigation(
                keyword,
                percent + profile.armorGrantedBonus,
                durationTicks + profile.armorDurationBonus
            )
        case let .leech(keyword, percent, durationTicks):
            return .leech(
                keyword,
                percent + profile.leechGrantedBonus,
                durationTicks + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }
}
