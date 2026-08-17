import Foundation
import TrinketCore

/// The `cleanse` trigger family of `CombatTraitTriggers`.
public struct CleanseTriggers: Equatable, Hashable, Sendable {
    public var cleanseBonusDraw: Int = 0
    public var holyDamageCleanseCount: Int = 0
    public var holyDamagePurgeCount: Int = 0
    public var holyDamagePurgeAll: Bool = false
    public var cleanseBlockPerStack: Int = 0
    public var cleanseAffectsBothHeroAndCompanion: Bool = false
    public var cleanseReflectDebuffToEnemy: Bool = false
    public var autoCleanseTeamPerTurn: Int = 0
    public var cleanseAlsoPurgesEnemyBuffs: Int = 0
    public var cleanseDodgeChanceBonus: Double = 0
    public var cleanseDodgeChanceBonusTurns: Int = 0
    public var cleansePartyBlock: Int = 0
    public var blockFirstDebuffPerTurn: Bool = false
    public var partyDebuffDurationHalved: Bool = false
    public var onCleansePoisonDealDamagePerStack: Int = 0

    public init(
        cleanseBonusDraw: Int = 0,
        holyDamageCleanseCount: Int = 0,
        holyDamagePurgeCount: Int = 0,
        holyDamagePurgeAll: Bool = false,
        cleanseBlockPerStack: Int = 0,
        cleanseAffectsBothHeroAndCompanion: Bool = false,
        cleanseReflectDebuffToEnemy: Bool = false,
        autoCleanseTeamPerTurn: Int = 0,
        cleanseAlsoPurgesEnemyBuffs: Int = 0,
        cleanseDodgeChanceBonus: Double = 0,
        cleanseDodgeChanceBonusTurns: Int = 0,
        cleansePartyBlock: Int = 0,
        blockFirstDebuffPerTurn: Bool = false,
        partyDebuffDurationHalved: Bool = false,
        onCleansePoisonDealDamagePerStack: Int = 0
    ) {
        self.cleanseBonusDraw = cleanseBonusDraw
        self.holyDamageCleanseCount = holyDamageCleanseCount
        self.holyDamagePurgeCount = holyDamagePurgeCount
        self.holyDamagePurgeAll = holyDamagePurgeAll
        self.cleanseBlockPerStack = cleanseBlockPerStack
        self.cleanseAffectsBothHeroAndCompanion = cleanseAffectsBothHeroAndCompanion
        self.cleanseReflectDebuffToEnemy = cleanseReflectDebuffToEnemy
        self.autoCleanseTeamPerTurn = autoCleanseTeamPerTurn
        self.cleanseAlsoPurgesEnemyBuffs = cleanseAlsoPurgesEnemyBuffs
        self.cleanseDodgeChanceBonus = cleanseDodgeChanceBonus
        self.cleanseDodgeChanceBonusTurns = cleanseDodgeChanceBonusTurns
        self.cleansePartyBlock = cleansePartyBlock
        self.blockFirstDebuffPerTurn = blockFirstDebuffPerTurn
        self.partyDebuffDurationHalved = partyDebuffDurationHalved
        self.onCleansePoisonDealDamagePerStack = onCleansePoisonDealDamagePerStack
    }
}

extension CleanseTriggers {
    mutating func merge(_ other: Self) {
        cleanseBonusDraw += other.cleanseBonusDraw
        holyDamageCleanseCount += other.holyDamageCleanseCount
        holyDamagePurgeCount += other.holyDamagePurgeCount
        holyDamagePurgeAll = holyDamagePurgeAll || other.holyDamagePurgeAll
        cleanseBlockPerStack += other.cleanseBlockPerStack
        cleanseAffectsBothHeroAndCompanion = cleanseAffectsBothHeroAndCompanion || other.cleanseAffectsBothHeroAndCompanion
        cleanseReflectDebuffToEnemy = cleanseReflectDebuffToEnemy || other.cleanseReflectDebuffToEnemy
        autoCleanseTeamPerTurn += other.autoCleanseTeamPerTurn
        cleanseAlsoPurgesEnemyBuffs += other.cleanseAlsoPurgesEnemyBuffs
        cleanseDodgeChanceBonus += other.cleanseDodgeChanceBonus
        cleanseDodgeChanceBonusTurns = max(cleanseDodgeChanceBonusTurns, other.cleanseDodgeChanceBonusTurns)
        cleansePartyBlock += other.cleansePartyBlock
        blockFirstDebuffPerTurn = blockFirstDebuffPerTurn || other.blockFirstDebuffPerTurn
        partyDebuffDurationHalved = partyDebuffDurationHalved || other.partyDebuffDurationHalved
        onCleansePoisonDealDamagePerStack += other.onCleansePoisonDealDamagePerStack
    }
}

