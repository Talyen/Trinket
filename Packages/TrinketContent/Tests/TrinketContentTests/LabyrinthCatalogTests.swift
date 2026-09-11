import Foundation
import Testing
import TrinketContent
import TrinketCore

@Suite("LabyrinthCatalog")
struct LabyrinthCatalogTests {
    @Test func `modifiers are authored with player facing content`() {
        #expect(!GameContent.labyrinthModifiers.isEmpty)
        for modifier in GameContent.labyrinthModifiers {
            #expect(!modifier.title.isEmpty)
            #expect(modifier.title.split(separator: " ").count <= 2)
            #expect(!modifier.effect.description.isEmpty)
        }
    }

    @Test func `generator is deterministic for seed`() {
        let first = LabyrinthGenerator.makeInitialMap(seed: 42)
        let second = LabyrinthGenerator.makeInitialMap(seed: 42)
        #expect(first.clusters.map(\.id) == second.clusters.map(\.id))
        #expect(first.nodes.keys.sorted() == second.nodes.keys.sorted())
        for id in first.nodes.keys {
            #expect(first.nodes[id] == second.nodes[id])
        }
    }

    @Test func `initial map has reachable entry from entrance`() {
        let generated = LabyrinthGenerator.makeInitialMap(seed: 7)
        let entrance = generated.nodes[LabyrinthGenerator.entranceNodeID]
        #expect(entrance?.isCleared == true)
        #expect(!(entrance?.outgoingIDs.isEmpty ?? true))
        for outgoing in entrance?.outgoingIDs ?? [] {
            #expect(generated.nodes[outgoing]?.isRevealed == true)
        }
    }

