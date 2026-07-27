import Foundation
import TrinketCore

public struct Combatant: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case hero = "Hero"
        case companion = "Companion"
        case enemy = "Enemy"
    }

    public let id: String
    public let name: String
    public let role: Role
    public let maxHealth: Int
    public let maxMana: Int
    public let actionIntervalTurns: Int?
    public let abilityChoices: AbilityChoices
    public let primaryStats: PrimaryStats
    public let growthArchetype: GrowthArchetype

    public var hasMana: Bool {
        maxMana > 0
    }

    public init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        maxMana: Int = 0,
        actionIntervalTurns: Int? = nil,
        abilityChoices: AbilityChoices,
        primaryStats: PrimaryStats = PrimaryStats(),
        growthArchetype: GrowthArchetype = .bruiser
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.maxMana = maxMana
        self.actionIntervalTurns = actionIntervalTurns
        self.abilityChoices = abilityChoices
        self.primaryStats = primaryStats
        self.growthArchetype = growthArchetype
    }

    public init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        maxMana: Int = 0,
        actionIntervalTurns: Int? = nil,
        abilities: [Ability],
        primaryStats: PrimaryStats = PrimaryStats(),
        growthArchetype: GrowthArchetype = .bruiser
    ) {
        self.init(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilityChoices: AbilityChoices(abilities: abilities),
            primaryStats: primaryStats,
            growthArchetype: growthArchetype
        )
    }

    public var abilityLoadout: AbilityLoadout {
        abilityChoices.selected
    }

    public var abilities: [Ability] {
        abilityLoadout.abilities
    }

    public func withAbilityLoadout(_ loadout: AbilityLoadout) -> Self {
        replacing(abilityChoices: abilityChoices.withSelectedLoadout(loadout))
    }

    public func withAbilityLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> Self {
        replacing(abilityChoices: abilityChoices.withSelectedLoadoutPreservingEmptyTiers(loadout))
    }

    public func withPrimaryStats(_ primaryStats: PrimaryStats) -> Self {
        replacing(primaryStats: primaryStats)
    }

    private func replacing(
        abilityChoices: AbilityChoices? = nil,
        primaryStats: PrimaryStats? = nil
    ) -> Self {
        Self(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilityChoices: abilityChoices ?? self.abilityChoices,
            primaryStats: primaryStats ?? self.primaryStats,
            growthArchetype: growthArchetype
        )
    }
}
