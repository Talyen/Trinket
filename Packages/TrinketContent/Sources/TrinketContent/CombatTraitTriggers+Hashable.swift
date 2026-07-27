import Foundation
import TrinketCore

extension CombatTraitTriggers: Equatable {
    public static func == (lhs: CombatTraitTriggers, rhs: CombatTraitTriggers) -> Bool {
        lhs.cleanseBonusHeal == rhs.cleanseBonusHeal
            && lhs.gainGoldBonusHealSelf == rhs.gainGoldBonusHealSelf
            && lhs.restoreHealthAlsoHealHero == rhs.restoreHealthAlsoHealHero
            && lhs.controlResistancePercent == rhs.controlResistancePercent
            && lhs.dodgeChanceBonus == rhs.dodgeChanceBonus
            && lhs.ambushBonusDamage == rhs.ambushBonusDamage
            && lhs.regenerationAmount == rhs.regenerationAmount
            && lhs.regenerationIntervalTurns == rhs.regenerationIntervalTurns
            && lhs.passiveMitigationFlat == rhs.passiveMitigationFlat
            && lhs.thornsPercent == rhs.thornsPercent
            && lhs.cannotBeHealed == rhs.cannotBeHealed
            && lhs.burnDecaySlowPercent == rhs.burnDecaySlowPercent
            && lhs.shieldErosionKeyword == rhs.shieldErosionKeyword
            && lhs.shieldErosionTicks == rhs.shieldErosionTicks
            && lhs.mitigationShredKeyword == rhs.mitigationShredKeyword
            && lhs.mitigationShredMultiplier == rhs.mitigationShredMultiplier
            && lhs.mitigationShredDurationTurns == rhs.mitigationShredDurationTurns
            && lhs.freezeControlVulnerabilityPercent == rhs.freezeControlVulnerabilityPercent
            && lhs.mitigationEffectivenessPenaltyPercent == rhs.mitigationEffectivenessPenaltyPercent
            && lhs.leechHealingMultiplier == rhs.leechHealingMultiplier
            && lhs.hemorrhageBleedBonus == rhs.hemorrhageBleedBonus
            && lhs.onBleedApplyPoison == rhs.onBleedApplyPoison
            && lhs.onBurnApplyPoison == rhs.onBurnApplyPoison
            && lhs.onBleedDealBurnDamage == rhs.onBleedDealBurnDamage
            && lhs.poisonDecayIncreaseChance == rhs.poisonDecayIncreaseChance
            && lhs.freezeDamageWhileBurningBonus == rhs.freezeDamageWhileBurningBonus
            && lhs.damageWhileTargetFrozenBonus == rhs.damageWhileTargetFrozenBonus
            && lhs.damageBelowHealthPercentThreshold == rhs.damageBelowHealthPercentThreshold
            && lhs.damageBelowHealthPercentKeyword == rhs.damageBelowHealthPercentKeyword
            && lhs.damageBelowHealthPercentBonus == rhs.damageBelowHealthPercentBonus
            && lhs.damageAfterDodgeBonus == rhs.damageAfterDodgeBonus
            && lhs.blockBrokenBlockFlat == rhs.blockBrokenBlockFlat
            && lhs.companionLeechSharePercent == rhs.companionLeechSharePercent
            && lhs.onceBelowHealthPercentThreshold == rhs.onceBelowHealthPercentThreshold
            && lhs.onceBelowHealthPercentHeal == rhs.onceBelowHealthPercentHeal
            && lhs.blockOnDeathsDoor == rhs.blockOnDeathsDoor
            && lhs.spendManaBlockFlat == rhs.spendManaBlockFlat
            && lhs.holyDamageBlockFlat == rhs.holyDamageBlockFlat
            && lhs.holyDamageCleanseCount == rhs.holyDamageCleanseCount
            && lhs.holyDamageHealFlat == rhs.holyDamageHealFlat
            && lhs.dodgeGoldFlat == rhs.dodgeGoldFlat
            && lhs.ignoreEnemyMitigationPercent == rhs.ignoreEnemyMitigationPercent
            && lhs.stunDealPhysicalFlat == rhs.stunDealPhysicalFlat
            && lhs.damageWhileTargetStunnedBonus == rhs.damageWhileTargetStunnedBonus
            && lhs.enemyStunnedApplyMarked == rhs.enemyStunnedApplyMarked
            && lhs.dodgeBlockFlat == rhs.dodgeBlockFlat
            && lhs.holyDamagePurgeCount == rhs.holyDamagePurgeCount
            && lhs.blockPerTurn == rhs.blockPerTurn
            && lhs.firstHitDoubleDamage == rhs.firstHitDoubleDamage
            && lhs.leechChancePercent == rhs.leechChancePercent
            && lhs.onHitAttackerBurn == rhs.onHitAttackerBurn
            && lhs.turnFreezeDamageAllEnemies == rhs.turnFreezeDamageAllEnemies
            && lhs.damageIncreasesEveryOtherTurn == rhs.damageIncreasesEveryOtherTurn
            && lhs.affixReactions == rhs.affixReactions
    }
}

