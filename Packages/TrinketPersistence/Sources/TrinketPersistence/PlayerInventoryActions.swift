public extension PlayerSaveStore {
    @discardableResult
    func salvageItem(id: String) -> ItemSalvageResult? {
        var result: ItemSalvageResult = .itemNotFound
        guard persistBatch(logging: "Failed to salvage item \(id)", { save in
            result = ItemSalvageApplier.salvage(itemID: id, save: &save)
        }) else {
            return nil
        }
        return result
    }
}
