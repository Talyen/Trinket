import TrinketContent
import TrinketCore

enum LabyrinthSanitizer {
    static func sanitize(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> PlayerLabyrinthState {
        if labyrinth.isMapPayloadUnreadable {
            var healed = labyrinth
            healed.ensureMap(
                seed: labyrinth.worldSeed == 0 ? nil : labyrinth.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
                eligibleRewards: eligibleRewards,
            )
            return sanitize(healed, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards)
        }

        var sanitized = labyrinth

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs,
            )
        }

        if sanitized.mapVersion == LabyrinthGenerator.currentMapVersion {
            repairClearedBossExits(
                in: &sanitized, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards,
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        let validNodeIDs = Set(sanitized.nodes.keys)
        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                validNodeIDs: validNodeIDs,
                cluster: sanitized.cluster(id: node.clusterID),
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

    private static func repairClearedBossExits(
        in labyrinth: inout PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String],
        eligibleRewards: [RewardModifier],
    ) {
        for boss in labyrinth.nodes.values.filter({ $0.type == .boss && $0.isCleared })
            .sorted(by: { $0.depth < $1.depth }) {
            let clusterIDs = Set(labyrinth.clusters.map(\.id))
            let hasExit = boss.outgoingIDs.contains {
                guard let target = labyrinth.nodes[$0] else { return false }
                return target.depth == boss.depth + 1 && clusterIDs.contains(target.clusterID)
            }
            guard !hasExit else { continue }
            if let entryID = labyrinth.clusters.first(where: { $0.depthBand == boss.depth + 1 })?.nodeIDs.first,
               labyrinth.nodes[entryID] != nil {
                labyrinth.nodes[boss.id]?.outgoingIDs = [entryID]
            } else {
                regenerateMissingFloor(
                    beyond: boss, in: &labyrinth,
                    eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards,
                )
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
        let enemyID: String? = if type == .boss, node.enemyID == nil {
            LabyrinthCatalog.fallbackBossEnemyID(worldSeed: worldSeed, nodeID: node.id)
        } else {
            node.enemyID
        }
        return LabyrinthNode(
            id: node.id,
            type: type,
            enemyID: enemyID,
            depth: depth,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition ?? fallbackGridPosition(for: node, in: cluster),
            modifierIDs: LabyrinthCatalog.resolvedModifierIDs(
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
