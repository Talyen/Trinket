import Foundation
import TrinketCore

/// Codable snapshot used to persist corrupted-item instance powers.
public struct ItemAffixPowerSnapshot: Codable, Equatable, Sendable {
    public var description: String
    public var modifiers: [AffixModifier]
    public var triggers: CombatTraitTriggersSnapshot

    public init(description: String, modifiers: [AffixModifier], triggers: CombatTraitTriggersSnapshot) {
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }

    public init(_ power: ItemAffixPower) {
        description = power.description
        modifiers = power.modifiers
        triggers = CombatTraitTriggersSnapshot(power.triggers)
    }

    public func power() -> ItemAffixPower {
        ItemAffixPower(
            description: description,
            modifiers: modifiers,
            triggers: triggers.triggers()
        )
    }
}

public struct CombatAffixReactionTriggersSnapshot: Codable, Equatable, Sendable {
    public var enemyStunnedPurgeCount: Int = 0
    public var enemyStunnedPurgeAll: Bool = false
    public var criticalPurgeCount: Int = 0
    public var criticalPurgeAll: Bool = false
    public var criticalGoldFlat: Int = 0
    public var leechRestoreManaFlat: Int = 0
    public var gainManaBlockFlat: Int = 0
    public var defeatEnemyGoldFlat: Int = 0
    public var leechGoldFlat: Int = 0
    public var dodgeHealFlat: Int = 0
    public var dodgeChanceBelowHealthPercentThreshold: Double = 0
    public var dodgeChanceBelowHealthPercentBonus: Double = 0
    public var dodgeDealStunFlat: Int = 0

    public init(_ value: CombatAffixReactionTriggers) {
        enemyStunnedPurgeCount = value.enemyStunnedPurgeCount
        enemyStunnedPurgeAll = value.enemyStunnedPurgeAll
        criticalPurgeCount = value.criticalPurgeCount
        criticalPurgeAll = value.criticalPurgeAll
        criticalGoldFlat = value.criticalGoldFlat
        leechRestoreManaFlat = value.leechRestoreManaFlat
        gainManaBlockFlat = value.gainManaBlockFlat
        defeatEnemyGoldFlat = value.defeatEnemyGoldFlat
        leechGoldFlat = value.leechGoldFlat
        dodgeHealFlat = value.dodgeHealFlat
        dodgeChanceBelowHealthPercentThreshold = value.dodgeChanceBelowHealthPercentThreshold
        dodgeChanceBelowHealthPercentBonus = value.dodgeChanceBelowHealthPercentBonus
        dodgeDealStunFlat = value.dodgeDealStunFlat
    }

    public func reactions() -> CombatAffixReactionTriggers {
        CombatAffixReactionTriggers(
            enemyStunnedPurgeCount: enemyStunnedPurgeCount,
            enemyStunnedPurgeAll: enemyStunnedPurgeAll,
            criticalPurgeCount: criticalPurgeCount,
            criticalPurgeAll: criticalPurgeAll,
            criticalGoldFlat: criticalGoldFlat,
            leechRestoreManaFlat: leechRestoreManaFlat,
            gainManaBlockFlat: gainManaBlockFlat,
            defeatEnemyGoldFlat: defeatEnemyGoldFlat,
            leechGoldFlat: leechGoldFlat,
            dodgeHealFlat: dodgeHealFlat,
            dodgeChanceBelowHealthPercentThreshold: dodgeChanceBelowHealthPercentThreshold,
            dodgeChanceBelowHealthPercentBonus: dodgeChanceBelowHealthPercentBonus,
            dodgeDealStunFlat: dodgeDealStunFlat
        )
    }
}

