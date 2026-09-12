import Foundation
import TrinketContent
import TrinketCore

package struct DamageProvenance: Equatable, Hashable, Sendable {
    let actionID: Int
    let cardID: Int?
}

public struct DamageRequest: Equatable, Hashable, Sendable {
    public var amount: Int
    public var target: Combatant
    public var keyword: Keyword?
    public var sourceActorID: String?
    public var options: DamageOperation
    package var provenance: DamageProvenance?

    public init(
        amount: Int,
        target: Combatant,
        keyword: Keyword? = nil,
        sourceActorID: String? = nil,
        options: DamageOperation = .attack(),
    ) {
        self.amount = amount
        self.target = target
        self.keyword = keyword
        self.sourceActorID = sourceActorID
        self.options = options
    }

    public static func directAbilityHit(
        amount: Int,
        target: Combatant,
        keyword: Keyword,
        sourceActorID: String,
    ) -> Self {
        Self(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: DamageOperation.attack(),
        )
    }

    public static func doTTick(
        amount: Int,
        target: Combatant,
        keyword: Keyword,
        sourceActorID: String?,
    ) -> Self {
        Self(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .periodic,
        )
    }
}

enum HealLogPolicy: Equatable, Hashable {
    case silent
    case instantHeal(actorName: String, abilityName: String, keyword: Keyword)
}

public enum HealingOrigin: Equatable, Hashable, Sendable {
    case restoration(Keyword)
    case leech
    case reaction
    case periodic

    var criticalKeyword: Keyword? {
        switch self {
        case let .restoration(keyword): keyword
        case .leech: .leech
        case .periodic: .health
        case .reaction: nil
        }
    }
}

public struct HealRequest: Equatable, Hashable, Sendable {
    enum AmountBasis: Equatable, Hashable, Sendable {
        case base, resolved
    }

    public var amount: Int
    public var target: Combatant
    public var sourceActorID: String?
    public let origin: HealingOrigin
    var logAs: HealLogPolicy
    var revivesIfDead: Bool
    var skipFightPacing: Bool

    public init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
        origin: HealingOrigin = .reaction,
    ) {
        self.init(
            amount: amount,
            target: target,
            sourceActorID: sourceActorID,
            origin: origin,
            logAs: .silent,
        )
    }

    init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
        origin: HealingOrigin = .reaction,
        logAs: HealLogPolicy,
        revivesIfDead: Bool = false,
        skipFightPacing: Bool = false,
    ) {
        self.amount = amount
        self.target = target
        self.sourceActorID = sourceActorID
        self.origin = origin
        self.logAs = logAs
        self.revivesIfDead = revivesIfDead
        self.skipFightPacing = skipFightPacing
    }

    var isHoTTick: Bool {
        origin == .periodic
    }

    var isDirectCardHeal = false
    var amountBasis: AmountBasis = .base
}
