import Foundation
import TrinketContent

public extension CombatTraitTriggers {
    // Trait trigger application mirrors the full CombatModifierProfile trigger surface.
    // swiftlint:disable:next function_body_length
    func apply(to profile: inout CombatModifierProfile) {
        profile.cleanseBonusHeal += cleanseBonusHeal
        profile.gainGoldBonusHealSelf += gainGoldBonusHealSelf
        profile.restoreHealthAlsoHealHero += restoreHealthAlsoHealHero
        profile.controlResistancePercent += controlResistancePercent
        profile.dodgeChanceBonus += dodgeChanceBonus
        profile.physicalDodgeChanceBonus += physicalDodgeChanceBonus
        profile.ambushBonusDamage += ambushBonusDamage
        profile.regenerationAmount += regenerationAmount
        profile.regenerationIntervalTurns = max(profile.regenerationIntervalTurns, regenerationIntervalTurns)
        profile.passiveMitigationFlat += passiveMitigationFlat
        profile.thornsPercent += thornsPercent
        profile.cannotBeHealed = profile.cannotBeHealed || cannotBeHealed
        profile.burnDecaySlowPercent += burnDecaySlowPercent
        if profile.shieldErosionKeyword == nil {
            profile.shieldErosionKeyword = shieldErosionKeyword
        }
        profile.shieldErosionTicks += shieldErosionTicks
        if profile.mitigationShredKeyword == nil {
            profile.mitigationShredKeyword = mitigationShredKeyword
        }
        profile.mitigationShredMultiplier = max(profile.mitigationShredMultiplier, mitigationShredMultiplier)
        profile.mitigationShredDurationTurns = max(
            profile.mitigationShredDurationTurns,
            mitigationShredDurationTurns
        )
        profile.freezeControlVulnerabilityPercent += freezeControlVulnerabilityPercent
        profile.mitigationEffectivenessPenaltyPercent += mitigationEffectivenessPenaltyPercent
        profile.leechHealingMultiplier *= leechHealingMultiplier
        profile.hemorrhageBleedBonus += hemorrhageBleedBonus
        profile.onBleedApplyPoison += onBleedApplyPoison
        profile.onBurnApplyPoison += onBurnApplyPoison
        profile.onBleedDealBurnDamage += onBleedDealBurnDamage
        profile.everyNthBleedApplyCount = max(profile.everyNthBleedApplyCount, everyNthBleedApplyCount)
        profile.everyNthBleedApplyPoisonPotency += everyNthBleedApplyPoisonPotency
        profile.freezeDamageWhileFrozenBonus += freezeDamageWhileFrozenBonus
        profile.damageWhileTargetFrozenBonus += damageWhileTargetFrozenBonus
        profile.damageBelowHealthPercentThreshold = max(
            profile.damageBelowHealthPercentThreshold,
            damageBelowHealthPercentThreshold
        )
        if profile.damageBelowHealthPercentKeyword == nil {
            profile.damageBelowHealthPercentKeyword = damageBelowHealthPercentKeyword
        }
        profile.damageBelowHealthPercentBonus += damageBelowHealthPercentBonus
        profile.damageAfterDodgeBonus += damageAfterDodgeBonus
        profile.refreshBleedOnReapply = profile.refreshBleedOnReapply || refreshBleedOnReapply
        profile.blockBrokenBlockFlat += blockBrokenBlockFlat
        profile.firstHitApplyMarked = profile.firstHitApplyMarked || firstHitApplyMarked
        profile.companionHealSharePercent += companionHealSharePercent
        profile.onceBelowHealthPercentThreshold = max(
            profile.onceBelowHealthPercentThreshold,
            onceBelowHealthPercentThreshold
        )
        profile.onceBelowHealthPercentHeal += onceBelowHealthPercentHeal
        profile.blockPerActionWhileDeathsDoor += blockPerActionWhileDeathsDoor
        profile.everyNthBurnTurnCount = max(profile.everyNthBurnTurnCount, everyNthBurnTurnCount)
        profile.everyNthBurnTurnFreezeDamage += everyNthBurnTurnFreezeDamage
        profile.spendManaBlockFlat += spendManaBlockFlat
        profile.holyDamageBlockFlat += holyDamageBlockFlat
        profile.holyDamageCleanseCount += holyDamageCleanseCount
        profile.holyDamageHealFlat += holyDamageHealFlat
        profile.dodgeGoldFlat += dodgeGoldFlat
        profile.ignoreEnemyMitigationPercent += ignoreEnemyMitigationPercent
        profile.stunDealPhysicalFlat += stunDealPhysicalFlat
        profile.damageWhileTargetStunnedBonus += damageWhileTargetStunnedBonus
        profile.enemyStunnedApplyMarked = profile.enemyStunnedApplyMarked || enemyStunnedApplyMarked
        profile.dodgeBlockFlat += dodgeBlockFlat
        profile.holyDamagePurgeCount += holyDamagePurgeCount
    }
}

public extension CombatantTraitDefinition {
    func apply(to profile: inout CombatModifierProfile) {
        for modifier in modifiers {
            profile.merge(modifier)
        }
        triggers.apply(to: &profile)
    }
}
