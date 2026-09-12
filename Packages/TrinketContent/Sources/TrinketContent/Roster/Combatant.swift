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
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maxHealth = maxHealth
        self.maxMana = maxMana
        self.actionIntervalTurns = actionIntervalTurns
        self.abilityChoices = abilityChoices
    }

    public init(
        id: String,
        name: String,
        role: Role,
        maxHealth: Int,
        maxMana: Int = 0,
        actionIntervalTurns: Int? = nil,
        abilities: [Ability],
    ) {
        self.init(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilityChoices: AbilityChoices(abilities: abilities),
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

    private func replacing(
        abilityChoices: AbilityChoices? = nil,
    ) -> Self {
        Self(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilityChoices: abilityChoices ?? self.abilityChoices,
        )
    }
}
