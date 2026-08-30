import Foundation
import TrinketContent
import TrinketCore

public struct DamageOptions: Equatable, Hashable, Sendable {
    public var applyStatBonus: Bool
    public var applyItemBonus: Bool
    public var applyDodge: Bool
    public var abilityCriticalChanceBonus: Double
    public var guaranteedCriticalIfEnemyBuffed: Bool
    public var guaranteedCritical: Bool
    public var isRetaliation: Bool
    public var applyControlMeter: Bool
    public var qualifiesForAmbush: Bool
    public var isAttackHit: Bool
    public var isBasicAttackHit: Bool
    public var abilityHasLeech: Bool
    public var isHealthCost: Bool
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
        causedByDodge: Bool = false,
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

    public static let directAbilityHit = Self(
        qualifiesForAmbush: true,
        isAttackHit: true,
    )

    public static let doTTick = Self(
        applyStatBonus: true,
        applyItemBonus: true,
        applyDodge: false,
        isRetaliation: true,
    )

    public static let healthCost = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isHealthCost: true,
    )

    package static let flatReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isRetaliation: true,
    )

    package static let flatControlReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: false,
        isRetaliation: true,
        applyControlMeter: true,
    )

    package static let dodgeTriggeredControlReaction = Self(
        applyStatBonus: false,
        applyItemBonus: false,
        applyDodge: true,
        isRetaliation: true,
        applyControlMeter: true,
        causedByDodge: true,
    )
}

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
        options: DamageOptions = .directAbilityHit,
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
            options: DamageOptions(qualifiesForAmbush: true, isAttackHit: true),
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
            options: .doTTick,
        )
    }
}

enum HealLogPolicy: Equatable, Hashable, Sendable {
    case silent
    case leech
    case instantHeal(actorName: String, abilityName: String, keyword: Keyword)
}

public struct HealRequest: Equatable, Hashable, Sendable {
    public var amount: Int
    public var target: Combatant
    public var sourceActorID: String?
    var logAs: HealLogPolicy
    var revivesIfDead: Bool
    var skipFightPacing: Bool

    public init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
    ) {
        self.init(
            amount: amount,
            target: target,
            sourceActorID: sourceActorID,
            logAs: .silent,
        )
    }

    init(
        amount: Int,
        target: Combatant,
        sourceActorID: String? = nil,
        logAs: HealLogPolicy,
        revivesIfDead: Bool = false,
        skipFightPacing: Bool = false,
        isHoTTick: Bool = false,
    ) {
        self.amount = amount
        self.target = target
        self.sourceActorID = sourceActorID
        self.logAs = logAs
        self.revivesIfDead = revivesIfDead
        self.skipFightPacing = skipFightPacing
        self.isHoTTick = isHoTTick
    }

    var isHoTTick: Bool
}
