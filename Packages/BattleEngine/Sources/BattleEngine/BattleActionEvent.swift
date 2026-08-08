import Foundation
import TrinketContent
import TrinketCore

/// A single observable event emitted during a battle tick. Rendered as
/// floating text in the UI and reduced into combat-log lines by
/// `BattleLogReducer`.
public struct ActionEvent: Identifiable, Equatable {
    public enum Kind: Equatable {
        case ability
        case abilityDamage
        case status
        case effect
        case milestone
    }

    public enum Milestone: Equatable {
        case battleStarted
        case enemyDefeated
        case partyDefeated
    }

    public enum EffectKind: Equatable, Sendable {
        case instantHeal
        case resourceGain
        case cardsDrawn
        case leechHeal
        case shieldApplied
        case shieldAbsorbed
        case controlActionSkipped
        case controlApplied
        case controlTriggered
        case cleanseApplied
        case purgeApplied
        case dodgeApplied
        case leechApplied
        case shieldHalved
        case deathsDoorTriggered
        case deathsDoorExpired
        case thornsApplied
        case thornsTriggered
        case markedApplied
        case markedConsumed
        case criticalChanceApplied
        case manaShieldApplied
        case manaShieldTriggered
        case damageKeywordOverrideApplied
        case nextHolyStrikeApplied
        case nextStrikeDoubleApplied
        case evadeNextHitApplied
    }

    public let id: Int
    /// Stable correlation for every event emitted while resolving one action.
    public let actionID: Int
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
    /// Exact critical attribution for resolved ability-damage components.
    public let isCritical: Bool

    public init(
        id: Int,
        actionID: Int = 0,
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
        milestone: Milestone? = nil,
        isCritical: Bool = false
    ) {
        self.id = id
        self.actionID = actionID
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
        self.isCritical = isCritical
    }

    public var damage: Int {
        amount
    }

    public var damageType: Keyword {
        keyword
    }

    /// Returns a copy with the given fields replaced; omitted fields keep their
    /// values. All fields are enumerated here so adding a field to `ActionEvent`
    /// forces this helper (and not distant call sites) to be updated.
    ///
    /// `effectKind` uses nil-means-unchanged, so this helper cannot reset an
    /// effect event back to `nil`; call sites that need that build a fresh event.
    public func with(
        effectKind: EffectKind? = nil,
        actorID: String? = nil,
        actorName: String? = nil,
        abilityName: String? = nil,
        amount: Int? = nil
    ) -> Self {
        Self(
            id: id,
            actionID: actionID,
            kind: kind,
            effectKind: effectKind ?? self.effectKind,
            actorID: actorID ?? self.actorID,
            actorName: actorName ?? self.actorName,
            abilityID: abilityID,
            abilityName: abilityName ?? self.abilityName,
            abilityTier: abilityTier,
            targetID: targetID,
            targetName: targetName,
            amount: amount ?? self.amount,
            keyword: keyword,
            appliedEffectSummaries: appliedEffectSummaries,
            milestone: milestone,
            isCritical: isCritical
        )
    }
}

/// A human-readable line in the combat log.
public struct LogEntry: Identifiable, Equatable {
    public let id: Int
    public let text: String
}
