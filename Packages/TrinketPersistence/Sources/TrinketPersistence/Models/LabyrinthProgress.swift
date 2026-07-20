import Foundation
import TrinketContent
import TrinketCore

/// Persistent The Labyrinth map.
public struct PlayerLabyrinthState: Equatable, Sendable {
    public var worldSeed: UInt64
    public var mapVersion: Int
    public var hasEntered: Bool
    public var clusters: [LabyrinthCluster]
    public var nodes: [String: LabyrinthNode]

    public static let freshStart = PlayerLabyrinthState()
    public static let testSeed = PlayerLabyrinthState()

    public init(
        worldSeed: UInt64 = 0,
        mapVersion: Int = LabyrinthGenerator.currentMapVersion,
        hasEntered: Bool = false,
        clusters: [LabyrinthCluster] = [],
        nodes: [String: LabyrinthNode] = [:]
    ) {
        self.worldSeed = worldSeed
        self.mapVersion = mapVersion
        self.hasEntered = hasEntered
        self.clusters = clusters
        self.nodes = nodes
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

    /// A node is actionable when revealed, not cleared, and reachable from a cleared ancestor
    /// (or it is the entrance's outgoing target).
    public func isNodeReachable(_ nodeID: String) -> Bool {
        guard let node = nodes[nodeID], node.isRevealed, !node.isCleared else { return false }
        if node.id == LabyrinthGenerator.entranceNodeID {
            return false
        }
        // Reachable if any cleared node lists it as outgoing.
        return nodes.values.contains { source in
            source.isCleared && source.outgoingIDs.contains(nodeID)
        }
    }

    public func reachableNodeIDs() -> [String] {
        nodes.keys.filter { isNodeReachable($0) }.sorted()
    }

    public var currentFloorNumber: Int {
        clusters.map(\.depthBand).max() ?? 0
    }

    public mutating func ensureMap(
        seed: UInt64? = nil,
        eligibleRecruitEventIDs: [String] = []
    ) {
        guard !hasMap else { return }
        let resolvedSeed = seed ?? worldSeed
        let generated = LabyrinthGenerator.makeInitialMap(
            seed: resolvedSeed == 0 ? 0x4C41_4259 : resolvedSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs
        )
        worldSeed = resolvedSeed == 0 ? 0x4C41_4259 : resolvedSeed
        clusters = generated.clusters
        nodes = generated.nodes
        mapVersion = LabyrinthGenerator.currentMapVersion
        hasEntered = true
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
        guard let cluster = cluster(for: nodeID),
              let biome = LabyrinthCatalog.biome(id: cluster.biomeID)
        else {
            return .zero
        }
        guard let node = node(id: nodeID) else { return .zero }
        let modifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        return LabyrinthModifierEffects.combining(modifiers, biomeBias: biome.keywordBias)
    }
}
