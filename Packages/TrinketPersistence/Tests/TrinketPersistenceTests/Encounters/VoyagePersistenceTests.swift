import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct VoyagePersistenceTests {
    @Test func `a decoded completed Voyage replaces its retired destination before re-entry`() throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        let original = state.offers
        let offer = try #require(original.first)
        let embarked = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        let run = try #require(state.activeRun)
        for node in run.nodes {
            state.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
        }
        var restored = PlayerVoyageState.decodePayload(state.encodedPayload)
        #expect(restored.activeRun == nil)
        #expect(restored.offers == original)

        restored.ensureBoard(access: .free)

        #expect(restored.offers.count == 3)
        #expect(restored.offers.map(\.difficulty) == VoyageDifficulty.allCases)
        #expect(Set(restored.offers.map(\.chapterID)) == ["chapter-1", "chapter-2", "chapter-3"])
        #expect(Array(restored.offers.dropFirst()) == Array(original.dropFirst()))
        #expect(restored.offers[0].id != offer.id)
        let replacement = restored.offers[0]
        let reembarked = restored.embark(offerID: replacement.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(reembarked)
        let active = restored
        restored.ensureBoard(access: .free)
        #expect(restored == active)
    }

    @Test func `successive battle rewards saturate saved run totals`() throws {
        var save = SaveTestSupport.makeSave()
        save.voyage.ensureBoard(access: .free)
        _ = save.voyage.embark(offerID: save.voyage.offers[0].id, eligibleRecruitEventIDs: [], access: .free)
        let run = try #require(save.voyage.activeRun)
        let battles = run.nodes.filter(\.type.isCombat)
        #expect(battles.count >= 2)
        save.voyage.activeRun?.earnedGold = Int.max - 1
        save.voyage.activeRun?.earnedMaterials = [.wood: Int.max - 1]

        let plan = BattleRewardPlan(
            stageGold: 1, goldFindPercent: 0,
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        )
        let earned = plan.resolve(battleGold: .init(), materials: [ResourceAmount(.wood, 1)])
        for battle in battles.prefix(2) {
            for node in run.nodes.prefix(while: { $0.id != battle.id }) {
                save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
            }
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            let settled = plan.settle(
                battleGold: .init(),
                inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
                materials: [],
            )
            #expect(VoyageCompletion.completeBattle(
                runID: run.id, nodeID: battle.id, party: (hero, companion),
                rewards: (settled: settled, earned: earned, encounterLevel: 12), save: &save, access: .free,
                recordReceipt: { _ in },
            ) == .completed)
        }
        #expect(save.voyage.activeRun?.earnedGold == Int.max)
        #expect(save.voyage.activeRun?.earnedMaterials[.wood] == Int.max)
        #expect(save.contracts.highestWonEncounterLevel == 12)
    }

    @Test func `board access and run lifecycle`() throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        #expect(Set(state.offers.map(\.chapterID)) == ["chapter-1", "chapter-2", "chapter-3"])
        #expect(state.offers.map(\.difficulty) == VoyageDifficulty.allCases)
        #expect(Set(state.offers.map(\.rewardModifier)).count == 3)
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
        let restored = PlayerVoyageState.decodePayload(state.encodedPayload)
        #expect(restored.abandonedRunIDs == [offer.id])
        #expect(restored.completedRunIDs == nil)
        #expect(restored == state)
    }

    @Test(arguments: [false, true])
    func `abandonment retires stale routes without hiding malformed route bytes`(completedOnPeer: Bool) throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        let offer = try #require(state.offers.first)
        let embarked = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        var stale = state
        if completedOnPeer, let run = stale.activeRun {
            for node in run.nodes {
                stale.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
            }
        }
        let abandoned = state.abandon(runID: offer.id, access: .free)
        #expect(abandoned)
        var json = try #require(JSONSerialization.jsonObject(with: stale.encodedPayload) as? [String: Any])
        json["abandonedRunIDs"] = [offer.id]
        let payload = try JSONSerialization.data(withJSONObject: json)
        var restored = PlayerVoyageState.decodePayload(payload)
        #expect(!restored.isUnreadable)
        #expect(restored.activeRun == nil)
        #expect(restored.completedRunIDs == nil)
        let reembarked = restored.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(!reembarked)
        state.activeRun = stale.activeRun
        #expect(state.sanitized().activeRun == nil)
        state.activeRun?.nodes.removeLast()
        let invalidPayload = state.encodedPayload
        #expect(PlayerVoyageState.decodePayload(invalidPayload).encodedPayload == invalidPayload)
        #expect(PlayerVoyageState.decodePayload(invalidPayload).isUnreadable)
        #expect(state.sanitized().encodedPayload == invalidPayload)
    }

    @Test func `destination modifiers survive refresh, replacement, and reload`() throws {
        var state = PlayerVoyageState()
        let choices: [RewardModifier] = [.gold, .experience, .wood]
        state.ensureBoard(access: .free, eligibleModifiers: choices)
        #expect(Set(state.offers.map(\.rewardModifier)) == Set(choices))
        state.refresh(access: .free, eligibleModifiers: choices)
        #expect(Set(state.offers.map(\.rewardModifier)) == Set(choices))
        let offer = try #require(state.offers.first)
        let embarked = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        let run = try #require(state.activeRun)
        #expect(run.offer.rewardModifier == offer.rewardModifier)
        let abandoned = state.abandon(runID: run.id, access: .free, eligibleModifiers: choices)
        #expect(abandoned)
        #expect(Set(state.offers.map(\.rewardModifier)) == Set(choices))
        #expect(try PlayerVoyageState.decodePayload(JSONEncoder().encode(state)) == state)
    }

    @Test func `legacy Voyage offer receives Bonus Gold without changing identity`() throws {
        let offer = VoyageOffer(id: "legacy", chapterID: "chapter-1", difficulty: .easy, seed: 17)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(offer)) as? [String: Any])
        json.removeValue(forKey: "rewardModifier")
        let restored = try JSONDecoder().decode(VoyageOffer.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored == offer)
        #expect(restored.rewardModifier == .gold)
    }

    @Test @MainActor func `active route stock and mystery pins survive reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistFixtureBatch(logging: "Voyage setup") { save in
            save.roster = .testSeed
            save.voyage.ensureBoard(access: .free)
            _ = save.voyage.embark(offerID: save.voyage.offers[0].id, eligibleRecruitEventIDs: [], access: .free)
        })
        let run = try #require(store.voyage.activeRun)
        let shopIndex = try #require(run.nodes.firstIndex { $0.type == .shop })
        #expect(store.persistFixtureBatch(logging: "Voyage progress") { save in
            for node in run.nodes.prefix(shopIndex) {
                save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.isCleared = true }
            }
            save.voyage.activeRun?.earnedGold = 37
            save.voyage.activeRun?.earnedMaterials = [.wood: 11]
        })
        let shop = EncounterIdentity(location: .voyage(runID: run.id, nodeID: run.nodes[shopIndex].id), save: store.currentSave)
        #expect(store.persistFixtureBatch(logging: "Voyage shop") { save in
            _ = ShopStockPersistence.prepare(encounter: shop, save: &save)
        })
        let stock = try #require(try ShopStockPersistence.stock(encounter: shop, save: store.currentSave))
        let offer = try #require(stock.offers.first)
        #expect(store.persistFixtureBatch(logging: "Voyage purchase") { save in
            save.roster.gold = 10000
            _ = ShopPurchaseApplier.purchase(offerID: offer.id, encounter: shop, save: &save, recordReceipt: { _ in })
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage == store.voyage)
        let loadedStock = try #require(try ShopStockPersistence.stock(encounter: shop, save: reloaded.currentSave))
        #expect(loadedStock.purchasedOfferIDs.contains(offer.id))
        #expect(loadedStock.offers == stock.offers)
        let mysteryNode = try #require(reloaded.voyage.activeRun?.nodes.first(where: { $0.type == .mystery }))
        #expect(reloaded.persistFixtureBatch(logging: "Voyage mystery pin") { save in
            save.voyage.updateNode(runID: run.id, nodeID: mysteryNode.id) {
                $0.mysteryEventID = "pinned-event"
                $0.mysteryOffersPayload = Data([1, 2, 3])
            }
        })
        let pinnedSave = try context.makeReloadedStore()
        let pinnedNode = try #require(pinnedSave.voyage.node(runID: run.id, nodeID: mysteryNode.id))
        #expect(pinnedNode.mysteryEventID == "pinned-event")
        #expect(pinnedNode.mysteryOffersPayload == Data([1, 2, 3]))
        #expect(pinnedSave.voyage == reloaded.voyage)
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
        let encounter = EncounterIdentity(location: .voyage(runID: run.id, nodeID: node.id), save: save)
        save.voyage.updateNode(runID: run.id, nodeID: node.id) { $0.mysteryEventID = event.id }
        var rng = SeededRandomNumberGenerator(seed: 19)
        let first = try MysteryOfferPersistence.prepare(
            event: event, encounter: encounter, save: &save, using: &rng,
        )
        #expect(first.count == 2)
        try SaveTestSupport.writeRoot(save, to: context.storeURL())
        let store = try context.makeSaveStore()
        var reopened: [MysteryOffer] = []
        #expect(store.persistFixtureBatch(logging: "Reopen Voyage mystery") { candidate in
            do {
                reopened = try MysteryOfferPersistence.prepare(
                    event: event, encounter: encounter, save: &candidate, using: &rng,
                )
            } catch { Issue.record("Voyage mystery failed to reopen: \(error)") }
        })
        #expect(reopened == first)
        let offered = try #require(first.first)
        let before = store.currentSave
        var result = MysteryEffectResult()
        #expect(store.persistFixtureBatch(logging: "Claim Voyage mystery") { candidate in
            result = MysteryOfferPersistence.claim(offered, encounter: encounter, save: &candidate)
        })
        #expect(result.grantedItems == [offered.item])
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage.activeRun?.node(id: node.id)?.isCleared == true)
        #expect(reloaded.voyage.activeRun?.earnedGold == before.voyage.activeRun?.earnedGold)
        #expect(reloaded.voyage.activeRun?.earnedMaterials == before.voyage.activeRun?.earnedMaterials)
        #expect(reloaded.journey == before.journey)
        var claimed = reloaded.currentSave
        let duplicate = MysteryOfferPersistence.claim(offered, encounter: encounter, save: &claimed)
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
        #expect(store.persistFixtureBatch(logging: "Preserve unreadable Voyage") { $0.voyage.refresh(access: .free) })
        #expect(try context.makeReloadedStore().voyage.encodedPayload == unreadable)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(CloudSaveSnapshot(saved))) as? [String: Any])
        json.removeValue(forKey: "voyagePayload")
        let old = try JSONDecoder().decode(CloudSaveSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(try old.restored().voyage == .freshStart)
    }
}
