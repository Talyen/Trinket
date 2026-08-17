import Foundation
import TrinketCore

/// The `mitigation` trigger family of `CombatTraitTriggers`.
public struct MitigationTriggers: Equatable, Hashable, Sendable {
    public var passiveMitigationFlat: Int = 0
    public var thornsPercent: Double = 0
    public var cannotBeHealed: Bool = false
    public var controlResistancePercent: Double = 0
    public var mitigationEffectivenessPenaltyPercent: Double = 0
    public var bleedResistance: Double = 0
    public var absorbHeroDamageFlat: Int = 0
    public var frozenEnemyDamageReductionFlat: Int = 0
    public var bleedingEnemyDamageReductionFlat: Int = 0
    public var stunnedEnemyNextTurnDamageMultiplier: Double = 1
    public var enemyBleedStacksDamageReductionStacks: Int = 0
    public var enemyBleedStacksDamageReductionPercent: Double = 0
    public var poisonedEnemyAccuracyPenaltyPercent: Double = 0
    public var poisonedEnemyMissChancePercent: Double = 0
    public var frozenEnemyMissChanceVsCompanionPercent: Double = 0
    public var holyDamageTargetMissNextAttack: Bool = false
    public var holyDamageReduceTargetDamage: Int = 0
    public var bleedingEnemyAttackDealDamage: Int = 0
    public var onAllyDamageHeal: Int = 0
    public var damageReductionPerUnspentManaEvery: Int = 0
    public var toughnessOnHit: Int = 0
    public var toughnessOnHitCap: Int = 0
    public var blockedControlBurnResistance: Double = 0
    public var afflictionResistance: Double = 0

    public init(
        passiveMitigationFlat: Int = 0,
        thornsPercent: Double = 0,
        cannotBeHealed: Bool = false,
        controlResistancePercent: Double = 0,
        mitigationEffectivenessPenaltyPercent: Double = 0,
        bleedResistance: Double = 0,
        absorbHeroDamageFlat: Int = 0,
        frozenEnemyDamageReductionFlat: Int = 0,
        bleedingEnemyDamageReductionFlat: Int = 0,
        stunnedEnemyNextTurnDamageMultiplier: Double = 1,
        enemyBleedStacksDamageReductionStacks: Int = 0,
        enemyBleedStacksDamageReductionPercent: Double = 0,
        poisonedEnemyAccuracyPenaltyPercent: Double = 0,
        poisonedEnemyMissChancePercent: Double = 0,
        frozenEnemyMissChanceVsCompanionPercent: Double = 0,
        holyDamageTargetMissNextAttack: Bool = false,
        holyDamageReduceTargetDamage: Int = 0,
        bleedingEnemyAttackDealDamage: Int = 0,
        onAllyDamageHeal: Int = 0,
        damageReductionPerUnspentManaEvery: Int = 0,
        toughnessOnHit: Int = 0,
        toughnessOnHitCap: Int = 0,
        blockedControlBurnResistance: Double = 0,
        afflictionResistance: Double = 0
    ) {
        self.passiveMitigationFlat = passiveMitigationFlat
        self.thornsPercent = thornsPercent
        self.cannotBeHealed = cannotBeHealed
        self.controlResistancePercent = controlResistancePercent
        self.mitigationEffectivenessPenaltyPercent = mitigationEffectivenessPenaltyPercent
        self.bleedResistance = bleedResistance
        self.absorbHeroDamageFlat = absorbHeroDamageFlat
        self.frozenEnemyDamageReductionFlat = frozenEnemyDamageReductionFlat
        self.bleedingEnemyDamageReductionFlat = bleedingEnemyDamageReductionFlat
        self.stunnedEnemyNextTurnDamageMultiplier = stunnedEnemyNextTurnDamageMultiplier
        self.enemyBleedStacksDamageReductionStacks = enemyBleedStacksDamageReductionStacks
        self.enemyBleedStacksDamageReductionPercent = enemyBleedStacksDamageReductionPercent
        self.poisonedEnemyAccuracyPenaltyPercent = poisonedEnemyAccuracyPenaltyPercent
        self.poisonedEnemyMissChancePercent = poisonedEnemyMissChancePercent
        self.frozenEnemyMissChanceVsCompanionPercent = frozenEnemyMissChanceVsCompanionPercent
        self.holyDamageTargetMissNextAttack = holyDamageTargetMissNextAttack
        self.holyDamageReduceTargetDamage = holyDamageReduceTargetDamage
        self.bleedingEnemyAttackDealDamage = bleedingEnemyAttackDealDamage
        self.onAllyDamageHeal = onAllyDamageHeal
        self.damageReductionPerUnspentManaEvery = damageReductionPerUnspentManaEvery
        self.toughnessOnHit = toughnessOnHit
        self.toughnessOnHitCap = toughnessOnHitCap
        self.blockedControlBurnResistance = blockedControlBurnResistance
        self.afflictionResistance = afflictionResistance
    }
}

