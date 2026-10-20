public enum ItemWish {
    public static func validTarget(_ id: String?, inventory: [InventoryItem]) -> String? {
        guard let id, (GameContent.uniqueItems + GameContent.trinketItems).contains(where: { $0.templateID == id }),
              !inventory.contains(where: { $0.templateID == id }) else { return nil }
        return id
    }

    static func select(
        from candidates: [InventoryItem], wishedTemplateID: String?,
        using random: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        if let wishedTemplateID, let wish = candidates.first(where: { $0.templateID == wishedTemplateID }) {
            let others = candidates.filter { $0.templateID != wishedTemplateID }
            if others.isEmpty || Int.random(in: 0 ... 1, using: &random) == 0 {
                return wish
            }
            return others[Int.random(in: others.indices, using: &random)]
        }
        return candidates[Int.random(in: candidates.indices, using: &random)]
    }
}
