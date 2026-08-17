import Foundation
import TrinketContent
import TrinketCore

/// Mutable per-combatant state for the duration of a single battle.
///
/// The `Combatant` itself is treated as an immutable definition; the runtime
/// tracks how that definition's state has evolved during the battle.
public struct CombatantRuntime: Hashable { // swiftlint:disable:this type_body_length
    private struct TalentState: Equatable, Hashable, Sendable {
        var talentMaxHealthBonus: Int = 0
        var pendingDamageAfterDodge: Int = 0
        var mitigationShredUntilTurn: Int = 0
        var mitigationShredMultiplier: Double = 1.0
        var pendingDamageDoubleAfterDodge: Bool = false
        var pendingGuaranteedCriticalAfterDodge: Bool = false
        var pendingBleedAfterDodge: Int = 0
        var pendingCardDamageBonus: Int = 0
        var pendingCardDamagePercent: Double = 0.0
        var talentDamagePercentBonus: Double = 0.0
        var talentDamagePercentUntilTurn: Int = 0
        var pendingNextHitBonus: Int = 0
        var pendingNextAttackHolyBonus: Int = 0
        var pendingBasicGuaranteedCrit: Bool = false
        var pendingAttackBonusOnFullHealth: Int = 0
        var permanentDamageBonus: Int = 0
        var talentLeechOverhealDamageBonus: Int = 0
        var totalBlockGainedThisCombat: Int = 0
        var pendingDoubleStatusNextCard: Bool = false
        var talentStatBonus: PrimaryStats = .init()
        var bonusDodgeUntilNextTurn: Double = 0.0
        var bonusDodgeExpiresAtTurn: Int = 0
        var healOverTimeAmount: Int = 0
        var healOverTimeTurnsRemaining: Int = 0
        var hasTakenAttackHitThisTurn: Bool = false
        var hasTriggeredSurpriseStrike: Bool = false
        var hasTriggeredSeismicRoar: Bool = false
        var hasTriggeredEndlessLegion: Bool = false
        var hasNegatedFirstEnemyAttack: Bool = false
        var hasNegatedEnemyAttackThisRound: Bool = false
        var manaSpentThisCardPlay: Int = 0
        var faeWardBlockedThisTurn: Bool = false
        var talentCritMultiplierBonus: Double = 0.0
    }

    private final class TalentBox: @unchecked Sendable {
        var state: TalentState
        init(_ state: TalentState) {
            self.state = state
        }
    }

    private var talentBox: TalentBox

    private mutating func mutateTalentState(_ body: (inout TalentState) -> Void) {
        if isKnownUniquelyReferenced(&talentBox) {
            body(&talentBox.state)
        } else {
            var newState = talentBox.state
            body(&newState)
            talentBox = TalentBox(newState)
        }
    }

    public var talentMaxHealthBonus: Int {
        get { talentBox.state.talentMaxHealthBonus }
        set { mutateTalentState { $0.talentMaxHealthBonus = newValue } }
    }

    public var pendingDamageAfterDodge: Int {
        get { talentBox.state.pendingDamageAfterDodge }
        set { mutateTalentState { $0.pendingDamageAfterDodge = newValue } }
    }

    public var mitigationShredUntilTurn: Int {
        get { talentBox.state.mitigationShredUntilTurn }
        set { mutateTalentState { $0.mitigationShredUntilTurn = newValue } }
    }

    public var mitigationShredMultiplier: Double {
        get { talentBox.state.mitigationShredMultiplier }
        set { mutateTalentState { $0.mitigationShredMultiplier = newValue } }
    }

    public var pendingDamageDoubleAfterDodge: Bool {
        get { talentBox.state.pendingDamageDoubleAfterDodge }
        set { mutateTalentState { $0.pendingDamageDoubleAfterDodge = newValue } }
    }

    public var pendingGuaranteedCriticalAfterDodge: Bool {
        get { talentBox.state.pendingGuaranteedCriticalAfterDodge }
        set { mutateTalentState { $0.pendingGuaranteedCriticalAfterDodge = newValue } }
    }

    public var pendingBleedAfterDodge: Int {
        get { talentBox.state.pendingBleedAfterDodge }
        set { mutateTalentState { $0.pendingBleedAfterDodge = newValue } }
    }

