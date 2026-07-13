import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

/// Active Skill ability-art callout anchored to a caster card.
struct SkillCalloutPresentation: Equatable, Identifiable {
    let id: Int
    let actorID: String
    let abilityID: String
    let abilityName: String
    let keyword: Keyword
    let expiresAt: Date
}

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
    let skipArmedAt: Date
}

enum BattleSpectaclePolicy {
    /// Hero/Companion Ultimates take the full-screen cinematic path.
    static func shouldPresentUltimateCinematic(for event: ActionEvent, heroID: String, companionID: String) -> Bool {
        guard event.kind == .ability, event.abilityTier == .ultimate else { return false }
        return event.actorID == heroID || event.actorID == companionID
    }

    static func shouldPresentSkillCallout(for event: ActionEvent) -> Bool {
        event.kind == .ability && event.abilityTier == .skill
    }

    /// Enemy Ultimates use the Skill callout treatment (no full-screen).
    static func shouldPresentEnemyUltimateAsCallout(for event: ActionEvent, heroID: String, companionID: String) -> Bool {
        guard event.kind == .ability, event.abilityTier == .ultimate else { return false }
        return event.actorID != heroID && event.actorID != companionID
    }
}
