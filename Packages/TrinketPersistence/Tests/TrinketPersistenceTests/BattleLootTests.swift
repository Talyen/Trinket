import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleLootTests {
    @Test func `quantity range endpoints`() {
        #expect(BattleLoot.quantityRange(forLevel: 1) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 24) == 7 ... 13)
        #expect(BattleLoot.quantityRange(forLevel: 48) == 11 ... 23)
        #expect(BattleLoot.quantityRange(forLevel: 50) == 12 ... 24)
    }

    @Test func `resolve always grants one item two distinct materials and gold`() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        let package = BattleLoot.resolve(
            encounterLevel: 1,
            rewardLevel: 1,
            enemyIsBoss: false,
            itemID: "test-loot",
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            using: &rng,
        )
        let isCatalogIdentity = package.item.isTrinket || package.item.rarity == .unique
        #expect(isCatalogIdentity || package.item.id == "test-loot")
        if !isCatalogIdentity {
            #expect(package.item.rarity == .basic || package.item.rarity == .astral)
        }
        #expect((3 ... 4).contains(package.gold))
        #expect(package.materials.count == 2)
        #expect(Set(package.materials.map(\.resource)).count == 2)
        for material in package.materials {
            #expect(BattleLoot.materialResources.contains(material.resource))
            #expect((3 ... 4).contains(material.quantity))
        }
    }

    @Test func `boss doubles currency independently of item rarity`() {
        var rng = SeededRandomNumberGenerator(seed: 99)
        let package = BattleLoot.resolve(
            encounterLevel: 1,
            rewardLevel: 1,
            enemyIsBoss: true,
            itemID: "boss-loot",
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            using: &rng,
        )
        #expect((6 ... 8).contains(package.gold))
        for material in package.materials {
            #expect((6 ... 8).contains(material.quantity))
        }
    }

    @Test func `journey loot is seed stable`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let first = VictoryRewardApplier.resolveLoot(
            .journey(stage: stage),
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 8,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )
        let second = VictoryRewardApplier.resolveLoot(
            .journey(stage: stage),
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 8,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )
        #expect(first == second)

        let otherWorld = VictoryRewardApplier.resolveLoot(
            .journey(stage: stage),
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 9,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )
        #expect(first != otherWorld)
    }

    @Test func `reward level changes items without changing currency`() {
        var earlyPremium = 0
        var latePremium = 0
        for seed in UInt64(1) ... 100 {
            var earlyRNG = SeededRandomNumberGenerator(seed: seed)
            var lateRNG = SeededRandomNumberGenerator(seed: seed)
            let early = BattleLoot.resolve(
                encounterLevel: 5, rewardLevel: 1, enemyIsBoss: false, itemID: "loot",
                ownedUniqueIDs: [], using: &earlyRNG,
            )
            let late = BattleLoot.resolve(
                encounterLevel: 5, rewardLevel: 20, enemyIsBoss: false, itemID: "loot",
                ownedUniqueIDs: [], using: &lateRNG,
            )
            #expect(early.gold == late.gold)
            #expect(early.materials == late.materials)
            if early.item.rarity != .basic {
                earlyPremium += 1
            }
            if late.item.rarity != .basic {
                latePremium += 1
            }
        }
        #expect(latePremium > earlyPremium)
    }

    @Test func `reward levels follow content progression across modes`() throws {
        let battle = try #require(GameContent.stage(id: "chapter-4-stage-10"))
        #expect(LootRequest.journey(stage: battle).rewardLevel == 20)
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 6))
        #expect(LootRequest.spire(floor: floor).rewardLevel == 12)
        let node = LabyrinthNode(id: "deep", type: .mystery, depth: 17, clusterID: "cluster")
        #expect(LootRequest.labyrinth(node: node, effects: .zero).rewardLevel == 17)
        var save = SaveTestSupport.makeSave()
        save.labyrinth.nodes[node.id] = node
        for stageID in ["chapter-4-stage-4", "chapter-4-stage-8"] {
            let encounter = EncounterIdentity(location: .journey(stageID: stageID), save: save)
            #expect(encounter.rewardLevel(in: save) == 16)
        }
        let encounter = EncounterIdentity(location: .labyrinth(nodeID: node.id), save: save)
        #expect(encounter.rewardLevel(in: save) == 17)
    }

    @Test func `battle requests carry authored item level and sanctum through settlement preparation`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-10"))
        let request = LootRequest.journey(stage: stage)
        for seed in UInt64(1) ... 16 {
            let actual = StageCompletion.resolveLoot(
                for: stage, encounterLevel: 3, enemyIsBoss: true, worldSeed: seed, astralChanceBonusPercent: 20,
            )
            var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(seed, salt: request.seedSalt))
            let expected = BattleLoot.resolve(
                encounterLevel: 3, rewardLevel: 20, enemyIsBoss: true, itemID: request.itemID,
                ownedUniqueIDs: [], astralChanceBonusPercent: 20, using: &rng,
            )
            #expect(actual == expected)
        }
    }

    @Test func `contracts use the resolved encounter level for item rewards`() throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard()
        let offer = try #require(save.contracts.offer(for: .standard))
        let actual = ContractsCompletion.resolveLoot(for: offer, encounterLevel: 20, save: save)
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(save.worldSeed, salt: "battle-loot-contract-\(offer.id)"),
        )
        let expected = BattleLoot.resolve(
            encounterLevel: 20, rewardLevel: 20, enemyIsBoss: false,
            itemID: "contract-\(offer.id)-loot",
            ownedTrinketIDs: save.inventory.ownedTrinketIDs, ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            using: &rng,
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
            )
            #expect(save.inventory.items.count == before + 1)
            #expect(save.inventory.items.last?.templateID == template.templateID)
            #expect(save.inventory.items.last?.isTrinket == false)
        }
    }
}