    public var pendingCardDamageBonus: Int {
        get { talentBox.state.pendingCardDamageBonus }
        set { mutateTalentState { $0.pendingCardDamageBonus = newValue } }
    }

    public var pendingCardDamagePercent: Double {
        get { talentBox.state.pendingCardDamagePercent }
        set { mutateTalentState { $0.pendingCardDamagePercent = newValue } }
    }

    public var talentDamagePercentBonus: Double {
        get { talentBox.state.talentDamagePercentBonus }
        set { mutateTalentState { $0.talentDamagePercentBonus = newValue } }
    }

    public var talentDamagePercentUntilTurn: Int {
        get { talentBox.state.talentDamagePercentUntilTurn }
        set { mutateTalentState { $0.talentDamagePercentUntilTurn = newValue } }
    }

    public var pendingNextHitBonus: Int {
        get { talentBox.state.pendingNextHitBonus }
        set { mutateTalentState { $0.pendingNextHitBonus = newValue } }
    }

    public var pendingNextAttackHolyBonus: Int {
        get { talentBox.state.pendingNextAttackHolyBonus }
        set { mutateTalentState { $0.pendingNextAttackHolyBonus = newValue } }
    }

    public var pendingBasicGuaranteedCrit: Bool {
        get { talentBox.state.pendingBasicGuaranteedCrit }
        set { mutateTalentState { $0.pendingBasicGuaranteedCrit = newValue } }
    }

    public var pendingAttackBonusOnFullHealth: Int {
        get { talentBox.state.pendingAttackBonusOnFullHealth }
        set { mutateTalentState { $0.pendingAttackBonusOnFullHealth = newValue } }
    }

    public var permanentDamageBonus: Int {
        get { talentBox.state.permanentDamageBonus }
        set { mutateTalentState { $0.permanentDamageBonus = newValue } }
    }

    public var talentLeechOverhealDamageBonus: Int {
        get { talentBox.state.talentLeechOverhealDamageBonus }
        set { mutateTalentState { $0.talentLeechOverhealDamageBonus = newValue } }
    }

    public var totalBlockGainedThisCombat: Int {
        get { talentBox.state.totalBlockGainedThisCombat }
        set { mutateTalentState { $0.totalBlockGainedThisCombat = newValue } }
    }

    public var pendingDoubleStatusNextCard: Bool {
        get { talentBox.state.pendingDoubleStatusNextCard }
        set { mutateTalentState { $0.pendingDoubleStatusNextCard = newValue } }
    }

    public var talentStatBonus: PrimaryStats {
        get { talentBox.state.talentStatBonus }
        set { mutateTalentState { $0.talentStatBonus = newValue } }
    }

    public var bonusDodgeUntilNextTurn: Double {
        get { talentBox.state.bonusDodgeUntilNextTurn }
        set { mutateTalentState { $0.bonusDodgeUntilNextTurn = newValue } }
    }

    public var bonusDodgeExpiresAtTurn: Int {
        get { talentBox.state.bonusDodgeExpiresAtTurn }
        set { mutateTalentState { $0.bonusDodgeExpiresAtTurn = newValue } }
    }

    public var healOverTimeAmount: Int {
        get { talentBox.state.healOverTimeAmount }
        set { mutateTalentState { $0.healOverTimeAmount = newValue } }
    }

    public var healOverTimeTurnsRemaining: Int {
        get { talentBox.state.healOverTimeTurnsRemaining }
        set { mutateTalentState { $0.healOverTimeTurnsRemaining = newValue } }
    }

    public var hasTakenAttackHitThisTurn: Bool {
        get { talentBox.state.hasTakenAttackHitThisTurn }
        set { mutateTalentState { $0.hasTakenAttackHitThisTurn = newValue } }
    }

    public var hasTriggeredSurpriseStrike: Bool {
        get { talentBox.state.hasTriggeredSurpriseStrike }
        set { mutateTalentState { $0.hasTriggeredSurpriseStrike = newValue } }
    }

    public var hasTriggeredSeismicRoar: Bool {
        get { talentBox.state.hasTriggeredSeismicRoar }
        set { mutateTalentState { $0.hasTriggeredSeismicRoar = newValue } }
    }

    public var hasTriggeredEndlessLegion: Bool {
        get { talentBox.state.hasTriggeredEndlessLegion }
        set { mutateTalentState { $0.hasTriggeredEndlessLegion = newValue } }
    }

