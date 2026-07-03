import Foundation
import TrinketCore
import TrinketContent

/// Tunable damage-resolution switches for a single `DamageRequest`.
public struct DamageOptions: Equatable, Hashable, Sendable {
    public var applyStatBonus: Bool
    public var applyItemBonus: Bool
    public var applyDodge: Bool

    public init(
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true
    ) {
        self.applyStatBonus = applyStatBonus
        self.applyItemBonus = applyItemBonus
        self.applyDodge = applyDodge
    }

    /// Direct ability hit: full bonuses and dodge checks.
    public static let directAbilityHit = DamageOptions()

    /// DoT tick: no dodge or stat bonus at resolution time (potency may already include bonuses).
    public static let doTTick = DamageOptions(
        applyStatBonus: false,
        applyItemBonus: true,
        applyDodge: false
    )
}

/// Describes one damage application through the combat pipeline.
public struct DamageRequest: Equatable, Hashable, Sendable {
    public var amount: Int
    public var target: Combatant
    public var keyword: Keyword?
    public var sourceActorID: String?
    public var options: DamageOptions

    public init(
        amount: Int,
        target: Combatant,
        keyword: Keyword? = nil,
        sourceActorID: String? = nil,
        options: DamageOptions = .directAbilityHit
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
        sourceActorID: String
    ) -> DamageRequest {
        DamageRequest(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .directAbilityHit
        )
    }

    public static func doTTick(
        amount: Int,
        target: Combatant,
        keyword: Keyword,
        sourceActorID: String?
    ) -> DamageRequest {
        DamageRequest(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .doTTick
        )
    }
}

/// Controls whether `resolveHeal` emits combat-log events. Handlers with
/// custom log lines use `.silent` until `HealingEngine` owns formatting.
public enum HealLogPolicy: Equatable, Hashable, Sendable {
    case silent
    case leech
}

/// Describes one heal application.
public struct HealRequest: Equatable, Hashable, Sendable {
    public var amount: Int
    public var target: Combatant
    public var sourceActorID: String?
    public var logAs: HealLogPolicy

    public init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
        logAs: HealLogPolicy = .silent
    ) {
        self.amount = amount
        self.target = target
        self.sourceActorID = sourceActorID
        self.logAs = logAs
    }
}
