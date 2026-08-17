import Foundation
import TrinketCore

/// The `attack` trigger family of `CombatTraitTriggers`.
public struct AttackTriggers: Equatable, Hashable, Sendable {
    public var attacksApplyPoison: Int = 0
    public var physicalAttackApplyBleed: Int = 0
    public var physicalAttackApplyBleedAndStun: Int = 0
    public var physicalAttackFlatStunBuildup: Int = 0
    public var basicAttackApplyBleed: Int = 0
    public var basicAttackFreezeBuildup: Int = 0
    public var criticalApplyPoison: Int = 0
    public var criticalApplyBurn: Int = 0
    public var criticalApplyStunBuildup: Int = 0
    public var criticalBlockFlat: Int = 0
    public var holyAttackApplyBurnAndStunBuildup: Int = 0
    public var onAttackStealGold: Int = 0
    public var basicAttackStealGold: Int = 0
    public var onAttackFrozenEnemyGainMana: Int = 0
    public var onAttackFrozenEnemyGainBlock: Int = 0
    public var onAttackStunnedEnemyGold: Int = 0
    public var onAttackStunnedEnemyBlock: Int = 0
    public var holyDamageNextHitBonus: Int = 0
    public var holyDamageNextAttackHolyBonus: Int = 0
    public var onBleedDamageNextBasicGuaranteedCrit: Bool = false
    public var nextAttackBonusOnFullHealth: Int = 0
    public var leechOverhealDamageBonus: Int = 0
    public var onHeroSpendManaCompanionNextAttackBonus: Int = 0
    public var partyBasicAttackHolyBonus: Int = 0
    public var partyHolyDamageBonusWhileCompanionFullHealth: Int = 0
    public var partyDamageBonusWhileCompanionFullHealth: Int = 0
    public var partyPhysicalDamageBonusFirstTurns: Int = 0
    public var partyPhysicalDamageBonusFirstTurnCount: Int = 0
    public var attackBurstChancePercent: Double = 0
    public var attackBurstDamage: Int = 0
    public var attackBurstBlock: Int = 0
    public var directHitBleedChancePercent: Double = 0
    public var attackApplyBleed: Int = 0
    public var onHeroAttackPoisonedEnemyApplyPoison: Int = 0
    public var onPhysicalDamageGainBlock: Int = 0
    public var critStealEnemyBlock: Bool = false
    public var criticalPurgeCount: Int = 0
    public var criticalPurgeAll: Bool = false
    public var onDefeatEnemyPartyStrengthBonus: Int = 0

