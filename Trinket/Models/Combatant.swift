import SwiftUI

struct CombatantProgression: Equatable, Hashable {
    let level: Int
    let currentXP: Int
    let requiredXP: Int

    static let initial = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)

    var progressFraction: Double {
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(currentXP) / Double(requiredXP), 0), 1)
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
    let abilityChoices: AbilityChoices

    init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        abilityChoices: AbilityChoices
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.abilityChoices = abilityChoices
    }

    init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        abilities: [Ability]
    ) {
        self.init(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            abilityChoices: AbilityChoices(abilities: abilities)
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
            abilityChoices: abilityChoices.withSelectedLoadout(loadout)
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