public struct CombatTraitTriggersSnapshot: Codable, Equatable, Sendable {
    public var cleanseBonusHeal: Int = 0
    public var gainGoldBonusHealSelf: Int = 0
    public var restoreHealthAlsoHealHero: Int = 0
    public var controlResistancePercent: Double = 0
    public var dodgeChanceBonus: Double = 0
    public var ambushBonusDamage: Int = 0
    public var regenerationAmount: Int = 0
    public var regenerationIntervalTurns: Int = 0
    public var passiveMitigationFlat: Int = 0
    public var thornsPercent: Double = 0
    public var cannotBeHealed: Bool = false
    public var burnDecaySlowPercent: Double = 0
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int = 0
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double = 0
    public var mitigationShredDurationTurns: Int = 0
    public var freezeControlVulnerabilityPercent: Double = 0
    public var mitigationEffectivenessPenaltyPercent: Double = 0
    public var leechHealingMultiplier: Double = 1
    public var hemorrhageBleedBonus: Int = 0
    public var onBleedApplyPoison: Int = 0
    public var onBurnApplyPoison: Int = 0
    public var onBleedDealBurnDamage: Int = 0
    public var poisonDecayIncreaseChance: Double = 0
    public var freezeDamageWhileBurningBonus: Int = 0
    public var damageWhileTargetFrozenBonus: Int = 0
    public var damageBelowHealthPercentThreshold: Double = 0
    public var damageBelowHealthPercentKeyword: Keyword?
    public var damageBelowHealthPercentBonus: Int = 0
    public var damageAfterDodgeBonus: Int = 0
    public var blockBrokenBlockFlat: Int = 0
    public var companionLeechSharePercent: Double = 0
    public var onceBelowHealthPercentThreshold: Double = 0
    public var onceBelowHealthPercentHeal: Int = 0
    public var blockOnDeathsDoor: Int = 0
    public var spendManaBlockFlat: Int = 0
    public var spendManaRandomDoTFlat: Int = 0
    public var holyDamageBlockFlat: Int = 0
    public var stunDamageBlockFlat: Int = 0
    public var holyDamageCleanseCount: Int = 0
    public var holyDamageHealFlat: Int = 0
    public var burnDamageHealFlat: Int = 0
    public var dodgeGoldFlat: Int = 0
    public var ignoreEnemyMitigationPercent: Double = 0
    public var stunDealPhysicalFlat: Int = 0
    public var damageWhileTargetStunnedBonus: Int = 0
    public var enemyStunnedApplyMarked: Bool = false
    public var dodgeBlockFlat: Int = 0
    public var dodgeApplyPoison: Int = 0
    public var holyDamagePurgeCount: Int = 0
    public var healCleanseCount: Int = 0
    public var onceDeathReviveHealth: Int = 0
    public var onceDeathReviveBlock: Int = 0
    public var blockPerTurn: Int = 0
    public var firstHitDoubleDamage: Bool = false
    public var leechChancePercent: Double = 0
    public var onHitAttackerBurn: Int = 0
    public var turnFreezeDamageAllEnemies: Int = 0
    public var damageIncreasesEveryOtherTurn: Bool = false
    public var affixReactions: CombatAffixReactionTriggersSnapshot?

    public init(_ value: CombatTraitTriggers) {
        apply(value)
    }