extension CombatTraitTriggers: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(cleanseBonusHeal)
        hasher.combine(gainGoldBonusHealSelf)
        hasher.combine(restoreHealthAlsoHealHero)
        hasher.combine(controlResistancePercent)
        hasher.combine(dodgeChanceBonus)
        hasher.combine(ambushBonusDamage)
        hasher.combine(regenerationAmount)
        hasher.combine(regenerationIntervalTurns)
        hasher.combine(passiveMitigationFlat)
        hasher.combine(thornsPercent)
        hasher.combine(cannotBeHealed)
        hasher.combine(burnDecaySlowPercent)
        hasher.combine(shieldErosionKeyword)
        hasher.combine(shieldErosionTicks)
        hasher.combine(mitigationShredKeyword)
        hasher.combine(mitigationShredMultiplier)
        hasher.combine(mitigationShredDurationTurns)
        hasher.combine(freezeControlVulnerabilityPercent)
        hasher.combine(mitigationEffectivenessPenaltyPercent)
        hasher.combine(leechHealingMultiplier)
        hasher.combine(hemorrhageBleedBonus)
        hasher.combine(onBleedApplyPoison)
        hasher.combine(onBurnApplyPoison)
        hasher.combine(onBleedDealBurnDamage)
        hasher.combine(poisonDecayIncreaseChance)
        hasher.combine(freezeDamageWhileBurningBonus)
        hasher.combine(damageWhileTargetFrozenBonus)
        hasher.combine(damageBelowHealthPercentThreshold)
        hasher.combine(damageBelowHealthPercentKeyword)
        hasher.combine(damageBelowHealthPercentBonus)
        hasher.combine(damageAfterDodgeBonus)
        hasher.combine(blockBrokenBlockFlat)
        hasher.combine(companionLeechSharePercent)
        hasher.combine(onceBelowHealthPercentThreshold)
        hasher.combine(onceBelowHealthPercentHeal)
        hasher.combine(blockOnDeathsDoor)
        hasher.combine(spendManaBlockFlat)
        hasher.combine(holyDamageBlockFlat)
        hasher.combine(holyDamageCleanseCount)
        hasher.combine(holyDamageHealFlat)
        hasher.combine(dodgeGoldFlat)
        hasher.combine(ignoreEnemyMitigationPercent)
        hasher.combine(stunDealPhysicalFlat)
        hasher.combine(damageWhileTargetStunnedBonus)
        hasher.combine(enemyStunnedApplyMarked)
        hasher.combine(dodgeBlockFlat)
        hasher.combine(holyDamagePurgeCount)
        hasher.combine(blockPerTurn)
        hasher.combine(firstHitDoubleDamage)
        hasher.combine(leechChancePercent)
        hasher.combine(onHitAttackerBurn)
        hasher.combine(turnFreezeDamageAllEnemies)
        hasher.combine(damageIncreasesEveryOtherTurn)
        hasher.combine(affixReactions)
    }
}
