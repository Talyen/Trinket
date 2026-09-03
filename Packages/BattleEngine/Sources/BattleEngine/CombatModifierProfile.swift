import Foundation
import TrinketContent
import TrinketCore

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var poisonDamageDealtPercent: Double
    public var healthRestoredBonus: Int
    public var leechGainedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var goldGainedPercent: Double
    public var blockGainedBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]
    public var damageTakenFlat: [Keyword: Int]
    public var damageTakenVulnerability: [Keyword: Double]
    public var companionDamageDealtBonus: Int
    public var companionBleedDamageDealtBonus: Int
    public var outgoingDamagePercent: Double
    public var incomingDamageReductionPercent: Double
    public var triggers: CombatTraitTriggers
    public var traitDisplayName: String?
    public var triggerAbilityNames: [String: String]

    public static let zero = Self()

    public init(
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        poisonDamageDealtPercent: Double = 0,
        healthRestoredBonus: Int = 0,
        leechGainedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        goldGainedPercent: Double = 0,
        blockGainedBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:],
        damageTakenFlat: [Keyword: Int] = [:],
        damageTakenVulnerability: [Keyword: Double] = [:],
        companionDamageDealtBonus: Int = 0,
        companionBleedDamageDealtBonus: Int = 0,
        outgoingDamagePercent: Double = 0,
        incomingDamageReductionPercent: Double = 0,
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
        traitDisplayName: String? = nil,
        triggerAbilityNames: [String: String] = [:],
    ) {
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.damageDealtBonus = damageDealtBonus
        self.poisonDamageDealtPercent = poisonDamageDealtPercent
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGainedBonus = leechGainedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.goldGainedPercent = goldGainedPercent
        self.blockGainedBonus = blockGainedBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
        self.damageTakenFlat = damageTakenFlat
        self.damageTakenVulnerability = damageTakenVulnerability
        self.companionDamageDealtBonus = companionDamageDealtBonus
        self.companionBleedDamageDealtBonus = companionBleedDamageDealtBonus
        self.outgoingDamagePercent = outgoingDamagePercent
        self.incomingDamageReductionPercent = incomingDamageReductionPercent
        self.triggers = triggers
        self.traitDisplayName = traitDisplayName
        self.triggerAbilityNames = triggerAbilityNames
    }

    public init(modifiers: [AffixModifier]) {
        self = .zero
        merge(modifiers)
    }

    public mutating func merge(_ modifiers: [AffixModifier]) {
        for modifier in modifiers {
            merge(modifier)
        }
    }

    public mutating func merge(_ other: Self) {
        maximumHealthBonus += other.maximumHealthBonus
        maximumManaBonus += other.maximumManaBonus
        for (keyword, amount) in other.damageDealtBonus {
            damageDealtBonus[keyword, default: 0] += amount
        }
        poisonDamageDealtPercent += other.poisonDamageDealtPercent
        healthRestoredBonus += other.healthRestoredBonus
        leechGainedBonus += other.leechGainedBonus
        leechHealingBonus += other.leechHealingBonus
        goldGainedBonus += other.goldGainedBonus
        goldGainedPercent += other.goldGainedPercent
        blockGainedBonus += other.blockGainedBonus
        bleedDurationBonus += other.bleedDurationBonus
        for (keyword, amount) in other.damageTakenReduction {
            damageTakenReduction[keyword, default: 0] += amount
        }
        for (keyword, amount) in other.damageTakenFlat {
            damageTakenFlat[keyword, default: 0] += amount
        }
        for (keyword, amount) in other.damageTakenVulnerability {
            damageTakenVulnerability[keyword, default: 0] += amount
        }
        companionDamageDealtBonus += other.companionDamageDealtBonus
        companionBleedDamageDealtBonus += other.companionBleedDamageDealtBonus
        outgoingDamagePercent += other.outgoingDamagePercent
        incomingDamageReductionPercent += other.incomingDamageReductionPercent
        triggers.merge(other.triggers)
        if traitDisplayName == nil {
            traitDisplayName = other.traitDisplayName
        }
        for (key, name) in other.triggerAbilityNames where triggerAbilityNames[key] == nil {
            triggerAbilityNames[key] = name
        }
    }

    public func triggerAbilityName(_ key: String, fallback: String) -> String {
        triggerAbilityNames[key] ?? fallback
    }

    public mutating func setTriggerAbilityName(_ key: String, _ name: String) {
        if triggerAbilityNames[key] == nil {
            triggerAbilityNames[key] = name
        }
    }

    public mutating func merge(_ modifier: AffixModifier) {
        modifier.apply(to: &self)
    }

    mutating func applyMaximumAffixStat(_ modifier: AffixModifier) -> Bool {
        switch modifier {
        case let .maximumHealth(amount):
            maximumHealthBonus += amount
        case let .maximumMana(amount):
            maximumManaBonus += amount
        default:
            return false
        }
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity - exhaustive affix mapping belongs in one switch
    mutating func applyAffixCombatBonus(_ modifier: AffixModifier) -> Bool {
        switch modifier {
        case let .damageDealt(keyword, amount):
            damageDealtBonus[keyword, default: 0] += amount
        case let .poisonDamageDealtPercent(amount):
            poisonDamageDealtPercent += amount
        case let .healthRestored(amount):
            healthRestoredBonus += amount
        case let .leechGainedPercent(amount):
            leechGainedBonus += amount
        case let .leechHealing(amount):
            leechHealingBonus += amount
        case let .goldGained(amount):
            goldGainedBonus += amount
        case let .goldGainedPercent(amount):
            goldGainedPercent += amount
        case let .blockGained(amount):
            blockGainedBonus += amount
        case let .damageTakenPercent(keyword, amount):
            damageTakenReduction[keyword, default: 0] += amount
        case let .damageTakenFlat(keyword, amount):
            damageTakenFlat[keyword, default: 0] += amount
        case let .damageTakenVulnerability(keyword, amount):
            damageTakenVulnerability[keyword, default: 0] += amount
        case let .companionDamageDealt(amount):
            companionDamageDealtBonus += amount
        case let .companionBleedDamageDealt(amount):
            companionBleedDamageDealtBonus += amount
        case let .outgoingDamagePercent(amount):
            outgoingDamagePercent += amount
        case let .incomingDamageReductionPercent(amount):
            incomingDamageReductionPercent += amount
        case let .dodgeChanceBonus(amount):
            triggers.dodgeChanceBonus += amount
        default:
            return false
        }
        return true
    }

    mutating func applyAffixDurationBonus(_ modifier: AffixModifier) {
        if case let .bleedDuration(amount) = modifier {
            bleedDurationBonus += amount
        }
    }

    public func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
    }

    public func damageDealtPercent(for keyword: Keyword) -> Double {
        keyword == .poison ? max(0, poisonDamageDealtPercent) : 0
    }

    public func damageTakenReduction(for keyword: Keyword) -> Double {
        min(1, max(0, damageTakenReduction[keyword, default: 0]))
    }

    public func damageTakenFlat(for keyword: Keyword) -> Int {
        max(0, damageTakenFlat[keyword, default: 0])
    }

    public func damageTakenVulnerability(for keyword: Keyword) -> Double {
        max(0, damageTakenVulnerability[keyword, default: 0])
    }
}

