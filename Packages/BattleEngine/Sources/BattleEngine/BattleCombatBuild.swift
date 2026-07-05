import Foundation
import TrinketCore
import TrinketContent

/// Snapshot of hero, pet, and enemy modifier profiles at battle start.
public struct BattleCombatBuild: Equatable {
    public let heroModifiers: CombatModifierProfile
    public let petModifiers: CombatModifierProfile
    public let enemyModifiers: CombatModifierProfile
    public let heroID: String
    public let petID: String
    public let enemyID: String

    public init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        heroModifiers: CombatModifierProfile,
        petModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile = .zero
    ) {
        let resolvedEnemy = enemy ?? Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: Enemy.fallbackMaxHealth,
            abilities: [.slash]
        )
        heroID = hero.id
        petID = pet.id
        enemyID = resolvedEnemy.id
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
    }

    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == heroID { return heroModifiers }
        if combatantID == petID { return petModifiers }
        if combatantID == enemyID { return enemyModifiers }
        return .zero
    }

    public func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer, durationTicks):
            return .shield(
                keyword,
                buffer + profile.blockGainedBonus,
                durationTicks + profile.blockDurationBonus
            )
        case let .mitigation(keyword, percent, durationTicks):
            return .mitigation(
                keyword,
                percent + profile.armorGainedBonus,
                durationTicks + profile.armorDurationBonus
            )
        case let .leech(keyword, percent, durationTicks):
            return .leech(
                keyword,
                percent + profile.leechGainedBonus,
                durationTicks + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }
}
