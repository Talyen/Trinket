import Foundation

struct BattleCombatantPaneConfiguration: Identifiable {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let healthBarPlacement: BattleCombatantPane.HealthBarPlacement
    let events: [ActionEvent]

    var id: String {
        combatant.id
    }
}