extension MitigationTriggers {
    mutating func merge(_ other: Self) {
        passiveMitigationFlat += other.passiveMitigationFlat
        thornsPercent += other.thornsPercent
        cannotBeHealed = cannotBeHealed || other.cannotBeHealed
        controlResistancePercent += other.controlResistancePercent
        mitigationEffectivenessPenaltyPercent += other.mitigationEffectivenessPenaltyPercent
        bleedResistance += other.bleedResistance
        absorbHeroDamageFlat += other.absorbHeroDamageFlat
        frozenEnemyDamageReductionFlat += other.frozenEnemyDamageReductionFlat
        bleedingEnemyDamageReductionFlat += other.bleedingEnemyDamageReductionFlat
        stunnedEnemyNextTurnDamageMultiplier *= other.stunnedEnemyNextTurnDamageMultiplier
        enemyBleedStacksDamageReductionStacks = max(enemyBleedStacksDamageReductionStacks, other.enemyBleedStacksDamageReductionStacks)
        enemyBleedStacksDamageReductionPercent += other.enemyBleedStacksDamageReductionPercent
        poisonedEnemyAccuracyPenaltyPercent += other.poisonedEnemyAccuracyPenaltyPercent
        poisonedEnemyMissChancePercent += other.poisonedEnemyMissChancePercent
        frozenEnemyMissChanceVsCompanionPercent += other.frozenEnemyMissChanceVsCompanionPercent
        holyDamageTargetMissNextAttack = holyDamageTargetMissNextAttack || other.holyDamageTargetMissNextAttack
        holyDamageReduceTargetDamage += other.holyDamageReduceTargetDamage
        bleedingEnemyAttackDealDamage += other.bleedingEnemyAttackDealDamage
        onAllyDamageHeal += other.onAllyDamageHeal
        damageReductionPerUnspentManaEvery = max(damageReductionPerUnspentManaEvery, other.damageReductionPerUnspentManaEvery)
        toughnessOnHit += other.toughnessOnHit
        toughnessOnHitCap = max(toughnessOnHitCap, other.toughnessOnHitCap)
        blockedControlBurnResistance += other.blockedControlBurnResistance
        afflictionResistance += other.afflictionResistance
    }
}

