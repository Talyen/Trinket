import SwiftUI

struct CombatantProgression: Equatable, Hashable, Codable {
    let level: Int
    let currentXP: Int
    let requiredXP: Int

    static let initial = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

    var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
    }

    func unlocks(_ tier: AbilityTier) -> Bool {
        level >= tier.unlockLevel
    }

    func addingExperience(_ amount: Int) -> CombatantProgression {
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

struct Combatant: Identifiable, Hashable {
    enum Role: String {
        case hero = "Hero"
        case pet = "Pet"
        case enemy = "Enemy"
    }

    let id: String
    let name: String
    let role: Role
    let maxHealth: Int
    let maxMana: Int
    let actionIntervalTicks: Int?
    let abilityChoices: AbilityChoices
    let primaryStats: PrimaryStats

    var hasMana: Bool {
        maxMana > 0
    }

    init(
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

    init(
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

    var abilityLoadout: AbilityLoadout {
        abilityChoices.selected
    }

    var abilities: [Ability] {
        abilityLoadout.abilities
    }

    func withAbilityLoadout(_ loadout: AbilityLoadout) -> Combatant {
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

    func withAbilityLoadoutPreservingEmptyTiers(_ loadout: AbilityLoadout) -> Combatant {
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

    var healthBarColor: Color {
        switch role {
        case .hero, .pet: return TrinketDesign.Colors.health
        case .enemy: return Color.red
        }
    }
}

extension Combatant.Role {
    var fallbackArtSymbolName: String {
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
