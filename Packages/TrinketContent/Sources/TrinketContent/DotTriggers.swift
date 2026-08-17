import Foundation
import TrinketCore

/// The `dot` trigger family of `CombatTraitTriggers`.
public struct DotTriggers: Equatable, Hashable, Sendable {
    public var burnDecaySlowPercent: Double = 0
    public var poisonDecaySlowPercent: Double = 0
    public var poisonDecayIncreaseChance: Double = 0
    public var onBleedApplyPoison: Int = 0
    public var onBurnApplyPoison: Int = 0
    public var onBleedDealBurnDamage: Int = 0
    public var hemorrhageBleedBonus: Int = 0
    public var freezeDamageWhileBurningBonus: Int = 0
    public var onBleedDamagePoisonTick: Int = 0
    public var onBleedAppliedToBleedingExtendTurns: Int = 0
    public var onBleedAppliedToBleedingDealDamage: Int = 0
    public var bleedsIgnoreMitigation: Bool = false
    public var onBleedDamageHealSelf: Int = 0
    public var onBurnTickHolyDamage: Int = 0
    public var burnTicksTwicePerTurn: Bool = false
    public var damagePerBurnPotencyPercent: Double = 0
    public var burnIncreaseChancePercent: Double = 0
    public var poisonThresholdStunAmount: Int = 0
    public var poisonDamageLeechPercent: Double = 0
    public var onCritDoubleBleedDuration: Bool = false
    public var criticalOnBleedingDetonateBleed: Bool = false
    public var onBurnDamageDetonateBleed: Bool = false
    public var freezeDamageLeech: Bool = false
    public var poisonDamageLeech: Bool = false
    public var bleedDamageGoldFlat: Int = 0
    public var burnDamageManaRestoreThreshold: Int = 0
    public var onBurnDamageRestoreManaPerTurnCap: Int = 0

    public init(
        burnDecaySlowPercent: Double = 0,
        poisonDecaySlowPercent: Double = 0,
        poisonDecayIncreaseChance: Double = 0,
        onBleedApplyPoison: Int = 0,
        onBurnApplyPoison: Int = 0,
        onBleedDealBurnDamage: Int = 0,
        hemorrhageBleedBonus: Int = 0,
        freezeDamageWhileBurningBonus: Int = 0,
        onBleedDamagePoisonTick: Int = 0,
        onBleedAppliedToBleedingExtendTurns: Int = 0,
        onBleedAppliedToBleedingDealDamage: Int = 0,
        bleedsIgnoreMitigation: Bool = false,
        onBleedDamageHealSelf: Int = 0,
        onBurnTickHolyDamage: Int = 0,
        burnTicksTwicePerTurn: Bool = false,
        damagePerBurnPotencyPercent: Double = 0,
        burnIncreaseChancePercent: Double = 0,
        poisonThresholdStunAmount: Int = 0,
        poisonDamageLeechPercent: Double = 0,
        onCritDoubleBleedDuration: Bool = false,
        criticalOnBleedingDetonateBleed: Bool = false,
        onBurnDamageDetonateBleed: Bool = false,
        freezeDamageLeech: Bool = false,
        poisonDamageLeech: Bool = false,
        bleedDamageGoldFlat: Int = 0,
        burnDamageManaRestoreThreshold: Int = 0,
        onBurnDamageRestoreManaPerTurnCap: Int = 0
    ) {
        self.burnDecaySlowPercent = burnDecaySlowPercent
        self.poisonDecaySlowPercent = poisonDecaySlowPercent
        self.poisonDecayIncreaseChance = poisonDecayIncreaseChance
        self.onBleedApplyPoison = onBleedApplyPoison
        self.onBurnApplyPoison = onBurnApplyPoison
        self.onBleedDealBurnDamage = onBleedDealBurnDamage
        self.hemorrhageBleedBonus = hemorrhageBleedBonus
        self.freezeDamageWhileBurningBonus = freezeDamageWhileBurningBonus
        self.onBleedDamagePoisonTick = onBleedDamagePoisonTick
        self.onBleedAppliedToBleedingExtendTurns = onBleedAppliedToBleedingExtendTurns
        self.onBleedAppliedToBleedingDealDamage = onBleedAppliedToBleedingDealDamage
        self.bleedsIgnoreMitigation = bleedsIgnoreMitigation
        self.onBleedDamageHealSelf = onBleedDamageHealSelf
        self.onBurnTickHolyDamage = onBurnTickHolyDamage
        self.burnTicksTwicePerTurn = burnTicksTwicePerTurn
        self.damagePerBurnPotencyPercent = damagePerBurnPotencyPercent
        self.burnIncreaseChancePercent = burnIncreaseChancePercent
        self.poisonThresholdStunAmount = poisonThresholdStunAmount
        self.poisonDamageLeechPercent = poisonDamageLeechPercent
        self.onCritDoubleBleedDuration = onCritDoubleBleedDuration
        self.criticalOnBleedingDetonateBleed = criticalOnBleedingDetonateBleed
        self.onBurnDamageDetonateBleed = onBurnDamageDetonateBleed
        self.freezeDamageLeech = freezeDamageLeech
        self.poisonDamageLeech = poisonDamageLeech
        self.bleedDamageGoldFlat = bleedDamageGoldFlat
        self.burnDamageManaRestoreThreshold = burnDamageManaRestoreThreshold
        self.onBurnDamageRestoreManaPerTurnCap = onBurnDamageRestoreManaPerTurnCap
    }
}

