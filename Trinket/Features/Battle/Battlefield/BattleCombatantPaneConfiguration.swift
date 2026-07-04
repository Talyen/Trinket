import BattleEngine
import Foundation
import TrinketContent

struct BattleCombatantPaneConfiguration: Identifiable {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let healthBarPlacement: BattleCombatantPane.HealthBarPlacement
    let events: [ActionEvent]

    var id: String {
        combatant.id
    }

    var hasMana: Bool {
        maxMana > 0
    }
}
