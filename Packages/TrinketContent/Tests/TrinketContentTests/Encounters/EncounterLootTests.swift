import Testing
import TrinketContent
import TrinketCore

struct EncounterLootTests {
    @Test(arguments: [RewardModifier.keyword(.freeze), .wood, .gold, .unique, .trinketHoard, .uniqueHoard])
    func `all battle modes apply shared reward modifiers`(modifier: RewardModifier) throws {
        // Exhausted collectibles must become Gold through every mode's loot path.
        let ownership = RewardOwnership(
            ownedTrinketIDs: Set(GameContent.trinketItems.map(\.templateID)),
            ownedUniqueIDs: Set(GameContent.uniqueItems.map(\.templateID)),
        )
        for loot in try modeLoot(modifier: modifier, ownership: ownership) {
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
        let ownership = RewardOwnership()
        for loot in try modeLoot(modifier: modifier, ownership: ownership) {
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

    @Test func `spire keyword reward guarantees matching gear and retains keyword bias`() throws {
        for spire in GameContent.spires {
            let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
            let seed = try #require((0 ..< 128).map(UInt64.init).first { candidate in
                GameContent.spireModifier(for: floor, worldSeed: candidate)?.effect == .reward(.keyword(spire.keyword))
            })
            let selected = try #require(GameContent.spireModifier(for: floor, worldSeed: seed))
            let request = LootRequest.spire(floor: floor, rewardModifier: .keyword(spire.keyword))
            #expect(request.keywordBias == [spire.keyword])
            #expect(request.rewardModifier == .keyword(spire.keyword))

            let loot = BattleLootContext(worldSeed: seed).spire(for: floor)
            #expect(loot == BattleLootContext(worldSeed: seed).spire(for: floor, modifier: selected))
            let item = try #require(loot.item)
            #expect(item.baseType.keywordAffinities.contains(spire.keyword))
            #expect(item.affixes.contains { $0.keywords.contains(spire.keyword) })
        }
    }

    @Test func `battle item roll uses encountered level and sanctum through settlement preparation`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-10"))
        let request = LootRequest.journey(stage: stage)
        for seed in UInt64(1) ... 16 {
            let actual = BattleLootContext(worldSeed: seed, astralChanceBonusPercent: 20).journey(
                for: stage,
                encounterLevel: 3,
                enemyIsBoss: true,
            )
            let expected = BattleLoot.resolve(
                request, encounterLevel: 3, enemyIsBoss: true, worldSeed: seed,
                ownership: RewardOwnership(), astralChanceBonusPercent: 20,
            )
            #expect(actual == expected)
        }
    }

    @Test func `combat loot resolves at provided encounter level instead of node depth`() throws {
        let node = LabyrinthNode(
            id: "level-override-node",
            type: .battle,
            enemyID: "goblin",
            depth: 2,
            clusterID: "labyrinth-test",
        )
        let atDepth = try #require(
            BattleLootContext(worldSeed: 5).labyrinth(for: node, effects: .zero),
        )
        let explicit = try #require(
            BattleLootContext(worldSeed: 5).labyrinth(for: node, effects: .zero, encounterLevel: 2),
        )
        #expect(explicit.gold == atDepth.gold)
        #expect(explicit.materials == atDepth.materials)

        let raised = try #require(
            BattleLootContext(worldSeed: 5).labyrinth(for: node, effects: .zero, encounterLevel: 40),
        )
        for (boosted, base) in zip(raised.materials, atDepth.materials) {
            #expect(boosted.resource == base.resource)
            #expect(boosted.quantity > base.quantity)
        }
        #expect(raised.gold > atDepth.gold)
    }

    @Test func `labyrinth boss node retains boss loot scaling for non-standard enemy`() throws {
        let nonBossEnemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let bossNode = LabyrinthNode(
            id: "same-node",
            type: .boss,
            enemyID: nonBossEnemy.id,
            depth: 5,
            clusterID: "cluster",
        )
        let battleNode = LabyrinthNode(
            id: "same-node",
            type: .battle,
            enemyID: nonBossEnemy.id,
            depth: 5,
            clusterID: "cluster",
        )
        let bossLoot = try #require(BattleLootContext(worldSeed: 42).labyrinth(for: bossNode, effects: .zero, encounterLevel: 10))
        let battleLoot = try #require(BattleLootContext(worldSeed: 42).labyrinth(for: battleNode, effects: .zero, encounterLevel: 10))
        #expect(bossLoot.gold == 2 * battleLoot.gold)
    }

    private func modeLoot(modifier: RewardModifier, ownership: RewardOwnership) throws -> [BattleLootResult] {
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let ids = [NodeModifierCatalog.rewardID(modifier)]
        let node = LabyrinthNode(id: "mode-node", type: .battle, enemyID: enemy.id, depth: 10, clusterID: "cluster", modifierIDs: ids)
        let voyage = VoyageNode(id: node.id, type: .battle, enemyID: enemy.id, modifierIDs: ids, recruitEventID: nil)
        let offer = ContractOffer(id: node.id, difficulty: .standard, enemyID: enemy.id, rewardModifier: modifier)
        let effects = NodeModifierEffects.combining(NodeModifierCatalog.modifiers(ids: ids))
        let context = BattleLootContext(worldSeed: 0x5445_5354, ownership: ownership)
        return try [
            #require(context.labyrinth(for: node, effects: effects)),
            context.voyage(node: voyage, encounterLevel: 10),
            context.contract(for: offer, encounterLevel: 10),
        ]
    }
}