extension DotTriggers {
    mutating func merge(_ other: Self) {
        burnDecaySlowPercent += other.burnDecaySlowPercent
        poisonDecaySlowPercent += other.poisonDecaySlowPercent
        poisonDecayIncreaseChance += other.poisonDecayIncreaseChance
        onBleedApplyPoison += other.onBleedApplyPoison
        onBurnApplyPoison += other.onBurnApplyPoison
        onBleedDealBurnDamage += other.onBleedDealBurnDamage
        hemorrhageBleedBonus += other.hemorrhageBleedBonus
        freezeDamageWhileBurningBonus += other.freezeDamageWhileBurningBonus
        onBleedDamagePoisonTick += other.onBleedDamagePoisonTick
        onBleedAppliedToBleedingExtendTurns += other.onBleedAppliedToBleedingExtendTurns
        onBleedAppliedToBleedingDealDamage += other.onBleedAppliedToBleedingDealDamage
        bleedsIgnoreMitigation = bleedsIgnoreMitigation || other.bleedsIgnoreMitigation
        onBleedDamageHealSelf += other.onBleedDamageHealSelf
        onBurnTickHolyDamage += other.onBurnTickHolyDamage
        burnTicksTwicePerTurn = burnTicksTwicePerTurn || other.burnTicksTwicePerTurn
        damagePerBurnPotencyPercent += other.damagePerBurnPotencyPercent
        burnIncreaseChancePercent += other.burnIncreaseChancePercent
        poisonThresholdStunAmount = max(poisonThresholdStunAmount, other.poisonThresholdStunAmount)
        poisonDamageLeechPercent += other.poisonDamageLeechPercent
        onCritDoubleBleedDuration = onCritDoubleBleedDuration || other.onCritDoubleBleedDuration
        criticalOnBleedingDetonateBleed = criticalOnBleedingDetonateBleed || other.criticalOnBleedingDetonateBleed
        onBurnDamageDetonateBleed = onBurnDamageDetonateBleed || other.onBurnDamageDetonateBleed
        freezeDamageLeech = freezeDamageLeech || other.freezeDamageLeech
        poisonDamageLeech = poisonDamageLeech || other.poisonDamageLeech
        bleedDamageGoldFlat += other.bleedDamageGoldFlat
        burnDamageManaRestoreThreshold = max(burnDamageManaRestoreThreshold, other.burnDamageManaRestoreThreshold)
        onBurnDamageRestoreManaPerTurnCap = max(onBurnDamageRestoreManaPerTurnCap, other.onBurnDamageRestoreManaPerTurnCap)
    }
}