public extension AffixModifier {
    func apply(to profile: inout CombatModifierProfile) {
        if profile.applyMaximumAffixStat(self) {
            return
        }
        if profile.applyAffixCombatBonus(self) {
            return
        }
        profile.applyAffixDurationBonus(self)
    }
}

public struct CombatBuild: Equatable, Hashable, Sendable {
    public let combatant: Combatant
    public let modifiers: CombatModifierProfile

    public init(combatant: Combatant, modifiers: CombatModifierProfile) {
        self.combatant = combatant
        self.modifiers = modifiers
    }

    public var effectiveMaxHealth: Int {
        CombatantMaxValues.maxHealth(for: combatant, modifiers: modifiers)
    }

    public var effectiveMaxMana: Int {
        CombatantMaxValues.maxMana(for: combatant, modifiers: modifiers)
    }
}

public enum CombatantMaxValues {
    public static func maxHealth(for combatant: Combatant, modifiers: CombatModifierProfile) -> Int {
        combatant.maxHealth + modifiers.maximumHealthBonus
    }

    public static func maxMana(for combatant: Combatant, modifiers: CombatModifierProfile) -> Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + modifiers.maximumManaBonus
    }

    public static func maxHealth(for combatant: Combatant, flatBonus: Int, talentBonus: Int = 0) -> Int {
        combatant.maxHealth + flatBonus + talentBonus
    }

    public static func maxMana(for combatant: Combatant, flatBonus: Int, effectBonus: Int = 0) -> Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + flatBonus + effectBonus
    }
}

public extension CombatTraitTriggers {
    func apply(to profile: inout CombatModifierProfile) {
        profile.triggers.merge(self)
    }

    func apply(to profile: inout CombatModifierProfile, abilityName: String) {
        apply(to: &profile)
        for key in populatedFieldNames {
            profile.setTriggerAbilityName(key, abilityName)
        }
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

public extension CombatantTalentEffect {
    func apply(to profile: inout CombatModifierProfile) {
        profile.merge(modifiers)
        triggers.apply(to: &profile, abilityName: name)
    }
}

public extension CombatantTalentCatalog {
    static func profile(for unlockedNodeIDs: Set<String>) -> CombatModifierProfile {
        var profile = CombatModifierProfile.zero
        for nodeID in unlockedNodeIDs.sorted() {
            signatureTalents[nodeID]?.apply(to: &profile)
        }
        return profile
    }
}