    @Test func `expand beyond boss appends next floor`() throws {
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
            seed: 11,
        )
        #expect(clusters.contains { $0.depthBand == 2 })
        #expect(!(nodes[boss.id]?.outgoingIDs.isEmpty ?? true))
    }

    @Test func `modifier effects combine damage and reward bonuses`() throws {
        let iron = try #require(GameContent.labyrinthModifier(id: LabyrinthModifierID("ironPressure")))
        let effects = LabyrinthModifierEffects.combining([iron])
        #expect(effects.damageDealtBonus == [.physical: 1])
        #expect(effects.shopDiscountPercent == 0)
    }

    @Test func `resolved modifiers keep an applicable existing modifier`() throws {
        let shopPool = LabyrinthCatalog.modifiers.filter { $0.applies(to: .shop) }
        let keep = try #require(shopPool.first).id
        let kept = LabyrinthCatalog.resolvedModifierIDs(
            for: .shop, enemyID: nil, existingModifierIDs: [keep], worldSeed: 7, nodeID: "n",
        )
        #expect(kept == [keep])
        let fresh = LabyrinthCatalog.resolvedModifierIDs(
            for: .shop, enemyID: nil, existingModifierIDs: [LabyrinthModifierID("bogus")],
            worldSeed: 7, nodeID: "n",
        )
        #expect(
            fresh == LabyrinthCatalog.modifierIDs(for: .shop, enemyID: nil, worldSeed: 7, nodeID: "n"),
        )
    }

    @Test func `shop nodes resolve one shop modifier`() {
        let shopPool = LabyrinthCatalog.modifiers.filter { $0.applies(to: .shop) }
        #expect(!shopPool.isEmpty)
        #expect(shopPool.contains(where: { $0.id == LabyrinthModifierID("shopDiscount") }))
        #expect(shopPool.contains(where: { $0.id == LabyrinthModifierID("appraisersEye") }))
        for seed in [1, 7, 42, 99, 1001] as [UInt64] {
            let ids = LabyrinthCatalog.modifierIDs(for: .shop, enemyID: nil, worldSeed: seed, nodeID: "n-\(seed)")
            #expect(ids.count == 1)
            #expect(ids.allSatisfy { id in shopPool.contains(where: { $0.id == id }) })
        }
        for type in LabyrinthNodeType.allCases
            where !type.isCombat && type != .shop && type != .mystery {
            let ids = LabyrinthCatalog.modifierIDs(for: type, enemyID: nil, worldSeed: 1, nodeID: "n")
            #expect(ids.isEmpty)
        }
    }

    @Test func `mystery nodes resolve exactly one economy modifier`() {
        let economyIDs: Set<LabyrinthModifierID> = [
            LabyrinthModifierID("bountyMark"),
            LabyrinthModifierID("scholarsToll"),
            LabyrinthModifierID("scavengersLuck"),
        ]
        for seed in [1, 7, 42, 99, 1001] as [UInt64] {
            let ids = LabyrinthCatalog.modifierIDs(for: .mystery, enemyID: nil, worldSeed: seed, nodeID: "n-\(seed)")
            #expect(ids.count == 1)
            #expect(economyIDs.contains(ids[0]))
        }
        let pool = LabyrinthCatalog.modifiers.filter { $0.applies(to: .mystery) }
        #expect(!pool.isEmpty)
        #expect(economyIDs.isSubset(of: Set(pool.map(\.id))))
        #expect(pool.allSatisfy { economyIDs.contains($0.id) || $0.applies(to: .mystery) })
    }

    @Test func `combat modifiers match enemy ability keywords`() {
        for enemy in GameContent.enemies {
            for nodeType in [LabyrinthNodeType.battle, LabyrinthNodeType.boss] {
                let pool = LabyrinthCatalog.combatModifiers(for: enemy.id, nodeType: nodeType)
                let enemyKeywords = LabyrinthCatalog.enemyDamageKeywords(for: enemy.id)
                for modifier in pool {
                    #expect(modifier.relevantKeyword.map(enemyKeywords.contains) != false)
                }
            }
        }
    }

    @Test func `generated combat modifiers align with node enemies`() {
        for seed in 0 ..< 20 {
            let generated = LabyrinthGenerator.makeInitialMap(seed: UInt64(seed))
            for node in generated.nodes.values where node.type.isCombat {
                guard let enemyID = node.enemyID else { continue }
                let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
                #expect(modifiers.count == 1)
                let enemyKeywords = LabyrinthCatalog.enemyDamageKeywords(for: enemyID)
                for modifier in modifiers {
                    #expect(modifier.relevantKeyword.map(enemyKeywords.contains) != false)
                }
            }
        }
    }

    @Test func `grid position adjacency matches six hex neighbors`() {
        let center = LabyrinthGridPosition(row: 1, column: 0)
        let neighbors = [
            LabyrinthGridPosition(row: 1, column: -1),
            LabyrinthGridPosition(row: 1, column: 1),
            LabyrinthGridPosition(row: 0, column: 0),
            LabyrinthGridPosition(row: 0, column: 1),
            LabyrinthGridPosition(row: 2, column: -1),
            LabyrinthGridPosition(row: 2, column: 0),
        ]
        let distant = LabyrinthGridPosition(row: 4, column: 0)
        #expect(neighbors.allSatisfy { center.isAdjacent(to: $0) })
        #expect(neighbors.allSatisfy { $0.isAdjacent(to: center) })
        #expect(!center.isAdjacent(to: center))
        #expect(!center.isAdjacent(to: distant))
    }

    @Test func `grid position ordering is row major`() {
        let positions = [
            LabyrinthGridPosition(row: 2, column: 0),
            LabyrinthGridPosition(row: 1, column: 1),
            LabyrinthGridPosition(row: 0, column: 0),
            LabyrinthGridPosition(row: 1, column: 0),
        ]
        #expect(positions.sorted(by: LabyrinthGridPosition.isOrderedBefore).map { "\($0.row):\($0.column)" } == [
            "0:0", "1:0", "1:1", "2:0",
        ])
    }

    @Test func `modifier catalog has unique I ds and non empty copy`() {
        let modifiers = GameContent.labyrinthModifiers
        #expect(!modifiers.isEmpty)
        #expect(Set(modifiers.map(\.id)).count == modifiers.count)
        #expect(modifiers.allSatisfy { !$0.title.isEmpty && !$0.effect.description.isEmpty })
    }

    @Test func `floor shape stays within plan bounds`() {
        var layoutSignatures = Set<String>()
        var observedCycleCounts = Set<Int>()

        for seed in 0 ..< 20 {
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
                #expect(nodes.count(where: { !$0.type.isCombat }) >= 2)

                let geometry = validateGeometry(of: nodes)
                for node in nodes {
                    let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
                    #expect(modifiers.allSatisfy { $0.applies(to: node.type) })
                    let expectsModifier = switch node.type {
                    case .shop, .mystery:
                        true
                    case .battle, .boss:
                        node.enemyID != nil
                    case .recruit, .entrance:
                        false
                    }
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

        let projectedColumns = positions.map(\.projectedHalfColumn)
        #expect(
            (projectedColumns.max() ?? 0) - (projectedColumns.min() ?? 0)
                <= LabyrinthMapLayout.maxProjectedSpan,
        )
        let neighborsByID = Dictionary(uniqueKeysWithValues: nodes.map { node in
            (node.id, nodes.filter { node.id != $0.id && node.isAdjacent(to: $0) }.map(\.id))
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
            cycleCount,
        )
    }

    @Test func `recruit nodes require eligible event`() {
        let withoutRecruit = LabyrinthGenerator.makeInitialMap(seed: 14)
        #expect(withoutRecruit.nodes.values.allSatisfy { $0.type != .recruit })

        var foundRecruit = false
        for seed in 0 ..< 16 {
            let withRecruit = LabyrinthGenerator.makeInitialMap(
                seed: UInt64(seed),
                eligibleRecruitEventIDs: ["recruit-test-event"],
            )
            for node in withRecruit.nodes.values where node.type == .recruit {
                foundRecruit = true
                #expect(node.recruitEventID == "recruit-test-event")
            }
        }
        #expect(foundRecruit)
    }

    @Test func `generated floors separate same type neighbors when possible`() {
        for seed in 0 ..< 32 {
            let generated = LabyrinthGenerator.makeInitialMap(seed: UInt64(seed))
            assertMinimalSeparation(clusters: generated.clusters, nodes: generated.nodes)
            let recruited = LabyrinthGenerator.makeInitialMap(
                seed: UInt64(seed),
                eligibleRecruitEventIDs: ["recruit-test-event"],
            )
            assertMinimalSeparation(clusters: recruited.clusters, nodes: recruited.nodes)
        }
        for seed in [3, 17, 99] as [UInt64] {
            let expanded = LabyrinthGenerator.makeMap(
                seed: seed,
                floorCount: 3,
                eligibleRecruitEventIDs: ["recruit-test-event"],
            )
            assertMinimalSeparation(clusters: expanded.clusters, nodes: expanded.nodes)
        }
    }

    private func assertMinimalSeparation(
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode],
    ) {
        for cluster in clusters where cluster.depthBand > 0 {
            let floor = cluster.nodeIDs.compactMap { nodes[$0] }
            #expect(adjacencyConflicts(in: floor) == minimalAdjacencyConflicts(for: floor))
        }
    }

    private func adjacencyConflicts(in nodes: [LabyrinthNode]) -> Int {
        var conflicts = 0
        for i in nodes.indices {
            for j in nodes.indices where j > i && nodes[i].isAdjacent(to: nodes[j]) {
                if nodes[i].type == nodes[j].type {
                    conflicts += 1
                }
            }
        }
        return conflicts
    }

    private func minimalAdjacencyConflicts(for nodes: [LabyrinthNode]) -> Int {
        guard nodes.count > 2 else { return 0 }
        let entry = nodes[0]
        let boss = nodes[nodes.count - 1]
        var middle = Array(nodes[1 ..< nodes.count - 1])
        var seen: Set<[LabyrinthNodeType]> = []
        var best = Int.max
        func visit(index: Int) {
            if index == middle.count {
                if seen.insert(middle.map(\.type)).inserted {
                    best = min(best, adjacencyConflicts(in: [entry] + middle + [boss]))
                }
                return
            }
            for i in index ..< middle.count {
                middle.swapAt(index, i)
                visit(index: index + 1)
                middle.swapAt(index, i)
            }
        }
        visit(index: 0)
        return best
    }
}