extension CleanseTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            cleanseBonusDraw: values.decode(Int.self, "cleanseBonusDraw", default: 0),
            holyDamageCleanseCount: values.decode(Int.self, "holyDamageCleanseCount", default: 0),
            holyDamagePurgeCount: values.decode(Int.self, "holyDamagePurgeCount", default: 0),
            holyDamagePurgeAll: values.decode(Bool.self, "holyDamagePurgeAll", default: false),
            cleanseBlockPerStack: values.decode(Int.self, "cleanseBlockPerStack", default: 0),
            cleanseAffectsBothHeroAndCompanion: values.decode(Bool.self, "cleanseAffectsBothHeroAndCompanion", default: false),
            cleanseReflectDebuffToEnemy: values.decode(Bool.self, "cleanseReflectDebuffToEnemy", default: false),
            autoCleanseTeamPerTurn: values.decode(Int.self, "autoCleanseTeamPerTurn", default: 0),
            cleanseAlsoPurgesEnemyBuffs: values.decode(Int.self, "cleanseAlsoPurgesEnemyBuffs", default: 0),
            cleanseDodgeChanceBonus: values.decode(Double.self, "cleanseDodgeChanceBonus", default: 0),
            cleanseDodgeChanceBonusTurns: values.decode(Int.self, "cleanseDodgeChanceBonusTurns", default: 0),
            cleansePartyBlock: values.decode(Int.self, "cleansePartyBlock", default: 0),
            blockFirstDebuffPerTurn: values.decode(Bool.self, "blockFirstDebuffPerTurn", default: false),
            partyDebuffDurationHalved: values.decode(Bool.self, "partyDebuffDurationHalved", default: false),
            onCleansePoisonDealDamagePerStack: values.decode(Int.self, "onCleansePoisonDealDamagePerStack", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(cleanseBonusDraw, "cleanseBonusDraw", default: 0)
        try container.encodeNonDefault(holyDamageCleanseCount, "holyDamageCleanseCount", default: 0)
        try container.encodeNonDefault(holyDamagePurgeCount, "holyDamagePurgeCount", default: 0)
        try container.encodeNonDefault(holyDamagePurgeAll, "holyDamagePurgeAll", default: false)
        try container.encodeNonDefault(cleanseBlockPerStack, "cleanseBlockPerStack", default: 0)
        try container.encodeNonDefault(cleanseAffectsBothHeroAndCompanion, "cleanseAffectsBothHeroAndCompanion", default: false)
        try container.encodeNonDefault(cleanseReflectDebuffToEnemy, "cleanseReflectDebuffToEnemy", default: false)
        try container.encodeNonDefault(autoCleanseTeamPerTurn, "autoCleanseTeamPerTurn", default: 0)
        try container.encodeNonDefault(cleanseAlsoPurgesEnemyBuffs, "cleanseAlsoPurgesEnemyBuffs", default: 0)
        try container.encodeNonDefault(cleanseDodgeChanceBonus, "cleanseDodgeChanceBonus", default: 0)
        try container.encodeNonDefault(cleanseDodgeChanceBonusTurns, "cleanseDodgeChanceBonusTurns", default: 0)
        try container.encodeNonDefault(cleansePartyBlock, "cleansePartyBlock", default: 0)
        try container.encodeNonDefault(blockFirstDebuffPerTurn, "blockFirstDebuffPerTurn", default: false)
        try container.encodeNonDefault(partyDebuffDurationHalved, "partyDebuffDurationHalved", default: false)
        try container.encodeNonDefault(onCleansePoisonDealDamagePerStack, "onCleansePoisonDealDamagePerStack", default: 0)
    }
}
