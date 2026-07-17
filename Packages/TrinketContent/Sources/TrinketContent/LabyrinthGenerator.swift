import Foundation
import TrinketCore

/// Deterministic expanding DAG generator for The Labyrinth.
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
            seed: seed &+ UInt64(nextBand) &* 1000003 &+ GameContent.stableSeed(for: gateNodeID)
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

    private static func generateCluster(
        depthBand: Int,
        previousBiomeID: LabyrinthBiomeID?,
        using rng: inout some RandomNumberGenerator
    ) -> GeneratedCluster {
        let biome = pickBiome(excluding: previousBiomeID, using: &rng)
        let modifierIDs = rollModifiers(depthBand: depthBand, biome: biome, using: &rng)
        let modifiers = LabyrinthCatalog.modifiers(ids: modifierIDs)
        let clusterID = "labyrinth-cluster-\(depthBand)-\(biome.id.rawValue)"
        let nodeCount = Int.random(in: 3 ... 7, using: &rng)
        let types = plannedTypes(
            count: nodeCount,
            depthBand: depthBand,
            modifiers: modifiers,
            biome: biome,
            using: &rng
        )
        var nodes = makeNodes(
            types: types,
            clusterID: clusterID,
            depthBand: depthBand,
            biome: biome,
            using: &rng
        )
        wireLayeredEdges(nodes: &nodes, using: &rng)
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

    private static func makeNodes(
        types: [LabyrinthNodeType],
        clusterID: String,
        depthBand: Int,
        biome: LabyrinthBiomeDefinition,
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthNode] {
        types.enumerated().map { index, type in
            let enemyID: String? = if type.isCombat {
                (type == .boss)
                    ? biome.bossEnemyID
                    : pickEnemy(from: biome, using: &rng)
            } else {
                nil
            }
            return LabyrinthNode(
                id: "\(clusterID)-n\(index)",
                type: type,
                enemyID: enemyID,
                depth: depthBand,
                clusterID: clusterID,
                outgoingIDs: [],
                isCleared: false,
                isRevealed: depthBand == 1 && index == 0,
                failCount: 0
            )
        }
    }

    private static func wireLayeredEdges(
        nodes: inout [LabyrinthNode],
        using rng: inout some RandomNumberGenerator
    ) {
        for index in nodes.indices {
            if nodes[index].type == .gate {
                continue
            }
            let remaining = (index + 1) ..< nodes.count
            guard !remaining.isEmpty else { continue }
            let preferred = Int.random(in: 2 ... 3, using: &rng)
            let targetCount = min(remaining.count, preferred)
            let targets = Array(remaining).shuffled(using: &rng).prefix(targetCount)
            nodes[index].outgoingIDs = targets.map { nodes[$0].id }
        }
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

    private static func rollModifiers(
        depthBand: Int,
        biome: LabyrinthBiomeDefinition,
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthModifierID] {
        let count = switch depthBand {
        case 1 ... 5: 1
        case 6 ... 15: Int.random(in: 1 ... 2, using: &rng)
        default: Int.random(in: 2 ... 3, using: &rng)
        }

        var picked: [LabyrinthModifierID] = []

        // ~10% of clusters get a Special modifier (plan §5.5).
        let specialPool = LabyrinthCatalog.modifiers.filter { $0.category == .special }
        if Int.random(in: 0 ... 99, using: &rng) < 10,
           let special = specialPool.randomElement(using: &rng) {
            picked.append(special.id)
        }

        // Threat always pairs with a bounty bump (Q10A). Affinity mods that already
        // carry both threat and bounty count as a paired unit.
        let threatPool = LabyrinthCatalog.modifiers.filter {
            $0.category == .threat || ($0.enemyPowerPercent > 0 && $0.category != .special)
        }
        let bountyPool = LabyrinthCatalog.modifiers.filter {
            $0.category == .bounty || ($0.goldPercent > 0 || $0.xpPercent > 0 || $0.itemDropBonusPercent > 0)
        }
        if picked.count < count, let threat = threatPool.randomElement(using: &rng) {
            picked.append(threat.id)
            let threatDef = LabyrinthCatalog.modifier(id: threat.id)
            let alreadyPaired = (threatDef?.goldPercent ?? 0) > 0
                || (threatDef?.xpPercent ?? 0) > 0
                || (threatDef?.itemDropBonusPercent ?? 0) > 0
                || threatDef?.category == .affinity
            // Threat always ships with a bounty bump (Q10A), even if it nudges past the rolled count.
            if !alreadyPaired, picked.count < 3 {
                let bountyChoices = bountyPool.filter { !picked.contains($0.id) }
                if let bounty = bountyChoices.randomElement(using: &rng) {
                    picked.append(bounty.id)
                }
            }
        }

        let affinityMatches = LabyrinthCatalog.modifiers.filter {
            $0.keywordBias == biome.keywordBias && !picked.contains($0.id)
        }
        if picked.count < count, let affinity = affinityMatches.randomElement(using: &rng) {
            picked.append(affinity.id)
        }

        let remainingPool = LabyrinthCatalog.modifiers.filter { !picked.contains($0.id) }
        var remaining = remainingPool
        while picked.count < count, !remaining.isEmpty {
            guard let next = remaining.randomElement(using: &rng) else { break }
            remaining.removeAll { $0.id == next.id }
            picked.append(next.id)
        }
        return Array(picked.prefix(count))
    }

    private static func plannedTypes(
        count: Int,
        depthBand: Int,
        modifiers: [LabyrinthModifierDefinition],
        biome: LabyrinthBiomeDefinition,
        using rng: inout some RandomNumberGenerator
    ) -> [LabyrinthNodeType] {
        var types: [LabyrinthNodeType] = []
        // Guaranteed specials from modifiers.
        for modifier in modifiers {
            if let guaranteed = modifier.guaranteedNodeType?.canonical, !types.contains(guaranteed) {
                types.append(guaranteed)
            }
        }

        // Always end with a gate (combat depth transition).
        let fillCount = max(0, count - types.count - 1)
        var weighted: [LabyrinthNodeType] = [
            .battle, .battle, .battle, .battle,
            .shop, .rest, .mystery, .craft
        ]
        // Threat modifiers bias battle finds; Heartwell / rest-leaning biomes bias shrines.
        let threatPower = modifiers.reduce(0) { $0 + $1.enemyPowerPercent }
        if threatPower >= 15 {
            weighted.append(contentsOf: [.battle, .battle])
        }
        if biome.id == .heartwellGrotto || modifiers.contains(where: { $0.guaranteedNodeType == .rest }) {
            weighted.append(contentsOf: [.rest, .rest])
        }
        for _ in 0 ..< fillCount {
            types.append(weighted.randomElement(using: &rng) ?? .battle)
        }

        // Depth 1+: ensure at least one battle-like node before the gate.
        if !types.contains(where: { $0 == .battle || $0 == .boss }) {
            types.insert(.battle, at: 0)
        }

        types = Array(types.prefix(max(count - 1, 1)))
        // Occasional boss near the end of deeper bands.
        if depthBand >= 3, !types.contains(.boss), Int.random(in: 0 ... 4, using: &rng) == 0 {
            if let replaceIndex = types.indices.randomElement(using: &rng) {
                types[replaceIndex] = .boss
            }
        }
        // Prefer a combat encounter as the cluster entry for a clear first action.
        if let battleIndex = types.firstIndex(where: { $0 == .battle }), battleIndex != 0 {
            types.swapAt(0, battleIndex)
        } else if !types.contains(where: { $0.isCombat && $0 != .gate }) {
            types.insert(.battle, at: 0)
        }
        types.append(.gate)
        return types
    }
}
