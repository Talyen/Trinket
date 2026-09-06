import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct MysteryEventPinTests {
    @Test func `pin journey event is idempotent`() {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        #expect(MysteryEventPinApplier.pinJourneyEvent(
            stageID: "chapter-1-stage-5",
            eventID: "mana-berries",
            save: &save,
        ))
        #expect(save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == "mana-berries")
        #expect(MysteryEventPinApplier.pinJourneyEvent(
            stageID: "chapter-1-stage-5",
            eventID: "other-event",
            save: &save,
        ))
        #expect(save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == "mana-berries")
    }

    @Test func `pin labyrinth event writes missing pin and skips missing node`() {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        #expect(!MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: "missing-node",
            eventID: "mana-berries",
            save: &save,
        ))

        var node = LabyrinthNode(
            id: "node-a",
            type: .mystery,
            depth: 2,
            clusterID: "cluster-1",
        )
        save.labyrinth.nodes[node.id] = node
        #expect(MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: node.id,
            eventID: "mana-berries",
            save: &save,
        ))
        #expect(save.labyrinth.nodes[node.id]?.mysteryEventID == "mana-berries")

        node.mysteryEventID = "mana-berries"
        save.labyrinth.nodes[node.id] = node
        #expect(MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: node.id,
            eventID: "other-event",
            save: &save,
        ))
        #expect(save.labyrinth.nodes[node.id]?.mysteryEventID == "mana-berries")
    }

    @Test(arguments: [false, true]) @MainActor
    func `offers survive disk reload and claim exactly once`(inLabyrinth: Bool) throws {
        let context = try PersistenceTestContext()
        let event = try #require(GameContent.mysteryEvent(matching: "crystal-geode"))
        let journeyStage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        let store = try context.makeSaveStore(resetState: true)
        var nodeID: String?
        if inLabyrinth {
            var labyrinth = store.labyrinth
            labyrinth.ensureMap(seed: store.worldSeed)
            nodeID = try #require(labyrinth.nodes.values.filter { $0.type == .mystery }.sorted { $0.id < $1.id }.first?.id)
            store.labyrinth = labyrinth
        }
        let stage = nodeID.map { GameContent.syntheticLabyrinthStage(nodeID: $0, encounter: .mysteryEvent(eventID: event.id)) }
            ?? journeyStage
        var first: [MysteryOffer]?
        #expect(store.persistBatch(logging: "Prepare mystery offers") { save in
            var rng = SeededRandomNumberGenerator(seed: 11)
            first = try? MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nodeID, save: &save, using: &rng)
        })
        let offered = try #require(first)
        #expect(offered.count == 2)
        let reloaded = try context.makeReloadedStore()
        var reopened: [MysteryOffer]?
        #expect(reloaded.persistBatch(logging: "Reopen mystery offers") { save in
            var rng = SeededRandomNumberGenerator(seed: 999)
            reopened = try? MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nodeID, save: &save, using: &rng)
        })
        #expect(reopened == offered)
        let goldBefore = reloaded.roster.gold
        var result = MysteryEffectResult()
        #expect(reloaded.persistBatch(logging: "Claim mystery offer") { save in
            result = MysteryOfferPersistence.claim(offered[0], stage: stage, labyrinthNodeID: nodeID, save: &save)
        })
        #expect(result.grantedItems == [offered[0].item])
        #expect(result.grantedMaterials == [ResourceAmount(.crystal, offered[0].bonus.amount)])
        #expect(reloaded.roster.gold == goldBefore)
        let claimed = try context.makeReloadedStore()
        #expect(claimed.inventory.items.contains(offered[0].item))
        #expect(claimed.persistBatch(logging: "Retry completed mystery") { save in
            result = MysteryOfferPersistence.claim(offered[0], stage: stage, labyrinthNodeID: nodeID, save: &save)
        })
        #expect(result.isEmpty)
        if let nodeID {
            #expect(claimed.labyrinth.nodes[nodeID]?.isCleared == true)
            #expect(claimed.labyrinth.nodes[nodeID]?.mysteryOffersPayload == nil)
        } else {
            #expect(claimed.journey.completedStageIDs.contains(stage.id))
            #expect(claimed.journey.mysteryOfferPayloads[stage.id] == nil)
        }
    }

    @Test func `newly owned special rewards refresh without changing the other offer`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        let matchingSeed = (UInt64(1) ... 1000).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return MysteryItemRarity.roll(using: &rng) == .unique
        }
        var rng = try SeededRandomNumberGenerator(seed: #require(matchingSeed))
        var save = SaveTestSupport.makeSave()
        let first = try MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng)
        #expect(first[0].item.templateID == "rimeheart_locket")
        save.inventory.appendUniqueItem(first[0].item)
        let next = try MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng)
        #expect(next[0].item.templateID != first[0].item.templateID)
        #expect(next[1] == first[1])
        #expect(MysteryOfferPersistence.claim(first[0], stage: stage, labyrinthNodeID: nil, save: &save).isEmpty)
        #expect(!save.journey.completedStageIDs.contains(stage.id))
    }

    @Test func `full gold wallets receive XP and partial wallets quote only receivable gold`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        for gold in [990, 999] {
            var save = SaveTestSupport.makeSave(gold: gold)
            save.homestead.pendingProduction = [:]
            var rng = SeededRandomNumberGenerator(seed: 3)
            let offers = try MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng)
            let offer = offers[0]
            let result = MysteryOfferPersistence.claim(offer, stage: stage, labyrinthNodeID: nil, save: &save)
            #expect(result.grantedItems == [offer.item])
            if gold == 990 {
                #expect(offer.bonus == .gold(9))
                #expect(result.grantedGold == 9)
            } else {
                guard case .experience = offer.bonus else { Issue.record("Expected XP for a full Gold wallet"); continue }
                #expect(offer.bonus.amount > 0)
                #expect(result.heroGrantedExperience == offer.bonus.amount)
                #expect(result.companionGrantedExperience == offer.bonus.amount)
            }
        }
    }

    @Test func `older labyrinth node payloads decode without offers`() throws {
        let node = LabyrinthNode(id: "legacy", type: .mystery, depth: 1, clusterID: "floor-1", mysteryEventID: "mana-berries")
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(LabyrinthNode.self, from: data)
        #expect(decoded.mysteryOffersPayload == nil)
        #expect(decoded.mysteryEventID == "mana-berries")
    }

    @Test func `journey gates corruption altar by chapter number`() {
        let inventory = PlayerInventoryState.testSeed
        let chapterOne = MysteryEventPickContext.journey(
            chapterNumber: 1,
            inventory: inventory,
            corruptionAltarCooldownRemaining: 0,
        )
        #expect(chapterOne.allowsCorruptionAltar == false)

        let chapterTwo = MysteryEventPickContext.journey(
            chapterNumber: 2,
            inventory: inventory,
            corruptionAltarCooldownRemaining: 0,
        )
        #expect(chapterTwo.allowsCorruptionAltar == true)
    }

    @Test func `labyrinth always allows corruption altar`() {
        let inventory = PlayerInventoryState.testSeed
        let context = MysteryEventPickContext.labyrinth(
            inventory: inventory,
            corruptionAltarCooldownRemaining: 3,
        )
        #expect(context.allowsCorruptionAltar == true)
        #expect(context.corruptionAltarCooldownRemaining == 3)
        #expect(
            context.hasEligibleCorruptTarget
                == !ItemCorruption.eligibleTargets(in: inventory).isEmpty,
        )
    }
}
