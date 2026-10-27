public struct RewardOwnership: Equatable, Sendable {
    public func resolved(_ modifier: RewardModifier, enemyIsBoss: Bool = false) -> RewardModifier {
        guard !enemyIsBoss || !modifier.isItemFocused else { return .gold }
        return modifier.resolved(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public var eligibleModifiers: [RewardModifier] {
        RewardModifier.eligible(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public func modifiers(ids: [NodeModifierID], enemyIsBoss: Bool = false) -> [NodeModifierDefinition] {
        guard !ids.isEmpty else { return [] }
        let hasReward = ids.contains { id in
            guard let definition = NodeModifierCatalog.modifier(id: id) else { return false }
            if case .reward = definition.effect {
                return true
            }
            return false
        }
        guard hasReward else { return ids.compactMap(NodeModifierCatalog.modifier(id:)) }
        return NodeModifierCatalog.modifiers(ids: ids, eligibleRewards: eligibleModifiers, enemyIsBoss: enemyIsBoss)
    }

    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }
}
