import TrinketContent
import TrinketCore

public struct CombatantRuntime: Hashable {
    private final class StateStorage: Hashable {
        var value: CombatantTalentState
        var uniques: CombatantUniqueState
        var reactions = ElementalReactionState()
        var peakDepleted: Int
        var referenceMaxHealth: Int

        init(
            _ value: CombatantTalentState = CombatantTalentState(),
            uniques: CombatantUniqueState = CombatantUniqueState(),
            peakDepleted: Int = 0,
            referenceMaxHealth: Int = 1,
        ) {
            self.value = value
            self.uniques = uniques
            self.peakDepleted = peakDepleted
            self.referenceMaxHealth = referenceMaxHealth
        }

        static func == (lhs: StateStorage, rhs: StateStorage) -> Bool {
            lhs === rhs || (
                lhs.value == rhs.value && lhs.uniques == rhs.uniques
                    && lhs.reactions == rhs.reactions && lhs.peakDepleted == rhs.peakDepleted
                    && lhs.referenceMaxHealth == rhs.referenceMaxHealth
            )
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(reactions)
            hasher.combine(value)
            hasher.combine(uniques)
            hasher.combine(peakDepleted)
            hasher.combine(referenceMaxHealth)
        }
    }

    private var runtimeStateStorage = StateStorage()

    var reactions: ElementalReactionState {
        _read { yield runtimeStateStorage.reactions }
        _modify {
            ensureUniqueStateStorage()
            yield &runtimeStateStorage.reactions
        }
    }

    var talents: CombatantTalentState {
        _read { yield runtimeStateStorage.value }
        _modify {
            ensureUniqueStateStorage()
            yield &runtimeStateStorage.value
        }
    }

    var uniques: CombatantUniqueState {
        _read { yield runtimeStateStorage.uniques }
        _modify {
            ensureUniqueStateStorage()
            yield &runtimeStateStorage.uniques
        }
    }

    private mutating func ensureUniqueStateStorage() {
        guard !isKnownUniquelyReferenced(&runtimeStateStorage) else { return }
        let reactions = runtimeStateStorage.reactions
        runtimeStateStorage = StateStorage(
            runtimeStateStorage.value,
            uniques: runtimeStateStorage.uniques,
            peakDepleted: runtimeStateStorage.peakDepleted,
            referenceMaxHealth: runtimeStateStorage.referenceMaxHealth,
        )
        runtimeStateStorage.reactions = reactions
    }

    public let combatant: Combatant

    public package(set) var currentHealth: Int {
        didSet {
            recordEnemyHealthProgress()
        }
    }

    package var defeatProgress: BattleDefeatProgress {
        BattleDefeatProgress(
            remainingHealth: runtimeStateStorage.referenceMaxHealth - runtimeStateStorage.peakDepleted,
            maximumHealth: runtimeStateStorage.referenceMaxHealth,
        )
    }

    private mutating func recordEnemyHealthProgress() {
        guard combatant.role == .enemy else { return }
        let reference = max(1, runtimeStateStorage.referenceMaxHealth)
        let depleted = max(0, reference - currentHealth)
        guard depleted > runtimeStateStorage.peakDepleted else { return }
        ensureUniqueStateStorage()
        runtimeStateStorage.peakDepleted = depleted
    }

    public package(set) var currentMana: Int

    public package(set) var activeEffects: [ActiveEffect] {
        didSet {
            currentMana = min(currentMana, maxMana)
            if combatant.role == .enemy, runtimeStateStorage.reactions.hasStatusPreparation {
                let effects = activeEffects
                reactions.expire(with: effects)
            }
        }
    }

    public package(set) var actionCount: Int

    public let maximumHealthBonus: Int

    public let maximumManaBonus: Int

    public package(set) var hasConsumedDeathsDoor: Bool

    public package(set) var deathsDoorExpiredAtTurn: Int?

    public package(set) var hasTriggeredFirstHitBonus: Bool

    public package(set) var hasTriggeredSecondWind: Bool

    public package(set) var hasTriggeredDeathRevive: Bool

    public package(set) var hasTriggeredPhoenixGift: Bool

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
        let healthCapacity = CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus)
        let startingMana = CombatantMaxValues.maxMana(for: combatant, flatBonus: maximumManaBonus)
        let manaCapacity = CombatantMaxValues.maxMana(
            for: combatant, flatBonus: maximumManaBonus,
            effectBonus: CombatantMaxValues.maximumManaBonus(in: initialActiveEffects),
        )
        currentHealth = min(healthCapacity, max(0, initialHealth ?? healthCapacity))
        currentMana = min(manaCapacity, max(0, initialMana ?? startingMana))
        activeEffects = initialActiveEffects
        actionCount = 0
        runtimeStateStorage.referenceMaxHealth = max(1, healthCapacity)
        recordEnemyHealthProgress()
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
        CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus, talentBonus: talents.battle.maximumHealthBonus)
    }

    var isBelowHalfHealth: Bool {
        HealthThreshold.isBelowHalf(currentHealth, maximum: maxHealth)
    }

    var isAboveHalfHealth: Bool {
        HealthThreshold.isAboveHalf(currentHealth, maximum: maxHealth)
    }

    public var maxMana: Int {
        CombatantMaxValues.maxMana(
            for: combatant, flatBonus: maximumManaBonus,
            effectBonus: CombatantMaxValues.maximumManaBonus(in: activeEffects),
        )
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

    package mutating func takeRawDamage(_ amount: Int) -> Int {
        let actual = min(max(0, amount), currentHealth)
        currentHealth -= actual
        return actual
    }

    package mutating func spendMana(_ amount: Int) -> Int {
        let actual = min(max(0, amount), currentMana)
        currentMana -= actual
        return actual
    }

    package mutating func restoreMana(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let space = max(0, maxMana - currentMana)
        let actual = min(amount, space)
        currentMana += actual
        return actual
    }

    package mutating func heal(_ amount: Int) -> Int {
        let actual = CombatGain.amount(amount, current: currentHealth, cap: maxHealth)
        currentHealth += actual
        return actual
    }

    package mutating func markActed() {
        actionCount += 1
    }

    package mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }
}