    public var hasNegatedFirstEnemyAttack: Bool {
        get { talentBox.state.hasNegatedFirstEnemyAttack }
        set { mutateTalentState { $0.hasNegatedFirstEnemyAttack = newValue } }
    }

    public var hasNegatedEnemyAttackThisRound: Bool {
        get { talentBox.state.hasNegatedEnemyAttackThisRound }
        set { mutateTalentState { $0.hasNegatedEnemyAttackThisRound = newValue } }
    }

    public var manaSpentThisCardPlay: Int {
        get { talentBox.state.manaSpentThisCardPlay }
        set { mutateTalentState { $0.manaSpentThisCardPlay = newValue } }
    }

    public var faeWardBlockedThisTurn: Bool {
        get { talentBox.state.faeWardBlockedThisTurn }
        set { mutateTalentState { $0.faeWardBlockedThisTurn = newValue } }
    }

    public var talentCritMultiplierBonus: Double {
        get { talentBox.state.talentCritMultiplierBonus }
        set { mutateTalentState { $0.talentCritMultiplierBonus = newValue } }
    }

    /// The immutable combatant definition (name, role, ability loadout, etc.).
    public let combatant: Combatant

    /// Current health. `0` means defeated.
    public var currentHealth: Int

    /// Current mana. Starts at `combatant.maxMana` and is `0` for combatants without mana.
    public var currentMana: Int

    /// Currently active status effects, in insertion order.
    public var activeEffects: [ActiveEffect]

    /// Number of times this combatant has acted so far in the battle.
    public var actionCount: Int

    /// Flat maximum-health bonus from equipped item affixes.
    public let maximumHealthBonus: Int

    /// Flat maximum-mana bonus from equipped item affixes.
    public let maximumManaBonus: Int

    /// True after this combatant has triggered Death's Door once this battle.
    public var hasConsumedDeathsDoor: Bool

    /// Round when Death's Door expired; lethal protection lasts through that round.
    public var deathsDoorExpiredAtTurn: Int?

    /// True after this combatant's ambush trait has added its first-strike bonus.
    public var hasTriggeredAmbush: Bool

    /// True after this combatant's first-hit double-damage trait has fired once.
    public var hasTriggeredFirstHitBonus: Bool

    /// True after this combatant's Second Wind affix has healed once this battle.
    public var hasTriggeredSecondWind: Bool

    /// True after this combatant's trait death-revive has fired once this battle.
    public var hasTriggeredDeathRevive: Bool

    /// True after this companion's Phoenix Gift has revived the hero once this battle.
    public var hasTriggeredPhoenixGift: Bool

