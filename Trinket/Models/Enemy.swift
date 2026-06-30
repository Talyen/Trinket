import Foundation

struct Enemy: Identifiable, Hashable {
    static let defaultMaxHealth: Int = 35
    static let defaultLevel: Int = 1

    let combatant: Combatant
    let isBoss: Bool
    let level: Int

    init(
        combatant: Combatant,
        isBoss: Bool = false,
        level: Int = Enemy.defaultLevel
    ) {
        self.combatant = combatant
        self.isBoss = isBoss
        self.level = level
    }

    var id: String {
        combatant.id
    }

    var name: String {
        combatant.name
    }

    var maxHealth: Int {
        combatant.maxHealth
    }

    static var randomNormalCombatant: Combatant {
        let normals = GameContent.enemies.filter { !$0.isBoss }
        return normals.randomElement()!.combatant
    }
}
