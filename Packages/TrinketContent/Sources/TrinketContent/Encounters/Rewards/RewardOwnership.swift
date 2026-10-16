public struct RewardOwnership: Equatable, Sendable {
    public func resolved(_ modifier: RewardModifier, enemyIsBoss: Bool = false) -> RewardModifier {
        guard !enemyIsBoss || !modifier.isItemFocused else { return .gold }
        return modifier.resolved(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public var eligibleModifiers: [RewardModifier] {
        RewardModifier.eligible(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public func modifiers(ids: [NodeModifierID], enemyIsBoss: Bool = false) -> [NodeModifierDefinition] {
        NodeModifierCatalog.modifiers(ids: ids, eligibleRewards: eligibleModifiers, enemyIsBoss: enemyIsBoss)
    }

    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }
}
