import Foundation
import TrinketContent
import TrinketCore

/// Mutable per-combatant state for the duration of a single battle. Replaces
/// the triplicated `heroHealth`/`petHealth`/`enemyHealth`, three effect arrays,
/// three action speeds, three next-ready ticks, and three action counters
/// that previously lived directly on `BattleState`.
///
/// The `Combatant` itself is treated as an immutable definition; the runtime
/// tracks how that definition's state has evolved during the battle.
public struct CombatantRuntime: Hashable {
    /// The immutable combatant definition (name, role, ability loadout, etc.).
    public let combatant: Combatant

    /// Current health. `0` means defeated.
    public var currentHealth: Int

    /// Current mana. Starts at `combatant.maxMana` and is `0` for combatants without mana.
    public var currentMana: Int

    /// Currently active status effects, in insertion order.
    public var activeEffects: [ActiveEffect]

    /// Action speed configuration. The effective interval is recomputed on
    /// read; `intervalModifier` is mutated by stat changes in future stages.
    public var actionSpeed: ActionSpeed

    /// The tick at which this combatant is next eligible to act.
    public var nextReadyAtTick: Int

    /// Number of times this combatant has acted so far in the battle.
    public var actionCount: Int

    /// Flat maximum-health bonus from equipped item affixes.
    public let maximumHealthBonus: Int

    /// Flat maximum-mana bonus from equipped item affixes.
    public let maximumManaBonus: Int

    /// True after this combatant has triggered Death's Door once this battle.
    public var hasConsumedDeathsDoor: Bool

    /// True after this combatant's ambush trait has added its first-strike bonus.
    public var hasTriggeredAmbush: Bool

    /// Tick until which mitigation from armor effects is reduced by `mitigationShredMultiplier`.
    public var mitigationShredUntilTick: Int

    /// Multiplier applied to armor mitigation while shred is active (e.g. 0.5 halves armor).
    public var mitigationShredMultiplier: Double

    public init(
        combatant: Combatant,
        initialHealth: Int? = nil,
        initialMana: Int? = nil,
        initialActiveEffects: [ActiveEffect] = [],
        initialActionSpeed: ActionSpeed? = nil,
        initialNextReadyAtTick: Int? = nil,
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        hasConsumedDeathsDoor: Bool = false,
        hasTriggeredAmbush: Bool = false,
        mitigationShredUntilTick: Int = 0,
        mitigationShredMultiplier: Double = 1
    ) {
        self.combatant = combatant
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.hasConsumedDeathsDoor = hasConsumedDeathsDoor
        self.hasTriggeredAmbush = hasTriggeredAmbush
        self.mitigationShredUntilTick = mitigationShredUntilTick
        self.mitigationShredMultiplier = mitigationShredMultiplier
        currentHealth = initialHealth ?? (combatant.maxHealth + combatant.primaryStats.toughness + maximumHealthBonus)
        currentMana = initialMana ?? (combatant.hasMana ? combatant.maxMana + combatant.primaryStats.intellect + maximumManaBonus : 0)
        activeEffects = initialActiveEffects

        let speed = initialActionSpeed ?? CombatantRuntime.defaultActionSpeed(for: combatant)
        actionSpeed = speed
        nextReadyAtTick = initialNextReadyAtTick ?? speed.effectiveInterval
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
        combatant.maxHealth + combatant.primaryStats.toughness + maximumHealthBonus
    }

    public var maxMana: Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + combatant.primaryStats.intellect + maximumManaBonus
    }

    public var primaryStats: PrimaryStats {
        combatant.primaryStats
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

    // MARK: - State queries

    /// True if this combatant can act on the given tick.
    public func isReady(atTick tick: Int) -> Bool {
        isAlive && nextReadyAtTick <= tick
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
    /// `wisdom / 5`. Returns the actual amount restored.
    public mutating func heal(_ amount: Int) -> Int {
        let wisdomBonus = primaryStats.wisdom / 5
        let total = amount + wisdomBonus
        let space = max(0, maxHealth - currentHealth)
        let actual = min(total, space)
        currentHealth = min(maxHealth, currentHealth + total)
        return actual
    }

    /// Records that this combatant just acted on `tick` and schedules the
    /// next ready tick.
    public mutating func markActed(atTick tick: Int, activeEffects: [ActiveEffect] = []) {
        actionCount += 1
        let hasteReduction = activeEffects.contains { active in
            if case .haste = active.effect { return active.remainingTicks > 0 }
            return false
        } ? 1 : 0
        let interval = max(1, actionSpeed.effectiveInterval - hasteReduction)
        nextReadyAtTick = tick + interval
    }

    public mutating func setEffects(_ effects: [ActiveEffect]) {
        activeEffects = effects
    }

    public mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }

    // MARK: - Defaults

    /// Default action speed for a combatant of the given role, using the
    /// `BattleState` baseline intervals (hero/pet: 2 ticks, enemy: 6 ticks).
    /// When the combatant provides a non-nil `actionIntervalTicks` that
    /// value is used instead. Agility is applied as a negative modifier.
    public static func defaultActionSpeed(for combatant: Combatant) -> ActionSpeed {
        let base: Int
        switch combatant.role {
        case .hero: base = BattleTiming.heroActionIntervalTicks
        case .pet: base = BattleTiming.petActionIntervalTicks
        case .enemy: base = BattleTiming.enemyActionIntervalTicks
        }
        let resolvedBase = combatant.actionIntervalTicks ?? base
        var speed = ActionSpeed(baseIntervalTicks: resolvedBase)
        speed.intervalModifier = -combatant.primaryStats.agility / 5
        return speed
    }
}
