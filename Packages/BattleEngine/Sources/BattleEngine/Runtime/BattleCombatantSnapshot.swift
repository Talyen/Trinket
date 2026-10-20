import TrinketCore

/// Immutable combat facts for optional command playback; no live runtime storage escapes.
public struct BattleCombatantSnapshot: Equatable, Sendable {
    public let id: String
    public let health: Int
    public let maxHealth: Int
    public let mana: Int
    public let maxMana: Int
    public let activeEffects: [ActiveEffect]

    init(_ runtime: CombatantRuntime) {
        id = runtime.id
        health = runtime.currentHealth
        maxHealth = runtime.maxHealth
        mana = runtime.currentMana
        maxMana = runtime.maxMana
        activeEffects = runtime.activeEffects
    }
}

public struct BattleCombatantChange: Equatable, Sendable {
    public let eventID: Int
    public let before: BattleCombatantSnapshot
    public let after: BattleCombatantSnapshot
}
