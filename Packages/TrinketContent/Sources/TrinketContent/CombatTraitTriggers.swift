import Foundation
import TrinketCore

/// Trait and affix trigger knobs authored for combat builds.
public struct CombatTraitTriggers: Codable, Sendable, Equatable, Hashable {
    public var cleanseBonusDraw: Int
    public var cleanseBonusHeal: Int
    public var gainGoldBonusHealSelf: Int
    public var controlResistancePercent: Double
    public var dodgeChanceBonus: Double
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
    public var poisonDecayIncreaseChance: Double
    public var freezeDamageWhileBurningBonus: Int
    public var damageWhileTargetFrozenBonus: Int
    public var damageBelowHealthPercentThreshold: Double
    public var damageBelowHealthPercentKeyword: Keyword?
    public var damageBelowHealthPercentBonus: Int
    public var damageAfterDodgeBonus: Int
    public var blockBrokenBlockFlat: Int
    public var companionLeechSharePercent: Double
    public var onceBelowHealthPercentThreshold: Double
    public var onceBelowHealthPercentHeal: Int
    public var blockOnDeathsDoor: Int
    public var spendManaBlockFlat: Int
    public var spendManaRandomDoTFlat: Int
    public var holyDamageBlockFlat: Int
    public var stunDamageBlockFlat: Int
    public var holyDamageCleanseCount: Int
    public var holyDamageHealFlat: Int
    public var burnDamageHealFlat: Int
    public var dodgeGoldFlat: Int
    public var ignoreEnemyMitigationPercent: Double
    public var stunDealPhysicalFlat: Int
    public var damageWhileTargetStunnedBonus: Int
    public var enemyStunnedApplyMarked: Bool
    public var dodgeBlockFlat: Int
    public var dodgeApplyPoison: Int
    public var holyDamagePurgeCount: Int
    public var onceDeathReviveHealth: Int
    public var onceDeathReviveBlock: Int
    public var blockPerTurn: Int
    public var firstHitDoubleDamage: Bool
    public var leechChancePercent: Double
    public var onHitAttackerBurn: Int
    public var turnFreezeDamageAllEnemies: Int
    public var damageIncreasesEveryOtherTurn: Bool
    public var enemyStunnedPurgeCount: Int
    public var enemyStunnedPurgeAll: Bool
    public var criticalPurgeCount: Int
    public var criticalPurgeAll: Bool
    public var criticalGoldFlat: Int
    public var leechRestoreManaFlat: Int
    public var gainManaBlockFlat: Int
    public var defeatEnemyGoldFlat: Int
    public var leechGoldFlat: Int
    public var dodgeHealFlat: Int
    public var dodgeChanceBelowHealthPercentThreshold: Double
    public var dodgeChanceBelowHealthPercentBonus: Double
    public var dodgeDealStunFlat: Int

