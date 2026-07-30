import Foundation
import TrinketContent
import TrinketCore

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var statBonuses: PrimaryStats
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var poisonDamageDealtPercent: Double
    public var healthRestoredBonus: Int
    public var leechGainedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var goldGainedPercent: Double
    public var blockGainedBonus: Int
    public var leechDurationBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]
    public var damageTakenFlat: [Keyword: Int]
    public var damageTakenVulnerability: [Keyword: Double]
    public var companionDamageDealtBonus: Int
    public var manaCostReductionPercent: Double
    /// Trait/affix trigger knobs authored as `CombatTraitTriggers` — single schema, not duplicated fields.
    public var triggers: CombatTraitTriggers
    public var traitDisplayName: String?

    public static let zero = Self()

    public init(
        statBonuses: PrimaryStats = PrimaryStats(),
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        poisonDamageDealtPercent: Double = 0,
        healthRestoredBonus: Int = 0,
        leechGainedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        goldGainedPercent: Double = 0,
        blockGainedBonus: Int = 0,
        leechDurationBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:],
        damageTakenFlat: [Keyword: Int] = [:],
        damageTakenVulnerability: [Keyword: Double] = [:],
        companionDamageDealtBonus: Int = 0,
        manaCostReductionPercent: Double = 0,
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
        traitDisplayName: String? = nil
    ) {
        self.statBonuses = statBonuses
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.damageDealtBonus = damageDealtBonus
        self.poisonDamageDealtPercent = poisonDamageDealtPercent
        self.manaCostReductionPercent = manaCostReductionPercent
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGainedBonus = leechGainedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.goldGainedPercent = goldGainedPercent
        self.blockGainedBonus = blockGainedBonus
        self.leechDurationBonus = leechDurationBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
        self.damageTakenFlat = damageTakenFlat
        self.damageTakenVulnerability = damageTakenVulnerability
        self.companionDamageDealtBonus = companionDamageDealtBonus
        self.triggers = triggers
        self.traitDisplayName = traitDisplayName
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
        statBonuses.merge(other.statBonuses)
        maximumHealthBonus += other.maximumHealthBonus
        maximumManaBonus += other.maximumManaBonus
        for (keyword, amount) in other.damageDealtBonus {
            damageDealtBonus[keyword, default: 0] += amount
        }
        poisonDamageDealtPercent += other.poisonDamageDealtPercent
        healthRestoredBonus += other.healthRestoredBonus
        leechGainedBonus += other.leechGainedBonus
        leechHealingBonus += other.leechHealingBonus
        goldGainedBonus += other.goldGainedBonus
        goldGainedPercent += other.goldGainedPercent
        blockGainedBonus += other.blockGainedBonus
        leechDurationBonus += other.leechDurationBonus
        bleedDurationBonus += other.bleedDurationBonus
        for (keyword, amount) in other.damageTakenReduction {
            damageTakenReduction[keyword, default: 0] += amount
        }
        for (keyword, amount) in other.damageTakenFlat {
            damageTakenFlat[keyword, default: 0] += amount
        }
        for (keyword, amount) in other.damageTakenVulnerability {
            damageTakenVulnerability[keyword, default: 0] += amount
        }
        companionDamageDealtBonus += other.companionDamageDealtBonus
        manaCostReductionPercent += other.manaCostReductionPercent
        uniqueTriggers().merge(other.triggers)
        if traitDisplayName == nil {
            traitDisplayName = other.traitDisplayName
        }
    }

    /// Copy-on-write for heap-backed `triggers` so `CombatModifierProfile.zero` stays immutable.
    @discardableResult
    public mutating func uniqueTriggers() -> CombatTraitTriggers {
        if !isKnownUniquelyReferenced(&triggers) {
            triggers = triggers.copy()
        }
        return triggers
    }

    public mutating func merge(_ modifier: AffixModifier) {
        modifier.apply(to: &self)
    }

    public func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
    }

    public func damageDealtPercent(for keyword: Keyword) -> Double {
        keyword == .poison ? max(0, poisonDamageDealtPercent) : 0
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

    public func effectiveManaCost(for ability: Ability) -> Int {
        guard ability.manaCost > 0 else { return 0 }
        let reduction = min(1, max(0, manaCostReductionPercent))
        let reduced = CombatRounding.scaled(ability.manaCost, multiplier: 1 - reduction)
        return max(0, reduced)
    }
}

public struct CombatBuild: Equatable, Hashable, Sendable {
    public let combatant: Combatant
    public let modifiers: CombatModifierProfile

    public init(combatant: Combatant, modifiers: CombatModifierProfile) {
        self.combatant = combatant
        self.modifiers = modifiers
    }

    public var effectiveMaxHealth: Int {
        combatant.maxHealth + modifiers.maximumHealthBonus
    }

    public var effectiveMaxMana: Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + (combatant.primaryStats.intellect / 5) + modifiers.maximumManaBonus
    }
}

public extension PrimaryStats {
    mutating func merge(_ other: PrimaryStats) {
        strength += other.strength
        agility += other.agility
        toughness += other.toughness
        intellect += other.intellect
        wisdom += other.wisdom
    }

    func merged(with other: PrimaryStats) -> PrimaryStats {
        var copy = self
        copy.merge(other)
        return copy
    }
}
