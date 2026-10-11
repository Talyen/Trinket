import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleLootTests {
    @Test(arguments: [RewardModifier.keyword(.freeze), .wood, .gold, .unique, .trinketHoard, .uniqueHoard])
    func `all battle modes apply shared reward modifiers`(modifier: RewardModifier) throws {
        var save = SaveTestSupport.makeSave()
        // Exhausted collectibles must become Gold through every mode's loot path.
        save.inventory = PlayerInventoryState(items: GameContent.trinketItems + GameContent.uniqueItems)
        for loot in try modeLoot(modifier: modifier, save: save) {
            #expect(loot.materials.count == 2)
            #expect(Set(loot.materials.map(\.resource)).count == 2)
            if let keyword = modifier.requiredKeyword {
                #expect(loot.item.baseType.keywordAffinities.contains(keyword))
                #expect(loot.item.affixes.contains { $0.keywords.contains(keyword) })
                #expect(loot.item.rarity != .unique && !loot.item.isTrinket)
            } else if modifier == .wood {
                #expect(loot.materials.first?.resource == .wood)
            } else {
                let range = BattleLoot.quantityRange(forLevel: 10)
                let boosted = CombatRounding.scaled(range.lowerBound, byPercent: 25) ... CombatRounding.scaled(
                    range.upperBound,
                    byPercent: 25,
                )
                #expect(boosted.contains(loot.gold))
            }
        }
    }

    @Test(arguments: [
        RewardModifier.armsHoard, .armorHoard, .ringHoard, .amuletHoard,
        .astralHoard, .trinketHoard, .uniqueHoard,
    ])
    func `hoards guarantee their advertised item across all battle modes`(modifier: RewardModifier) throws {
        let save = SaveTestSupport.makeSave()
        for loot in try modeLoot(modifier: modifier, save: save) {
            switch modifier {
            case .armsHoard, .armorHoard, .ringHoard, .amuletHoard:
                #expect(modifier.requiredBaseTypeIDs?.contains(loot.item.baseType.id) == true)
                #expect(loot.item.rarity == .basic || loot.item.rarity == .astral)
            case .astralHoard:
                #expect(loot.item.rarity == .astral)
            case .trinketHoard:
                #expect(loot.item.isTrinket)
            case .uniqueHoard:
                #expect(loot.item.rarity == .unique)
            default:
                Issue.record("Unexpected modifier")
            }
        }
    }

    @Test func `noncombat offer quality follows won encounters across modes`() {
        let node = LabyrinthNode(id: "deep", type: .mystery, depth: 17, clusterID: "cluster")
        var save = SaveTestSupport.makeSave()
        save.labyrinth.nodes[node.id] = node
        for stageID in ["chapter-4-stage-4", "chapter-4-stage-8"] {
            let encounter = EncounterIdentity(location: .journey(stageID: stageID), save: save)
            #expect(encounter.rewardLevel(in: save) == 1)
        }
        let encounter = EncounterIdentity(location: .labyrinth(nodeID: node.id), save: save)
        #expect(encounter.rewardLevel(in: save) == 1)
        save.contracts.recordVictory(encounterLevel: 25)
        #expect(encounter.rewardLevel(in: save) == 25)
    }

    @Test func `spire keyword reward guarantees matching gear and retains keyword bias`() throws {
        for spire in GameContent.spires {
            let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 10))
            let seed = try #require((0 ..< 128).map(UInt64.init).first { candidate in
                GameContent.spireModifier(for: floor, worldSeed: candidate)?.effect == .reward(.keyword(spire.keyword))
            })
            let selected = try #require(GameContent.spireModifier(for: floor, worldSeed: seed))
            let request = LootRequest.spire(floor: floor, rewardModifier: .keyword(spire.keyword))
            #expect(request.keywordBias == [spire.keyword])
            #expect(request.rewardModifier == .keyword(spire.keyword))

            let loot = SpireCompletion.resolveLoot(for: floor, worldSeed: seed)
            #expect(loot == SpireCompletion.resolveLoot(for: floor, worldSeed: seed, modifier: selected))
            let item = try #require(loot.item)
            #expect(item.baseType.keywordAffinities.contains(spire.keyword))
            #expect(item.affixes.contains { $0.keywords.contains(spire.keyword) })
        }
    }

    @Test func `battle item roll uses encountered level and sanctum through settlement preparation`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-10"))
        let request = LootRequest.journey(stage: stage)
        for seed in UInt64(1) ... 16 {
            let actual = StageCompletion.resolveLoot(
                for: stage, encounterLevel: 3, enemyIsBoss: true, worldSeed: seed, astralChanceBonusPercent: 20,
            )
            let expected = BattleLoot.resolve(
                request, encounterLevel: 3, enemyIsBoss: true, worldSeed: seed,
                ownership: RewardOwnership(), astralChanceBonusPercent: 20,
            )
            #expect(actual == expected)
        }
    }

    @Test func `a won Contract uses its own encounter level for item quality`() throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard(eligibleModifiers: [.gold])
        let offer = try #require(save.contracts.offer(for: .standard))
        #expect(CampaignRewardLevel.resolve(in: save) == 1)
        let actual = ContractsCompletion.resolveLoot(for: offer, encounterLevel: 20, save: save)
        let expected = BattleLoot.resolve(
            .contract(offerID: offer.id), encounterLevel: 20, enemyIsBoss: false,
            worldSeed: save.worldSeed, ownership: RewardOwnership(save),
        )
        #expect(actual == expected)
    }

    @Test func `authored astral rewards remain the requested template`() throws {
        let template = try #require(GameContent.itemTemplate(matching: "longsword-astral"))
        let stage = Stage(
            id: "authored-loot", chapterID: "chapter-1", chapterNumber: 1, stageNumber: 1,
            encounter: .mysteryEvent(eventID: ""),
            rewards: StageReward(gold: 0, itemTemplateIDs: [template.templateID]),
        )
        for seed in UInt64(1) ... 8 {
            var save = SaveTestSupport.makeSave(worldSeed: seed)
            let before = save.inventory.items.count
            StageCompletion.claimRewardsIfNeeded(
                for: stage, hero: save.roster.activeHero, companion: save.roster.activeCompanion, save: &save,
                recordReceipt: { _ in },
            )
            #expect(save.inventory.items.count == before + 1)
            #expect(save.inventory.items.last?.templateID == template.templateID)
            #expect(save.inventory.items.last?.isTrinket == false)
        }
    }

    @Test func `duplicate headline item converts to consolation gold`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        var save = SaveTestSupport.makeSave()
        let trinket = try #require(GameContent.trinketItems.first)
        save.inventory.appendUniqueItem(trinket)
        let goldBefore = save.roster.gold

        VictoryRewardApplier.grantVictoryRewards(
            party: (hero, companion),
            encounterLevel: 10,
            stageGold: 0,
            materialRewards: [],
            item: trinket,
            save: &save,
            recordReceipt: { _ in },
        )

        let range = BattleLoot.quantityRange(forLevel: 10)
        #expect(save.roster.gold - goldBefore == (range.lowerBound + range.upperBound) / 2)
        #expect(save.inventory.items.count(where: { $0.templateID == trinket.templateID }) == 1)
    }

    private func modeLoot(modifier: RewardModifier, save: PlayerSave) throws -> [BattleLootResult] {
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let ids = [NodeModifierCatalog.rewardID(modifier)]
        let node = LabyrinthNode(id: "mode-node", type: .battle, enemyID: enemy.id, depth: 10, clusterID: "cluster", modifierIDs: ids)
        let voyage = VoyageNode(id: node.id, type: .battle, enemyID: enemy.id, modifierIDs: ids, recruitEventID: nil)
        let offer = ContractOffer(id: node.id, difficulty: .standard, enemyID: enemy.id, rewardModifier: modifier)
        let effects = NodeModifierEffects.combining(NodeModifierCatalog.modifiers(ids: ids))
        return try [
            #require(LabyrinthCompletion.resolveCombatLoot(
                for: node, effects: effects, worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs, ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            )),
            VoyageCompletion.resolveLoot(node: voyage, encounterLevel: 10, save: save),
            ContractsCompletion.resolveLoot(for: offer, encounterLevel: 10, save: save),
        ]
    }
}
