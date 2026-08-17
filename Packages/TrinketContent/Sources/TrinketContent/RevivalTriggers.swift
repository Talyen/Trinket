import Foundation
import TrinketCore

/// The `revival` trigger family of `CombatTraitTriggers`.
public struct RevivalTriggers: Equatable, Hashable, Sendable {
    public var onceDeathReviveHealth: Int = 0
    public var onceDeathReviveBlock: Int = 0
    public var deathsDoorDurationBonusTurns: Int = 0
    public var reviveDealBurnDamage: Int = 0
    public var onSurviveDeathsDoorDamageBonusPercent: Double = 0
    public var deathsDoorDodgeAndDebuffImmunity: Bool = false
    public var deathsDoorExtraLethalProtection: Bool = false
    public var onDeathDealPhysicalDamageAllEnemies: Int = 0
    public var guaranteedCritWhileOnDeathsDoor: Bool = false
    public var onEnemyDefeatReviveSelfHealth: Int = 0
    public var onHeroFatalHealPercentMaxHealth: Double = 0
    public var onAllyDeathsDoorHealAndCleanse: Int = 0
    public var surviveDeathsDoorPartyHealPercent: Double = 0
    public var onEnemyDefeatRestoreHealthAndBlockHealth: Int = 0
    public var onEnemyDefeatRestoreHealthAndBlockBlock: Int = 0

    public init(
        onceDeathReviveHealth: Int = 0,
        onceDeathReviveBlock: Int = 0,
        deathsDoorDurationBonusTurns: Int = 0,
        reviveDealBurnDamage: Int = 0,
        onSurviveDeathsDoorDamageBonusPercent: Double = 0,
        deathsDoorDodgeAndDebuffImmunity: Bool = false,
        deathsDoorExtraLethalProtection: Bool = false,
        onDeathDealPhysicalDamageAllEnemies: Int = 0,
        guaranteedCritWhileOnDeathsDoor: Bool = false,
        onEnemyDefeatReviveSelfHealth: Int = 0,
        onHeroFatalHealPercentMaxHealth: Double = 0,
        onAllyDeathsDoorHealAndCleanse: Int = 0,
        surviveDeathsDoorPartyHealPercent: Double = 0,
        onEnemyDefeatRestoreHealthAndBlockHealth: Int = 0,
        onEnemyDefeatRestoreHealthAndBlockBlock: Int = 0
    ) {
        self.onceDeathReviveHealth = onceDeathReviveHealth
        self.onceDeathReviveBlock = onceDeathReviveBlock
        self.deathsDoorDurationBonusTurns = deathsDoorDurationBonusTurns
        self.reviveDealBurnDamage = reviveDealBurnDamage
        self.onSurviveDeathsDoorDamageBonusPercent = onSurviveDeathsDoorDamageBonusPercent
        self.deathsDoorDodgeAndDebuffImmunity = deathsDoorDodgeAndDebuffImmunity
        self.deathsDoorExtraLethalProtection = deathsDoorExtraLethalProtection
        self.onDeathDealPhysicalDamageAllEnemies = onDeathDealPhysicalDamageAllEnemies
        self.guaranteedCritWhileOnDeathsDoor = guaranteedCritWhileOnDeathsDoor
        self.onEnemyDefeatReviveSelfHealth = onEnemyDefeatReviveSelfHealth
        self.onHeroFatalHealPercentMaxHealth = onHeroFatalHealPercentMaxHealth
        self.onAllyDeathsDoorHealAndCleanse = onAllyDeathsDoorHealAndCleanse
        self.surviveDeathsDoorPartyHealPercent = surviveDeathsDoorPartyHealPercent
        self.onEnemyDefeatRestoreHealthAndBlockHealth = onEnemyDefeatRestoreHealthAndBlockHealth
        self.onEnemyDefeatRestoreHealthAndBlockBlock = onEnemyDefeatRestoreHealthAndBlockBlock
    }
}

extension RevivalTriggers {
    mutating func merge(_ other: Self) {
        onceDeathReviveHealth = max(onceDeathReviveHealth, other.onceDeathReviveHealth)
        onceDeathReviveBlock += other.onceDeathReviveBlock
        deathsDoorDurationBonusTurns += other.deathsDoorDurationBonusTurns
        reviveDealBurnDamage += other.reviveDealBurnDamage
        onSurviveDeathsDoorDamageBonusPercent += other.onSurviveDeathsDoorDamageBonusPercent
        deathsDoorDodgeAndDebuffImmunity = deathsDoorDodgeAndDebuffImmunity || other.deathsDoorDodgeAndDebuffImmunity
        deathsDoorExtraLethalProtection = deathsDoorExtraLethalProtection || other.deathsDoorExtraLethalProtection
        onDeathDealPhysicalDamageAllEnemies += other.onDeathDealPhysicalDamageAllEnemies
        guaranteedCritWhileOnDeathsDoor = guaranteedCritWhileOnDeathsDoor || other.guaranteedCritWhileOnDeathsDoor
        onEnemyDefeatReviveSelfHealth = max(onEnemyDefeatReviveSelfHealth, other.onEnemyDefeatReviveSelfHealth)
        onHeroFatalHealPercentMaxHealth += other.onHeroFatalHealPercentMaxHealth
        onAllyDeathsDoorHealAndCleanse = max(onAllyDeathsDoorHealAndCleanse, other.onAllyDeathsDoorHealAndCleanse)
        surviveDeathsDoorPartyHealPercent += other.surviveDeathsDoorPartyHealPercent
        onEnemyDefeatRestoreHealthAndBlockHealth += other.onEnemyDefeatRestoreHealthAndBlockHealth
        onEnemyDefeatRestoreHealthAndBlockBlock += other.onEnemyDefeatRestoreHealthAndBlockBlock
    }
}

