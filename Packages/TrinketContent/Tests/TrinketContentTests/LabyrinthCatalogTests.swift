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
            #expect(!modifier.epithet.isEmpty)
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

    @Test func expandBeyondGateAppendsNextBand() {
        let generated = LabyrinthGenerator.makeInitialMap(seed: 11)
        var clusters = generated.clusters
        var nodes = generated.nodes
        guard let firstGate = nodes.values.first(where: { $0.type == .gate && $0.depth == 1 }) else {
            Issue.record("Expected a depth-1 gate")
            return
        }
        var gate = firstGate
        gate.isCleared = true
        nodes[gate.id] = gate
        LabyrinthGenerator.expandBeyondGate(
            gateNodeID: gate.id,
            clusters: &clusters,
            nodes: &nodes,
            seed: 11
        )
        #expect(clusters.contains { $0.depthBand == 2 })
        #expect(!(nodes[gate.id]?.outgoingIDs.isEmpty ?? true))
    }

    @Test func modifierEffectsCombineThreatAndBounty() throws {
        let iron = try #require(GameContent.labyrinthModifier(id: LabyrinthModifierID("ironPressure")))
        let effects = LabyrinthModifierEffects.combining([iron], biomeBias: .physical)
        #expect(effects.enemyPowerPercent == 20)
        #expect(effects.goldPercent == 20)
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

    @Test func threatModifiersAlwaysCarryBountyBump() {
        // Expand a few maps so deeper bands (multi-modifier) appear, then assert
        // every cluster with enemy-power threat also has a bounty-style bump.
        for seed in [3, 11, 42, 77] as [UInt64] {
            var clusters = LabyrinthGenerator.makeInitialMap(seed: seed).clusters
            var nodes = LabyrinthGenerator.makeInitialMap(seed: seed).nodes
            if var gate = nodes.values.first(where: { $0.type == .gate && $0.depth == 1 }) {
                gate.isCleared = true
                nodes[gate.id] = gate
                LabyrinthGenerator.expandBeyondGate(
                    gateNodeID: gate.id,
                    clusters: &clusters,
                    nodes: &nodes,
                    seed: seed
                )
            }
            for cluster in clusters where cluster.depthBand > 0 {
                let mods = LabyrinthCatalog.modifiers(ids: cluster.modifierIDs)
                let hasThreatPower = mods.contains { $0.enemyPowerPercent > 0 }
                guard hasThreatPower else { continue }
                let hasBounty = mods.contains {
                    $0.goldPercent > 0 || $0.xpPercent > 0 || $0.itemDropBonusPercent > 0
                        || $0.astralChanceBonusPercent > 0 || $0.category == .bounty
                        || $0.category == .affinity
                }
                #expect(hasBounty, "Cluster \(cluster.id) has threat without bounty")
            }
        }
    }

    @Test func clusterSizeStaysWithinPlanBounds() {
        for seed in 0 ..< 40 {
            let generated = LabyrinthGenerator.makeInitialMap(seed: UInt64(seed))
            for cluster in generated.clusters where cluster.depthBand > 0 {
                #expect(cluster.nodeIDs.count >= 3)
                #expect(cluster.nodeIDs.count <= 7)
            }
        }
    }
}
