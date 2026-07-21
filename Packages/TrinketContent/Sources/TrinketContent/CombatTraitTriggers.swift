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
    public var regenerationIntervalTurns: Int
    public var passiveMitigationFlat: Int
    public var thornsPercent: Double
    public var cannotBeHealed: Bool
    public var burnDecaySlowPercent: Double
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double
    public var mitigationShredDurationTurns: Int
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
    public var firstHitApplyMarked: Bool
    public var companionHealSharePercent: Double
    public var onceBelowHealthPercentThreshold: Double
    public var onceBelowHealthPercentHeal: Int
    public var blockPerActionWhileDeathsDoor: Int
    public var everyNthBurnTurnCount: Int
    public var everyNthBurnTurnFreezeDamage: Int
    public var spendManaBlockFlat: Int
    public var holyDamageBlockFlat: Int
    public var holyDamageCleanseCount: Int
    public var holyDamageHealFlat: Int
    public var dodgeGoldFlat: Int
    public var ignoreEnemyMitigationPercent: Double
    public var stunDealPhysicalFlat: Int
    public var damageWhileTargetStunnedBonus: Int
    public var enemyStunnedApplyMarked: Bool
    public var dodgeBlockFlat: Int
    public var holyDamagePurgeCount: Int

    public init(
        cleanseBonusHeal: Int = 0,
        gainGoldBonusHealSelf: Int = 0,
        restoreHealthAlsoHealHero: Int = 0,
        controlResistancePercent: Double = 0,
        dodgeChanceBonus: Double = 0,
        physicalDodgeChanceBonus: Double = 0,
        ambushBonusDamage: Int = 0,
        regenerationAmount: Int = 0,
        regenerationIntervalTurns: Int = 0,
        passiveMitigationFlat: Int = 0,
        thornsPercent: Double = 0,
        cannotBeHealed: Bool = false,
        burnDecaySlowPercent: Double = 0,
        shieldErosionKeyword: Keyword? = nil,
        shieldErosionTicks: Int = 0,
        mitigationShredKeyword: Keyword? = nil,
        mitigationShredMultiplier: Double = 0,
        mitigationShredDurationTurns: Int = 0,
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
        firstHitApplyMarked: Bool = false,
        companionHealSharePercent: Double = 0,
        onceBelowHealthPercentThreshold: Double = 0,
        onceBelowHealthPercentHeal: Int = 0,
        blockPerActionWhileDeathsDoor: Int = 0,
        everyNthBurnTurnCount: Int = 0,
        everyNthBurnTurnFreezeDamage: Int = 0,
        spendManaBlockFlat: Int = 0,
        holyDamageBlockFlat: Int = 0,
        holyDamageCleanseCount: Int = 0,
        holyDamageHealFlat: Int = 0,
        dodgeGoldFlat: Int = 0,
        ignoreEnemyMitigationPercent: Double = 0,
        stunDealPhysicalFlat: Int = 0,
        damageWhileTargetStunnedBonus: Int = 0,
        enemyStunnedApplyMarked: Bool = false,
        dodgeBlockFlat: Int = 0,
        holyDamagePurgeCount: Int = 0
    ) {
        self.cleanseBonusHeal = cleanseBonusHeal
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.restoreHealthAlsoHealHero = restoreHealthAlsoHealHero
        self.controlResistancePercent = controlResistancePercent
        self.dodgeChanceBonus = dodgeChanceBonus
        self.physicalDodgeChanceBonus = physicalDodgeChanceBonus
        self.ambushBonusDamage = ambushBonusDamage
        self.regenerationAmount = regenerationAmount
        self.regenerationIntervalTurns = regenerationIntervalTurns
        self.passiveMitigationFlat = passiveMitigationFlat
        self.thornsPercent = thornsPercent
        self.cannotBeHealed = cannotBeHealed
        self.burnDecaySlowPercent = burnDecaySlowPercent
        self.shieldErosionKeyword = shieldErosionKeyword
        self.shieldErosionTicks = shieldErosionTicks
        self.mitigationShredKeyword = mitigationShredKeyword
        self.mitigationShredMultiplier = mitigationShredMultiplier
        self.mitigationShredDurationTurns = mitigationShredDurationTurns
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
        self.firstHitApplyMarked = firstHitApplyMarked
        self.companionHealSharePercent = companionHealSharePercent
        self.onceBelowHealthPercentThreshold = onceBelowHealthPercentThreshold
        self.onceBelowHealthPercentHeal = onceBelowHealthPercentHeal
        self.blockPerActionWhileDeathsDoor = blockPerActionWhileDeathsDoor
        self.everyNthBurnTurnCount = everyNthBurnTurnCount
        self.everyNthBurnTurnFreezeDamage = everyNthBurnTurnFreezeDamage
        self.spendManaBlockFlat = spendManaBlockFlat
        self.holyDamageBlockFlat = holyDamageBlockFlat
        self.holyDamageCleanseCount = holyDamageCleanseCount
        self.holyDamageHealFlat = holyDamageHealFlat
        self.dodgeGoldFlat = dodgeGoldFlat
        self.ignoreEnemyMitigationPercent = ignoreEnemyMitigationPercent
        self.stunDealPhysicalFlat = stunDealPhysicalFlat
        self.damageWhileTargetStunnedBonus = damageWhileTargetStunnedBonus
        self.enemyStunnedApplyMarked = enemyStunnedApplyMarked
        self.dodgeBlockFlat = dodgeBlockFlat
        self.holyDamagePurgeCount = holyDamagePurgeCount
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
        regenerationIntervalTurns = max(regenerationIntervalTurns, other.regenerationIntervalTurns)
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
        mitigationShredDurationTurns = max(mitigationShredDurationTurns, other.mitigationShredDurationTurns)
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
        firstHitApplyMarked = firstHitApplyMarked || other.firstHitApplyMarked
        companionHealSharePercent += other.companionHealSharePercent
        onceBelowHealthPercentThreshold = max(onceBelowHealthPercentThreshold, other.onceBelowHealthPercentThreshold)
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockPerActionWhileDeathsDoor += other.blockPerActionWhileDeathsDoor
        everyNthBurnTurnCount = max(everyNthBurnTurnCount, other.everyNthBurnTurnCount)
        everyNthBurnTurnFreezeDamage += other.everyNthBurnTurnFreezeDamage
        spendManaBlockFlat += other.spendManaBlockFlat
        holyDamageBlockFlat += other.holyDamageBlockFlat
        holyDamageCleanseCount += other.holyDamageCleanseCount
        holyDamageHealFlat += other.holyDamageHealFlat
        dodgeGoldFlat += other.dodgeGoldFlat
        ignoreEnemyMitigationPercent += other.ignoreEnemyMitigationPercent
        stunDealPhysicalFlat += other.stunDealPhysicalFlat
        damageWhileTargetStunnedBonus += other.damageWhileTargetStunnedBonus
        enemyStunnedApplyMarked = enemyStunnedApplyMarked || other.enemyStunnedApplyMarked
        dodgeBlockFlat += other.dodgeBlockFlat
        holyDamagePurgeCount += other.holyDamagePurgeCount
    }
}
