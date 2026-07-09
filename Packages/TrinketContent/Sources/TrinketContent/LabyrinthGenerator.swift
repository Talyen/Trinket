import Foundation
import TrinketCore

/// Deterministic expanding DAG generator for Wanderer's Labyrinth.
public enum LabyrinthGenerator {
    public static let entranceNodeID = "labyrinth-entrance"
    public static let entranceClusterID = "labyrinth-cluster-0"

    /// Creates a fresh map with the entrance cluster (depth band 1).
    public static func makeInitialMap(seed: UInt64 = 0) -> (
        clusters: [LabyrinthCluster],
        nodes: [String: LabyrinthNode],
        deepestDepth: Int
    ) {
        var rng = SeededRandomNumberGenerator(seed: seed == 0 ? 0x4C41_4259 : seed)
        var nodes: [String: LabyrinthNode] = [:]
        var clusters: [LabyrinthCluster] = []

        let first = generateCluster(
            depthBand: 1,
            previousBiomeID: nil,
            using: &rng
        )
        clusters.append(first.cluster)
        for node in first.nodes {
            nodes[node.id] = node
        }

        // Entrance is always revealed and acts as a free cleared gate into the first cluster.
        let entrance = LabyrinthNode(
            id: entranceNodeID,
            type: .gate,
            enemyID: nil,
            depth: 0,
            clusterID: entranceClusterID,
            outgoingIDs: first.entryNodeIDs,
            isCleared: true,
            isRevealed: true
        )
        nodes[entrance.id] = entrance
        clusters.insert(
            LabyrinthCluster(
                id: entranceClusterID,
                biomeID: first.cluster.biomeID,
                depthBand: 0,
                modifierIDs: [],
                nodeIDs: [entrance.id]
            ),
            at: 0
        )

        revealReachable(from: entrance.id, nodes: &nodes)
        return (clusters, nodes, 0)
    }

    /// Appends the next depth-band cluster beyond a cleared gate and wires edges.
    public static func expandBeyondGate(
        gateNodeID: String,
        clusters: inout [LabyrinthCluster],
        nodes: inout [String: LabyrinthNode],
        seed: UInt64
    ) {
        guard var gate = nodes[gateNodeID], gate.type == .gate, gate.isCleared else { return }
        guard gate.outgoingIDs.isEmpty else { return }

        let nextBand = gate.depth + 1
        let previousBiome = clusters.last(where: { $0.depthBand == gate.depth })?.biomeID
            ?? clusters.last?.biomeID

        var rng = SeededRandomNumberGenerator(
            seed: seed &+ UInt64(nextBand) &* 1_000_003 &+ GameContent.stableSeed(for: gateNodeID)
        )
        let generated = generateCluster(
            depthBand: nextBand,
            previousBiomeID: previousBiome,
            using: &rng
        )
        clusters.append(generated.cluster)
        for node in generated.nodes {
            nodes[node.id] = node
        }
        gate.outgoingIDs = generated.entryNodeIDs
        nodes[gate.id] = gate
        revealReachable(from: gate.id, nodes: &nodes)
    }

    public static func revealReachable(from nodeID: String, nodes: inout [String: LabyrinthNode]) {
        guard let source = nodes[nodeID] else { return }
        for outgoingID in source.outgoingIDs {
            guard var target = nodes[outgoingID] else { continue }
            if !target.isRevealed {
                target.isRevealed = true
                nodes[outgoingID] = target
            }
        }
    }

    // MARK: - Cluster generation

    private struct GeneratedCluster {
        let cluster: LabyrinthCluster
        let nodes: [LabyrinthNode]
        let entryNodeIDs: [String]
    }

    private static func generateCluster<RNG: RandomNumberGenerator>(
        depthBand: Int,
        previousBiomeID: LabyrinthBiomeID?,
        using rng: inout RNG
    ) -> GeneratedCluster {
        let biome = pickBiome(excluding: previousBiomeID, using: &rng)
        let modifierIDs = rollModifiers(depthBand: depthBand, biome: biome, using: &rng)
        let modifiers = LabyrinthCatalog.modifiers(ids: modifierIDs)
        let clusterID = "labyrinth-cluster-\(depthBand)-\(biome.id.rawValue)"

        let nodeCount = Int.random(in: 3 ... 5, using: &rng)
        var types = plannedTypes(
            count: nodeCount,
            depthBand: depthBand,
            modifiers: modifiers,
            using: &rng
        )

        var nodes: [LabyrinthNode] = []
        nodes.reserveCapacity(types.count)
        for (index, type) in types.enumerated() {
            let nodeID = "\(clusterID)-n\(index)"
            let enemyID: String?
            if type.isCombat {
                if type == .warden || type == .gate {
                    enemyID = type == .warden ? biome.wardenEnemyID : pickEnemy(from: biome, using: &rng)
                } else {
                    enemyID = pickEnemy(from: biome, using: &rng)
                }
            } else {
                enemyID = nil
            }
            nodes.append(
                LabyrinthNode(
                    id: nodeID,
                    type: type,
                    enemyID: enemyID,
                    depth: depthBand,
                    clusterID: clusterID,
                    outgoingIDs: [],
                    isCleared: false,
                    isRevealed: depthBand == 1 && index == 0,
                    failCount: 0
                )
            )
        }

        // Wire a simple layered DAG: each node connects to 1–2 later nodes; last is gate.
        for index in nodes.indices {
            if nodes[index].type == .gate { continue }
            let remaining = (index + 1) ..< nodes.count
            guard !remaining.isEmpty else { continue }
            let targetCount = min(remaining.count, Int.random(in: 1 ... 2, using: &rng))
            let targets = Array(remaining).shuffled(using: &rng).prefix(targetCount)
            nodes[index].outgoingIDs = targets.map { nodes[$0].id }
        }

        // Ensure every non-entry node is reachable from entry (index 0).
        ensureReachability(nodes: &nodes)

        let cluster = LabyrinthCluster(
            id: clusterID,
            biomeID: biome.id,
            depthBand: depthBand,
            modifierIDs: modifierIDs,
            nodeIDs: nodes.map(\.id)
        )
        return GeneratedCluster(
            cluster: cluster,
            nodes: nodes,
            entryNodeIDs: nodes.isEmpty ? [] : [nodes[0].id]
        )
    }