extension RevivalTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            onceDeathReviveHealth: values.decode(Int.self, "onceDeathReviveHealth", default: 0),
            onceDeathReviveBlock: values.decode(Int.self, "onceDeathReviveBlock", default: 0),
            deathsDoorDurationBonusTurns: values.decode(Int.self, "deathsDoorDurationBonusTurns", default: 0),
            reviveDealBurnDamage: values.decode(Int.self, "reviveDealBurnDamage", default: 0),
            onSurviveDeathsDoorDamageBonusPercent: values.decode(Double.self, "onSurviveDeathsDoorDamageBonusPercent", default: 0),
            deathsDoorDodgeAndDebuffImmunity: values.decode(Bool.self, "deathsDoorDodgeAndDebuffImmunity", default: false),
            deathsDoorExtraLethalProtection: values.decode(Bool.self, "deathsDoorExtraLethalProtection", default: false),
            onDeathDealPhysicalDamageAllEnemies: values.decode(Int.self, "onDeathDealPhysicalDamageAllEnemies", default: 0),
            guaranteedCritWhileOnDeathsDoor: values.decode(Bool.self, "guaranteedCritWhileOnDeathsDoor", default: false),
            onEnemyDefeatReviveSelfHealth: values.decode(Int.self, "onEnemyDefeatReviveSelfHealth", default: 0),
            onHeroFatalHealPercentMaxHealth: values.decode(Double.self, "onHeroFatalHealPercentMaxHealth", default: 0),
            onAllyDeathsDoorHealAndCleanse: values.decode(Int.self, "onAllyDeathsDoorHealAndCleanse", default: 0),
            surviveDeathsDoorPartyHealPercent: values.decode(Double.self, "surviveDeathsDoorPartyHealPercent", default: 0),
            onEnemyDefeatRestoreHealthAndBlockHealth: values.decode(Int.self, "onEnemyDefeatRestoreHealthAndBlockHealth", default: 0),
            onEnemyDefeatRestoreHealthAndBlockBlock: values.decode(Int.self, "onEnemyDefeatRestoreHealthAndBlockBlock", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(onceDeathReviveHealth, "onceDeathReviveHealth", default: 0)
        try container.encodeNonDefault(onceDeathReviveBlock, "onceDeathReviveBlock", default: 0)
        try container.encodeNonDefault(deathsDoorDurationBonusTurns, "deathsDoorDurationBonusTurns", default: 0)
        try container.encodeNonDefault(reviveDealBurnDamage, "reviveDealBurnDamage", default: 0)
        try container.encodeNonDefault(onSurviveDeathsDoorDamageBonusPercent, "onSurviveDeathsDoorDamageBonusPercent", default: 0)
        try container.encodeNonDefault(deathsDoorDodgeAndDebuffImmunity, "deathsDoorDodgeAndDebuffImmunity", default: false)
        try container.encodeNonDefault(deathsDoorExtraLethalProtection, "deathsDoorExtraLethalProtection", default: false)
        try container.encodeNonDefault(onDeathDealPhysicalDamageAllEnemies, "onDeathDealPhysicalDamageAllEnemies", default: 0)
        try container.encodeNonDefault(guaranteedCritWhileOnDeathsDoor, "guaranteedCritWhileOnDeathsDoor", default: false)
        try container.encodeNonDefault(onEnemyDefeatReviveSelfHealth, "onEnemyDefeatReviveSelfHealth", default: 0)
        try container.encodeNonDefault(onHeroFatalHealPercentMaxHealth, "onHeroFatalHealPercentMaxHealth", default: 0)
        try container.encodeNonDefault(onAllyDeathsDoorHealAndCleanse, "onAllyDeathsDoorHealAndCleanse", default: 0)
        try container.encodeNonDefault(surviveDeathsDoorPartyHealPercent, "surviveDeathsDoorPartyHealPercent", default: 0)
        try container.encodeNonDefault(onEnemyDefeatRestoreHealthAndBlockHealth, "onEnemyDefeatRestoreHealthAndBlockHealth", default: 0)
        try container.encodeNonDefault(onEnemyDefeatRestoreHealthAndBlockBlock, "onEnemyDefeatRestoreHealthAndBlockBlock", default: 0)
    }
}
