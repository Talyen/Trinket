import Foundation
import TrinketContent
import TrinketCore

/// Persistent The Labyrinth map.
public struct PlayerLabyrinthState: Equatable, Sendable {
    private struct ReachabilityIndex {
        var explicitOutgoingIDs: Set<String> = []
        var clearedPositionsByCluster: [String: Set<LabyrinthGridPosition>] = [:]
    }

    public var worldSeed: UInt64
    public var mapVersion: Int
    public var hasEntered: Bool
    public var clusters: [LabyrinthCluster]
    public var nodes: [String: LabyrinthNode]
    /// Current-run party health by combatant id. Missing entries mean full health;
    /// written on battle victory and Campfire rests, cleared when a map is generated.
    public var runHealthByCombatantID: [String: Int]
    /// In-memory only: the SwiftData map blob existed but could not be decoded.
    /// Sanitizer must not regenerate a map, and graph apply must keep the prior blob.
    public var isMapPayloadUnreadable: Bool

    public static let freshStart = Self()
    public static let testSeed = Self()

    public init(
        worldSeed: UInt64 = 0,
        mapVersion: Int = LabyrinthGenerator.currentMapVersion,
        hasEntered: Bool = false,
        clusters: [LabyrinthCluster] = [],
        nodes: [String: LabyrinthNode] = [:],
        runHealthByCombatantID: [String: Int] = [:],
        isMapPayloadUnreadable: Bool = false
    ) {
        self.worldSeed = worldSeed
        self.mapVersion = mapVersion
        self.hasEntered = hasEntered
        self.clusters = clusters
        self.nodes = nodes
        self.runHealthByCombatantID = runHealthByCombatantID
        self.isMapPayloadUnreadable = isMapPayloadUnreadable
    }

    public var hasMap: Bool {
        !nodes.isEmpty
    }

    public func node(id: String) -> LabyrinthNode? {
        nodes[id]
    }

    public func cluster(id: String) -> LabyrinthCluster? {
        clusters.first { $0.id == id }
    }

    public func cluster(for nodeID: String) -> LabyrinthCluster? {
        guard let node = nodes[nodeID] else { return nil }
        return cluster(id: node.clusterID)
    }

    /// A node is actionable when revealed, not cleared, and adjacent to a cleared hex.
    /// Explicit outgoing links bridge the entrance and completed floors.
    public func isNodeReachable(_ nodeID: String) -> Bool {
        guard let node = nodes[nodeID], node.isRevealed, !node.isCleared else { return false }
        if node.id == LabyrinthGenerator.entranceNodeID {
            return false
        }
        let index = reachabilityIndex()
        if index.explicitOutgoingIDs.contains(nodeID) {
            return true
        }
        guard let position = node.gridPosition,
              let clearedPositions = index.clearedPositionsByCluster[node.clusterID]
        else { return false }
        return Self.adjacentPositions(to: position).contains { clearedPositions.contains($0) }
    }

    public func reachableNodeIDs() -> [String] {
        let index = reachabilityIndex()

        return nodes.values.compactMap { node in
            guard node.isRevealed,
                  !node.isCleared,
                  node.id != LabyrinthGenerator.entranceNodeID
            else { return nil }
            if index.explicitOutgoingIDs.contains(node.id) {
                return node.id
            }
            guard let position = node.gridPosition,
                  let clearedPositions = index.clearedPositionsByCluster[node.clusterID],
                  Self.adjacentPositions(to: position).contains(where: clearedPositions.contains)
            else { return nil }
            return node.id
        }.sorted()
    }

    private func reachabilityIndex() -> ReachabilityIndex {
        var index = ReachabilityIndex()
        for node in nodes.values where node.isCleared {
            index.explicitOutgoingIDs.formUnion(node.outgoingIDs)
            if let position = node.gridPosition {
                index.clearedPositionsByCluster[node.clusterID, default: []].insert(position)
            }
        }
        return index
    }

    private static func adjacentPositions(to position: LabyrinthGridPosition) -> [LabyrinthGridPosition] {
        [
            LabyrinthGridPosition(row: position.row, column: position.column - 1),
            LabyrinthGridPosition(row: position.row, column: position.column + 1),
            LabyrinthGridPosition(row: position.row - 1, column: position.column),
            LabyrinthGridPosition(row: position.row - 1, column: position.column + 1),
            LabyrinthGridPosition(row: position.row + 1, column: position.column - 1),
            LabyrinthGridPosition(row: position.row + 1, column: position.column),
        ].filter { position.isAdjacent(to: $0) }
    }

    public var currentFloorNumber: Int {
        clusters.map(\.depthBand).max() ?? 0
    }

    public mutating func ensureMap(
        seed: UInt64? = nil,
        eligibleRecruitEventIDs: [String] = []
    ) {
        if isMapPayloadUnreadable {
            // Auto-recovery path for corrupt blobs (Phase 2.2): clear the
            // unreadable flag so a fresh map can be generated instead of
            // looping "Labyrinth Error" forever.
            isMapPayloadUnreadable = false
            if hasMap {
                return
            }
        } else if hasMap {
            return
        }
        let resolvedSeed: UInt64 = {
            if let seed, seed != 0 { return seed }
            return worldSeed
        }()
        guard resolvedSeed != 0 else { return }
        let generated = LabyrinthGenerator.makeInitialMap(
            seed: resolvedSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        worldSeed = resolvedSeed
        clusters = generated.clusters
        nodes = generated.nodes
        runHealthByCombatantID = [:]
        mapVersion = LabyrinthGenerator.currentMapVersion
        hasEntered = true
        isMapPayloadUnreadable = false
    }

    public mutating func markCleared(
        nodeID: String,
        eligibleRecruitEventIDs: [String] = []
    ) {
        guard var node = nodes[nodeID], !node.isCleared else { return }
        node.isCleared = true
        nodes[nodeID] = node
        LabyrinthGenerator.revealReachable(from: nodeID, nodes: &nodes)

        if node.type.canonical == .boss {
            LabyrinthGenerator.expandBeyondBoss(
                bossNodeID: nodeID,
                clusters: &clusters,
                nodes: &nodes,
                seed: worldSeed,
                eligibleRecruitEventIDs: eligibleRecruitEventIDs
            )
        }
    }

    public func effects(for nodeID: String) -> LabyrinthModifierEffects {
        guard let node = node(id: nodeID) else { return .zero }
        let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        return LabyrinthModifierEffects.combining(modifiers)
    }
}
