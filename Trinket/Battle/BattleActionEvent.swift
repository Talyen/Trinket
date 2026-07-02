import Foundation

/// A single observable event emitted during a battle tick. Rendered as
/// floating text in the UI and reduced into combat-log lines by
/// `BattleLogReducer`.
struct ActionEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case ability
        case status
        case effect
        case milestone
    }

    enum Milestone: Equatable {
        case battleStarted
        case enemyDefeated
        case partyDefeated
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
        case purgeApplied
        case dodgeApplied
        case leechApplied
        case mitigationHalved
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
    let appliedEffectSummaries: [String]
    let milestone: Milestone?

    init(
        id: Int,
        kind: Kind,
        effectKind: EffectKind? = nil,
        actorName: String,
        abilityName: String,
        targetID: String,
        targetName: String,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        milestone: Milestone? = nil
    ) {
        self.id = id
        self.kind = kind
        self.effectKind = effectKind
        self.actorName = actorName
        self.abilityName = abilityName
        self.targetID = targetID
        self.targetName = targetName
        self.amount = amount
        self.keyword = keyword
        self.appliedEffectSummaries = appliedEffectSummaries
        self.milestone = milestone
    }

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
