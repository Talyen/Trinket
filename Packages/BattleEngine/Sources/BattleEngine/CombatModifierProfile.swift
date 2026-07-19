import Foundation
import TrinketContent
import TrinketCore

public struct CombatModifierProfile: Equatable, Hashable, Sendable {
    public var statBonuses: PrimaryStats
    public var maximumHealthBonus: Int
    public var maximumManaBonus: Int
    public var damageDealtBonus: [Keyword: Int]
    public var healthRestoredBonus: Int
    public var leechGainedBonus: Double
    public var leechHealingBonus: Int
    public var goldGainedBonus: Int
    public var blockGainedBonus: Int
    public var leechDurationBonus: Int
    public var bleedDurationBonus: Int
    public var damageTakenReduction: [Keyword: Double]
    public var damageTakenFlat: [Keyword: Int]
    public var damageTakenVulnerability: [Keyword: Double]
    public var companionDamageDealtBonus: Int
    public var manaCostReductionPercent: Double
    public var cleanseBonusHeal: Int
    public var gainGoldBonusHealSelf: Int
    public var restoreHealthAlsoHealHero: Int
    public var controlResistancePercent: Double
    public var dodgeChanceBonus: Double
    public var physicalDodgeChanceBonus: Double
    public var ambushBonusDamage: Int
    public var regenerationAmount: Int
    public var regenerationIntervalTicks: Int
    public var passiveMitigationFlat: Int
    public var thornsPercent: Double
    public var cannotBeHealed: Bool
    public var burnDecaySlowPercent: Double
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double
    public var mitigationShredDurationTicks: Int
    public var freezeControlVulnerabilityPercent: Double
    public var mitigationEffectivenessPenaltyPercent: Double
    public var leechHealingMultiplier: Double
    public var hemorrhageBleedBonus: Int
    public var onBleedApplyPoison: Int
    public var onBurnApplyPoison: Int
    public var onBleedDealBurnDamage: Int
    public var everyNthBleedApplyCount: Int
    public var everyNthBleedApplyPoisonPotency: Int
    public var freezeDamageWhileFrozenBonus: Int
    public var damageWhileTargetFrozenBonus: Int
    public var damageBelowHealthPercentThreshold: Double
    public var damageBelowHealthPercentKeyword: Keyword?
    public var damageBelowHealthPercentBonus: Int
    public var damageAfterDodgeBonus: Int
    public var refreshBleedOnReapply: Bool
    public var blockBrokenBlockFlat: Int
    public var blockGainedCleanseCount: Int
    public var blockGainedCleanseIntervalTicks: Int
    public var enemyStunnedHasteDurationTicks: Int
    public var firstHitApplyMarked: Bool
    public var companionActLeechPercent: Double
    public var companionActLeechDurationTicks: Int
    public var companionHealSharePercent: Double
    public var onceBelowHealthPercentThreshold: Double
    public var onceBelowHealthPercentHeal: Int
    public var blockPerActionWhileDeathsDoor: Int
    public var everyNthBurnTickCount: Int
    public var everyNthBurnTickFreezeDamage: Int
    public var traitDisplayName: String?

    public static let zero = CombatModifierProfile()

