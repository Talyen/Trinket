import Foundation
import TrinketCore

private struct TriggerCodingKey: CodingKey {
    let stringValue: String

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue _: Int) {
        nil
    }

    var intValue: Int? {
        nil
    }
}

private struct DefaultingTriggerDecoder {
    private let values: KeyedDecodingContainer<TriggerCodingKey>

    init(_ decoder: Decoder) throws {
        values = try decoder.container(keyedBy: TriggerCodingKey.self)
    }

    private init(values: KeyedDecodingContainer<TriggerCodingKey>) {
        self.values = values
    }

    func decode<Value: Decodable>(
        _ type: Value.Type,
        _ key: String,
        default defaultValue: Value
    ) throws -> Value {
        try values.decodeIfPresent(type, forKey: TriggerCodingKey(key)) ?? defaultValue
    }

    func nested(_ key: String) throws -> Self? {
        let codingKey = TriggerCodingKey(key)
        guard values.contains(codingKey), try !values.decodeNil(forKey: codingKey) else {
            return nil
        }
        return try Self(values: values.nestedContainer(keyedBy: TriggerCodingKey.self, forKey: codingKey))
    }
}

public extension CombatTraitTriggers {
    // swiftlint:disable:next function_body_length
    init(from decoder: Decoder) throws {
        let values = try DefaultingTriggerDecoder(decoder)
        let legacyAffix = try values.nested("affixReactions")

        let enemyStunnedPurgeCount = try values.decode(
            Int.self,
            "enemyStunnedPurgeCount",
            default: legacyAffix?.decode(Int.self, "enemyStunnedPurgeCount", default: 0) ?? 0
        )
        let enemyStunnedPurgeAll = try values.decode(
            Bool.self,
            "enemyStunnedPurgeAll",
            default: legacyAffix?.decode(Bool.self, "enemyStunnedPurgeAll", default: false) ?? false
        )
        let criticalPurgeCount = try values.decode(
            Int.self,
            "criticalPurgeCount",
            default: legacyAffix?.decode(Int.self, "criticalPurgeCount", default: 0) ?? 0
        )
        let criticalPurgeAll = try values.decode(
            Bool.self,
            "criticalPurgeAll",
            default: legacyAffix?.decode(Bool.self, "criticalPurgeAll", default: false) ?? false
        )
        let criticalGoldFlat = try values.decode(
            Int.self,
            "criticalGoldFlat",
            default: legacyAffix?.decode(Int.self, "criticalGoldFlat", default: 0) ?? 0
        )
        let leechRestoreManaFlat = try values.decode(
            Int.self,
            "leechRestoreManaFlat",
            default: legacyAffix?.decode(Int.self, "leechRestoreManaFlat", default: 0) ?? 0
        )
        let gainManaBlockFlat = try values.decode(
            Int.self,
            "gainManaBlockFlat",
            default: legacyAffix?.decode(Int.self, "gainManaBlockFlat", default: 0) ?? 0
        )
        let defeatEnemyGoldFlat = try values.decode(
            Int.self,
            "defeatEnemyGoldFlat",
            default: legacyAffix?.decode(Int.self, "defeatEnemyGoldFlat", default: 0) ?? 0
        )
        let leechGoldFlat = try values.decode(
            Int.self,
            "leechGoldFlat",
            default: legacyAffix?.decode(Int.self, "leechGoldFlat", default: 0) ?? 0
        )
        let dodgeHealFlat = try values.decode(
            Int.self,
            "dodgeHealFlat",
            default: legacyAffix?.decode(Int.self, "dodgeHealFlat", default: 0) ?? 0
        )
        let dodgeChanceBelowHealthPercentThreshold = try values.decode(
            Double.self,
            "dodgeChanceBelowHealthPercentThreshold",
            default: legacyAffix?.decode(Double.self, "dodgeChanceBelowHealthPercentThreshold", default: 0) ?? 0
        )
        let dodgeChanceBelowHealthPercentBonus = try values.decode(
            Double.self,
            "dodgeChanceBelowHealthPercentBonus",
            default: legacyAffix?.decode(Double.self, "dodgeChanceBelowHealthPercentBonus", default: 0) ?? 0
        )
        let dodgeDealStunFlat = try values.decode(
            Int.self,
            "dodgeDealStunFlat",
            default: legacyAffix?.decode(Int.self, "dodgeDealStunFlat", default: 0) ?? 0
        )

        try self.init(
            cleanseBonusHeal: values.decode(Int.self, "cleanseBonusHeal", default: 0),
            gainGoldBonusHealSelf: values.decode(Int.self, "gainGoldBonusHealSelf", default: 0),
            restoreHealthAlsoHealHero: values.decode(Int.self, "restoreHealthAlsoHealHero", default: 0),
            controlResistancePercent: values.decode(Double.self, "controlResistancePercent", default: 0),
            dodgeChanceBonus: values.decode(Double.self, "dodgeChanceBonus", default: 0),
            ambushBonusDamage: values.decode(Int.self, "ambushBonusDamage", default: 0),
            regenerationAmount: values.decode(Int.self, "regenerationAmount", default: 0),
            regenerationIntervalTurns: values.decode(Int.self, "regenerationIntervalTurns", default: 0),
            passiveMitigationFlat: values.decode(Int.self, "passiveMitigationFlat", default: 0),
            thornsPercent: values.decode(Double.self, "thornsPercent", default: 0),
            cannotBeHealed: values.decode(Bool.self, "cannotBeHealed", default: false),
            burnDecaySlowPercent: values.decode(Double.self, "burnDecaySlowPercent", default: 0),
            shieldErosionKeyword: values.decode(Keyword?.self, "shieldErosionKeyword", default: nil),
            shieldErosionTicks: values.decode(Int.self, "shieldErosionTicks", default: 0),
            mitigationShredKeyword: values.decode(Keyword?.self, "mitigationShredKeyword", default: nil),
            mitigationShredMultiplier: values.decode(Double.self, "mitigationShredMultiplier", default: 0),
            mitigationShredDurationTurns: values.decode(Int.self, "mitigationShredDurationTurns", default: 0),
            freezeControlVulnerabilityPercent: values.decode(
                Double.self,
                "freezeControlVulnerabilityPercent",
                default: 0
            ),
            mitigationEffectivenessPenaltyPercent: values.decode(
                Double.self,
                "mitigationEffectivenessPenaltyPercent",
                default: 0
            ),
            leechHealingMultiplier: values.decode(Double.self, "leechHealingMultiplier", default: 1),
            hemorrhageBleedBonus: values.decode(Int.self, "hemorrhageBleedBonus", default: 0),
            onBleedApplyPoison: values.decode(Int.self, "onBleedApplyPoison", default: 0),
            onBurnApplyPoison: values.decode(Int.self, "onBurnApplyPoison", default: 0),
            onBleedDealBurnDamage: values.decode(Int.self, "onBleedDealBurnDamage", default: 0),
            poisonDecayIncreaseChance: values.decode(Double.self, "poisonDecayIncreaseChance", default: 0),
            freezeDamageWhileBurningBonus: values.decode(Int.self, "freezeDamageWhileBurningBonus", default: 0),
            damageWhileTargetFrozenBonus: values.decode(Int.self, "damageWhileTargetFrozenBonus", default: 0),
            damageBelowHealthPercentThreshold: values.decode(
                Double.self,
                "damageBelowHealthPercentThreshold",
                default: 0
            ),
            damageBelowHealthPercentKeyword: values.decode(
                Keyword?.self,
                "damageBelowHealthPercentKeyword",
                default: nil
            ),
            damageBelowHealthPercentBonus: values.decode(Int.self, "damageBelowHealthPercentBonus", default: 0),
            damageAfterDodgeBonus: values.decode(Int.self, "damageAfterDodgeBonus", default: 0),
            blockBrokenBlockFlat: values.decode(Int.self, "blockBrokenBlockFlat", default: 0),
            companionLeechSharePercent: values.decode(Double.self, "companionLeechSharePercent", default: 0),
            onceBelowHealthPercentThreshold: values.decode(
                Double.self,
                "onceBelowHealthPercentThreshold",
                default: 0
            ),
            onceBelowHealthPercentHeal: values.decode(Int.self, "onceBelowHealthPercentHeal", default: 0),
            blockOnDeathsDoor: values.decode(Int.self, "blockOnDeathsDoor", default: 0),
            spendManaBlockFlat: values.decode(Int.self, "spendManaBlockFlat", default: 0),
            spendManaRandomDoTFlat: values.decode(Int.self, "spendManaRandomDoTFlat", default: 0),
            holyDamageBlockFlat: values.decode(Int.self, "holyDamageBlockFlat", default: 0),
            stunDamageBlockFlat: values.decode(Int.self, "stunDamageBlockFlat", default: 0),
            holyDamageCleanseCount: values.decode(Int.self, "holyDamageCleanseCount", default: 0),
            holyDamageHealFlat: values.decode(Int.self, "holyDamageHealFlat", default: 0),
            burnDamageHealFlat: values.decode(Int.self, "burnDamageHealFlat", default: 0),
            dodgeGoldFlat: values.decode(Int.self, "dodgeGoldFlat", default: 0),
            ignoreEnemyMitigationPercent: values.decode(Double.self, "ignoreEnemyMitigationPercent", default: 0),
            stunDealPhysicalFlat: values.decode(Int.self, "stunDealPhysicalFlat", default: 0),
            damageWhileTargetStunnedBonus: values.decode(Int.self, "damageWhileTargetStunnedBonus", default: 0),
            enemyStunnedApplyMarked: values.decode(Bool.self, "enemyStunnedApplyMarked", default: false),
            dodgeBlockFlat: values.decode(Int.self, "dodgeBlockFlat", default: 0),
            dodgeApplyPoison: values.decode(Int.self, "dodgeApplyPoison", default: 0),
            holyDamagePurgeCount: values.decode(Int.self, "holyDamagePurgeCount", default: 0),
            healCleanseCount: values.decode(Int.self, "healCleanseCount", default: 0),
            onceDeathReviveHealth: values.decode(Int.self, "onceDeathReviveHealth", default: 0),
            onceDeathReviveBlock: values.decode(Int.self, "onceDeathReviveBlock", default: 0),
            blockPerTurn: values.decode(Int.self, "blockPerTurn", default: 0),
            firstHitDoubleDamage: values.decode(Bool.self, "firstHitDoubleDamage", default: false),
            leechChancePercent: values.decode(Double.self, "leechChancePercent", default: 0),
            onHitAttackerBurn: values.decode(Int.self, "onHitAttackerBurn", default: 0),
            turnFreezeDamageAllEnemies: values.decode(Int.self, "turnFreezeDamageAllEnemies", default: 0),
            damageIncreasesEveryOtherTurn: values.decode(
                Bool.self,
                "damageIncreasesEveryOtherTurn",
                default: false
            ),
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
