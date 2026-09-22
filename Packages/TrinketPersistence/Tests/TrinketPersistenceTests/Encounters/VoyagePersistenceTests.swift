import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct VoyagePersistenceTests {
    @Test func `board access and run lifecycle`() throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        #expect(Set(state.offers.map(\.chapterID)) == ["chapter-1", "chapter-2", "chapter-3"])
        #expect(state.offers.map(\.difficulty) == VoyageDifficulty.allCases)
        let original = state
        state.ensureBoard(access: .free)
        #expect(state == original)
        let offer = try #require(state.offers.first)
        let didEmbark = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(didEmbark)
        let embarked = state
        state.refresh(access: .free)
        #expect(state == embarked)
        let duplicateEmbark = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(!duplicateEmbark)
        let didAbandon = state.abandon(runID: offer.id, access: .free)
        #expect(didAbandon)
        #expect(state.activeRun == nil)
        #expect(state.offers[0].id != offer.id)
        #expect(Array(state.offers.dropFirst()) == Array(original.offers.dropFirst()))
        #expect(!state.isPlayable(runID: offer.id, nodeID: embarked.activeRun?.nodes.first?.id ?? ""))
    }

    @Test @MainActor func `active route stock and mystery pins survive reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistBatch(logging: "Voyage setup") { save in
            save.roster = .testSeed
            save.voyage.ensureBoard(access: .free)
            _ = save.voyage.embark(offerID: save.voyage.offers[0].id, eligibleRecruitEventIDs: [], access: .free)
        })
        let run = try #require(store.voyage.activeRun)
        let shopIndex = try #require(run.nodes.firstIndex { $0.type == .shop })
        #expect(store.persistBatch(logging: "Voyage progress") { save in
            for node in run.nodes.prefix(shopIndex) {
                save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
            }
            save.voyage.activeRun?.earnedGold = 37
            save.voyage.activeRun?.earnedMaterials = [.wood: 11]
        })
        let shop = EncounterIdentity(location: .voyage(runID: run.id, nodeID: run.nodes[shopIndex].id), save: store.currentSave)
        #expect(store.persistBatch(logging: "Voyage shop") { save in
            _ = ShopStockPersistence.prepare(encounter: shop, save: &save)
        })
        let stock = try #require(try ShopStockPersistence.stock(encounter: shop, save: store.currentSave))
        let offer = try #require(stock.offers.first)
        #expect(store.persistBatch(logging: "Voyage purchase") { save in
            save.roster.gold = 10000
            _ = ShopPurchaseApplier.purchase(offerID: offer.id, encounter: shop, save: &save)
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage == store.voyage)
        let loadedStock = try #require(try ShopStockPersistence.stock(encounter: shop, save: reloaded.currentSave))
        #expect(loadedStock.purchasedOfferIDs.contains(offer.id))
        #expect(loadedStock.offers == stock.offers)
        #expect(reloaded.persistBatch(logging: "Voyage mystery pin") { save in
            if let node = save.voyage.activeRun?.nodes.first(where: { $0.type == .mystery }) {
                save.voyage.updateNode(runID: run.id, nodeID: node.id) {
                    $0.mysteryEventID = "pinned-event"
                    $0.mysteryOffersPayload = Data([1, 2, 3])
                }
            }
        })
        #expect(try context.makeReloadedStore().voyage == reloaded.voyage)
        let snapshot = CloudSaveSnapshot(reloaded.currentSave)
        let decoded = try JSONDecoder().decode(CloudSaveSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(try decoded.restored().voyage == reloaded.voyage)
    }

    @Test @MainActor func `mystery offers reload and claim within voyage`() throws {
        let context = try PersistenceTestContext()
        var save = SaveTestSupport.makeSave()
        save.voyage.ensureBoard(access: .free)
        _ = save.voyage.embark(offerID: save.voyage.offers[0].id, eligibleRecruitEventIDs: [], access: .free)
        let run = try #require(save.voyage.activeRun)
        let index = try #require(run.nodes.firstIndex { $0.type == .mystery })
        for node in run.nodes.prefix(index) {
            save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
        }
        let node = run.nodes[index]
        let event = try #require(GameContent.mysteryEvent(matching: "crystal-geode"))
        let stage = GameContent.syntheticLabyrinthStage(nodeID: node.id, encounter: .mysteryEvent(eventID: event.id))
        let encounter = EncounterIdentity(location: .voyage(runID: run.id, nodeID: node.id), save: save)
        save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.mysteryEventID = event.id }
        var rng = SeededRandomNumberGenerator(seed: 19)
        let first = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, encounter: encounter, save: &save, using: &rng,
        )
        #expect(first.count == 2)
        try SaveTestSupport.writeRoot(save, to: context.storeURL())
        let store = try context.makeSaveStore()
        var reopened: [MysteryOffer] = []
        #expect(store.persistBatch(logging: "Reopen Voyage mystery") { candidate in
            do {
                reopened = try MysteryOfferPersistence.prepare(
                    event: event, stage: stage, labyrinthNodeID: nil, encounter: encounter, save: &candidate, using: &rng,
                )
            } catch { Issue.record("Voyage mystery failed to reopen: \(error)") }
        })
        #expect(reopened == first)
        let offered = try #require(first.first)
        let before = store.currentSave
        var result = MysteryEffectResult()
        #expect(store.persistBatch(logging: "Claim Voyage mystery") { candidate in
            result = MysteryOfferPersistence.claim(offered, stage: stage, labyrinthNodeID: nil, encounter: encounter, save: &candidate)
        })
        #expect(result.grantedItems == [offered.item])
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage.activeRun?.node(id: node.id)?.isCleared == true)
        #expect(reloaded.voyage.activeRun?.earnedGold == before.voyage.activeRun?.earnedGold)
        #expect(reloaded.voyage.activeRun?.earnedMaterials == before.voyage.activeRun?.earnedMaterials)
        #expect(reloaded.journey == before.journey)
        var claimed = reloaded.currentSave
        let duplicate = MysteryOfferPersistence.claim(offered, stage: stage, labyrinthNodeID: nil, encounter: encounter, save: &claimed)
        #expect(duplicate.isEmpty)
        #expect(claimed == reloaded.currentSave)
    }

    @Test @MainActor func `missing and unreadable payloads preserve other progress`() throws {
        let context = try PersistenceTestContext()
        let saved = PlayerSave.testSeed
        let unreadable = Data("{\"version\":999}".utf8)
        try SaveTestSupport.writeRoot(saved, to: context.storeURL()) { modelContext in
            let root = try #require(try modelContext.fetch(FetchDescriptor<PlayerSaveRoot>()).first)
            root.voyagePayload = unreadable
        }
        let store = try context.makeSaveStore()
        #expect(store.voyage.isUnreadable)
        #expect(store.voyage.encodedPayload == unreadable)
        #expect(store.roster == saved.roster)
        #expect(store.persistBatch(logging: "Preserve unreadable Voyage") { $0.voyage.refresh(access: .free) })
        #expect(try context.makeReloadedStore().voyage.encodedPayload == unreadable)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(CloudSaveSnapshot(saved))) as? [String: Any])
        json.removeValue(forKey: "voyagePayload")
        let old = try JSONDecoder().decode(CloudSaveSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(try old.restored().voyage == .freshStart)
    }
}