    public init(
        attacksApplyPoison: Int = 0,
        physicalAttackApplyBleed: Int = 0,
        physicalAttackApplyBleedAndStun: Int = 0,
        physicalAttackFlatStunBuildup: Int = 0,
        basicAttackApplyBleed: Int = 0,
        basicAttackFreezeBuildup: Int = 0,
        criticalApplyPoison: Int = 0,
        criticalApplyBurn: Int = 0,
        criticalApplyStunBuildup: Int = 0,
        criticalBlockFlat: Int = 0,
        holyAttackApplyBurnAndStunBuildup: Int = 0,
        onAttackStealGold: Int = 0,
        basicAttackStealGold: Int = 0,
        onAttackFrozenEnemyGainMana: Int = 0,
        onAttackFrozenEnemyGainBlock: Int = 0,
        onAttackStunnedEnemyGold: Int = 0,
        onAttackStunnedEnemyBlock: Int = 0,
        holyDamageNextHitBonus: Int = 0,
        holyDamageNextAttackHolyBonus: Int = 0,
        onBleedDamageNextBasicGuaranteedCrit: Bool = false,
        nextAttackBonusOnFullHealth: Int = 0,
        leechOverhealDamageBonus: Int = 0,
        onHeroSpendManaCompanionNextAttackBonus: Int = 0,
        partyBasicAttackHolyBonus: Int = 0,
        partyHolyDamageBonusWhileCompanionFullHealth: Int = 0,
        partyDamageBonusWhileCompanionFullHealth: Int = 0,
        partyPhysicalDamageBonusFirstTurns: Int = 0,
        partyPhysicalDamageBonusFirstTurnCount: Int = 0,
        attackBurstChancePercent: Double = 0,
        attackBurstDamage: Int = 0,
        attackBurstBlock: Int = 0,
        directHitBleedChancePercent: Double = 0,
        attackApplyBleed: Int = 0,
        onHeroAttackPoisonedEnemyApplyPoison: Int = 0,
        onPhysicalDamageGainBlock: Int = 0,
        critStealEnemyBlock: Bool = false,
        criticalPurgeCount: Int = 0,
        criticalPurgeAll: Bool = false,
        onDefeatEnemyPartyStrengthBonus: Int = 0
    ) {
        self.attacksApplyPoison = attacksApplyPoison
        self.physicalAttackApplyBleed = physicalAttackApplyBleed
        self.physicalAttackApplyBleedAndStun = physicalAttackApplyBleedAndStun
        self.physicalAttackFlatStunBuildup = physicalAttackFlatStunBuildup
        self.basicAttackApplyBleed = basicAttackApplyBleed
        self.basicAttackFreezeBuildup = basicAttackFreezeBuildup
        self.criticalApplyPoison = criticalApplyPoison
        self.criticalApplyBurn = criticalApplyBurn
        self.criticalApplyStunBuildup = criticalApplyStunBuildup
        self.criticalBlockFlat = criticalBlockFlat
        self.holyAttackApplyBurnAndStunBuildup = holyAttackApplyBurnAndStunBuildup
        self.onAttackStealGold = onAttackStealGold
        self.basicAttackStealGold = basicAttackStealGold
        self.onAttackFrozenEnemyGainMana = onAttackFrozenEnemyGainMana
        self.onAttackFrozenEnemyGainBlock = onAttackFrozenEnemyGainBlock
        self.onAttackStunnedEnemyGold = onAttackStunnedEnemyGold
        self.onAttackStunnedEnemyBlock = onAttackStunnedEnemyBlock
        self.holyDamageNextHitBonus = holyDamageNextHitBonus
        self.holyDamageNextAttackHolyBonus = holyDamageNextAttackHolyBonus
        self.onBleedDamageNextBasicGuaranteedCrit = onBleedDamageNextBasicGuaranteedCrit
        self.nextAttackBonusOnFullHealth = nextAttackBonusOnFullHealth
        self.leechOverhealDamageBonus = leechOverhealDamageBonus
        self.onHeroSpendManaCompanionNextAttackBonus = onHeroSpendManaCompanionNextAttackBonus
        self.partyBasicAttackHolyBonus = partyBasicAttackHolyBonus
        self.partyHolyDamageBonusWhileCompanionFullHealth = partyHolyDamageBonusWhileCompanionFullHealth
        self.partyDamageBonusWhileCompanionFullHealth = partyDamageBonusWhileCompanionFullHealth
        self.partyPhysicalDamageBonusFirstTurns = partyPhysicalDamageBonusFirstTurns
        self.partyPhysicalDamageBonusFirstTurnCount = partyPhysicalDamageBonusFirstTurnCount
        self.attackBurstChancePercent = attackBurstChancePercent
        self.attackBurstDamage = attackBurstDamage
        self.attackBurstBlock = attackBurstBlock
        self.directHitBleedChancePercent = directHitBleedChancePercent
        self.attackApplyBleed = attackApplyBleed
        self.onHeroAttackPoisonedEnemyApplyPoison = onHeroAttackPoisonedEnemyApplyPoison
        self.onPhysicalDamageGainBlock = onPhysicalDamageGainBlock
        self.critStealEnemyBlock = critStealEnemyBlock
        self.criticalPurgeCount = criticalPurgeCount
        self.criticalPurgeAll = criticalPurgeAll
        self.onDefeatEnemyPartyStrengthBonus = onDefeatEnemyPartyStrengthBonus
    }
}

