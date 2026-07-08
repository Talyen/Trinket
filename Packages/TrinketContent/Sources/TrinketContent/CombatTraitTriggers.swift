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
    public var onBleedApplyPoison: Int
    public var onBurnApplyPoison: Int
    public var onBleedDealBurnDamage: Int
    public var everyNthBleedApplyCount: Int
    public var everyNthBleedApplyPoisonPotency: Int
    public var freezeDamageWhileFrozenBonus: Int
    public var damageWhileTargetFrozenBonus: Int
    public var damageBelowHealthPercentThreshold: Double
    public var damageBelowHealthPercentKeyword: Keyword?
    public var damageBelowHealthPercentBonus: Int
    public var damageAfterDodgeBonus: Int
    public var refreshBleedOnReapply: Bool
    public var blockBrokenArmorPercent: Double
    public var blockBrokenArmorDurationTicks: Int
    public var armorGainedBlock: Int
    public var blockGainedCleanseCount: Int
    public var blockGainedCleanseIntervalTicks: Int
    public var enemyStunnedHasteDurationTicks: Int
    public var firstHitApplyMarked: Bool
    public var petActLeechPercent: Double
    public var petActLeechDurationTicks: Int
    public var petHealSharePercent: Double
    public var onceBelowHealthPercentThreshold: Double
    public var onceBelowHealthPercentHeal: Int
    public var blockPerActionWhileDeathsDoor: Int
    public var everyNthBurnTickCount: Int
    public var everyNthBurnTickFreezeDamage: Int

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
        hemorrhageBleedBonus: Int = 0,
        onBleedApplyPoison: Int = 0,
        onBurnApplyPoison: Int = 0,
        onBleedDealBurnDamage: Int = 0,
        everyNthBleedApplyCount: Int = 0,
        everyNthBleedApplyPoisonPotency: Int = 0,
        freezeDamageWhileFrozenBonus: Int = 0,
        damageWhileTargetFrozenBonus: Int = 0,
        damageBelowHealthPercentThreshold: Double = 0,
        damageBelowHealthPercentKeyword: Keyword? = nil,
        damageBelowHealthPercentBonus: Int = 0,
        damageAfterDodgeBonus: Int = 0,
        refreshBleedOnReapply: Bool = false,
        blockBrokenArmorPercent: Double = 0,
        blockBrokenArmorDurationTicks: Int = 0,
        armorGainedBlock: Int = 0,
        blockGainedCleanseCount: Int = 0,
        blockGainedCleanseIntervalTicks: Int = 0,
        enemyStunnedHasteDurationTicks: Int = 0,
        firstHitApplyMarked: Bool = false,
        petActLeechPercent: Double = 0,
        petActLeechDurationTicks: Int = 0,
        petHealSharePercent: Double = 0,
        onceBelowHealthPercentThreshold: Double = 0,
        onceBelowHealthPercentHeal: Int = 0,
        blockPerActionWhileDeathsDoor: Int = 0,
        everyNthBurnTickCount: Int = 0,
        everyNthBurnTickFreezeDamage: Int = 0
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
        self.onBleedApplyPoison = onBleedApplyPoison
        self.onBurnApplyPoison = onBurnApplyPoison
        self.onBleedDealBurnDamage = onBleedDealBurnDamage
        self.everyNthBleedApplyCount = everyNthBleedApplyCount
        self.everyNthBleedApplyPoisonPotency = everyNthBleedApplyPoisonPotency
        self.freezeDamageWhileFrozenBonus = freezeDamageWhileFrozenBonus
        self.damageWhileTargetFrozenBonus = damageWhileTargetFrozenBonus
        self.damageBelowHealthPercentThreshold = damageBelowHealthPercentThreshold
        self.damageBelowHealthPercentKeyword = damageBelowHealthPercentKeyword
        self.damageBelowHealthPercentBonus = damageBelowHealthPercentBonus
        self.damageAfterDodgeBonus = damageAfterDodgeBonus
        self.refreshBleedOnReapply = refreshBleedOnReapply
        self.blockBrokenArmorPercent = blockBrokenArmorPercent
        self.blockBrokenArmorDurationTicks = blockBrokenArmorDurationTicks
        self.armorGainedBlock = armorGainedBlock
        self.blockGainedCleanseCount = blockGainedCleanseCount
        self.blockGainedCleanseIntervalTicks = blockGainedCleanseIntervalTicks
        self.enemyStunnedHasteDurationTicks = enemyStunnedHasteDurationTicks
        self.firstHitApplyMarked = firstHitApplyMarked
        self.petActLeechPercent = petActLeechPercent
        self.petActLeechDurationTicks = petActLeechDurationTicks
        self.petHealSharePercent = petHealSharePercent
        self.onceBelowHealthPercentThreshold = onceBelowHealthPercentThreshold
        self.onceBelowHealthPercentHeal = onceBelowHealthPercentHeal
        self.blockPerActionWhileDeathsDoor = blockPerActionWhileDeathsDoor
        self.everyNthBurnTickCount = everyNthBurnTickCount
        self.everyNthBurnTickFreezeDamage = everyNthBurnTickFreezeDamage
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
        onBleedApplyPoison += other.onBleedApplyPoison
        onBurnApplyPoison += other.onBurnApplyPoison
        onBleedDealBurnDamage += other.onBleedDealBurnDamage
        everyNthBleedApplyCount = max(everyNthBleedApplyCount, other.everyNthBleedApplyCount)
        everyNthBleedApplyPoisonPotency += other.everyNthBleedApplyPoisonPotency
        freezeDamageWhileFrozenBonus += other.freezeDamageWhileFrozenBonus
        damageWhileTargetFrozenBonus += other.damageWhileTargetFrozenBonus
        damageBelowHealthPercentThreshold = max(damageBelowHealthPercentThreshold, other.damageBelowHealthPercentThreshold)
        if damageBelowHealthPercentKeyword == nil { damageBelowHealthPercentKeyword = other.damageBelowHealthPercentKeyword }
        damageBelowHealthPercentBonus += other.damageBelowHealthPercentBonus
        damageAfterDodgeBonus += other.damageAfterDodgeBonus
        refreshBleedOnReapply = refreshBleedOnReapply || other.refreshBleedOnReapply
        blockBrokenArmorPercent += other.blockBrokenArmorPercent
        blockBrokenArmorDurationTicks = max(blockBrokenArmorDurationTicks, other.blockBrokenArmorDurationTicks)
        armorGainedBlock += other.armorGainedBlock
        blockGainedCleanseCount += other.blockGainedCleanseCount
        blockGainedCleanseIntervalTicks = max(blockGainedCleanseIntervalTicks, other.blockGainedCleanseIntervalTicks)
        enemyStunnedHasteDurationTicks = max(enemyStunnedHasteDurationTicks, other.enemyStunnedHasteDurationTicks)
        firstHitApplyMarked = firstHitApplyMarked || other.firstHitApplyMarked
        petActLeechPercent += other.petActLeechPercent
        petActLeechDurationTicks = max(petActLeechDurationTicks, other.petActLeechDurationTicks)
        petHealSharePercent += other.petHealSharePercent
        onceBelowHealthPercentThreshold = max(onceBelowHealthPercentThreshold, other.onceBelowHealthPercentThreshold)
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockPerActionWhileDeathsDoor += other.blockPerActionWhileDeathsDoor
        everyNthBurnTickCount = max(everyNthBurnTickCount, other.everyNthBurnTickCount)
        everyNthBurnTickFreezeDamage += other.everyNthBurnTickFreezeDamage
    }
}
