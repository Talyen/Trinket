import Foundation
import TrinketContent
import TrinketCore

struct HealingEcho: Hashable, Sendable {
    let amount: Int
    let sourceActorID: String
}

struct LingeringBlessing: Hashable, Sendable {
    let amount: Int
    let sourceActorID: String
    var turnsRemaining: Int
}

@dynamicMemberLookup
public struct CombatantRuntime: Hashable {
    public struct TalentState: Equatable, Hashable, Sendable {
        var healingEchoes: [HealingEcho] = []
        var cleansedKeywordProtection: Set<Keyword> = []
        var purgedEffectProtection: Set<EffectKind> = []
        var subzeroMistActive = false
        public var talentMaxHealthBonus: Int = 0
        public var permanentDamageBonus: Int = 0
        public var keywordDamageRamp: [Keyword: Int] = [:]
        public var talentLeechOverhealDamageBonus: Int = 0
        public var totalBlockGainedThisCombat: Int = 0
        public var talentCritMultiplierBonus: Double = 0.0
        public var hasNegatedFirstEnemyAttack: Bool = false
        public var bonusDodgeUntilNextTurn: Double = 0.0
        public var bonusDodgeExpiresAtTurn: Int = 0
        var lingeringBlessing: LingeringBlessing?
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
        public var pendingBasicCritBonus: Double = 0.0
        public var pendingAttackBonusOnFullHealth: Int = 0
        public var pendingDoubleStatusNextCard: Bool = false
        public var goldenTouchActiveThisCard: Bool = false
        public var hasEmpoweredWithMana: Bool = false
        public var empoweredThisAction: Bool = false
        var manaSpentTowardAutoPlay: Int = 0
        public var flatDamageReductionBonus: Int = 0
        public var flatDamageReductionCap: Int = 4

        public init() {}

        mutating func resetForNewTurn(currentTurn: Int) {
            subzeroMistActive = false
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

    private final class TalentStorage: Hashable {
        var value: TalentState

        init(_ value: TalentState = TalentState()) {
            self.value = value
        }

        static func == (lhs: TalentStorage, rhs: TalentStorage) -> Bool {
            lhs === rhs || lhs.value == rhs.value
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
        }
    }

    private var talentStateStorage = TalentStorage()

    private mutating func mutateTalentState(_ body: (inout TalentState) -> Void) {
        if !isKnownUniquelyReferenced(&talentStateStorage) {
            talentStateStorage = TalentStorage(talentStateStorage.value)
        }
        body(&talentStateStorage.value)
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<TalentState, T>) -> T {
        _read { yield talentStateStorage.value[keyPath: keyPath] }
        set { mutateTalentState { $0[keyPath: keyPath] = newValue } }
    }

    var talentState: TalentState {
        _read { yield talentStateStorage.value }
        set { talentStateStorage = TalentStorage(newValue) }
    }

    public let combatant: Combatant

    public var currentHealth: Int

    public var currentMana: Int

    public var activeEffects: [ActiveEffect] {
        didSet {
            currentMana = min(currentMana, maxMana)
        }
    }

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
        talentStateStorage = TalentStorage()
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
        let actual = CombatGain.amount(amount, current: currentHealth, cap: maxHealth)
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
}