extension AttackTriggers {
    mutating func merge(_ other: Self) {
        attacksApplyPoison += other.attacksApplyPoison
        physicalAttackApplyBleed += other.physicalAttackApplyBleed
        physicalAttackApplyBleedAndStun += other.physicalAttackApplyBleedAndStun
        physicalAttackFlatStunBuildup += other.physicalAttackFlatStunBuildup
        basicAttackApplyBleed += other.basicAttackApplyBleed
        basicAttackFreezeBuildup += other.basicAttackFreezeBuildup
        criticalApplyPoison += other.criticalApplyPoison
        criticalApplyBurn += other.criticalApplyBurn
        criticalApplyStunBuildup += other.criticalApplyStunBuildup
        criticalBlockFlat += other.criticalBlockFlat
        holyAttackApplyBurnAndStunBuildup += other.holyAttackApplyBurnAndStunBuildup
        onAttackStealGold += other.onAttackStealGold
        basicAttackStealGold += other.basicAttackStealGold
        onAttackFrozenEnemyGainMana += other.onAttackFrozenEnemyGainMana
        onAttackFrozenEnemyGainBlock += other.onAttackFrozenEnemyGainBlock
        onAttackStunnedEnemyGold += other.onAttackStunnedEnemyGold
        onAttackStunnedEnemyBlock += other.onAttackStunnedEnemyBlock
        holyDamageNextHitBonus += other.holyDamageNextHitBonus
        holyDamageNextAttackHolyBonus += other.holyDamageNextAttackHolyBonus
        onBleedDamageNextBasicGuaranteedCrit = onBleedDamageNextBasicGuaranteedCrit || other.onBleedDamageNextBasicGuaranteedCrit
        nextAttackBonusOnFullHealth += other.nextAttackBonusOnFullHealth
        leechOverhealDamageBonus += other.leechOverhealDamageBonus
        onHeroSpendManaCompanionNextAttackBonus += other.onHeroSpendManaCompanionNextAttackBonus
        partyBasicAttackHolyBonus += other.partyBasicAttackHolyBonus
        partyHolyDamageBonusWhileCompanionFullHealth += other.partyHolyDamageBonusWhileCompanionFullHealth
        partyDamageBonusWhileCompanionFullHealth += other.partyDamageBonusWhileCompanionFullHealth
        partyPhysicalDamageBonusFirstTurns += other.partyPhysicalDamageBonusFirstTurns
        partyPhysicalDamageBonusFirstTurnCount = max(partyPhysicalDamageBonusFirstTurnCount, other.partyPhysicalDamageBonusFirstTurnCount)
        attackBurstChancePercent += other.attackBurstChancePercent
        attackBurstDamage += other.attackBurstDamage
        attackBurstBlock += other.attackBurstBlock
        directHitBleedChancePercent += other.directHitBleedChancePercent
        attackApplyBleed += other.attackApplyBleed
        onHeroAttackPoisonedEnemyApplyPoison += other.onHeroAttackPoisonedEnemyApplyPoison
        onPhysicalDamageGainBlock += other.onPhysicalDamageGainBlock
        critStealEnemyBlock = critStealEnemyBlock || other.critStealEnemyBlock
        criticalPurgeAll = criticalPurgeAll || other.criticalPurgeAll
        criticalPurgeCount += other.criticalPurgeCount
        onDefeatEnemyPartyStrengthBonus += other.onDefeatEnemyPartyStrengthBonus
    }
}

