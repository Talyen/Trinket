import Foundation
import TrinketContent
import TrinketCore

/// Mutable per-combatant state for the duration of a single battle.
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

    /// Number of times this combatant has acted so far in the battle.
    public var actionCount: Int

    /// Flat maximum-health bonus from equipped item affixes.
    public let maximumHealthBonus: Int

    /// Flat maximum-mana bonus from equipped item affixes.
    public let maximumManaBonus: Int

    /// True after this combatant has triggered Death's Door once this battle.
    public var hasConsumedDeathsDoor: Bool

    /// Round when Death's Door expired; lethal protection lasts through that round.
    public var deathsDoorExpiredAtTick: Int?

    /// True after this combatant's ambush trait has added its first-strike bonus.
    public var hasTriggeredAmbush: Bool

    /// True after this combatant's Second Wind affix has healed once this battle.
    public var hasTriggeredSecondWind: Bool

    /// True after this combatant's Hexmark affix has marked its first target this battle.
    public var hasTriggeredHexmark: Bool

    /// Pending flat damage bonus earned by dodging and consumed by the next damage dealt.
    public var pendingDamageAfterDodge: Int

    /// Number of bleed applications this combatant has sourced this battle.
    public var bleedApplyCount: Int

    /// Number of burn ticks this combatant has sourced this battle.
    public var burnTickCount: Int

    /// Round until which Toughness-based inherent DR is reduced by `mitigationShredMultiplier`.
    public var mitigationShredUntilTick: Int

    /// Multiplier applied to Toughness-based DR while shred is active (e.g. 0.5 halves it).
    public var mitigationShredMultiplier: Double

    public init(
        combatant: Combatant,
        initialHealth: Int? = nil,
        initialMana: Int? = nil,
        initialActiveEffects: [ActiveEffect] = [],
        maximumHealthBonus: Int = 0,
        maximumManaBonus: Int = 0,
        hasConsumedDeathsDoor: Bool = false,
        deathsDoorExpiredAtTick: Int? = nil,
        hasTriggeredAmbush: Bool = false,
        hasTriggeredSecondWind: Bool = false,
        hasTriggeredHexmark: Bool = false,
        pendingDamageAfterDodge: Int = 0,
        bleedApplyCount: Int = 0,
        burnTickCount: Int = 0,
        mitigationShredUntilTick: Int = 0,
        mitigationShredMultiplier: Double = 1
    ) {
        self.combatant = combatant
        self.maximumHealthBonus = maximumHealthBonus
        self.maximumManaBonus = maximumManaBonus
        self.hasConsumedDeathsDoor = hasConsumedDeathsDoor
        self.deathsDoorExpiredAtTick = deathsDoorExpiredAtTick
        self.hasTriggeredAmbush = hasTriggeredAmbush
        self.hasTriggeredSecondWind = hasTriggeredSecondWind
        self.hasTriggeredHexmark = hasTriggeredHexmark
        self.pendingDamageAfterDodge = pendingDamageAfterDodge
        self.bleedApplyCount = bleedApplyCount
        self.burnTickCount = burnTickCount
        self.mitigationShredUntilTick = mitigationShredUntilTick
        self.mitigationShredMultiplier = mitigationShredMultiplier
        currentHealth = initialHealth ?? (combatant.maxHealth + combatant.primaryStats.toughness + maximumHealthBonus)
        currentMana = initialMana ?? (combatant.hasMana ? combatant.maxMana + combatant.primaryStats.intellect + maximumManaBonus : 0)
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
}
