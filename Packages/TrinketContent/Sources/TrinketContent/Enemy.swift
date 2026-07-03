import Foundation
import TrinketCore

public struct Enemy: Identifiable, Hashable, Sendable {
    public static let defaultMaxHealth: Int = 35
    public static let defaultLevel: Int = 1

    public let combatant: Combatant
    public let isBoss: Bool
    public let level: Int

    public init(
        combatant: Combatant,
        isBoss: Bool = false,
        level: Int = Enemy.defaultLevel
    ) {
        self.combatant = combatant
        self.isBoss = isBoss
        self.level = level
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
            maxHealth: defaultMaxHealth,
            abilities: [.slash]
        )
    }
}
