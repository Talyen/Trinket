import Foundation

struct BattleVictorySummary: Equatable {
    let stageGold: Int
    let battleGold: Int
    let experience: Int
    let heroName: String
    let petName: String
    let itemNames: [String]

    var totalGold: Int {
        stageGold + battleGold
    }
}
