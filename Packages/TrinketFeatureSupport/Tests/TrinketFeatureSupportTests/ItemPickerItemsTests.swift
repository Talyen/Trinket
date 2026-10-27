import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureAdapters

struct ItemPickerItemsTests {
    @Test func `search combines fields and filters`() {
        let base = makeItem("match", name: "Étoile", rarity: .astral, keyword: .burn)
        let item = InventoryItem(
            id: base.id, baseType: base.baseType, rarity: base.rarity, displayName: base.displayName,
            affixes: base.affixes + [ItemAffix(id: "purity", title: "Purity", description: "Restore Health.", keywords: [.health])],
        )
        var model = ItemPickerItems()
        model.update(inventory: [item, makeItem("other", rarity: .basic)], loadout: .init(), slot: .weapon)
        let filter = ItemPickerFilter(search: "  ETOILE sword flame damage purity health BURN \n", rarity: .astral, keyword: .burn)
        #expect(model.matching(filter).map(\.id) == [item.id])
        #expect(model.matching(ItemPickerFilter(search: "etoile missing")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "etoile", rarity: .unique)).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "etoile", keyword: .poison)).isEmpty)
        #expect(model.keywords == [.burn, .health, .physical])
        #expect(!model.keywords.contains(.poison))
    }

    @Test func `search finds displayed translations and rebuilds for the rendering locale`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "maul"))
        let item = InventoryItem(
            id: "localized-maul", baseType: base, rarity: .basic, displayName: base.name,
            affixes: [ItemAffix(
                id: "search-fixture",
                title: "Smoldering",
                description: "Increase Burn damage by 1",
                keywords: [.burn, .dodge],
            )],
        )
        var model = ItemPickerItems()
        model.update(inventory: [item], loadout: .init(), slot: .weapon, locale: Locale(identifier: "en"))
        #expect(model.matching(ItemPickerFilter(search: "Maul Smoldering")).map(\.id) == [item.id])
        // The unchanged inventory must rebuild: the card's item noun differs from the Maul attack.
        model.update(inventory: [item], loadout: .init(), slot: .weapon, locale: Locale(identifier: "ko"))
        #expect(model.matching(ItemPickerFilter(search: "대형 망치 그을린 화상 피해 1 증가 회피")).map(\.id) == [item.id])
        #expect(model.matching(ItemPickerFilter(search: "후려치기")).isEmpty)
        model.update(inventory: [item], loadout: .init(), slot: .weapon, locale: Locale(identifier: "en"))
        #expect(model.matching(ItemPickerFilter(search: "대형 망치")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "Maul Smoldering")).map(\.id) == [item.id])
    }

    @Test func `order is deterministic and stable during visit`() {
        let items = [
            makeItem("z", rarity: .astral), makeItem("b", rarity: .unique),
            makeItem("equipped", rarity: .basic), makeItem("a", rarity: .astral),
        ]
        var model = ItemPickerItems()
        model.update(inventory: items, loadout: .init(itemIDsBySlot: [.weapon: "equipped"]), slot: .weapon)
        #expect(model.eligible.map(\.id) == ["equipped", "b", "a", "z"])
        #expect(model.matching(ItemPickerFilter(rarity: .astral)).map(\.id) == ["a", "z"])
        model.update(inventory: items.reversed(), loadout: .init(itemIDsBySlot: [.weapon: "z"]), slot: .weapon)
        #expect(model.eligible.map(\.id) == ["equipped", "b", "a", "z"])
        var nextVisit = ItemPickerItems()
        nextVisit.update(inventory: items, loadout: .init(itemIDsBySlot: [.weapon: "z"]), slot: .weapon)
        #expect(nextVisit.eligible.map(\.id) == ["z", "b", "a", "equipped"])
    }

    @Test func `inventory changes refresh search and eligibility`() {
        var model = ItemPickerItems()
        model.update(inventory: [makeItem("same", name: "Old")], loadout: .init(), slot: .weapon)
        model.update(inventory: [makeItem("same", name: "New", keyword: .burn)], loadout: .init(), slot: .weapon)
        #expect(model.matching(ItemPickerFilter(search: "old")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "new", keyword: .burn)).map(\.id) == ["same"])
        let replacement = makeItem("replacement", name: "Replacement", keyword: .poison)
        model.update(inventory: [replacement], loadout: .init(), slot: .weapon)
        #expect(model.eligible.map(\.id) == [replacement.id])
        #expect(model.matching(ItemPickerFilter(search: "new")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "replacement", keyword: .poison)).map(\.id) == [replacement.id])
        #expect(!model.keywords.contains(.burn))
        model.update(inventory: [replacement], loadout: .init(), slot: .armor)
        #expect(model.eligible.isEmpty)
        #expect(model.keywords.isEmpty)
    }

    @Test func `large inventories retain distinct instances`() {
        let count = 500
        let items = (0 ..< count).map { makeItem("item-\($0)", rarity: $0.isMultiple(of: 2) ? .astral : .basic) }
        var model = ItemPickerItems()
        model.update(inventory: items, loadout: .init(), slot: .weapon)
        #expect(Set(model.eligible.map(\.id)).count == count)
        #expect(model.matching(ItemPickerFilter(search: "sword", rarity: .astral)).count == count / 2)
    }

    @Test func `search follows items becoming eligible and changing while hidden`() {
        let old = makeItem("sword", name: "Old")
        let updated = makeItem("sword", name: "New", keyword: .burn)
        var model = ItemPickerItems()
        model.update(inventory: [old], loadout: .init(), slot: .armor)
        #expect(model.matching(ItemPickerFilter(search: "old")).isEmpty)
        model.update(inventory: [old], loadout: .init(), slot: .weapon)
        #expect(model.matching(ItemPickerFilter(search: "old")).map(\.id) == [old.id])
        model.update(inventory: [old], loadout: .init(), slot: .armor)
        model.update(inventory: [updated], loadout: .init(), slot: .armor)
        model.update(inventory: [updated], loadout: .init(), slot: .weapon)
        #expect(model.matching(ItemPickerFilter(search: "old")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "new", keyword: .burn)).map(\.id) == [updated.id])
    }

    private func makeItem(
        _ id: String,
        name: String = "Sword",
        rarity: Rarity = .basic,
        keyword: Keyword = .physical,
    ) -> InventoryItem {
        InventoryItem(
            id: id,
            baseType: ItemBaseType(id: "sword", name: "Sword", slot: .weapon, weaponKind: .oneHanded, keywordAffinities: [.poison]),
            rarity: rarity,
            displayName: name,
            affixes: [ItemAffix(id: "picker-fixture", title: "Flame", description: "Deal damage.", keywords: [keyword])],
        )
    }
}
