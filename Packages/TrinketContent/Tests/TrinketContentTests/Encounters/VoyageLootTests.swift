import Testing
import TrinketContent
import TrinketCore

struct VoyageLootTests {
    @Test func `final destination and node Gold bonuses add on the boss reward`() {
        let context = BattleLootContext(worldSeed: 0x5445_5354)
        let offer = VoyageOffer(id: "gold-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .gold)
        let plain = VoyageNode(id: "gold-boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        var marked = plain
        marked.modifierIDs = [NodeModifierCatalog.rewardID(.gold)]
        let baseline = context.voyage(node: plain, encounterLevel: 10)
        let enhanced = context.finalVoyage(node: marked, offer: offer, encounterLevel: 10)
        #expect(enhanced.primary.gold == CombatRounding.scaled(baseline.gold, byPercent: 50))
        #expect(enhanced.additionalItem == nil)
        #expect(enhanced.primary.materials == baseline.materials)
    }

    @Test func `two material focuses fill both boss slots`() {
        let context = BattleLootContext(worldSeed: 0x5445_5354)
        let offer = VoyageOffer(id: "material-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .stone)
        let node = VoyageNode(
            id: "material-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.wood)], recruitEventID: nil,
        )
        let loot = context.finalVoyage(node: node, offer: offer, encounterLevel: 10)
        #expect(Set(loot.primary.materials.map(\.resource)) == [.wood, .stone])
        let raw = BattleLoot.quantityRange(forLevel: 10)
        let possible = Set(raw.map { CombatRounding.scaled($0 * 2, byPercent: RewardModifier.bonusPercent) })
        #expect(loot.primary.materials.allSatisfy { possible.contains($0.quantity) })
    }

    @Test func `two item modifiers make deterministic independent boss rolls`() throws {
        let context = BattleLootContext(worldSeed: 0x5445_5354)
        let offer = VoyageOffer(id: "item-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .armorHoard)
        let node = VoyageNode(
            id: "item-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.armsHoard)], recruitEventID: nil,
        )
        let first = context.finalVoyage(node: node, offer: offer, encounterLevel: 10)
        let second = context.finalVoyage(node: node, offer: offer, encounterLevel: 10)
        #expect(first.primary == second.primary)
        #expect(first.additionalItem == second.additionalItem)
        #expect(first.primary.item.baseType.slot == .weapon)
        #expect(try #require(first.additionalItem).baseType.slot == .armor)
        #expect(first.primary.item.id != first.additionalItem?.id)
    }

    @Test func `exhausted destination collectible resolves to Bonus Gold`() {
        let context = BattleLootContext(
            worldSeed: 0x5445_5354,
            ownership: RewardOwnership(ownedTrinketIDs: Set(GameContent.trinketItems.map(\.templateID))),
        )
        let offer = VoyageOffer(id: "exhausted", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .trinketHoard)
        let node = VoyageNode(id: "exhausted-boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        let baseline = context.voyage(node: node, encounterLevel: 10)
        let final = context.finalVoyage(node: node, offer: offer, encounterLevel: 10)
        #expect(context.ownership.resolved(offer.rewardModifier) == .gold)
        #expect(final.primary.gold == CombatRounding.scaled(baseline.gold, byPercent: RewardModifier.bonusPercent))
        #expect(final.additionalItem == nil)
    }

    @Test func `second collectible roll converts to Gold when the first takes the last item`() throws {
        let remaining = try #require(GameContent.uniqueItems.last)
        let owned = GameContent.uniqueItems.filter { $0.templateID != remaining.templateID }
        let context = BattleLootContext(
            worldSeed: 0x5445_5354,
            ownership: RewardOwnership(ownedUniqueIDs: Set(owned.map(\.templateID))),
        )
        let offer = VoyageOffer(id: "last-unique", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .uniqueHoard)
        let node = VoyageNode(
            id: "last-unique-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.uniqueHoard)], recruitEventID: nil,
        )
        let ordinary = context.voyage(node: node, encounterLevel: 10)
        let final = context.finalVoyage(node: node, offer: offer, encounterLevel: 10)
        #expect(final.primary.item.templateID == remaining.templateID)
        #expect(final.additionalItem == nil)
        #expect(final.primary.gold == CombatRounding.scaled(ordinary.gold, byPercent: RewardModifier.bonusPercent))
    }
}
