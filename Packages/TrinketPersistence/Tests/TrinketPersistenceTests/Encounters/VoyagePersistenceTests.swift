import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct VoyagePersistenceTests {
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
                runID: run.id, nodeID: battle.id, hero: hero, companion: companion,
                rewards: (settled: settled, earned: earned, encounterLevel: 12), save: &save, access: .free,
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

    @Test func `final destination and node Gold bonuses add on the boss reward`() {
        let save = SaveTestSupport.makeSave()
        let offer = VoyageOffer(id: "gold-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .gold)
        let plain = VoyageNode(id: "gold-boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        var marked = plain
        marked.modifierIDs = [NodeModifierCatalog.rewardID(.gold)]
        let baseline = VoyageCompletion.resolveLoot(node: plain, encounterLevel: 10, save: save)
        let enhanced = VoyageCompletion.resolveFinalLoot(node: marked, offer: offer, encounterLevel: 10, save: save)
        #expect(enhanced.primary.gold == CombatRounding.scaled(baseline.gold, byPercent: 50))
        #expect(enhanced.additionalItem == nil)
        #expect(enhanced.primary.materials == baseline.materials)
    }

    @Test func `two material focuses fill both boss slots`() {
        let save = SaveTestSupport.makeSave()
        let offer = VoyageOffer(id: "material-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .stone)
        let node = VoyageNode(
            id: "material-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.wood)], recruitEventID: nil,
        )
        let loot = VoyageCompletion.resolveFinalLoot(node: node, offer: offer, encounterLevel: 10, save: save)
        #expect(Set(loot.primary.materials.map(\.resource)) == [.wood, .stone])
        let raw = BattleLoot.quantityRange(forLevel: 10)
        let possible = Set(raw.map { CombatRounding.scaled($0 * 2, byPercent: RewardModifier.bonusPercent) })
        #expect(loot.primary.materials.allSatisfy { possible.contains($0.quantity) })
    }

    @Test func `two item modifiers make deterministic independent boss rolls`() throws {
        let save = SaveTestSupport.makeSave()
        let offer = VoyageOffer(id: "item-run", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .armorHoard)
        let node = VoyageNode(
            id: "item-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.armsHoard)], recruitEventID: nil,
        )
        let first = VoyageCompletion.resolveFinalLoot(node: node, offer: offer, encounterLevel: 10, save: save)
        let second = VoyageCompletion.resolveFinalLoot(node: node, offer: offer, encounterLevel: 10, save: save)
        #expect(first.primary == second.primary)
        #expect(first.additionalItem == second.additionalItem)
        #expect(first.primary.item.baseType.slot == .weapon)
        #expect(try #require(first.additionalItem).baseType.slot == .armor)
        #expect(first.primary.item.id != first.additionalItem?.id)
    }

    @Test func `exhausted destination collectible resolves to Bonus Gold`() {
        var save = SaveTestSupport.makeSave()
        for item in GameContent.trinketItems {
            save.inventory.appendUniqueItem(item)
        }
        let offer = VoyageOffer(id: "exhausted", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .trinketHoard)
        let node = VoyageNode(id: "exhausted-boss", type: .boss, enemyID: "the_blight_treant", modifierIDs: [], recruitEventID: nil)
        let baseline = VoyageCompletion.resolveLoot(node: node, encounterLevel: 10, save: save)
        let final = VoyageCompletion.resolveFinalLoot(node: node, offer: offer, encounterLevel: 10, save: save)
        #expect(offer.rewardModifier.resolved(
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
        ) == .gold)
        #expect(final.primary.gold == CombatRounding.scaled(baseline.gold, byPercent: RewardModifier.bonusPercent))
        #expect(final.additionalItem == nil)
    }

    @Test func `second collectible roll converts to Gold when the first takes the last item`() throws {
        var save = SaveTestSupport.makeSave()
        let remaining = try #require(GameContent.uniqueItems.last)
        for item in GameContent.uniqueItems where item.templateID != remaining.templateID {
            save.inventory.appendUniqueItem(item)
        }
        let offer = VoyageOffer(id: "last-unique", chapterID: "chapter-1", difficulty: .easy, seed: 17, rewardModifier: .uniqueHoard)
        let node = VoyageNode(
            id: "last-unique-boss", type: .boss, enemyID: "the_blight_treant",
            modifierIDs: [NodeModifierCatalog.rewardID(.uniqueHoard)], recruitEventID: nil,
        )
        let ordinary = VoyageCompletion.resolveLoot(node: node, encounterLevel: 10, save: save)
        let final = VoyageCompletion.resolveFinalLoot(node: node, offer: offer, encounterLevel: 10, save: save)
        #expect(final.primary.item.templateID == remaining.templateID)
        #expect(final.additionalItem == nil)
        #expect(final.primary.gold == CombatRounding.scaled(ordinary.gold, byPercent: RewardModifier.bonusPercent))
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
        let mysteryNode = try #require(reloaded.voyage.activeRun?.nodes.first(where: { $0.type == .mystery }))
        #expect(reloaded.persistBatch(logging: "Voyage mystery pin") { save in
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
