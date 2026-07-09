import Foundation
import TrinketContent
import TrinketCore

/// Persistent Wanderer's Labyrinth map + discovery meta.
public struct PlayerLabyrinthState: Equatable, Sendable {
    public var worldSeed: UInt64
    public var deepestDepth: Int
    public var hasEntered: Bool
    public var clusters: [LabyrinthCluster]
    public var nodes: [String: LabyrinthNode]
    public var discoveredBiomeIDs: Set<String>
    public var discoveredModifierIDs: Set<String>
    public var claimedMilestoneDepths: Set<Int>

    public static let freshStart = PlayerLabyrinthState()
    public static let testSeed = PlayerLabyrinthState()

    public init(
        worldSeed: UInt64 = 0,
        deepestDepth: Int = 0,
        hasEntered: Bool = false,
        clusters: [LabyrinthCluster] = [],
        nodes: [String: LabyrinthNode] = [:],
        discoveredBiomeIDs: Set<String> = [],
        discoveredModifierIDs: Set<String> = [],
        claimedMilestoneDepths: Set<Int> = []
    ) {
        self.worldSeed = worldSeed
        self.deepestDepth = deepestDepth
        self.hasEntered = hasEntered
        self.clusters = clusters
        self.nodes = nodes
        self.discoveredBiomeIDs = discoveredBiomeIDs
        self.discoveredModifierIDs = discoveredModifierIDs
        self.claimedMilestoneDepths = claimedMilestoneDepths
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
        if node.id == LabyrinthGenerator.entranceNodeID { return false }
        // Reachable if any cleared node lists it as outgoing.
        return nodes.values.contains { source in
            source.isCleared && source.outgoingIDs.contains(nodeID)
        }
    }

    public func reachableNodeIDs() -> [String] {
        nodes.keys.filter { isNodeReachable($0) }.sorted()
    }

    public mutating func ensureMap(seed: UInt64? = nil) {
        guard !hasMap else { return }
        let resolvedSeed = seed ?? worldSeed
        let generated = LabyrinthGenerator.makeInitialMap(seed: resolvedSeed == 0 ? 0x4C41_4259 : resolvedSeed)
        worldSeed = resolvedSeed == 0 ? 0x4C41_4259 : resolvedSeed
        clusters = generated.clusters
        nodes = generated.nodes
        deepestDepth = generated.deepestDepth
        hasEntered = true
        recordDiscoveries()
    }

    public mutating func recordFail(nodeID: String) {
        guard var node = nodes[nodeID] else { return }
        node.failCount += 1
        nodes[nodeID] = node
    }

    public mutating func markCleared(nodeID: String) {
        guard var node = nodes[nodeID], !node.isCleared else { return }
        node.isCleared = true
        nodes[nodeID] = node
        deepestDepth = max(deepestDepth, node.depth)
        LabyrinthGenerator.revealReachable(from: nodeID, nodes: &nodes)

        if node.type == .gate {
            LabyrinthGenerator.expandBeyondGate(
                gateNodeID: nodeID,
                clusters: &clusters,
                nodes: &nodes,
                seed: worldSeed
            )
        }
        recordDiscoveries()
    }

    public mutating func recordDiscoveries() {
        for cluster in clusters where cluster.depthBand > 0 {
            // Discover biome/modifiers once any node in the cluster is revealed.
            let revealed = cluster.nodeIDs.contains { nodes[$0]?.isRevealed == true }
            guard revealed else { continue }
            discoveredBiomeIDs.insert(cluster.biomeID.rawValue)
            for modifierID in cluster.modifierIDs {
                discoveredModifierIDs.insert(modifierID.rawValue)
            }
        }
    }

    public func effects(for nodeID: String) -> LabyrinthModifierEffects {
        guard let cluster = cluster(for: nodeID),
              let biome = LabyrinthCatalog.biome(id: cluster.biomeID)
        else {
            return .zero
        }
        let modifiers = LabyrinthCatalog.modifiers(ids: cluster.modifierIDs)
        return LabyrinthModifierEffects.combining(modifiers, biomeBias: biome.keywordBias)
    }
}

public extension PlayerLabyrinthState {
    var current: PlayerLabyrinthState {
        get { self }
        set { self = newValue }
    }
}
