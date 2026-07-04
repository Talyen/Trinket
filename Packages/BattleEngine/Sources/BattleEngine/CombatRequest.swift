import Foundation
import TrinketCore
import TrinketContent

/// Tunable damage-resolution switches for a single `DamageRequest`.
public struct DamageOptions: Equatable, Hashable, Sendable {
    public var applyStatBonus: Bool
    public var applyItemBonus: Bool
    public var applyDodge: Bool
    public var abilityCriticalChanceBonus: Double
    public var guaranteedCriticalIfEnemyBuffed: Bool

    public init(
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false
    ) {
        self.applyStatBonus = applyStatBonus
        self.applyItemBonus = applyItemBonus
        self.applyDodge = applyDodge
        self.abilityCriticalChanceBonus = abilityCriticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
    }

    /// Direct ability hit: full bonuses and dodge checks.
    public static let directAbilityHit = DamageOptions()

    /// DoT tick: stat and item bonuses at resolution time; no dodge.
    public static let doTTick = DamageOptions(
        applyStatBonus: true,
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

/// Controls whether `HealingEngine.resolveHeal` emits combat-log events.
public enum HealLogPolicy: Equatable, Hashable, Sendable {
    case silent
    case leech
    case instantHeal(actorName: String, abilityName: String, keyword: Keyword, displayAmount: Int)
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
