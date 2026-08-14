import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    mutating func merge(_ other: Self) {
        mergeBaseTriggers(other)
        mergeAdvancedTriggers(other)
        mergeAffixTriggers(other)
    }

    private mutating func mergeBaseTriggers(_ other: CombatTraitTriggers) {
        cleanseBonusDraw += other.cleanseBonusDraw
        cleanseSelfHeal += other.cleanseSelfHeal
        cleanseBonusHeal += other.cleanseBonusHeal
        gainGoldBonusHealSelf += other.gainGoldBonusHealSelf
        controlResistancePercent += other.controlResistancePercent
        dodgeChanceBonus += other.dodgeChanceBonus
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
        poisonDecayIncreaseChance += other.poisonDecayIncreaseChance
    }

    private mutating func mergeAdvancedTriggers(_ other: CombatTraitTriggers) {
        freezeDamageWhileBurningBonus += other.freezeDamageWhileBurningBonus
        damageWhileTargetFrozenBonus += other.damageWhileTargetFrozenBonus
        damageBelowHealthPercentThreshold = max(
            damageBelowHealthPercentThreshold,
            other.damageBelowHealthPercentThreshold
        )
        if damageBelowHealthPercentKeyword == nil {
            damageBelowHealthPercentKeyword = other.damageBelowHealthPercentKeyword
        }
        damageBelowHealthPercentBonus += other.damageBelowHealthPercentBonus
        damageAfterDodgeBonus += other.damageAfterDodgeBonus
        blockBrokenBlockFlat += other.blockBrokenBlockFlat
        companionLeechSharePercent += other.companionLeechSharePercent
        onceBelowHealthPercentThreshold = max(
            onceBelowHealthPercentThreshold,
            other.onceBelowHealthPercentThreshold
        )
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockOnDeathsDoor += other.blockOnDeathsDoor
        spendManaBlockFlat += other.spendManaBlockFlat
        spendManaRandomDoTFlat += other.spendManaRandomDoTFlat
        holyDamageBlockFlat += other.holyDamageBlockFlat
        stunDamageBlockFlat += other.stunDamageBlockFlat
        holyDamageCleanseCount += other.holyDamageCleanseCount
        holyDamageHealFlat += other.holyDamageHealFlat
        burnDamageHealFlat += other.burnDamageHealFlat
        dodgeGoldFlat += other.dodgeGoldFlat
        ignoreEnemyMitigationPercent += other.ignoreEnemyMitigationPercent
        stunDealPhysicalFlat += other.stunDealPhysicalFlat
        damageWhileTargetStunnedBonus += other.damageWhileTargetStunnedBonus
        enemyStunnedApplyMarked = enemyStunnedApplyMarked || other.enemyStunnedApplyMarked
        dodgeBlockFlat += other.dodgeBlockFlat
        dodgeApplyPoison += other.dodgeApplyPoison
        holyDamagePurgeCount += other.holyDamagePurgeCount
        onceDeathReviveHealth = max(onceDeathReviveHealth, other.onceDeathReviveHealth)
        onceDeathReviveBlock += other.onceDeathReviveBlock
        blockPerTurn += other.blockPerTurn
        firstHitDoubleDamage = firstHitDoubleDamage || other.firstHitDoubleDamage
        leechChancePercent += other.leechChancePercent
        onHitAttackerBurn += other.onHitAttackerBurn
        turnFreezeDamageAllEnemies += other.turnFreezeDamageAllEnemies
        damageIncreasesEveryOtherTurn = damageIncreasesEveryOtherTurn || other.damageIncreasesEveryOtherTurn
    }

    private mutating func mergeAffixTriggers(_ other: CombatTraitTriggers) {
        enemyStunnedPurgeCount += other.enemyStunnedPurgeCount
        enemyStunnedPurgeAll = enemyStunnedPurgeAll || other.enemyStunnedPurgeAll
        criticalPurgeCount += other.criticalPurgeCount
        criticalPurgeAll = criticalPurgeAll || other.criticalPurgeAll
        criticalGoldFlat += other.criticalGoldFlat
        criticalActionGoldFlat += other.criticalActionGoldFlat
        leechRestoreManaFlat += other.leechRestoreManaFlat
        gainManaBlockFlat += other.gainManaBlockFlat
        defeatEnemyGoldFlat += other.defeatEnemyGoldFlat
        leechGoldFlat += other.leechGoldFlat
        dodgeHealFlat += other.dodgeHealFlat
        dodgeChanceBelowHealthPercentThreshold = max(
            dodgeChanceBelowHealthPercentThreshold,
            other.dodgeChanceBelowHealthPercentThreshold
        )
        dodgeChanceBelowHealthPercentBonus += other.dodgeChanceBelowHealthPercentBonus
        dodgeDealStunFlat += other.dodgeDealStunFlat
        holyDamagePoisonFlat += other.holyDamagePoisonFlat
        drawEveryOtherTurn += other.drawEveryOtherTurn
        repeatManaEmpowerment = repeatManaEmpowerment || other.repeatManaEmpowerment
        drawOnHealthLoss += other.drawOnHealthLoss
        physicalStunBuildupPercent += other.physicalStunBuildupPercent
        freezeDamageLeech = freezeDamageLeech || other.freezeDamageLeech
        blockGainThornsPercent += other.blockGainThornsPercent
        drawOnSpendMana += other.drawOnSpendMana
        physicalDamageBlockPercent += other.physicalDamageBlockPercent
        poisonDamageLeech = poisonDamageLeech || other.poisonDamageLeech
        bleedDamageGoldFlat += other.bleedDamageGoldFlat
        goldPerTurn += other.goldPerTurn
        healthRestoredPoisonPercent += other.healthRestoredPoisonPercent
        sunderingBlockMultiplier += other.sunderingBlockMultiplier
        cardsPlayedManaThreshold = max(cardsPlayedManaThreshold, other.cardsPlayedManaThreshold)
        cardsPlayedManaFlat += other.cardsPlayedManaFlat
        victoryGoldFlat += other.victoryGoldFlat
        healthPerTurn += other.healthPerTurn
        companionCardsPerTurn += other.companionCardsPerTurn
        freezeExtraActionSkips += other.freezeExtraActionSkips
        stunnedDamageMultiplier *= other.stunnedDamageMultiplier
        criticalChanceBonus += other.criticalChanceBonus
        victoryGoldCoin = victoryGoldCoin || other.victoryGoldCoin
    }
}
