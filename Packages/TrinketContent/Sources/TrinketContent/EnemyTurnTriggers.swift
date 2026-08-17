import Foundation
import TrinketCore

/// The `enemyTurn` trigger family of `CombatTraitTriggers`.
public struct EnemyTurnTriggers: Equatable, Hashable, Sendable {
    public var negateFirstEnemyAttack: Bool = false
    public var negateFirstEnemyAttackPerRound: Bool = false
    public var negateFirstEnemyAttackChance: Double = 0
    public var attackDelayEnemyTurnChancePercent: Double = 0
    public var bleedingEnemyActionSkipChancePercent: Double = 0
    public var extraCardDrawWhileEnemyBleeding: Bool = false
    public var onDefeatEnemyExtraAction: Bool = false
    public var extraCardDrawBelowEnemyHealthPercent: Double = 0
    public var onDefeatBleedingEnemyResetActionTimer: Bool = false
    public var ultimateAppliesBurnPotency: Int = 0
    public var onHeroHolyAbilityCompanionHolyDamage: Int = 0
    public var onHolyDamageRestoreMana: Int = 0
    public var burnReducesEnemyHealingAndLeechPercent: Double = 0

    public init(
        negateFirstEnemyAttack: Bool = false,
        negateFirstEnemyAttackPerRound: Bool = false,
        negateFirstEnemyAttackChance: Double = 0,
        attackDelayEnemyTurnChancePercent: Double = 0,
        bleedingEnemyActionSkipChancePercent: Double = 0,
        extraCardDrawWhileEnemyBleeding: Bool = false,
        onDefeatEnemyExtraAction: Bool = false,
        extraCardDrawBelowEnemyHealthPercent: Double = 0,
        onDefeatBleedingEnemyResetActionTimer: Bool = false,
        ultimateAppliesBurnPotency: Int = 0,
        onHeroHolyAbilityCompanionHolyDamage: Int = 0,
        onHolyDamageRestoreMana: Int = 0,
        burnReducesEnemyHealingAndLeechPercent: Double = 0
    ) {
        self.negateFirstEnemyAttack = negateFirstEnemyAttack
        self.negateFirstEnemyAttackPerRound = negateFirstEnemyAttackPerRound
        self.negateFirstEnemyAttackChance = negateFirstEnemyAttackChance
        self.attackDelayEnemyTurnChancePercent = attackDelayEnemyTurnChancePercent
        self.bleedingEnemyActionSkipChancePercent = bleedingEnemyActionSkipChancePercent
        self.extraCardDrawWhileEnemyBleeding = extraCardDrawWhileEnemyBleeding
        self.onDefeatEnemyExtraAction = onDefeatEnemyExtraAction
        self.extraCardDrawBelowEnemyHealthPercent = extraCardDrawBelowEnemyHealthPercent
        self.onDefeatBleedingEnemyResetActionTimer = onDefeatBleedingEnemyResetActionTimer
        self.ultimateAppliesBurnPotency = ultimateAppliesBurnPotency
        self.onHeroHolyAbilityCompanionHolyDamage = onHeroHolyAbilityCompanionHolyDamage
        self.onHolyDamageRestoreMana = onHolyDamageRestoreMana
        self.burnReducesEnemyHealingAndLeechPercent = burnReducesEnemyHealingAndLeechPercent
    }
}

extension EnemyTurnTriggers {
    mutating func merge(_ other: Self) {
        negateFirstEnemyAttack = negateFirstEnemyAttack || other.negateFirstEnemyAttack
        negateFirstEnemyAttackPerRound = negateFirstEnemyAttackPerRound || other.negateFirstEnemyAttackPerRound
        negateFirstEnemyAttackChance = max(negateFirstEnemyAttackChance, other.negateFirstEnemyAttackChance)
        attackDelayEnemyTurnChancePercent += other.attackDelayEnemyTurnChancePercent
        bleedingEnemyActionSkipChancePercent += other.bleedingEnemyActionSkipChancePercent
        extraCardDrawWhileEnemyBleeding = extraCardDrawWhileEnemyBleeding || other.extraCardDrawWhileEnemyBleeding
        onDefeatEnemyExtraAction = onDefeatEnemyExtraAction || other.onDefeatEnemyExtraAction
        extraCardDrawBelowEnemyHealthPercent = max(extraCardDrawBelowEnemyHealthPercent, other.extraCardDrawBelowEnemyHealthPercent)
        onDefeatBleedingEnemyResetActionTimer = onDefeatBleedingEnemyResetActionTimer || other.onDefeatBleedingEnemyResetActionTimer
        ultimateAppliesBurnPotency += other.ultimateAppliesBurnPotency
        onHeroHolyAbilityCompanionHolyDamage += other.onHeroHolyAbilityCompanionHolyDamage
        onHolyDamageRestoreMana += other.onHolyDamageRestoreMana
        burnReducesEnemyHealingAndLeechPercent += other.burnReducesEnemyHealingAndLeechPercent
    }
}

