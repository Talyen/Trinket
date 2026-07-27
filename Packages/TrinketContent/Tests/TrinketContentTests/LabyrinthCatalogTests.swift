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

    @Test func expandBeyondBossAppendsNextFloor() throws {
        let generated = LabyrinthGenerator.makeInitialMap(seed: 11)
        var clusters = generated.clusters
        var nodes = generated.nodes
        let firstBoss = try #require(nodes.values.first(where: { $0.type == .boss && $0.depth == 1 }), "Expected a floor-1 boss")
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
            "astralSeam", "serpentBloom", "rimeTax",
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
            "Rime Tax": "Freeze damage is increased by 1.",
        ])
    }

    @Test func floorShapeStaysWithinPlanBounds() {
        var layoutSignatures = Set<String>()
        var observedCycleCounts = Set<Int>()

        for seed in 0 ..< 100 {
            let generated = LabyrinthGenerator.makeInitialMap(seed: UInt64(seed))
            for cluster in generated.clusters where cluster.depthBand > 0 {
                let nodes = cluster.nodeIDs.compactMap { generated.nodes[$0] }
                #expect(nodes.count >= 7)
                #expect(nodes.count <= 9)
                #expect(nodes.count(where: { $0.type == .boss }) == 1)
                #expect(nodes.first?.type == .battle)
                #expect(nodes.last?.type == .boss)
                #expect(!nodes.contains { !$0.isRevealed })
                #expect(nodes.allSatisfy { $0.modifierIDs.count <= 1 })
                #expect(nodes.last?.modifierIDs.count == 1)
                #expect(nodes.count(where: { !$0.type.isCombat }) >= 2)

                let geometry = validateGeometry(of: nodes)
                for node in nodes {
                    let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
                    #expect(modifiers.allSatisfy { $0.applies(to: node.type) })
                    let expectsModifier = node.type.isCombat || node.type == .shop || node.type == .craft
                    #expect(node.modifierIDs.count == (expectsModifier ? 1 : 0))
                    #expect(node.outgoingIDs.isEmpty)
                }
                observedCycleCounts.insert(geometry.cycleCount)
                layoutSignatures.insert(geometry.signature)
            }
        }

        #expect(layoutSignatures.count >= 10)
        #expect(observedCycleCounts == [0, 1])
    }

    private func validateGeometry(of nodes: [LabyrinthNode]) -> (signature: String, cycleCount: Int) {
        let positions = nodes.compactMap(\.gridPosition)
        #expect(positions.count == nodes.count)
        #expect(Set(positions).count == nodes.count)
        let rows = positions.map(\.row)
        let minimumRow = rows.min()
        let maximumRow = rows.max()
        #expect(minimumRow == 0)
        #expect(nodes.first?.gridPosition?.row == minimumRow)
        #expect(nodes.last?.gridPosition?.row == maximumRow)
        #expect(rows.count(where: { $0 == minimumRow }) == 1)
        #expect(rows.count(where: { $0 == maximumRow }) == 1)

        let projectedColumns = positions.map { 2 * $0.column + $0.row }
        #expect((projectedColumns.max() ?? 0) - (projectedColumns.min() ?? 0) <= 4)
        let neighborsByID = Dictionary(uniqueKeysWithValues: nodes.map { node in
            (node.id, nodes.filter { node.id != $0.id && areAdjacent(node, $0) }.map(\.id))
        })
        let degrees = nodes.map { neighborsByID[$0.id]?.count ?? 0 }
        #expect(degrees.allSatisfy { $0 <= 3 })
        #expect(degrees.first == 1)
        #expect(degrees.last == 1)
        #expect(degrees.contains(3))

        var reached = Set(nodes.prefix(1).map(\.id))
        var frontier = Array(reached)
        while let id = frontier.popLast() {
            for neighborID in neighborsByID[id] ?? [] where reached.insert(neighborID).inserted {
                frontier.append(neighborID)
            }
        }
        #expect(reached == Set(nodes.map(\.id)))
        let cycleCount = degrees.reduce(0, +) / 2 - nodes.count + 1
        #expect(cycleCount == 0 || cycleCount == 1)
        return (
            positions.map { "\($0.row):\($0.column)" }.joined(separator: "|"),
            cycleCount
        )
    }

    private func areAdjacent(_ source: LabyrinthNode, _ target: LabyrinthNode) -> Bool {
        guard let sourcePosition = source.gridPosition,
              let targetPosition = target.gridPosition
        else { return false }
        let rowDelta = targetPosition.row - sourcePosition.row
        let columnDelta = targetPosition.column - sourcePosition.column
        return (rowDelta == 0 && abs(columnDelta) == 1)
            || (rowDelta == 1 && (columnDelta == 0 || columnDelta == -1))
            || (rowDelta == -1 && (columnDelta == 0 || columnDelta == 1))
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
