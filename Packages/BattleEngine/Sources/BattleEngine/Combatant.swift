import Foundation
import TrinketCore
import TrinketContent

public struct CombatantProgression: Equatable, Hashable, Codable, Sendable {
    public let level: Int
    public let currentXP: Int
    public let requiredXP: Int

    public static let initial = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

    public init(level: Int, currentXP: Int, requiredXP: Int) {
        self.level = level
        self.currentXP = currentXP
        self.requiredXP = requiredXP
    }

    public var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
    }

    public func unlocks(_ tier: AbilityTier) -> Bool {
        level >= tier.unlockLevel
    }

    public func addingExperience(_ amount: Int) -> CombatantProgression {
        guard amount > 0 else { return self }

        var nextLevel = level
        var nextXP = currentXP + amount
        var nextRequiredXP = requiredXP

        while nextRequiredXP > 0, nextXP >= nextRequiredXP {
            nextXP -= nextRequiredXP
            nextLevel += 1
            nextRequiredXP += 50
        }

        return CombatantProgression(
            level: nextLevel,
            currentXP: nextXP,
            requiredXP: nextRequiredXP
        )
    }
}

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
        primaryStats: PrimaryStats = PrimaryStats()
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.maxMana = maxMana
        self.actionIntervalTicks = actionIntervalTicks
        self.abilityChoices = abilityChoices
        self.primaryStats = primaryStats
    }

    public init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        maxMana: Int = 0,
        actionIntervalTicks: Int? = nil,
        abilities: [Ability],
        primaryStats: PrimaryStats = PrimaryStats()
    ) {
        self.init(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTicks: actionIntervalTicks,
            abilityChoices: AbilityChoices(abilities: abilities),
            primaryStats: primaryStats
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
            primaryStats: primaryStats
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
            primaryStats: primaryStats
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
