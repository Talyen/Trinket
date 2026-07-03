import Foundation

/// Mutable per-combatant state for the duration of a single battle. Replaces
/// the triplicated `heroHealth`/`petHealth`/`enemyHealth`, three effect arrays,
/// three action speeds, three next-ready ticks, and three action counters
/// that previously lived directly on `BattleState`.
///
/// The `Combatant` itself is treated as an immutable definition; the runtime
/// tracks how that definition's state has evolved during the battle.
struct CombatantRuntime: Hashable {
    /// The immutable combatant definition (name, role, ability loadout, etc.).
    let combatant: Combatant

    /// Current health. `0` means defeated.
    var currentHealth: Int

    /// Current mana. Starts at `combatant.maxMana` and is `0` for combatants without mana.
    var currentMana: Int

    /// Currently active status effects, in insertion order.
    var activeEffects: [ActiveEffect]

    /// Action speed configuration. The effective interval is recomputed on
    /// read; `intervalModifier` is mutated by stat changes in future stages.
    var actionSpeed: ActionSpeed

    /// The tick at which this combatant is next eligible to act.
    var nextReadyAtTick: Int

    /// Number of times this combatant has acted so far in the battle.
    var actionCount: Int

    /// Flat maximum-health bonus from equipped item affixes.
    let maximumHealthBonus: Int

    /// Flat maximum-mana bonus from equipped item affixes.
    let maximumManaBonus: Int

    init(
        combatant: Combatant,
        initialHealth: Int? = nil,
        initialMana: Int? = nil,
        initialActiveEffects: [ActiveEffect] = [],
        initialActionSpeed: ActionSpeed? = nil,
        initialNextReadyAtTick: Int? = nil,
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0
    ) {
        self.combatant = combatant
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        currentHealth = initialHealth ?? (combatant.maxHealth + combatant.primaryStats.toughness + maximumHealthBonus)
        currentMana = initialMana ?? (combatant.hasMana ? combatant.maxMana + combatant.primaryStats.intellect + maximumManaBonus : 0)
        activeEffects = initialActiveEffects

        let speed = initialActionSpeed ?? CombatantRuntime.defaultActionSpeed(for: combatant)
        actionSpeed = speed
        nextReadyAtTick = initialNextReadyAtTick ?? speed.effectiveInterval
        actionCount = 0
    }

    // MARK: - Identity passthrough

    var id: String {
        combatant.id
    }

    var name: String {
        combatant.name
    }

    var role: Combatant.Role {
        combatant.role
    }

    var maxHealth: Int {
        combatant.maxHealth + combatant.primaryStats.toughness + maximumHealthBonus
    }

    var maxMana: Int {
        guard combatant.hasMana else { return 0 }
        return combatant.maxMana + combatant.primaryStats.intellect + maximumManaBonus
    }

    var primaryStats: PrimaryStats {
        combatant.primaryStats
    }

    var abilityLoadout: AbilityLoadout {
        combatant.abilityLoadout
    }

    var abilities: [Ability] {
        combatant.abilities
    }

    var isAlive: Bool {
        currentHealth > 0
    }

    // MARK: - State queries

    /// True if this combatant can act on the given tick.
    func isReady(atTick tick: Int) -> Bool {
        isAlive && nextReadyAtTick <= tick
    }

    // MARK: - State mutations

    /// Subtracts `amount` from `currentHealth`, clamped at 0. Returns the
    /// actual health lost. The caller is responsible for shield absorption
    /// and mitigation before calling this.
    mutating func takeRawDamage(_ amount: Int) -> Int {
        let actual = min(amount, currentHealth)
        currentHealth = max(0, currentHealth - amount)
        return actual
    }

    /// Subtracts `amount` from `currentMana`, clamped at 0. Returns the
    /// actual mana spent.
    mutating func spendMana(_ amount: Int) -> Int {
        let actual = min(amount, currentMana)
        currentMana = max(0, currentMana - amount)
        return actual
    }

    /// Restores `amount` mana, capped at `maxMana`. Returns the actual
    /// amount restored.
    mutating func restoreMana(_ amount: Int) -> Int {
        let space = max(0, maxMana - currentMana)
        let actual = min(amount, space)
        currentMana += actual
        return actual
    }

    /// Restores `amount` health, capped at `maxHealth` and boosted by
    /// `wisdom / 5`. Returns the actual amount restored.
    mutating func heal(_ amount: Int) -> Int {
        let wisdomBonus = primaryStats.wisdom / 5
        let total = amount + wisdomBonus
        let space = max(0, maxHealth - currentHealth)
        let actual = min(total, space)
        currentHealth = min(maxHealth, currentHealth + total)
        return actual
    }

    /// Records that this combatant just acted on `tick` and schedules the
    /// next ready tick.
    mutating func markActed(atTick tick: Int) {
        actionCount += 1
        nextReadyAtTick = tick + actionSpeed.effectiveInterval
    }

    mutating func setEffects(_ effects: [ActiveEffect]) {
        activeEffects = effects
    }

    mutating func removeEffects(matching predicate: (ActiveEffect) -> Bool) {
        activeEffects.removeAll(where: predicate)
    }

    // MARK: - Defaults

    /// Default action speed for a combatant of the given role, using the
    /// `BattleState` baseline intervals (hero/pet: 2 ticks, enemy: 6 ticks).
    /// When the combatant provides a non-nil `actionIntervalTicks` that
    /// value is used instead. Agility is applied as a negative modifier.
    static func defaultActionSpeed(for combatant: Combatant) -> ActionSpeed {
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
