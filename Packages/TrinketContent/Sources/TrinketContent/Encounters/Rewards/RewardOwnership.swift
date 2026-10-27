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
        if ids.count == 1, let id = ids.first {
            guard let definition = NodeModifierCatalog.modifier(id: id) else { return [] }
            guard case let .reward(reward) = definition.effect else { return [definition] }
            guard resolved(reward, enemyIsBoss: enemyIsBoss) != reward else { return [definition] }
            return NodeModifierCatalog.modifier(id: NodeModifierCatalog.rewardID(.gold)).map { [$0] } ?? []
        }
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
