import Foundation
import TrinketContent
import TrinketCore

public struct CombatantRuntime: Hashable {
    private final class StateStorage: Hashable {
        var value: CombatantTalentState
        var peakDepleted: Int
        var referenceMaxHealth: Int

        init(
            _ value: CombatantTalentState = CombatantTalentState(),
            peakDepleted: Int = 0,
            referenceMaxHealth: Int = 1,
        ) {
            self.value = value
            self.peakDepleted = peakDepleted
            self.referenceMaxHealth = referenceMaxHealth
        }

        static func == (lhs: StateStorage, rhs: StateStorage) -> Bool {
            lhs === rhs || (
                lhs.value == rhs.value && lhs.peakDepleted == rhs.peakDepleted
                    && lhs.referenceMaxHealth == rhs.referenceMaxHealth
            )
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
            hasher.combine(peakDepleted)
            hasher.combine(referenceMaxHealth)
        }
    }

    private var runtimeStateStorage = StateStorage()

    var talents: CombatantTalentState {
        _read { yield runtimeStateStorage.value }
        _modify {
            if !isKnownUniquelyReferenced(&runtimeStateStorage) {
                runtimeStateStorage = StateStorage(
                    runtimeStateStorage.value,
                    peakDepleted: runtimeStateStorage.peakDepleted,
                    referenceMaxHealth: runtimeStateStorage.referenceMaxHealth,
                )
            }
            yield &runtimeStateStorage.value
        }
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
        if !isKnownUniquelyReferenced(&runtimeStateStorage) {
            runtimeStateStorage = StateStorage(runtimeStateStorage.value, peakDepleted: depleted, referenceMaxHealth: reference)
        } else {
            runtimeStateStorage.peakDepleted = depleted
        }
    }

    public package(set) var currentMana: Int

    public package(set) var activeEffects: [ActiveEffect] {
        didSet {
            currentMana = min(currentMana, maxMana)
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
        currentHealth = initialHealth ?? CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus)
        currentMana = initialMana ?? CombatantMaxValues.maxMana(for: combatant, flatBonus: maximumManaBonus)
        activeEffects = initialActiveEffects
        actionCount = 0
        runtimeStateStorage.referenceMaxHealth = max(1, CombatantMaxValues.maxHealth(for: combatant, flatBonus: maximumHealthBonus))
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

    package mutating func takeRawDamage(_ amount: Int) -> Int {
        let actual = min(amount, currentHealth)
        currentHealth = max(0, currentHealth - amount)
        return actual
    }

    package mutating func spendMana(_ amount: Int) -> Int {
        let actual = min(amount, currentMana)
        currentMana = max(0, currentMana - amount)
        return actual
    }

    package mutating func restoreMana(_ amount: Int) -> Int {
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

    package mutating func setEffects(_ effects: [ActiveEffect]) {
        activeEffects = effects
    }

    package mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }
}
