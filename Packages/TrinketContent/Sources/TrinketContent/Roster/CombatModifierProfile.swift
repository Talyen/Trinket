import TrinketCore

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var damageDealtPercents: [Keyword: Double] = [:]
    public var maximumHealthPercentBonus: Double = 0
    public var criticalDamagePercent: Double = 0
    public var healthRestoredPercent: Double = 0
    public var manaRestoredPercent: Double = 0
    public var leechHealingPercent: Double = 0
    public var blockGainedPercent: Double = 0
    public var companionDamageDealtPercent: Double = 0
    public var rangedDamageDealtPercent: Double = 0
    public var maximumHealthBonus: Int = 0
    public var maximumManaBonus: Int = 0
    public var criticalDamageBonus: Int = 0
    public var manaRestoredBonus: Int = 0
    public var damageDealtBonus: [Keyword: Int] = [:]
    public var poisonDamageDealtPercent: Double = 0
    public var healthRestoredBonus: Int = 0
    public var leechGainedBonus: Double = 0
    public var leechHealingBonus: Int = 0
    public var goldGainedBonus: Int = 0
    public var goldGainedPercent: Double = 0
    public var blockGainedBonus: Int = 0
    public var bleedDurationBonus: Int = 0
    public var damageTakenReduction: [Keyword: Double] = [:]
    public var damageTakenFlat: [Keyword: Int] = [:]
    public var damageTakenVulnerability: [Keyword: Double] = [:]
    public var companionDamageDealtBonus: Int = 0
    public var companionPhysicalDamageDealtBonus: Int = 0
    public var companionBleedDamageDealtBonus: Int = 0
    public var outgoingDamagePercent: Double = 0
    public var incomingDamageReductionPercent: Double = 0
    /// Augments physical damage dealt while any equipped weapon has a ranged base type (e.g. bows and crossbows).
    public var rangedDamageDealtBonus: Int = 0
    public var maximumManaPercentBonus: Double = 0
    public var triggers: CombatTraitTriggers = .init()
    public var triggerAbilityNames: [CombatTriggerField: String] = [:]

    public static let zero = Self()

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
            companionPhysicalDamageDealtBonus = SaturatedArithmetic.saturatingAdd(
                companionPhysicalDamageDealtBonus, amount,
            )
        case let .companionBleedDamageDealt(amount):
            companionBleedDamageDealtBonus = SaturatedArithmetic.saturatingAdd(
                companionBleedDamageDealtBonus, amount,
            )
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

public extension CombatModifierProfile {
    init(modifiers: [AffixModifier] = []) {
        self.init()
        merge(modifiers)
    }
}
