import TrinketContent
import TrinketCore

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var damageDealtPercents: [Keyword: Double]
    public var maximumHealthPercentBonus: Double
    public var criticalDamagePercent: Double
    public var healthRestoredPercent: Double
    public var manaRestoredPercent: Double
    public var leechHealingPercent: Double
    public var blockGainedPercent: Double
    public var companionDamageDealtPercent: Double
    public var rangedDamageDealtPercent: Double
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var criticalDamageBonus: Int
    public var manaRestoredBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var poisonDamageDealtPercent: Double
    public var healthRestoredBonus: Int
    public var leechGainedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var goldGainedPercent: Double
    public var blockGainedBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]
    public var damageTakenFlat: [Keyword: Int]
    public var damageTakenVulnerability: [Keyword: Double]
    public var companionDamageDealtBonus: Int
    public var companionPhysicalDamageDealtBonus: Int
    public var companionBleedDamageDealtBonus: Int
    public var outgoingDamagePercent: Double
    public var incomingDamageReductionPercent: Double
    /// Augments physical damage dealt while any equipped weapon has a ranged base type (e.g. bows and crossbows).
    public var rangedDamageDealtBonus: Int
    public var maximumManaPercentBonus: Double
    public var triggers: CombatTraitTriggers
    public var triggerAbilityNames: [CombatTriggerField: String]

    public static let zero = Self()

    public init(
        damageDealtPercents: [Keyword: Double] = [:],
        maximumHealthPercentBonus: Double = 0,
        criticalDamagePercent: Double = 0,
        healthRestoredPercent: Double = 0,
        manaRestoredPercent: Double = 0,
        leechHealingPercent: Double = 0,
        blockGainedPercent: Double = 0,
        companionDamageDealtPercent: Double = 0,
        rangedDamageDealtPercent: Double = 0,
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        criticalDamageBonus: Int = 0,
        manaRestoredBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        poisonDamageDealtPercent: Double = 0,
        healthRestoredBonus: Int = 0,
        leechGainedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        goldGainedPercent: Double = 0,
        blockGainedBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:],
        damageTakenFlat: [Keyword: Int] = [:],
        damageTakenVulnerability: [Keyword: Double] = [:],
        companionDamageDealtBonus: Int = 0,
        companionPhysicalDamageDealtBonus: Int = 0,
        companionBleedDamageDealtBonus: Int = 0,
        outgoingDamagePercent: Double = 0,
        incomingDamageReductionPercent: Double = 0,
        rangedDamageDealtBonus: Int = 0,
        maximumManaPercentBonus: Double = 0,
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
        triggerAbilityNames: [CombatTriggerField: String] = [:],
    ) {
        self.damageDealtPercents = damageDealtPercents
        self.maximumHealthPercentBonus = maximumHealthPercentBonus
        self.criticalDamagePercent = criticalDamagePercent
        self.healthRestoredPercent = healthRestoredPercent
        self.manaRestoredPercent = manaRestoredPercent
        self.leechHealingPercent = leechHealingPercent
        self.blockGainedPercent = blockGainedPercent
        self.companionDamageDealtPercent = companionDamageDealtPercent
        self.rangedDamageDealtPercent = rangedDamageDealtPercent
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.criticalDamageBonus = criticalDamageBonus
        self.manaRestoredBonus = manaRestoredBonus
        self.damageDealtBonus = damageDealtBonus
        self.poisonDamageDealtPercent = poisonDamageDealtPercent
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGainedBonus = leechGainedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.goldGainedPercent = goldGainedPercent
        self.blockGainedBonus = blockGainedBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
        self.damageTakenFlat = damageTakenFlat
        self.damageTakenVulnerability = damageTakenVulnerability
        self.companionDamageDealtBonus = companionDamageDealtBonus
        self.companionPhysicalDamageDealtBonus = companionPhysicalDamageDealtBonus
        self.companionBleedDamageDealtBonus = companionBleedDamageDealtBonus
        self.outgoingDamagePercent = outgoingDamagePercent
        self.incomingDamageReductionPercent = incomingDamageReductionPercent
        self.rangedDamageDealtBonus = rangedDamageDealtBonus
        self.maximumManaPercentBonus = maximumManaPercentBonus
        self.triggers = triggers
        self.triggerAbilityNames = triggerAbilityNames
    }

    public init(modifiers: [AffixModifier]) {
        self = .zero
        merge(modifiers)
    }

    public mutating func merge(_ modifiers: [AffixModifier]) {
        for modifier in modifiers {
            merge(modifier)
        }
    }

    public mutating func merge(_ other: Self) {
        damageDealtPercents.merge(other.damageDealtPercents, uniquingKeysWith: +)
        maximumHealthPercentBonus += other.maximumHealthPercentBonus
        criticalDamagePercent += other.criticalDamagePercent
        healthRestoredPercent += other.healthRestoredPercent
        manaRestoredPercent += other.manaRestoredPercent
        leechHealingPercent += other.leechHealingPercent
        blockGainedPercent += other.blockGainedPercent
        companionDamageDealtPercent += other.companionDamageDealtPercent
        rangedDamageDealtPercent += other.rangedDamageDealtPercent
        maximumHealthBonus = SaturatedArithmetic.saturatingAdd(maximumHealthBonus, other.maximumHealthBonus)
        maximumManaBonus = SaturatedArithmetic.saturatingAdd(maximumManaBonus, other.maximumManaBonus)
        criticalDamageBonus = SaturatedArithmetic.saturatingAdd(criticalDamageBonus, other.criticalDamageBonus)
        manaRestoredBonus = SaturatedArithmetic.saturatingAdd(manaRestoredBonus, other.manaRestoredBonus)
        damageDealtBonus.merge(other.damageDealtBonus, uniquingKeysWith: SaturatedArithmetic.saturatingAdd)
        poisonDamageDealtPercent += other.poisonDamageDealtPercent
        healthRestoredBonus = SaturatedArithmetic.saturatingAdd(healthRestoredBonus, other.healthRestoredBonus)
        leechGainedBonus += other.leechGainedBonus
        leechHealingBonus = SaturatedArithmetic.saturatingAdd(leechHealingBonus, other.leechHealingBonus)
        goldGainedBonus = SaturatedArithmetic.saturatingAdd(goldGainedBonus, other.goldGainedBonus)
        goldGainedPercent += other.goldGainedPercent
        blockGainedBonus = SaturatedArithmetic.saturatingAdd(blockGainedBonus, other.blockGainedBonus)
        bleedDurationBonus = SaturatedArithmetic.saturatingAdd(bleedDurationBonus, other.bleedDurationBonus)
        damageTakenReduction.merge(other.damageTakenReduction, uniquingKeysWith: +)
        damageTakenFlat.merge(other.damageTakenFlat, uniquingKeysWith: SaturatedArithmetic.saturatingAdd)
        damageTakenVulnerability.merge(other.damageTakenVulnerability, uniquingKeysWith: +)
        companionDamageDealtBonus = SaturatedArithmetic.saturatingAdd(companionDamageDealtBonus, other.companionDamageDealtBonus)
        companionPhysicalDamageDealtBonus = SaturatedArithmetic.saturatingAdd(
            companionPhysicalDamageDealtBonus, other.companionPhysicalDamageDealtBonus,
        )
        companionBleedDamageDealtBonus = SaturatedArithmetic.saturatingAdd(
            companionBleedDamageDealtBonus, other.companionBleedDamageDealtBonus,
        )
        outgoingDamagePercent += other.outgoingDamagePercent
        incomingDamageReductionPercent += other.incomingDamageReductionPercent
        rangedDamageDealtBonus = SaturatedArithmetic.saturatingAdd(rangedDamageDealtBonus, other.rangedDamageDealtBonus)
        maximumManaPercentBonus += other.maximumManaPercentBonus
        triggers.merge(other.triggers)
        triggerAbilityNames.merge(other.triggerAbilityNames) { existing, _ in existing }
    }

    public func triggerAbilityName(_ key: CombatTriggerField, fallback: String) -> String {
        triggerAbilityNames[key] ?? fallback
    }

    public mutating func setTriggerAbilityName(_ key: CombatTriggerField, _ name: String) {
        if triggerAbilityNames[key] == nil {
            triggerAbilityNames[key] = name
        }
    }

    // swiftlint:disable:next function_body_length - one exhaustive mapping requires combat handling for every modifier case
    public mutating func merge(_ modifier: AffixModifier) {
        switch modifier {
        case let .maximumHealthPercent(amount):
            maximumHealthPercentBonus += amount
        case let .maximumHealth(amount):
            maximumHealthBonus = SaturatedArithmetic.saturatingAdd(maximumHealthBonus, amount)
        case let .maximumMana(amount):
            maximumManaBonus = SaturatedArithmetic.saturatingAdd(maximumManaBonus, amount)
        case let .damageDealtPercent(keyword, amount):
            damageDealtPercents[keyword, default: 0] += amount
        case let .criticalDamagePercent(amount):
            criticalDamagePercent += amount
        case let .healthRestoredPercent(amount):
            healthRestoredPercent += amount
        case let .manaRestoredPercent(amount):
            manaRestoredPercent += amount
        case let .leechHealingPercent(amount):
            leechHealingPercent += amount
        case let .blockGainedPercent(amount):
            blockGainedPercent += amount
        case let .companionDamageDealtPercent(amount):
            companionDamageDealtPercent += amount
        case let .rangedDamageDealtPercent(amount):
            rangedDamageDealtPercent += amount
        case let .damageDealt(keyword, amount):
            damageDealtBonus[keyword] = SaturatedArithmetic.saturatingAdd(damageDealtBonus[keyword, default: 0], amount)
        case let .poisonDamageDealtPercent(amount):
            poisonDamageDealtPercent += amount
        case let .criticalDamage(amount):
            criticalDamageBonus = SaturatedArithmetic.saturatingAdd(criticalDamageBonus, amount)
        case let .manaRestored(amount):
            manaRestoredBonus = SaturatedArithmetic.saturatingAdd(manaRestoredBonus, amount)
        case let .healthRestored(amount):
            healthRestoredBonus = SaturatedArithmetic.saturatingAdd(healthRestoredBonus, amount)
        case let .leechGainedPercent(amount):
            leechGainedBonus += amount
        case let .leechHealing(amount):
            leechHealingBonus = SaturatedArithmetic.saturatingAdd(leechHealingBonus, amount)
        case let .goldGained(amount):
            goldGainedBonus = SaturatedArithmetic.saturatingAdd(goldGainedBonus, amount)
        case let .goldGainedPercent(amount):
            goldGainedPercent += amount
        case let .blockGained(amount):
            blockGainedBonus = SaturatedArithmetic.saturatingAdd(blockGainedBonus, amount)
        case let .damageTakenPercent(keyword, amount):
            damageTakenReduction[keyword, default: 0] += amount
        case let .damageTakenFlat(keyword, amount):
            damageTakenFlat[keyword] = SaturatedArithmetic.saturatingAdd(damageTakenFlat[keyword, default: 0], amount)
        case let .damageTakenVulnerability(keyword, amount):
            damageTakenVulnerability[keyword, default: 0] += amount
        case let .companionDamageDealt(amount):
            companionDamageDealtBonus = SaturatedArithmetic.saturatingAdd(companionDamageDealtBonus, amount)
        case let .companionPhysicalDamageDealt(amount):
            companionPhysicalDamageDealtBonus = SaturatedArithmetic.saturatingAdd(companionPhysicalDamageDealtBonus, amount)
        case let .companionBleedDamageDealt(amount):
            companionBleedDamageDealtBonus = SaturatedArithmetic.saturatingAdd(companionBleedDamageDealtBonus, amount)
        case let .outgoingDamagePercent(amount):
            outgoingDamagePercent += amount
        case let .incomingDamageReductionPercent(amount):
            incomingDamageReductionPercent += amount
        case let .dodgeChanceBonus(amount):
            triggers.dodgeChanceBonus += amount
        case let .rangedDamageDealt(amount):
            rangedDamageDealtBonus = SaturatedArithmetic.saturatingAdd(rangedDamageDealtBonus, amount)
        case let .maximumManaPercent(amount):
            maximumManaPercentBonus += amount
        case let .startBattleBlock(amount):
            triggers.startBattleBlock = SaturatedArithmetic.saturatingAdd(triggers.startBattleBlock, amount)
        case let .attackLeechPercent(amount):
            triggers.attackLeechPercent += amount
        case let .attackBlockRemoval(amount):
            triggers.attackBlockRemoval = SaturatedArithmetic.saturatingAdd(triggers.attackBlockRemoval, amount)
        case let .attackPurgeCount(count):
            triggers.attackPurgeCount = SaturatedArithmetic.saturatingAdd(triggers.attackPurgeCount, count)
        case let .bleedDuration(amount):
            bleedDurationBonus = SaturatedArithmetic.saturatingAdd(bleedDurationBonus, amount)
        }
    }

    public func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
    }

    public func damageDealtPercent(for keyword: Keyword) -> Double {
        max(
            0,
            damageDealtPercents[keyword, default: 0]
                + companionDamageDealtPercent
                + (keyword == .poison ? poisonDamageDealtPercent : 0),
        )
    }

    public func damageTakenReduction(for keyword: Keyword) -> Double {
        min(1, max(0, damageTakenReduction[keyword, default: 0]))
    }

    public func damageTakenFlat(for keyword: Keyword) -> Int {
        max(0, damageTakenFlat[keyword, default: 0])
    }

    public func damageTakenVulnerability(for keyword: Keyword) -> Double {
        max(0, damageTakenVulnerability[keyword, default: 0])
    }
}
