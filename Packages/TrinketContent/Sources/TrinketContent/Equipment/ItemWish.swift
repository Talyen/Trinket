public enum ItemWish {
    private static let collectibleTemplateIDs = Set(GameContent.uniqueItems.lazy.map(\.templateID))
        .union(GameContent.trinketItems.lazy.map(\.templateID))

    public static func validTarget(_ id: String?, inventory: [InventoryItem]) -> String? {
        guard let id, collectibleTemplateIDs.contains(id),
              !inventory.contains(where: { $0.templateID == id }) else { return nil }
        return id
    }

    static func select(
        from candidates: [InventoryItem], wishedTemplateID: String?,
        partyBias: PartyLootBias = PartyLootBias(),
        using random: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        if let wishedTemplateID, candidates.count == 1, candidates[0].templateID == wishedTemplateID {
            return candidates[0]
        }
        if let wishedTemplateID, let wish = candidates.first(where: { $0.templateID == wishedTemplateID }) {
            guard candidates.contains(where: { $0.templateID != wishedTemplateID }) else { return wish }
            guard Int.random(in: 0 ... 1, using: &random) != 0 else { return wish }
            return partyBias.select(from: candidates.filter { $0.templateID != wishedTemplateID }, using: &random)
        }
        return partyBias.select(from: candidates, using: &random)
    }
}
