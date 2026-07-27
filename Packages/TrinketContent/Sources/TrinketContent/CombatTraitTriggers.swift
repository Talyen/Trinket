import Foundation
import TrinketCore

public final class CombatTraitTriggers: @unchecked Sendable {
    public var cleanseBonusHeal: Int
    public var gainGoldBonusHealSelf: Int
    public var restoreHealthAlsoHealHero: Int
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
    public var blockPerTurn: Int
    public var firstHitDoubleDamage: Bool
    public var leechChancePercent: Double
    public var onHitAttackerBurn: Int
    public var turnFreezeDamageAllEnemies: Int
    public var damageIncreasesEveryOtherTurn: Bool
    public var affixReactions: CombatAffixReactionTriggers?

    public init(
        cleanseBonusHeal: Int = 0,
        gainGoldBonusHealSelf: Int = 0,
        restoreHealthAlsoHealHero: Int = 0,
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
        holyDamageBlockFlat: Int = 0,
        holyDamageCleanseCount: Int = 0,
        holyDamageHealFlat: Int = 0,
        dodgeGoldFlat: Int = 0,
        ignoreEnemyMitigationPercent: Double = 0,
        stunDealPhysicalFlat: Int = 0,
        damageWhileTargetStunnedBonus: Int = 0,
        enemyStunnedApplyMarked: Bool = false,
        dodgeBlockFlat: Int = 0,
        holyDamagePurgeCount: Int = 0,
        blockPerTurn: Int = 0,
        firstHitDoubleDamage: Bool = false,
        leechChancePercent: Double = 0,
        onHitAttackerBurn: Int = 0,
        turnFreezeDamageAllEnemies: Int = 0,
        damageIncreasesEveryOtherTurn: Bool = false,
        affixReactions: CombatAffixReactionTriggers? = nil
    ) {
        self.cleanseBonusHeal = cleanseBonusHeal
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.restoreHealthAlsoHealHero = restoreHealthAlsoHealHero
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
        self.blockPerTurn = blockPerTurn
        self.firstHitDoubleDamage = firstHitDoubleDamage
        self.leechChancePercent = leechChancePercent
        self.onHitAttackerBurn = onHitAttackerBurn
        self.turnFreezeDamageAllEnemies = turnFreezeDamageAllEnemies
        self.damageIncreasesEveryOtherTurn = damageIncreasesEveryOtherTurn
        self.affixReactions = affixReactions.map { $0.copy() }
    }

    public func copy() -> CombatTraitTriggers {
        CombatTraitTriggers(
            cleanseBonusHeal: cleanseBonusHeal,
            gainGoldBonusHealSelf: gainGoldBonusHealSelf,
            restoreHealthAlsoHealHero: restoreHealthAlsoHealHero,
            controlResistancePercent: controlResistancePercent,
            dodgeChanceBonus: dodgeChanceBonus,
            ambushBonusDamage: ambushBonusDamage,
            regenerationAmount: regenerationAmount,
            regenerationIntervalTurns: regenerationIntervalTurns,
            passiveMitigationFlat: passiveMitigationFlat,
            thornsPercent: thornsPercent,
            cannotBeHealed: cannotBeHealed,
            burnDecaySlowPercent: burnDecaySlowPercent,
            shieldErosionKeyword: shieldErosionKeyword,
            shieldErosionTicks: shieldErosionTicks,
            mitigationShredKeyword: mitigationShredKeyword,
            mitigationShredMultiplier: mitigationShredMultiplier,
            mitigationShredDurationTurns: mitigationShredDurationTurns,
            freezeControlVulnerabilityPercent: freezeControlVulnerabilityPercent,
            mitigationEffectivenessPenaltyPercent: mitigationEffectivenessPenaltyPercent,
            leechHealingMultiplier: leechHealingMultiplier,
            hemorrhageBleedBonus: hemorrhageBleedBonus,
            onBleedApplyPoison: onBleedApplyPoison,
            onBurnApplyPoison: onBurnApplyPoison,
            onBleedDealBurnDamage: onBleedDealBurnDamage,
            poisonDecayIncreaseChance: poisonDecayIncreaseChance,
            freezeDamageWhileBurningBonus: freezeDamageWhileBurningBonus,
            damageWhileTargetFrozenBonus: damageWhileTargetFrozenBonus,
            damageBelowHealthPercentThreshold: damageBelowHealthPercentThreshold,
            damageBelowHealthPercentKeyword: damageBelowHealthPercentKeyword,
            damageBelowHealthPercentBonus: damageBelowHealthPercentBonus,
            damageAfterDodgeBonus: damageAfterDodgeBonus,
            blockBrokenBlockFlat: blockBrokenBlockFlat,
            companionLeechSharePercent: companionLeechSharePercent,
            onceBelowHealthPercentThreshold: onceBelowHealthPercentThreshold,
            onceBelowHealthPercentHeal: onceBelowHealthPercentHeal,
            blockOnDeathsDoor: blockOnDeathsDoor,
            spendManaBlockFlat: spendManaBlockFlat,
            holyDamageBlockFlat: holyDamageBlockFlat,
            holyDamageCleanseCount: holyDamageCleanseCount,
            holyDamageHealFlat: holyDamageHealFlat,
            dodgeGoldFlat: dodgeGoldFlat,
            ignoreEnemyMitigationPercent: ignoreEnemyMitigationPercent,
            stunDealPhysicalFlat: stunDealPhysicalFlat,
            damageWhileTargetStunnedBonus: damageWhileTargetStunnedBonus,
            enemyStunnedApplyMarked: enemyStunnedApplyMarked,
            dodgeBlockFlat: dodgeBlockFlat,
            holyDamagePurgeCount: holyDamagePurgeCount,
            blockPerTurn: blockPerTurn,
            firstHitDoubleDamage: firstHitDoubleDamage,
            leechChancePercent: leechChancePercent,
            onHitAttackerBurn: onHitAttackerBurn,
            turnFreezeDamageAllEnemies: turnFreezeDamageAllEnemies,
            damageIncreasesEveryOtherTurn: damageIncreasesEveryOtherTurn,
            affixReactions: affixReactions
        )
    }

    public func merge(_ other: CombatTraitTriggers) {
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
        damageBelowHealthPercentThreshold = max(damageBelowHealthPercentThreshold, other.damageBelowHealthPercentThreshold)
        if damageBelowHealthPercentKeyword == nil {
            damageBelowHealthPercentKeyword = other.damageBelowHealthPercentKeyword
        }
        damageBelowHealthPercentBonus += other.damageBelowHealthPercentBonus
        damageAfterDodgeBonus += other.damageAfterDodgeBonus
        blockBrokenBlockFlat += other.blockBrokenBlockFlat
        companionLeechSharePercent += other.companionLeechSharePercent
        onceBelowHealthPercentThreshold = max(onceBelowHealthPercentThreshold, other.onceBelowHealthPercentThreshold)
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockOnDeathsDoor += other.blockOnDeathsDoor
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
