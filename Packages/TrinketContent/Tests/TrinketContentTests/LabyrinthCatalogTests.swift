import Foundation
import Testing
import TrinketContent
import TrinketCore

@Suite("LabyrinthCatalog")
struct LabyrinthCatalogTests {
    @Test func biomesAndModifiersAreAuthoredWithPlayerFacingContent() {
        #expect(!GameContent.labyrinthBiomes.isEmpty)
        for biome in GameContent.labyrinthBiomes {
            #expect(!biome.enemyPool.isEmpty)
            for enemyID in biome.enemyPool {
                #expect(GameContent.enemy(matching: enemyID) != nil)
            }
            #expect(GameContent.enemy(matching: biome.bossEnemyID) != nil)
        }

        #expect(!GameContent.labyrinthModifiers.isEmpty)
        for modifier in GameContent.labyrinthModifiers {
            #expect(!modifier.title.isEmpty)
            #expect(modifier.title.split(separator: " ").count <= 2)
            #expect(!modifier.effect.description.isEmpty)
        }
    }

    @Test func generatorIsDeterministicForSeed() {
        let first = LabyrinthGenerator.makeInitialMap(seed: 42)
        let second = LabyrinthGenerator.makeInitialMap(seed: 42)
        #expect(first.clusters.map(\.id) == second.clusters.map(\.id))
        #expect(first.nodes.keys.sorted() == second.nodes.keys.sorted())
        for id in first.nodes.keys {
            #expect(first.nodes[id] == second.nodes[id])
        }
    }

    @Test func initialMapHasReachableEntryFromEntrance() {
        let generated = LabyrinthGenerator.makeInitialMap(seed: 7)
        let entrance = generated.nodes[LabyrinthGenerator.entranceNodeID]
        #expect(entrance?.isCleared == true)
        #expect(!(entrance?.outgoingIDs.isEmpty ?? true))
        for outgoing in entrance?.outgoingIDs ?? [] {
            #expect(generated.nodes[outgoing]?.isRevealed == true)
        }
    }

    @Test func expandBeyondBossAppendsNextFloor() {
        let generated = LabyrinthGenerator.makeInitialMap(seed: 11)
        var clusters = generated.clusters
        var nodes = generated.nodes
        guard let firstBoss = nodes.values.first(where: { $0.type == .boss && $0.depth == 1 }) else {
            Issue.record("Expected a floor-1 boss")
            return
        }
        var boss = firstBoss
        boss.isCleared = true
        nodes[boss.id] = boss
        LabyrinthGenerator.expandBeyondBoss(
            bossNodeID: boss.id,
            clusters: &clusters,
            nodes: &nodes,
            seed: 11
        )
        #expect(clusters.contains { $0.depthBand == 2 })
        #expect(!(nodes[boss.id]?.outgoingIDs.isEmpty ?? true))
    }

    @Test func modifierEffectsCombineDamageAndBiomeLootBias() throws {
        let iron = try #require(GameContent.labyrinthModifier(id: LabyrinthModifierID("ironPressure")))
        let effects = LabyrinthModifierEffects.combining([iron], biomeBias: .physical)
        #expect(effects.damageDealtBonus == [.physical: 1])
        #expect(effects.goldPercent == 0)
        #expect(effects.keywordBiases.contains(.physical))
    }

    @Test func generatorDoesNotEmitEventNodes() {
        for seed in [1, 7, 42, 99, 1001] as [UInt64] {
            let generated = LabyrinthGenerator.makeInitialMap(seed: seed)
            #expect(generated.nodes.values.allSatisfy { $0.type != .event })
        }
    }

    @Test func eventTypeCanonicalizesToMystery() {
        #expect(LabyrinthNodeType.event.canonical == .mystery)
        #expect(LabyrinthNodeType.event.title == "Mystery")
        #expect(LabyrinthNodeType.event.primaryActionTitle == "Approach")
    }