extension AttackTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix: DefaultingTriggerDecoder?) throws {
        try self.init(
            attacksApplyPoison: values.decode(Int.self, "attacksApplyPoison", default: 0),
            physicalAttackApplyBleed: values.decode(Int.self, "physicalAttackApplyBleed", default: 0),
            physicalAttackApplyBleedAndStun: values.decode(Int.self, "physicalAttackApplyBleedAndStun", default: 0),
            physicalAttackFlatStunBuildup: values.decode(Int.self, "physicalAttackFlatStunBuildup", default: 0),
            basicAttackApplyBleed: values.decode(Int.self, "basicAttackApplyBleed", default: 0),
            basicAttackFreezeBuildup: values.decode(Int.self, "basicAttackFreezeBuildup", default: 0),
            criticalApplyPoison: values.decode(Int.self, "criticalApplyPoison", default: 0),
            criticalApplyBurn: values.decode(Int.self, "criticalApplyBurn", default: 0),
            criticalApplyStunBuildup: values.decode(Int.self, "criticalApplyStunBuildup", default: 0),
            criticalBlockFlat: values.decode(Int.self, "criticalBlockFlat", default: 0),
            holyAttackApplyBurnAndStunBuildup: values.decode(Int.self, "holyAttackApplyBurnAndStunBuildup", default: 0),
            onAttackStealGold: values.decode(Int.self, "onAttackStealGold", default: 0),
            basicAttackStealGold: values.decode(Int.self, "basicAttackStealGold", default: 0),
            onAttackFrozenEnemyGainMana: values.decode(Int.self, "onAttackFrozenEnemyGainMana", default: 0),
            onAttackFrozenEnemyGainBlock: values.decode(Int.self, "onAttackFrozenEnemyGainBlock", default: 0),
            onAttackStunnedEnemyGold: values.decode(Int.self, "onAttackStunnedEnemyGold", default: 0),
            onAttackStunnedEnemyBlock: values.decode(Int.self, "onAttackStunnedEnemyBlock", default: 0),
            holyDamageNextHitBonus: values.decode(Int.self, "holyDamageNextHitBonus", default: 0),
            holyDamageNextAttackHolyBonus: values.decode(Int.self, "holyDamageNextAttackHolyBonus", default: 0),
            onBleedDamageNextBasicGuaranteedCrit: values.decode(Bool.self, "onBleedDamageNextBasicGuaranteedCrit", default: false),
            nextAttackBonusOnFullHealth: values.decode(Int.self, "nextAttackBonusOnFullHealth", default: 0),
            leechOverhealDamageBonus: values.decode(Int.self, "leechOverhealDamageBonus", default: 0),
            onHeroSpendManaCompanionNextAttackBonus: values.decode(Int.self, "onHeroSpendManaCompanionNextAttackBonus", default: 0),
            partyBasicAttackHolyBonus: values.decode(Int.self, "partyBasicAttackHolyBonus", default: 0),
            partyHolyDamageBonusWhileCompanionFullHealth: values.decode(
                Int.self,
                "partyHolyDamageBonusWhileCompanionFullHealth",
                default: 0
            ),
            partyDamageBonusWhileCompanionFullHealth: values.decode(Int.self, "partyDamageBonusWhileCompanionFullHealth", default: 0),
            partyPhysicalDamageBonusFirstTurns: values.decode(Int.self, "partyPhysicalDamageBonusFirstTurns", default: 0),
            partyPhysicalDamageBonusFirstTurnCount: values.decode(Int.self, "partyPhysicalDamageBonusFirstTurnCount", default: 0),
            attackBurstChancePercent: values.decode(Double.self, "attackBurstChancePercent", default: 0),
            attackBurstDamage: values.decode(Int.self, "attackBurstDamage", default: 0),
            attackBurstBlock: values.decode(Int.self, "attackBurstBlock", default: 0),
            directHitBleedChancePercent: values.decode(Double.self, "directHitBleedChancePercent", default: 0),
            attackApplyBleed: values.decode(Int.self, "attackApplyBleed", default: 0),
            onHeroAttackPoisonedEnemyApplyPoison: values.decode(Int.self, "onHeroAttackPoisonedEnemyApplyPoison", default: 0),
            onPhysicalDamageGainBlock: values.decode(Int.self, "onPhysicalDamageGainBlock", default: 0),
            critStealEnemyBlock: values.decode(Bool.self, "critStealEnemyBlock", default: false),
            criticalPurgeCount: values.decode(
                Int.self,
                "criticalPurgeCount",
                default: legacyAffix?.decode(Int.self, "criticalPurgeCount", default: 0) ?? 0
            ),
            criticalPurgeAll: values.decode(
                Bool.self,
                "criticalPurgeAll",
                default: legacyAffix?.decode(Bool.self, "criticalPurgeAll", default: false) ?? false
            ),
            onDefeatEnemyPartyStrengthBonus: values.decode(Int.self, "onDefeatEnemyPartyStrengthBonus", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(attacksApplyPoison, "attacksApplyPoison", default: 0)
        try container.encodeNonDefault(physicalAttackApplyBleed, "physicalAttackApplyBleed", default: 0)
        try container.encodeNonDefault(physicalAttackApplyBleedAndStun, "physicalAttackApplyBleedAndStun", default: 0)
        try container.encodeNonDefault(physicalAttackFlatStunBuildup, "physicalAttackFlatStunBuildup", default: 0)
        try container.encodeNonDefault(basicAttackApplyBleed, "basicAttackApplyBleed", default: 0)
        try container.encodeNonDefault(basicAttackFreezeBuildup, "basicAttackFreezeBuildup", default: 0)
        try container.encodeNonDefault(criticalApplyPoison, "criticalApplyPoison", default: 0)
        try container.encodeNonDefault(criticalApplyBurn, "criticalApplyBurn", default: 0)
        try container.encodeNonDefault(criticalApplyStunBuildup, "criticalApplyStunBuildup", default: 0)
        try container.encodeNonDefault(criticalBlockFlat, "criticalBlockFlat", default: 0)
        try container.encodeNonDefault(holyAttackApplyBurnAndStunBuildup, "holyAttackApplyBurnAndStunBuildup", default: 0)
        try container.encodeNonDefault(onAttackStealGold, "onAttackStealGold", default: 0)
        try container.encodeNonDefault(basicAttackStealGold, "basicAttackStealGold", default: 0)
        try container.encodeNonDefault(onAttackFrozenEnemyGainMana, "onAttackFrozenEnemyGainMana", default: 0)
        try container.encodeNonDefault(onAttackFrozenEnemyGainBlock, "onAttackFrozenEnemyGainBlock", default: 0)
        try container.encodeNonDefault(onAttackStunnedEnemyGold, "onAttackStunnedEnemyGold", default: 0)
        try container.encodeNonDefault(onAttackStunnedEnemyBlock, "onAttackStunnedEnemyBlock", default: 0)
        try container.encodeNonDefault(holyDamageNextHitBonus, "holyDamageNextHitBonus", default: 0)
        try container.encodeNonDefault(holyDamageNextAttackHolyBonus, "holyDamageNextAttackHolyBonus", default: 0)
        try container.encodeNonDefault(onBleedDamageNextBasicGuaranteedCrit, "onBleedDamageNextBasicGuaranteedCrit", default: false)
        try container.encodeNonDefault(nextAttackBonusOnFullHealth, "nextAttackBonusOnFullHealth", default: 0)
        try container.encodeNonDefault(leechOverhealDamageBonus, "leechOverhealDamageBonus", default: 0)
        try container.encodeNonDefault(onHeroSpendManaCompanionNextAttackBonus, "onHeroSpendManaCompanionNextAttackBonus", default: 0)
        try container.encodeNonDefault(partyBasicAttackHolyBonus, "partyBasicAttackHolyBonus", default: 0)
        try container.encodeNonDefault(
            partyHolyDamageBonusWhileCompanionFullHealth,
            "partyHolyDamageBonusWhileCompanionFullHealth",
            default: 0
        )
        try container.encodeNonDefault(partyDamageBonusWhileCompanionFullHealth, "partyDamageBonusWhileCompanionFullHealth", default: 0)
        try container.encodeNonDefault(partyPhysicalDamageBonusFirstTurns, "partyPhysicalDamageBonusFirstTurns", default: 0)
        try container.encodeNonDefault(partyPhysicalDamageBonusFirstTurnCount, "partyPhysicalDamageBonusFirstTurnCount", default: 0)
        try container.encodeNonDefault(attackBurstChancePercent, "attackBurstChancePercent", default: 0)
        try container.encodeNonDefault(attackBurstDamage, "attackBurstDamage", default: 0)
        try container.encodeNonDefault(attackBurstBlock, "attackBurstBlock", default: 0)
        try container.encodeNonDefault(directHitBleedChancePercent, "directHitBleedChancePercent", default: 0)
        try container.encodeNonDefault(attackApplyBleed, "attackApplyBleed", default: 0)
        try container.encodeNonDefault(onHeroAttackPoisonedEnemyApplyPoison, "onHeroAttackPoisonedEnemyApplyPoison", default: 0)
        try container.encodeNonDefault(onPhysicalDamageGainBlock, "onPhysicalDamageGainBlock", default: 0)
        try container.encodeNonDefault(critStealEnemyBlock, "critStealEnemyBlock", default: false)
        try container.encodeNonDefault(criticalPurgeCount, "criticalPurgeCount", default: 0)
        try container.encodeNonDefault(criticalPurgeAll, "criticalPurgeAll", default: false)
        try container.encodeNonDefault(onDefeatEnemyPartyStrengthBonus, "onDefeatEnemyPartyStrengthBonus", default: 0)
    }
}
