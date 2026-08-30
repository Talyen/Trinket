import Foundation
import TrinketContent
import TrinketCore

@dynamicMemberLookup
public struct CombatantRuntime: Hashable {
    public struct TalentState: Equatable, Hashable, Sendable {
        public var talentMaxHealthBonus: Int = 0
        public var permanentDamageBonus: Int = 0
        public var keywordDamageRamp: [Keyword: Int] = [:]
        public var talentLeechOverhealDamageBonus: Int = 0
        public var totalBlockGainedThisCombat: Int = 0
        public var talentStatBonus: PrimaryStats = .init()
        public var talentCritMultiplierBonus: Double = 0.0
        public var hasNegatedFirstEnemyAttack: Bool = false

        public var bonusDodgeUntilNextTurn: Double = 0.0
        public var bonusDodgeExpiresAtTurn: Int = 0
        public var healOverTimeAmount: Int = 0
        public var healOverTimeTurnsRemaining: Int = 0
        public var hasTakenAttackHitThisTurn: Bool = false
        public var faeWardBlockedThisTurn: Bool = false
        public var hasTriggeredBlockBreakThisTurn: Bool = false
        public var talentDamagePercentBonus: Double = 0.0
        public var talentDamagePercentUntilTurn: Int = 0

        public var pendingDamageAfterDodge: Int = 0
        public var pendingDamageDoubleAfterDodge: Bool = false
        public var pendingGuaranteedCriticalAfterDodge: Bool = false
        public var pendingBleedAfterDodge: Int = 0
        public var pendingCardDamageBonus: Int = 0
        public var pendingCardDamagePercent: Double = 0.0
        public var pendingNextHitBonus: Int = 0
        public var pendingNextAttackHolyBonus: Int = 0
        public var pendingBasicGuaranteedCrit: Bool = false
        public var pendingAttackBonusOnFullHealth: Int = 0
        public var pendingDoubleStatusNextCard: Bool = false
        public var goldenTouchActiveThisCard: Bool = false
        public var manaSpentThisCardPlay: Int = 0

        public init() {}

        mutating func resetForNewTurn(currentTurn: Int) {
            if bonusDodgeExpiresAtTurn == 0 || currentTurn >= bonusDodgeExpiresAtTurn {
                bonusDodgeUntilNextTurn = 0
                bonusDodgeExpiresAtTurn = 0
            }
            hasTakenAttackHitThisTurn = false
            faeWardBlockedThisTurn = false
            hasTriggeredBlockBreakThisTurn = false
            if talentDamagePercentUntilTurn != 0, currentTurn >= talentDamagePercentUntilTurn {
                talentDamagePercentBonus = 0
                talentDamagePercentUntilTurn = 0
            }
        }
    }

    private var talentBox: CopyOnWriteBox<TalentState>

    private mutating func mutateTalentState(_ body: (inout TalentState) -> Void) {
        if isKnownUniquelyReferenced(&talentBox) {
            body(&talentBox.value)
        } else {
            var newState = talentBox.value
            body(&newState)
            talentBox = CopyOnWriteBox(newState)
        }
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<TalentState, T>) -> T {
        get { talentBox.value[keyPath: keyPath] }
        set { mutateTalentState { $0[keyPath: keyPath] = newValue } }
    }

    public let combatant: Combatant

    public var currentHealth: Int

    public var currentMana: Int

    public var activeEffects: [ActiveEffect]

    public var actionCount: Int

    public let maximumHealthBonus: Int

    public let maximumManaBonus: Int

    public var hasConsumedDeathsDoor: Bool

    public var deathsDoorExpiredAtTurn: Int?

    public var hasTriggeredFirstHitBonus: Bool

    public var hasTriggeredSecondWind: Bool

    public var hasTriggeredDeathRevive: Bool

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
        hasTriggeredPhoenixGift: Bool = false,
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
        talentBox = CopyOnWriteBox(TalentState())
        currentHealth = initialHealth ?? CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus)
        currentMana = initialMana ?? CombatantMaxValues.maxMana(for: combatant, flatBonus: maximumManaBonus)
        activeEffects = initialActiveEffects
        actionCount = 0
    }

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
        CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus, talentBonus: self.talentMaxHealthBonus)
    }

    public var maxMana: Int {
        let effectBonus = activeEffects.reduce(0) { sum, active in
            if case let .maximumManaBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        return CombatantMaxValues.maxMana(for: combatant, flatBonus: maximumManaBonus, effectBonus: effectBonus)
    }

    public var primaryStats: PrimaryStats {
        var merged = combatant.primaryStats
        merged.merge(self.talentStatBonus)
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

    public var isAlive: Bool {
        currentHealth > 0
    }

    public mutating func takeRawDamage(_ amount: Int) -> Int {
        let actual = min(amount, currentHealth)
        currentHealth = max(0, currentHealth - amount)
        return actual
    }

    public mutating func spendMana(_ amount: Int) -> Int {
        let actual = min(amount, currentMana)
        currentMana = max(0, currentMana - amount)
        return actual
    }

    public mutating func restoreMana(_ amount: Int) -> Int {
        let space = max(0, maxMana - currentMana)
        let actual = min(amount, space)
        currentMana += actual
        return actual
    }

    public mutating func heal(_ amount: Int) -> Int {
        let wisdomPercent = PrimaryStats.diminishingReturnsPercent(for: primaryStats.wisdom)
        let wisdomBonus = CombatRounding.scaled(amount, multiplier: wisdomPercent)
        let total = amount + wisdomBonus
        let cachedMaxHealth = maxHealth
        let space = max(0, cachedMaxHealth - currentHealth)
        let actual = min(total, space)
        currentHealth += actual
        return actual
    }

    public mutating func markActed() {
        actionCount += 1
    }

    public mutating func setEffects(_ effects: [ActiveEffect]) {
        activeEffects = effects
    }

    public mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }

    package mutating func resetTalentTurnState(currentTurn: Int) {
        mutateTalentState { $0.resetForNewTurn(currentTurn: currentTurn) }
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
            && lhs.talentBox.value == rhs.talentBox.value
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
        hasher.combine(talentBox.value)
    }
}
