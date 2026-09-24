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
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let ids = [LabyrinthCatalog.rewardID(modifier)]
        let node = LabyrinthNode(id: "reward-node", type: .battle, enemyID: enemy.id, depth: 10, clusterID: "cluster", modifierIDs: ids)
        let voyage = VoyageNode(id: node.id, type: .battle, enemyID: enemy.id, modifierIDs: ids, recruitEventID: nil)
        let offer = ContractOffer(id: node.id, difficulty: .standard, enemyID: enemy.id, rewardModifier: modifier)
        let effects = LabyrinthModifierEffects.combining(LabyrinthCatalog.modifiers(ids: ids))
        let labyrinthLoot = try #require(LabyrinthCompletion.resolveCombatLoot(
            for: node, effects: effects, worldSeed: save.worldSeed,
            ownedTrinketIDs: save.inventory.ownedTrinketIDs, ownedUniqueIDs: save.inventory.ownedUniqueIDs,
        ))
        let packages = [
            labyrinthLoot,
            VoyageCompletion.resolveLoot(node: voyage, encounterLevel: 10, save: save),
            ContractsCompletion.resolveLoot(for: offer, encounterLevel: 10, save: save),
        ]
        for loot in packages {
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
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let ids = [LabyrinthCatalog.rewardID(modifier)]
        let node = LabyrinthNode(id: "hoard-node", type: .battle, enemyID: enemy.id, depth: 10, clusterID: "cluster", modifierIDs: ids)
        let voyage = VoyageNode(id: node.id, type: .battle, enemyID: enemy.id, modifierIDs: ids, recruitEventID: nil)
        let offer = ContractOffer(id: node.id, difficulty: .standard, enemyID: enemy.id, rewardModifier: modifier)
        let effects = LabyrinthModifierEffects.combining(LabyrinthCatalog.modifiers(ids: ids))
        let labyrinth = try #require(LabyrinthCompletion.resolveCombatLoot(
            for: node, effects: effects, worldSeed: save.worldSeed,
            ownedTrinketIDs: [], ownedUniqueIDs: [],
        ))
        for loot in [
            labyrinth,
            VoyageCompletion.resolveLoot(node: voyage, encounterLevel: 10, save: save),
            ContractsCompletion.resolveLoot(for: offer, encounterLevel: 10, save: save),
        ] {
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

    @Test(arguments: BattleLoot.materialResources, [false, true])
    func `focused materials guarantee one boosted slot and a distinct ordinary slot`(resource: HomesteadResource, boss: Bool) throws {
        func resolve(bonus: Int) -> BattleLootResult {
            var rng = SeededRandomNumberGenerator(seed: 42)
            return BattleLoot.resolve(
                encounterLevel: 20, rewardLevel: 20, enemyIsBoss: boss, itemID: "focused",
                ownedUniqueIDs: [], materialsFoundPercent: bonus, materialFocus: resource, using: &rng,
            )
        }
        let base = resolve(bonus: 0)
        let boosted = resolve(bonus: 25)
        #expect(boosted.materials.count == 2)
        #expect(Set(boosted.materials.map(\.resource)).count == 2)
        let focused = try #require(boosted.materials.first)
        #expect(focused.resource == resource)
        #expect(focused.quantity == CombatRounding.scaled(base.materials[0].quantity, byPercent: 25))
        #expect(boosted.materials[1] == base.materials[1])
        #expect(boosted.gold == base.gold)
        #expect(boosted.item == base.item)
    }

    @Test func `gold and general material bonuses leave other rewards unchanged`() {
        func resolve(gold: Int = 0, materials: Int = 0) -> BattleLootResult {
            var rng = SeededRandomNumberGenerator(seed: 42)
            return BattleLoot.resolve(
                encounterLevel: 20, rewardLevel: 20, enemyIsBoss: true, itemID: "bonus",
                ownedUniqueIDs: [], goldFoundPercent: gold, materialsFoundPercent: materials, using: &rng,
            )
        }
        let base = resolve()
        let gold = resolve(gold: 25)
        let materials = resolve(materials: 25)
        #expect(gold.gold == CombatRounding.scaled(base.gold, byPercent: 25))
        #expect(gold.materials == base.materials && gold.item == base.item)
        #expect(materials.materials == base.materials.map {
            ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: 25))
        })
        #expect(materials.gold == base.gold && materials.item == base.item)
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

    @Test func `noncombat offer quality follows won encounters across modes`() throws {
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
            #expect(encounter.rewardLevel(in: save) == 1)
        }
        let encounter = EncounterIdentity(location: .labyrinth(nodeID: node.id), save: save)
        #expect(encounter.rewardLevel(in: save) == 1)
        save.contracts.recordVictory(encounterLevel: 25)
        #expect(encounter.rewardLevel(in: save) == 25)
    }

    @Test func `battle item roll uses encountered level and sanctum through settlement preparation`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-10"))
        let request = LootRequest.journey(stage: stage)
        for seed in UInt64(1) ... 16 {
            let actual = StageCompletion.resolveLoot(
                for: stage, encounterLevel: 3, enemyIsBoss: true, worldSeed: seed, astralChanceBonusPercent: 20,
            )
            var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(seed, salt: request.seedSalt))
            let expected = BattleLoot.resolve(
                encounterLevel: 3, rewardLevel: 3, enemyIsBoss: true, itemID: request.itemID,
                ownedUniqueIDs: [], astralChanceBonusPercent: 20, using: &rng,
            )
            #expect(actual == expected)
        }
    }

    @Test func `a won Contract uses its own encounter level for item quality`() throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard(eligibleModifiers: [.gold])
        let offer = try #require(save.contracts.offer(for: .standard))
        #expect(ContractsCompletion.campaignRewardLevel(in: save) == 1)
        let actual = ContractsCompletion.resolveLoot(for: offer, encounterLevel: 20, save: save)
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(save.worldSeed, salt: "battle-loot-contract-\(offer.id)"),
        )
        let expected = BattleLoot.resolve(
            encounterLevel: 20, rewardLevel: 20, enemyIsBoss: false,
            itemID: "contract-\(offer.id)-loot",
            ownedTrinketIDs: save.inventory.ownedTrinketIDs, ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            goldFoundPercent: 25, using: &rng,
        )
        #expect(actual == expected)

        for stage in GameContent.chapters[0].stages {
            save.journey.complete(stage, in: GameContent.chapters)
        }
        #expect(ContractsCompletion.campaignRewardLevel(in: save) > 1)
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

    @Test func `duplicate headline item converts to consolation gold`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        var save = SaveTestSupport.makeSave()
        let trinket = try #require(GameContent.trinketItems.first)
        save.inventory.appendUniqueItem(trinket)
        let goldBefore = save.roster.gold

        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: 10,
            stageGold: 0,
            materialRewards: [],
            item: trinket,
            save: &save,
        )

        let range = BattleLoot.quantityRange(forLevel: 10)
        #expect(save.roster.gold - goldBefore == (range.lowerBound + range.upperBound) / 2)
        #expect(save.inventory.items.count(where: { $0.templateID == trinket.templateID }) == 1)
    }
}