extension EnemyTurnTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            negateFirstEnemyAttack: values.decode(Bool.self, "negateFirstEnemyAttack", default: false),
            negateFirstEnemyAttackPerRound: values.decode(Bool.self, "negateFirstEnemyAttackPerRound", default: false),
            negateFirstEnemyAttackChance: values.decode(Double.self, "negateFirstEnemyAttackChance", default: 0),
            attackDelayEnemyTurnChancePercent: values.decode(Double.self, "attackDelayEnemyTurnChancePercent", default: 0),
            bleedingEnemyActionSkipChancePercent: values.decode(Double.self, "bleedingEnemyActionSkipChancePercent", default: 0),
            extraCardDrawWhileEnemyBleeding: values.decode(Bool.self, "extraCardDrawWhileEnemyBleeding", default: false),
            onDefeatEnemyExtraAction: values.decode(Bool.self, "onDefeatEnemyExtraAction", default: false),
            extraCardDrawBelowEnemyHealthPercent: values.decode(Double.self, "extraCardDrawBelowEnemyHealthPercent", default: 0),
            onDefeatBleedingEnemyResetActionTimer: values.decode(Bool.self, "onDefeatBleedingEnemyResetActionTimer", default: false),
            ultimateAppliesBurnPotency: values.decode(Int.self, "ultimateAppliesBurnPotency", default: 0),
            onHeroHolyAbilityCompanionHolyDamage: values.decode(Int.self, "onHeroHolyAbilityCompanionHolyDamage", default: 0),
            onHolyDamageRestoreMana: values.decode(Int.self, "onHolyDamageRestoreMana", default: 0),
            burnReducesEnemyHealingAndLeechPercent: values.decode(Double.self, "burnReducesEnemyHealingAndLeechPercent", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(negateFirstEnemyAttack, "negateFirstEnemyAttack", default: false)
        try container.encodeNonDefault(negateFirstEnemyAttackPerRound, "negateFirstEnemyAttackPerRound", default: false)
        try container.encodeNonDefault(negateFirstEnemyAttackChance, "negateFirstEnemyAttackChance", default: 0)
        try container.encodeNonDefault(attackDelayEnemyTurnChancePercent, "attackDelayEnemyTurnChancePercent", default: 0)
        try container.encodeNonDefault(bleedingEnemyActionSkipChancePercent, "bleedingEnemyActionSkipChancePercent", default: 0)
        try container.encodeNonDefault(extraCardDrawWhileEnemyBleeding, "extraCardDrawWhileEnemyBleeding", default: false)
        try container.encodeNonDefault(onDefeatEnemyExtraAction, "onDefeatEnemyExtraAction", default: false)
        try container.encodeNonDefault(extraCardDrawBelowEnemyHealthPercent, "extraCardDrawBelowEnemyHealthPercent", default: 0)
        try container.encodeNonDefault(onDefeatBleedingEnemyResetActionTimer, "onDefeatBleedingEnemyResetActionTimer", default: false)
        try container.encodeNonDefault(ultimateAppliesBurnPotency, "ultimateAppliesBurnPotency", default: 0)
        try container.encodeNonDefault(onHeroHolyAbilityCompanionHolyDamage, "onHeroHolyAbilityCompanionHolyDamage", default: 0)
        try container.encodeNonDefault(onHolyDamageRestoreMana, "onHolyDamageRestoreMana", default: 0)
        try container.encodeNonDefault(burnReducesEnemyHealingAndLeechPercent, "burnReducesEnemyHealingAndLeechPercent", default: 0)
    }
}
