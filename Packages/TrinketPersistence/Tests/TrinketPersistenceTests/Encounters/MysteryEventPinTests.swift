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
        let nodeID = try reachableMysteryNodeID(in: store, enabled: inLabyrinth)
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
        #expect(result.grantedMaterials == [ResourceAmount(.gems, offered[0].bonus.amount)])
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

    #if DEBUG
    @Test @MainActor func `failed Mystery claim preserves saved offers and retry survives reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore(resetState: true)
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        var save = store.currentSave
        save.roster.gold = 0
        save.homestead.pendingProduction = [:]
        var rng = SeededRandomNumberGenerator(seed: 3)
        let offers = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        )
        save.roster.gold = PlayerRosterState.maxGoldBalance
        #expect(store.persistBatch(logging: "Seed stale mystery offer") { $0 = save })
        let before = store.currentSave
        let request = MysteryEncounterRequest(
            encounter: EncounterIdentity(location: .journey(stageID: stage.id), save: before),
            stage: stage, event: event, displayedOffers: offers,
        )
        store.forcesNextSaveFailure = true
        let failed = store.persistTransaction(logging: "Refresh mystery offer") { candidate in
            MysteryEncounterResolution.resolve(choiceID: offers[0].choiceID, request: request, save: &candidate, using: &rng)
        }
        guard case .persistFailed = failed else {
            Issue.record("Expected failed refresh write")
            return
        }
        #expect(store.currentSave == before)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.currentSave == before)
        let retry = reloaded.persistTransaction(logging: "Retry mystery refresh") { candidate in
            MysteryEncounterResolution.resolve(choiceID: offers[0].choiceID, request: request, save: &candidate, using: &rng)
        }
        guard case let .committed(.reward(result)) = retry else {
            Issue.record("Expected the pinned offer to be granted on retry")
            return
        }
        #expect(result.grantedItems == [offers[0].item])
        #expect(reloaded.journey.completedStageIDs.contains(stage.id))
        let reopened = try context.makeReloadedStore()
        #expect(reopened.inventory.item(matching: offers[0].item.id) == offers[0].item)
    }
    #endif

    @MainActor
    private func reachableMysteryNodeID(in store: PlayerSaveStore, enabled: Bool) throws -> String? {
        guard enabled else { return nil }
        var labyrinth = store.labyrinth
        labyrinth.ensureMap(seed: store.worldSeed)
        let reachable = Set(labyrinth.reachableNodeIDs())
        if let mysteryID = labyrinth.nodes.values.filter({ $0.type == .mystery && reachable.contains($0.id) })
            .min(by: { $0.id < $1.id })?.id {
            #expect(store.persistBatch(logging: "Test setup") { $0.labyrinth = labyrinth })
            return mysteryID
        }
        let reachableID = try #require(reachable.min())
        let existing = try #require(labyrinth.nodes[reachableID])
        labyrinth.nodes[reachableID] = LabyrinthNode(
            id: existing.id,
            type: .mystery,
            enemyID: existing.enemyID,
            depth: existing.depth,
            clusterID: existing.clusterID,
            gridPosition: existing.gridPosition,
            modifierIDs: existing.modifierIDs,
            recruitEventID: existing.recruitEventID,
            outgoingIDs: existing.outgoingIDs,
            isCleared: false,
            isRevealed: true,
        )
        #expect(store.persistBatch(logging: "Test setup") { $0.labyrinth = labyrinth })
        return reachableID
    }

    @Test func `opened special reward stays pinned when acquired elsewhere`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-4"))
        let matchingSeed = (UInt64(1) ... 1000).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            let offer = MysteryEffectApplier.resolveOffer(
                choice: event.choices[0], encounterID: stage.id, encounterLevel: 16, rewardLevel: 16,
                save: SaveTestSupport.makeSave(), using: &rng,
            )
            return offer?.item.rarity == .unique
        }
        var rng = try SeededRandomNumberGenerator(seed: #require(matchingSeed))
        var save = SaveTestSupport.makeSave()
        save.contracts.recordVictory(encounterLevel: 16)
        let first = try MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng)
        #expect(first[0].item.templateID == "rimeheart_locket")
        save.inventory.appendUniqueItem(first[0].item)
        let next = try MysteryOfferPersistence.prepare(event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng)
        #expect(next[0] == first[0])
        #expect(next[1] == first[1])
        let result = MysteryOfferPersistence.claim(first[0], stage: stage, labyrinthNodeID: nil, save: &save)
        #expect(result.grantedItems.isEmpty)
        #expect(save.journey.completedStageIDs.contains(stage.id))
    }

    @Test func `gold wallets near cap receive fitting Gold and XP for overflow`() throws {
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
            #expect(result.grantedGold == max(0, PlayerRosterState.maxGoldBalance - gold))
            #expect(result.hasGrantedExperience)
        }
    }

    @Test func `a pinned split bonus converts only remaining Gold when the wallet fills`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        var save = SaveTestSupport.makeSave(gold: PlayerRosterState.maxGoldBalance - 1)
        var rng = SeededRandomNumberGenerator(seed: 3)
        let offer = try #require(MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        ).first)
        guard case let .goldAndExperience(gold, experience, nominalGold, fullOverflowExperience) = offer.bonus else {
            Issue.record("Expected a split Gold and XP offer")
            return
        }
        save.roster.gold = PlayerRosterState.maxGoldBalance
        let expectedExperience = RewardExperiencePolicy.sharedAward(
            SaturatedArithmetic.saturatingAdd(experience, RewardSettlementPolicy.overflowExperience(
                fullOverflowExperience, overflow: gold, gains: nominalGold,
            )), roster: save.roster,
        )
        let result = MysteryOfferPersistence.claim(offer, stage: stage, labyrinthNodeID: nil, save: &save)
        #expect(result.grantedGold == 0)
        #expect(result.heroGrantedExperience == expectedExperience)
        #expect(result.companionGrantedExperience == expectedExperience)
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

    @Test func `prepare skips non-pool choices in mixed events`() throws {
        let pool = MysteryItemPool(baseTypeID: "sapphire_amulet")
        let event = MysteryEvent(
            id: "mixed-test",
            title: "Mixed",
            narrative: "{A} or {B}",
            artID: nil,
            choices: [
                MysteryChoice(id: "take", label: "Take", effects: [.gainItem(pool), .gainGold(10)]),
                MysteryChoice(id: "walk-away", label: "Leave", effects: [.leave]),
            ],
        )
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        var save = SaveTestSupport.makeSave()
        var rng = SeededRandomNumberGenerator(seed: 7)
        let offers = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        )
        #expect(offers.count == 1)
        #expect(offers[0].choiceID == "take")
        var rng2 = SeededRandomNumberGenerator(seed: 7)
        #expect(MysteryEffectApplier.resolveOffer(
            choice: event.choices[1], encounterID: stage.id, encounterLevel: 1, rewardLevel: 1,
            save: save, using: &rng2,
        ) == nil)
    }

    @Test func `shown bonus remains claimable after wallet changes`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        var save = SaveTestSupport.makeSave(gold: 0)
        save.homestead.pendingProduction = [:]
        var rng = SeededRandomNumberGenerator(seed: 3)
        let offers = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        )
        let offer = try #require(offers.first)
        guard case .gold = offer.bonus else {
            Issue.record("Expected a receivable Gold offer")
            return
        }
        save.roster.gold = PlayerRosterState.maxGoldBalance
        let result = MysteryOfferPersistence.claim(offer, stage: stage, labyrinthNodeID: nil, save: &save)
        #expect(result.grantedItems == [offer.item])
        #expect(result.grantedGold == 0)
        #expect(result.hasGrantedExperience)
        #expect(save.journey.completedStageIDs.contains(stage.id))
    }

    @Test func `legacy raw XP snapshot is capped without rerolling its item`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        var save = SaveTestSupport.makeSave()
        var rng = SeededRandomNumberGenerator(seed: 3)
        let original = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        )
        let raw = original.map { MysteryOffer(choiceID: $0.choiceID, item: $0.item, bonus: .experience(10000)) }
        save.journey.mysteryOfferPayloads[stage.id] = try JSONEncoder().encode(MysteryOfferSnapshot(eventID: event.id, offers: raw))
        save.roster.progressions[save.roster.activeHeroID] = .at(level: 1)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 30)
        let revised = try MysteryOfferPersistence.prepare(
            event: event, stage: stage, labyrinthNodeID: nil, save: &save, using: &rng,
        )
        #expect(revised.map(\.item) == original.map(\.item))
        #expect(revised[0].bonus == .experience(10000))
        let result = MysteryOfferPersistence.claim(revised[0], stage: stage, labyrinthNodeID: nil, save: &save)
        #expect(result.heroGrantedExperience == 30)
        #expect(result.companionGrantedExperience == 30)
    }
}