    public init(
        combatant: Combatant,
        initialHealth: Int? = nil,
        initialMana: Int? = nil,
        initialActiveEffects: [ActiveEffect] = [],
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        hasConsumedDeathsDoor: Bool = false,
        deathsDoorExpiredAtTurn: Int? = nil,
        hasTriggeredAmbush: Bool = false,
        hasTriggeredFirstHitBonus: Bool = false,
        hasTriggeredSecondWind: Bool = false,
        hasTriggeredDeathRevive: Bool = false,
        hasTriggeredPhoenixGift: Bool = false,
        pendingDamageAfterDodge: Int = 0,
        mitigationShredUntilTurn: Int = 0,
        mitigationShredMultiplier: Double = 1,
        talentMaxHealthBonus: Int = 0,
        pendingDamageDoubleAfterDodge: Bool = false,
        pendingGuaranteedCriticalAfterDodge: Bool = false,
        pendingBleedAfterDodge: Int = 0,
        pendingCardDamageBonus: Int = 0,
        pendingCardDamagePercent: Double = 0,
        talentDamagePercentBonus: Double = 0,
        talentDamagePercentUntilTurn: Int = 0,
        talentCritMultiplierBonus: Double = 0,
        bonusDodgeUntilNextTurn: Double = 0,
        hasTakenAttackHitThisTurn: Bool = false,
        hasTriggeredSurpriseStrike: Bool = false,
        hasTriggeredSeismicRoar: Bool = false,
        manaSpentThisCardPlay: Int = 0,
        faeWardBlockedThisTurn: Bool = false,
        hasNegatedFirstEnemyAttack: Bool = false,
        hasNegatedEnemyAttackThisRound: Bool = false,
        pendingNextHitBonus: Int = 0,
        pendingNextAttackHolyBonus: Int = 0,
        pendingBasicGuaranteedCrit: Bool = false,
        pendingAttackBonusOnFullHealth: Int = 0,
        permanentDamageBonus: Int = 0,
        pendingDoubleStatusNextCard: Bool = false,
        talentStatBonus: PrimaryStats = PrimaryStats()
    ) {
        self.combatant = combatant
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.hasConsumedDeathsDoor = hasConsumedDeathsDoor
        self.deathsDoorExpiredAtTurn = deathsDoorExpiredAtTurn
        self.hasTriggeredAmbush = hasTriggeredAmbush
        self.hasTriggeredFirstHitBonus = hasTriggeredFirstHitBonus
        self.hasTriggeredSecondWind = hasTriggeredSecondWind
        self.hasTriggeredDeathRevive = hasTriggeredDeathRevive
        self.hasTriggeredPhoenixGift = hasTriggeredPhoenixGift
        talentBox = TalentBox(TalentState(
            talentMaxHealthBonus: talentMaxHealthBonus,
            pendingDamageAfterDodge: pendingDamageAfterDodge,
            mitigationShredUntilTurn: mitigationShredUntilTurn,
            mitigationShredMultiplier: mitigationShredMultiplier,
            pendingDamageDoubleAfterDodge: pendingDamageDoubleAfterDodge,
            pendingGuaranteedCriticalAfterDodge: pendingGuaranteedCriticalAfterDodge,
            pendingBleedAfterDodge: pendingBleedAfterDodge,
            pendingCardDamageBonus: pendingCardDamageBonus,
            pendingCardDamagePercent: pendingCardDamagePercent,
            talentDamagePercentBonus: talentDamagePercentBonus,
            talentDamagePercentUntilTurn: talentDamagePercentUntilTurn,
            pendingNextHitBonus: pendingNextHitBonus,
            pendingNextAttackHolyBonus: pendingNextAttackHolyBonus,
            pendingBasicGuaranteedCrit: pendingBasicGuaranteedCrit,
            pendingAttackBonusOnFullHealth: pendingAttackBonusOnFullHealth,
            permanentDamageBonus: permanentDamageBonus,
            pendingDoubleStatusNextCard: pendingDoubleStatusNextCard,
            talentStatBonus: talentStatBonus,
            bonusDodgeUntilNextTurn: bonusDodgeUntilNextTurn,
            hasTakenAttackHitThisTurn: hasTakenAttackHitThisTurn,
            hasTriggeredSurpriseStrike: hasTriggeredSurpriseStrike,
            hasTriggeredSeismicRoar: hasTriggeredSeismicRoar,
            hasTriggeredEndlessLegion: false,
            hasNegatedFirstEnemyAttack: hasNegatedFirstEnemyAttack,
            hasNegatedEnemyAttackThisRound: hasNegatedEnemyAttackThisRound,
            manaSpentThisCardPlay: manaSpentThisCardPlay,
            faeWardBlockedThisTurn: faeWardBlockedThisTurn,
            talentCritMultiplierBonus: talentCritMultiplierBonus
        ))
        currentHealth = initialHealth ?? (combatant.maxHealth + maximumHealthBonus + talentMaxHealthBonus)
        currentMana = initialMana ?? (combatant.hasMana ? combatant.maxMana + (combatant.primaryStats.intellect / 5) + maximumManaBonus : 0)
        activeEffects = initialActiveEffects
        actionCount = 0
    }

    // MARK: - Identity passthrough

    public var id: String {
        combatant.id
    }

    public var name: String {
        combatant.name
    }

    public var role: Combatant.Role {
        combatant.role
    }

    public var maxHealth: Int {
        combatant.maxHealth + maximumHealthBonus + talentMaxHealthBonus
    }

