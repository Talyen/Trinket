import BattleEngine
import Foundation
import TrinketCore

/// Full-screen Ultimate cinematic for Hero/Companion casts.
struct BattleCinematicPresentation: Equatable, Identifiable {
    enum Phase: Equatable {
        case expanding
        case playing
        case collapsing
    }

    let id: Int
    let actorID: String
    let actorName: String
    let abilityID: String
    let abilityName: String
    let keyword: Keyword
    var phase: Phase
    let startedAt: Date
}

enum BattleSpectaclePolicy {
    /// Hero/Companion Ultimates take the full-screen cinematic path.
    static func shouldPresentUltimateCinematic(for event: ActionEvent, heroID: String, companionID: String) -> Bool {
        guard event.kind == .ability, event.abilityTier == .ultimate else { return false }
        return event.actorID == heroID || event.actorID == companionID
    }
}
