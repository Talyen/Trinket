import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    func merge(_ other: CombatTraitTriggers) {
        mergeBaseTriggers(other)
        mergeAdvancedTriggers(other)
        mergeNewAffixTriggers(other)
    }

    private func mergeBaseTriggers(_ other: CombatTraitTriggers) {
        cleanseBonusHeal += other.cleanseBonusHeal
        gainGoldBonusHealSelf += other.gainGoldBonusHealSelf
        restoreHealthAlsoHealHero += other.restoreHealthAlsoHealHero
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

    private func mergeAdvancedTriggers(_ other: CombatTraitTriggers) {
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
        healCleanseCount += other.healCleanseCount
        onceDeathReviveHealth = max(onceDeathReviveHealth, other.onceDeathReviveHealth)
        onceDeathReviveBlock += other.onceDeathReviveBlock
        blockPerTurn += other.blockPerTurn
        firstHitDoubleDamage = firstHitDoubleDamage || other.firstHitDoubleDamage
        leechChancePercent += other.leechChancePercent
        onHitAttackerBurn += other.onHitAttackerBurn
        turnFreezeDamageAllEnemies += other.turnFreezeDamageAllEnemies
        damageIncreasesEveryOtherTurn = damageIncreasesEveryOtherTurn || other.damageIncreasesEveryOtherTurn
    }

    private func mergeNewAffixTriggers(_ other: CombatTraitTriggers) {
        guard let otherAffix = other.affixReactions else { return }
        if affixReactions == nil {
            affixReactions = otherAffix.copy()
        } else {
            ensureAffixReactions().merge(otherAffix)
        }
    }
}
