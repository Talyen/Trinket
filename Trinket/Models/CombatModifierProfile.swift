import Foundation

enum AffixModifier: Equatable, Hashable {
    case strength(Int)
    case agility(Int)
    case toughness(Int)
    case intellect(Int)
    case wisdom(Int)
    case maximumHealth(Int)
    case damageDealt(Keyword, Int)
    case healthRestored(Int)
    case leechGrantedPercent(Double)
    case leechHealing(Int)
    case goldGained(Int)
    case blockGranted(Int)
    case armorGrantedPercent(Double)
    case blockDuration(Int)
    case armorDuration(Int)
    case leechDuration(Int)
    case bleedDuration(Int)
    case damageTakenPercent(Keyword, Double)
}

struct CombatModifierProfile: Equatable, Hashable {
    var statBonuses: PrimaryStats
    var maximumHealthBonus: Int
    var damageDealtBonus: [Keyword: Int]
    var healthRestoredBonus: Int
    var leechGrantedBonus: Double
    var leechHealingBonus: Int
    var goldGainedBonus: Int
    var blockGrantedBonus: Int
    var armorGrantedBonus: Double
    var blockDurationBonus: Int
    var armorDurationBonus: Int
    var leechDurationBonus: Int
    var bleedDurationBonus: Int
    var damageTakenReduction: [Keyword: Double]

    static let zero = CombatModifierProfile()

    init(
        statBonuses: PrimaryStats = PrimaryStats(),
        maximumHealthBonus: Int = 0,
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

    init(modifiers: [AffixModifier]) {
        self = .zero
        merge(modifiers)
    }

    mutating func merge(_ modifiers: [AffixModifier]) {
        for modifier in modifiers {
            merge(modifier)
        }
    }

    mutating func merge(_ other: CombatModifierProfile) {
        statBonuses.merge(other.statBonuses)
        maximumHealthBonus += other.maximumHealthBonus
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

    mutating func merge(_ modifier: AffixModifier) {
        switch modifier {
        case let .strength(amount):
            statBonuses.strength += amount
        case let .agility(amount):
            statBonuses.agility += amount
        case let .toughness(amount):
            statBonuses.toughness += amount
        case let .intellect(amount):
            statBonuses.intellect += amount
        case let .wisdom(amount):
            statBonuses.wisdom += amount
        case let .maximumHealth(amount):
            maximumHealthBonus += amount
        case let .damageDealt(keyword, amount):
            damageDealtBonus[keyword, default: 0] += amount
        case let .healthRestored(amount):
            healthRestoredBonus += amount
        case let .leechGrantedPercent(amount):
            leechGrantedBonus += amount
        case let .leechHealing(amount):
            leechHealingBonus += amount
        case let .goldGained(amount):
            goldGainedBonus += amount
        case let .blockGranted(amount):
            blockGrantedBonus += amount
        case let .armorGrantedPercent(amount):
            armorGrantedBonus += amount
        case let .blockDuration(amount):
            blockDurationBonus += amount
        case let .armorDuration(amount):
            armorDurationBonus += amount
        case let .leechDuration(amount):
            leechDurationBonus += amount
        case let .bleedDuration(amount):
            bleedDurationBonus += amount
        case let .damageTakenPercent(keyword, amount):
            damageTakenReduction[keyword, default: 0] += amount
        }
    }

    func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
    }

    func damageTakenReduction(for keyword: Keyword) -> Double {
        min(1, max(0, damageTakenReduction[keyword, default: 0]))
    }
}

struct CombatBuild: Equatable, Hashable {
    let combatant: Combatant
    let modifiers: CombatModifierProfile

    var effectiveMaxHealth: Int {
        combatant.maxHealth + combatant.primaryStats.toughness + modifiers.maximumHealthBonus
    }
}

extension PrimaryStats {
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