    // swiftlint:disable:next function_body_length
    private mutating func apply(_ value: CombatTraitTriggers) {
        cleanseBonusHeal = value.cleanseBonusHeal
        gainGoldBonusHealSelf = value.gainGoldBonusHealSelf
        restoreHealthAlsoHealHero = value.restoreHealthAlsoHealHero
        controlResistancePercent = value.controlResistancePercent
        dodgeChanceBonus = value.dodgeChanceBonus
        ambushBonusDamage = value.ambushBonusDamage
        regenerationAmount = value.regenerationAmount
        regenerationIntervalTurns = value.regenerationIntervalTurns
        passiveMitigationFlat = value.passiveMitigationFlat
        thornsPercent = value.thornsPercent
        cannotBeHealed = value.cannotBeHealed
        burnDecaySlowPercent = value.burnDecaySlowPercent
        shieldErosionKeyword = value.shieldErosionKeyword
        shieldErosionTicks = value.shieldErosionTicks
        mitigationShredKeyword = value.mitigationShredKeyword
        mitigationShredMultiplier = value.mitigationShredMultiplier
        mitigationShredDurationTurns = value.mitigationShredDurationTurns
        freezeControlVulnerabilityPercent = value.freezeControlVulnerabilityPercent
        mitigationEffectivenessPenaltyPercent = value.mitigationEffectivenessPenaltyPercent
        leechHealingMultiplier = value.leechHealingMultiplier
        hemorrhageBleedBonus = value.hemorrhageBleedBonus
        onBleedApplyPoison = value.onBleedApplyPoison
        onBurnApplyPoison = value.onBurnApplyPoison
        onBleedDealBurnDamage = value.onBleedDealBurnDamage
        poisonDecayIncreaseChance = value.poisonDecayIncreaseChance
        freezeDamageWhileBurningBonus = value.freezeDamageWhileBurningBonus
        damageWhileTargetFrozenBonus = value.damageWhileTargetFrozenBonus
        damageBelowHealthPercentThreshold = value.damageBelowHealthPercentThreshold
        damageBelowHealthPercentKeyword = value.damageBelowHealthPercentKeyword
        damageBelowHealthPercentBonus = value.damageBelowHealthPercentBonus
        damageAfterDodgeBonus = value.damageAfterDodgeBonus
        blockBrokenBlockFlat = value.blockBrokenBlockFlat
        companionLeechSharePercent = value.companionLeechSharePercent
        onceBelowHealthPercentThreshold = value.onceBelowHealthPercentThreshold
        onceBelowHealthPercentHeal = value.onceBelowHealthPercentHeal
        blockOnDeathsDoor = value.blockOnDeathsDoor
        spendManaBlockFlat = value.spendManaBlockFlat
        spendManaRandomDoTFlat = value.spendManaRandomDoTFlat
        holyDamageBlockFlat = value.holyDamageBlockFlat
        stunDamageBlockFlat = value.stunDamageBlockFlat
        holyDamageCleanseCount = value.holyDamageCleanseCount
        holyDamageHealFlat = value.holyDamageHealFlat
        burnDamageHealFlat = value.burnDamageHealFlat
        dodgeGoldFlat = value.dodgeGoldFlat
        ignoreEnemyMitigationPercent = value.ignoreEnemyMitigationPercent
        stunDealPhysicalFlat = value.stunDealPhysicalFlat
        damageWhileTargetStunnedBonus = value.damageWhileTargetStunnedBonus
        enemyStunnedApplyMarked = value.enemyStunnedApplyMarked
        dodgeBlockFlat = value.dodgeBlockFlat
        dodgeApplyPoison = value.dodgeApplyPoison
        holyDamagePurgeCount = value.holyDamagePurgeCount
        healCleanseCount = value.healCleanseCount
        onceDeathReviveHealth = value.onceDeathReviveHealth
        onceDeathReviveBlock = value.onceDeathReviveBlock
        blockPerTurn = value.blockPerTurn
        firstHitDoubleDamage = value.firstHitDoubleDamage
        leechChancePercent = value.leechChancePercent
        onHitAttackerBurn = value.onHitAttackerBurn
        turnFreezeDamageAllEnemies = value.turnFreezeDamageAllEnemies
        damageIncreasesEveryOtherTurn = value.damageIncreasesEveryOtherTurn
        affixReactions = value.affixReactions.map(CombatAffixReactionTriggersSnapshot.init)
    }

    // swiftlint:disable:next function_body_length
    public func triggers() -> CombatTraitTriggers {
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
            spendManaRandomDoTFlat: spendManaRandomDoTFlat,
            holyDamageBlockFlat: holyDamageBlockFlat,
            stunDamageBlockFlat: stunDamageBlockFlat,
            holyDamageCleanseCount: holyDamageCleanseCount,
            holyDamageHealFlat: holyDamageHealFlat,
            burnDamageHealFlat: burnDamageHealFlat,
            dodgeGoldFlat: dodgeGoldFlat,
            ignoreEnemyMitigationPercent: ignoreEnemyMitigationPercent,
            stunDealPhysicalFlat: stunDealPhysicalFlat,
            damageWhileTargetStunnedBonus: damageWhileTargetStunnedBonus,
            enemyStunnedApplyMarked: enemyStunnedApplyMarked,
            dodgeBlockFlat: dodgeBlockFlat,
            dodgeApplyPoison: dodgeApplyPoison,
            holyDamagePurgeCount: holyDamagePurgeCount,
            healCleanseCount: healCleanseCount,
            onceDeathReviveHealth: onceDeathReviveHealth,
            onceDeathReviveBlock: onceDeathReviveBlock,
            blockPerTurn: blockPerTurn,
            firstHitDoubleDamage: firstHitDoubleDamage,
            leechChancePercent: leechChancePercent,
            onHitAttackerBurn: onHitAttackerBurn,
            turnFreezeDamageAllEnemies: turnFreezeDamageAllEnemies,
            damageIncreasesEveryOtherTurn: damageIncreasesEveryOtherTurn,
            affixReactions: affixReactions?.reactions()
        )
    }
}

public enum ItemAffixPowerCoding {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func encode(_ powers: [ItemAffixPower]) throws -> Data {
        try encoder.encode(powers.map(ItemAffixPowerSnapshot.init))
    }

    public static func decode(_ data: Data) throws -> [ItemAffixPower] {
        try decoder.decode([ItemAffixPowerSnapshot].self, from: data).map { $0.power() }
    }
}