    // Memberwise init mirrors the large profile surface; keep assignments colocated.
    // swiftlint:disable:next function_body_length
    public init(
        statBonuses: PrimaryStats = PrimaryStats(),
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        damageDealtBonus: [Keyword: Int] = [:],
        healthRestoredBonus: Int = 0,
        leechGainedBonus: Double = 0,
        leechHealingBonus: Int = 0,
        goldGainedBonus: Int = 0,
        blockGainedBonus: Int = 0,
        leechDurationBonus: Int = 0,
        bleedDurationBonus: Int = 0,
        damageTakenReduction: [Keyword: Double] = [:],
        damageTakenFlat: [Keyword: Int] = [:],
        damageTakenVulnerability: [Keyword: Double] = [:],
        companionDamageDealtBonus: Int = 0,
        manaCostReductionPercent: Double = 0,
        cleanseBonusHeal: Int = 0,
        gainGoldBonusHealSelf: Int = 0,
        restoreHealthAlsoHealHero: Int = 0,
        controlResistancePercent: Double = 0,
        dodgeChanceBonus: Double = 0,
        physicalDodgeChanceBonus: Double = 0,
        ambushBonusDamage: Int = 0,
        regenerationAmount: Int = 0,
        regenerationIntervalTicks: Int = 0,
        passiveMitigationFlat: Int = 0,
        thornsPercent: Double = 0,
        cannotBeHealed: Bool = false,
        burnDecaySlowPercent: Double = 0,
        shieldErosionKeyword: Keyword? = nil,
        shieldErosionTicks: Int = 0,
        mitigationShredKeyword: Keyword? = nil,
        mitigationShredMultiplier: Double = 0,
        mitigationShredDurationTicks: Int = 0,
        freezeControlVulnerabilityPercent: Double = 0,
        mitigationEffectivenessPenaltyPercent: Double = 0,
        leechHealingMultiplier: Double = 1,
        hemorrhageBleedBonus: Int = 0,
        onBleedApplyPoison: Int = 0,
        onBurnApplyPoison: Int = 0,
        onBleedDealBurnDamage: Int = 0,
        everyNthBleedApplyCount: Int = 0,
        everyNthBleedApplyPoisonPotency: Int = 0,
        freezeDamageWhileFrozenBonus: Int = 0,
        damageWhileTargetFrozenBonus: Int = 0,
        damageBelowHealthPercentThreshold: Double = 0,
        damageBelowHealthPercentKeyword: Keyword? = nil,
        damageBelowHealthPercentBonus: Int = 0,
        damageAfterDodgeBonus: Int = 0,
        refreshBleedOnReapply: Bool = false,
        blockBrokenBlockFlat: Int = 0,
        blockGainedCleanseCount: Int = 0,
        blockGainedCleanseIntervalTicks: Int = 0,
        enemyStunnedHasteDurationTicks: Int = 0,
        firstHitApplyMarked: Bool = false,
        companionActLeechPercent: Double = 0,
        companionActLeechDurationTicks: Int = 0,
        companionHealSharePercent: Double = 0,
        onceBelowHealthPercentThreshold: Double = 0,
        onceBelowHealthPercentHeal: Int = 0,
        blockPerActionWhileDeathsDoor: Int = 0,
        everyNthBurnTickCount: Int = 0,
        everyNthBurnTickFreezeDamage: Int = 0,
        traitDisplayName: String? = nil
    ) {
        self.statBonuses = statBonuses
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.damageDealtBonus = damageDealtBonus
        self.healthRestoredBonus = healthRestoredBonus
        self.leechGainedBonus = leechGainedBonus
        self.leechHealingBonus = leechHealingBonus
        self.goldGainedBonus = goldGainedBonus
        self.blockGainedBonus = blockGainedBonus
        self.leechDurationBonus = leechDurationBonus
        self.bleedDurationBonus = bleedDurationBonus
        self.damageTakenReduction = damageTakenReduction
        self.damageTakenFlat = damageTakenFlat
        self.damageTakenVulnerability = damageTakenVulnerability
        self.companionDamageDealtBonus = companionDamageDealtBonus
        self.manaCostReductionPercent = manaCostReductionPercent
        self.cleanseBonusHeal = cleanseBonusHeal
        self.gainGoldBonusHealSelf = gainGoldBonusHealSelf
        self.restoreHealthAlsoHealHero = restoreHealthAlsoHealHero
        self.controlResistancePercent = controlResistancePercent
        self.dodgeChanceBonus = dodgeChanceBonus
        self.physicalDodgeChanceBonus = physicalDodgeChanceBonus
        self.ambushBonusDamage = ambushBonusDamage
        self.regenerationAmount = regenerationAmount
        self.regenerationIntervalTicks = regenerationIntervalTicks
        self.passiveMitigationFlat = passiveMitigationFlat
        self.thornsPercent = thornsPercent
        self.cannotBeHealed = cannotBeHealed
        self.burnDecaySlowPercent = burnDecaySlowPercent
        self.shieldErosionKeyword = shieldErosionKeyword
        self.shieldErosionTicks = shieldErosionTicks
        self.mitigationShredKeyword = mitigationShredKeyword
        self.mitigationShredMultiplier = mitigationShredMultiplier
        self.mitigationShredDurationTicks = mitigationShredDurationTicks
        self.freezeControlVulnerabilityPercent = freezeControlVulnerabilityPercent
        self.mitigationEffectivenessPenaltyPercent = mitigationEffectivenessPenaltyPercent
        self.leechHealingMultiplier = leechHealingMultiplier
        self.hemorrhageBleedBonus = hemorrhageBleedBonus
        self.onBleedApplyPoison = onBleedApplyPoison
        self.onBurnApplyPoison = onBurnApplyPoison
        self.onBleedDealBurnDamage = onBleedDealBurnDamage
        self.everyNthBleedApplyCount = everyNthBleedApplyCount
        self.everyNthBleedApplyPoisonPotency = everyNthBleedApplyPoisonPotency
        self.freezeDamageWhileFrozenBonus = freezeDamageWhileFrozenBonus
        self.damageWhileTargetFrozenBonus = damageWhileTargetFrozenBonus
        self.damageBelowHealthPercentThreshold = damageBelowHealthPercentThreshold
        self.damageBelowHealthPercentKeyword = damageBelowHealthPercentKeyword
        self.damageBelowHealthPercentBonus = damageBelowHealthPercentBonus
        self.damageAfterDodgeBonus = damageAfterDodgeBonus
        self.refreshBleedOnReapply = refreshBleedOnReapply
        self.blockBrokenBlockFlat = blockBrokenBlockFlat
        self.blockGainedCleanseCount = blockGainedCleanseCount
        self.blockGainedCleanseIntervalTicks = blockGainedCleanseIntervalTicks
        self.enemyStunnedHasteDurationTicks = enemyStunnedHasteDurationTicks
        self.firstHitApplyMarked = firstHitApplyMarked
        self.companionActLeechPercent = companionActLeechPercent
        self.companionActLeechDurationTicks = companionActLeechDurationTicks
        self.companionHealSharePercent = companionHealSharePercent
        self.onceBelowHealthPercentThreshold = onceBelowHealthPercentThreshold
        self.onceBelowHealthPercentHeal = onceBelowHealthPercentHeal
        self.blockPerActionWhileDeathsDoor = blockPerActionWhileDeathsDoor
        self.everyNthBurnTickCount = everyNthBurnTickCount
        self.everyNthBurnTickFreezeDamage = everyNthBurnTickFreezeDamage
        self.traitDisplayName = traitDisplayName
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

    // Profile merge is intentionally exhaustive over every stacked combat field.
    // swiftlint:disable:next function_body_length
    public mutating func merge(_ other: CombatModifierProfile) {
        statBonuses.merge(other.statBonuses)
        maximumHealthBonus += other.maximumHealthBonus
        maximumManaBonus += other.maximumManaBonus
        for (keyword, amount) in other.damageDealtBonus {
            damageDealtBonus[keyword, default: 0] += amount
        }
        healthRestoredBonus += other.healthRestoredBonus
        leechGainedBonus += other.leechGainedBonus
        leechHealingBonus += other.leechHealingBonus
        goldGainedBonus += other.goldGainedBonus
        blockGainedBonus += other.blockGainedBonus
        leechDurationBonus += other.leechDurationBonus
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
        manaCostReductionPercent += other.manaCostReductionPercent
        cleanseBonusHeal += other.cleanseBonusHeal
        gainGoldBonusHealSelf += other.gainGoldBonusHealSelf
        restoreHealthAlsoHealHero += other.restoreHealthAlsoHealHero
        controlResistancePercent += other.controlResistancePercent
        dodgeChanceBonus += other.dodgeChanceBonus
        physicalDodgeChanceBonus += other.physicalDodgeChanceBonus
        ambushBonusDamage += other.ambushBonusDamage
        regenerationAmount += other.regenerationAmount
        regenerationIntervalTicks = max(regenerationIntervalTicks, other.regenerationIntervalTicks)
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
        mitigationShredDurationTicks = max(mitigationShredDurationTicks, other.mitigationShredDurationTicks)
        freezeControlVulnerabilityPercent += other.freezeControlVulnerabilityPercent
        mitigationEffectivenessPenaltyPercent += other.mitigationEffectivenessPenaltyPercent
        leechHealingMultiplier *= other.leechHealingMultiplier
        hemorrhageBleedBonus += other.hemorrhageBleedBonus
        onBleedApplyPoison += other.onBleedApplyPoison
        onBurnApplyPoison += other.onBurnApplyPoison
        onBleedDealBurnDamage += other.onBleedDealBurnDamage
        everyNthBleedApplyCount = max(everyNthBleedApplyCount, other.everyNthBleedApplyCount)
        everyNthBleedApplyPoisonPotency += other.everyNthBleedApplyPoisonPotency
        freezeDamageWhileFrozenBonus += other.freezeDamageWhileFrozenBonus
        damageWhileTargetFrozenBonus += other.damageWhileTargetFrozenBonus
        damageBelowHealthPercentThreshold = max(damageBelowHealthPercentThreshold, other.damageBelowHealthPercentThreshold)
        if damageBelowHealthPercentKeyword == nil {
            damageBelowHealthPercentKeyword = other.damageBelowHealthPercentKeyword
        }
        damageBelowHealthPercentBonus += other.damageBelowHealthPercentBonus
        damageAfterDodgeBonus += other.damageAfterDodgeBonus
        refreshBleedOnReapply = refreshBleedOnReapply || other.refreshBleedOnReapply
        blockBrokenBlockFlat += other.blockBrokenBlockFlat
        blockGainedCleanseCount += other.blockGainedCleanseCount
        blockGainedCleanseIntervalTicks = max(blockGainedCleanseIntervalTicks, other.blockGainedCleanseIntervalTicks)
        enemyStunnedHasteDurationTicks = max(enemyStunnedHasteDurationTicks, other.enemyStunnedHasteDurationTicks)
        firstHitApplyMarked = firstHitApplyMarked || other.firstHitApplyMarked
        companionActLeechPercent += other.companionActLeechPercent
        companionActLeechDurationTicks = max(companionActLeechDurationTicks, other.companionActLeechDurationTicks)
        companionHealSharePercent += other.companionHealSharePercent
        onceBelowHealthPercentThreshold = max(onceBelowHealthPercentThreshold, other.onceBelowHealthPercentThreshold)
        onceBelowHealthPercentHeal += other.onceBelowHealthPercentHeal
        blockPerActionWhileDeathsDoor += other.blockPerActionWhileDeathsDoor
        everyNthBurnTickCount = max(everyNthBurnTickCount, other.everyNthBurnTickCount)
        everyNthBurnTickFreezeDamage += other.everyNthBurnTickFreezeDamage
        if traitDisplayName == nil {
            traitDisplayName = other.traitDisplayName
        }
    }

    public mutating func merge(_ modifier: AffixModifier) {
        modifier.apply(to: &self)
    }

    public func damageDealtBonus(for keyword: Keyword) -> Int {
        damageDealtBonus[keyword, default: 0]
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

    public func effectiveManaCost(for ability: Ability) -> Int {
        guard ability.manaCost > 0 else { return 0 }
        let reduction = min(1, max(0, manaCostReductionPercent))
        let reduced = Int(floor(Double(ability.manaCost) * (1 - reduction)))
        return max(0, reduced)
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
        combatant.maxHealth + combatant.primaryStats.toughness + modifiers.maximumHealthBonus
    }

    public var effectiveMaxMana: Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + combatant.primaryStats.intellect + modifiers.maximumManaBonus
    }
}

public extension PrimaryStats {
    mutating func merge(_ other: PrimaryStats) {
        strength += other.strength
        agility += other.agility
        toughness += other.toughness
        intellect += other.intellect
        wisdom += other.wisdom
    }

    func merged(with other: PrimaryStats) -> PrimaryStats {
        var copy = self
        copy.merge(other)
        return copy
    }
}
