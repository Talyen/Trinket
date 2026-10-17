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
        case reaction(CombatReaction)
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

    public private(set) var actorID: String
    public private(set) var actorName: String
    public let abilityID: String
    public private(set) var abilityName: String
    public let abilityTier: AbilityTier?
    public let targetID: String
    public let targetName: String
    public private(set) var amount: Int
    public let keyword: Keyword
    public let appliedEffects: [Effect]
    public let stealsGold: Bool
    public var milestone: Milestone? {
        guard case let .milestone(milestone) = kind else { return nil }
        return milestone
    }

    public private(set) var isCritical: Bool

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
        appliedEffects: [Effect] = [],
        stealsGold: Bool = false,
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
        self.appliedEffects = appliedEffects
        self.stealsGold = stealsGold
        self.isCritical = isCritical
    }

    public func with(
        actorID: String? = nil,
        actorName: String? = nil,
        abilityName: String? = nil,
        amount: Int? = nil,
        isCritical: Bool? = nil,
    ) -> Self {
        var copy = self
        copy.actorID = actorID ?? self.actorID
        copy.actorName = actorName ?? self.actorName
        copy.abilityName = abilityName ?? self.abilityName
        copy.amount = amount ?? self.amount
        copy.isCritical = isCritical ?? self.isCritical
        return copy
    }
}
