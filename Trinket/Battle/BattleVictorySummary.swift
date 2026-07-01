import Foundation

struct BattleVictorySummary: Equatable {
    let stageGold: Int
    let battleGold: Int
    let experience: Int
    let heroName: String
    let petName: String
    let itemNames: [String]
    let heroProgressionBefore: CombatantProgression
    let heroProgressionAfter: CombatantProgression
    let petProgressionBefore: CombatantProgression
    let petProgressionAfter: CombatantProgression

    var totalGold: Int {
        stageGold + battleGold
    }
}
