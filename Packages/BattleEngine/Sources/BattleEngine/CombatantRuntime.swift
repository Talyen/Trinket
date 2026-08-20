import Foundation
import TrinketContent
import TrinketCore

/// Mutable per-combatant state for the duration of a single battle.
///
/// The `Combatant` itself is treated as an immutable definition; the runtime
/// tracks how that definition's state has evolved during the battle.
@dynamicMemberLookup
public struct CombatantRuntime: Hashable {
    package struct TalentState: Equatable, Hashable, Sendable {
        var talentMaxHealthBonus: Int = 0
        var pendingDamageAfterDodge: Int = 0
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
        var keywordDamageRamp: [Keyword: Int] = [:]
        var talentLeechOverhealDamageBonus: Int = 0
        var totalBlockGainedThisCombat: Int = 0
        var pendingDoubleStatusNextCard: Bool = false
        var talentStatBonus: PrimaryStats = .init()
        var bonusDodgeUntilNextTurn: Double = 0.0
        var bonusDodgeExpiresAtTurn: Int = 0
        var healOverTimeAmount: Int = 0
        var healOverTimeTurnsRemaining: Int = 0
        var hasTakenAttackHitThisTurn: Bool = false
        var hasNegatedFirstEnemyAttack: Bool = false
        var manaSpentThisCardPlay: Int = 0
        var faeWardBlockedThisTurn: Bool = false
        var talentCritMultiplierBonus: Double = 0.0
    }

    // Concurrency-Safety: `@unchecked Sendable` — COW box is mutated only through
    // `mutateTalentState` while uniquely referenced; copies clone `TalentState`.
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

    package subscript<T>(dynamicMember keyPath: WritableKeyPath<TalentState, T>) -> T {
        get { talentBox.state[keyPath: keyPath] }
        set { mutateTalentState { $0[keyPath: keyPath] = newValue } }
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

    /// Round when Death's Door expired; lethal protection lasts through that
    /// round's remaining effect pass, then clears before the next player turn.
    public var deathsDoorExpiredAtTurn: Int?

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
        hasTriggeredFirstHitBonus: Bool = false,
        hasTriggeredSecondWind: Bool = false,
        hasTriggeredDeathRevive: Bool = false,
        hasTriggeredPhoenixGift: Bool = false
    ) {
        self.combatant = combatant
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.hasConsumedDeathsDoor = hasConsumedDeathsDoor
        self.deathsDoorExpiredAtTurn = deathsDoorExpiredAtTurn
        self.hasTriggeredFirstHitBonus = hasTriggeredFirstHitBonus
        self.hasTriggeredSecondWind = hasTriggeredSecondWind
        self.hasTriggeredDeathRevive = hasTriggeredDeathRevive
        self.hasTriggeredPhoenixGift = hasTriggeredPhoenixGift
        talentBox = TalentBox(TalentState())
        currentHealth = initialHealth ?? (combatant.maxHealth + maximumHealthBonus)
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
        combatant.maxHealth + maximumHealthBonus + self.talentMaxHealthBonus
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
        merged.merge(self.talentStatBonus)
        // Weaken Soul: active Strength-reduction debuffs subtract from Strength.
        for active in activeEffects {
            if case let .strengthReduction(amount, _) = active.effect {
                merged.strength -= amount
            }
        }
        return merged
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
        hasher.combine(hasTriggeredFirstHitBonus)
        hasher.combine(hasTriggeredSecondWind)
        hasher.combine(hasTriggeredDeathRevive)
        hasher.combine(hasTriggeredPhoenixGift)
        hasher.combine(talentBox.state)
    }
}
