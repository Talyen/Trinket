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
    public var passiveMitigationFlat: Int
    public var thornsPercent: Double
    public var cannotBeHealed: Bool
    public var burnDecaySlowPercent: Double
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double
    public var mitigationShredDurationTicks: Int
    public var freezeControlVulnerabilityPercent: Double
    public var mitigationEffectivenessPenaltyPercent: Double
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
    public var blockBrokenBlockFlat: Int
    public var blockGainedCleanseCount: Int
    public var blockGainedCleanseIntervalTicks: Int
    public var enemyStunnedHasteDurationTicks: Int
    public var firstHitApplyMarked: Bool
    public var companionActLeechPercent: Double
    public var companionActLeechDurationTicks: Int
    public var companionHealSharePercent: Double
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
        passiveMitigationFlat: Int = 0,
        thornsPercent: Double = 0,
        cannotBeHealed: Bool = false,
        burnDecaySlowPercent: Double = 0,
        shieldErosionKeyword: Keyword? = nil,
        shieldErosionTicks: Int = 0,
        mitigationShredKeyword: Keyword? = nil,
        mitigationShredMultiplier: Double = 0,
        mitigationShredDurationTicks: Int = 0,
        freezeControlVulnerabilityPercent: Double = 0,
        mitigationEffectivenessPenaltyPercent: Double = 0,
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
        blockBrokenBlockFlat: Int = 0,
        blockGainedCleanseCount: Int = 0,
        blockGainedCleanseIntervalTicks: Int = 0,
        enemyStunnedHasteDurationTicks: Int = 0,
        firstHitApplyMarked: Bool = false,
        companionActLeechPercent: Double = 0,
        companionActLeechDurationTicks: Int = 0,
        companionHealSharePercent: Double = 0,
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
        self.passiveMitigationFlat = passiveMitigationFlat
        self.thornsPercent = thornsPercent
        self.cannotBeHealed = cannotBeHealed
        self.burnDecaySlowPercent = burnDecaySlowPercent
        self.shieldErosionKeyword = shieldErosionKeyword
        self.shieldErosionTicks = shieldErosionTicks
        self.mitigationShredKeyword = mitigationShredKeyword
        self.mitigationShredMultiplier = mitigationShredMultiplier
        self.mitigationShredDurationTicks = mitigationShredDurationTicks
        self.freezeControlVulnerabilityPercent = freezeControlVulnerabilityPercent
        self.mitigationEffectivenessPenaltyPercent = mitigationEffectivenessPenaltyPercent
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
        self.blockBrokenBlockFlat = blockBrokenBlockFlat
        self.blockGainedCleanseCount = blockGainedCleanseCount
        self.blockGainedCleanseIntervalTicks = blockGainedCleanseIntervalTicks
        self.enemyStunnedHasteDurationTicks = enemyStunnedHasteDurationTicks
        self.firstHitApplyMarked = firstHitApplyMarked
        self.companionActLeechPercent = companionActLeechPercent
        self.companionActLeechDurationTicks = companionActLeechDurationTicks
        self.companionHealSharePercent = companionHealSharePercent
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
        passiveMitigationFlat += other.passiveMitigationFlat
        thornsPercent += other.thornsPercent
        cannotBeHealed = cannotBeHealed || other.cannotBeHealed
        burnDecaySlowPercent += other.burnDecaySlowPercent
        if shieldErosionKeyword == nil {
            shieldErosionKeyword = other.shieldErosionKeyword
        }
        shieldErosionTicks += other.shieldErosionTicks
        if mitigationShredKeyword == nil {
            mitigationShredKeyword = other.mitigationShredKeyword
        }
        mitigationShredMultiplier = max(mitigationShredMultiplier, other.mitigationShredMultiplier)
        mitigationShredDurationTicks = max(mitigationShredDurationTicks, other.mitigationShredDurationTicks)
        freezeControlVulnerabilityPercent += other.freezeControlVulnerabilityPercent
        mitigationEffectivenessPenaltyPercent += other.mitigationEffectivenessPenaltyPercent
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
        if damageBelowHealthPercentKeyword == nil {
            damageBelowHealthPercentKeyword = other.damageBelowHealthPercentKeyword
        }
        damageBelowHealthPercentBonus += other.damageBelowHealthPercentBonus
        damageAfterDodgeBonus += other.damageAfterDodgeBonus
        refreshBleedOnReapply = refreshBleedOnReapply || other.refreshBleedOnReapply
        blockBrokenBlockFlat += other.blockBrokenBlockFlat
        blockGainedCleanseCount += other.blockGainedCleanseCount
        blockGainedCleanseIntervalTicks = max(blockGainedCleanseIntervalTicks, other.blockGainedCleanseIntervalTicks)
        enemyStunnedHasteDurationTicks = max(enemyStunnedHasteDurationTicks, other.enemyStunnedHasteDurationTicks)
        firstHitApplyMarked = firstHitApplyMarked || other.firstHitApplyMarked
        companionActLeechPercent += other.companionActLeechPercent
        companionActLeechDurationTicks = max(companionActLeechDurationTicks, other.companionActLeechDurationTicks)
        companionHealSharePercent += other.companionHealSharePercent
        onceBelowHealthPercentThreshold = max(onceBelowHealthPercentThreshold, other.onceBelowHealthPercentThreshold)
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockPerActionWhileDeathsDoor += other.blockPerActionWhileDeathsDoor
        everyNthBurnTickCount = max(everyNthBurnTickCount, other.everyNthBurnTickCount)
        everyNthBurnTickFreezeDamage += other.everyNthBurnTickFreezeDamage
    }
}
