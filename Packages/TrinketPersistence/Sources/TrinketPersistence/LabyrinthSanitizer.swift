import TrinketContent
import TrinketCore

enum LabyrinthSanitizer {
    static func sanitize(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> PlayerLabyrinthState {
        var sanitized = labyrinth
        if sanitized.isMapPayloadUnreadable {
            sanitized.ensureMap(
                seed: labyrinth.worldSeed == 0 ? nil : labyrinth.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
                eligibleRewards: eligibleRewards,
            )
        }

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs,
            )
        }

        if sanitized.mapVersion == LabyrinthGenerator.currentMapVersion {
            if !labyrinth.isMapPayloadUnreadable {
                repairEntrance(in: &sanitized)
            }
            repairClearedBossExits(
                in: &sanitized, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards,
            )
        }

        let validClusterIDs = Set(sanitized.clusters.lazy.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        let validNodeIDs = Set(sanitized.nodes.keys)
        let clustersByID = Dictionary(sanitized.clusters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                validNodeIDs: validNodeIDs,
                cluster: clustersByID[node.clusterID],
                worldSeed: sanitized.worldSeed,
                eligibleRewards: eligibleRewards,
            )
        }

        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
                eligibleRewards: eligibleRewards,
            )
        }
        return sanitized
    }

    private static func repairEntrance(in labyrinth: inout PlayerLabyrinthState) {
        // Only the shipped floor format establishes a known entry without rerolling rooms.
        guard labyrinth.hasEntered,
              let firstFloor = labyrinth.clusters.first(where: { $0.id == "labyrinth-cluster-1" && $0.depthBand == 1 }),
              let entryID = firstFloor.nodeIDs.first, entryID == "\(firstFloor.id)-n0",
              let entry = labyrinth.nodes[entryID], entry.depth == 1, entry.clusterID == firstFloor.id else { return }
        let entranceID = LabyrinthGenerator.entranceNodeID
        let clusterID = LabyrinthGenerator.entranceClusterID
        var outgoing = labyrinth.nodes[entranceID]?.outgoingIDs.filter { labyrinth.nodes[$0] != nil } ?? []
        if !outgoing.contains(where: { labyrinth.nodes[$0]?.clusterID == firstFloor.id && labyrinth.nodes[$0]?.depth == 1 }) {
            outgoing.append(entryID)
        }
        labyrinth.nodes[entranceID] = LabyrinthNode(
            id: entranceID, type: .entrance, depth: 0, clusterID: clusterID,
            gridPosition: LabyrinthGridPosition(row: 0, column: 1), outgoingIDs: outgoing,
            isCleared: true, isRevealed: true,
        )
        let cluster = LabyrinthCluster(id: clusterID, depthBand: 0, nodeIDs: [entranceID])
        if let index = labyrinth.clusters.firstIndex(where: { $0.id == clusterID }) {
            labyrinth.clusters[index] = cluster
        } else {
            labyrinth.clusters.insert(cluster, at: 0)
        }
    }

    private static func repairClearedBossExits(
        in labyrinth: inout PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String],
        eligibleRewards: [RewardModifier],
    ) {
        var clusterIDs = Set(labyrinth.clusters.lazy.map(\.id))
        for boss in labyrinth.nodes.values.filter({ $0.type == .boss && $0.isCleared })
            .sorted(by: { $0.depth < $1.depth }) {
            guard boss.depth < Int.max else { continue }
            let nextDepth = max(0, boss.depth) + 1
            let hasExit = boss.outgoingIDs.contains {
                guard let target = labyrinth.nodes[$0] else { return false }
                return target.depth == nextDepth && clusterIDs.contains(target.clusterID)
            }
            guard !hasExit else { continue }
            if let entryID = labyrinth.clusters.first(where: { $0.depthBand == nextDepth })?.nodeIDs.first,
               labyrinth.nodes[entryID] != nil {
                labyrinth.nodes[boss.id]?.outgoingIDs = [entryID]
            } else {
                regenerateMissingFloor(
                    beyond: boss, in: &labyrinth,
                    eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards,
                )
                clusterIDs = Set(labyrinth.clusters.lazy.map(\.id))
            }
        }
    }

    private static func regenerateMissingFloor(
        beyond boss: LabyrinthNode,
        in labyrinth: inout PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String],
        eligibleRewards: [RewardModifier],
    ) {
        var generatedClusters: [LabyrinthCluster] = []
        var generatedNodes = [boss.id: boss]
        generatedNodes[boss.id]?.outgoingIDs = []
        LabyrinthGenerator.expandBeyondBoss(
            bossNodeID: boss.id, clusters: &generatedClusters, nodes: &generatedNodes,
            seed: labyrinth.worldSeed, eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            eligibleRewards: eligibleRewards,
        )
        for cluster in generatedClusters {
            if let index = labyrinth.clusters.firstIndex(where: { $0.id == cluster.id }) {
                labyrinth.clusters[index] = cluster
            } else {
                labyrinth.clusters.append(cluster)
            }
        }
        for (id, node) in generatedNodes where id != boss.id {
            if labyrinth.nodes[id] == nil {
                labyrinth.nodes[id] = node
            }
        }
        labyrinth.nodes[boss.id]?.outgoingIDs = generatedNodes[boss.id]?.outgoingIDs ?? []
    }

    private static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        validNodeIDs: Set<String>,
        cluster: LabyrinthCluster?,
        worldSeed: UInt64,
        eligibleRewards: [RewardModifier],
    ) -> LabyrinthNode {
        let depth = max(0, node.depth)
        let type: LabyrinthNodeType = if node.type == .entrance, depth > 0 {
            .boss
        } else {
            node.type
        }
        let enemyID: String? = if type.isCombat,
                                  node.enemyID.flatMap({ GameContent.enemy(matching: $0) })?.isBoss != (type == .boss) {
            if type == .boss {
                LabyrinthCatalog.fallbackBossEnemyID(worldSeed: worldSeed, nodeID: node.id)
            } else {
                fallbackBattleEnemyID(worldSeed: worldSeed, nodeID: node.id)
            }
        } else {
            node.enemyID
        }
        return LabyrinthNode(
            id: node.id,
            type: type,
            enemyID: enemyID,
            depth: depth,
            clusterID: node.clusterID,
            gridPosition: sanitizedGridPosition(for: node, in: cluster),
            modifierIDs: NodeModifierCatalog.resolvedModifierIDs(
                for: type,
                enemyID: enemyID,
                existingModifierIDs: node.modifierIDs,
                worldSeed: worldSeed,
                nodeID: node.id,
                eligibleRewards: eligibleRewards,
            ),
            recruitEventID: node.recruitEventID,
            mysteryEventID: node.mysteryEventID,
            mysteryOffersPayload: node.mysteryOffersPayload,
            shopPayload: node.shopPayload,
            outgoingIDs: node.outgoingIDs.filter { validNodeIDs.contains($0) },
            isCleared: node.isCleared,
            isRevealed: depth > 0 || node.isRevealed,
        )
    }

    private static func fallbackBattleEnemyID(worldSeed: UInt64, nodeID: String) -> String {
        var random = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: "labyrinth-battle-\(nodeID)"),
        )
        return LabyrinthCatalog.pickTrashEnemyID(using: &random)
    }

    private static func sanitizedGridPosition(
        for node: LabyrinthNode,
        in cluster: LabyrinthCluster?,
    ) -> LabyrinthGridPosition {
        let nodeCount = max(1, cluster?.nodeIDs.count ?? 1)
        // Covers generated axial positions and the legacy rectangular fallback,
        // while keeping neighbor and map-projection arithmetic bounded.
        if let position = node.gridPosition,
           (0 ... nodeCount).contains(position.row),
           (-(nodeCount / 2 + 1) ... LabyrinthMapLayout.maxProjectedHalfColumn).contains(position.column) {
            return position
        }
        return fallbackGridPosition(for: node, in: cluster)
    }

    private static func fallbackGridPosition(
        for node: LabyrinthNode,
        in cluster: LabyrinthCluster?,
    ) -> LabyrinthGridPosition {
        guard let cluster,
              let index = cluster.nodeIDs.firstIndex(of: node.id)
        else { return LabyrinthGridPosition(row: 0, column: 1) }
        if index == cluster.nodeIDs.count - 1 {
            return LabyrinthGridPosition(row: max(1, (index + 1) / 3), column: 1)
        }
        return LabyrinthGridPosition(row: index / 3, column: index % 3)
    }
}
