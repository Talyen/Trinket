import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

struct CollectionSearchTests {
    @Test func emptyQueryReturnsNoResults() throws {
        let wand = try #require(GameContent.itemTemplate(matching: "wand-basic"))
        let results = CollectionSearch.results(
            for: "   ",
            rosterState: .initial,
            inventoryState: PlayerInventoryState(items: [wand])
        )

        #expect(results.isEmpty)
    }

    @Test func matchesUnlockedHeroByName() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let results = CollectionSearch.results(
            for: "knight",
            rosterState: .initial,
            inventoryState: .initial
        )

        #expect(results.heroes.map(\.id) == [knight.id])
        #expect(results.pets.isEmpty)
        #expect(results.items.isEmpty)
    }

    @Test func excludesLockedCombatants() throws {
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        #expect(!PlayerRosterState.freshStart.isUnlocked(wolf))

        let results = CollectionSearch.results(
            for: "wolf",
            rosterState: .freshStart,
            inventoryState: .freshStart
        )

        #expect(results.pets.isEmpty)
    }

    @Test func matchesOwnedItemsByDisplayName() throws {
        let wand = try #require(GameContent.itemTemplate(matching: "wand-basic"))
        let results = CollectionSearch.results(
            for: "wand",
            rosterState: .initial,
            inventoryState: PlayerInventoryState(items: [wand])
        )

        #expect(results.items.map(\.id) == [wand.id])
        #expect(results.heroes.isEmpty)
        #expect(results.pets.isEmpty)
    }

    @Test func itemMatcherOptionallyIncludesAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let item = InventoryItem(
            id: "keen-longsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .basic)]
        )

        #expect(!CollectionSearch.matchesItem(item, query: "keen", includeAffixes: false))
        #expect(CollectionSearch.matchesItem(item, query: "keen", includeAffixes: true))
        #expect(CollectionSearch.matchesItem(item, query: baseType.name, includeAffixes: false))
    }
}
