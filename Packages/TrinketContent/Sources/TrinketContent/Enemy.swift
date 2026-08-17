import Foundation
import TrinketCore

public struct Enemy: Identifiable, Hashable, Sendable {
    public static let fallbackMaxHealth: Int = 12

    public let combatant: Combatant
    public let traitID: String
    public let isBoss: Bool
    public let faction: EnemyFaction

    public init(
        combatant: Combatant,
        traitID: String,
        isBoss: Bool = false,
        faction: EnemyFaction = .mortal
    ) {
        self.combatant = combatant
        self.traitID = traitID
        self.isBoss = isBoss
        self.faction = faction
    }

    public var id: String {
        combatant.id
    }

    public var name: String {
        combatant.name
    }

    public var maxHealth: Int {
        combatant.maxHealth
    }

    public static var fallbackCombatant: Combatant {
        Combatant(
            id: "fallback-enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: fallbackMaxHealth,
            abilities: [.slash],
            growthArchetype: .bruiser
        )
    }
}