    @Test func legacyEliteNodeTypeDecodesAsBattle() throws {
        let legacy = try JSONDecoder().decode(
            LabyrinthNodeType.self,
            from: Data(#""elite""#.utf8)
        )
        #expect(legacy == .battle)

        let encoded = try JSONEncoder().encode(legacy)
        #expect(String(data: encoded, encoding: .utf8) == #""battle""#)
    }

    @Test func modifierCatalogContainsOnlyApprovedDefinitions() {
        #expect(Set(GameContent.labyrinthModifiers.map(\.id.rawValue)) == [
            "ironPressure", "ashTithe", "bloodMarket", "gildedWhisper",
            "astralSeam", "serpentBloom", "rimeTax"
        ])
        #expect(Dictionary(uniqueKeysWithValues: GameContent.labyrinthModifiers.map { modifier in
            (modifier.title, modifier.effect.description)
        }) == [
            "Iron Pressure": "Physical damage is increased by 1.",
            "Ash Tithe": "Burn damage is increased by 1.",
            "Blood Market": "Bleed damage is increased by 1.",
            "Gilded Whisper": "Increases Gold rewards by 10%.",
            "Astral Seam": "Increases chance to find Astral items by 25%.",
            "Serpent Bloom": "Poison damage is increased by 1.",
            "Rime Tax": "Freeze damage is increased by 1."
        ])
    }

    @Test func floorShapeStaysWithinPlanBounds() {
        for seed in 0 ..< 40 {
            let generated = LabyrinthGenerator.makeInitialMap(seed: UInt64(seed))
            for cluster in generated.clusters where cluster.depthBand > 0 {
                let nodes = cluster.nodeIDs.compactMap { generated.nodes[$0] }
                #expect(nodes.count >= 7)
                #expect(nodes.count <= 9)
                #expect(nodes.filter { $0.type == .boss }.count == 1)
                #expect(nodes.first?.type == .battle)
                #expect(nodes.last?.type == .boss)
                #expect(!nodes.contains { !$0.isRevealed })
                #expect(nodes.allSatisfy { $0.modifierIDs.count <= 1 })
                #expect(nodes.last?.modifierIDs.count == 1)
                #expect(nodes.last?.gridPosition == LabyrinthGridPosition(row: 4, column: -2))
                #expect(nodes.filter { !$0.type.isCombat }.count >= 2)
                #expect(Set(nodes.compactMap(\.gridPosition?.row)) == Set(0 ... 4))
                var reached = Set(nodes.prefix(1).map(\.id))
                var frontier = Array(reached)
                var incomingCounts: [String: Int] = [:]
                for node in nodes {
                    let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
                    #expect(modifiers.allSatisfy { $0.applies(to: node.type) })
                    let expectsModifier = node.type.isCombat || node.type == .shop || node.type == .craft
                    #expect(node.modifierIDs.count == (expectsModifier ? 1 : 0))
                    for outgoingID in node.outgoingIDs {
                        let target = generated.nodes[outgoingID]
                        #expect(target?.gridPosition?.row == (node.gridPosition?.row ?? -1) + 1)
                        #expect(
                            target?.gridPosition?.column == node.gridPosition?.column
                                || target?.gridPosition?.column == (node.gridPosition?.column ?? 0) - 1
                        )
                        incomingCounts[outgoingID, default: 0] += 1
                    }
                }
                while let id = frontier.popLast() {
                    for outgoingID in generated.nodes[id]?.outgoingIDs ?? [] where reached.insert(outgoingID).inserted {
                        frontier.append(outgoingID)
                    }
                }
                #expect(reached == Set(nodes.map(\.id)))
                #expect(nodes.contains { $0.outgoingIDs.count > 1 })
                #expect(incomingCounts.values.contains { $0 > 1 })
            }
        }
    }

    @Test func recruitNodesRequireEligibleEvent() {
        let withoutRecruit = LabyrinthGenerator.makeInitialMap(seed: 14)
        #expect(withoutRecruit.nodes.values.allSatisfy { $0.type != .recruit })

        var foundRecruit = false
        for seed in 0 ..< 40 {
            let withRecruit = LabyrinthGenerator.makeInitialMap(
                seed: UInt64(seed),
                eligibleRecruitEventIDs: ["recruit-test-event"]
            )
            for node in withRecruit.nodes.values where node.type == .recruit {
                foundRecruit = true
                #expect(node.recruitEventID == "recruit-test-event")
            }
        }
        #expect(foundRecruit)
    }
}