extension MitigationTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            passiveMitigationFlat: values.decode(Int.self, "passiveMitigationFlat", default: 0),
            thornsPercent: values.decode(Double.self, "thornsPercent", default: 0),
            cannotBeHealed: values.decode(Bool.self, "cannotBeHealed", default: false),
            controlResistancePercent: values.decode(Double.self, "controlResistancePercent", default: 0),
            mitigationEffectivenessPenaltyPercent: values.decode(Double.self, "mitigationEffectivenessPenaltyPercent", default: 0),
            bleedResistance: values.decode(Double.self, "bleedResistance", default: 0),
            absorbHeroDamageFlat: values.decode(Int.self, "absorbHeroDamageFlat", default: 0),
            frozenEnemyDamageReductionFlat: values.decode(Int.self, "frozenEnemyDamageReductionFlat", default: 0),
            bleedingEnemyDamageReductionFlat: values.decode(Int.self, "bleedingEnemyDamageReductionFlat", default: 0),
            stunnedEnemyNextTurnDamageMultiplier: values.decode(Double.self, "stunnedEnemyNextTurnDamageMultiplier", default: 1),
            enemyBleedStacksDamageReductionStacks: values.decode(Int.self, "enemyBleedStacksDamageReductionStacks", default: 0),
            enemyBleedStacksDamageReductionPercent: values.decode(Double.self, "enemyBleedStacksDamageReductionPercent", default: 0),
            poisonedEnemyAccuracyPenaltyPercent: values.decode(Double.self, "poisonedEnemyAccuracyPenaltyPercent", default: 0),
            poisonedEnemyMissChancePercent: values.decode(Double.self, "poisonedEnemyMissChancePercent", default: 0),
            frozenEnemyMissChanceVsCompanionPercent: values.decode(Double.self, "frozenEnemyMissChanceVsCompanionPercent", default: 0),
            holyDamageTargetMissNextAttack: values.decode(Bool.self, "holyDamageTargetMissNextAttack", default: false),
            holyDamageReduceTargetDamage: values.decode(Int.self, "holyDamageReduceTargetDamage", default: 0),
            bleedingEnemyAttackDealDamage: values.decode(Int.self, "bleedingEnemyAttackDealDamage", default: 0),
            onAllyDamageHeal: values.decode(Int.self, "onAllyDamageHeal", default: 0),
            damageReductionPerUnspentManaEvery: values.decode(Int.self, "damageReductionPerUnspentManaEvery", default: 0),
            toughnessOnHit: values.decode(Int.self, "toughnessOnHit", default: 0),
            toughnessOnHitCap: values.decode(Int.self, "toughnessOnHitCap", default: 0),
            blockedControlBurnResistance: values.decode(Double.self, "blockedControlBurnResistance", default: 0),
            afflictionResistance: values.decode(Double.self, "afflictionResistance", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(passiveMitigationFlat, "passiveMitigationFlat", default: 0)
        try container.encodeNonDefault(thornsPercent, "thornsPercent", default: 0)
        try container.encodeNonDefault(cannotBeHealed, "cannotBeHealed", default: false)
        try container.encodeNonDefault(controlResistancePercent, "controlResistancePercent", default: 0)
        try container.encodeNonDefault(mitigationEffectivenessPenaltyPercent, "mitigationEffectivenessPenaltyPercent", default: 0)
        try container.encodeNonDefault(bleedResistance, "bleedResistance", default: 0)
        try container.encodeNonDefault(absorbHeroDamageFlat, "absorbHeroDamageFlat", default: 0)
        try container.encodeNonDefault(frozenEnemyDamageReductionFlat, "frozenEnemyDamageReductionFlat", default: 0)
        try container.encodeNonDefault(bleedingEnemyDamageReductionFlat, "bleedingEnemyDamageReductionFlat", default: 0)
        try container.encodeNonDefault(stunnedEnemyNextTurnDamageMultiplier, "stunnedEnemyNextTurnDamageMultiplier", default: 1)
        try container.encodeNonDefault(enemyBleedStacksDamageReductionStacks, "enemyBleedStacksDamageReductionStacks", default: 0)
        try container.encodeNonDefault(enemyBleedStacksDamageReductionPercent, "enemyBleedStacksDamageReductionPercent", default: 0)
        try container.encodeNonDefault(poisonedEnemyAccuracyPenaltyPercent, "poisonedEnemyAccuracyPenaltyPercent", default: 0)
        try container.encodeNonDefault(poisonedEnemyMissChancePercent, "poisonedEnemyMissChancePercent", default: 0)
        try container.encodeNonDefault(frozenEnemyMissChanceVsCompanionPercent, "frozenEnemyMissChanceVsCompanionPercent", default: 0)
        try container.encodeNonDefault(holyDamageTargetMissNextAttack, "holyDamageTargetMissNextAttack", default: false)
        try container.encodeNonDefault(holyDamageReduceTargetDamage, "holyDamageReduceTargetDamage", default: 0)
        try container.encodeNonDefault(bleedingEnemyAttackDealDamage, "bleedingEnemyAttackDealDamage", default: 0)
        try container.encodeNonDefault(onAllyDamageHeal, "onAllyDamageHeal", default: 0)
        try container.encodeNonDefault(damageReductionPerUnspentManaEvery, "damageReductionPerUnspentManaEvery", default: 0)
        try container.encodeNonDefault(toughnessOnHit, "toughnessOnHit", default: 0)
        try container.encodeNonDefault(toughnessOnHitCap, "toughnessOnHitCap", default: 0)
        try container.encodeNonDefault(blockedControlBurnResistance, "blockedControlBurnResistance", default: 0)
        try container.encodeNonDefault(afflictionResistance, "afflictionResistance", default: 0)
    }
}
