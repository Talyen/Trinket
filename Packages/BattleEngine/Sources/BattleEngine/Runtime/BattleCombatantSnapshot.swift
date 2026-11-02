import TrinketCore

/// Immutable combat facts for optional command playback; no live runtime storage escapes.
public struct BattleCombatantSnapshot: Equatable, Sendable {
    public let id: String
    public let health: Int
    public let maxHealth: Int
    public let mana: Int
    public let maxMana: Int
    public let activeEffects: [ActiveEffect]

    public init(
        id: String,
        health: Int,
        maxHealth: Int,
        mana: Int,
        maxMana: Int,
        activeEffects: [ActiveEffect] = [],
    ) {
        self.id = id
        self.health = health
        self.maxHealth = maxHealth
        self.mana = mana
        self.maxMana = maxMana
        self.activeEffects = activeEffects
    }

    public init(_ runtime: CombatantRuntime) {
        self.init(
            id: runtime.id,
            health: runtime.currentHealth,
            maxHealth: runtime.maxHealth,
            mana: runtime.currentMana,
            maxMana: runtime.maxMana,
            activeEffects: runtime.activeEffects,
        )
    }
}

public struct BattleCombatantChange: Equatable, Sendable {
    public let eventID: Int
    public let before: BattleCombatantSnapshot
    public let after: BattleCombatantSnapshot

    public init(
        eventID: Int,
        before: BattleCombatantSnapshot,
        after: BattleCombatantSnapshot,
    ) {
        self.eventID = eventID
        self.before = before
        self.after = after
    }
}
