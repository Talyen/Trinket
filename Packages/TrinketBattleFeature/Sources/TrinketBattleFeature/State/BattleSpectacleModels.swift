import BattleEngine
import Foundation
import TrinketCore

struct BattleUltimateInFramePresentation: Equatable, Identifiable {
    let id: Int
    let actorID: String
    let actorName: String
    let abilityID: String
    let abilityName: String
    let keyword: Keyword
    let startedAt: Date
}

enum BattleSpectaclePolicy {
    static func shouldPresentUltimateHighlight(for event: ActionEvent, heroID: String, companionID: String) -> Bool {
        guard event.kind == .ability, event.abilityTier == .ultimate else { return false }
        return event.actorID == heroID || event.actorID == companionID
    }
}
