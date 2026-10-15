import Foundation
import TrinketContent
import TrinketCore

public struct ActionEvent: Identifiable, Equatable, Sendable {
    public enum Origin: Equatable, Sendable {
        case direct, automatic, periodic
    }

    /// Effect and milestone payloads belong to their kind, so every consumer
    /// sees the same meaning and emitted events cannot be partially retagged.
    public enum Kind: Equatable, Sendable {
        case ability
        case abilityDamage
        case status
        case effect(EffectOutcome)
        case milestone(Milestone)
    }

    public enum Milestone: Equatable, Sendable {
        case battleStarted(heroName: String, companionName: String)
        case enemyDefeated
        case partyDefeated
    }

    public enum EffectOutcome: Equatable, Sendable, CaseIterable {
        case instantHeal
        case overheal
        case resourceGain
        case cardsDrawn
        case leechHeal
        case partyDamagePreparationApplied
        case blockSpent
        case blockStripped
        case shieldApplied
        case shieldAbsorbed
        case damageReduced
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
        case playNextCardTwiceApplied
        case nextBurnBonusApplied
        case evadeNextHitApplied
        case wardApplied
        case dotAmplified
        case recurringDamageApplied
        case avatarApplied
        case hemorrhageApplied
        case hemorrhageTriggered
    }

    public let id: Int
    public let actionID: Int
    public let feedbackGroupID: Int
    public let origin: Origin
    public let isFullyBlocked: Bool
    public let kind: Kind
    public var effectKind: EffectOutcome? {
        guard case let .effect(outcome) = kind else { return nil }
        return outcome
    }

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
    public var milestone: Milestone? {
        guard case let .milestone(milestone) = kind else { return nil }
        return milestone
    }

    public let isCritical: Bool

    public init(
        id: Int,
        actionID: Int = 0,
        kind: Kind,
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
        isCritical: Bool = false,
        feedbackGroupID: Int? = nil,
        origin: Origin = .direct,
        isFullyBlocked: Bool = false,
    ) {
        self.id = id
        self.actionID = actionID
        self.feedbackGroupID = feedbackGroupID ?? actionID
        self.origin = origin
        self.isFullyBlocked = isFullyBlocked
        self.kind = kind
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
        self.isCritical = isCritical
    }

    public var damage: Int {
        amount
    }

    public var damageType: Keyword {
        keyword
    }

    public func with(
        actorID: String? = nil,
        actorName: String? = nil,
        abilityName: String? = nil,
        amount: Int? = nil,
        isCritical: Bool? = nil,
    ) -> Self {
        Self(
            id: id,
            actionID: actionID,
            kind: kind,
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
            isCritical: isCritical ?? self.isCritical,
            feedbackGroupID: feedbackGroupID,
            origin: origin,
            isFullyBlocked: isFullyBlocked,
        )
    }
}

public struct LogEntry: Identifiable, Equatable {
    public let id: Int
    public let text: String
}