    private static func ensureReachability(nodes: inout [LabyrinthNode]) {
        guard nodes.count > 1 else { return }
        var reachable: Set<String> = [nodes[0].id]
        var changed = true
        while changed {
            changed = false
            for node in nodes where reachable.contains(node.id) {
                for outgoing in node.outgoingIDs where !reachable.contains(outgoing) {
                    reachable.insert(outgoing)
                    changed = true
                }
            }
        }
        for index in nodes.indices where !reachable.contains(nodes[index].id) {
            // Link from the nearest earlier reachable node.
            if let prior = nodes[..<index].last(where: { reachable.contains($0.id) }) {
                if let priorIndex = nodes.firstIndex(where: { $0.id == prior.id }) {
                    nodes[priorIndex].outgoingIDs.append(nodes[index].id)
                    reachable.insert(nodes[index].id)
                }
            }
        }
    }

    private static func pickBiome<RNG: RandomNumberGenerator>(
        excluding previous: LabyrinthBiomeID?,
        using rng: inout RNG
    ) -> LabyrinthBiomeDefinition {
        let pool = LabyrinthCatalog.biomes.filter { $0.id != previous }
        let choices = pool.isEmpty ? LabyrinthCatalog.biomes : pool
        return choices.randomElement(using: &rng) ?? LabyrinthCatalog.biomes[0]
    }

    private static func pickEnemy<RNG: RandomNumberGenerator>(
        from biome: LabyrinthBiomeDefinition,
        using rng: inout RNG
    ) -> String {
        biome.enemyPool.randomElement(using: &rng) ?? biome.wardenEnemyID
    }

    private static func rollModifiers<RNG: RandomNumberGenerator>(
        depthBand: Int,
        biome: LabyrinthBiomeDefinition,
        using rng: inout RNG
    ) -> [LabyrinthModifierID] {
        let count: Int
        switch depthBand {
        case 1 ... 5: count = 1
        case 6 ... 15: count = Int.random(in: 1 ... 2, using: &rng)
        default: count = Int.random(in: 2 ... 3, using: &rng)
        }

        var picked: [LabyrinthModifierID] = []
        // Prefer a threat-style modifier first so bounty pairing is visible.
        let threatPool = LabyrinthCatalog.modifiers.filter { $0.category == .threat || $0.enemyPowerPercent > 0 }
        if let threat = threatPool.randomElement(using: &rng) {
            picked.append(threat.id)
        }

        let affinityMatches = LabyrinthCatalog.modifiers.filter {
            $0.keywordBias == biome.keywordBias && !picked.contains($0.id)
        }
        if picked.count < count, let affinity = affinityMatches.randomElement(using: &rng) {
            picked.append(affinity.id)
        }

        let remainingPool = LabyrinthCatalog.modifiers.filter { !picked.contains($0.id) }
        while picked.count < count, let next = remainingPool.randomElement(using: &rng) {
            if picked.contains(next.id) { continue }
            picked.append(next.id)
            if picked.count >= count { break }
        }
        return Array(picked.prefix(count))
    }

    private static func plannedTypes<RNG: RandomNumberGenerator>(
        count: Int,
        depthBand: Int,
        modifiers: [LabyrinthModifierDefinition],
        using rng: inout RNG
    ) -> [LabyrinthNodeType] {
        var types: [LabyrinthNodeType] = []
        // Guaranteed specials from modifiers.
        for modifier in modifiers {
            if let guaranteed = modifier.guaranteedNodeType, !types.contains(guaranteed) {
                types.append(guaranteed)
            }
        }

        // Always end with a gate (combat depth transition).
        let fillCount = max(0, count - types.count - 1)
        let weighted: [LabyrinthNodeType] = [
            .battle, .battle, .battle, .elite,
            .shop, .rest, .mystery, .event, .craft
        ]
        for _ in 0 ..< fillCount {
            types.append(weighted.randomElement(using: &rng) ?? .battle)
        }

        // Depth 1+: ensure at least one battle-like node before the gate.
        if !types.contains(where: { $0 == .battle || $0 == .elite || $0 == .warden }) {
            types.insert(.battle, at: 0)
        }

        types = Array(types.prefix(max(count - 1, 1)))
        // Occasional warden near the end of deeper bands.
        if depthBand >= 3, !types.contains(.warden), Int.random(in: 0 ... 4, using: &rng) == 0 {
            if let replaceIndex = types.indices.randomElement(using: &rng) {
                types[replaceIndex] = .warden
            }
        }
        // Prefer a combat encounter as the cluster entry for a clear first action.
        if let battleIndex = types.firstIndex(where: { $0 == .battle || $0 == .elite }), battleIndex != 0 {
            types.swapAt(0, battleIndex)
        } else if !types.contains(where: { $0.isCombat && $0 != .gate }) {
            types.insert(.battle, at: 0)
        }
        types.append(.gate)
        return types
    }
}
