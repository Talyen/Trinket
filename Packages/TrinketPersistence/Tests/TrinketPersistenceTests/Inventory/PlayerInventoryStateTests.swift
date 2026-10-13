import Testing
import TrinketContent
@testable import TrinketPersistence

struct PlayerInventoryStateTests {
    @Test func `signed gold delta cannot reduce balance below zero`() {
        var save = PlayerSave.fresh
        save.roster.gold = 2

        let applied = save.applyGoldDelta(-3)

        #expect(applied == -2)
        #expect(save.roster.gold == 0)
    }

    @Test func `add reward item ignores duplicate ID`() throws {
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]
        var inventory = PlayerInventoryState.freshStart

        inventory.addRewardItem(from: template, for: stage)
        inventory.addRewardItem(from: template, for: stage)

        try #expect(inventory.items.count == 1)
        try #expect(inventory.items.first?.id == "chapter-1-stage-1-shortsword-basic")
    }
}
