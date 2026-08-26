import Foundation
import TrinketContent
import TrinketCore

/// Tunable damage-resolution switches for a single `DamageRequest`.
public struct DamageOptions: Equatable, Hashable, Sendable {
    public var applyStatBonus: Bool
    public var applyItemBonus: Bool
    public var applyDodge: Bool
    public var abilityCriticalChanceBonus: Double
    public var guaranteedCriticalIfEnemyBuffed: Bool
    /// When true, skip the crit roll and force a critical (ability next-strike buffs).
    public var guaranteedCritical: Bool
    /// When true, retaliation damage skips reactive on-hit effects (thorns ping-pong).
    public var isRetaliation: Bool
    /// When true, stun/freeze control meter still charges even though the hit is
    /// flagged `isRetaliation` (enemy per-turn control damage, e.g. Frostwarden).
    public var applyControlMeter: Bool
    /// When true, ambush trait bonus may apply on this damage (direct ability hits only).
    public var qualifiesForAmbush: Bool
    /// When true, this is a direct attack hit (ability/enemy strike) — not DoT, retaliation, or costs.
    /// On-hit wards (thorns, freeze-next-attacker) only fire for attack hits.
    public var isAttackHit: Bool
    /// When true, this is a direct basic-ability attack hit (basic card played).
    public var isBasicAttackHit: Bool
    /// When true, heal the attacker for `Effect.abilityLeechPercent` of health lost.
    public var abilityHasLeech: Bool
    /// When true, treat as a fixed "Lose N Health" cost — exact HP, no attack pipeline.
    public var isHealthCost: Bool
    /// When true, this hit was spawned from an on-dodge reaction. A dodge of this
    /// hit still applies, but does not run `afterDodge` again.
    public var causedByDodge: Bool

    public init(
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        guaranteedCritical: Bool = false,
        isRetaliation: Bool = false,
        applyControlMeter: Bool = false,
        qualifiesForAmbush: Bool = false,
        isAttackHit: Bool = false,
        isBasicAttackHit: Bool = false,
        abilityHasLeech: Bool = false,
        isHealthCost: Bool = false,
        causedByDodge: Bool = false
    ) {
        self.applyStatBonus = applyStatBonus
        self.applyItemBonus = applyItemBonus
        self.applyDodge = applyDodge
        self.abilityCriticalChanceBonus = abilityCriticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        self.guaranteedCritical = guaranteedCritical
        self.isRetaliation = isRetaliation
        self.applyControlMeter = applyControlMeter
        self.qualifiesForAmbush = qualifiesForAmbush
        self.isAttackHit = isAttackHit
        self.isBasicAttackHit = isBasicAttackHit
        self.abilityHasLeech = abilityHasLeech
        self.isHealthCost = isHealthCost
        self.causedByDodge = causedByDodge
    }

    /// Direct ability hit: full bonuses and dodge checks. Qualifies for ambush trait bonus.
    public static let directAbilityHit = Self(
        qualifiesForAmbush: true,
        isAttackHit: true
    )

    /// DoT tick: stat and item bonuses at resolution time; no dodge; not an attack hit.
    public static let doTTick = Self(
        applyStatBonus: true,
        applyItemBonus: true,
        applyDodge: false,
        isRetaliation: true
    )

    /// Authored "Lose N Health" cost: exact HP loss with no dodge/crit/mitigation/ambush.
    public static let healthCost = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isHealthCost: true
    )

    package static let flatReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isRetaliation: true
    )

    package static let flatControlReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isRetaliation: true,
        applyControlMeter: true
    )

    package static let dodgeTriggeredControlReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: true,
        isRetaliation: true,
        applyControlMeter: true,
        causedByDodge: true
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
    ) -> Self {
        Self(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: DamageOptions(qualifiesForAmbush: true, isAttackHit: true)
        )
    }

    public static func doTTick(
        amount: Int,
        target: Combatant,
        keyword: Keyword,
        sourceActorID: String?
    ) -> Self {
        Self(
            amount: amount,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: .doTTick
        )
    }
}

/// Controls whether `HealingEngine.resolveHeal` emits combat-log events.
enum HealLogPolicy: Equatable, Hashable, Sendable {
    case silent
    case leech
    case instantHeal(actorName: String, abilityName: String, keyword: Keyword)
}

/// Describes one heal application.
public struct HealRequest: Equatable, Hashable, Sendable {
    public var amount: Int
    public var target: Combatant
    public var sourceActorID: String?
    var logAs: HealLogPolicy
    /// When true, HealingEngine may restore a combatant at 0 Health (Phoenix Gift).
    var revivesIfDead: Bool
    var skipFightPacing: Bool

    public init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil
    ) {
        self.init(
            amount: amount,
            target: target,
            sourceActorID: sourceActorID,
            logAs: .silent
        )
    }

    init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
        logAs: HealLogPolicy,
        revivesIfDead: Bool = false,
        skipFightPacing: Bool = false,
        isHoTTick: Bool = false
    ) {
        self.amount = amount
        self.target = target
        self.sourceActorID = sourceActorID
        self.logAs = logAs
        self.revivesIfDead = revivesIfDead
        self.skipFightPacing = skipFightPacing
        self.isHoTTick = isHoTTick
    }

    /// When true, this heal is a Lingering Blessing HoT tick and must not re-arm HoT.
    var isHoTTick: Bool
}
