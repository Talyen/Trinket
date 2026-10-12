import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct ItemCorruptionTests {
    @Test(arguments: [false, true])
    func `saved unknown affixes remain intact and cannot enter the altar`(hasStoredPowers: Bool) throws {
        let known = try makeItem(baseID: "longsword", rarity: .basic)
        let unknown = ItemAffix(id: "removed-affix", title: "Old Affix", description: "Saved effect.", keywords: [])
        let item = InventoryItem(
            id: known.id, baseType: known.baseType, rarity: known.rarity, displayName: known.displayName,
            affixes: [unknown] + known.affixes,
            affixPowers: hasStoredPowers ? [ItemAffixPower(description: unknown.description, modifiers: [])]
                + known.affixes.compactMap { GameContent.itemAffixDefinition(matching: $0.id)?.basic } : nil,
        )
        let restored = try #require(StoredInventoryItem(item).resolved())
        #expect(restored == item)
        var save = PlayerSave.testSeed
        save.inventory.items = [restored]
        var rng = SeededRandomNumberGenerator(seed: 123)
        var untouchedRNG = rng

        #expect(!ItemCorruption.isEligibleTarget(restored))
        #expect(ItemCorruption.eligibleTargets(in: save.inventory.items).isEmpty)
        #expect(ItemCorruption.corrupt(restored, using: &rng) == nil)
        #expect(ItemCorruptionApplier.corrupt(itemID: restored.id, save: &save, using: &rng) == .failure(.ineligible))
        #expect(save.inventory.items == [restored])
        #expect(rng.next() == untouchedRNG.next())
    }

    @Test func `already corrupted items rejected`() throws {
        var item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        item = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: item.baseType,
            rarity: item.rarity,
            displayName: item.displayName,
            affixes: item.affixes,
            isCorrupted: true,
            affixPowers: item.affixes.compactMap {
                GameContent.itemAffixDefinition(matching: $0.id)?.power(for: item.rarity)
            },
        )
        var save = PlayerSave.testSeed
        save.inventory.items = [item]
        var rng = SeededRandomNumberGenerator(seed: 1)
        let result = ItemCorruptionApplier.corrupt(itemID: item.id, save: &save, using: &rng)
        #expect(result == .failure(.alreadyCorrupted))
    }

    @Test func `legacy marked affix reports already corrupted`() throws {
        let plain = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        let markedOnly = withMarkedFirstAffix(plain)
        var save = PlayerSave.testSeed
        save.inventory.items = [markedOnly]
        var rng = SeededRandomNumberGenerator(seed: 1)
        let result = ItemCorruptionApplier.corrupt(itemID: markedOnly.id, save: &save, using: &rng)
        #expect(result == .failure(.alreadyCorrupted))
        #expect(save.inventory.items == [markedOnly])
    }

    @Test @MainActor func `store corruption command persists its committed result`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2, id: "store-corrupt")
        try store.performFixtureMutation { save in
            save.inventory.items = [item]
        }
        var rng = SeededRandomNumberGenerator(seed: 3)
        let outcome = store.corruptItem(id: item.id, using: &rng)
        guard case let .committed(applied) = outcome else {
            Issue.record("Expected corruption success, got \(String(describing: outcome))")
            return
        }
        #expect(applied.item.isCorrupted)
        let stored = try #require(store.currentSave.inventory.items.first { $0.id == item.id })
        #expect(stored.isCorrupted)
        #expect(stored.hasCorruptedAffix)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.inventory.item(matching: item.id) == applied.item)
    }

    @Test func `trinkets cannot be corrupted`() throws {
        let trinket = try #require(GameContent.trinketItems.first)
        var save = PlayerSave.fresh
        save.inventory.items = [trinket]
        var rng = SeededRandomNumberGenerator(seed: 1)

        let result = ItemCorruptionApplier.corrupt(itemID: trinket.id, save: &save, using: &rng)

        #expect(result == .failure(.ineligible))
        #expect(save.inventory.items == [trinket])
    }

    @Test func `cooldown decrements on non altar mystery`() {
        var save = PlayerSave.testSeed
        save.corruptionAltarCooldownRemaining = 3
        ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        #expect(save.corruptionAltarCooldownRemaining == 2)
        ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
        #expect(save.corruptionAltarCooldownRemaining == 6)
    }

    @Test @MainActor func `corruption persists across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let item = try makeItem(baseID: "sapphire_ring", rarity: .basic, affixCount: 2, id: "corrupt-ring")
        try store.performFixtureMutation { save in
            save.inventory.items = [item]
        }

        let seed = try #require((UInt64(1) ... 64).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            guard let detail = ItemCorruption.corrupt(item, using: &rng) else { return false }
            return detail.item.affixes.contains { affix in
                !item.affixes.contains { $0.id == affix.id }
                    && detail.effects.contains {
                        $0 == .bumpedUp(affixTitle: affix.title) || $0 == .bumpedDown(affixTitle: affix.title)
                    }
            }
        })
        var applied: ItemCorruptionDetail?
        try store.performFixtureMutation { save in
            var rng = SeededRandomNumberGenerator(seed: seed)
            if case let .success(result) = ItemCorruptionApplier.corrupt(
                itemID: item.id,
                save: &save,
                using: &rng,
            ) {
                applied = result
                ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
            }
        }

        let result = try #require(applied)
        #expect(result.item.isCorrupted)
        #expect(result.item.affixes.filter(\.isCorrupted).count == 1)
        #expect(store.currentSave.corruptionAltarCooldownRemaining == 6)

        let reloaded = try context.makeSaveStore()
        let reloadedItem = try #require(reloaded.currentSave.inventory.items.first { $0.id == item.id })
        #expect(reloadedItem == result.item)
        #expect(reloadedItem.isCorrupted)
        #expect(reloadedItem.hasCorruptedAffix)
        #expect(reloadedItem.affixes.filter(\.isCorrupted).count == 1)
        #expect(reloadedItem.affixPowers?.count == reloadedItem.affixes.count)
        #expect(reloaded.currentSave.corruptionAltarCooldownRemaining == 6)

        #expect(!ItemCorruption.isEligibleTarget(reloadedItem))
    }
}

private func makeItem(
    baseID: String,
    rarity: Rarity,
    affixCount: Int = 1,
    id: String = "test-item",
) throws -> InventoryItem {
    let base = try #require(GameContent.itemBaseTypes.first { $0.id == baseID })
    let pool = GameContent.itemAffixDefinitions.filter { $0.slot == base.slot }
    let definitions = Array(pool.prefix(affixCount))
    try #require(definitions.count == affixCount)
    return InventoryItem(
        id: id,
        baseType: base,
        rarity: rarity,
        displayName: base.name,
        affixes: definitions.map { $0.resolved(for: rarity) },
    )
}

private func withMarkedFirstAffix(_ item: InventoryItem) -> InventoryItem {
    InventoryItem(
        id: item.id,
        templateID: item.templateID,
        baseType: item.baseType,
        rarity: item.rarity,
        displayName: item.displayName,
        affixes: item.affixes.enumerated().map { index, affix in
            ItemAffix(
                id: affix.id,
                title: affix.title,
                description: affix.description,
                keywords: affix.keywords,
                isCorrupted: index == 0,
            )
        },
        isCorrupted: false,
        affixPowers: item.affixPowers,
    )
}
