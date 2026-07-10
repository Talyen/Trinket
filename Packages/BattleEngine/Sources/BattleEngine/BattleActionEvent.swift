import Foundation
import TrinketContent
import TrinketCore

/// A single observable event emitted during a battle tick. Rendered as
/// floating text in the UI and reduced into combat-log lines by
/// `BattleLogReducer`.
public struct ActionEvent: Identifiable, Equatable {
    public enum Kind: Equatable {
        case ability
        case status
        case effect
        case milestone
    }

    public enum Milestone: Equatable {
        case battleStarted
        case enemyDefeated
        case partyDefeated
    }

    public enum EffectKind: Equatable {
        case instantHeal
        case resourceGain
        case cardsDrawn
        case leechHeal
        case shieldApplied
        case mitigationApplied
        case shieldAbsorbed
        case controlActionSkipped
        case controlApplied
        case controlTriggered
        case cleanseApplied
        case purgeApplied
        case dodgeApplied
        case criticalApplied
        case leechApplied
        case mitigationHalved
        case deathsDoorTriggered
        case deathsDoorExpired
        case hasteApplied
        case thornsApplied
        case thornsTriggered
        case markedApplied
        case markedConsumed
        case criticalChanceApplied
        case manaShieldApplied
        case manaShieldTriggered
        case damageKeywordOverrideApplied
        case nextHolyStrikeApplied
    }

    public let id: Int
    public let kind: Kind
    public let effectKind: EffectKind?
    public let actorID: String
    public let actorName: String
    public let abilityID: String
    public let abilityName: String
    public let abilityTier: AbilityTier?
    public let targetID: String
    public let targetName: String
    public let amount: Int
    public let keyword: Keyword
    public let appliedEffectSummaries: [String]
    public let milestone: Milestone?

    public init(
        id: Int,
        kind: Kind,
        effectKind: EffectKind? = nil,
        actorID: String = "",
        actorName: String,
        abilityID: String = "",
        abilityName: String,
        abilityTier: AbilityTier? = nil,
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
        self.actorID = actorID
        self.actorName = actorName
        self.abilityID = abilityID
        self.abilityName = abilityName
        self.abilityTier = abilityTier
        self.targetID = targetID
        self.targetName = targetName
        self.amount = amount
        self.keyword = keyword
        self.appliedEffectSummaries = appliedEffectSummaries
        self.milestone = milestone
    }

    public var damage: Int {
        amount
    }

    public var damageType: Keyword {
        keyword
    }
}

/// A human-readable line in the combat log.
public struct LogEntry: Identifiable, Equatable {
    public let id: Int
    public let text: String
}
