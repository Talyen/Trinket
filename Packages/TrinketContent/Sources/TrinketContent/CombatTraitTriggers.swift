import Foundation
import TrinketCore

/// Trait and affix trigger knobs authored for combat builds.
public struct CombatTraitTriggers: Codable, Sendable, Equatable, Hashable {
    public var cleanseBonusDraw: Int
    public var cleanseSelfHeal: Int
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
    public var criticalActionGoldFlat: Int
    public var leechRestoreManaFlat: Int
    public var gainManaBlockFlat: Int
    public var defeatEnemyGoldFlat: Int
    public var leechGoldFlat: Int
    public var dodgeHealFlat: Int
    public var dodgeChanceBelowHealthPercentThreshold: Double
    public var dodgeChanceBelowHealthPercentBonus: Double
    public var dodgeDealStunFlat: Int
    public var holyDamagePoisonFlat: Int
    public var drawEveryOtherTurn: Int
    public var repeatManaEmpowerment: Bool
    public var drawOnHealthLoss: Int
    public var physicalStunBuildupPercent: Double
    public var freezeDamageLeech: Bool
    public var blockGainThornsPercent: Double
    public var drawOnSpendMana: Int
    public var physicalDamageBlockPercent: Double
    public var poisonDamageLeech: Bool
    public var bleedDamageGoldFlat: Int
    public var goldPerTurn: Int
    public var healthRestoredPoisonPercent: Double
    public var sunderingBlockMultiplier: Double
    public var cardsPlayedManaThreshold: Int
    public var cardsPlayedManaFlat: Int
    public var victoryGoldFlat: Int
    public var healthPerTurn: Int
    public var companionCardsPerTurn: Int
    public var freezeExtraActionSkips: Int
    public var stunnedDamageMultiplier: Double
    public var criticalChanceBonus: Double
    public var victoryGoldCoin: Bool

    // swiftlint:disable:next function_body_length
    public init(
        cleanseBonusDraw: Int = 0,
        cleanseSelfHeal: Int = 0,
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
        criticalActionGoldFlat: Int = 0,
        leechRestoreManaFlat: Int = 0,
        gainManaBlockFlat: Int = 0,
        defeatEnemyGoldFlat: Int = 0,
        leechGoldFlat: Int = 0,
        dodgeHealFlat: Int = 0,
        dodgeChanceBelowHealthPercentThreshold: Double = 0,
        dodgeChanceBelowHealthPercentBonus: Double = 0,
        dodgeDealStunFlat: Int = 0,
        holyDamagePoisonFlat: Int = 0,
        drawEveryOtherTurn: Int = 0,
        repeatManaEmpowerment: Bool = false,
        drawOnHealthLoss: Int = 0,
        physicalStunBuildupPercent: Double = 0,
        freezeDamageLeech: Bool = false,
        blockGainThornsPercent: Double = 0,
        drawOnSpendMana: Int = 0,
        physicalDamageBlockPercent: Double = 0,
        poisonDamageLeech: Bool = false,
        bleedDamageGoldFlat: Int = 0,
        goldPerTurn: Int = 0,
        healthRestoredPoisonPercent: Double = 0,
        sunderingBlockMultiplier: Double = 0,
        cardsPlayedManaThreshold: Int = 0,
        cardsPlayedManaFlat: Int = 0,
        victoryGoldFlat: Int = 0,
        healthPerTurn: Int = 0,
        companionCardsPerTurn: Int = 0,
        freezeExtraActionSkips: Int = 0,
        stunnedDamageMultiplier: Double = 1,
        criticalChanceBonus: Double = 0,
        victoryGoldCoin: Bool = false
    ) {
        self.cleanseBonusDraw = cleanseBonusDraw
        self.cleanseSelfHeal = cleanseSelfHeal
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
        self.criticalActionGoldFlat = criticalActionGoldFlat
        self.leechRestoreManaFlat = leechRestoreManaFlat
        self.gainManaBlockFlat = gainManaBlockFlat
        self.defeatEnemyGoldFlat = defeatEnemyGoldFlat
        self.leechGoldFlat = leechGoldFlat
        self.dodgeHealFlat = dodgeHealFlat
        self.dodgeChanceBelowHealthPercentThreshold = dodgeChanceBelowHealthPercentThreshold
        self.dodgeChanceBelowHealthPercentBonus = dodgeChanceBelowHealthPercentBonus
        self.dodgeDealStunFlat = dodgeDealStunFlat
        self.holyDamagePoisonFlat = holyDamagePoisonFlat
        self.drawEveryOtherTurn = drawEveryOtherTurn
        self.repeatManaEmpowerment = repeatManaEmpowerment
        self.drawOnHealthLoss = drawOnHealthLoss
        self.physicalStunBuildupPercent = physicalStunBuildupPercent
        self.freezeDamageLeech = freezeDamageLeech
        self.blockGainThornsPercent = blockGainThornsPercent
        self.drawOnSpendMana = drawOnSpendMana
        self.physicalDamageBlockPercent = physicalDamageBlockPercent
        self.poisonDamageLeech = poisonDamageLeech
        self.bleedDamageGoldFlat = bleedDamageGoldFlat
        self.goldPerTurn = goldPerTurn
        self.healthRestoredPoisonPercent = healthRestoredPoisonPercent
        self.sunderingBlockMultiplier = sunderingBlockMultiplier
        self.cardsPlayedManaThreshold = cardsPlayedManaThreshold
        self.cardsPlayedManaFlat = cardsPlayedManaFlat
        self.victoryGoldFlat = victoryGoldFlat
        self.healthPerTurn = healthPerTurn
        self.companionCardsPerTurn = companionCardsPerTurn
        self.freezeExtraActionSkips = freezeExtraActionSkips
        self.stunnedDamageMultiplier = stunnedDamageMultiplier
        self.criticalChanceBonus = criticalChanceBonus
        self.victoryGoldCoin = victoryGoldCoin
    }
}