    // swiftlint:disable:next function_body_length
    public init(
        cleanseBonusDraw: Int = 0,
        cleanseBonusHeal: Int = 0,
        gainGoldBonusHealSelf: Int = 0,
        controlResistancePercent: Double = 0,
        dodgeChanceBonus: Double = 0,
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
        poisonDecayIncreaseChance: Double = 0,
        freezeDamageWhileBurningBonus: Int = 0,
        damageWhileTargetFrozenBonus: Int = 0,
        damageBelowHealthPercentThreshold: Double = 0,
        damageBelowHealthPercentKeyword: Keyword? = nil,
        damageBelowHealthPercentBonus: Int = 0,
        damageAfterDodgeBonus: Int = 0,
        blockBrokenBlockFlat: Int = 0,
        companionLeechSharePercent: Double = 0,
        onceBelowHealthPercentThreshold: Double = 0,
        onceBelowHealthPercentHeal: Int = 0,
        blockOnDeathsDoor: Int = 0,
        spendManaBlockFlat: Int = 0,
        spendManaRandomDoTFlat: Int = 0,
        holyDamageBlockFlat: Int = 0,
        stunDamageBlockFlat: Int = 0,
        holyDamageCleanseCount: Int = 0,
        holyDamageHealFlat: Int = 0,
        burnDamageHealFlat: Int = 0,
        dodgeGoldFlat: Int = 0,
        ignoreEnemyMitigationPercent: Double = 0,
        stunDealPhysicalFlat: Int = 0,
        damageWhileTargetStunnedBonus: Int = 0,
        enemyStunnedApplyMarked: Bool = false,
        dodgeBlockFlat: Int = 0,
        dodgeApplyPoison: Int = 0,
        holyDamagePurgeCount: Int = 0,
        onceDeathReviveHealth: Int = 0,
        onceDeathReviveBlock: Int = 0,
        blockPerTurn: Int = 0,
        firstHitDoubleDamage: Bool = false,
        leechChancePercent: Double = 0,
        onHitAttackerBurn: Int = 0,
        turnFreezeDamageAllEnemies: Int = 0,
        damageIncreasesEveryOtherTurn: Bool = false,
        enemyStunnedPurgeCount: Int = 0,
        enemyStunnedPurgeAll: Bool = false,
        criticalPurgeCount: Int = 0,
        criticalPurgeAll: Bool = false,
        criticalGoldFlat: Int = 0,
        leechRestoreManaFlat: Int = 0,
        gainManaBlockFlat: Int = 0,
        defeatEnemyGoldFlat: Int = 0,
        leechGoldFlat: Int = 0,
        dodgeHealFlat: Int = 0,
        dodgeChanceBelowHealthPercentThreshold: Double = 0,
        dodgeChanceBelowHealthPercentBonus: Double = 0,
        dodgeDealStunFlat: Int = 0
    ) {
        self.cleanseBonusDraw = cleanseBonusDraw
        self.cleanseBonusHeal = cleanseBonusHeal
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.controlResistancePercent = controlResistancePercent
        self.dodgeChanceBonus = dodgeChanceBonus
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
        self.poisonDecayIncreaseChance = poisonDecayIncreaseChance
        self.freezeDamageWhileBurningBonus = freezeDamageWhileBurningBonus
        self.damageWhileTargetFrozenBonus = damageWhileTargetFrozenBonus
        self.damageBelowHealthPercentThreshold = damageBelowHealthPercentThreshold
        self.damageBelowHealthPercentKeyword = damageBelowHealthPercentKeyword
        self.damageBelowHealthPercentBonus = damageBelowHealthPercentBonus
        self.damageAfterDodgeBonus = damageAfterDodgeBonus
        self.blockBrokenBlockFlat = blockBrokenBlockFlat
        self.companionLeechSharePercent = companionLeechSharePercent
        self.onceBelowHealthPercentThreshold = onceBelowHealthPercentThreshold
        self.onceBelowHealthPercentHeal = onceBelowHealthPercentHeal
        self.blockOnDeathsDoor = blockOnDeathsDoor
        self.spendManaBlockFlat = spendManaBlockFlat
        self.spendManaRandomDoTFlat = spendManaRandomDoTFlat
        self.holyDamageBlockFlat = holyDamageBlockFlat
        self.stunDamageBlockFlat = stunDamageBlockFlat
        self.holyDamageCleanseCount = holyDamageCleanseCount
        self.holyDamageHealFlat = holyDamageHealFlat
        self.burnDamageHealFlat = burnDamageHealFlat
        self.dodgeGoldFlat = dodgeGoldFlat
        self.ignoreEnemyMitigationPercent = ignoreEnemyMitigationPercent
        self.stunDealPhysicalFlat = stunDealPhysicalFlat
        self.damageWhileTargetStunnedBonus = damageWhileTargetStunnedBonus
        self.enemyStunnedApplyMarked = enemyStunnedApplyMarked
        self.dodgeBlockFlat = dodgeBlockFlat
        self.dodgeApplyPoison = dodgeApplyPoison
        self.holyDamagePurgeCount = holyDamagePurgeCount
        self.onceDeathReviveHealth = onceDeathReviveHealth
        self.onceDeathReviveBlock = onceDeathReviveBlock
        self.blockPerTurn = blockPerTurn
        self.firstHitDoubleDamage = firstHitDoubleDamage
        self.leechChancePercent = leechChancePercent
        self.onHitAttackerBurn = onHitAttackerBurn
        self.turnFreezeDamageAllEnemies = turnFreezeDamageAllEnemies
        self.damageIncreasesEveryOtherTurn = damageIncreasesEveryOtherTurn
        self.enemyStunnedPurgeCount = enemyStunnedPurgeCount
        self.enemyStunnedPurgeAll = enemyStunnedPurgeAll
        self.criticalPurgeCount = criticalPurgeCount
        self.criticalPurgeAll = criticalPurgeAll
        self.criticalGoldFlat = criticalGoldFlat
        self.leechRestoreManaFlat = leechRestoreManaFlat
        self.gainManaBlockFlat = gainManaBlockFlat
        self.defeatEnemyGoldFlat = defeatEnemyGoldFlat
        self.leechGoldFlat = leechGoldFlat
        self.dodgeHealFlat = dodgeHealFlat
        self.dodgeChanceBelowHealthPercentThreshold = dodgeChanceBelowHealthPercentThreshold
        self.dodgeChanceBelowHealthPercentBonus = dodgeChanceBelowHealthPercentBonus
        self.dodgeDealStunFlat = dodgeDealStunFlat
    }
}
