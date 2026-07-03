import Foundation
import TrinketCore
import TrinketContent

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var statBonuses: PrimaryStats
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var healthRestoredBonus: Int
    public var leechGrantedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var blockGrantedBonus: Int
    public var armorGrantedBonus: Double
    public var blockDurationBonus: Int
    public var armorDurationBonus: Int
    public var leechDurationBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]

    public static let zero = CombatModifierProfile()

    public init(
        statBonuses: PrimaryStats = PrimaryStats(),
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        healthRestoredBonus: Int = 0,
        leechGrantedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        blockGrantedBonus: Int = 0,
        armorGrantedBonus: Double = 0,
        blockDurationBonus: Int = 0,
        armorDurationBonus: Int = 0,
        leechDurationBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:]
    ) {
        self.statBonuses = statBonuses
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.damageDealtBonus = damageDealtBonus
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGrantedBonus = leechGrantedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.blockGrantedBonus = blockGrantedBonus
        self.armorGrantedBonus = armorGrantedBonus
        self.blockDurationBonus = blockDurationBonus
        self.armorDurationBonus = armorDurationBonus
        self.leechDurationBonus = leechDurationBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
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

    public mutating func merge(_ other: CombatModifierProfile) {
        statBonuses.merge(other.statBonuses)
        maximumHealthBonus += other.maximumHealthBonus
        maximumManaBonus += other.maximumManaBonus
        for (keyword, amount) in other.damageDealtBonus {
            damageDealtBonus[keyword, default: 0] += amount
        }
        healthRestoredBonus += other.healthRestoredBonus
        leechGrantedBonus += other.leechGrantedBonus
        leechHealingBonus += other.leechHealingBonus
        goldGainedBonus += other.goldGainedBonus
        blockGrantedBonus += other.blockGrantedBonus
        armorGrantedBonus += other.armorGrantedBonus
        blockDurationBonus += other.blockDurationBonus
        armorDurationBonus += other.armorDurationBonus
        leechDurationBonus += other.leechDurationBonus
        bleedDurationBonus += other.bleedDurationBonus
        for (keyword, amount) in other.damageTakenReduction {
            damageTakenReduction[keyword, default: 0] += amount
        }
    }

    public mutating func merge(_ modifier: AffixModifier) {
        modifier.apply(to: &self)
    }

    public func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
    }

    public func damageTakenReduction(for keyword: Keyword) -> Double {
        min(1, max(0, damageTakenReduction[keyword, default: 0]))
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
        combatant.maxHealth + combatant.primaryStats.toughness + modifiers.maximumHealthBonus
    }

    public var effectiveMaxMana: Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + combatant.primaryStats.intellect + modifiers.maximumManaBonus
    }
}

public extension PrimaryStats {
    public mutating func merge(_ other: PrimaryStats) {
        strength += other.strength
        agility += other.agility
        toughness += other.toughness
        intellect += other.intellect
        wisdom += other.wisdom
    }

    public func merged(with other: PrimaryStats) -> PrimaryStats {
        var copy = self
        copy.merge(other)
        return copy
    }
}
