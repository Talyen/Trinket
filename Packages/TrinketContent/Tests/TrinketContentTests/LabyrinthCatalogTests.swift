import Testing
import TrinketContent
import TrinketCore

@Suite("LabyrinthCatalog")
struct LabyrinthCatalogTests {
    @Test func biomesAreAuthoredWithResolvableEnemies() throws {
        #expect(GameContent.labyrinthBiomes.count >= 8)
        for biome in GameContent.labyrinthBiomes {
            #expect(!biome.enemyPool.isEmpty)
            for enemyID in biome.enemyPool {
                #expect(GameContent.enemy(matching: enemyID) != nil)
            }
            #expect(GameContent.enemy(matching: biome.wardenEnemyID) != nil)
        }
    }

    @Test func modifiersHavePlayerFacingTitles() {
        #expect(GameContent.labyrinthModifiers.count >= 8)
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
}
