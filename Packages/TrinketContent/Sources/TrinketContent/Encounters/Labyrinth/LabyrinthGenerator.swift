import Foundation
import TrinketCore

public enum LabyrinthGenerator {
    public static let currentMapVersion = 6
    public static let entranceNodeID = "labyrinth-entrance"
    public static let entranceClusterID = "labyrinth-cluster-0"

    public static let fallbackWorldSeed: UInt64 = 0x4C41_4259

    public static func makeInitialMap(
        seed: UInt64 = 0,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
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
            eligibleRewards: eligibleRewards,
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
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode],
    ) {
        var generated = makeInitialMap(
            seed: seed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            eligibleRewards: eligibleRewards,
        )
        guard floorCount > 1 else { return generated }

        for floor in 1 ..< floorCount {
            guard let bossID = generated.clusters
                .first(where: { $0.depthBand == floor })?
                .nodeIDs
                .compactMap({ generated.nodes[$0] })
                .first(where: { $0.type == .boss })?
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
                eligibleRewards: eligibleRewards,
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
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) {
        guard var boss = nodes[bossNodeID], boss.type == .boss, boss.isCleared else { return }
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
            eligibleRewards: eligibleRewards,
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

    private static func generateFloor(
        number: Int,
        previousBossEnemyID: String?,
        worldSeed: UInt64,
        eligibleRecruitEventIDs: [String],
        eligibleRewards: [RewardModifier],
        using rng: inout some RandomNumberGenerator,
    ) -> GeneratedFloor {
        let clusterID = "labyrinth-cluster-\(number)"
        let count = Int.random(in: 7 ... 9, using: &rng)
        let planned = LabyrinthFloorTypePlacement.plannedTypes(
            count: count,
            hasEligibleRecruit: !eligibleRecruitEventIDs.isEmpty,
            using: &rng,
        )
        var remainingRecruitIDs = eligibleRecruitEventIDs.shuffled(using: &rng)
        let bossEnemyID = LabyrinthCatalog.pickBossEnemyID(
            excluding: previousBossEnemyID,
            using: &rng,
        )
        let positions = LabyrinthFloorGeometry.positions(nodeCount: count, using: &rng)
        let types = LabyrinthFloorTypePlacement.separatedTypes(planned, positions: positions, using: &rng)
        let nodes = types.enumerated().map { index, type in
            let nodeID = "\(clusterID)-n\(index)"
            let enemyID: String? = if type.isCombat {
                type == .boss
                    ? bossEnemyID
                    : LabyrinthCatalog.pickTrashEnemyID(using: &rng)
            } else {
                nil
            }
            return LabyrinthNode(
                id: nodeID,
                type: type,
                enemyID: enemyID,
                depth: number,
                clusterID: clusterID,
                gridPosition: positions[index],
                modifierIDs: NodeModifierCatalog.modifierIDs(
                    for: type,
                    enemyID: enemyID,
                    worldSeed: worldSeed,
                    nodeID: nodeID,
                    eligibleRewards: eligibleRewards,
                ),
                recruitEventID: type == .recruit ? remainingRecruitIDs.popLast() : nil,
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
}
