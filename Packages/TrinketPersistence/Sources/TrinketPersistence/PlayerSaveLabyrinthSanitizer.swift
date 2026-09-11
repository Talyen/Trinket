import Foundation
import TrinketContent
import TrinketCore

extension PlayerSaveSanitizer {
    static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
    ) -> PlayerLabyrinthState {
        if labyrinth.isMapPayloadUnreadable {
            var healed = labyrinth
            healed.ensureMap(
                seed: labyrinth.worldSeed == 0 ? nil : labyrinth.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            )
            return sanitizeLabyrinth(healed, eligibleRecruitEventIDs: eligibleRecruitEventIDs)
        }

        var sanitized = labyrinth

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs,
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
            )
        }

        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            )
        }
        return sanitized
    }

    private static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        validNodeIDs: Set<String>,
        cluster: LabyrinthCluster?,
        worldSeed: UInt64,
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
