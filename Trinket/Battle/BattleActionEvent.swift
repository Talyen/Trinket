import Foundation

/// A single observable event emitted during a battle tick. Rendered as
/// floating text in the UI and recorded for combat log replay.
struct ActionEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case ability
        case status
        case effect
    }

    enum EffectKind: Equatable {
        case instantHeal
        case resourceGain
        case leechHeal
        case shieldApplied
        case mitigationApplied
        case shieldAbsorbed
        case preventionSkipped
        case preventionApplied
        case preventionTriggered
        case cleanseApplied
        case dodgeApplied
    }

    let id: Int
    let kind: Kind
    let effectKind: EffectKind?
    let actorName: String
    let abilityName: String
    let targetID: String
    let targetName: String
    let amount: Int
    let keyword: Keyword

    var damage: Int {
        amount
    }

    var damageType: Keyword {
        keyword
    }
}

/// A human-readable line in the combat log.
struct LogEntry: Identifiable, Equatable {
    let id: Int
    let text: String
}