extension DotTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            burnDecaySlowPercent: values.decode(Double.self, "burnDecaySlowPercent", default: 0),
            poisonDecaySlowPercent: values.decode(Double.self, "poisonDecaySlowPercent", default: 0),
            poisonDecayIncreaseChance: values.decode(Double.self, "poisonDecayIncreaseChance", default: 0),
            onBleedApplyPoison: values.decode(Int.self, "onBleedApplyPoison", default: 0),
            onBurnApplyPoison: values.decode(Int.self, "onBurnApplyPoison", default: 0),
            onBleedDealBurnDamage: values.decode(Int.self, "onBleedDealBurnDamage", default: 0),
            hemorrhageBleedBonus: values.decode(Int.self, "hemorrhageBleedBonus", default: 0),
            freezeDamageWhileBurningBonus: values.decode(Int.self, "freezeDamageWhileBurningBonus", default: 0),
            onBleedDamagePoisonTick: values.decode(Int.self, "onBleedDamagePoisonTick", default: 0),
            onBleedAppliedToBleedingExtendTurns: values.decode(Int.self, "onBleedAppliedToBleedingExtendTurns", default: 0),
            onBleedAppliedToBleedingDealDamage: values.decode(Int.self, "onBleedAppliedToBleedingDealDamage", default: 0),
            bleedsIgnoreMitigation: values.decode(Bool.self, "bleedsIgnoreMitigation", default: false),
            onBleedDamageHealSelf: values.decode(Int.self, "onBleedDamageHealSelf", default: 0),
            onBurnTickHolyDamage: values.decode(Int.self, "onBurnTickHolyDamage", default: 0),
            burnTicksTwicePerTurn: values.decode(Bool.self, "burnTicksTwicePerTurn", default: false),
            damagePerBurnPotencyPercent: values.decode(Double.self, "damagePerBurnPotencyPercent", default: 0),
            burnIncreaseChancePercent: values.decode(Double.self, "burnIncreaseChancePercent", default: 0),
            poisonThresholdStunAmount: values.decode(Int.self, "poisonThresholdStunAmount", default: 0),
            poisonDamageLeechPercent: values.decode(Double.self, "poisonDamageLeechPercent", default: 0),
            onCritDoubleBleedDuration: values.decode(Bool.self, "onCritDoubleBleedDuration", default: false),
            criticalOnBleedingDetonateBleed: values.decode(Bool.self, "criticalOnBleedingDetonateBleed", default: false),
            onBurnDamageDetonateBleed: values.decode(Bool.self, "onBurnDamageDetonateBleed", default: false),
            freezeDamageLeech: values.decode(Bool.self, "freezeDamageLeech", default: false),
            poisonDamageLeech: values.decode(Bool.self, "poisonDamageLeech", default: false),
            bleedDamageGoldFlat: values.decode(Int.self, "bleedDamageGoldFlat", default: 0),
            burnDamageManaRestoreThreshold: values.decode(Int.self, "burnDamageManaRestoreThreshold", default: 0),
            onBurnDamageRestoreManaPerTurnCap: values.decode(Int.self, "onBurnDamageRestoreManaPerTurnCap", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(burnDecaySlowPercent, "burnDecaySlowPercent", default: 0)
        try container.encodeNonDefault(poisonDecaySlowPercent, "poisonDecaySlowPercent", default: 0)
        try container.encodeNonDefault(poisonDecayIncreaseChance, "poisonDecayIncreaseChance", default: 0)
        try container.encodeNonDefault(onBleedApplyPoison, "onBleedApplyPoison", default: 0)
        try container.encodeNonDefault(onBurnApplyPoison, "onBurnApplyPoison", default: 0)
        try container.encodeNonDefault(onBleedDealBurnDamage, "onBleedDealBurnDamage", default: 0)
        try container.encodeNonDefault(hemorrhageBleedBonus, "hemorrhageBleedBonus", default: 0)
        try container.encodeNonDefault(freezeDamageWhileBurningBonus, "freezeDamageWhileBurningBonus", default: 0)
        try container.encodeNonDefault(onBleedDamagePoisonTick, "onBleedDamagePoisonTick", default: 0)
        try container.encodeNonDefault(onBleedAppliedToBleedingExtendTurns, "onBleedAppliedToBleedingExtendTurns", default: 0)
        try container.encodeNonDefault(onBleedAppliedToBleedingDealDamage, "onBleedAppliedToBleedingDealDamage", default: 0)
        try container.encodeNonDefault(bleedsIgnoreMitigation, "bleedsIgnoreMitigation", default: false)
        try container.encodeNonDefault(onBleedDamageHealSelf, "onBleedDamageHealSelf", default: 0)
        try container.encodeNonDefault(onBurnTickHolyDamage, "onBurnTickHolyDamage", default: 0)
        try container.encodeNonDefault(burnTicksTwicePerTurn, "burnTicksTwicePerTurn", default: false)
        try container.encodeNonDefault(damagePerBurnPotencyPercent, "damagePerBurnPotencyPercent", default: 0)
        try container.encodeNonDefault(burnIncreaseChancePercent, "burnIncreaseChancePercent", default: 0)
        try container.encodeNonDefault(poisonThresholdStunAmount, "poisonThresholdStunAmount", default: 0)
        try container.encodeNonDefault(poisonDamageLeechPercent, "poisonDamageLeechPercent", default: 0)
        try container.encodeNonDefault(onCritDoubleBleedDuration, "onCritDoubleBleedDuration", default: false)
        try container.encodeNonDefault(criticalOnBleedingDetonateBleed, "criticalOnBleedingDetonateBleed", default: false)
        try container.encodeNonDefault(onBurnDamageDetonateBleed, "onBurnDamageDetonateBleed", default: false)
        try container.encodeNonDefault(freezeDamageLeech, "freezeDamageLeech", default: false)
        try container.encodeNonDefault(poisonDamageLeech, "poisonDamageLeech", default: false)
        try container.encodeNonDefault(bleedDamageGoldFlat, "bleedDamageGoldFlat", default: 0)
        try container.encodeNonDefault(burnDamageManaRestoreThreshold, "burnDamageManaRestoreThreshold", default: 0)
        try container.encodeNonDefault(onBurnDamageRestoreManaPerTurnCap, "onBurnDamageRestoreManaPerTurnCap", default: 0)
    }
}
