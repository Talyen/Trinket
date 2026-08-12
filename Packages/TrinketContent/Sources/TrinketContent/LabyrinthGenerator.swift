import Foundation
import TrinketCore

/// Deterministic expanding floor generator for The Labyrinth.
public enum LabyrinthGenerator {
    public static let currentMapVersion = 3
    public static let entranceNodeID = "labyrinth-entrance"
    public static let entranceClusterID = "labyrinth-cluster-0"

    /// Deterministic fallback seed used when an initial map is requested with seed 0.
    public static let fallbackWorldSeed: UInt64 = 0x4C41_4259

    public static func makeInitialMap(
        seed: UInt64 = 0,
        eligibleRecruitEventIDs: [String] = []
    ) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode]
    ) {
        var rng = SeededRandomNumberGenerator(seed: seed == 0 ? fallbackWorldSeed : seed)
        let first = generateFloor(
            number: 1,
            previousBiomeID: nil,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            using: &rng
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
            isRevealed: true
        )
        nodes[entrance.id] = entrance
        return (
            [
                LabyrinthCluster(
                    id: entranceClusterID,
                    biomeID: first.cluster.biomeID,
                    depthBand: 0,
                    modifierIDs: [],
                    nodeIDs: [entrance.id]
                ),
                first.cluster,
            ],
            nodes
        )
    }

    /// Rebuilds a deterministic sequence of generated floors for save migration.
    public static func makeMap(
        seed: UInt64,
        floorCount: Int,
        eligibleRecruitEventIDs: [String] = []
    ) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode]
    ) {
        var generated = makeInitialMap(
            seed: seed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
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
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }
        return generated
    }

    /// Appends one floor beyond a cleared boss and wires the boss to its entry.
    public static func expandBeyondBoss(
        bossNodeID: String,
        clusters: inout [LabyrinthCluster],
        nodes: inout [String: LabyrinthNode],
        seed: UInt64,
        eligibleRecruitEventIDs: [String] = []
    ) {
        guard var boss = nodes[bossNodeID], boss.type.canonical == .boss, boss.isCleared else { return }
        guard boss.outgoingIDs.isEmpty else { return }

        let nextFloor = boss.depth + 1
        let previousBiome = clusters.first(where: { $0.depthBand == boss.depth })?.biomeID
        var rng = SeededRandomNumberGenerator(
            seed: seed &+ UInt64(nextFloor) &* 1000003 &+ GameContent.stableSeed(for: bossNodeID)
        )
        let generated = generateFloor(
            number: nextFloor,
            previousBiomeID: previousBiome,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            using: &rng
        )
        clusters.append(generated.cluster)
        for node in generated.nodes {
            nodes[node.id] = node
        }
        boss.outgoingIDs = generated.entryNodeIDs
        nodes[boss.id] = boss
    }

    /// Node types are visible for the whole floor; this remains the reachability hook.
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

    private static func generateFloor(
        number: Int,
        previousBiomeID: LabyrinthBiomeID?,
        eligibleRecruitEventIDs: [String],
        using rng: inout some RandomNumberGenerator
    ) -> GeneratedFloor {
        let biome = pickBiome(excluding: previousBiomeID, using: &rng)
        let clusterID = "labyrinth-cluster-\(number)-\(biome.id.rawValue)"
        let count = Int.random(in: 7 ... 9, using: &rng)
        let types = plannedTypes(
            count: count,
            hasEligibleRecruit: !eligibleRecruitEventIDs.isEmpty,
            using: &rng
        )
        var remainingRecruitIDs = eligibleRecruitEventIDs.shuffled(using: &rng)
        let payloads = types.map { type in
            let enemyID: String? = if type.isCombat {
                type == .boss ? biome.bossEnemyID : pickEnemy(from: biome, using: &rng)
            } else {
                nil
            }
            let recruitEventID = type == .recruit ? remainingRecruitIDs.popLast() : nil
            return (
                type: type,
                enemyID: enemyID,
                modifierIDs: modifierIDs(for: type, using: &rng),
                recruitEventID: recruitEventID
            )
        }
        let positions = gridPositions(nodeCount: count, using: &rng)
        let nodes = payloads.enumerated().map { index, payload in
            LabyrinthNode(
                id: "\(clusterID)-n\(index)",
                type: payload.type,
                enemyID: payload.enemyID,
                depth: number,
                clusterID: clusterID,
                gridPosition: positions[index],
                modifierIDs: payload.modifierIDs,
                recruitEventID: payload.recruitEventID,
                isRevealed: true
            )
        }
        let cluster = LabyrinthCluster(
            id: clusterID,
            biomeID: biome.id,
            depthBand: number,
            modifierIDs: [],
            nodeIDs: nodes.map(\.id)
        )
        return GeneratedFloor(cluster: cluster, nodes: nodes, entryNodeIDs: [nodes[0].id])
    }

    private static func gridPositions(
        nodeCount: Int,
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthGridPosition] {
        let closesLoop = Int.random(in: 0 ..< 5, using: &rng) == 0
        var depths = Array(4 ... 6)
        depths.shuffle(using: &rng)

        for depth in depths {
            var bossPositions = boundedPositions(in: depth)
            bossPositions.shuffle(using: &rng)
            let middleCandidates = (1 ..< depth).flatMap(boundedPositions(in:))
            let k = nodeCount - 2
            guard middleCandidates.count >= k else { continue }

            for boss in bossPositions {
                // Fast path: try random subset sampling to avoid allocating tens of thousands of combination arrays.
                var found: [LabyrinthGridPosition]?
                for _ in 0 ..< 1000 {
                    let candidate = Array(middleCandidates.shuffled(using: &rng).prefix(k))
                    let positions = [LabyrinthGridPosition(row: 0, column: 0)] + candidate + [boss]
                    if isValidFloorShape(positions, closesLoop: closesLoop) {
                        found = [positions[0]] + candidate.sorted(by: LabyrinthGridPosition.isOrderedBefore) + [boss]
                        break
                    }
                }
                if let found {
                    return found
                }

                // Fallback for rare seeds if random sampling did not find a valid shape.
                var middleSets = combinations(of: middleCandidates, choosing: k)
                middleSets.shuffle(using: &rng)
                for middle in middleSets {
                    let positions = [LabyrinthGridPosition(row: 0, column: 0)] + middle + [boss]
                    guard isValidFloorShape(positions, closesLoop: closesLoop) else { continue }
                    return [positions[0]] + middle.sorted(by: LabyrinthGridPosition.isOrderedBefore) + [boss]
                }
            }
        }

        preconditionFailure("Labyrinth floor constraints must produce a layout")
    }

    /// Limits projected center positions to `LabyrinthMapLayout` half-column slots.
    private static func boundedPositions(in row: Int) -> [LabyrinthGridPosition] {
        let bound = LabyrinthMapLayout.maxProjectedHalfColumn
        return (-bound ... bound).compactMap { projectedColumn in
            guard (projectedColumn - row).isMultiple(of: 2) else { return nil }
            return LabyrinthGridPosition(
                row: row,
                column: (projectedColumn - row) / 2
            )
        }
    }

    private static func combinations(
        of positions: [LabyrinthGridPosition],
        choosing count: Int
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
        closesLoop: Bool
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
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthNodeType] {
        var nonCombat: [LabyrinthNodeType] = [.shop, .rest, .mystery, .craft]
        if hasEligibleRecruit {
            nonCombat.append(.recruit)
        }
        nonCombat.shuffle(using: &rng)

        var middle = Array(nonCombat.prefix(min(3, count - 2)))
        var weighted: [LabyrinthNodeType] = [.battle, .battle, .battle, .mystery, .rest, .craft, .shop]
        if hasEligibleRecruit, !middle.contains(.recruit) {
            weighted.append(.recruit)
        }
        while middle.count < count - 2 {
            let next = weighted.randomElement(using: &rng) ?? .battle
            if [.shop, .rest, .craft, .recruit].contains(next), middle.contains(next) {
                middle.append(.battle)
            } else {
                middle.append(next)
            }
        }
        middle.shuffle(using: &rng)
        return [.battle] + middle + [.boss]
    }

    private static func modifierIDs(
        for type: LabyrinthNodeType,
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthModifierID] {
        let ids: [String] = switch type.canonical {
        case .battle, .boss:
            Array(
                ["ironPressure", "ashTithe", "bloodMarket", "serpentBloom", "rimeTax"]
                    .shuffled(using: &rng)
                    .prefix(1)
            )
        case .shop:
            ["gildedWhisper"]
        case .craft:
            ["astralSeam"]
        case .rest, .mystery, .event, .recruit, .entrance:
            []
        }
        return ids.map { LabyrinthModifierID($0) }
    }

    private static func pickBiome(
        excluding previous: LabyrinthBiomeID?,
        using rng: inout some RandomNumberGenerator
    ) -> LabyrinthBiomeDefinition {
        let pool = LabyrinthCatalog.biomes.filter { $0.id != previous }
        let choices = pool.isEmpty ? LabyrinthCatalog.biomes : pool
        return choices.randomElement(using: &rng) ?? LabyrinthCatalog.biomes[0]
    }

    private static func pickEnemy(
        from biome: LabyrinthBiomeDefinition,
        using rng: inout some RandomNumberGenerator
    ) -> String {
        biome.enemyPool.randomElement(using: &rng) ?? biome.bossEnemyID
    }
}
