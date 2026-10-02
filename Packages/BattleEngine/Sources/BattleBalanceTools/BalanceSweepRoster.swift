import TrinketContent

public struct BalanceSweepRoster: Equatable, Sendable {
    public var heroes: [Combatant]
    public var companions: [Combatant]
    public var enemies: [Enemy]

    public static func resolve(config: BalanceSweepConfig) -> Self {
        let heroes = filter(GameContent.heroes, ids: config.heroIDs, id: \.id)
        let companions = filter(GameContent.companions, ids: config.companionIDs, id: \.id)
        let enemies = filter(GameContent.enemies, ids: config.enemyIDs, id: \.id)
        return Self(heroes: heroes, companions: companions, enemies: enemies)
    }

    private static func filter<Element>(_ all: [Element], ids: [String], id: KeyPath<Element, String>) -> [Element] {
        guard !ids.isEmpty else { return all }
        let wanted = Set(ids)
        return all.filter { wanted.contains($0[keyPath: id]) }
    }
}
