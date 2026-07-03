import Foundation
import TrinketCore

public struct Combatant: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case hero = "Hero"
        case pet = "Pet"
        case enemy = "Enemy"
    }

    public let id: String
    public let name: String
    public let role: Role
    public let maxHealth: Int
    public let maxMana: Int
    public let actionIntervalTicks: Int?
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
        actionIntervalTicks: Int? = nil,
        abilityChoices: AbilityChoices,
        primaryStats: PrimaryStats = PrimaryStats(),
        growthArchetype: GrowthArchetype = .bruiser
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.maxMana = maxMana
        self.actionIntervalTicks = actionIntervalTicks
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
        actionIntervalTicks: Int? = nil,
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
            actionIntervalTicks: actionIntervalTicks,
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

    public func withAbilityLoadout(_ loadout: AbilityLoadout) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTicks: actionIntervalTicks,
            abilityChoices: abilityChoices.withSelectedLoadout(loadout),
            primaryStats: primaryStats,
            growthArchetype: growthArchetype
        )
    }

    public func withAbilityLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTicks: actionIntervalTicks,
            abilityChoices: abilityChoices.withSelectedLoadoutPreservingEmptyTiers(loadout),
            primaryStats: primaryStats,
            growthArchetype: growthArchetype
        )
    }
}

public extension Combatant.Role {
    public var fallbackArtSymbolName: String {
        switch self {
        case .hero:
            return "person.fill"
        case .pet:
            return "pawprint.fill"
        case .enemy:
            return "flame.fill"
        }
    }
}
