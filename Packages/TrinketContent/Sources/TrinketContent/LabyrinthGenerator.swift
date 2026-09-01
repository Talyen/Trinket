import Foundation
import TrinketCore

public enum LabyrinthGenerator {
    public static let currentMapVersion = 5
    public static let entranceNodeID = "labyrinth-entrance"
    public static let entranceClusterID = "labyrinth-cluster-0"

    public static let fallbackWorldSeed: UInt64 = 0x4C41_4259

    public static func makeInitialMap(
        seed: UInt64 = 0,
        eligibleRecruitEventIDs: [String] = [],
    ) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode],
    ) {
        let resolvedSeed = seed == 0 ? fallbackWorldSeed : seed
        var rng = SeededRandomNumberGenerator(seed: resolvedSeed)
        let first = generateFloor(
            number: 1,
            previousBossEnemyID: nil,
            worldSeed: resolvedSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            using: &rng,
        )
        var nodes = Dictionary(uniqueKeysWithValues: first.nodes.map { ($0.id, $0) })
        let entrance = LabyrinthNode(
            id: entranceNodeID,
            type: .entrance,
            depth: 0,
            clusterID: entranceClusterID,
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            outgoingIDs: first.entryNodeIDs,
            isCleared: true,
            isRevealed: true,
        )
        nodes[entrance.id] = entrance
        return (
            [
                LabyrinthCluster(
                    id: entranceClusterID,
                    depthBand: 0,
                    nodeIDs: [entrance.id],
                ),
                first.cluster,
            ],
            nodes,
        )
    }

    public static func makeMap(
        seed: UInt64,
        floorCount: Int,
        eligibleRecruitEventIDs: [String] = [],
    ) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode],
    ) {
        var generated = makeInitialMap(
            seed: seed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
        )
        guard floorCount > 1 else { return generated }

        for floor in 1 ..< floorCount {
            guard let bossID = generated.clusters
                .first(where: { $0.depthBand == floor })?
                .nodeIDs
                .compactMap({ generated.nodes[$0] })
                .first(where: { $0.type.canonical == .boss })?
                .id,
                var boss = generated.nodes[bossID]
            else { break }
            boss.isCleared = true
            generated.nodes[bossID] = boss
            expandBeyondBoss(
                bossNodeID: bossID,
                clusters: &generated.clusters,
                nodes: &generated.nodes,
                seed: seed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            )
        }
        return generated
    }

    public static func expandBeyondBoss(
        bossNodeID: String,
        clusters: inout [LabyrinthCluster],
        nodes: inout [String: LabyrinthNode],
        seed: UInt64,
        eligibleRecruitEventIDs: [String] = [],
    ) {
        guard var boss = nodes[bossNodeID], boss.type.canonical == .boss, boss.isCleared else { return }
        guard boss.outgoingIDs.isEmpty else { return }

        let nextFloor = boss.depth + 1
        let previousBossEnemyID = boss.enemyID
        let resolvedSeed = seed == 0 ? fallbackWorldSeed : seed
        var rng = SeededRandomNumberGenerator(
            seed: resolvedSeed &+ UInt64(nextFloor) &* 1000003 &+ GameContent.stableSeed(for: bossNodeID),
        )
        let generated = generateFloor(
            number: nextFloor,
            previousBossEnemyID: previousBossEnemyID,
            worldSeed: resolvedSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            using: &rng,
        )
        clusters.append(generated.cluster)
        for node in generated.nodes {
            nodes[node.id] = node
        }
        boss.outgoingIDs = generated.entryNodeIDs
        nodes[boss.id] = boss
    }

    public static func revealReachable(from nodeID: String, nodes: inout [String: LabyrinthNode]) {
        guard let source = nodes[nodeID] else { return }
        for outgoingID in source.outgoingIDs {
            guard var target = nodes[outgoingID], !target.isRevealed else { continue }
            target.isRevealed = true
            nodes[outgoingID] = target
        }
    }

    private struct GeneratedFloor {
        let cluster: LabyrinthCluster
        let nodes: [LabyrinthNode]
        let entryNodeIDs: [String]
    }

    private struct LayoutKey: Hashable {
        let nodeCount: Int
        let closesLoop: Bool
    }

    private static let validLayoutsByKey: [LayoutKey: [[LabyrinthGridPosition]]] = {
        var result: [LayoutKey: [[LabyrinthGridPosition]]] = [:]
        let entrance = LabyrinthGridPosition(row: 0, column: 0)

        for nodeCount in 7 ... 9 {
            for closesLoop in [false, true] {
                let key = LayoutKey(nodeCount: nodeCount, closesLoop: closesLoop)
                let middleCount = nodeCount - 2
                var layouts: [[LabyrinthGridPosition]] = []

                for depth in 4 ... 6 {
                    let middleCandidates = (1 ..< depth).flatMap(boundedPositions(in:))
                    guard middleCandidates.count >= middleCount else { continue }

                    for boss in boundedPositions(in: depth) {
                        for middle in combinations(of: middleCandidates, choosing: middleCount) {
                            let positions = [entrance] + middle + [boss]
                            guard isValidFloorShape(positions, closesLoop: closesLoop) else { continue }
                            layouts.append(
                                [entrance]
                                    + middle.sorted(by: LabyrinthGridPosition.isOrderedBefore)
                                    + [boss],
                            )
                        }
                    }
                }
                result[key] = layouts
            }
        }
        return result
    }()

    private static func generateFloor(
        number: Int,
        previousBossEnemyID: String?,
        worldSeed: UInt64,
        eligibleRecruitEventIDs: [String],
        using rng: inout some RandomNumberGenerator,
    ) -> GeneratedFloor {
        let clusterID = "labyrinth-cluster-\(number)"
        let count = Int.random(in: 7 ... 9, using: &rng)
        let types = plannedTypes(
            count: count,
            hasEligibleRecruit: !eligibleRecruitEventIDs.isEmpty,
            using: &rng,
        )
        var remainingRecruitIDs = eligibleRecruitEventIDs.shuffled(using: &rng)
        let bossEnemyID = LabyrinthCatalog.pickBossEnemyID(
            excluding: previousBossEnemyID,
            using: &rng,
        )
        let payloads = types.enumerated().map { index, type in
            let nodeID = "\(clusterID)-n\(index)"
            let enemyID: String? = if type.isCombat {
                type == .boss
                    ? bossEnemyID
                    : LabyrinthCatalog.pickTrashEnemyID(using: &rng)
            } else {
                nil
            }
            let recruitEventID = type == .recruit ? remainingRecruitIDs.popLast() : nil
            return (
                type: type,
                nodeID: nodeID,
                enemyID: enemyID,
                modifierIDs: LabyrinthCatalog.modifierIDs(
                    for: type,
                    enemyID: enemyID,
                    worldSeed: worldSeed,
                    nodeID: nodeID,
                ),
                recruitEventID: recruitEventID,
            )
        }
        let positions = gridPositions(nodeCount: count, using: &rng)
        let nodes = payloads.enumerated().map { index, payload in
            LabyrinthNode(
                id: payload.nodeID,
                type: payload.type,
                enemyID: payload.enemyID,
                depth: number,
                clusterID: clusterID,
                gridPosition: positions[index],
                modifierIDs: payload.modifierIDs,
                recruitEventID: payload.recruitEventID,
                isRevealed: true,
            )
        }
        let cluster = LabyrinthCluster(
            id: clusterID,
            depthBand: number,
            nodeIDs: nodes.map(\.id),
        )
        return GeneratedFloor(cluster: cluster, nodes: nodes, entryNodeIDs: [nodes[0].id])
    }

    private static func gridPositions(
        nodeCount: Int,
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthGridPosition] {
        let closesLoop = Int.random(in: 0 ..< 5, using: &rng) == 0
        let key = LayoutKey(nodeCount: nodeCount, closesLoop: closesLoop)
        guard let layouts = validLayoutsByKey[key],
              let selected = layouts.randomElement(using: &rng)
        else { preconditionFailure("Labyrinth floor constraints must produce a layout") }
        return selected
    }

    private static func boundedPositions(in row: Int) -> [LabyrinthGridPosition] {
        let bound = LabyrinthMapLayout.maxProjectedHalfColumn
        return (-bound ... bound).compactMap { projectedColumn in
            guard (projectedColumn - row).isMultiple(of: 2) else { return nil }
            return LabyrinthGridPosition(
                row: row,
                column: (projectedColumn - row) / 2,
            )
        }
    }

    private static func combinations(
        of positions: [LabyrinthGridPosition],
        choosing count: Int,
    ) -> [[LabyrinthGridPosition]] {
        guard count > 0 else { return [[]] }
        guard positions.count >= count else { return [] }

        var result: [[LabyrinthGridPosition]] = []
        var selection: [LabyrinthGridPosition] = []

        func appendCombinations(startingAt index: Int) {
            if selection.count == count {
                result.append(selection)
                return
            }
            let remainingNeeded = count - selection.count
            guard positions.count - index >= remainingNeeded else { return }
            for candidateIndex in index ... positions.count - remainingNeeded {
                selection.append(positions[candidateIndex])
                appendCombinations(startingAt: candidateIndex + 1)
                selection.removeLast()
            }
        }

        appendCombinations(startingAt: 0)
        return result
    }

    private static func isValidFloorShape(
        _ positions: [LabyrinthGridPosition],
        closesLoop: Bool,
    ) -> Bool {
        let degrees = positions.map { source in
            positions.count(where: { target in
                source != target && source.isAdjacent(to: target)
            })
        }
        guard degrees.first == 1,
              degrees.last == 1,
              degrees.allSatisfy({ $0 <= 3 }),
              degrees.contains(3)
        else { return false }

        var reached: Set<LabyrinthGridPosition> = [positions[0]]
        var frontier = [positions[0]]
        while let source = frontier.popLast() {
            for target in positions where source.isAdjacent(to: target) && reached.insert(target).inserted {
                frontier.append(target)
            }
        }
        guard reached.count == positions.count else { return false }

        let edgeCount = degrees.reduce(0, +) / 2
        let cycleCount = edgeCount - positions.count + 1
        return cycleCount == (closesLoop ? 1 : 0)
    }

    private static func plannedTypes(
        count: Int,
        hasEligibleRecruit: Bool,
        using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthNodeType] {
        var nonCombat: [LabyrinthNodeType] = [.shop, .rest, .mystery]
        if hasEligibleRecruit {
            nonCombat.append(.recruit)
        }
        nonCombat.shuffle(using: &rng)

        var middle = Array(nonCombat.prefix(min(3, count - 2)))
        var weighted: [LabyrinthNodeType] = [.battle, .battle, .battle, .mystery, .rest, .shop]
        if hasEligibleRecruit, !middle.contains(.recruit) {
            weighted.append(.recruit)
        }
        while middle.count < count - 2 {
            let next = weighted.randomElement(using: &rng) ?? .battle
            if [.shop, .rest, .recruit].contains(next), middle.contains(next) {
                middle.append(.battle)
            } else {
                middle.append(next)
            }
        }
        middle.shuffle(using: &rng)
        return [.battle] + middle + [.boss]
    }
}