    public var maxMana: Int {
        guard combatant.hasMana else { return 0 }
        let effectBonus = activeEffects.reduce(0) { sum, active in
            if case let .maximumManaBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        return combatant.maxMana + (combatant.primaryStats.intellect / 5) + maximumManaBonus + effectBonus
    }

    public var primaryStats: PrimaryStats {
        var merged = combatant.primaryStats
        merged.merge(talentStatBonus)
        // Weaken Soul: active Strength-reduction debuffs subtract from Strength.
        for active in activeEffects {
            if case let .strengthReduction(amount, _) = active.effect {
                merged.strength -= amount
            }
        }
        return merged
    }

    /// Primary stats including combat-long talent bonuses (Dense Bones, Alpha Might, Weaken Soul).
    public var effectivePrimaryStats: PrimaryStats {
        primaryStats
    }

    public var abilityLoadout: AbilityLoadout {
        combatant.abilityLoadout
    }

    public var abilities: [Ability] {
        combatant.abilities
    }

    /// Indicates whether the combatant is alive.
    public var isAlive: Bool {
        currentHealth > 0
    }

    // MARK: - State mutations

    /// Subtracts `amount` from `currentHealth`, clamped at 0. Returns the
    /// actual health lost. The caller is responsible for shield absorption
    /// and mitigation before calling this.
    public mutating func takeRawDamage(_ amount: Int) -> Int {
        let actual = min(amount, currentHealth)
        currentHealth = max(0, currentHealth - amount)
        return actual
    }

    /// Subtracts `amount` from `currentMana`, clamped at 0. Returns the
    /// actual mana spent.
    public mutating func spendMana(_ amount: Int) -> Int {
        let actual = min(amount, currentMana)
        currentMana = max(0, currentMana - amount)
        return actual
    }

    /// Restores `amount` mana, capped at `maxMana`. Returns the actual
    /// amount restored.
    public mutating func restoreMana(_ amount: Int) -> Int {
        let space = max(0, maxMana - currentMana)
        let actual = min(amount, space)
        currentMana += actual
        return actual
    }

    /// Restores `amount` health, capped at `maxHealth` and boosted by
    /// Wisdom's diminishing returns curve percentage. Returns the actual amount restored.
    public mutating func heal(_ amount: Int) -> Int {
        let wisdomPercent = primaryStats.diminishingReturnsPercent(for: primaryStats.wisdom)
        let wisdomBonus = CombatRounding.scaled(amount, multiplier: wisdomPercent)
        let total = amount + wisdomBonus
        let space = max(0, maxHealth - currentHealth)
        let actual = min(total, space)
        currentHealth = min(maxHealth, currentHealth + total)
        return actual
    }

    /// Records that this combatant just acted.
    public mutating func markActed() {
        actionCount += 1
    }

    public mutating func setEffects(_ effects: [ActiveEffect]) {
        activeEffects = effects
    }

    public mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.combatant == rhs.combatant
            && lhs.currentHealth == rhs.currentHealth
            && lhs.currentMana == rhs.currentMana
            && lhs.activeEffects == rhs.activeEffects
            && lhs.actionCount == rhs.actionCount
            && lhs.maximumHealthBonus == rhs.maximumHealthBonus
            && lhs.maximumManaBonus == rhs.maximumManaBonus
            && lhs.hasConsumedDeathsDoor == rhs.hasConsumedDeathsDoor
            && lhs.deathsDoorExpiredAtTurn == rhs.deathsDoorExpiredAtTurn
            && lhs.hasTriggeredAmbush == rhs.hasTriggeredAmbush
            && lhs.hasTriggeredFirstHitBonus == rhs.hasTriggeredFirstHitBonus
            && lhs.hasTriggeredSecondWind == rhs.hasTriggeredSecondWind
            && lhs.hasTriggeredDeathRevive == rhs.hasTriggeredDeathRevive
            && lhs.hasTriggeredPhoenixGift == rhs.hasTriggeredPhoenixGift
            && lhs.talentBox.state == rhs.talentBox.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(combatant)
        hasher.combine(currentHealth)
        hasher.combine(currentMana)
        hasher.combine(activeEffects)
        hasher.combine(actionCount)
        hasher.combine(maximumHealthBonus)
        hasher.combine(maximumManaBonus)
        hasher.combine(hasConsumedDeathsDoor)
        hasher.combine(deathsDoorExpiredAtTurn)
        hasher.combine(hasTriggeredAmbush)
        hasher.combine(hasTriggeredFirstHitBonus)
        hasher.combine(hasTriggeredSecondWind)
        hasher.combine(hasTriggeredDeathRevive)
        hasher.combine(hasTriggeredPhoenixGift)
        hasher.combine(talentBox.state)
    }
}
