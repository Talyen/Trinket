import Foundation
import TrinketCore

public struct Enemy: Identifiable, Hashable, Sendable {
    public static let fallbackMaxHealth: Int = 12

    public let combatant: Combatant
    public let positiveTraitID: String
    public let negativeTraitID: String
    public let isBoss: Bool

    public init(
        combatant: Combatant,
        positiveTraitID: String,
        negativeTraitID: String,
        isBoss: Bool = false
    ) {
        self.combatant = combatant
        self.positiveTraitID = positiveTraitID
        self.negativeTraitID = negativeTraitID
        self.isBoss = isBoss
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
