import Foundation
import TrinketCore
import TrinketContent

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var statBonuses: PrimaryStats
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var healthRestoredBonus: Int
    public var leechGainedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var blockGainedBonus: Int
    public var armorGainedBonus: Double
    public var blockDurationBonus: Int
    public var armorDurationBonus: Int
    public var leechDurationBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]
    public var damageTakenVulnerability: [Keyword: Double]
    public var petDamageDealtBonus: Int
    public var cleanseBonusHeal: Int
    public var gainGoldBonusHealSelf: Int
    public var restoreHealthAlsoHealHero: Int
    public var controlResistancePercent: Double
    public var dodgeChanceBonus: Double
    public var physicalDodgeChanceBonus: Double
    public var ambushBonusDamage: Int
    public var regenerationAmount: Int
    public var regenerationIntervalTicks: Int
    public var passiveArmorPercent: Double
    public var thornsPercent: Double
    public var cannotBeHealed: Bool
    public var burnDecaySlowPercent: Double
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double
    public var mitigationShredDurationTicks: Int
    public var freezeControlVulnerabilityPercent: Double
    public var armorEffectivenessPenaltyPercent: Double
    public var graspingVinesHealBonus: Int
    public var leechHealingMultiplier: Double
    public var hemorrhageBleedBonus: Int

    public static let zero = CombatModifierProfile()

    public init(
        statBonuses: PrimaryStats = PrimaryStats(),
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        healthRestoredBonus: Int = 0,
        leechGainedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        blockGainedBonus: Int = 0,
        armorGainedBonus: Double = 0,
        blockDurationBonus: Int = 0,
        armorDurationBonus: Int = 0,
        leechDurationBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:],
        damageTakenVulnerability: [Keyword: Double] = [:],
        petDamageDealtBonus: Int = 0,
        cleanseBonusHeal: Int = 0,
        gainGoldBonusHealSelf: Int = 0,
        restoreHealthAlsoHealHero: Int = 0,
        controlResistancePercent: Double = 0,
        dodgeChanceBonus: Double = 0,
        physicalDodgeChanceBonus: Double = 0,
        ambushBonusDamage: Int = 0,
        regenerationAmount: Int = 0,
        regenerationIntervalTicks: Int = 0,
        passiveArmorPercent: Double = 0,
        thornsPercent: Double = 0,
        cannotBeHealed: Bool = false,
        burnDecaySlowPercent: Double = 0,
        shieldErosionKeyword: Keyword? = nil,
        shieldErosionTicks: Int = 0,
        mitigationShredKeyword: Keyword? = nil,
        mitigationShredMultiplier: Double = 0,
        mitigationShredDurationTicks: Int = 0,
        freezeControlVulnerabilityPercent: Double = 0,
        armorEffectivenessPenaltyPercent: Double = 0,
        graspingVinesHealBonus: Int = 0,
        leechHealingMultiplier: Double = 1,
        hemorrhageBleedBonus: Int = 0
    ) {
        self.statBonuses = statBonuses
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.damageDealtBonus = damageDealtBonus
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGainedBonus = leechGainedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.blockGainedBonus = blockGainedBonus
        self.armorGainedBonus = armorGainedBonus
        self.blockDurationBonus = blockDurationBonus
        self.armorDurationBonus = armorDurationBonus
        self.leechDurationBonus = leechDurationBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
        self.damageTakenVulnerability = damageTakenVulnerability
        self.petDamageDealtBonus = petDamageDealtBonus
        self.cleanseBonusHeal = cleanseBonusHeal
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.restoreHealthAlsoHealHero = restoreHealthAlsoHealHero
        self.controlResistancePercent = controlResistancePercent
        self.dodgeChanceBonus = dodgeChanceBonus
        self.physicalDodgeChanceBonus = physicalDodgeChanceBonus
        self.ambushBonusDamage = ambushBonusDamage
        self.regenerationAmount = regenerationAmount
        self.regenerationIntervalTicks = regenerationIntervalTicks
        self.passiveArmorPercent = passiveArmorPercent
        self.thornsPercent = thornsPercent
        self.cannotBeHealed = cannotBeHealed
        self.burnDecaySlowPercent = burnDecaySlowPercent
        self.shieldErosionKeyword = shieldErosionKeyword
        self.shieldErosionTicks = shieldErosionTicks
        self.mitigationShredKeyword = mitigationShredKeyword
        self.mitigationShredMultiplier = mitigationShredMultiplier
        self.mitigationShredDurationTicks = mitigationShredDurationTicks
        self.freezeControlVulnerabilityPercent = freezeControlVulnerabilityPercent
        self.armorEffectivenessPenaltyPercent = armorEffectivenessPenaltyPercent
        self.graspingVinesHealBonus = graspingVinesHealBonus
        self.leechHealingMultiplier = leechHealingMultiplier
        self.hemorrhageBleedBonus = hemorrhageBleedBonus
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
        leechGainedBonus += other.leechGainedBonus
        leechHealingBonus += other.leechHealingBonus
        goldGainedBonus += other.goldGainedBonus
        blockGainedBonus += other.blockGainedBonus
        armorGainedBonus += other.armorGainedBonus
        blockDurationBonus += other.blockDurationBonus
        armorDurationBonus += other.armorDurationBonus
        leechDurationBonus += other.leechDurationBonus
        bleedDurationBonus += other.bleedDurationBonus
        for (keyword, amount) in other.damageTakenReduction {
            damageTakenReduction[keyword, default: 0] += amount
        }
        for (keyword, amount) in other.damageTakenVulnerability {
            damageTakenVulnerability[keyword, default: 0] += amount
        }
        petDamageDealtBonus += other.petDamageDealtBonus
        cleanseBonusHeal += other.cleanseBonusHeal
        gainGoldBonusHealSelf += other.gainGoldBonusHealSelf
        restoreHealthAlsoHealHero += other.restoreHealthAlsoHealHero
        controlResistancePercent += other.controlResistancePercent
        dodgeChanceBonus += other.dodgeChanceBonus
        physicalDodgeChanceBonus += other.physicalDodgeChanceBonus
        ambushBonusDamage += other.ambushBonusDamage
        regenerationAmount += other.regenerationAmount
        regenerationIntervalTicks = max(regenerationIntervalTicks, other.regenerationIntervalTicks)
        passiveArmorPercent += other.passiveArmorPercent
        thornsPercent += other.thornsPercent
        cannotBeHealed = cannotBeHealed || other.cannotBeHealed
        burnDecaySlowPercent += other.burnDecaySlowPercent
        if shieldErosionKeyword == nil { shieldErosionKeyword = other.shieldErosionKeyword }
        shieldErosionTicks += other.shieldErosionTicks
        if mitigationShredKeyword == nil { mitigationShredKeyword = other.mitigationShredKeyword }
        mitigationShredMultiplier = max(mitigationShredMultiplier, other.mitigationShredMultiplier)
        mitigationShredDurationTicks = max(mitigationShredDurationTicks, other.mitigationShredDurationTicks)
        freezeControlVulnerabilityPercent += other.freezeControlVulnerabilityPercent
        armorEffectivenessPenaltyPercent += other.armorEffectivenessPenaltyPercent
        graspingVinesHealBonus += other.graspingVinesHealBonus
        leechHealingMultiplier *= other.leechHealingMultiplier
        hemorrhageBleedBonus += other.hemorrhageBleedBonus
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

    public func damageTakenVulnerability(for keyword: Keyword) -> Double {
        max(0, damageTakenVulnerability[keyword, default: 0])
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
