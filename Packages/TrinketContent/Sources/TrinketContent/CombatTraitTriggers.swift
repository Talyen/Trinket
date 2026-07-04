import Foundation
import TrinketCore

public struct CombatTraitTriggers: Equatable, Hashable, Sendable {
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

    public init(
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

    public mutating func merge(_ other: CombatTraitTriggers) {
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
}
