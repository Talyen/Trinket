import Foundation
import Testing
import TrinketContent
@testable import TrinketPersistence

struct CloudSaveMergeClaimsRegressionTests {
    @Test func `two first-floor Spire wins grant their shared reward once`() throws {
        let spire = try #require(GameContent.spires.first)
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        #expect(base.spires.highestClearedFloorBySpireID[spire.id.rawValue] == nil)
        var first = base
        var second = base
        let firstCleared = first.spires.markFloorCleared(1, spireID: spire.id.rawValue)
        let secondCleared = second.spires.markFloorCleared(1, spireID: spire.id.rawValue)
        #expect(firstCleared && secondCleared)
        first.roster.gold = 20
        second.roster.gold = 20

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.spires.highestClearedFloor(for: spire.id.rawValue) == 1)
        #expect(merged.roster.gold == 20)
    }

    @Test func `two first Labyrinth wins grant their shared reward once`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        #expect(base.labyrinth.nodes.isEmpty)
        var first = base
        first.labyrinth.ensureMap(seed: base.worldSeed)
        let nodeID = try #require(first.labyrinth.reachableNodeIDs().first {
            first.labyrinth.node(id: $0)?.type.isCombat == true
        })
        var second = first
        first.labyrinth.markCleared(nodeID: nodeID)
        second.labyrinth.markCleared(nodeID: nodeID)
        first.roster.gold = 20
        second.roster.gold = 20
        #expect(first.labyrinth.node(id: nodeID)?.isCleared == true)
        #expect(second.labyrinth.node(id: nodeID)?.isCleared == true)
        #expect(first.labyrinth.worldSeed == base.worldSeed)
        #expect(CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: second, base: base))

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.labyrinth.node(id: nodeID)?.isCleared == true)
        #expect(merged.roster.gold == 20)
    }

    @Test func `generating the same Labyrinth entrance does not merge unrelated rewards as one claim`() {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        var first = base
        first.labyrinth.ensureMap(seed: base.worldSeed)
        first.roster.gold = 20
        var second = base
        second.labyrinth.ensureMap(seed: base.worldSeed)
        second.roster.gold = 30

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == 40)
    }

    @Test func `two first Voyage wins grant their shared reward once`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        base.voyage.ensureBoard(access: .fullGame)
        let offer = try #require(base.voyage.offers.first)
        var first = base
        var second = base
        let firstEmbarked = first.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame)
        let secondEmbarked = second.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame)
        #expect(firstEmbarked && secondEmbarked)
        let nodeID = try #require(first.voyage.activeRun?.nextNode?.id)
        first.voyage.updateNode(runID: offer.id, nodeID: nodeID) { $0.isCleared = true }
        second.voyage.updateNode(runID: offer.id, nodeID: nodeID) { $0.isCleared = true }
        first.roster.gold = 20
        second.roster.gold = 20

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.voyage.node(runID: offer.id, nodeID: nodeID)?.isCleared == true)
        #expect(merged.roster.gold == 20)
    }

    @Test func `salvaging the same item offline grants its materials once`() throws {
        let item = try #require(GameContent.sampleInventoryItems.first { ItemSalvage.isEligible($0) })
        var base = PlayerSave.testSeed
        base.inventory.items = [item]
        base.homestead.resources = [:]
        base.homestead.lastProductionAt = Date().addingTimeInterval(86400)

        var first = base
        var second = base
        let firstResult = ItemSalvageApplier.salvage(itemID: item.id, save: &first)
        let secondResult = ItemSalvageApplier.salvage(itemID: item.id, save: &second)
        guard case let .success(yields) = firstResult else {
            Issue.record("The source item must be salvageable")
            return
        }
        #expect(secondResult == firstResult)

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.inventory.item(matching: item.id) == nil)
        for yield in yields {
            #expect(merged.homestead.resources[yield.resource, default: 0] == yield.quantity)
        }
    }

    @Test func `two wins of one Labyrinth node pay Gold once when loot differs`() throws {
        var base = PlayerSave.testSeed
        base.inventory.items = []
        base.roster.gold = 10
        base.labyrinth.ensureMap(seed: base.worldSeed)
        let nodeID = try #require(base.labyrinth.reachableNodeIDs().first {
            base.labyrinth.node(id: $0)?.type.isCombat == true
        })
        let loot = try #require(GameContent.uniqueItems.first)
        let otherLoot = try #require(GameContent.uniqueItems.dropFirst().first)

        var first = base
        first.labyrinth.markCleared(nodeID: nodeID)
        first.inventory.appendUniqueItem(loot)
        first.roster.gold = 20
        var second = base
        second.labyrinth.markCleared(nodeID: nodeID)
        second.inventory.appendUniqueItem(otherLoot)
        second.roster.gold = 30

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: false)
        #expect(merged.roster.gold == 30)
        #expect(merged.labyrinth.node(id: nodeID)?.isCleared == true)
        #expect(merged.inventory.items.contains { $0.id == loot.id })
        #expect(merged.inventory.items.contains { $0.id == otherLoot.id })
    }
}
