import Foundation
import TrinketContent
import TrinketCore

extension PlayerSaveSanitizer {
    static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = []
    ) -> PlayerLabyrinthState {
        if labyrinth.isMapPayloadUnreadable {
            return labyrinth
        }

        var sanitized = labyrinth

        if sanitized.hasEntered,
           sanitized.hasMap,
           sanitized.mapVersion < LabyrinthGenerator.currentMapVersion {
            sanitized = regeneratedLabyrinth(
                from: sanitized,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }

        sanitized.clusters = sanitized.clusters.map { cluster in
            LabyrinthCluster(
                id: cluster.id,
                depthBand: max(0, cluster.depthBand),
                nodeIDs: cluster.nodeIDs
            )
        }

        let validClusterIDs = Set(sanitized.clusters.map(\.id))
        sanitized.nodes = sanitized.nodes.filter { _, node in
            validClusterIDs.contains(node.clusterID) || node.id == LabyrinthGenerator.entranceNodeID
        }

        let existingNodes = sanitized.nodes
        for (id, node) in existingNodes {
            sanitized.nodes[id] = sanitizedLabyrinthNode(
                node,
                existingNodes: existingNodes,
                cluster: sanitized.cluster(id: node.clusterID),
                worldSeed: sanitized.worldSeed
            )
        }

        if sanitized.hasEntered, sanitized.nodes.isEmpty {
            sanitized.ensureMap(
                seed: sanitized.worldSeed == 0 ? nil : sanitized.worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }
        sanitized.mapVersion = LabyrinthGenerator.currentMapVersion
        return sanitized
    }

    private static func regeneratedLabyrinth(
        from legacy: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String]
    ) -> PlayerLabyrinthState {
        let floorCount = max(1, legacy.currentFloorNumber)
        let seed = legacy.worldSeed == 0 ? LabyrinthGenerator.fallbackWorldSeed : legacy.worldSeed
        let generated = LabyrinthGenerator.makeMap(
            seed: seed,
            floorCount: floorCount,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        var nodes = generated.nodes
        migrateLegacyFloorProgress(from: legacy, clusters: generated.clusters, nodes: &nodes)
        for (id, legacyNode) in legacy.nodes {
            guard let generatedNode = nodes[id] else { continue }
            nodes[id] = LabyrinthNode(
                id: generatedNode.id,
                type: generatedNode.type,
                enemyID: generatedNode.enemyID,
                depth: generatedNode.depth,
                clusterID: generatedNode.clusterID,
                gridPosition: generatedNode.gridPosition,
                modifierIDs: generatedNode.modifierIDs,
                recruitEventID: legacyNode.recruitEventID ?? generatedNode.recruitEventID,
                mysteryEventID: legacyNode.mysteryEventID ?? generatedNode.mysteryEventID,
                outgoingIDs: generatedNode.outgoingIDs,
                isCleared: generatedNode.isCleared || legacyNode.isCleared,
                isRevealed: generatedNode.isRevealed || legacyNode.isRevealed
            )
        }
        ensureHistoricalFloorAccess(floorCount: floorCount, clusters: generated.clusters, nodes: &nodes)
        return PlayerLabyrinthState(
            worldSeed: seed,
            mapVersion: LabyrinthGenerator.currentMapVersion,
            hasEntered: legacy.hasEntered,
            clusters: generated.clusters,
            nodes: nodes,
            runHealthByCombatantID: legacy.runHealthByCombatantID
        )
    }

    private static func migrateLegacyFloorProgress(
        from legacy: PlayerLabyrinthState, clusters: [LabyrinthCluster], nodes: inout [String: LabyrinthNode]
    ) {
        for cluster in clusters where cluster.depthBand > 0 {
            guard let legacyCluster = legacy.clusters.first(where: { $0.depthBand == cluster.depthBand }),
                  Set(legacyCluster.nodeIDs).isDisjoint(with: cluster.nodeIDs)
            else { continue }
            let legacyFloorNodes = legacyCluster.nodeIDs.compactMap { legacy.nodes[$0] }
            let clearedNonBossCount = legacyFloorNodes.count { $0.isCleared && $0.type.canonical != .boss }
            guard let entryID = cluster.nodeIDs.first else { continue }
            var migrationOrder: [String] = []
            for targetID in cluster.nodeIDs where nodes[targetID]?.type.canonical != .boss {
                let path = adjacentPath(from: entryID, to: targetID, nodeIDs: cluster.nodeIDs, nodes: nodes)
                for nodeID in path where nodes[nodeID]?.type.canonical != .boss && !migrationOrder.contains(nodeID) {
                    migrationOrder.append(nodeID)
                }
            }
            for nodeID in migrationOrder.prefix(clearedNonBossCount) {
                guard var node = nodes[nodeID] else { continue }
                node.isCleared = true
                nodes[nodeID] = node
            }
            guard legacyFloorNodes.contains(where: { $0.isCleared && $0.type.canonical == .boss }),
                  let bossID = cluster.nodeIDs.first(where: { nodes[$0]?.type.canonical == .boss }),
                  var boss = nodes[bossID]
            else { continue }
            boss.isCleared = true
            nodes[bossID] = boss
        }
    }

    private static func ensureHistoricalFloorAccess(
        floorCount: Int,
        clusters: [LabyrinthCluster],
        nodes: inout [String: LabyrinthNode]
    ) {
        guard floorCount > 1 else { return }
        for floor in 1 ..< floorCount {
            guard let cluster = clusters.first(where: { $0.depthBand == floor }),
                  let entryID = cluster.nodeIDs.first,
                  let bossID = cluster.nodeIDs.last
            else { continue }
            for nodeID in adjacentPath(
                from: entryID,
                to: bossID,
                nodeIDs: cluster.nodeIDs,
                nodes: nodes
            ) {
                guard var node = nodes[nodeID] else { break }
                node.isCleared = true
                nodes[nodeID] = node
            }
        }
    }

    private static func sanitizedLabyrinthNode(
        _ node: LabyrinthNode,
        existingNodes: [String: LabyrinthNode],
        cluster: LabyrinthCluster?,
        worldSeed: UInt64
    ) -> LabyrinthNode {
        let depth = max(0, node.depth)
        let type: LabyrinthNodeType = if node.type == .entrance || node.type.rawValue == "gate", depth > 0 {
            .boss
        } else {
            node.type.canonical
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
            gridPosition: node.gridPosition ?? legacyGridPosition(for: node, in: cluster),
            modifierIDs: LabyrinthCatalog.resolvedModifierIDs(
                for: type,
                enemyID: enemyID,
                existingModifierIDs: node.modifierIDs,
                worldSeed: worldSeed,
                nodeID: node.id
            ),
            recruitEventID: node.recruitEventID,
            mysteryEventID: node.mysteryEventID,
            outgoingIDs: node.outgoingIDs.filter { existingNodes[$0] != nil },
            isCleared: node.isCleared,
            isRevealed: depth > 0 || node.isRevealed
        )
    }

    private static func legacyGridPosition(
        for node: LabyrinthNode,
        in cluster: LabyrinthCluster?
    ) -> LabyrinthGridPosition {
        guard let cluster,
              let index = cluster.nodeIDs.firstIndex(of: node.id)
        else { return LabyrinthGridPosition(row: 0, column: 1) }
        if index == cluster.nodeIDs.count - 1 {
            return LabyrinthGridPosition(row: max(1, (index + 1) / 3), column: 1)
        }
        return LabyrinthGridPosition(row: index / 3, column: index % 3)
    }

    private static func adjacentPath(
        from sourceID: String,
        to targetID: String,
        nodeIDs: [String],
        nodes: [String: LabyrinthNode]
    ) -> [String] {
        var frontier = [sourceID]
        var nextIndex = 0
        var predecessor: [String: String] = [:]
        var visited: Set<String> = [sourceID]
        let candidateNodes: [(id: String, node: LabyrinthNode)] = nodeIDs.sorted().compactMap { id in
            nodes[id].map { (id, $0) }
        }

        while nextIndex < frontier.count {
            let nodeID = frontier[nextIndex]
            nextIndex += 1
            if nodeID == targetID {
                break
            }
            guard let source = nodes[nodeID] else {
                continue
            }

            for (candidateID, candidate) in candidateNodes {
                guard !visited.contains(candidateID), source.isAdjacent(to: candidate) else { continue }
                visited.insert(candidateID)
                predecessor[candidateID] = nodeID
                frontier.append(candidateID)
            }
        }

        guard visited.contains(targetID) else { return [] }
        var path = [targetID]
        while let current = path.last, let previous = predecessor[current] {
            path.append(previous)
        }
        path.reverse()
        return path.first == sourceID ? path : []
    }
}
