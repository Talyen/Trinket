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

    @Test func `quantity range endpoints`() {
        #expect(BattleLoot.quantityRange(forLevel: Int.min) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 1) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 24) == 7 ... 13)
        #expect(BattleLoot.quantityRange(forLevel: 48) == 11 ... 23)
        #expect(BattleLoot.quantityRange(forLevel: 50) == 12 ... 24)
        #expect(BattleLoot.quantityRange(forLevel: Int.max / 20 + 1) == 84704437073156107 ... 188232082384791347)
        #expect(BattleLoot.quantityRange(forLevel: Int.max) == 1694088741463122090 ... 3764641647695826864)
    }

    @Test(arguments: [false, true])
    func `maximum encounter level loot retains valid quantities with boss and reward bonuses`(boss: Bool) {
        func resolve(bonus: Int) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(seedSalt: "maximum-level", itemID: "maximum-level", goldFoundPercent: bonus, materialsFoundPercent: bonus),
                encounterLevel: Int.max, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
            )
        }
        let base = resolve(bonus: 0)
        let boosted = resolve(bonus: RewardModifier.bonusPercent)
        let multiplier = boss ? 2 : 1
        let range = (1694088741463122090 * multiplier) ... (3764641647695826864 * multiplier)
        #expect(range.contains(base.gold))
        #expect(base.materials.count == 2)
        #expect(Set(base.materials.map(\.resource)).count == 2)
        #expect(base.materials.allSatisfy { range.contains($0.quantity) })
        #expect(boosted.gold == CombatRounding.scaled(base.gold, byPercent: RewardModifier.bonusPercent))
        #expect(boosted.materials == base.materials.map {
            ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: RewardModifier.bonusPercent))
        })
        #expect(boosted.item == base.item)
    }

    @Test(arguments: [false, true])
    func `ordinary and boss loot grants one item and two distinct material rewards`(boss: Bool) {
        let loot = BattleLoot.resolve(
            LootRequest(seedSalt: "test", itemID: "test-loot"),
            encounterLevel: 1, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
        )
        let range = boss ? 6 ... 8 : 3 ... 4
        #expect(loot.item.isTrinket || loot.item.rarity == .unique || loot.item.id == "test-loot")
        #expect(range.contains(loot.gold))
        #expect(loot.materials.count == 2)
        #expect(Set(loot.materials.map(\.resource)).count == 2)
        #expect(loot.materials.allSatisfy {
            BattleLoot.materialResources.contains($0.resource) && range.contains($0.quantity)
        })
    }

    @Test(arguments: BattleLoot.materialResources, [false, true])
    func `focused rewards retain general material bonuses on both distinct slots`(resource: HomesteadResource, boss: Bool) throws {
        let modifier = try #require(RewardModifier(rawValue: resource.rawValue))
        func resolve(bonus: Int) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(
                    seedSalt: "focused", itemID: "focused",
                    materialsFoundPercent: bonus - RewardModifier.bonusPercent, rewardModifier: modifier,
                ),
                encounterLevel: 20, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
            )
        }
        let unboostedFocus = resolve(bonus: 0)
        let base = resolve(bonus: RewardModifier.bonusPercent)
        let boosted = resolve(bonus: 2 * RewardModifier.bonusPercent)
        #expect(boosted.materials.count == 2)
        #expect(Set(boosted.materials.map(\.resource)).count == 2)
        let focused = try #require(boosted.materials.first)
        #expect(focused.resource == resource)
        #expect(focused.quantity == CombatRounding.scaled(unboostedFocus.materials[0].quantity, byPercent: 2 * RewardModifier.bonusPercent))
        #expect(boosted.materials[1].resource == base.materials[1].resource)
        #expect(boosted.materials[1].quantity == CombatRounding.scaled(
            base.materials[1].quantity,
            byPercent: RewardModifier.bonusPercent,
        ))
        #expect(boosted.gold == base.gold)
        #expect(boosted.item == base.item)
    }

    @Test func `gold and general material bonuses leave other rewards unchanged`() {
        func resolve(gold: Int = 0, materials: Int = 0) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(seedSalt: "bonus", itemID: "bonus", goldFoundPercent: gold, materialsFoundPercent: materials),
                encounterLevel: 20, enemyIsBoss: true, worldSeed: 42, ownership: RewardOwnership(),
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
        func resolve(seed: UInt64) -> BattleLootResult {
            BattleLoot.resolve(
                .journey(stage: stage), encounterLevel: 1, enemyIsBoss: false,
                worldSeed: seed, ownership: RewardOwnership(),
            )
        }
        let first = resolve(seed: 8)
        #expect(first == resolve(seed: 8))
        #expect(first != resolve(seed: 9))
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
